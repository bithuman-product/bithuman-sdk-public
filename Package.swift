// swift-tools-version: 6.0
// bitHumanKit — public binary distribution.
//
// The source for these frameworks lives in the private monorepo
// bithuman-product/bithuman-sdk (the swift/ tree for bitHumanKit; the
// engine/expression/ and sdks/swift/ trees for the two Layer-1 engine
// products extracted on the refactor/engine-tiers branch). This package
// consumes the pre-compiled XCFrameworks attached to THIS repo's GitHub
// Releases via SwiftPM's binaryTarget — each `.xcframework.zip` is built
// from bithuman-sdk and uploaded here per release; consumers depend only
// on this package URL.
//
// All third-party deps (MLX, HuggingFace, Tokenizers, …) are
// statically linked into the framework binaries, so consumers
// don't need any transitive Swift Package dependencies. Just
// add this package and `import bitHumanKit` (or `import Expression`
// / `import Bithuman` for the lower-level engine products).
//
// Products
//   - bitHumanKit  Full on-device voice + video chat SDK (umbrella).
//                  Re-exports the Expression avatar engine + the Essence
//                  (libessence) runtime + the on-device LLM/TTS stack.
//                  Most apps want this one. `import bitHumanKit`.
//   - Expression   Layer-1 avatar engine on its own: Wav2Vec2 → DiT →
//                  VAE → ANE expressive talking head. Built from the
//                  bithuman-sdk engine/expression/ package. Pull this in
//                  directly when you only need the avatar renderer (no
//                  STT/LLM/TTS). Home of the `Bithuman` actor,
//                  `Bithuman.Quality`, `AvatarConfig`, `ImxContainer`.
//                  `import Expression`.
//   - Bithuman     Layer-1 Essence engine on its own: the portable
//                  libessence C++ avatar runtime (audio → composited BGR
//                  frames from a pre-built `.imx`). Built from the
//                  bithuman-sdk sdks/swift/ package. CPU-only, works on
//                  any Apple Silicon. `import Bithuman`.
//
// Hardware floor (gated at runtime via HardwareCheck.evaluate()):
//   macOS:   M3+ Apple Silicon, macOS 26 (Tahoe)
//   iPad:    iPad Pro M4+, 16 GB unified memory, iPadOS 26
//   iPhone:  iPhone 16 Pro+ (A18 Pro), iOS 26
//
// RELEASE NOTE (binaryTarget checksums):
//   The `bitHumanKit` slice ships today (v0.8.1). The `Expression` and
//   `Bithuman` (Essence) slices are wired here against the SAME release
//   tag but their checksums below are PLACEHOLDERS — they must be filled
//   in by the release flow (scripts/build-binary-xcframework.sh emits the
//   per-product zips; `swift package compute-checksum <zip>` yields the
//   value). Until a release uploads those two zips + updates these
//   checksums, only the `bitHumanKit` product resolves. See
//   scripts/validate-release.sh and docs/RELEASE_MATRIX.md.
import PackageDescription

// Pin every binary slice to the same release tag so a `from:` bump moves
// all three products in lockstep.
let releaseTag = "v0.8.1"
let releaseBase = "https://github.com/bithuman-product/bithuman-sdk-public/releases/download/\(releaseTag)"

let package = Package(
    name: "bithuman",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0"),
    ],
    products: [
        .library(name: "bitHumanKit", targets: ["bitHumanKit"]),
        .library(name: "Expression", targets: ["Expression"]),
        .library(name: "Bithuman", targets: ["Bithuman"]),
    ],
    targets: [
        .binaryTarget(
            name: "bitHumanKit",
            url: "\(releaseBase)/bitHumanKit.xcframework.zip",
            checksum: "5c536e37919b693591dff234db8627c01952ae24ae58651aeacbd875bd78e9db"
        ),
        // Layer-1 avatar engine (engine/expression). PLACEHOLDER checksum —
        // filled in by the release flow once Expression.xcframework.zip is
        // built + uploaded to the release tag above.
        .binaryTarget(
            name: "Expression",
            url: "\(releaseBase)/Expression.xcframework.zip",
            checksum: "0000000000000000000000000000000000000000000000000000000000000000"
        ),
        // Layer-1 Essence engine (sdks/swift, libessence). PLACEHOLDER
        // checksum — filled in by the release flow once
        // Bithuman.xcframework.zip is built + uploaded to the release tag.
        .binaryTarget(
            name: "Bithuman",
            url: "\(releaseBase)/Bithuman.xcframework.zip",
            checksum: "0000000000000000000000000000000000000000000000000000000000000000"
        ),
    ]
)
