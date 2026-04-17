// swift-tools-version:6.0
import PackageDescription

// BithumanSwiftExample — a minimal, self-contained example of
// bitHuman's Swift SDK. Loads model weights, feeds a synthetic
// audio signal, and writes the rendered avatar frames + paired
// audio slices to disk as a side-by-side WAV/PNG sequence.
//
// Requirements: macOS 14+, Apple Silicon M3+, 16 GB RAM,
// Xcode 16.3+. See README.md for the weight-setup walkthrough.

let package = Package(
    name: "BithumanSwiftExample",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // Pin to the latest published tag. The SDK is distributed as
        // source via GitHub; subsequent releases add CVPixelBuffer
        // zero-copy output and an AsyncThrowingStream run() API.
        .package(url: "https://github.com/bithuman-product/bithuman-expression-swift.git", from: "0.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "BithumanSwiftExample",
            dependencies: [
                .product(name: "BithumanAvatar", package: "bithuman-expression-swift"),
            ],
            swiftSettings: [
                // BithumanAvatar pins Swift 5 language mode (some
                // low-level types aren't Sendable yet). Match to keep
                // strict-concurrency checks as warnings.
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
