// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacOSAvatar",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [
        .package(url: "https://github.com/bithuman-product/bithuman-sdk-public.git",
                 from: "0.8.1")
    ],
    targets: [
        .executableTarget(
            name: "MacOSAvatar",
            dependencies: [
                .product(name: "bitHumanKit", package: "bithuman-sdk-public")
            ],
            path: "Sources"
        )
    ]
)
