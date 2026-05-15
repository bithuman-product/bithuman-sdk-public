# bitHuman Expression on macOS — minimal SDK demo

Render a 25 FPS lip-synced MP4 on-device using the bundled Swift runtime. No LLM, STT, TTS, Docker, or LiveKit — just the SDK.

Full docs: [Python SDK](https://docs.bithuman.ai/sdks/python) ·
[Essence vs Expression](https://docs.bithuman.ai/getting-started/models).

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

## Run — CLI path (no identity override)

The `bithuman` CLI renders an Expression `.imx` with its baked-in face:

```bash
bithuman generate expression.imx --audio speech.wav --output demo.mp4
```

The CLI has no face-override flag. To swap the portrait at load time,
use the script path below.

## Run — custom script path (face override supported)

`quickstart.py` drives the same pipeline through `AsyncBithuman.create()`
directly. Its `--identity` argument overrides the bundle's baked-in
face with any local image path or URL — encoded once on load
(~300 ms) and cached.

```bash
pip install -r requirements.txt
python quickstart.py --model expression.imx --audio speech.wav --output out.mp4
python quickstart.py --model expression.imx --audio speech.wav --identity alice.jpg --output alice.mp4
python quickstart.py --model expression.imx --audio speech.wav --identity "https://.../portrait.jpg" --output galaxy.mp4
```

Browse ready-made faces on [bithuman.ai → Explore](https://www.bithuman.ai/#explore).
Pre-encoded `.npy` identities load instantly — useful if the same
portrait is reused across sessions.

## What this demonstrates

- `AsyncBithuman.create(model_path=..., identity=...)` — load bundle, optionally override the face
- `push_audio()` + `flush()` — audio-clocked streaming contract
- `runtime.run()` — pull paired `(frame, audio_chunk)` events until `end_of_speech`

Swap `--audio` for a live mic stream or pair with a TTS for a talking agent — the SDK surface is identical.

## Related

- [Python SDK on PyPI](https://pypi.org/project/bithuman/)
- [Python SDK docs](https://docs.bithuman.ai/sdks/python)
- [macos-avatar — native macOS Expression app](../../swift/macos-avatar/)
