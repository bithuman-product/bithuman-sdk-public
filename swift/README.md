# bitHumanKit — Swift SDK

![bitHuman Banner](https://docs.bithuman.ai/images/bithuman-banner.jpg)

**On-device voice + lip-synced avatar SDK for Apple Silicon.**

[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://github.com/bithuman-product/bithuman-sdk-public)
[![Platforms](https://img.shields.io/badge/platform-macOS%2026%20%7C%20iOS%2026%20%7C%20iPadOS%2026-lightgrey.svg)]()

`bitHumanKit` is a Swift Package that drops a real-time voice agent — with optional lip-synced avatar — into your Mac, iPad, or iPhone app. All inference runs on the device's GPU and Neural Engine. The avatar engine is metered through a 1-request-per-minute heartbeat to `api.bithuman.ai`; audio-only mode runs unmetered and offline.

## Install

In Xcode: **File → Add Package Dependencies →**

```
https://github.com/bithuman-product/bithuman-sdk-public.git
```

Or in `Package.swift`:

```swift
.package(url: "https://github.com/bithuman-product/bithuman-sdk-public.git", from: "0.8.1")
```

The package wraps a pre-compiled `bitHumanKit.xcframework`. Every third-party dep (MLX, HuggingFace, Tokenizers, ...) is statically linked — consumers have **zero** transitive Swift Package dependencies. Just `import bitHumanKit`.

## Hardware floor

| Platform | Minimum | OS |
|----------|---------|-----|
| macOS | M3+ Apple Silicon | macOS 26 (Tahoe) |
| iPad | iPad Pro M4+, 16 GB | iPadOS 26 |
| iPhone | iPhone 16 Pro+ (A18 Pro) | iOS 26 |

`HardwareCheck.evaluate()` gates this at runtime — under-spec devices see a polite refusal instead of a half-loaded engine.

## Two models

| | **Essence** | **Expression** |
|---|---|---|
| **What** | Pre-rendered avatar + audio-driven lip patches | AI-generated facial animation from any face image |
| **Resolution** | 720p+ | 384x384 |
| **Avatar source** | `.imx` model file from [bithuman.ai](https://www.bithuman.ai/#explore) | Any portrait image |
| **Runtime cost** | 1 cr/min | 2 cr/min |
| **Best for** | Branded characters, kiosks, polished playback | Dynamic faces, drag-drop swap, conversational apps |

## Quick start

### Audio-only voice agent (no API key needed)

```swift
import bitHumanKit

var config = VoiceChatConfig()
config.localeIdentifier = "en-US"
config.systemPrompt = "You are a helpful assistant. One sentence per turn."
config.voice = .preset("Aiden")

let chat = VoiceChat(config: config)
try await chat.start()
// Speak into your mic. The agent listens, thinks, and replies through your speakers.
```

### With lip-synced avatar (requires BITHUMAN_API_KEY)

```swift
import bitHumanKit

let weights = try await ExpressionWeights.ensureAvailable()
let agent = AgentCatalog.defaultAgent
let portrait = AgentCatalog.thumbnailURL(for: agent)!

var config = VoiceChatConfig()
config.systemPrompt = agent.systemPrompt
config.avatar = AvatarConfig(modelPath: weights, portraitPath: portrait)
config.apiKey = ProcessInfo.processInfo.environment["BITHUMAN_API_KEY"]

let chat = VoiceChat(config: config)
try await chat.start()  // throws .missingAPIKey / .authenticationFailed
```

## Get an API key

The avatar pipeline charges 2 credits per active minute (Essence: 1 cr/min). Audio-only mode is free and unmetered.

Sign in at [www.bithuman.ai](https://www.bithuman.ai) → Developer → API Keys. Either set `VoiceChatConfig.apiKey` or export `BITHUMAN_API_KEY` before `chat.start()`.

## CLI (no code)

```bash
brew tap bithuman-product/bithuman
brew install bithuman-cli
bithuman-cli video        # voice + lip-synced floating avatar window
bithuman-cli text         # type to chat
bithuman-cli              # voice mode (default)
```

## Examples

Working SwiftUI example projects live in [`Examples/swift/`](../Examples/swift/):

| Example | Platform | Model | API key? |
|---------|----------|-------|----------|
| [macos-voice/](../Examples/swift/macos-voice/) | macOS | Audio only | No |
| [macos-avatar/](../Examples/swift/macos-avatar/) | macOS | Expression | Yes (2 cr/min) |
| [ios-avatar/](../Examples/swift/ios-avatar/) | iOS/iPadOS | Expression | Yes (2 cr/min) |
| [essence-playback/](../Examples/swift/essence-playback/) | macOS/iPad | Essence | Yes (1 cr/min) |

## Documentation

- [Swift SDK overview](https://docs.bithuman.ai/swift-sdk/overview)
- [10-min quickstart](https://docs.bithuman.ai/swift-sdk/quickstart)
- [macOS deployment](https://docs.bithuman.ai/swift-sdk/macos)
- [iOS / iPadOS deployment](https://docs.bithuman.ai/swift-sdk/ios)
- [Essence on Swift](https://docs.bithuman.ai/swift-sdk/essence)
- [bithuman-cli](https://docs.bithuman.ai/swift-sdk/cli)
- [Troubleshooting](https://docs.bithuman.ai/swift-sdk/troubleshooting)
- [Pricing & credits](https://docs.bithuman.ai/getting-started/pricing)

## Source code & support

The `bitHumanKit.xcframework` is a binary distribution — the Swift source is private. This directory and the root-level [`Package.swift`](../Package.swift) are the public surface.

- **Issues / feature requests** — [GitHub Issues](https://github.com/bithuman-product/bithuman-sdk-public/issues)
- **Changelog** — [`CHANGELOG.md`](./CHANGELOG.md)
- **Security** — see [SECURITY.md](../SECURITY.md)

## Versioning

Tags follow SemVer. Each tag points at a release that publishes a matching `bitHumanKit.xcframework.zip` artifact on the [Releases](https://github.com/bithuman-product/bithuman-sdk-public/releases) page.

## License

Binary distribution. Use is governed by the [bitHuman Terms of Service](https://www.bithuman.ai/terms). Model weights are proprietary and downloaded at runtime from authenticated endpoints.
