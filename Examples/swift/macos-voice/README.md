# macos-voice -- Minimal macOS Voice Agent

A minimal SwiftUI app that boots a voice-only conversational agent on macOS. All inference (speech recognition, LLM, TTS) runs on-device. No API key required. No avatar rendering.

## Prerequisites

- macOS 26 (Tahoe) or later
- Apple Silicon Mac (M3 or newer)
- Xcode 26+
- ~3 GB free disk for first-launch model downloads
- A microphone (built-in or external)

## Run

From this directory:

```bash
swift run MacOSVoice
```

Or open the directory in Xcode (File -> Open -> select the folder containing `Package.swift`) and hit Run.

The first launch downloads LLM and TTS weights to `~/.cache/huggingface/hub/`. Subsequent launches are instant.

## What it does

1. Creates a `VoiceChatConfig` with English locale, a system prompt, and the "Aiden" voice preset.
2. Boots a `VoiceChat` session that listens through the microphone.
3. Transcribes speech, generates a response via the on-device LLM, and speaks the reply through the speakers.

No network calls are made after the initial weights download.

## Files

| File | Purpose |
|------|---------|
| `Package.swift` | SPM manifest -- depends on `bitHumanKit` from `bithuman-sdk-public` |
| `Sources/main.swift` | SwiftUI `@main` app with `Lifecycle` class and `ContentView` |

## Docs

- [Swift SDK quickstart](https://docs.bithuman.ai/swift-sdk/quickstart)
- [macOS guide](https://docs.bithuman.ai/swift-sdk/macos)
