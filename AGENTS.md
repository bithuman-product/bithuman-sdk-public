# bitHuman SDK -- AI Agent Discovery

bitHuman is a real-time avatar animation platform. You push audio in, and get lip-synced video frames out at 25 FPS. Two avatar models are available: Essence (CPU, pre-built `.imx` files) and Expression (GPU or Apple Silicon M3+, any face image). Integration surfaces include a Python SDK, a Swift SDK (Apple native), a CLI, and a REST API. All require an API secret from [www.bithuman.ai](https://www.bithuman.ai/#developer).

## SDK / Tool Decision Tree

| User goal | Recommended path | Package / tool | Example directory |
|---|---|---|---|
| Web app, fastest demo | Cloud Essence (LiveKit plugin) | `pip install livekit-plugins-bithuman` | `Examples/python/cloud-essence/` |
| Web app, custom face image | Cloud Expression (LiveKit plugin) | `pip install livekit-plugins-bithuman` | `Examples/python/cloud-expression/` |
| Kiosk / 24-7 / edge box | Self-hosted Essence (CPU) | `pip install bithuman` | `Examples/python/local-essence/` |
| On-prem NVIDIA GPU | Self-hosted Expression (Docker) | `docker pull bithuman/expression-avatar:latest` | `Examples/python/local-expression-gpu/` |
| macOS / iPad / iPhone app | Swift SDK (on-device) | SwiftPM `bithuman-sdk-public` >= 0.8.1 | `Examples/swift/` |
| Mac, no code | CLI | `curl -fsSL https://github.com/bithuman-product/bithuman-sdk-public/releases/latest/download/install.sh \| sh` | `Examples/cli/` |
| Any language, HTTP only | REST API | `curl https://api.bithuman.ai/v1/...` | `Examples/rest-api/` |
| 100% offline Mac | Ollama + Apple Speech + bitHuman | -- | `Examples/integrations/offline-mac/` |
| Browser embed (iframe) | Embed widget | `bithuman-chat-widget-v5.js` | See docs: [embed](https://docs.bithuman.ai/integrations/embed) |

## Quick Setup Per Path

### Python SDK (local Essence)

```bash
pip install bithuman --upgrade
export BITHUMAN_API_SECRET=your_secret
# Download an .imx from https://www.bithuman.ai/#explore
python -c "
import asyncio, os
from bithuman import AsyncBithuman
async def main():
    rt = await AsyncBithuman.create(model_path='avatar.imx', api_secret=os.environ['BITHUMAN_API_SECRET'])
    await rt.stop()
asyncio.run(main())
"
```

### Python SDK (cloud via LiveKit plugin)

```bash
pip install livekit-plugins-bithuman
export BITHUMAN_API_SECRET=your_secret
# See Examples/python/cloud-essence/ for a full LiveKit agent
```

### Swift SDK (Apple native)

```swift
// Package.swift
.package(url: "https://github.com/bithuman-product/bithuman-sdk-public.git", from: "0.8.1")

// In code:
import bitHumanKit
// Set BITHUMAN_API_KEY env var or pass via config
```

### CLI (no code)

```bash
# Universal installer (macOS + Linux)
curl -fsSL https://github.com/bithuman-product/bithuman-sdk-public/releases/latest/download/install.sh | sh
# Or macOS Homebrew
brew install bithuman-product/bithuman/bithuman

bithuman avatar      # browser-served avatar at http://127.0.0.1:8080
bithuman voice       # spoken conversation in the terminal
```

### REST API

```bash
curl -X POST https://api.bithuman.ai/v1/agent/A91XMB7113/speak \
  -H "api-secret: YOUR_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello world"}'
```

## API Surface Summary

### Python SDK (`pip install bithuman`)

| Class / Function | Purpose |
|---|---|
| `AsyncBithuman.create(model_path, api_secret)` | Create async runtime (Essence or Expression) |
| `Bithuman.create(model_path, api_secret)` | Create sync/threaded runtime |
| `runtime.push_audio(pcm_bytes, sample_rate)` | Push int16 PCM audio (any sample rate, auto-resampled) |
| `runtime.flush()` | Signal end of current audio segment |
| `runtime.interrupt()` | Cancel current playback immediately |
| `runtime.run()` | Async iterator yielding `VideoFrame` objects |
| `runtime.push(VideoControl(action="wave"))` | Trigger gesture (Essence only) |
| `runtime.set_identity("face.jpg")` | Swap face mid-session (Expression only) |
| `runtime.stop()` | Shut down cleanly |
| `frame.bgr_image` | `np.ndarray` (H, W, 3) uint8 BGR |
| `frame.audio_chunk` | Synchronized audio output |
| `frame.has_image` | Whether this frame contains an image |
| `frame.end_of_speech` | Whether this is the last frame of the segment |
| `load_audio(path)` | Returns `(float32_pcm, sample_rate)` |
| `float32_to_int16(pcm)` | Convert float32 PCM to int16 |

### LiveKit Plugin (`pip install livekit-plugins-bithuman`)

| Class | Purpose |
|---|---|
| `bithuman.AvatarSession` | Managed cloud session (Essence or Expression) |
| `LocalAvatarRunner` | Self-hosted LiveKit integration |
| `LocalVideoPlayer` | Local video output window |
| `LocalAudioIO` | Local audio I/O bridge |

### Swift SDK (`bitHumanKit`)

| Type | Purpose |
|---|---|
| `BitHuman` | Main entry point -- configure, start, stop |
| `VoiceAgent` | Audio-only voice agent (STT + LLM + TTS) |
| `AvatarView` | SwiftUI view for lip-synced avatar |
| `HardwareCheck.evaluate()` | Runtime hardware gate (M3+ Mac, M4+ iPad, A18 Pro+ iPhone) |

### REST API (`https://api.bithuman.ai`)

All requests require `api-secret: YOUR_SECRET` header.

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/v1/validate` | Verify API secret is valid |
| POST | `/v1/agent/generate` | Create agent from prompt + image/video/audio |
| GET | `/v1/agent/status/{agent_id}` | Poll generation progress (processing -> ready/failed) |
| GET | `/v1/agent/{code}` | Get agent details |
| POST | `/v1/agent/{code}` | Update agent system prompt |
| POST | `/v1/agent/{code}/speak` | Make avatar say text in live session |
| POST | `/v1/agent/{code}/add-context` | Inject silent knowledge into session |
| POST | `/v1/files/upload` | Upload image/video/audio (URL or base64) |
| GET | `/v2/credit-summaries` | Check credit balance and plan |
| POST | `/v1/embed-tokens/request` | Generate JWT for iframe embed |
| POST | `/v1/dynamics/generate` | Create gesture animations |
| GET | `/v1/dynamics/{agent_id}` | List available gestures |

### CLI (`bithuman` — install via `curl|sh` or Homebrew, not pip)

| Command | Purpose |
|---|---|
| `bithuman doctor` | Verify host + API key |
| `bithuman avatar` | Browser-served avatar at `http://127.0.0.1:8080` |
| `bithuman voice` | Spoken conversation in the terminal |
| `bithuman text` | Text chat, stdin → stdout |
| `bithuman generate <model> --audio <file> -o out.mp4` | Render lip-synced MP4 |
| `bithuman stream <model>` | Start local HTTP streaming server |
| `bithuman speak <audio>` | Send audio to a running stream server |
| `bithuman info <model>` | Show `.imx` model metadata |
| `bithuman models list` | List downloadable showcase avatars |

## Common Patterns

### Pattern 1: Push audio, get frames (core loop)

```python
pcm, sr = load_audio("speech.wav")
pcm = float32_to_int16(pcm)
chunk = sr // 25  # one chunk per video frame
for i in range(0, len(pcm), chunk):
    await runtime.push_audio(pcm[i : i + chunk].tobytes(), sr)
await runtime.flush()

async for frame in runtime.run():
    if frame.has_image:
        cv2.imshow("avatar", frame.bgr_image)
    if frame.end_of_speech:
        break
```

### Pattern 2: LiveKit cloud plugin (web app)

```python
from livekit.plugins.bithuman import AvatarSession

session = AvatarSession(
    avatar_id="A91XMB7113",       # agent code from dashboard
    api_secret=os.environ["BITHUMAN_API_SECRET"],
)
# Connect to LiveKit room, push TTS audio, get video track
```

### Pattern 3: REST speak (make avatar talk)

```bash
curl -X POST https://api.bithuman.ai/v1/agent/A91XMB7113/speak \
  -H "api-secret: $BITHUMAN_API_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"text": "Welcome to the demo"}'
```

### Pattern 4: Generate agent (REST)

```bash
# Start generation
curl -X POST https://api.bithuman.ai/v1/agent/generate \
  -H "api-secret: $BITHUMAN_API_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "A friendly fitness coach", "image": "https://example.com/face.jpg"}'

# Poll until ready (every 5s)
curl https://api.bithuman.ai/v1/agent/status/A91XMB7113 \
  -H "api-secret: $BITHUMAN_API_SECRET"
```

### Pattern 5: Expression identity swap (macOS M3+)

```python
runtime = await AsyncBithuman.create(
    model_path="expression.imx",
    api_secret=os.environ["BITHUMAN_API_SECRET"],
    identity="alice.jpg",
    quality="medium",
)
# Later, swap face mid-session:
await runtime.set_identity("bob.jpg")       # ~300ms
await runtime.set_identity("bob.npy")       # instant (pre-encoded)
```

## Repository Layout

There are two repos relevant to Apple-platform development:

| Repo | Visibility | What it contains |
|------|-----------|------------------|
| **bithuman-sdk-public** | Public | SwiftPM binary package, Python SDK metadata, runnable examples, docs.bithuman.ai source |
| **bithuman-apps** | Private | Reference apps (Mac, iPad, iPhone) that consume the SDK via the published SwiftPM binary — the same way any external developer would |

Reference apps do **not** live inside bithuman-sdk-public. They are in the separate `bithuman-apps` repo and depend on the SDK as a normal SwiftPM consumer.

### bithuman-sdk-public

```
bithuman-sdk-public/
├── AGENTS.md                 <-- You are here (AI agent discovery)
├── CLAUDE.md                 Claude Code instructions
├── .cursorrules              Cursor AI rules
├── .github/
│   └── copilot-instructions.md  GitHub Copilot instructions
├── Package.swift             SwiftPM manifest (must be at root)
├── README.md                 Human-facing readme
├── CONTRIBUTING.md           How to contribute
├── SECURITY.md               Security policy
├── python/                   Python SDK public surface
│   ├── README.md             PyPI package docs
│   ├── CHANGELOG.md          Release history
│   └── LICENSE.md
├── swift/                    Swift SDK public surface
│   ├── README.md             Swift SDK docs
│   ├── CHANGELOG.md          Release history
│   └── LICENSE.md
├── Examples/
│   ├── AGENTS.md             Examples-specific agent guide
│   ├── README.md             Examples index
│   ├── quickstart/           Try bitHuman in 2 minutes
│   ├── python/
│   │   ├── cloud-essence/        Cloud Essence via LiveKit
│   │   ├── cloud-expression/     Cloud Expression via LiveKit
│   │   ├── local-essence/        CPU-only local Essence
│   │   ├── local-expression-gpu/ NVIDIA GPU Docker
│   │   ├── local-expression-mac/ macOS M3+ Python
│   │   └── local-expression-gpu-livekit-cloud/
│   ├── swift/
│   │   ├── macos-voice/          macOS audio-only voice agent
│   │   ├── macos-avatar/         macOS voice + avatar
│   │   ├── ios-avatar/           iOS/iPadOS
│   │   └── essence-playback/     Essence .imx on Apple Silicon
│   ├── cli/                  Shell scripts for CLI tools
│   ├── rest-api/
│   │   ├── curl/             Per-endpoint curl scripts
│   │   └── python/           Full Python scripts
│   └── integrations/
│       ├── nextjs-ui/        Next.js LiveKit frontend
│       ├── java-websocket/   Java WebSocket client
│       ├── gradio-web/       Gradio + FastRTC browser UI
│       └── offline-mac/      100% offline macOS stack
└── docs/                     docs.bithuman.ai source (Mintlify)
    ├── docs.json             Mintlify config
    ├── llms.txt              LLM-oriented index
    ├── llms-full.txt         Full LLM-oriented docs
    ├── api-reference/
    │   └── openapi.yaml      OpenAPI 3.1 spec
    ├── getting-started/
    ├── deployment/
    ├── swift-sdk/
    ├── examples/
    └── integrations/
```

## Key Links

| Resource | URL |
|---|---|
| Documentation | https://docs.bithuman.ai |
| API keys | https://www.bithuman.ai/#developer |
| OpenAPI spec | https://docs.bithuman.ai/api-reference/openapi.yaml |
| LLM-optimized docs | https://docs.bithuman.ai/llms.txt |
| Full LLM docs | https://docs.bithuman.ai/llms-full.txt |
| Python SDK (PyPI) | https://pypi.org/project/bithuman/ |
| Swift SDK (SwiftPM) | https://github.com/bithuman-product/bithuman-sdk-public |
| Examples | https://github.com/bithuman-product/bithuman-sdk-public/tree/main/Examples |
| Discord | https://discord.gg/ES953n7bPA |
| Status page | https://status.bithuman.ai |

## What NOT To Do

- **The SDK internals are closed-source.** Consume the binary distributions only: SwiftPM `bithuman-sdk-public` for Swift, `pip install bithuman` for Python, Maven `ai.bithuman:sdk` for Kotlin, the CLI installer for the binary. Do not attempt to fetch SDK source.
- **Do NOT hardcode API keys** in source files. Always use environment variables (`BITHUMAN_API_SECRET` for Python/REST/CLI, `BITHUMAN_API_KEY` for Swift).
- **Do NOT pin Swift SDK below 0.8.1** -- earlier versions have breaking API changes.
- **Do NOT use `figure_id`** -- it is deprecated. Use `agent_code` everywhere.
- **Do NOT use `BITHUMAN_API_KEY` in Python code** -- use `BITHUMAN_API_SECRET`. The `_API_KEY` name is a legacy alias.
- **Do NOT try to run Expression models on CPU** -- they require NVIDIA GPU or Apple Silicon M3+. The SDK raises `ExpressionModelNotSupported`, not a crash, but your code should handle it.
- **Do NOT poll agent generation status faster than every 5 seconds**.

## Pricing

| Model | Self-hosted | Cloud |
|---|---|---|
| Essence | 1 cr/min | 2 cr/min |
| Expression | 2 cr/min | 4 cr/min |
| Agent generation | 250 cr (one-time) | -- |
| Free tier | 99 cr/month (no card required) | -- |

Check balance: `GET https://api.bithuman.ai/v2/credit-summaries` with `api-secret` header.

## Environment Variables

| Variable | Used by | Purpose |
|---|---|---|
| `BITHUMAN_API_SECRET` | Python, REST, CLI, LiveKit | Primary API credential |
| `BITHUMAN_API_KEY` | Swift SDK | API credential for Apple platforms |
| `BITHUMAN_RUNTIME_TOKEN` | Python | Pre-minted JWT (alternative to API secret) |
| `BITHUMAN_VERBOSE` | Python | Enable debug logging |

## Two Models Compared

| | Essence | Expression |
|---|---|---|
| Compute | CPU only (any platform) | NVIDIA GPU or Apple Silicon M3+ |
| Avatar source | Pre-built `.imx` from dashboard | Any face image (JPG/PNG) |
| Build step | Yes (generate on dashboard, ~3 min) | None (provide face image at runtime) |
| Gestures | Yes (wave, nod, etc.) | No |
| Identity swap | No (baked into `.imx`) | Yes (`set_identity()`) |
| Best for | Kiosks, edge, 24/7, voice agents | Custom faces, native apps, dynamic |
