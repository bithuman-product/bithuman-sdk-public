# Swift SDK (Apple Platforms)

The Swift SDK (`bitHumanKit`) runs all inference on-device: STT, LLM, TTS, and lip-sync animation. No server, no cloud GPU, no Docker. Import the package, point it at a model, and ship a native app.

bitHumanKit is distributed as a SwiftPM binary package with zero transitive Swift dependencies.

## Examples

| Example | Platform | Model | API key? | What it shows |
|---------|----------|-------|----------|---------------|
| [macos-voice/](macos-voice/) | macOS | -- (audio only) | No | Minimal voice agent: `VoiceChat` + `VoiceChatConfig`. No avatar, no billing. |
| [macos-avatar/](macos-avatar/) | macOS | Expression | Yes (2 cr/min) | Voice agent with lip-synced avatar: `ExpressionWeights`, `AvatarConfig`, `AvatarCoordinator`, `FramePump`, `AvatarRendererView` via `NSViewRepresentable`. |
| [ios-avatar/](ios-avatar/) | iOS / iPadOS | Expression | Yes (2 cr/min) | Same avatar pipeline on iPhone/iPad: `HardwareCheck.evaluate()` gate, `UIViewRepresentable`, memory entitlements. |
| [essence-playback/](essence-playback/) | macOS / iPad | Essence | Yes (1 cr/min) | Essence `.imx` model: `Bithuman.createRuntime(modelPath:)`, `EssenceRuntime.pushAudio()`, `frames()` AsyncStream. |

Each example is a standalone SPM project. Clone, open in Xcode (or `swift run` from the terminal), and go.

## Supported models

- **Expression** -- AI-generated facial animation from any face image, powered by the on-device Swift daemon.
- **Essence** -- CPU-based lip sync from pre-built `.imx` model files. Supported on Apple Silicon via the same Swift SDK.

## Hardware floor

| Platform | Minimum device | OS |
|----------|---------------|----|
| Mac | Apple Silicon M3+ | macOS 26+ |
| iPad | M4+ iPad Pro (16 GB) | iPadOS 26+ |
| iPhone | iPhone 16 Pro+ | iOS 26+ |

M1 and M2 Macs are not supported for Expression (the SDK raises `ExpressionModelNotSupported`). Essence works on any Apple Silicon Mac.

## Links

| Resource | URL |
|----------|-----|
| SwiftPM package | [github.com/bithuman-product/bithuman-sdk-public](https://github.com/bithuman-product/bithuman-sdk-public) |
| Overview docs | [docs.bithuman.ai/swift-sdk/overview](https://docs.bithuman.ai/swift-sdk/overview) |
| Quickstart | [docs.bithuman.ai/swift-sdk/quickstart](https://docs.bithuman.ai/swift-sdk/quickstart) |
| CLI (no-code) | [docs.bithuman.ai/swift-sdk/cli](https://docs.bithuman.ai/swift-sdk/cli) |

## Integration

Add the package to your Xcode project or `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/bithuman-product/bithuman-sdk-public.git", from: "0.8.1")
]
```

Then `import bitHumanKit` in your source files.

## CLI (no-code path)

For quick testing without writing code, install the CLI via Homebrew:

```bash
brew tap bithuman-product/bithuman
brew install bithuman-cli
bithuman-cli video
```

See [docs.bithuman.ai/swift-sdk/cli](https://docs.bithuman.ai/swift-sdk/cli) for usage.

## Reference apps

Reference apps (Mac, iPad, iPhone) live in the private [bithuman-apps](https://github.com/bithuman-product/bithuman-apps) repo. They consume the SDK via the published SwiftPM binary package — the same way any external developer would. Prebuilt binaries are linked from the [quickstart docs](https://docs.bithuman.ai/swift-sdk/quickstart).

## Python SDK on Apple Silicon

For developers who prefer Python, the `bithuman` PyPI package includes a macOS arm64 wheel with the bundled Swift daemon. See the [local-expression-mac](../python/local-expression-mac/) example for a minimal Python-based Expression demo on Mac -- no Xcode required.

## Documentation

- [Swift SDK overview](https://docs.bithuman.ai/swift-sdk/overview)
- [Quickstart](https://docs.bithuman.ai/swift-sdk/quickstart)
- [CLI reference](https://docs.bithuman.ai/swift-sdk/cli)
- [Models overview](https://docs.bithuman.ai/getting-started/models)
