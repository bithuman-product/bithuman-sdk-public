# bitHuman SDK

Real-time avatar animation — audio in, lip-synced video out at 25 FPS. Two models (Essence + Expression), three runtime surfaces (cloud, self-hosted, on-device).

[![Docs](https://img.shields.io/badge/docs-docs.bithuman.ai-blue)](https://docs.bithuman.ai)
[![PyPI](https://badge.fury.io/py/bithuman.svg)](https://pypi.org/project/bithuman/)
[![Discord](https://img.shields.io/badge/Discord-community-5865F2)](https://discord.gg/ES953n7bPA)

## Quick links

| What you need | Where to go |
|---|---|
| Python SDK (`pip install bithuman`) | [`python/README.md`](python/README.md) |
| Swift SDK (SwiftPM binary package) | [`Package.swift`](Package.swift) / [Swift docs](https://docs.bithuman.ai/swift-sdk/overview) |
| Working examples (Docker, LiveKit, APIs) | [`Examples/`](Examples/) |
| Full documentation | [docs.bithuman.ai](https://docs.bithuman.ai) |
| REST API reference | [api-reference](https://docs.bithuman.ai/api-reference/overview) |
| Get an API key | [www.bithuman.ai → Developer](https://www.bithuman.ai/#developer) |

## Repository layout

```
├── Package.swift          # Swift SDK binary target (SwiftPM)
├── python/                # Python SDK public surface (README, changelog, license)
├── Examples/              # Runnable examples for all platforms
│   ├── essence-cloud/         Cloud Essence via LiveKit plugin
│   ├── essence-selfhosted/    Local Essence on CPU
│   ├── expression-cloud/      Cloud Expression via LiveKit plugin
│   ├── expression-selfhosted/ Self-hosted Expression on NVIDIA GPU
│   ├── apple-expression/      On-device Expression (macOS M3+)
│   ├── api/                   REST API scripts
│   └── integrations/          Java, Next.js, Gradio, offline macOS
├── docs/                  # docs.bithuman.ai source (Mintlify)
├── CONTRIBUTING.md
└── SECURITY.md
```

## Install

### Python

```bash
pip install bithuman --upgrade
```

Pre-built wheels for Python 3.9–3.14 on Linux x86_64 + ARM64, macOS Intel + Apple Silicon, Windows x86_64.

### Swift (Xcode / SwiftPM)

**File → Add Package Dependencies →**

```
https://github.com/bithuman-product/bithuman-sdk-public.git
```

Or in `Package.swift`:

```swift
.package(url: "https://github.com/bithuman-product/bithuman-sdk-public.git", from: "0.8.1")
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

More examples: [`Examples/`](Examples/) — each directory has its own README with a one-command run path.

## Documentation

- [Getting started](https://docs.bithuman.ai/getting-started/quickstart) (Python)
- [Swift SDK](https://docs.bithuman.ai/swift-sdk/overview) (Mac / iPad / iPhone)
- [REST API](https://docs.bithuman.ai/api-reference/overview)
- [Pricing & credits](https://docs.bithuman.ai/getting-started/pricing)
- [Authentication](https://docs.bithuman.ai/getting-started/authentication)

## Issues & feedback

- **Bug reports / feature requests** → [GitHub Issues](https://github.com/bithuman-product/bithuman-sdk-public/issues)
- **Security vulnerabilities** → see [SECURITY.md](SECURITY.md)
- **Community** → [Discord](https://discord.gg/ES953n7bPA)

## License

- Example code in this repo: MIT
- Swift SDK (`bitHumanKit.xcframework`): binary distribution, governed by [bitHuman Terms of Service](https://www.bithuman.ai/terms)
- Python SDK (`bithuman` wheel): commercial license, see [bithuman.ai](https://bithuman.ai)
