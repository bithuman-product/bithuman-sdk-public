// MacOSAvatar -- macOS voice agent WITH lip-synced avatar.
//
// Demonstrates ExpressionWeights download, AvatarConfig,
// AvatarCoordinator, FramePump, and AvatarRendererView hosted
// inside SwiftUI via NSViewRepresentable.
//
// Requires: BITHUMAN_API_KEY environment variable (2 cr/min).
//   export BITHUMAN_API_KEY="your-key-here"
//   swift run MacOSAvatar
//
// Stop: Ctrl-C or close the window.

import AppKit
import Foundation
import SwiftUI
import bitHumanKit

@main
struct MacOSAvatarApp: App {
    @StateObject private var lifecycle = AvatarLifecycle()

    var body: some Scene {
        WindowGroup {
            AvatarContentView(lifecycle: lifecycle)
                .task { await lifecycle.start() }
                .frame(minWidth: 400, minHeight: 480)
        }
    }
}

// MARK: - Lifecycle

@MainActor
final class AvatarLifecycle: ObservableObject {
    @Published var phase: BootPhase = .idle
    @Published private(set) var renderer: AvatarRendererView?

    private var chat: VoiceChat?
    private var coordinator: AvatarCoordinator?
    private var pump: FramePump?

    enum BootPhase: Equatable {
        case idle
        case downloading(Double)   // 0...1
        case warming
        case live
        case error(String)
    }

    func start() async {
        do {
            // 1. Download / verify the universal Expression weights bundle.
            //    First launch pulls ~1.6 GB (SHA-256 verified, then cached).
            phase = .downloading(0)
            let weights = try await ExpressionWeights.ensureAvailable { event in
                Task { @MainActor in
                    if case .downloading(let fraction, _, _, _, _) = event {
                        self.phase = .downloading(fraction)
                    }
                }
            }
            phase = .warming

            // 2. Pick a bundled agent for the first run.
            let agent = AgentCatalog.defaultAgent
            let portrait = AgentCatalog.thumbnailURL(for: agent)!

            // 3. Configure voice chat with avatar.
            var config = VoiceChatConfig()
            config.systemPrompt = agent.systemPrompt
            config.avatar = AvatarConfig(modelPath: weights, portraitPath: portrait)
            config.apiKey = ProcessInfo.processInfo.environment["BITHUMAN_API_KEY"]

            let chat = VoiceChat(config: config)
            try await chat.start()  // throws .missingAPIKey / .authenticationFailed
            await chat.setVoicePreset(agent.voicePreset)

            // 4. Bind the coordinator and render stack.
            guard let bh = chat.bithuman else {
                phase = .error("avatar engine failed to initialise")
                return
            }

            let coord = AvatarCoordinator(chat: chat)
            coord.bindToOrchestrator()
            coord.prewarmPortraitURL = portrait
            coord.currentAgentCode = agent.code

            let renderer = AvatarRendererView(
                frame: .zero, idleFrame: chat.initialIdleFrame, clipMode: .circle)
            let pump = FramePump(
                bithuman: bh, chat: chat, window: renderer, coordinator: coord)
            coord.framePump = pump
            chat.onBargeIn = { [weak pump] in pump?.buffer.flushSpeech() }

            // 5. Hold strong references so SwiftUI does not deinit them
            //    during view re-renders.
            self.chat = chat
            self.coordinator = coord
            self.pump = pump
            self.renderer = renderer
            self.phase = .live
        } catch {
            phase = .error(error.localizedDescription)
        }
    }
}

// MARK: - NSViewRepresentable host for AvatarRendererView

struct AvatarHost: NSViewRepresentable {
    let view: AvatarRendererView

    func makeNSView(context: Context) -> AvatarRendererView { view }
    func updateNSView(_ nsView: AvatarRendererView, context: Context) {}
}

// MARK: - UI

struct AvatarContentView: View {
    @ObservedObject var lifecycle: AvatarLifecycle

    var body: some View {
        VStack(spacing: 16) {
            Text("bitHuman Avatar Agent")
                .font(.title)

            switch lifecycle.phase {
            case .idle:
                Text("initialising...")
                    .foregroundColor(.secondary)
            case .downloading(let progress):
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .frame(width: 200)
                    Text("Downloading weights: \(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            case .warming:
                ProgressView("Warming up the model...")
            case .live:
                if let renderer = lifecycle.renderer {
                    AvatarHost(view: renderer)
                        .frame(width: 280, height: 280)
                        .clipShape(Circle())
                }
                Text("live -- talk to me")
                    .font(.title3)
                    .foregroundColor(.green)
            case .error(let message):
                Text("Error: \(message)")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(32)
    }
}
