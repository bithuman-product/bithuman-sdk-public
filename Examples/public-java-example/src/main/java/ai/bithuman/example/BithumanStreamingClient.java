package ai.bithuman.example;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import org.java_websocket.client.WebSocketClient;
import org.java_websocket.handshake.ServerHandshake;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.imageio.ImageIO;
import javax.sound.sampled.*;
import java.awt.image.BufferedImage;
import java.io.*;
import java.net.URI;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/**
 * bitHuman Java Streaming Client
 *
 * Streams PCM audio over WebSocket and receives JPEG video frames + PCM audio
 * from the bitHuman streaming server.
 *
 * Audio input:   16 kHz, mono, signed 16-bit little-endian PCM
 * Video output:  JPEG frames at 25 FPS
 * Audio output:  16 kHz, mono, signed 16-bit little-endian PCM
 *
 * Usage:
 *   java -jar bithuman-java-example.jar \
 *       --server ws://localhost:8765 \
 *       --audio  input.wav \
 *       --output-dir ./frames
 */
public class BithumanStreamingClient {

    private static final Logger log = LoggerFactory.getLogger(BithumanStreamingClient.class);
    private static final Gson gson = new Gson();

    // Binary message type tags — must match the Python server
    private static final byte TAG_VIDEO = 0x01;
    private static final byte TAG_AUDIO = 0x02;
    private static final byte TAG_END_OF_SPEECH = 0x03;

    // Audio format: 16 kHz, mono, int16 LE
    private static final int SAMPLE_RATE = 16_000;
    private static final int CHANNELS = 1;
    private static final int BITS_PER_SAMPLE = 16;
    private static final int CHUNK_MS = 100;
    private static final int SAMPLES_PER_CHUNK = SAMPLE_RATE * CHUNK_MS / 1000;
    private static final int BYTES_PER_CHUNK = SAMPLES_PER_CHUNK * (BITS_PER_SAMPLE / 8);

    private final URI serverUri;
    private final Path audioFile;
    private final Path outputDir;
    private final boolean saveFrames;
    private final boolean playAudio;

    private AvatarWebSocket ws;
    private final AtomicBoolean connected = new AtomicBoolean(false);
    private final CountDownLatch connectLatch = new CountDownLatch(1);
    private final CountDownLatch doneLatch = new CountDownLatch(1);

    // Stats
    private final AtomicLong videoFramesReceived = new AtomicLong(0);
    private final AtomicLong audioChunksReceived = new AtomicLong(0);
    private final AtomicLong audioChunksSent = new AtomicLong(0);

    public BithumanStreamingClient(URI serverUri, Path audioFile, Path outputDir,
                                   boolean saveFrames, boolean playAudio) {
        this.serverUri = serverUri;
        this.audioFile = audioFile;
        this.outputDir = outputDir;
        this.saveFrames = saveFrames;
        this.playAudio = playAudio;
    }

    /** Run the full streaming session: connect, stream audio, receive frames, disconnect. */
    public void run() throws Exception {
        if (saveFrames) {
            Files.createDirectories(outputDir);
        }

        log.info("Connecting to {}...", serverUri);
        ws = new AvatarWebSocket(serverUri);
        ws.connectBlocking(10, TimeUnit.SECONDS);
        if (!connected.get()) {
            throw new IOException("Failed to connect to server");
        }

        CompletableFuture<Void> audioFuture = CompletableFuture.runAsync(() -> {
            try {
                streamAudioFile();
            } catch (Exception e) {
                log.error("Audio streaming error", e);
            }
        });

        boolean finished = doneLatch.await(120, TimeUnit.SECONDS);
        if (!finished) {
            log.warn("Timed out waiting for end-of-speech");
        }

        audioFuture.cancel(true);
        ws.closeBlocking();

        log.info("Session complete — {} video frames, {} audio chunks received, {} audio chunks sent",
                videoFramesReceived.get(), audioChunksReceived.get(), audioChunksSent.get());
    }

    /** Read a WAV file, resample to 16 kHz mono int16 if needed, and stream over WebSocket. */
    private void streamAudioFile() throws Exception {
        log.info("Loading audio file: {}", audioFile);

        try (AudioInputStream rawStream = AudioSystem.getAudioInputStream(audioFile.toFile())) {
            AudioFormat srcFormat = rawStream.getFormat();
            log.info("Source format: {} Hz, {} ch, {} bits, {}",
                    srcFormat.getSampleRate(), srcFormat.getChannels(),
                    srcFormat.getSampleSizeInBits(), srcFormat.getEncoding());

            AudioFormat targetFormat = new AudioFormat(
                    AudioFormat.Encoding.PCM_SIGNED,
                    SAMPLE_RATE, BITS_PER_SAMPLE, CHANNELS,
                    CHANNELS * (BITS_PER_SAMPLE / 8),
                    SAMPLE_RATE, false
            );

            AudioInputStream pcmStream;
            if (srcFormat.matches(targetFormat)) {
                pcmStream = rawStream;
            } else {
                if (srcFormat.getEncoding() != AudioFormat.Encoding.PCM_SIGNED
                        && srcFormat.getEncoding() != AudioFormat.Encoding.PCM_UNSIGNED
                        && srcFormat.getEncoding() != AudioFormat.Encoding.PCM_FLOAT) {
                    AudioFormat decodedFormat = new AudioFormat(
                            AudioFormat.Encoding.PCM_SIGNED,
                            srcFormat.getSampleRate(),
                            16,
                            srcFormat.getChannels(),
                            srcFormat.getChannels() * 2,
                            srcFormat.getSampleRate(),
                            false
                    );
                    AudioInputStream decoded = AudioSystem.getAudioInputStream(decodedFormat, rawStream);
                    pcmStream = AudioSystem.getAudioInputStream(targetFormat, decoded);
                } else {
                    pcmStream = AudioSystem.getAudioInputStream(targetFormat, rawStream);
                }
            }

            log.info("Streaming audio as 16 kHz / mono / int16 LE in {} ms chunks...", CHUNK_MS);

            byte[] buf = new byte[BYTES_PER_CHUNK];
            int read;
            long totalSent = 0;

            while ((read = pcmStream.read(buf, 0, buf.length)) > 0 && connected.get()) {
                byte[] chunk = (read == buf.length) ? buf : java.util.Arrays.copyOf(buf, read);
                ws.send(chunk);
                totalSent += read;
                audioChunksSent.incrementAndGet();
                Thread.sleep(CHUNK_MS);
            }
            pcmStream.close();
            log.info("Audio streaming complete — {} bytes sent", totalSent);
            sendJson("end");
        }
    }

    private void onVideoFrame(int width, int height, float fps, double timestamp, byte[] jpegData) {
        long n = videoFramesReceived.incrementAndGet();

        if (saveFrames) {
            try {
                BufferedImage img = ImageIO.read(new ByteArrayInputStream(jpegData));
                if (img != null) {
                    Path outPath = outputDir.resolve(String.format("frame_%06d.jpg", n));
                    ImageIO.write(img, "jpg", outPath.toFile());
                }
            } catch (IOException e) {
                log.warn("Failed to save frame {}: {}", n, e.getMessage());
            }
        }

        if (n % 25 == 0) {
            log.info("Video: frame #{} ({}x{}, {} FPS)", n, width, height, String.format("%.1f", fps));
        }
    }

    private void onAudioChunk(int sampleRate, int channels, double timestamp, byte[] pcmData) {
        audioChunksReceived.incrementAndGet();
        // To play audio, push pcmData into a SourceDataLine — see README for details.
    }

    private void onEndOfSpeech() {
        log.info("End-of-speech received from server");
        doneLatch.countDown();
    }

    private void sendJson(String type) {
        JsonObject msg = new JsonObject();
        msg.addProperty("type", type);
        ws.send(msg.toString());
    }

    private class AvatarWebSocket extends WebSocketClient {

        AvatarWebSocket(URI uri) {
            super(uri);
        }

        @Override
        public void onOpen(ServerHandshake handshake) {
            log.info("WebSocket opened (status {})", handshake.getHttpStatus());
            connected.set(true);
            connectLatch.countDown();
        }

        @Override
        public void onMessage(String message) {
            try {
                JsonObject json = gson.fromJson(message, JsonObject.class);
                String type = json.has("type") ? json.get("type").getAsString() : "unknown";
                log.info("Server message [{}]: {}", type,
                        json.has("message") ? json.get("message").getAsString() : message);
            } catch (Exception e) {
                log.debug("Non-JSON text from server: {}", message);
            }
        }

        @Override
        public void onMessage(ByteBuffer buffer) {
            if (buffer.remaining() < 1) return;

            buffer.order(ByteOrder.BIG_ENDIAN);
            byte tag = buffer.get();

            switch (tag) {
                case TAG_VIDEO -> parseVideoFrame(buffer);
                case TAG_AUDIO -> parseAudioChunk(buffer);
                case TAG_END_OF_SPEECH -> onEndOfSpeech();
                default -> log.warn("Unknown binary tag: 0x{}", String.format("%02X", tag));
            }
        }

        @Override
        public void onClose(int code, String reason, boolean remote) {
            log.info("WebSocket closed: code={}, reason='{}', remote={}", code, reason, remote);
            connected.set(false);
            connectLatch.countDown();
            doneLatch.countDown();
        }

        @Override
        public void onError(Exception ex) {
            log.error("WebSocket error", ex);
        }

        private void parseVideoFrame(ByteBuffer buf) {
            if (buf.remaining() < 20) {
                log.warn("Truncated video header");
                return;
            }
            int width = Short.toUnsignedInt(buf.getShort());
            int height = Short.toUnsignedInt(buf.getShort());
            float fps = buf.getFloat();
            int jpegLen = buf.getInt();
            double timestamp = buf.getDouble();

            if (buf.remaining() < jpegLen) {
                log.warn("Truncated video payload (expected {} bytes, got {})", jpegLen, buf.remaining());
                return;
            }
            byte[] jpegData = new byte[jpegLen];
            buf.get(jpegData);

            onVideoFrame(width, height, fps, timestamp, jpegData);
        }

        private void parseAudioChunk(ByteBuffer buf) {
            if (buf.remaining() < 17) {
                log.warn("Truncated audio header");
                return;
            }
            int sampleRate = buf.getInt();
            int channels = Byte.toUnsignedInt(buf.get());
            int pcmLen = buf.getInt();
            double timestamp = buf.getDouble();

            if (buf.remaining() < pcmLen) {
                log.warn("Truncated audio payload (expected {} bytes, got {})", pcmLen, buf.remaining());
                return;
            }
            byte[] pcmData = new byte[pcmLen];
            buf.get(pcmData);

            onAudioChunk(sampleRate, channels, timestamp, pcmData);
        }
    }

    public static void main(String[] args) throws Exception {
        String serverUrl = "ws://localhost:8765";
        String audioPath = null;
        String outputPath = "./frames";
        boolean save = true;
        boolean play = false;

        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--server", "-s" -> serverUrl = args[++i];
                case "--audio", "-a" -> audioPath = args[++i];
                case "--output-dir", "-o" -> outputPath = args[++i];
                case "--no-save" -> save = false;
                case "--play-audio" -> play = true;
                case "--help", "-h" -> {
                    printUsage();
                    return;
                }
            }
        }

        if (audioPath == null) {
            System.err.println("Error: --audio <path> is required");
            printUsage();
            System.exit(1);
        }

        Path audio = Path.of(audioPath);
        if (!Files.exists(audio)) {
            System.err.println("Error: audio file not found: " + audioPath);
            System.exit(1);
        }

        log.info("bitHuman Java Streaming Client");
        log.info("  Server:     {}", serverUrl);
        log.info("  Audio:      {}", audioPath);
        log.info("  Output dir: {}", save ? outputPath : "(disabled)");

        BithumanStreamingClient client = new BithumanStreamingClient(
                URI.create(serverUrl), audio, Path.of(outputPath), save, play);
        client.run();
    }

    private static void printUsage() {
        System.out.println("""
                bitHuman Java Streaming Client

                Usage:
                  java -jar bithuman-java-example.jar [options]

                Required:
                  --audio, -a <path>       Path to input WAV audio file

                Options:
                  --server, -s <url>       WebSocket server URL (default: ws://localhost:8765)
                  --output-dir, -o <path>  Directory to save video frames (default: ./frames)
                  --no-save                Don't save video frames to disk
                  --play-audio             Play received audio through speakers
                  --help, -h               Show this help

                Examples:
                  java -jar bithuman-java-example.jar --audio speech.wav
                  java -jar bithuman-java-example.jar --server ws://gpu-server:8765 --audio speech.wav
                  java -jar bithuman-java-example.jar --audio speech.wav --no-save
                """);
    }
}
