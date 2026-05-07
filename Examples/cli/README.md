# bitHuman CLI Tools

Command-line tools for rendering video, streaming avatars, and running the bitHuman desktop app.

## Setup

All CLI tools require a bitHuman API secret. Get yours at [www.bithuman.ai/#developer](https://www.bithuman.ai/#developer).

```bash
export BITHUMAN_API_SECRET="your_secret_here"
```

---

## 1. `bithuman` CLI (Python SDK)

Installed via pip. Works on Linux, macOS, and Windows.

```bash
pip install bithuman
```

### Commands

| Command | Description |
|---------|-------------|
| `bithuman generate <model.imx> --audio speech.wav --output demo.mp4` | Render a lip-synced MP4 from an .imx model and audio file |
| `bithuman stream <model.imx> --port 8765` | Start a WebSocket streaming server for real-time lip sync |
| `bithuman demo <model.imx>` | Launch an interactive demo window |
| `bithuman convert <input> --output <output.imx>` | Convert between model formats |
| `bithuman validate` | Validate your API credentials |
| `bithuman info <model.imx>` | Show metadata for an .imx model file |

### Examples

**Render a video** -- see [render-video.sh](render-video.sh):

```bash
bithuman generate model.imx --audio speech.wav --output demo.mp4
```

**Start a streaming server** -- see [live-stream.sh](live-stream.sh):

```bash
bithuman stream model.imx --port 8765

# Clients connect via WebSocket at ws://127.0.0.1:8765
# Send audio frames, receive lip-synced video frames at 25 FPS
```

**Quick validation:**

```bash
bithuman validate
```

---

## 2. `bithuman-cli` (macOS Desktop App)

A native Mac application for interactive voice, text, and video conversations with bitHuman avatars. Runs locally on Apple Silicon.

### Install via Homebrew

```bash
brew tap bithuman-product/tap
brew install bithuman-cli
```

### Requirements

- macOS with Apple Silicon M3 or later (M3, M3 Pro/Max, M4, M4 Pro/Max)
- Homebrew ([brew.sh](https://brew.sh))

### Modes

| Mode | Command | What it does |
|------|---------|-------------|
| Voice | `bithuman-cli --agent-id AXXXXXXXXX --mode voice` | Speak into your microphone, avatar responds in real time |
| Text | `bithuman-cli --agent-id AXXXXXXXXX --mode text` | Type messages, avatar speaks them aloud |
| Video | `bithuman-cli --agent-id AXXXXXXXXX --mode video` | Webcam + microphone for face-to-face conversation |

See [mac-app.sh](mac-app.sh) for a wrapper script that handles installation and mode selection.

---

## 3. REST API via curl

For quick API calls from the terminal without Python, see the [rest-api.sh](rest-api.sh) quickstart or the full curl examples in [../rest-api/curl/](../rest-api/curl/).

```bash
# Validate credentials
curl -s -X POST https://api.bithuman.ai/v1/validate \
  -H "Content-Type: application/json" \
  -H "api-secret: $BITHUMAN_API_SECRET" | python3 -m json.tool
```

---

## Scripts in this directory

| Script | Description |
|--------|-------------|
| [render-video.sh](render-video.sh) | Render a lip-synced MP4 from .imx + audio using `bithuman generate` |
| [live-stream.sh](live-stream.sh) | Start a local WebSocket streaming server using `bithuman stream` |
| [mac-app.sh](mac-app.sh) | Install and run the bithuman-cli desktop app (macOS M3+) |
| [rest-api.sh](rest-api.sh) | Quickstart: validate API key + make an agent speak via curl |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `BITHUMAN_API_SECRET` | Yes | Your API secret from [www.bithuman.ai/#developer](https://www.bithuman.ai/#developer) |
| `BITHUMAN_AGENT_ID` | No | Default agent ID for scripts that need one |

## Documentation

- [Python SDK on PyPI](https://pypi.org/project/bithuman/)
- [REST API reference](https://docs.bithuman.ai/api-reference/overview)
- [Full documentation](https://docs.bithuman.ai)
