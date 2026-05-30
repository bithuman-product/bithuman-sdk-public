# HelloVoiceChat

The minimum it takes to embed `bitHumanKit` into an SPM-built macOS
executable: a voice agent with no avatar and no billing. STT + LLM + TTS
all run on-device.

## Run

```bash
cd Examples/swift/hello-voice-chat
swift run -c release HelloVoiceChat
```

Speak into the mic; Ctrl-C to quit. Override any field on
`VoiceChatConfig` (system prompt, language, voice) before passing it to
`VoiceChat`.

## Requires

- macOS 26+ (Tahoe), Apple Silicon M3+
- Microphone permission (granted on first launch)

No API key, no model file: the voice path is unmetered.
