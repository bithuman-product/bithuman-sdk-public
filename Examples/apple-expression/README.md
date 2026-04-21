# bitHuman Expression on macOS — minimal SDK demo

**Input:** one WAV file + one packed `.imx` Expression model.
**Output:** a 25 FPS lip-synced MP4 rendered entirely on-device.

No LLM, no STT/TTS, no LiveKit. Just the bitHuman Python SDK calling into the bundled Swift runtime on Apple Silicon.

## Requirements

- macOS 14+
- **Apple Silicon, M3 or later** (M1/M2 unsupported — the Expression animator needs M3-class GPU memory bandwidth)
- 16 GB RAM, ~5 GB free disk
- Python 3.9–3.14
- `ffmpeg` on your PATH (`brew install ffmpeg`)

## Install

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

`pip install bithuman` on macOS arm64 automatically ships `bithuman-expression-daemon` — the Swift subprocess that runs the animator, face encoder, and face renderer. Nothing else to install.

## Run

```bash
export BITHUMAN_API_SECRET="your_secret_from_bithuman.ai"

python quickstart.py \
    --model /path/to/expression.imx \
    --audio speech.wav \
    --output out.mp4
```

Takes a few seconds to load the model, then ~0.5× real time to render.

## Use a custom face

Pass a portrait image and the SDK encodes it on load (~300 ms one-time):

```bash
python quickstart.py \
    --model expression.imx \
    --audio speech.wav \
    --identity alice.jpg \
    --output alice.mp4
```

Or pass a pre-encoded `.npy` reference latent for instant load (useful if the same portrait is reused across many sessions).

## What you should see

```
[ready] 384x384, identity=override
[pushed] 15.00s of audio @ 16000 Hz
[done] alice.mp4 — 375 frames (15.00s video, 14.96s audio)
```

## Where to get an `.imx`

Build one with the `bithuman pack` CLI (see the [main SDK README](https://github.com/bithuman-product/bithuman-python-sdk#pack)), or download a pre-packed model from your bitHuman dashboard.

## What this example demonstrates

- `AsyncBithuman.create(model_path=..., identity=...)` — one call to load the bundle and (optionally) override the avatar face
- `push_audio()` + `flush()` — audio-clocked streaming contract
- `runtime.run()` — pull paired `(frame, audio_chunk)` events until `end_of_speech`

Swap `--audio` for a live microphone stream, or pair with a TTS to build a talking agent. The SDK surface is identical — only the audio source changes.

## Related

- [Expression on macOS docs](https://docs.bithuman.ai/examples/apple-expression)
- [Python SDK reference](https://github.com/bithuman-product/bithuman-python-sdk)
- [Swift SDK (direct Swift consumers)](https://github.com/bithuman-product/bithuman-expression-swift)
- [bitHuman Halo — end-user desktop app built on this SDK](https://docs.bithuman.ai/examples/halo-macos)
