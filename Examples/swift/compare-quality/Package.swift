// swift-tools-version: 6.0

import PackageDescription

// CompareQuality — render a WAV through the avatar engine to a lip-synced
// MP4, to A/B fp16 vs int4 animator quality. Targets the Layer-1 Expression
// avatar engine directly (the `Expression` product), so it pulls in the
// renderer without the STT/LLM/TTS umbrella. See README.md.
let package = Package(
    name: "CompareQuality",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [
        .package(name: "bithuman",
                 url: "https://github.com/bithuman-product/bithuman-sdk-public.git",
                 from: "0.8.1")
    ],
    targets: [
        .executableTarget(
            name: "CompareQuality",
            dependencies: [
                .product(name: "Expression", package: "bithuman")
            ],
            path: "Sources/CompareQuality",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
