// CompareLLM — load each LLM choice and run a fixed avatar-style
// prompt set, so the iOS-vs-macOS LLM split can be sanity-checked
// from a Mac. Mirrors LLMClient's load/install path (direct factory
// call, same generation params) so what we measure here is what
// ships in production.
//
// Usage:
//   compare-llm                  # both models, 4 prompts
//   compare-llm --model ios      # iOS choice only (Gemma 3 1B QAT)
//   compare-llm --model macos    # macOS choice only (Gemma 3n E2B)

import Foundation
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers
import HuggingFace

let avatarInstructions = """
You are a friendly voice assistant inside a small avatar app. \
Reply in 1-2 short sentences. Be warm, natural, conversational. \
No bullet lists.
"""

let promptSet: [String] = [
    "Hi! What can you do?",
    "I just got back from a long day at work. Any quick way to relax?",
    "I am trying to learn Spanish. Can you teach me one useful phrase?",
    "What's a fun fact about octopuses?",
]

enum Choice: String {
    case ios, macos, both
}

private let helpText = """
compare-llm — sanity-check the iOS-vs-macOS LLM split from a Mac.

Loads each LLM choice (or both) and runs a fixed 4-prompt avatar-
style prompt set, so what we measure here is what ships in production.

Usage:
  compare-llm                  # both models, 4 prompts
  compare-llm --model ios      # iOS choice only (Gemma 3 1B QAT)
  compare-llm --model macos    # macOS choice only (Gemma 3n E2B)
  compare-llm -h | --help      # this help

Models are downloaded into the standard ~/.cache/huggingface/hub
cache on first run.
"""

func parseChoice() -> Choice {
    let args = Array(CommandLine.arguments.dropFirst())
    if args.contains("-h") || args.contains("--help") {
        print(helpText)
        exit(0)
    }
    var i = 0
    while i < args.count {
        if args[i] == "--model" || args[i] == "-m" {
            guard i + 1 < args.count else { break }
            return Choice(rawValue: args[i + 1].lowercased()) ?? .both
        }
        i += 1
    }
    return .both
}

func loadContainer(_ config: ModelConfiguration) async throws -> ModelContainer {
    try await LLMModelFactory.shared.loadContainer(
        from: #hubDownloader(),
        using: #huggingFaceTokenizerLoader(),
        configuration: config,
        progressHandler: { progress in
            let pct = Int(progress.fractionCompleted * 100)
            if pct % 10 == 0 {
                FileHandle.standardError.write(Data("  download: \(pct)%\r".utf8))
            }
        }
    )
}

func runPrompts(label: String, container: ModelContainer) async {
    let session = ChatSession(
        container,
        instructions: avatarInstructions,
        generateParameters: GenerateParameters(
            maxTokens: 300,
            temperature: 0.7,
            topP: 0.95,
            repetitionPenalty: 1.1
        )
    )
    print("\n=== \(label) ===\n")
    for prompt in promptSet {
        print("USER: \(prompt)")
        let start = Date()
        var response = ""
        do {
            for try await chunk in session.streamResponse(to: prompt) {
                response += chunk
            }
        } catch {
            print("BOT (error): \(error)")
            continue
        }
        let elapsed = Date().timeIntervalSince(start)
        print("BOT (\(String(format: "%.1f", elapsed))s): \(response.trimmingCharacters(in: .whitespacesAndNewlines))")
        print("")
    }
}

@main
struct CompareLLM {
    static func main() async {
        let choice = parseChoice()
        do {
            if choice == .ios || choice == .both {
                print("Loading iOS choice (Gemma 3 1B QAT 4-bit)…")
                let c = try await loadContainer(LLMRegistry.gemma3_1B_qat_4bit)
                await runPrompts(label: "iOS — Gemma 3 1B QAT 4-bit", container: c)
            }
            if choice == .macos || choice == .both {
                print("Loading macOS choice (Gemma 3n E2B 4-bit)…")
                let c = try await loadContainer(LLMRegistry.gemma4_e2b_it_4bit)
                await runPrompts(label: "macOS — Gemma 3n E2B 4-bit", container: c)
            }
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }
}
