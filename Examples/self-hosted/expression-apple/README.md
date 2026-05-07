# bitHuman Expression on macOS — minimal SDK demo

Render a 25 FPS lip-synced MP4 on-device using the bundled Swift runtime. No LLM, STT, TTS, Docker, or LiveKit — just the SDK.

Full docs: [docs.bithuman.ai/examples/apple-expression](https://docs.bithuman.ai/examples/apple-expression).

## Requirements

- macOS 14+ on Apple Silicon **M3 or later** (M1/M2 raise `ExpressionModelNotSupported`)
- 16 GB RAM, ~5 GB free disk
- Python 3.9–3.14
- `ffmpeg` on PATH (`brew install ffmpeg`)

## Install

```bash
python -m venv .venv
source .venv/bin/activate
pip install --upgrade bithuman opencv-python-headless
export BITHUMAN_API_SECRET="your_secret_from_bithuman.ai"
```

The macOS arm64 wheel ships `bithuman-expression-daemon` (the Swift subprocess the runtime spawns for Expression `.imx` files). Nothing else to install.

## Run — CLI path

```bash
bithuman demo --model expression.imx --audio speech.wav
```

Outputs `demo.mp4`. `--audio` defaults to a bundled sample clip if omitted. Pass `--identity face.jpg` (or a URL) to override the bundle's baked-in face — encoded once on load (~300 ms) and cached:

```bash
bithuman demo --model expression.imx --identity alice.jpg --output alice.mp4
bithuman demo --model expression.imx --identity "https://.../portrait.jpg" --output galaxy.mp4
```

See the [agent gallery](https://docs.bithuman.ai/examples/apple-expression#agent-gallery) for ready-made identity URLs.

## Run — custom script path

`quickstart.py` drives the same pipeline through `AsyncBithuman.create()` directly — useful when you're about to swap audio/identity/output for your own data flow.

```bash
pip install -r requirements.txt
python quickstart.py --model expression.imx --audio speech.wav --output out.mp4
python quickstart.py --model expression.imx --audio speech.wav --identity alice.jpg --output alice.mp4
```

Pre-encoded `.npy` identities load instantly — useful if the same portrait is reused across sessions.

## What this demonstrates

- `AsyncBithuman.create(model_path=..., identity=...)` — load bundle, optionally override the face
- `push_audio()` + `flush()` — audio-clocked streaming contract
- `runtime.run()` — pull paired `(frame, audio_chunk)` events until `end_of_speech`

Swap `--audio` for a live mic stream or pair with a TTS for a talking agent — the SDK surface is identical.

## Related

- [Python SDK on PyPI](https://pypi.org/project/bithuman/)
- [bitHuman Halo — consumer macOS app built on this pipeline](https://docs.bithuman.ai/examples/halo-macos)
