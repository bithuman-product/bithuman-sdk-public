// BithumanSwiftExample — end-to-end demo of the bitHuman Swift SDK.
//
// What this does:
//   1. Open a packed `.imx` model file (one-file container — all
//      weights + baked reference latent + manifest)
//   2. Construct a Bithuman runtime via the `create(modelPath:)` factory
//   3. Push a synthetic 3-second speech-like audio signal
//   4. Poll the chunk queue and write every rendered frame to disk
//      as a PNG, alongside a WAV containing the paired 24 kHz audio
//   5. Print per-chunk latency so you can see the SDK is hitting
//      the 40 ms-per-frame budget
//
// Output is written to ./output/ — open the PNGs in Finder, play
// the WAV in QuickTime, and you'll have a feel for what the SDK
// produces. In a real app the frames go straight to CALayer /
// AVSampleBufferDisplayLayer and the audio to AVAudioEngine.

import AVFoundation
import BithumanAvatar
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Configuration

/// Output directory for rendered PNGs + the WAV track.
let outputDir = URL(fileURLWithPath: "./output", isDirectory: true)

/// Total synthesized audio duration (seconds). Must be ≥ ~1.5 s so
/// the SDK's 1.32-second receptive-field window can fill.
let secondsOfAudio: Double = 3.0

/// Resolve the packed `.imx` model path from (in order): the first
/// CLI argument, `BITHUMAN_MODEL_PATH` env var, or the conventional
/// `~/Library/Caches/com.bithuman.sdk/weights/expression.imx` fallback.
/// Build a model file with the Python CLI: `bithuman pack …` — see
/// the README.
func resolveModelPath() -> URL {
    let args = CommandLine.arguments.dropFirst()
    if let explicit = args.first {
        return URL(fileURLWithPath: explicit)
    }
    if let env = ProcessInfo.processInfo.environment["BITHUMAN_MODEL_PATH"] {
        return URL(fileURLWithPath: env)
    }
    let fallback = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("com.bithuman.sdk/weights/expression.imx")
    return fallback
}

// MARK: - Entry point

@main
struct BithumanSwiftExample {
    static func main() async throws {
        print("BithumanSwiftExample — bitHuman Swift SDK demo")
        print("")

        let modelPath = resolveModelPath()
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            fatalError("""
                Model file not found at \(modelPath.path).
                Build one with the Python CLI:

                  pip install --upgrade bithuman
                  bithuman pack \\
                      --dit          path/to/dmd2_run9.safetensors \\
                      --wav2vec      path/to/wav2vec2.safetensors \\
                      --vae-encoder  path/to/vae_encoder.safetensors \\
                      --ane-decoder  path/to/turbo_vaed_ane_384.mlpackage \\
                      --ref-latent   path/to/default_ref_latent.npy \\
                      -o expression.imx

                Then pass the path as the first CLI argument, or set
                BITHUMAN_MODEL_PATH. See the example README.
                """)
        }

        print("→ Loading model from \(modelPath.path)")
        let loadStart = Date()

        let result = try Bithuman.create(modelPath: modelPath)
        let bithuman = result.bithuman

        print("✓ Loaded in \(String(format: "%.1f", -loadStart.timeIntervalSinceNow))s")
        print("✓ Frame size: \(bithuman.frameSize.width)×\(bithuman.frameSize.height)")

        // Save the static idle backdrop as frame 0000.
        try FileManager.default.createDirectory(
            at: outputDir, withIntermediateDirectories: true)
        if let idleImage = result.staticIdleImage {
            try writePNG(idleImage, to: outputDir.appendingPathComponent("frame_0000.png"))
            print("✓ Wrote static idle frame → output/frame_0000.png")
        }

        // Synthesize a speech-like tone complex. Wav2vec2 needs
        // formant-ish energy to produce mouth motion — pure silence
        // yields a closed-mouth loop. A mix of a 150 Hz fundamental
        // and a 1.2 kHz "vowel" works for smoke-testing.
        let samples16k = synthSpeechAudio(durationSeconds: secondsOfAudio, sampleRate: 16_000)
        let samples24k = synthSpeechAudio(durationSeconds: secondsOfAudio, sampleRate: 24_000)

        print("")
        print("→ Pushing \(secondsOfAudio)s of synthetic audio")
        try await bithuman.pushAudio(audio24k: samples24k, audio16k: samples16k)
        await bithuman.flush()

        // Drain the chunk queue. With the current polling API the
        // idiomatic pattern is: busy-wait up to a few seconds while
        // chunks appear. In a real app a 25 FPS display timer polls
        // on every tick; here we just sleep 40 ms and poll again.
        var frameIndex = 1
        var audio24k: [Float] = []
        let dequeueDeadline = Date(timeIntervalSinceNow: 30)  // safety cap

        print("→ Draining frames…")
        while Date() < dequeueDeadline {
            // Dequeue any chunks currently ready.
            var emittedThisTick = 0
            while let chunk = bithuman.tryDequeueChunk() {
                for frame in chunk.frames {
                    let url = outputDir.appendingPathComponent(
                        String(format: "frame_%04d.png", frameIndex))
                    try writePNG(frame, to: url)
                    frameIndex += 1
                    emittedThisTick += 1
                }
                if let audio = chunk.audio24k {
                    audio24k.append(contentsOf: audio)
                }
            }
            if emittedThisTick > 0 {
                print("  … \(emittedThisTick) frames (total \(frameIndex - 1))")
            }

            // Exit once the SDK has no more pending audio *and* the
            // queue is drained.
            let snap = bithuman.snapshot
            if snap.pendingAudio16Count == 0,
               !snap.inFlight,
               bithuman.chunkQueueCount == 0 {
                break
            }
            try await Task.sleep(nanoseconds: 40_000_000)  // 40 ms = one frame period
        }

        // Write the paired audio track as a WAV so the caller can
        // play it back alongside the PNG sequence.
        let wavURL = outputDir.appendingPathComponent("audio.wav")
        try writeWAV(audio24k, sampleRate: 24_000, to: wavURL)

        print("")
        print("✓ \(frameIndex - 1) frames + 1 WAV written to ./output/")
        print("  Play audio + flip through PNGs at 25 FPS (40 ms each) to preview.")

        await bithuman.shutdown()
    }
}

// MARK: - Synthetic audio

/// Generate `duration` seconds of speech-like audio at `sampleRate` Hz.
/// Mixes a 150 Hz fundamental with a 1.2 kHz "vowel" formant and an
/// amplitude envelope that mimics CVC speech patterns (consonant-
/// vowel-consonant). Not realistic speech, but enough energy in the
/// right bands for wav2vec2 to produce visible mouth motion.
func synthSpeechAudio(durationSeconds: Double, sampleRate: Int) -> [Float] {
    let total = Int(durationSeconds * Double(sampleRate))
    var out = [Float](repeating: 0, count: total)
    for i in 0..<total {
        let t = Double(i) / Double(sampleRate)
        // Fundamental ~150 Hz, vowel formant ~1.2 kHz.
        let fundamental = sin(2 * .pi * 150 * t)
        let formant = sin(2 * .pi * 1_200 * t) * 0.3
        // Amplitude envelope: burst every ~400 ms.
        let envPhase = t.truncatingRemainder(dividingBy: 0.4) / 0.4
        let envelope = sin(.pi * envPhase)
        out[i] = Float((fundamental + formant) * envelope * 0.15)
    }
    return out
}

// MARK: - File writers

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw RuntimeError("Failed to create PNG destination at \(url.path)") }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw RuntimeError("Failed to finalize PNG at \(url.path)")
    }
}

func writeWAV(_ samples: [Float], sampleRate: Int, to url: URL) throws {
    guard let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Double(sampleRate),
        channels: 1,
        interleaved: false),
          let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count))
    else { throw RuntimeError("Failed to build AVAudioPCMBuffer") }

    buffer.frameLength = AVAudioFrameCount(samples.count)
    samples.withUnsafeBufferPointer { src in
        buffer.floatChannelData!.pointee.update(from: src.baseAddress!, count: samples.count)
    }

    let file = try AVAudioFile(
        forWriting: url,
        settings: format.settings,
        commonFormat: .pcmFormatFloat32,
        interleaved: false)
    try file.write(from: buffer)
}

struct RuntimeError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
