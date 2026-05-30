// swift-tools-version: 6.0

import PackageDescription

// CompareLLM — load each on-device LLM choice (iOS vs macOS split) and
// run a fixed avatar-style prompt set, to sanity-check the model split
// from a Mac before shipping.
//
// This tool does NOT depend on any bitHuman binary framework: it talks
// to the same upstream OSS packages (mlx-swift-lm, swift-transformers,
// swift-huggingface) that bitHumanKit's LLMClient is built on, with the
// same load/generate path. Pins mirror swift/Package.swift in the
// private monorepo so what we measure here is what ships. See README.md.
let package = Package(
    name: "CompareLLM",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", from: "3.31.3"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "CompareLLM",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
            ],
            path: "Sources/CompareLLM",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
