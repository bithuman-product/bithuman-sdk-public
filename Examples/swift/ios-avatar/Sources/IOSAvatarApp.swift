// IOSAvatar -- iOS/iPadOS voice agent with lip-synced avatar.
//
// Demonstrates HardwareCheck.evaluate() gate, UIViewRepresentable
// hosting, and the full avatar pipeline on iOS. Requires memory
// entitlements approved by Apple (see Info.plist and README).
//
// Requires: BITHUMAN_API_KEY set in Xcode scheme environment
//           variables (Product -> Scheme -> Edit Scheme -> Run ->
//           Arguments -> Environment Variables).

import Foundation
import SwiftUI
import UIKit
import bitHumanKit

@main
struct IOSAvatarApp: App {
    var body: some Scene {
        WindowGroup {
            switch HardwareCheck.evaluate() {
            case .supported:
                AvatarRootView()
            case .unsupported(let reason):
                UnsupportedDeviceView(reason: reason)
            }
        }
    }
}

// MARK: - Unsupported device screen

struct UnsupportedDeviceView: View {
    let reason: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Device Not Supported")
                .font(.title)
            Text(reason)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text("This app requires iPhone 16 Pro or later, or iPad Pro M4 or later.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

// MARK: - Avatar root view (hardware is supported)

struct AvatarRootView: View {
    @StateObject private var lifecycle = AvatarLifecycle()

    var body: some View {
        VStack(spacing: 16) {
            Text("bitHuman Avatar")
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
        .task { await lifecycle.start() }
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
        case downloading(Double)
        case warming
        case live
        case error(String)
    }

    func start() async {
        do {
            // 1. Download / verify the Expression weights (~1.6 GB, cached).
            phase = .downloading(0)
            let weights = try await ExpressionWeights.ensureAvailable { event in
                Task { @MainActor in
                    if case .downloading(let fraction, _, _, _, _) = event {
                        self.phase = .downloading(fraction)
                    }
                }
            }
            phase = .warming

            // 2. Pick a bundled agent.
            let agent = AgentCatalog.defaultAgent
            let portrait = AgentCatalog.thumbnailURL(for: agent)!

            // 3. Configure voice chat with avatar.
            var config = VoiceChatConfig()
            config.systemPrompt = agent.systemPrompt
            config.avatar = AvatarConfig(modelPath: weights, portraitPath: portrait)
            config.apiKey = ProcessInfo.processInfo.environment["BITHUMAN_API_KEY"]

            let chat = VoiceChat(config: config)
            try await chat.start()
            await chat.setVoicePreset(agent.voicePreset)

            // 4. Wire up the coordinator and render stack.
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

            // 5. Hold strong references.
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

// MARK: - UIViewRepresentable host for AvatarRendererView

struct AvatarHost: UIViewRepresentable {
    let view: AvatarRendererView

    func makeUIView(context: Context) -> AvatarRendererView { view }
    func updateUIView(_ uiView: AvatarRendererView, context: Context) {}
}
