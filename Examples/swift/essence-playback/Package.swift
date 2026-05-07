// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EssencePlayback",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0")
    ],
    dependencies: [
        .package(url: "https://github.com/bithuman-product/bithuman-sdk-public.git",
                 from: "0.8.1")
    ],
    targets: [
        .executableTarget(
            name: "EssencePlayback",
            dependencies: [
                .product(name: "bitHumanKit", package: "bithuman-sdk-public")
            ],
            path: "Sources"
        )
    ]
)
