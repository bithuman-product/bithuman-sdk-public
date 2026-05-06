# bitHumanKit

Public Swift Package for [bitHumanKit](https://docs.bithuman.ai/swift-sdk/overview) — bitHuman's on-device voice + lip-synced avatar SDK for Apple Silicon.

This package wraps the pre-compiled `bitHumanKit.xcframework` (attached to this repo's [Releases](https://github.com/bithuman-product/bithuman-sdk-public/releases)) via a SwiftPM `binaryTarget`. The source is private. Every third-party dep (MLX, HuggingFace, Tokenizers, …) is statically linked into the framework binary, so consumers add this single package and have **zero** transitive Swift Package dependencies.

## Install

In Xcode: **File → Add Package Dependencies →**

```
https://github.com/bithuman-product/bithuman-sdk-public.git
```

Or in `Package.swift`:

```swift
.package(url: "https://github.com/bithuman-product/bithuman-sdk-public.git", from: "0.8.1")
```

Then:

```swift
import bitHumanKit
```

## Hardware floor

Runtime-gated via `HardwareCheck.evaluate()`:

| Platform | Minimum |
|---|---|
| macOS | M3+ Apple Silicon, macOS 26 (Tahoe) |
| iPad | iPad Pro M4+, 16 GB unified memory, iPadOS 26 |
| iPhone | iPhone 16 Pro+ (A18 Pro), iOS 26 |

## Documentation

All public documentation lives at **[docs.bithuman.ai](https://docs.bithuman.ai/swift-sdk/overview)**:

- [10-min quickstart](https://docs.bithuman.ai/swift-sdk/quickstart)
- [macOS deployment guide](https://docs.bithuman.ai/swift-sdk/macos)
- [iOS / iPadOS deployment guide](https://docs.bithuman.ai/swift-sdk/ios)
- [bithuman-cli](https://docs.bithuman.ai/swift-sdk/cli) (no-code Mac tool)
- [Troubleshooting](https://docs.bithuman.ai/swift-sdk/troubleshooting)
- [Pricing & credits](https://docs.bithuman.ai/getting-started/pricing)
- [Authentication](https://docs.bithuman.ai/getting-started/authentication)

Reference apps (full annotated source for Mac, iPad, iPhone): bithuman-product/bithuman-apps.

## Get an API key

The avatar pipeline is metered (2 credits/min). Audio-only mode is unmetered.

Sign in at <https://www.bithuman.ai> → Developer → API Keys, then either set `VoiceChatConfig.apiKey` or export `BITHUMAN_API_KEY` before `chat.start()`. See [docs.bithuman.ai/getting-started/authentication](https://docs.bithuman.ai/getting-started/authentication) for the full flow.

## Versioning

Tags follow SemVer. Each tag points at a release that publishes a matching `bitHumanKit.xcframework.zip` artifact on the [Releases](https://github.com/bithuman-product/bithuman-sdk-public/releases) page.

## Issues & feedback

File issues at <https://github.com/bithuman-product/bithuman-sdk-public/issues>.

## License

Binary distribution. Use is governed by the [bitHuman Terms of Service](https://www.bithuman.ai/terms). Model weights are proprietary and downloaded at runtime from authenticated endpoints.
