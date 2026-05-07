# bitHuman SDK

Real-time avatar animation — audio in, lip-synced video out at 25 FPS. Two models (Essence + Expression), three runtime surfaces (cloud, self-hosted, on-device).

[![Docs](https://img.shields.io/badge/docs-docs.bithuman.ai-blue)](https://docs.bithuman.ai)
[![PyPI](https://badge.fury.io/py/bithuman.svg)](https://pypi.org/project/bithuman/)
[![Discord](https://img.shields.io/badge/Discord-community-5865F2)](https://discord.gg/ES953n7bPA)

## Choose your path

| I want to... | Go to | What I need |
|---|---|---|
| Try it in 2 minutes | [Examples/quickstart/](Examples/quickstart/) | API key |
| Add a talking avatar to my web app | [Examples/cloud/](Examples/cloud/) | API key |
| Run on my own hardware (CPU or GPU) | [Examples/self-hosted/](Examples/self-hosted/) | API key + hardware |
| Build a native Mac/iPad/iPhone app | [Examples/swift/](Examples/swift/) | Apple Silicon M3+ |
| Call the REST API from any language | [Examples/cloud/rest-api/](Examples/cloud/rest-api/) | API key |
| Connect to my existing stack | [Examples/integrations/](Examples/integrations/) | Varies |

Get an API key at [www.bithuman.ai → Developer](https://www.bithuman.ai/#developer).

## Repository layout

```
├── Package.swift              Swift SDK binary target (SwiftPM)
├── python/                    Python SDK public surface (README, changelog, license)
├── Examples/
│   ├── quickstart/                Try bitHuman in under 2 minutes
│   ├── cloud/                     bitHuman hosts the avatar (no GPU needed)
│   │   ├── essence-livekit/           Essence model via LiveKit plugin
│   │   ├── expression-livekit/        Expression model via LiveKit plugin
│   │   └── rest-api/                  HTTP-only: generate, speak, manage
│   ├── self-hosted/               You host the avatar (full control)
│   │   ├── essence-cpu/               Essence on any machine (Linux/Mac/Win/RPi)
│   │   ├── expression-gpu/            Expression on Linux + NVIDIA GPU
│   │   └── expression-apple/          Expression on macOS M3+ (Python)
│   ├── swift/                     Native Apple apps (Mac/iPad/iPhone)
│   └── integrations/              Next.js, Java, Gradio, offline Mac
├── docs/                      docs.bithuman.ai source (Mintlify)
├── CONTRIBUTING.md
└── SECURITY.md
```

## Two models

| | **Essence** | **Expression** |
|---|---|---|
| **What** | Pre-rendered avatar from photo/video | AI-generated facial animation from any face image |
| **Compute** | CPU only (any platform) | NVIDIA GPU **or** Apple Silicon M3+ |
| **Best for** | Kiosks, voice agents, edge, 24/7 | Custom faces, native apps, dynamic characters |
| **Avatar source** | `.imx` file from [bithuman.ai](https://www.bithuman.ai/#explore) | Any face image (JPG/PNG) |

Full comparison: [docs.bithuman.ai/getting-started/models](https://docs.bithuman.ai/getting-started/models)

## Install

### Python

```bash
pip install bithuman --upgrade
```

Pre-built wheels for Python 3.9-3.14 on Linux x86_64 + ARM64, macOS Intel + Apple Silicon, Windows x86_64.

### Swift (Xcode / SwiftPM)

**File → Add Package Dependencies →**

```
https://github.com/bithuman-product/bithuman-sdk-public.git
```

Hardware floor: M3+ Mac (macOS 26), M4+ iPad Pro (iPadOS 26), iPhone 16 Pro+ (iOS 26).

### CLI (Mac, no code)

```bash
brew tap bithuman-product/bithuman
brew install bithuman-cli
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
            image = frame.bgr_image      # numpy (H, W, 3) uint8
        if frame.end_of_speech:
            break
    await runtime.stop()

asyncio.run(main())
```

More examples: [Examples/](Examples/) — each directory has a README with a one-command run path.

## Documentation

- [Getting started](https://docs.bithuman.ai/getting-started/quickstart) (Python) / [Swift SDK](https://docs.bithuman.ai/swift-sdk/overview) (Apple)
- [REST API reference](https://docs.bithuman.ai/api-reference/overview)
- [Pricing & credits](https://docs.bithuman.ai/getting-started/pricing) / [Authentication](https://docs.bithuman.ai/getting-started/authentication)

## Issues & feedback

- **Bug reports / feature requests** → [GitHub Issues](https://github.com/bithuman-product/bithuman-sdk-public/issues)
- **Security vulnerabilities** → [SECURITY.md](SECURITY.md)
- **Community** → [Discord](https://discord.gg/ES953n7bPA)

## License

- Example code: MIT
- Swift SDK (`bitHumanKit.xcframework`): [bitHuman Terms of Service](https://www.bithuman.ai/terms)
- Python SDK (`bithuman` wheel): commercial license, see [bithuman.ai](https://bithuman.ai)
