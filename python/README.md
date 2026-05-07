# bitHuman Avatar Runtime

![bitHuman Banner](https://docs.bithuman.ai/images/bithuman-banner.jpg)

**Real-time avatar engine for visual AI agents, digital humans, and creative characters.**

[![PyPI version](https://badge.fury.io/py/bithuman.svg)](https://pypi.org/project/bithuman/)
[![Python](https://img.shields.io/badge/python-3.9--3.14-blue.svg)](https://www.python.org/downloads/)
[![Platforms](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey.svg)]()

Photorealistic avatars with audio-driven lip sync at 25 FPS. Runs on edge devices — typically 1–2 CPU cores, &lt;200 ms end-to-end latency. Use it for voice agents with faces, video chatbots, tutors, NPCs, digital humans.

## Which avatar should I use?

The SDK ships one API — `AsyncBithuman.create(model_path=…)` — driving two model types. Start with **Essence**. It's the default, runs on every supported platform, and is what every new user should reach for.

| | **Essence** ← default | **Expression** |
|---|---|---|
| Runs on | Linux / macOS / Windows, any CPU | macOS 14+ on Apple Silicon **M3 or later** (on-device) |
| Rendering | Pre-built `.imx` bundle, in-process | Bundled Swift daemon via IPC |
| Footprint | 1–2 CPU cores, &lt;200 MB RAM | ~4 GB RAM working set |
| Best for | Voice agents, kiosks, edge devices, everywhere | Custom-face avatars on Mac M3+ |

Loading an Expression `.imx` on an unsupported host raises a typed `ExpressionModelNotSupported` — not a crash. For cloud or self-hosted-GPU Expression dispatch (Linux + NVIDIA, or bitHuman's cloud workers), use the [LiveKit plugin](https://github.com/bithuman-product/bithuman-sdk-public/tree/main/Examples/cloud/expression-livekit) (`bithuman.AvatarSession`), not `AsyncBithuman`.

Architecture deep dive + production patterns at [docs.bithuman.ai](https://docs.bithuman.ai).

## Install

```bash
pip install bithuman --upgrade
```

Pre-built wheels for Python 3.9 – 3.14 on Linux x86_64 + ARM64, macOS Intel + Apple Silicon, Windows x86_64. No compile step.

For LiveKit Agent integration (voice agents with faces over WebRTC):

```bash
pip install bithuman[agent]
```

## Quick start — Essence (cross-platform, default)

Grab an `.imx` from your [bitHuman dashboard](https://www.bithuman.ai/#explore) (⋮ → Download), export your API secret, then:

### CLI

```bash
export BITHUMAN_API_SECRET=your_secret
bithuman generate avatar.imx --audio speech.wav --output demo.mp4
```

Don't have a WAV to test with? Grab the 13-second sample bundled in the examples repo:

```bash
curl -O https://raw.githubusercontent.com/bithuman-product/bithuman-sdk-public/main/Examples/self-hosted/essence-cpu/speech.wav
```

### Python

```python
import asyncio, os
from bithuman import AsyncBithuman
from bithuman.audio import load_audio, float32_to_int16

async def main():
    runtime = await AsyncBithuman.create(
        model_path="avatar.imx",
        api_secret=os.environ["BITHUMAN_API_SECRET"],
    )
    await runtime.start()

    pcm, sr = load_audio("speech.wav")
    pcm = float32_to_int16(pcm)
    chunk = sr // 25  # one chunk per video frame
    for i in range(0, len(pcm), chunk):
        await runtime.push_audio(pcm[i : i + chunk].tobytes(), sr)
    await runtime.flush()

    async for frame in runtime.run():
        if frame.has_image:
            image = frame.bgr_image        # np.ndarray (H, W, 3), uint8
            audio = frame.audio_chunk      # synchronized output
        if frame.end_of_speech:
            break
    await runtime.stop()

asyncio.run(main())
```

`Bithuman` (no `Async`) is the threaded sync equivalent — same surface, no `await`. Usage examples live in the [Examples](https://github.com/bithuman-product/bithuman-sdk-public/tree/main/Examples) directory.

## Quick start — Expression on macOS M3+ (on-device, optional)

> **macOS 14+ on Apple Silicon M3 or later (M3+ recommended).** M1 / M2 / Intel / Linux / Windows: use Essence above, or the LiveKit cloud plugin for Expression dispatch.

Expression bundles a diffusion-based animator that renders any face image in real time. Same API — just point at an Expression `.imx`.

```bash
bithuman demo --model expression.imx --audio speech.wav         # CLI one-shot
```

```python
runtime = await AsyncBithuman.create(
    model_path="expression.imx",
    api_secret=os.environ["BITHUMAN_API_SECRET"],
    identity="alice.jpg",         # optional — overrides the bundle's default face
    quality="medium",             # "high" is offline-only (~2× slower)
)

await runtime.set_identity("bob.jpg")           # swap face mid-session, ~300 ms
await runtime.set_identity("bob_cached.npy")    # pre-encoded — instant
```

| `identity=` | Cost on load | Cost on swap |
|---|---|---|
| `None` | 0 (bundle's baked-in face) | n/a |
| `.jpg` / `.png` | ~300 ms | ~300 ms |
| `.npy` (pre-encoded) | instant | instant |

| `quality=` | Realtime @ 384×384 on M5 | Realtime @ 512×512 on M5 |
|---|---|---|
| `"medium"` (default) | **1.84×** | **1.14×** |
| `"high"` | 1.05× | 0.67× ⚠ sub-realtime — offline only |

On a supported Mac, `AsyncBithuman` transparently spawns the bundled `bithuman-expression-daemon` subprocess when it sees an Expression manifest — there's nothing to configure.

## API surface

```python
from bithuman import (
    AsyncBithuman, Bithuman,                  # runtimes
    AudioChunk, VideoFrame, VideoControl,     # data classes
    Emotion, EmotionPrediction,               # emotion input
    BithumanError, TokenExpiredError, ...     # typed exceptions
)

# Stream audio in, pull frames out:
await runtime.push_audio(pcm_bytes, sample_rate)    # int16, any SR (auto-resampled)
await runtime.flush()
runtime.interrupt()                                 # cancel current playback

async for frame in runtime.run():
    frame.bgr_image          # (H, W, 3) uint8 BGR
    frame.audio_chunk        # synchronized output
    frame.end_of_speech
    frame.frame_index

# Controls:
await runtime.push(VideoControl(action="wave"))
await runtime.push(VideoControl(target_video="idle"))

# Identity (Expression only):
await runtime.set_identity("face.jpg")
```

Full reference: [docs.bithuman.ai](https://docs.bithuman.ai).

## CLI

Every command reads `$BITHUMAN_API_SECRET` by default.

| Command | Works with | Description |
|---------|-----------|-------------|
| `bithuman generate <model> --audio <file>` | Essence + Expression | Render a lip-synced MP4 |
| `bithuman stream <model>` | Essence + Expression | Live streaming server at `localhost:3001` |
| `bithuman speak <audio>` | — | Send audio to a running `stream` server |
| `bithuman demo --model <imx> [--audio <file>]` | Expression (macOS M3+) | Zero-friction Expression demo with a bundled sample clip |
| `bithuman convert <model>` | Essence | Convert legacy TAR `.imx` to IMX v2 (smaller, 1000× faster load) |
| `bithuman pack …` | Expression | Pack an Expression bundle from raw animator + encoder + renderer weights |
| `bithuman info <model>` | Essence + Expression | Show model metadata |
| `bithuman validate <path>` | Essence + Expression | Sanity-check a model file |

## Environment variables

| Variable | Description |
|----------|-------------|
| `BITHUMAN_API_SECRET` | API secret — recommended |
| `BITHUMAN_API_KEY` | Legacy alias read by `generate` / `stream`; use `BITHUMAN_API_SECRET` in new code |
| `BITHUMAN_RUNTIME_TOKEN` | Pre-minted JWT (alternative to API secret) |
| `BITHUMAN_VERBOSE` | Enable debug logging |

## LiveKit agents

Build full voice agents with faces:

```python
from bithuman import AsyncBithuman
from bithuman.utils.agent import LocalAvatarRunner, LocalVideoPlayer, LocalAudioIO

runtime = await AsyncBithuman.create(model_path="avatar.imx", api_secret="…")
avatar = LocalAvatarRunner(
    bithuman_runtime=runtime,
    audio_input=session.audio,
    audio_output=LocalAudioIO(session, agent_output),
    video_output=LocalVideoPlayer(window_size=(1280, 720)),
)
await avatar.start()
```

For end-to-end Docker Compose stacks (LiveKit + OpenAI + bitHuman) see the [`Examples/`](https://github.com/bithuman-product/bithuman-sdk-public/tree/main/Examples) directory.

## Troubleshooting

**`objc: Class AVFFrameReceiver is implemented in both …/cv2/… and …/av/…`**
Both OpenCV and PyAV (`av`) ship their own FFmpeg dylibs. The warning appears as soon as both are imported — it's printed once at import and usually harmless. If you have the full `opencv-python` installed (rather than `opencv-python-headless` that `bithuman` depends on), it's a much larger collision — fix that variant explicitly:

```bash
pip uninstall -y opencv-python && pip install opencv-python-headless
```

## Links

- [Docs](https://docs.bithuman.ai) · [PyPI](https://pypi.org/project/bithuman/)
- [Examples](https://github.com/bithuman-product/bithuman-sdk-public/tree/main/Examples) directory — end-to-end stacks (Docker Compose, LiveKit agents, web UIs)
- [bitHuman Halo](https://bithuman.ai/halo) — free macOS desktop app built on this SDK
- [bithuman.ai](https://bithuman.ai) · [API Keys](https://www.bithuman.ai/#developer)

## License

Commercial license required. See [bithuman.ai](https://bithuman.ai) for pricing.

---

## Source code & support

The wheels you install via `pip install bithuman` ship Cython-compiled `.so` files for parts of the runtime that include client-side licensing material; the corresponding `.py` source is kept in a private repository for that reason. Everything else in the SDK — the public Python API, the CLI, the LiveKit plugin glue — is the documentation you're reading and the symbols you import.

This repo is the public surface for the package:

- **Issues / feature requests** — file them here.
- **Changelog** — [`CHANGELOG.md`](./CHANGELOG.md) tracks every PyPI release.
- **Discussions / docs** — [docs.bithuman.ai](https://docs.bithuman.ai).
- **Working examples** — [Examples](https://github.com/bithuman-product/bithuman-sdk-public/tree/main/Examples) directory.

If you hit a bug or want to propose an API change, please open an issue with a minimal repro and the output of `pip show bithuman` + `python --version`.
