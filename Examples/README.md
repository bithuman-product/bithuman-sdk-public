# bitHuman Examples

Real-time avatar animation — audio in, lip-synced video out at 25 FPS. Pick your SDK/tool below.

Full documentation at **[docs.bithuman.ai](https://docs.bithuman.ai)**.

## Choose your path

| I want to... | Go to |
|---|---|
| Try it in 2 minutes (any path) | [quickstart/](quickstart/) |
| Build with Python (local or cloud) | [python/](python/) |
| Build a native Mac/iPad/iPhone app | [swift/](swift/) |
| Use the CLI (no code) | [cli/](cli/) |
| Call the HTTP API from any language | [rest-api/](rest-api/) |
| Connect to an existing stack | [integrations/](integrations/) |

## Directory layout

```
Examples/
├── quickstart/                  Try bitHuman in under 2 minutes
│
├── python/                      Python SDK examples (progressive)
│   ├── cloud-essence/               Cloud Essence via LiveKit plugin
│   ├── cloud-expression/            Cloud Expression via LiveKit plugin
│   ├── local-essence/               Essence on any machine (CPU)
│   ├── local-expression-gpu/        Expression on NVIDIA GPU (Docker)
│   ├── local-expression-mac/        Expression on macOS M3+ (Python)
│   └── local-expression-gpu-livekit-cloud/  GPU + LiveKit Cloud WebRTC
│
├── swift/                       Swift SDK for Apple platforms
│   ├── macos-voice/                 macOS voice agent (audio only)
│   ├── macos-avatar/                macOS voice + lip-synced avatar
│   ├── ios-avatar/                  iOS/iPadOS with hardware gate
│   └── essence-playback/            Essence .imx on Apple Silicon
│
├── cli/                         Command-line tools (no code)
│   ├── render-video.sh              Render .imx + audio → MP4
│   ├── live-stream.sh               Start local streaming server
│   └── mac-app.sh                   bithuman-cli Homebrew Mac app
│
├── rest-api/                    HTTP API (any language)
│   ├── curl/                        Individual curl scripts per endpoint
│   └── python/                      Full Python scripts
│
└── integrations/                Framework bridges
    ├── nextjs-ui/                   Next.js LiveKit frontend
    ├── java-websocket/              Java WebSocket client
    ├── gradio-web/                  Gradio + FastRTC browser UI
    └── offline-mac/                 100% offline macOS stack
```

## Two models

| | **Essence** | **Expression** |
|---|---|---|
| **What** | Pre-rendered avatar from photo/video | AI-generated animation from any face image |
| **Compute** | CPU only (any platform) | NVIDIA GPU **or** Apple Silicon M3+ |
| **Avatar source** | `.imx` file from [bithuman.ai](https://www.bithuman.ai/#explore) | Any face image (JPG/PNG) |
| **Best for** | Kiosks, edge devices, 24/7 displays | Custom faces, native apps, dynamic characters |

Full comparison: [docs.bithuman.ai/getting-started/models](https://docs.bithuman.ai/getting-started/models)

## Get an API key

Sign in at [www.bithuman.ai](https://www.bithuman.ai) → Developer → API Keys.

- Python / REST / CLI: set `BITHUMAN_API_SECRET`
- Swift SDK: set `BITHUMAN_API_KEY`

Free tier: 99 credits/month (~50 min cloud Essence). See [pricing](https://docs.bithuman.ai/getting-started/pricing).

## Documentation

- [Getting started](https://docs.bithuman.ai/getting-started/quickstart) (Python) / [Swift SDK](https://docs.bithuman.ai/swift-sdk/quickstart) (Apple)
- [REST API](https://docs.bithuman.ai/api-reference/overview) / [OpenAPI spec](https://docs.bithuman.ai/api-reference/openapi.yaml)
- [Pricing](https://docs.bithuman.ai/getting-started/pricing) / [Authentication](https://docs.bithuman.ai/getting-started/authentication)

## Resources

- [Platform dashboard](https://www.bithuman.ai) / [API keys](https://www.bithuman.ai/#developer)
- [Python SDK (PyPI)](https://pypi.org/project/bithuman/) / [Discord](https://discord.gg/ES953n7bPA)

## License

MIT for example code. The bitHuman SDK and model weights are governed by the [bitHuman Terms of Service](https://www.bithuman.ai/terms).
