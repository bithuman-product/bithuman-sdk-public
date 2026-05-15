# macos-avatar -- macOS Voice Agent with Lip-Synced Avatar

A SwiftUI app that boots a voice agent with a real-time, lip-synced Expression avatar on macOS. The avatar pipeline downloads ~1.6 GB of weights on first launch, then runs entirely on-device.

## Prerequisites

- macOS 26 (Tahoe) or later
- Apple Silicon Mac (M3 or newer)
- Xcode 26+
- ~3 GB free disk for model downloads (LLM + TTS + Expression weights)
- A `BITHUMAN_API_KEY` -- avatar mode is metered at **2 credits per active minute**

### Get an API key

1. Sign in at [bithuman.ai](https://www.bithuman.ai) -> Developer -> API Keys.
2. Export it before running:

```bash
export BITHUMAN_API_KEY="your-key-here"
```

Audio-only mode (see `macos-voice/`) is free and unmetered. The avatar pipeline requires a key for the 1-request-per-minute billing heartbeat.

## Run

```bash
export BITHUMAN_API_KEY="your-key-here"
swift run MacOSAvatar
```

Or open in Xcode, set the environment variable in the scheme (Product -> Scheme -> Edit Scheme -> Run -> Arguments -> Environment Variables), and hit Run.

## What it does

1. Downloads and SHA-256-verifies the Expression weights bundle via `ExpressionWeights.ensureAvailable()` (cached at `~/.cache/bithuman/expression/`).
2. Configures `VoiceChatConfig` with an `AvatarConfig` pointing to the weights and a bundled agent portrait.
3. Boots `VoiceChat` with avatar mode -- this starts the billing heartbeat.
4. Creates an `AvatarCoordinator` and `FramePump` to drive frames into `AvatarRendererView`.
5. Hosts the renderer in SwiftUI via `NSViewRepresentable`.

The avatar circle renders live lip-synced animation as the agent speaks.

## Key API types

| Type | Role |
|------|------|
| `ExpressionWeights` | Downloads and caches the universal weights bundle |
| `AvatarConfig` | Points the pipeline at weights + portrait |
| `AvatarCoordinator` | Binds voice orchestration to avatar state |
| `FramePump` | Drives frames from the inference engine into the renderer |
| `AvatarRendererView` | NSView / UIView that displays avatar frames |

## Files

| File | Purpose |
|------|---------|
| `Package.swift` | SPM manifest -- depends on `bitHumanKit` |
| `Sources/main.swift` | SwiftUI `@main` app with `AvatarLifecycle`, `AvatarHost`, and `AvatarContentView` |

## Docs

- [Swift SDK quickstart](https://docs.bithuman.ai/sdks/swift)
- [macOS guide](https://docs.bithuman.ai/sdks/swift)
