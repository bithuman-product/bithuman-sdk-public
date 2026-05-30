// swift-tools-version: 6.0

import PackageDescription

// CompareTTS — load each TTS backend (Kokoro, Qwen3-TTS) and synthesize
// a fixed utterance, to sanity-check the vendored MLXAudioTTS path from
// a Mac without a mic.
//
// PRIVATE-SOURCE DEPENDENCY: this tool imports `MLXAudioTTS`, which is
// re-exported by the `Voice` product of the bithuman-sdk `voice/`
// package (the vendored Blaizzy/mlx-audio-swift TTS stack). That stack
// is NOT part of the public binary distribution, so this example cannot
// build against the published SwiftPM package alone — it needs the
// private monorepo `bithuman-product/bithuman-sdk` cloned as a SIBLING
// of this repo:
//
//     ~/code/bithuman-sdk          (private; collaborator access)
//     ~/code/bithuman-sdk-public   (this repo)
//
// The path dep below resolves voice/ via that sibling layout. External
// developers without private access should use the `Voice` API through
// the `bitHumanKit` umbrella binary instead of this dev harness. See
// README.md.
let package = Package(
    name: "CompareTTS",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMinor(from: "0.31.3")),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", from: "3.31.3"),
        // Private-source path dep — see the header note. Resolves the
        // `voice/` SwiftPM package (product "Voice") via the sibling
        // bithuman-sdk checkout.
        .package(name: "voice", path: "../../../../bithuman-sdk/voice"),
    ],
    targets: [
        .executableTarget(
            name: "CompareTTS",
            dependencies: [
                .product(name: "Voice", package: "voice"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ],
            path: "Sources/CompareTTS",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
