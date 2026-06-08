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
// RELEASE NOTE (Layer-1 engine products):
//   Only the `bitHumanKit` umbrella slice ships today (v0.8.1) — and it
//   re-exports both the Expression avatar engine and the Essence runtime,
//   so apps get everything via `import bitHumanKit`. The standalone
//   `Expression` and `Bithuman` (Essence) products are NOT yet published:
//   their per-product XCFramework zips + checksums are produced by the
//   release flow (scripts/build-binary-xcframework.sh emits the per-product
//   zips; `swift package compute-checksum <zip>` yields the value). They are
//   omitted from `products`/`targets` below until a release uploads those
//   two zips, so this manifest always resolves cleanly. To re-add them, fill
//   in real checksums and restore the two products/binaryTargets. See
//   scripts/validate-release.sh and docs/RELEASE_MATRIX.md.
import PackageDescription

// Pin the binary slice to a release tag. When the Layer-1 engine products are
// published they should share this tag so a `from:` bump moves them in lockstep.
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
        // NOTE: the standalone `Expression` and `Bithuman` (Essence) Layer-1
        // engine products are not yet published — their per-product XCFramework
        // zips + checksums are produced by the release flow. They are
        // intentionally omitted here until a release uploads them, so the
        // package resolves cleanly. Until then, use `bitHumanKit` (the umbrella
        // product re-exports both engines). See the RELEASE NOTE above.
    ],
    targets: [
        .binaryTarget(
            name: "bitHumanKit",
            url: "\(releaseBase)/bitHumanKit.xcframework.zip",
            checksum: "5c536e37919b693591dff234db8627c01952ae24ae58651aeacbd875bd78e9db"
        ),
    ]
)
