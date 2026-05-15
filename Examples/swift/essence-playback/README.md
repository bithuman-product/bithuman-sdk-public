# essence-playback -- Essence Avatar on macOS / iPad

A SwiftUI app that loads an Essence `.imx` model file and renders the avatar with real-time, audio-driven lip sync. Demonstrates `Bithuman.createRuntime(modelPath:)`, `EssenceRuntime.pushAudio()`, and the `frames()` AsyncStream.

## Essence vs Expression

bitHumanKit ships two avatar runtimes behind a single API:

| | Essence | Expression |
|---|---|---|
| **Avatar source** | `.imx` model file (built from video on the dashboard) | Any portrait image -- no build step |
| **Resolution** | 720p+ | 384x384 |
| **What renders** | Pre-rendered base movement + audio-driven lip patches | Diffusion-generated facial animation |
| **Custom gestures** | Baked into the `.imx` | No |
| **Runtime cost** | 1 cr/min on-device | 2 cr/min on-device |
| **Memory footprint** | Lower -- no DiT in memory | Higher -- DiT weights resident |
| **Best for** | Branded characters, kiosks, polished playback | Dynamic faces, drag-drop swap, micro-expression |

Pick Essence when you have a branded character and want 720p+ fidelity at the lower credit rate. Pick Expression when you want drag-and-drop face swapping at 384x384.

## Prerequisites

- macOS 26+ on Apple Silicon M3+ (or iPadOS 26+ on iPad Pro M4+)
- Xcode 26+
- A `.imx` model file (create one at [bithuman.ai](https://www.bithuman.ai) -> Agents -> New Agent -> Essence model)
- A `BITHUMAN_API_KEY` -- Essence is metered at **1 credit per active minute**

### Get an API key

1. Sign in at [bithuman.ai](https://www.bithuman.ai) -> Developer -> API Keys.
2. Export it:

```bash
export BITHUMAN_API_KEY="your-key-here"
```

### Get a .imx model file

1. Sign in at [bithuman.ai](https://www.bithuman.ai) -> Agents -> New Agent.
2. Select the **Essence** model.
3. Upload your source video and wait for generation to finish.
4. Download the resulting `.imx` file.

The dashboard also ships royalty-free Essence agents you can use as placeholders.

## Run

```bash
export BITHUMAN_API_KEY="your-key-here"
swift run EssencePlayback /path/to/agent.imx
```

Or open in Xcode and pass the `.imx` path as a launch argument (Product -> Scheme -> Edit Scheme -> Run -> Arguments -> Arguments Passed On Launch).

## What it does

1. Calls `Bithuman.createRuntime(modelPath:)` with the `.imx` URL. The SDK inspects the file and returns `.essence(EssenceRuntime)`.
2. Subscribes to `essence.frames()` -- an `AsyncStream<CGImage?>` at the model's native frame rate. `nil` elements mean "render the idle frame" (keep the last good image on screen).
3. Displays frames in a SwiftUI `Image` view.
4. In a real integration, you would pipe 16 kHz mono PCM audio from your TTS or microphone into `essence.pushAudio(_:)` to drive real-time lip sync.

The audio encoder runs on the Neural Engine (ANE) via Metal/MLX. The renderer composites lip patches over the decoded base movement on CPU.

## Key API types

| Type | Role |
|------|------|
| `Bithuman.createRuntime(modelPath:)` | Inspects the file and returns `.essence(EssenceRuntime)` or `.expression(Bithuman)` |
| `EssenceRuntime` | Actor that drives the Essence pipeline |
| `EssenceRuntime.pushAudio(_:)` | Feed 16 kHz mono PCM for lip sync |
| `EssenceRuntime.frames()` | `AsyncStream<CGImage?>` of rendered frames |
| `EssenceRuntime.stop()` | Releases ANE resources |
| `EssenceRuntime.resolution` | Native pixel size of the loaded `.imx` |

## Hardware support

| Platform | Minimum | Notes |
|----------|---------|-------|
| macOS | M3+ Apple Silicon, macOS 26 | Recommended development target |
| iPad | iPad Pro M4+, 16 GB, iPadOS 26 | Requires increased-memory-limit entitlement |
| iPhone | Not supported (Phase 1) | Memory budget too tight for 720p+ -- see Essence docs |

## Files

| File | Purpose |
|------|---------|
| `Package.swift` | SPM manifest -- targets macOS 26.0 and iOS 26.0, depends on `bitHumanKit` |
| `Sources/main.swift` | SwiftUI `@main` app with `EssenceLifecycle`, frame rendering, and platform-conditional `Image` display |

## Docs

- [Essence on Swift](https://docs.bithuman.ai/sdks/swift)
- [Swift SDK quickstart](https://docs.bithuman.ai/sdks/swift)
- [Models overview](https://docs.bithuman.ai/getting-started/models)
