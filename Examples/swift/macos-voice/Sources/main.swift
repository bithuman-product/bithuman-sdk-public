// MacOSVoice -- Minimal macOS voice-only agent (no avatar).
//
// Demonstrates VoiceChat + VoiceChatConfig for an audio-only
// conversational agent. All inference runs on-device: speech
// recognition, LLM, and text-to-speech. No API key required.
//
// Run:  swift run MacOSVoice
// Stop: Ctrl-C or close the window.

import SwiftUI
import bitHumanKit

@main
struct MacOSVoiceApp: App {
    @StateObject private var lifecycle = Lifecycle()

    var body: some Scene {
        WindowGroup {
            ContentView(lifecycle: lifecycle)
                .task { await lifecycle.start() }
                .frame(minWidth: 400, minHeight: 200)
        }
    }
}

// MARK: - Lifecycle

@MainActor
final class Lifecycle: ObservableObject {
    @Published var status = "booting..."
    private var chat: VoiceChat?

    func start() async {
        var config = VoiceChatConfig()
        config.localeIdentifier = "en-US"
        config.systemPrompt = "You are a helpful assistant. One sentence per turn."
        config.voice = .preset("Aiden")

        do {
            let chat = VoiceChat(config: config)
            try await chat.start()
            self.chat = chat
            status = "live -- talk to me"
        } catch {
            status = "error: \(error.localizedDescription)"
        }
    }
}

// MARK: - UI

struct ContentView: View {
    @ObservedObject var lifecycle: Lifecycle

    var body: some View {
        VStack(spacing: 16) {
            Text("bitHuman Voice Agent")
                .font(.title)
            Text(lifecycle.status)
                .font(.title3)
                .foregroundColor(lifecycle.status.hasPrefix("live") ? .green : .secondary)
            Text("Speak into your microphone. The agent listens, thinks, and replies through your speakers.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(32)
    }
}
