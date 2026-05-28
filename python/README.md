# bitHuman Avatar Runtime — Python SDK landing page

> **What this directory is.** The per-language landing page (README + [CHANGELOG](CHANGELOG.md) + [LICENSE](LICENSE.md)) for the [`bithuman` package on PyPI](https://pypi.org/project/bithuman/). **The SDK runtime source is private** — signing material is baked into the published wheels. To install: `pip install bithuman`. To browse runnable examples: [`Examples/python/`](../Examples/python/). To file a bug or request a feature: [bithuman-sdk-public/issues](https://github.com/bithuman-product/bithuman-sdk-public/issues).

![bitHuman Banner](https://docs.bithuman.ai/images/bithuman-banner.jpg)

**Real-time avatar engine for visual AI agents, digital humans, and creative characters.**

[![PyPI version](https://badge.fury.io/py/bithuman.svg)](https://pypi.org/project/bithuman/)
[![Python](https://img.shields.io/badge/python-3.9--3.14-blue.svg)](https://www.python.org/downloads/)
[![Platforms](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey.svg)]()

Photorealistic avatars with audio-driven lip sync at 25 FPS. Runs on edge devices — typically 1–2 CPU cores, &lt;200 ms end-to-end latency. Use it for voice agents with faces, video chatbots, tutors, NPCs, digital humans.

## What the SDK ships

The SDK exposes one API — `AsyncBithuman.create(model_path=…)` — driving the **Essence** model family. Essence runs on Linux / macOS / Windows on any modern CPU (1–2 cores, &lt;200 MB RAM) and is the supported avatar runtime.

Architecture deep dive + production patterns at [docs.bithuman.ai](https://docs.bithuman.ai).

## Install

```bash
pip install bithuman --upgrade
```

Pre-built wheels for Python 3.10 – 3.14 on Linux x86_64 + aarch64 and macOS Apple Silicon. (macOS Intel + Windows ship via a separate per-tag CI run; Python 3.9 dropped in 2.0.)

For LiveKit Agent integration (voice agents with faces over WebRTC):

```bash
pip install bithuman[agent]
```

## Library only — the CLI ships separately

As of 2.3, this package is **library-only** (~5 MB). The `bithuman`
CLI moved to its own PyPI package, [`bithuman-cli`](https://pypi.org/project/bithuman-cli/),
to keep this wheel slim for backend services / batch jobs / custom
integrations. The runtime library API is unchanged — code pinned to
`bithuman==1.11.3` (or `2.x`) runs on 2.3 without edits.

Need the talk-to-your-avatar CLI? Install either of:

```bash
pip install bithuman-cli                                   # sibling wheel
brew install bithuman-product/bithuman/bithuman            # Homebrew tap
```

Both surface the same `bithuman run` / `render` / `info` subcommands
documented at [docs.bithuman.ai/getting-started/cli](https://docs.bithuman.ai/getting-started/cli).
The CLI source lives in [`bithuman-apps`](https://github.com/bithuman-product/bithuman-apps);
this repo hosts the library only.

## Quick start — Essence (cross-platform, default)

Grab an `.imx` from your [bitHuman dashboard](https://www.bithuman.ai/#explore) (⋮ → Download), export your API secret, then:

### Offline render via CLI

The CLI is a separate install (see above). Once it's on your `PATH`:

```bash
export BITHUMAN_API_SECRET=your_secret
bithuman render avatar.imx --audio speech.wav --output demo.mp4   # Linux
```

(Offline render on macOS routes via Apple's AVAssetWriter — planned follow-up; meanwhile use the Linux build or the Python library below.)

Don't have a WAV to test with? Grab the 13-second sample bundled in the examples repo:

```bash
curl -O https://raw.githubusercontent.com/bithuman-product/bithuman-sdk-public/main/Examples/python/local-essence/speech.wav
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
```

Full reference: [docs.bithuman.ai](https://docs.bithuman.ai).

## CLI

The `bithuman` CLI is a **separate package** ([`bithuman-cli`](https://pypi.org/project/bithuman-cli/)
on PyPI, [`bithuman` on Homebrew](https://github.com/bithuman-product/homebrew-bithuman)).
Source lives in the [`bithuman-apps`](https://github.com/bithuman-product/bithuman-apps) repo.
Install one of:

```bash
# PyPI sibling wheel — same Rust binary, Python-friendly install
pip install bithuman-cli

# macOS + Linux — universal installer
curl -fsSL https://github.com/bithuman-product/homebrew-bithuman/releases/latest/download/install.sh | sh
# Or macOS Homebrew
brew install bithuman-product/bithuman/bithuman
```

Every command reads `$BITHUMAN_API_SECRET` by default.

| Command | Description |
|---------|-------------|
| `bithuman doctor` | Verify host + API key |
| `bithuman avatar` | Browser-served avatar at `http://127.0.0.1:8080` |
| `bithuman voice` | Spoken conversation in the terminal |
| `bithuman text` | Text chat, stdin → stdout |
| `bithuman generate <model> --audio <file> -o out.mp4` | Render a lip-synced MP4 |
| `bithuman stream <model>` | Local HTTP streaming server |
| `bithuman speak <audio>` | Send audio to a running `stream` server |
| `bithuman info <model>` | Show `.imx` model metadata |
| `bithuman models list` | List downloadable showcase avatars |

Full reference: [docs.bithuman.ai/getting-started/cli](https://docs.bithuman.ai/getting-started/cli)

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

The wheels you install via `pip install bithuman` ship Cython-compiled `.so` files for parts of the runtime that include client-side licensing material; the corresponding `.py` source is kept in a private repository for that reason. Everything else in the SDK — the public Python API and the LiveKit plugin glue — is the documentation you're reading and the symbols you import. The CLI is a separate package; its source lives in [`bithuman-apps`](https://github.com/bithuman-product/bithuman-apps).

This repo is the public surface for the package:

- **Issues / feature requests** — file them here.
- **Changelog** — [`CHANGELOG.md`](./CHANGELOG.md) tracks every PyPI release.
- **Discussions / docs** — [docs.bithuman.ai](https://docs.bithuman.ai).
- **Working examples** — [Examples](https://github.com/bithuman-product/bithuman-sdk-public/tree/main/Examples) directory.

If you hit a bug or want to propose an API change, please open an issue with a minimal repro and the output of `pip show bithuman` + `python --version`.
