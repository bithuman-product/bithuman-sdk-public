// swift-tools-version: 6.0

import PackageDescription

// HelloVoiceChat — the minimum it takes to embed bitHumanKit into an
// SPM-built macOS executable: a voice agent with no avatar and no
// billing. See README.md to run.
let package = Package(
    name: "HelloVoiceChat",
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
            name: "HelloVoiceChat",
            dependencies: [
                .product(name: "bitHumanKit", package: "bithuman")
            ],
            path: "Sources/HelloVoiceChat",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
