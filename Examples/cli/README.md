# bitHuman CLI Tools

Command-line tools for rendering video, streaming an avatar, and
running voice / text / browser-avatar conversations — no code.

## Install

The `bithuman` command is a single self-contained binary, installed via
Homebrew or the universal one-liner. It is **not** the `pip install
bithuman` package (that ships the Python *SDK* plus an `essence-render`
console script — see the [Python examples](../python/)).

```bash
# macOS — Homebrew (recommended; pulls native deps).
brew install bithuman-product/bithuman/bithuman

# macOS / Linux — universal one-liner.
curl -fsSL https://github.com/bithuman-product/homebrew-bithuman/releases/latest/download/install.sh | sh
```

All commands need a bitHuman API secret. Get yours at
[www.bithuman.ai/#developer](https://www.bithuman.ai/#developer).

```bash
export BITHUMAN_API_SECRET="your_secret_here"
bithuman doctor      # verify host setup + API key presence
```

---

## Commands

| Command | Description |
|---------|-------------|
| `bithuman doctor` | Host capability check (arch, OS, RAM, disk, API key) |
| `bithuman generate <model.imx> --audio speech.wav --output demo.mp4` | Offline batch render an MP4 from a model + WAV |
| `bithuman avatar [--model <imx>]` | Browser-served avatar at `http://127.0.0.1:8080` |
| `bithuman voice` | Interactive voice chat (auto-picks cloud or `--local`) |
| `bithuman text` | Non-interactive text chat (stdin → stdout) |
| `bithuman stream [--model <imx>] [--port 3001]` | HTTP streaming avatar server |
| `bithuman speak <audio.wav> [--port 3001]` | POST a WAV to a running `stream` server |
| `bithuman action <name> [--port 3001]` | POST an action trigger (e.g. `wave`) to a `stream` server |
| `bithuman info <model.imx>` | Show metadata for an `.imx` model file |
| `bithuman asr <audio.wav>` | Transcribe a 16 kHz mono WAV (on-device Whisper) |
| `bithuman tts "<text>"` | Synthesize text to a 24 kHz mono WAV (offline) |
| `bithuman models list` / `pull` | Browse and download showcase avatars |
| `bithuman cleanup` | Wipe regenerable model caches under `~/.cache` |
| `bithuman --help` | Full list of commands and flags |

Run `bithuman <command> --help` for the full flag list of any command.

### Render a video — see [render-video.sh](render-video.sh)

```bash
bithuman generate model.imx --audio speech.wav --output demo.mp4
```

### Start a streaming server — see [live-stream.sh](live-stream.sh)

```bash
bithuman stream --model model.imx --port 3001

# HTTP endpoints (no WebSocket):
#   POST /audio       raw f32 PCM      GET  /video.mjpg   MJPEG video
#   POST /action      action trigger   GET  /status       server status
# Drive it from another shell:  bithuman speak clip.wav --port 3001
```

### Validate your API secret

There is no `bithuman validate` subcommand — use the REST endpoint:

```bash
curl -s -X POST https://api.bithuman.ai/v1/validate \
  -H "api-secret: $BITHUMAN_API_SECRET" | python3 -m json.tool
```

---

## Voice / text / browser-avatar conversations

The same `bithuman` binary runs full conversations locally — no agent
ID, no separate app. Models are `.imx` files, not agent IDs.

| Mode | Command | What it does |
|------|---------|-------------|
| Voice | `bithuman voice` | Speak into your mic; spoken reply, with transcript |
| Text | `bithuman text` | Type messages; the model replies as text |
| Browser avatar | `bithuman avatar` | Lip-synced avatar in your browser at `127.0.0.1:8080` |
| Server-side voice + avatar | `bithuman avatar --openai` | Mic + speakers locally, avatar in the browser |

`voice` and `text` auto-pick the **cloud** backend when
`OPENAI_API_KEY` is set (instant, no downloads) or fully **on-device**
with `--local` (≈5 GB first-run download, then offline). See
[mac-app.sh](mac-app.sh) for a thin wrapper.

```bash
export OPENAI_API_KEY=sk-...   # optional — enables the instant cloud path
bithuman voice                 # or:  bithuman voice --local
```

Requirements for the on-device modes: macOS Apple Silicon M3+ or
Linux x86_64 / aarch64.

---

## REST API via curl

For API calls from the terminal without Python, see
[rest-api.sh](rest-api.sh) or the full curl examples in
[../rest-api/curl/](../rest-api/curl/).

```bash
curl -s -X POST https://api.bithuman.ai/v1/validate \
  -H "Content-Type: application/json" \
  -H "api-secret: $BITHUMAN_API_SECRET" | python3 -m json.tool
```

---

## Scripts in this directory

| Script | Description |
|--------|-------------|
| [render-video.sh](render-video.sh) | Render a lip-synced MP4 from `.imx` + audio using `bithuman generate` |
| [live-stream.sh](live-stream.sh) | Start a local HTTP/MJPEG streaming server using `bithuman stream` |
| [mac-app.sh](mac-app.sh) | Wrapper for `bithuman voice` / `text` / `avatar` conversations |
| [rest-api.sh](rest-api.sh) | Quickstart: validate API key + make an agent speak via curl |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `BITHUMAN_API_SECRET` | Yes | Your API secret from [www.bithuman.ai/#developer](https://www.bithuman.ai/#developer) |
| `OPENAI_API_KEY` | No | Enables the instant cloud backend for `voice` / `text` |

## Documentation

- [CLI reference](https://docs.bithuman.ai/getting-started/cli)
- [REST API reference](https://docs.bithuman.ai/api-reference/overview)
- [Full documentation](https://docs.bithuman.ai)
