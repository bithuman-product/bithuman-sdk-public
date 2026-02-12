# bitHuman Java Streaming Example

A complete example showing how to stream audio to a bitHuman avatar server and
receive lip-synced video frames back -- all from Java over a single WebSocket
connection.

**Tested with:** bitHuman SDK 1.6.7, Java 17, Maven 3.6+, Python 3.10

## Architecture

```
┌──────────────────────┐         WebSocket          ┌──────────────────────────────┐
│                      │                             │                              │
│   Java Client        │ ─── PCM audio chunks ────> │   Python Streaming Server    │
│                      │                             │   (bithuman_streaming_       │
│   BithumanStreaming   │ <── JPEG video frames ──── │    server.py)                │
│   Client.java        │ <── PCM audio output  ──── │                              │
│                      │ <── end-of-speech     ──── │   wraps: bithuman Python SDK │
│                      │                             │   + AsyncBithuman runtime    │
└──────────────────────┘                             └──────────────────────────────┘
```

**How it works:**
1. The Python server loads a bitHuman `.imx` avatar model and listens on a WebSocket port
2. The Java client connects, streams audio as raw PCM bytes
3. The bitHuman SDK generates lip-synced avatar video in real time
4. The server encodes each frame as JPEG and sends it back over the same WebSocket
5. The Java client receives frames and can save them, display them, or stream them onward

---

## Step-by-Step Setup Guide

### Step 1: Get Your bitHuman Credentials

1. Go to **https://imaginex.bithuman.ai** and create an account
2. Navigate to the **SDK** section and create an API secret
   - It will look like: `sk_bh_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - Save this -- you'll need it to authenticate
3. Go to the **Community** page and download an avatar model (`.imx` file)
   - Or use any `.imx` model you already have

### Step 2: Set Up the Python Server

The server requires Python 3.10+ with the bitHuman SDK.

```bash
# Install Python dependencies
pip install bithuman websockets opencv-python-headless loguru

# Verify the SDK is installed
python -c "import bithuman; print('OK')"
```

### Step 3: Install Java and Maven

**macOS:**
```bash
brew install openjdk@17 maven
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y openjdk-17-jdk maven
```

**Windows:**
- Download JDK 17 from https://adoptium.net
- Download Maven from https://maven.apache.org/download.cgi
- Add both to your PATH

Verify:
```bash
java -version   # should show 17.x
mvn -version    # should show 3.6+
```

### Step 4: Build the Java Client

```bash
cd public-java-example

# Build the fat JAR (includes all dependencies)
mvn clean package -q

# Verify the JAR was created
ls -lh target/bithuman-java-example-1.0.0.jar
```

### Step 5: Prepare a Test Audio File

You need a WAV file with speech audio. The Java client automatically handles
format conversion (sample rate, channels, bit depth), so any standard WAV works.

If you don't have one, create a test file with `ffmpeg`:

```bash
# Option A: Convert any audio file to WAV
ffmpeg -i your_audio.mp3 -ar 16000 -ac 1 -sample_fmt s16 test_speech.wav

# Option B: Record from microphone (5 seconds)
ffmpeg -f alsa -i default -t 5 -ar 16000 -ac 1 -sample_fmt s16 test_speech.wav    # Linux
ffmpeg -f avfoundation -i ":0" -t 5 -ar 16000 -ac 1 -sample_fmt s16 test_speech.wav  # macOS

# Option C: Generate a sine wave for testing (no speech, just verifies the pipeline)
ffmpeg -f lavfi -i "sine=frequency=440:duration=3" -ar 16000 -ac 1 -sample_fmt s16 test_tone.wav
```

### Step 6: Start the Python Streaming Server

Open **Terminal 1** (server):

```bash
python bithuman_streaming_server.py \
    --model /path/to/your/avatar.imx \
    --api-secret sk_bh_your_secret_here \
    --port 8765
```

You should see:
```
INFO | Model loaded — frame size 722x1280
INFO | WebSocket server listening on ws://0.0.0.0:8765
```

**Using environment variables instead** (recommended):
```bash
export BITHUMAN_MODEL_PATH=/path/to/your/avatar.imx
export BITHUMAN_API_SECRET=sk_bh_your_secret_here

python bithuman_streaming_server.py
```

### Step 7: Run the Java Client

Open **Terminal 2** (client):

```bash
# Stream audio and save video frames to ./frames/
java -jar target/bithuman-java-example-1.0.0.jar \
    --audio test_speech.wav \
    --output-dir ./frames

# Or just count frames without saving (faster)
java -jar target/bithuman-java-example-1.0.0.jar \
    --audio test_speech.wav \
    --no-save
```

You should see output like:
```
INFO - bitHuman Java Streaming Client
INFO -   Server:     ws://localhost:8765
INFO -   Audio:      test_speech.wav
INFO -   Output dir: ./frames
INFO - Connecting to ws://localhost:8765...
INFO - WebSocket opened (status 101)
INFO - Connected!
INFO - Server message [connected]: bitHuman streaming server ready
INFO - Source format: 44100.0 Hz, 2 ch, 16 bits, PCM_SIGNED
INFO - Streaming audio as 16 kHz / mono / int16 LE in 100 ms chunks...
INFO - Video: frame #25 (1280x2270, 25.0 FPS)
INFO - Video: frame #50 (1280x2270, 25.0 FPS)
INFO - Video: frame #75 (1280x2270, 25.0 FPS)
INFO - Audio streaming complete — 140804 bytes sent
INFO - Video: frame #100 (1280x2270, 25.0 FPS)
INFO - Video: frame #125 (1280x2270, 25.0 FPS)
INFO - End-of-speech received from server
INFO - Session complete — 127 video frames, 110 audio chunks received, 45 audio chunks sent
```

### Step 8: Verify the Output

If you saved frames, check them:

```bash
# List saved frames
ls frames/ | head -5

# Check a frame is valid (using Python)
python -c "from PIL import Image; img=Image.open('frames/frame_000060.jpg'); print(f'{img.size[0]}x{img.size[1]}')"

# Or open in your image viewer
open frames/frame_000060.jpg      # macOS
xdg-open frames/frame_000060.jpg  # Linux
```

You should see the avatar with mouth movements matching the audio.

---

## Running Server and Client on Different Machines

The server (with GPU/model) and client (Java app) can run on separate hosts:

**Server machine** (with bitHuman SDK + model):
```bash
python bithuman_streaming_server.py \
    --model /path/to/avatar.imx \
    --api-secret sk_bh_xxx \
    --host 0.0.0.0 \
    --port 8765
```

**Client machine** (Java only — no Python needed):
```bash
java -jar bithuman-java-example-1.0.0.jar \
    --server ws://server-ip:8765 \
    --audio speech.wav
```

---

## Java Client — Command-Line Reference

```
Usage:
  java -jar bithuman-java-example-1.0.0.jar [options]

Required:
  --audio, -a <path>       Path to input WAV audio file

Options:
  --server, -s <url>       WebSocket server URL (default: ws://localhost:8765)
  --output-dir, -o <path>  Directory to save video frames (default: ./frames)
  --no-save                Don't save video frames to disk
  --play-audio             Play received audio through speakers
  --help, -h               Show this help
```

## Python Server — Command-Line Reference

```
Usage:
  python bithuman_streaming_server.py [options]

Options:
  --model <path>           Path to .imx avatar model (or BITHUMAN_MODEL_PATH env)
  --api-secret <secret>    bitHuman API secret (or BITHUMAN_API_SECRET env)
  --token <token>          bitHuman runtime token, optional (or BITHUMAN_RUNTIME_TOKEN env)
  --host <addr>            Listen address (default: 0.0.0.0)
  --port <port>            Listen port (default: 8765)
  --insecure               Disable SSL verification (development only)
```

---

## Wire Protocol Reference

The WebSocket carries both text (JSON) and binary messages.
All multi-byte fields are **big-endian** (network byte order).

### Client to Server

| Format | Description |
|--------|-------------|
| **Binary** | Raw PCM audio: 16 kHz, mono, signed 16-bit little-endian. Send in ~100 ms chunks (3200 bytes each). |
| **JSON** `{"type":"end"}` | Signals end of the current audio segment (tells the avatar to flush). |
| **JSON** `{"type":"interrupt"}` | Interrupts the avatar's current playback immediately. |

### Server to Client

| Tag | Format | Description |
|-----|--------|-------------|
| `0x01` | Video frame | 21-byte header + JPEG payload |
| `0x02` | Audio chunk | 18-byte header + PCM payload |
| `0x03` | End-of-speech | 1-byte marker — avatar finished speaking |
| **JSON** | Status | Text frame with connection metadata (sent on connect) |

### Video Frame Header (tag = 0x01)

```
Offset  Size  Type      Field
0       1     uint8     tag (0x01)
1       2     uint16    width (pixels)
3       2     uint16    height (pixels)
5       4     float32   fps (current server FPS)
9       4     uint32    jpeg_length (payload size in bytes)
13      8     float64   timestamp (Unix epoch seconds)
21      N     bytes     JPEG image data
```

### Audio Chunk Header (tag = 0x02)

```
Offset  Size  Type      Field
0       1     uint8     tag (0x02)
1       4     uint32    sample_rate (typically 16000)
5       1     uint8     channels (typically 1)
6       4     uint32    pcm_length (payload size in bytes)
10      8     float64   timestamp (Unix epoch seconds)
18      N     bytes     PCM audio data (int16 little-endian)
```

### End-of-Speech Marker (tag = 0x03)

```
Offset  Size  Type      Field
0       1     uint8     tag (0x03)
```

---

## Audio Input Requirements

bitHuman expects audio in this exact format:

| Property | Value |
|----------|-------|
| Sample rate | 16,000 Hz |
| Channels | 1 (mono) |
| Bit depth | 16-bit signed integer |
| Byte order | Little-endian |
| Recommended chunk size | ~100 ms (1600 samples = 3200 bytes) |

The Java client automatically converts WAV files to this format using
`javax.sound.sampled`. For other formats (MP3, OGG), you can add the
appropriate Java SPI library to the classpath, or pre-convert with `ffmpeg`.

---

## Video Output

| Property | Value |
|----------|-------|
| Codec | JPEG (quality 80) |
| Frame rate | 25 FPS |
| Resolution | Model-dependent (e.g. 1280x2270) |
| Typical frame size | ~150-200 KB |
| End-to-end latency | ~200-500 ms from audio input to video output |

---

## Extending the Example

### Real-Time Microphone Input

Replace the file-reading loop with `TargetDataLine` for live audio:

```java
AudioFormat format = new AudioFormat(16000, 16, 1, true, false);
TargetDataLine mic = AudioSystem.getTargetDataLine(format);
mic.open(format);
mic.start();

byte[] buf = new byte[3200]; // 100 ms
while (mic.isOpen() && connected.get()) {
    int read = mic.read(buf, 0, buf.length);
    ws.send(Arrays.copyOf(buf, read));
}
sendJson("end");
```

### Audio Playback

Play the avatar's audio output through speakers:

```java
AudioFormat format = new AudioFormat(16000, 16, 1, true, false);
SourceDataLine speaker = AudioSystem.getSourceDataLine(format);
speaker.open(format, 16000); // 0.5s buffer
speaker.start();

// In onAudioChunk():
speaker.write(pcmData, 0, pcmData.length);
```

### Live Video Display with Swing

```java
JFrame window = new JFrame("bitHuman Avatar");
JLabel imageLabel = new JLabel();
window.add(imageLabel);
window.setSize(640, 1136);
window.setVisible(true);

// In onVideoFrame():
BufferedImage img = ImageIO.read(new ByteArrayInputStream(jpegData));
SwingUtilities.invokeLater(() -> {
    imageLabel.setIcon(new ImageIcon(img.getScaledInstance(640, 1136, Image.SCALE_FAST)));
    window.repaint();
});
```

### Spring Boot Integration

```java
@Service
public class AvatarService {
    private WebSocketClient ws;

    @PostConstruct
    void connect() throws Exception {
        ws = new AvatarWebSocket(URI.create("ws://avatar-server:8765"));
        ws.connectBlocking(10, TimeUnit.SECONDS);
    }

    /** Stream TTS audio to the avatar and collect video frames. */
    public List<byte[]> generateVideo(byte[] pcmAudio16kMono) throws Exception {
        List<byte[]> frames = new CopyOnWriteArrayList<>();

        // Register frame callback (adapt from the example's onVideoFrame)
        // ...

        // Stream audio in 100ms chunks
        for (int i = 0; i < pcmAudio16kMono.length; i += 3200) {
            int end = Math.min(i + 3200, pcmAudio16kMono.length);
            ws.send(Arrays.copyOfRange(pcmAudio16kMono, i, end));
            Thread.sleep(100);
        }
        ws.send("{\"type\":\"end\"}");

        // Wait for end-of-speech, then return frames
        // ...
        return frames;
    }
}
```

### Encoding Video Frames to MP4

After saving frames, stitch them into a video with `ffmpeg`:

```bash
ffmpeg -framerate 25 -i frames/frame_%06d.jpg -c:v libx264 -pix_fmt yuv420p output.mp4
```

---

## Troubleshooting

| Symptom | Cause | Solution |
|---------|-------|----------|
| `Failed to connect to server` | Server not running or wrong port | Verify the server is running and the URL is correct |
| `Connection refused` | Firewall blocking the port | Open port 8765 (or whichever you configured) |
| No video frames received | No audio being sent | The avatar is idle until it receives audio. Check audio file path. |
| `UnsupportedAudioFileException` | Unsupported WAV codec | Convert with: `ffmpeg -i input.mp3 -ar 16000 -ac 1 -sample_fmt s16 output.wav` |
| Garbled/corrupted frames | Network packet loss (rare over TCP) | Check server logs for errors. Ensure WebSocket message size limit is sufficient. |
| High latency | Network distance or slow model | Run server close to client. CPU-only mode is slower than GPU. |
| `Model path required` | Missing `--model` argument | Pass `--model /path/to/avatar.imx` or set `BITHUMAN_MODEL_PATH` env |
| `API secret or token required` | Missing credentials | Pass `--api-secret sk_bh_xxx` or set `BITHUMAN_API_SECRET` env |
| Server exits immediately | Invalid model or credentials | Check the server logs for authentication or model loading errors |

---

## Project Structure

```
public-java-example/
├── bithuman_streaming_server.py                       # Python server (wraps bitHuman SDK)
├── pom.xml                                            # Maven build config
├── README.md                                          # This file
└── src/main/java/ai/bithuman/example/
    └── BithumanStreamingClient.java                   # Java WebSocket client
```

## Dependencies

**Python server:**
- `bithuman` (bitHuman SDK)
- `websockets`
- `opencv-python-headless`
- `loguru`

**Java client:**
- `org.java-websocket:Java-WebSocket:1.5.7` (WebSocket client)
- `com.google.code.gson:gson:2.11.0` (JSON parsing)
- `org.slf4j:slf4j-simple:2.0.16` (logging)

All Java dependencies are bundled into the fat JAR by `maven-shade-plugin`.

---

## License

This example is provided as part of the bitHuman platform documentation.
See https://bithuman.ai for terms of use.
