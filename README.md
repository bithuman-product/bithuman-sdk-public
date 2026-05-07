# bitHuman SDK

**Turn any face into a talking avatar.** Send audio in, get a lip-synced animated face out — in real time, at 25 frames per second.

Use it to build AI assistants with faces, video chatbots, virtual tutors, digital receptionists, or anything that needs a character that speaks.

[![Docs](https://img.shields.io/badge/docs-docs.bithuman.ai-blue)](https://docs.bithuman.ai)
[![PyPI](https://badge.fury.io/py/bithuman.svg)](https://pypi.org/project/bithuman/)
[![Discord](https://img.shields.io/badge/Discord-community-5865F2)](https://discord.gg/ES953n7bPA)

## Before you start

You need a free API key. It takes 30 seconds:

1. Go to [www.bithuman.ai](https://www.bithuman.ai) and sign up
2. Click **Developer** → **API Keys**
3. Copy your key

You get **99 free credits per month** (about 50 minutes of avatar time). No credit card required.

> **Which key name do I use?**
> - Python, CLI, and REST API → set the environment variable `BITHUMAN_API_SECRET`
> - Swift SDK (Apple apps) → set the environment variable `BITHUMAN_API_KEY`
>
> They come from the same dashboard page. The names differ for historical reasons.

## Pick how you want to build

| I want to... | Tool | Time to first demo | Start here |
|---|---|---|---|
| **See it work immediately** | Python or CLI | 5 min | [Examples/quickstart/](Examples/quickstart/) |
| **Build with Python** (web app, server, Raspberry Pi) | `pip install bithuman` | 10 min | [Examples/python/](Examples/python/) |
| **Build a native Apple app** (Mac, iPad, iPhone) | Swift SDK | 15 min | [Examples/swift/](Examples/swift/) |
| **Use the command line** (no code at all) | `bithuman-cli` | 2 min | [Examples/cli/](Examples/cli/) |
| **Call from any language** (Java, Go, JS, etc.) | REST API | 5 min | [Examples/rest-api/](Examples/rest-api/) |

If you're unsure, start with **[Examples/quickstart/](Examples/quickstart/)**.

## Two avatar models

bitHuman has two avatar engines. Start with **Essence** unless you need custom face-swapping.

| | **Essence** (start here) | **Expression** (advanced) |
|---|---|---|
| **How it works** | You upload a photo/video on [bithuman.ai](https://www.bithuman.ai/#explore), it generates a `.imx` avatar file you download | You provide any face image at runtime — no generation step |
| **Hardware needed** | Any CPU (laptop, server, Raspberry Pi) | NVIDIA GPU **or** Mac with M3+ chip |
| **Cost** | 1 credit/min (self-hosted) or 2 credits/min (cloud) | 2 credits/min (self-hosted) or 4 credits/min (cloud) |
| **Best for** | Getting started, kiosks, voice agents, 24/7 displays | Apps where users pick their own face, consumer apps |

Full comparison: [docs.bithuman.ai/getting-started/models](https://docs.bithuman.ai/getting-started/models)

## Install

### Python (Linux, macOS, Windows)

```bash
pip install bithuman --upgrade
```

Works with Python 3.9 through 3.14. Pre-built wheels — no compile step.

### Swift (Mac, iPad, iPhone)

In Xcode: **File → Add Package Dependencies →** paste this URL:

```
https://github.com/bithuman-product/bithuman-sdk-public.git
```

Requires Apple Silicon M3 or newer. See [swift/README.md](swift/README.md) for details.

### CLI (Mac, no code needed)

```bash
brew tap bithuman-product/bithuman
brew install bithuman-cli
bithuman-cli video    # starts a voice + avatar window
```

## Quick start (Python)

```python
import asyncio, os
from bithuman import AsyncBithuman
from bithuman.audio import load_audio, float32_to_int16

async def main():
    # 1. Load the avatar model and connect to the billing API
    runtime = await AsyncBithuman.create(
        model_path="avatar.imx",                          # your .imx file
        api_secret=os.environ["BITHUMAN_API_SECRET"],     # from bithuman.ai
    )
    await runtime.start()

    # 2. Push audio — the avatar will lip-sync to it
    pcm, sr = load_audio("speech.wav")
    pcm = float32_to_int16(pcm)
    chunk = sr // 25                                       # one chunk per frame
    for i in range(0, len(pcm), chunk):
        await runtime.push_audio(pcm[i : i + chunk].tobytes(), sr)
    await runtime.flush()                                  # signal "audio is done"

    # 3. Pull video frames — each frame is a numpy image
    async for frame in runtime.run():
        if frame.has_image:
            image = frame.bgr_image   # numpy array, shape (H, W, 3), BGR format
        if frame.end_of_speech:
            break

    await runtime.stop()

asyncio.run(main())
```

Don't have an `.imx` file? Download one from [bithuman.ai → Explore](https://www.bithuman.ai/#explore) (click the **...** menu on any agent → **Download**).

## What's in this repo

```
├── Package.swift              Swift package manifest — the binary distribution of bitHumanKit
│                              (binaryTarget consuming bitHumanKit.xcframework.zip from
│                              this repo's GitHub Releases). Required at root by SwiftPM.
│
├── python/                    Per-language landing page for the `bithuman` PyPI package.
│                              README, CHANGELOG, LICENSE — no SDK source (the runtime
│                              ships as wheels, source is private).
├── swift/                     Per-language landing page for the `bitHumanKit` Swift package.
│                              README, CHANGELOG, LICENSE — no SDK source (the framework
│                              ships as a pre-compiled xcframework consumed via Package.swift
│                              above).
│
├── Examples/                  Working code you can run
│   ├── quickstart/                Your first demo (start here)
│   ├── python/                    6 Python examples (cloud + local)
│   ├── swift/                     4 Swift examples (macOS, iOS, Essence)
│   ├── cli/                       Shell scripts for CLI tools
│   ├── rest-api/                  curl and Python scripts for the HTTP API
│   └── integrations/              Next.js, Java, Gradio, offline Mac
│
├── docs/                      Source for docs.bithuman.ai (Mintlify)
├── AGENTS.md                  Instructions for AI coding agents
└── CONTRIBUTING.md            How to contribute to this repo
```

> **Heads up on `python/` and `swift/`.** These directories hold the per-language landing pages and changelogs only — the SDK runtime sources are private (signing material is baked into the published artefacts). Use them as a navigation entry point ("here is the README and version history for the Python SDK") rather than expecting to find source. To install: `pip install bithuman` (Python) or add the SwiftPM URL above (Swift). To file a bug: [bithuman-sdk-public/issues](https://github.com/bithuman-product/bithuman-sdk-public/issues).

## Pricing

| What | Cost | Notes |
|------|------|-------|
| Free tier | 99 credits/month | No credit card needed |
| Essence (you host) | 1 credit/min | Runs on CPU |
| Essence (we host) | 2 credits/min | No setup needed |
| Expression (you host) | 2 credits/min | Needs GPU or Mac M3+ |
| Expression (we host) | 4 credits/min | No setup needed |
| Generate a new agent | 250 credits | One-time cost |

1 credit ~ 1 minute of avatar time. [Full pricing details](https://docs.bithuman.ai/getting-started/pricing)

## Documentation

| Topic | Link |
|-------|------|
| Python getting started | [docs.bithuman.ai/getting-started/quickstart](https://docs.bithuman.ai/getting-started/quickstart) |
| Swift SDK | [docs.bithuman.ai/swift-sdk/overview](https://docs.bithuman.ai/swift-sdk/overview) |
| REST API reference | [docs.bithuman.ai/api-reference/overview](https://docs.bithuman.ai/api-reference/overview) |
| How authentication works | [docs.bithuman.ai/getting-started/authentication](https://docs.bithuman.ai/getting-started/authentication) |
| Pricing and credits | [docs.bithuman.ai/getting-started/pricing](https://docs.bithuman.ai/getting-started/pricing) |
| Essence vs Expression | [docs.bithuman.ai/getting-started/models](https://docs.bithuman.ai/getting-started/models) |

## Get help

- **Questions or bugs** → [GitHub Issues](https://github.com/bithuman-product/bithuman-sdk-public/issues)
- **Community chat** → [Discord](https://discord.gg/ES953n7bPA)
- **Security issues** → email [security@bithuman.ai](mailto:security@bithuman.ai) (see [SECURITY.md](SECURITY.md))

## License

- Example code in this repo: **MIT** (use it however you want)
- Python SDK (`bithuman` package): commercial license — see [bithuman.ai](https://bithuman.ai)
- Swift SDK (`bitHumanKit` framework): [bitHuman Terms of Service](https://www.bithuman.ai/terms)
