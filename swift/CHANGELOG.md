# Changelog

All notable changes to the `bitHumanKit` Swift SDK are documented here.

## [0.8.1] - 2026-04-28

### Initial binary release

First public release of bitHumanKit as a SwiftPM binary package.

- **Voice agent** — on-device speech recognition (Apple's `SpeechAnalyzer`), on-device language model, on-device voice synthesis with optional voice cloning.
- **Lip-synced avatar** — Expression model rendering at 384x384 @ 25 FPS with eight bundled agent personas and drag-drop face swap.
- **Essence runtime** — on-device Essence `.imx` playback at 720p+ with audio-driven lip patches via `EssenceRuntime`.
- **SwiftUI components** — `AvatarRendererView`, `AvatarCoordinator`, `FramePump`, pickers for agents/voices/prompts.
- **Hardware gating** — `HardwareCheck.evaluate()` refuses under-spec devices at runtime.
- **Cross-platform** — same Swift code runs on macOS 26 (M3+), iPadOS 26 (M4+ iPad Pro), iOS 26 (iPhone 16 Pro+).
- **Zero transitive dependencies** — all third-party deps (MLX, HuggingFace, Tokenizers) statically linked.
- **Billing heartbeat** — 1-request-per-minute heartbeat to `api.bithuman.ai` for avatar mode. Audio-only mode is unmetered and works offline.
