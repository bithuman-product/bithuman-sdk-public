// Internal: load each TTS backend end-to-end and run a fixed
// utterance, so the vendored MLXAudioTTS path can be sanity-
// checked from a Mac without needing a mic / interactive shell.
//
// Sibling of CompareDiT (avatar) and CompareLLM (LLM).
import Foundation
@preconcurrency import MLX
@preconcurrency import MLXAudioTTS
@preconcurrency import MLXLMCommon

private let helpText = """
compare-tts — load each TTS backend end-to-end and run a fixed
utterance, so the vendored MLXAudioTTS path can be sanity-checked
from a Mac without needing a mic / interactive shell.

Backends exercised:
  Kokoro     mlx-community/Kokoro-82M-4bit         (preset voices)
  Qwen3-TTS  mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit  (cloning)

Usage:
  compare-tts            # run both backends
  compare-tts -h | --help   # this help

Models download into ~/.cache/huggingface/hub on first run. Reports
load time, gen time, RTF, |mean| and peak amplitude per backend.
"""

@main
struct CompareTTS {
    static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.contains("-h") || args.contains("--help") {
            print(helpText)
            return
        }
        let text = "Hello, this is a smoke test of the vendored speech pipeline."
        let cases: [(label: String, repo: String, voice: String?)] = [
            ("Kokoro", "mlx-community/Kokoro-82M-4bit", "af_heart"),
            ("Qwen3-TTS", "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit", "Aiden"),
        ]

        var failed = 0
        for c in cases {
            let t0 = Date()
            print("→ \(c.label) (\(c.repo))")
            do {
                let model = try await TTS.loadModel(modelRepo: c.repo)
                let loadSec = Date().timeIntervalSince(t0)

                let tGen = Date()
                let pcm = try await model.generate(
                    text: text,
                    voice: c.voice,
                    refAudio: nil,
                    refText: nil,
                    language: nil
                )
                let genSec = Date().timeIntervalSince(tGen)

                let samples = pcm.size
                let durationSec = Double(samples) / Double(model.sampleRate)
                let absMean = MLX.mean(MLX.abs(pcm)).item(Float.self)
                let peak = MLX.max(MLX.abs(pcm)).item(Float.self)
                let rtf = genSec / max(durationSec, 0.001)
                let ok = absMean > 0.001 && peak > 0.05 && durationSec > 0.5
                print(String(format: "  load %.1fs · gen %.2fs · %d samples @ %d Hz = %.2fs · RTF %.2fx · |mean| %.4f peak %.3f · %@",
                             loadSec, genSec, samples, model.sampleRate, durationSec, rtf, absMean, peak,
                             ok ? "PASS" : "FAIL"))
                if !ok { failed += 1 }
            } catch {
                print("  ERROR: \(error.localizedDescription)")
                failed += 1
            }
        }
        if failed > 0 {
            print("\n\(failed)/\(cases.count) failed")
            exit(1)
        }
        print("\nall \(cases.count) backends OK")
    }
}
