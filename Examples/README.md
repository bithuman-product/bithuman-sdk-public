# bitHuman Examples

Working code you can run. Each example is self-contained — pick one, follow its README, and you'll have a talking avatar running.

## Where to start

**If you've never used bitHuman before**, follow this path:

1. Get your API key at [www.bithuman.ai](https://www.bithuman.ai) → Developer → API Keys (30 seconds, free)
2. Run one of the [quickstart/](quickstart/) scripts (5 minutes)
3. Pick a full example from the table below based on what you're building

## Pick your example

### By what you're building

| I want to... | Example | What you need |
|---|---|---|
| **Just see it work** | [quickstart/](quickstart/) | API key |
| **Web app, fastest path** | [python/cloud-essence/](python/cloud-essence/) | API key + agent ID |
| **Web app with any face as avatar** | [python/cloud-expression/](python/cloud-expression/) | API key + face image |
| **Run on my own server (CPU only)** | [python/local-essence/](python/local-essence/) | API key + `.imx` model file |
| **Run on my own NVIDIA GPU** | [python/local-expression-gpu/](python/local-expression-gpu/) | API key + NVIDIA GPU (8 GB+ VRAM) |
| **Run on Mac M3+ (Python)** | [python/local-expression-mac/](python/local-expression-mac/) | API key + Mac with M3 or newer |
| **Build a Mac app (Swift)** | [swift/macos-avatar/](swift/macos-avatar/) | API key + Xcode 26 + Mac M3+ |
| **Build an iPhone/iPad app** | [swift/ios-avatar/](swift/ios-avatar/) | API key + Xcode 26 + iPhone 16 Pro or iPad Pro M4 |
| **Use the command line (no code)** | [cli/](cli/) | API key |
| **Call from Java, Go, or any language** | [rest-api/curl/](rest-api/curl/) | API key |
| **100% offline on Mac** | [integrations/offline-mac/](integrations/offline-mac/) | Mac with M2 or newer |

### By SDK / language

| SDK | Examples | Description |
|-----|----------|-------------|
| [python/](python/) | 6 examples | Cloud-hosted and self-hosted avatars using the Python SDK |
| [swift/](swift/) | 4 examples | Native Mac, iPad, and iPhone apps using the Swift SDK |
| [cli/](cli/) | 3 scripts | Shell scripts — render videos, stream, Mac desktop app |
| [rest-api/](rest-api/) | 7 curl + 6 Python | HTTP API calls that work from any programming language |
| [integrations/](integrations/) | 4 projects | Next.js frontend, Java client, Gradio UI, offline Mac |

## Recommended learning path (Python)

If you want to understand bitHuman deeply, follow these examples in order:

1. **[quickstart/local-avatar.py](quickstart/local-avatar.py)** — The simplest possible thing: load a model, push audio, see frames. ~25 lines.
2. **[python/local-essence/quickstart.py](python/local-essence/quickstart.py)** — Same idea but with OpenCV display and real-time playback.
3. **[python/local-essence/microphone.py](python/local-essence/microphone.py)** — Feed your microphone into the avatar in real time.
4. **[python/local-essence/conversation.py](python/local-essence/conversation.py)** — Full AI conversation: you speak, OpenAI thinks, the avatar replies.
5. **[python/cloud-essence/](python/cloud-essence/)** — Docker Compose stack with LiveKit, OpenAI, and a web UI.

## How authentication works

You need an API key to use bitHuman. It's free to sign up (99 credits/month, no credit card).

1. Go to [www.bithuman.ai](https://www.bithuman.ai) and create an account
2. Click **Developer** → **API Keys** and copy your secret

Then set it as an environment variable before running any example:

```bash
# For Python, CLI, and REST API examples:
export BITHUMAN_API_SECRET="paste_your_key_here"

# For Swift examples (different variable name, same key):
export BITHUMAN_API_KEY="paste_your_key_here"
```

> **Why two different variable names?** The Python SDK was built first and used `BITHUMAN_API_SECRET`. The Swift SDK came later and uses `BITHUMAN_API_KEY`. They're the same credential from the same dashboard — just different names for historical reasons. We know it's confusing. Use the right one for your SDK.

## Two avatar models

bitHuman offers two ways to create avatars:

**Essence** (recommended for beginners)
- You upload a photo or video on [bithuman.ai](https://www.bithuman.ai/#explore), and it generates a `.imx` model file
- Download the `.imx` file and use it in your code
- Runs on any CPU — no GPU needed
- Costs 1 credit/min (self-hosted) or 2 credits/min (cloud)

**Expression** (advanced — for dynamic faces)
- Provide any face image (JPG/PNG) at runtime — no generation step
- The avatar is created on-the-fly from the image
- Requires an NVIDIA GPU or Mac with M3+ chip
- Costs 2 credits/min (self-hosted) or 4 credits/min (cloud)

Full comparison: [docs.bithuman.ai/getting-started/models](https://docs.bithuman.ai/getting-started/models)

## Pricing

| What | Cost |
|------|------|
| Free tier | 99 credits/month (no credit card) |
| Essence, you host the avatar | 1 credit per minute |
| Essence, bitHuman hosts it | 2 credits per minute |
| Expression, you host the avatar | 2 credits per minute |
| Expression, bitHuman hosts it | 4 credits per minute |
| Generate a new avatar agent | 250 credits (one-time) |

1 credit = roughly 1 minute of avatar time. [Full pricing details](https://docs.bithuman.ai/getting-started/pricing)

## Directory structure

```
Examples/
├── quickstart/                  Your first demo (start here)
│   ├── cloud-avatar.py              Cloud avatar via LiveKit + OpenAI
│   └── local-avatar.py              Local avatar from .imx file + audio
│
├── python/                      Python SDK examples
│   ├── cloud-essence/               bitHuman hosts the avatar (easiest)
│   ├── cloud-expression/            bitHuman hosts it, any face image
│   ├── local-essence/               You host, any CPU
│   ├── local-expression-gpu/        You host, NVIDIA GPU required
│   ├── local-expression-mac/        You host, Mac M3+ required
│   └── local-expression-gpu-livekit-cloud/  You host GPU, LiveKit Cloud for WebRTC
│
├── swift/                       Swift SDK for Apple devices
│   ├── macos-voice/                 Voice-only agent on Mac (free, no API key)
│   ├── macos-avatar/                Voice + animated face on Mac
│   ├── ios-avatar/                  iPhone/iPad with hardware checks
│   └── essence-playback/            Play .imx files on Apple devices
│
├── cli/                         Command-line tools (no programming needed)
│   ├── render-video.sh              Turn .imx + audio into an MP4 video
│   ├── live-stream.sh               Start a live avatar streaming server
│   └── mac-app.sh                   Install the Mac desktop app via Homebrew
│
├── rest-api/                    HTTP API (works from any language)
│   ├── curl/                        One shell script per API endpoint
│   │   ├── validate.sh                  Check if your API key works
│   │   ├── speak.sh                     Make an avatar speak text
│   │   ├── generate-agent.sh            Create a new avatar from scratch
│   │   ├── add-context.sh               Give the avatar background knowledge
│   │   ├── list-agents.sh               Get info about an avatar
│   │   ├── upload-file.sh               Upload an image/video/audio
│   │   └── check-credits.sh             Check your credit balance
│   └── python/                      Same operations as Python scripts
│
└── integrations/                Connect bitHuman to existing tools
    ├── nextjs-ui/                   Ready-made web interface (Next.js + LiveKit)
    ├── java-websocket/              Java client for streaming avatar frames
    ├── gradio-web/                  Browser-based UI with Gradio
    └── offline-mac/                 100% offline Mac setup (Ollama + Apple Speech)
```

## Documentation

- **Getting started**: [Python quickstart](https://docs.bithuman.ai/getting-started/quickstart) | [Swift quickstart](https://docs.bithuman.ai/swift-sdk/quickstart)
- **API reference**: [REST API](https://docs.bithuman.ai/api-reference/overview) | [OpenAPI spec](https://docs.bithuman.ai/api-reference/openapi.yaml)
- **Guides**: [Authentication](https://docs.bithuman.ai/getting-started/authentication) | [Pricing](https://docs.bithuman.ai/getting-started/pricing) | [Models](https://docs.bithuman.ai/getting-started/models)

## Get help

- [GitHub Issues](https://github.com/bithuman-product/bithuman-sdk-public/issues) — bug reports and feature requests
- [Discord](https://discord.gg/ES953n7bPA) — community chat
- [docs.bithuman.ai](https://docs.bithuman.ai) — full documentation

## License

MIT for example code. The bitHuman SDK and model weights are governed by the [bitHuman Terms of Service](https://www.bithuman.ai/terms).
