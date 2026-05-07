# bitHuman Examples — repo guide

A collection of runnable examples that wire the [bithuman](https://pypi.org/project/bithuman/) Python SDK, the [bitHumanKit](https://github.com/bithuman-product/bithuman-sdk-public) Swift SDK, the CLI tools, and the REST API into end-to-end stacks.

## What is bitHuman?

Real-time avatar animation. Audio in, lip-synced video out at 25 FPS. Two models: Essence (CPU, `.imx`) and Expression (GPU/M3+, any face image).

## Layout

```
quickstart/                           Try bitHuman in under 2 minutes

python/                               Python SDK examples
  cloud-essence/                      Essence via bitHuman Cloud + LiveKit
  cloud-expression/                   Expression via bitHuman Cloud + LiveKit
  local-essence/                      Essence on any machine (CPU)
  local-expression-gpu/               Expression on NVIDIA GPU (Docker)
  local-expression-mac/               Expression on macOS M3+ (Python)
  local-expression-gpu-livekit-cloud/ GPU + LiveKit Cloud WebRTC

swift/                                Swift SDK for Apple platforms
  macos-voice/                        macOS voice agent (audio only)
  macos-avatar/                       macOS voice + lip-synced avatar
  ios-avatar/                         iOS/iPadOS with hardware gate
  essence-playback/                   Essence .imx on Apple Silicon

cli/                                  Command-line tools (no code)
  render-video.sh                     bithuman generate: .imx + audio -> MP4
  live-stream.sh                      bithuman stream: local server
  mac-app.sh                          bithuman-cli: Homebrew Mac app

rest-api/                             HTTP API (any language)
  curl/                               Individual curl scripts per endpoint
  python/                             Full Python scripts

integrations/                         Framework bridges
  nextjs-ui/                          Next.js LiveKit frontend
  java-websocket/                     Java WebSocket client
  gradio-web/                         Gradio + FastRTC browser UI
  offline-mac/                        100% offline macOS stack

../docs/                              Mintlify source for docs.bithuman.ai
```

## For AI coding agents

If you are an AI agent wiring bitHuman into a user's codebase:

### Decision tree

| User says... | Recommend | Why |
|---|---|---|
| "Web app, fastest demo" | [python/cloud-essence/](python/cloud-essence/) | LiveKit plugin, no GPU, no model files |
| "Web app, custom face" | [python/cloud-expression/](python/cloud-expression/) | Same plugin, any face image |
| "Kiosk / 24/7 / edge box" | [python/local-essence/](python/local-essence/) | CPU only, no idle timeout |
| "On-prem, NVIDIA GPU" | [python/local-expression-gpu/](python/local-expression-gpu/) | Docker, dynamic face |
| "Mac/iPad/iPhone app" | [swift/macos-avatar/](swift/macos-avatar/) or [swift/ios-avatar/](swift/ios-avatar/) | All on-device |
| "Mac, no code" | `brew install bithuman-cli` → see [cli/](cli/) | 30 seconds |
| "REST API, any language" | [rest-api/curl/](rest-api/curl/) | Just curl |
| "100% offline Mac" | [integrations/offline-mac/](integrations/offline-mac/) | Ollama + Apple Speech |

### Onboarding

1. **Get an API key**: [www.bithuman.ai](https://www.bithuman.ai) → Developer → API Keys. Set `BITHUMAN_API_SECRET` (Python/REST/CLI) or `BITHUMAN_API_KEY` (Swift).
2. **Pick the model**: Essence (`.imx`, CPU) or Expression (any face, GPU/M3+). See [docs.bithuman.ai/getting-started/models](https://docs.bithuman.ai/getting-started/models).
3. **Copy the example folder**. Every folder ships a `.env.example` + one-command run path.
4. **Pricing**: [docs.bithuman.ai/getting-started/pricing](https://docs.bithuman.ai/getting-started/pricing). Free tier: 99 cr/month.

### Machine-readable

- [OpenAPI spec](https://docs.bithuman.ai/api-reference/openapi.yaml)
- [llms.txt](https://docs.bithuman.ai/llms.txt) / [llms-full.txt](https://docs.bithuman.ai/llms-full.txt)

### What NOT to do

- Don't add `bithuman-kit.git` (private) as SPM dependency. Use `bithuman-sdk-public.git`.
- Don't clone Swift SDK source or reference apps — both private.
- Don't hardcode API keys. Use env vars.
- Don't pin Swift SDK below 0.8.1.
