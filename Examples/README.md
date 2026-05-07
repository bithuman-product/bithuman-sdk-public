# bitHuman Examples

Real-time avatar animation — audio in, lip-synced video out at 25 FPS. Pick your path below based on what you're building.

Full documentation at **[docs.bithuman.ai](https://docs.bithuman.ai)**.

## Start here

> **New to bitHuman?** Run one of the [quickstart/](quickstart/) examples in under 2 minutes, then pick a full stack below.

## Choose your path

| I want to... | Go to | What you need |
|---|---|---|
| Try it in 2 minutes | [quickstart/](quickstart/) | API key only |
| Add a talking avatar to my web app | [cloud/essence-livekit/](cloud/essence-livekit/) | API key + agent ID |
| Use any face image as avatar (cloud) | [cloud/expression-livekit/](cloud/expression-livekit/) | API key + face image |
| Call the REST API from any language | [cloud/rest-api/](cloud/rest-api/) | API key |
| Run Essence on my own server (CPU) | [self-hosted/essence-cpu/](self-hosted/essence-cpu/) | API key + `.imx` file |
| Run Expression on NVIDIA GPU | [self-hosted/expression-gpu/](self-hosted/expression-gpu/) | NVIDIA GPU 8 GB+ VRAM |
| Run Expression on Mac M3+ (Python) | [self-hosted/expression-apple/](self-hosted/expression-apple/) | Apple Silicon M3+ |
| Build a native Mac/iPad/iPhone app | [swift/](swift/) | Apple Silicon M3+/M4+ |
| Run 100% offline on a Mac | [integrations/offline-mac/](integrations/offline-mac/) | Apple Silicon M2+ |
| Just render a video file | [quickstart/generate-video.sh](quickstart/generate-video.sh) | API key + `.imx` file |

## Two models

| | **Essence** | **Expression** |
|---|---|---|
| **What** | Pre-rendered avatar from photo/video | AI-generated facial animation from any face image |
| **Compute** | CPU only (any platform) | NVIDIA GPU **or** Apple Silicon M3+ |
| **Avatar source** | `.imx` model file from [bithuman.ai](https://www.bithuman.ai/#explore) | Any face image (JPG/PNG) |
| **Features** | Gestures, animal mode, full body, no idle timeout | Dynamic face swap, identity change mid-session |
| **Best for** | Kiosks, edge devices, voice agents, 24/7 displays | Custom faces, native apps, dynamic characters |

See [docs.bithuman.ai/getting-started/models](https://docs.bithuman.ai/getting-started/models) for the full comparison.

## Directory layout

```
Examples/
├── quickstart/              Try bitHuman in under 2 minutes
│
├── cloud/                   bitHuman hosts the avatar (no GPU needed)
│   ├── essence-livekit/         Essence via LiveKit plugin + Docker
│   ├── expression-livekit/      Expression via LiveKit plugin + Docker
│   └── rest-api/                HTTP-only: generate, speak, manage agents
│
├── self-hosted/             You host the avatar (full control)
│   ├── essence-cpu/             Essence on any machine (Linux/Mac/Win/RPi)
│   ├── expression-gpu/          Expression on Linux + NVIDIA GPU
│   ├── expression-gpu-livekit-cloud/  Same but WebRTC via LiveKit Cloud
│   └── expression-apple/        Expression on macOS M3+ (Python SDK)
│
├── swift/                   Native Apple apps (Mac/iPad/iPhone)
│
└── integrations/            Connect bitHuman to your stack
    ├── nextjs-ui/               Drop-in Next.js LiveKit frontend
    ├── java-websocket/          Java WebSocket client
    ├── gradio-web/              Gradio + FastRTC browser UI
    └── offline-mac/             100% offline: Ollama + Apple Speech
```

## Quick start

```bash
git clone https://github.com/bithuman-product/bithuman-sdk-public.git
cd bithuman-sdk-public/Examples/quickstart
```

Each example has its own README with prerequisites and a one-command run path.

## Get an API key

Sign in at [www.bithuman.ai](https://www.bithuman.ai) → Developer → API Keys. Set `BITHUMAN_API_SECRET` for Python/REST/LiveKit, or `BITHUMAN_API_KEY` for the Swift SDK.

Free tier: 99 credits/month (~50 minutes of cloud Essence). See [pricing](https://docs.bithuman.ai/getting-started/pricing).

## Documentation

- [Getting started](https://docs.bithuman.ai/getting-started/quickstart) (Python) / [Swift SDK](https://docs.bithuman.ai/swift-sdk/quickstart) (Apple)
- [REST API reference](https://docs.bithuman.ai/api-reference/overview)
- [Authentication](https://docs.bithuman.ai/getting-started/authentication) / [Pricing](https://docs.bithuman.ai/getting-started/pricing)
- [llms.txt](https://docs.bithuman.ai/llms.txt) / [llms-full.txt](https://docs.bithuman.ai/llms-full.txt) / [openapi.yaml](https://docs.bithuman.ai/api-reference/openapi.yaml)

## Resources

- [Platform dashboard](https://www.bithuman.ai) / [API keys](https://www.bithuman.ai/#developer)
- [Python SDK (PyPI)](https://pypi.org/project/bithuman/) / [Discord](https://discord.gg/ES953n7bPA) / [Status](https://status.bithuman.ai)

## License

MIT for example code. The bitHuman SDK and model weights are governed by the [bitHuman Terms of Service](https://www.bithuman.ai/terms).
