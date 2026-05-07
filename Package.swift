// swift-tools-version: 6.0
// bitHumanKit — public binary distribution.
//
// The source for bitHumanKit lives in the swift/ tree of the private
// monorepo bithuman-product/bithuman-sdk (formerly the standalone
// bithuman-product/bithuman-kit before the 2026-05-05 consolidation).
// This package consumes the pre-compiled XCFramework attached to
// THIS repo's GitHub Releases via SwiftPM's binaryTarget — the
// `.xcframework.zip` is built from bithuman-sdk and uploaded here
// per release; consumers depend only on this package URL.
//
// All third-party deps (MLX, HuggingFace, Tokenizers, …) are
// statically linked into the framework binary, so consumers
// don't need any transitive Swift Package dependencies. Just
// add this package and `import bitHumanKit`.
//
// Hardware floor (gated at runtime via HardwareCheck.evaluate()):
//   macOS:   M3+ Apple Silicon, macOS 26 (Tahoe)
//   iPad:    iPad Pro M4+, 16 GB unified memory, iPadOS 26
//   iPhone:  iPhone 16 Pro+ (A18 Pro), iOS 26
import PackageDescription

let package = Package(
    name: "bithuman-kit",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0"),
    ],
    products: [
        .library(name: "bitHumanKit", targets: ["bitHumanKit"]),
    ],
    targets: [
        .binaryTarget(
            name: "bitHumanKit",
            url: "https://github.com/bithuman-product/bithuman-sdk-public/releases/download/v0.8.1/bitHumanKit.xcframework.zip",
            checksum: "5c536e37919b693591dff234db8627c01952ae24ae58651aeacbd875bd78e9db"
        ),
    ]
)
