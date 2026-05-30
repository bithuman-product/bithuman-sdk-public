# CompareTTS

Load each TTS backend and synthesize a fixed utterance, so the vendored
`MLXAudioTTS` path can be sanity-checked from a Mac without a mic.

Backends exercised:

| Backend   | Repo                                          | Use      |
|-----------|-----------------------------------------------|----------|
| Kokoro    | `mlx-community/Kokoro-82M-4bit`               | preset   |
| Qwen3-TTS | `mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit` | cloning  |

## Private-source dependency

This example imports `MLXAudioTTS`, re-exported by the `Voice` product of
the bithuman-sdk `voice/` package (the vendored
[Blaizzy/mlx-audio-swift](https://github.com/Blaizzy/mlx-audio-swift) TTS
stack, MIT). That stack is **not** part of the public binary
distribution, so this dev harness can only build against the private
monorepo. Clone it as a **sibling** of this repo:

```
~/code/bithuman-sdk          # private (collaborator access)
~/code/bithuman-sdk-public   # this repo
```

The `Package.swift` path dep (`../../../../bithuman-sdk/engine/voice`) resolves
`engine/voice/` via that layout.

External developers without private access should reach the TTS stack
through the published `bitHumanKit` umbrella binary instead of this tool.

## Run

```bash
cd Examples/swift/compare-tts
swift run -c release CompareTTS            # both backends
swift run -c release CompareTTS --help
```

Models download into `~/.cache/huggingface/hub` on first run. Reports
load time, gen time, RTF, |mean| and peak amplitude per backend.

## Requires

- macOS 26+ (Tahoe), Apple Silicon
- The private bithuman-sdk sibling checkout (see above)
