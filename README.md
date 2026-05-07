# bitHuman SDK

Real-time avatar animation — audio in, lip-synced video out at 25 FPS. Two models (Essence + Expression), four ways to integrate.

[![Docs](https://img.shields.io/badge/docs-docs.bithuman.ai-blue)](https://docs.bithuman.ai)
[![PyPI](https://badge.fury.io/py/bithuman.svg)](https://pypi.org/project/bithuman/)
[![Discord](https://img.shields.io/badge/Discord-community-5865F2)](https://discord.gg/ES953n7bPA)

## Choose your path

| I want to... | SDK/Tool | Go to |
|---|---|---|
| Build with Python (local or cloud) | `pip install bithuman` | [Examples/python/](Examples/python/) |
| Build a native Mac/iPad/iPhone app | Swift SDK (`bitHumanKit`) | [Examples/swift/](Examples/swift/) |
| Use the CLI (no code) | `bithuman` or `bithuman-cli` | [Examples/cli/](Examples/cli/) |
| Call the HTTP API from any language | REST API | [Examples/rest-api/](Examples/rest-api/) |
| Try it in 2 minutes | Any | [Examples/quickstart/](Examples/quickstart/) |

Get an API key at [www.bithuman.ai → Developer](https://www.bithuman.ai/#developer).

## Repository layout

```
├── python/                    Python SDK (README, changelog, license)
├── swift/                     Swift SDK (README, changelog, license)
├── Package.swift              SwiftPM manifest (must be at root)
├── Examples/
│   ├── quickstart/                Try bitHuman in under 2 minutes
│   ├── python/                    Python SDK (6 examples: cloud + local)
│   ├── swift/                     Swift SDK (4 examples: macOS, iOS, Essence)
│   ├── cli/                       CLI tools (render, stream, Mac app)
│   ├── rest-api/                  HTTP API (curl + Python scripts)
│   └── integrations/              Next.js, Java, Gradio, offline Mac
├── docs/                      docs.bithuman.ai source (Mintlify)
├── CONTRIBUTING.md
└── SECURITY.md
```

## Two models

| | **Essence** | **Expression** |
|---|---|---|
| **What** | Pre-rendered avatar from photo/video | AI-generated animation from any face image |
| **Compute** | CPU only (any platform) | NVIDIA GPU **or** Apple Silicon M3+ |
| **Best for** | Kiosks, voice agents, edge, 24/7 | Custom faces, native apps, dynamic characters |

Full comparison: [docs.bithuman.ai/getting-started/models](https://docs.bithuman.ai/getting-started/models)

## Install

### Python

```bash
pip install bithuman --upgrade
```

### Swift (Xcode / SwiftPM)

**File → Add Package Dependencies →** `https://github.com/bithuman-product/bithuman-sdk-public.git`

### CLI (Mac, no code)

```bash
brew tap bithuman-product/bithuman && brew install bithuman-cli
bithuman-cli video
```

## Quick start

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
    chunk = sr // 25
    for i in range(0, len(pcm), chunk):
        await runtime.push_audio(pcm[i : i + chunk].tobytes(), sr)
    await runtime.flush()
    async for frame in runtime.run():
        if frame.has_image:
            image = frame.bgr_image
        if frame.end_of_speech:
            break
    await runtime.stop()

asyncio.run(main())
```

## Documentation

- [Getting started](https://docs.bithuman.ai/getting-started/quickstart) (Python) / [Swift SDK](https://docs.bithuman.ai/swift-sdk/overview) (Apple)
- [REST API](https://docs.bithuman.ai/api-reference/overview) / [Pricing](https://docs.bithuman.ai/getting-started/pricing)

## Issues & feedback

- [GitHub Issues](https://github.com/bithuman-product/bithuman-sdk-public/issues) / [Discord](https://discord.gg/ES953n7bPA) / [SECURITY.md](SECURITY.md)

## License

Example code: MIT. Swift SDK: [bitHuman ToS](https://www.bithuman.ai/terms). Python SDK: commercial, see [bithuman.ai](https://bithuman.ai).
