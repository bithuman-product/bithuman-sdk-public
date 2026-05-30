// swift-tools-version: 6.0

import PackageDescription

// BenchEssence — apples-to-apples Essence runtime perf + correctness
// bench harness. Sibling of the Python bench_essence.py.
//
// NOTE ON THE DEPENDENCY: this harness calls the internal
// `EssenceRuntime.generateFrameDetailedForBench` test seam (per-frame
// `cluster_idx`), which is NOT part of the public `bitHumanKit` /
// `Bithuman` API surface. Against the published binary it will fail to
// compile at that call site. To run the full per-frame correctness path
// you need an internal build of the framework that exposes the seam;
// the public binary only surfaces the rendered frames via `frames()`.
// See README.md.
let package = Package(
    name: "BenchEssence",
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
            name: "BenchEssence",
            dependencies: [
                .product(name: "bitHumanKit", package: "bithuman")
            ],
            path: "Sources/BenchEssence",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
