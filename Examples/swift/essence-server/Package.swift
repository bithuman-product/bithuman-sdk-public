// swift-tools-version: 6.0

import PackageDescription

// EssenceServer — a native Swift LiveKit avatar service. Hosts N
// EssenceRuntime instances behind an HTTP /launch endpoint, joins
// LiveKit rooms as a participant, and streams lip-synced video + audio
// back. Drop-in for the Python essence-avatar pool. See ARCHITECTURE.md
// and README.md.
//
// Beyond the bitHumanKit binary, this example pulls in three public
// SwiftPM deps that are NOT bundled into the framework (they're a server
// concern, not an SDK concern): the bitHuman LiveKit room SDK fork,
// JWTKit (LiveKit token minting), and Hummingbird (the HTTP server).
let package = Package(
    name: "EssenceServer",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [
        .package(name: "bithuman",
                 url: "https://github.com/bithuman-product/bithuman-sdk-public.git",
                 from: "0.8.1"),
        // bitHuman fork of client-sdk-swift carrying a no-device
        // app-audio patch (lets headless server avatars publish audio in
        // manual-render mode without claiming the mic). Drop the fork
        // once livekit/client-sdk-swift#985 merges + tags.
        .package(url: "https://github.com/bithuman-product/bithuman-livekit-swift", branch: "main"),
        .package(url: "https://github.com/vapor/jwt-kit", from: "5.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "EssenceServer",
            dependencies: [
                .product(name: "bitHumanKit", package: "bithuman"),
                .product(name: "LiveKit", package: "bithuman-livekit-swift"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ],
            path: "Sources/EssenceServer",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                // Embed Info.plist into __TEXT,__info_plist so macOS can
                // surface NSMicrophoneUsageDescription and TCC grants the
                // mic access LiveKit's LocalAudioTrack needs. Path is
                // relative to this package root.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist",
                ]),
            ]
        )
    ]
)
