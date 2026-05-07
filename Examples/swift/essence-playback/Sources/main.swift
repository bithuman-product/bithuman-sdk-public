// EssencePlayback -- Essence avatar model on macOS / iPad.
//
// Demonstrates Bithuman.createRuntime(modelPath:) which returns
// .essence(EssenceRuntime). Shows pushAudio() for lip sync and
// frames() AsyncStream for rendering.
//
// Requires:
//   - A .imx model file (build one at bithuman.ai -> Agents -> New Agent -> Essence)
//   - BITHUMAN_API_KEY environment variable (1 cr/min for Essence)
//
// Run:
//   export BITHUMAN_API_KEY="your-key-here"
//   swift run EssencePlayback /path/to/agent.imx

import Foundation
import SwiftUI
import bitHumanKit

@main
struct EssencePlaybackApp: App {
    @StateObject private var lifecycle = EssenceLifecycle()

    var body: some Scene {
        WindowGroup {
            EssenceContentView(lifecycle: lifecycle)
                .task { await lifecycle.start() }
            #if os(macOS)
                .frame(minWidth: 800, minHeight: 600)
            #endif
        }
    }
}

// MARK: - Lifecycle

@MainActor
final class EssenceLifecycle: ObservableObject {
    @Published var phase: BootPhase = .idle
    @Published var currentFrame: CGImage?

    private var essence: EssenceRuntime?
    private var resolution: CGSize = .zero

    enum BootPhase: Equatable {
        case idle
        case loading
        case live
        case error(String)
    }

    func start() async {
        // Resolve the .imx path from the first command-line argument,
        // falling back to a well-known location for development.
        let imxPath: String
        if CommandLine.arguments.count > 1 {
            imxPath = CommandLine.arguments[1]
        } else {
            // Default location -- adjust for your project.
            imxPath = NSHomeDirectory() + "/.cache/bithuman/essence/agent.imx"
        }

        let imxURL = URL(fileURLWithPath: imxPath)
        guard FileManager.default.fileExists(atPath: imxPath) else {
            phase = .error("Model file not found at \(imxPath). Pass the .imx path as the first argument.")
            return
        }

        do {
            phase = .loading

            // Bithuman.createRuntime inspects the file and returns
            // the matching runtime variant.
            let runtime = try await Bithuman.createRuntime(modelPath: imxURL)

            switch runtime {
            case .essence(let essence):
                self.essence = essence
                self.resolution = essence.resolution

                // Start consuming the frame stream. Each frame is a
                // full-resolution CGImage. A nil element means "show
                // the idle frame" -- keep the last good image on screen.
                Task {
                    for await frame in essence.frames() {
                        await MainActor.run {
                            if let frame = frame {
                                self.currentFrame = frame
                            }
                            // On nil: keep the previous frame displayed.
                        }
                    }
                }

                phase = .live

            case .expression:
                phase = .error("Expected an Essence .imx file but got Expression weights. Use the macos-avatar example for Expression.")
            }
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    /// Feed audio into the Essence runtime for lip sync.
    /// In a real app, pipe 16 kHz mono PCM from your TTS or
    /// microphone capture here.
    func pushAudio(_ pcmData: Data) async {
        do {
            try await essence?.pushAudio(pcmData)
        } catch {
            phase = .error("pushAudio failed: \(error.localizedDescription)")
        }
    }

    func stop() async {
        await essence?.stop()
    }
}

// MARK: - UI

struct EssenceContentView: View {
    @ObservedObject var lifecycle: EssenceLifecycle

    var body: some View {
        VStack(spacing: 16) {
            Text("bitHuman Essence Playback")
                .font(.title)

            switch lifecycle.phase {
            case .idle:
                Text("initialising...")
                    .foregroundColor(.secondary)
            case .loading:
                ProgressView("Loading .imx model...")
            case .live:
                if let frame = lifecycle.currentFrame {
                    #if os(macOS)
                    Image(nsImage: nsImage(from: frame))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 720)
                    #else
                    Image(uiImage: UIImage(cgImage: frame))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 720)
                    #endif
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(maxWidth: 720)
                        .overlay(
                            Text("Waiting for frames...")
                                .foregroundColor(.white)
                        )
                }
                Text("live -- feed audio via pushAudio() for lip sync")
                    .font(.caption)
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

// MARK: - Helpers

#if os(macOS)
import AppKit

/// Convert a CGImage to NSImage for SwiftUI on macOS.
func nsImage(from cgImage: CGImage) -> NSImage {
    NSImage(cgImage: cgImage, size: NSSize(
        width: cgImage.width,
        height: cgImage.height
    ))
}
#endif
