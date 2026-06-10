# bitHuman CLI Tools

Command-line tools for running a live avatar locally and rendering
lip-synced video offline — no code.

## Install

The `bithuman` command is a single self-contained binary published
on a Homebrew tap and as the `bithuman-cli` PyPI wheel. Source lives
in the private `bithuman-apps` repo; runnable examples are in this
directory. For the Python library (`from bithuman import AsyncBithuman`)
see the [Python examples](../python/).

```bash
# macOS — Homebrew (recommended; pulls native deps).
brew install bithuman-product/bithuman/bithuman-cli

# macOS / Linux — universal one-liner.
curl -fsSL https://raw.githubusercontent.com/bithuman-product/homebrew-bithuman/main/install.sh | sh

# PyPI sibling wheel, same Rust binary (macOS Apple Silicon only —
# on Linux use the one-liner above).
pip install bithuman-cli
```

All commands need a bitHuman API secret. Get yours at
[www.bithuman.ai/#developer](https://www.bithuman.ai/#developer).

```bash
export BITHUMAN_API_SECRET="your_secret_here"
bithuman doctor      # verify host setup + API key presence
```

---

## Commands

The 2.x CLI surface is six commands. Run `bithuman <command> --help`
for the full flag list.

| Command | Description |
|---------|-------------|
| `bithuman run [<model.imx>]` | Live avatar — self-contained LiveKit pool + embedded server. Prints a landing-page URL to open in a browser. |
| `bithuman render <model.imx> --audio speech.wav --output demo.mp4` | Offline batch render an MP4 from a model + WAV. |
| `bithuman info <model.imx>` | Print metadata for an `.imx` model file. |
| `bithuman pull <slug>` | Download a showcase avatar fixture by slug into the local cache. |
| `bithuman list` | Browse showcase avatars — manifest + local cache state. |
| `bithuman doctor` | Host capability check (arch, OS, RAM, disk, API key, brain availability). |

### Run a live avatar — see [live-stream.sh](live-stream.sh) and [mac-app.sh](mac-app.sh)

```bash
bithuman run model.imx
# Open the printed http://127.0.0.1:8088/<CODE> URL in your browser,
# grant mic permission, and talk.
```

### Render a video offline — see [render-video.sh](render-video.sh)

```bash
bithuman render model.imx --audio speech.wav --output demo.mp4
```

> ⚠️ Note: As of bithuman 2.3.0 / libessence ABI v7, `bithuman render` is
> implemented on Linux only. On macOS, the binary returns a "not implemented"
> error from `be_video_encoder_*`. macOS support is queued. Workarounds:
> run on Linux (Docker manylinux container or native Linux host), or use
> `bithuman run` and record the browser tab (live-streaming variant).

### Validate your API secret

There is no `bithuman validate` subcommand — use the REST endpoint:

```bash
curl -s -X POST https://api.bithuman.ai/v1/validate \
  -H "api-secret: $BITHUMAN_API_SECRET" | python3 -m json.tool
```

---

## Brain selection

`bithuman run` connects the avatar to a *brain* (the LLM + TTS that
generates speech). Pick one of two paths via env vars:

| Brain | How to enable | Notes |
|-------|---------------|-------|
| Cloud (default) | `export OPENAI_API_KEY=sk-...` | OpenAI Realtime; instant, no downloads. |
| On-device | `export BITHUMAN_LOCAL=1` | whisper.cpp + llama.cpp + Supertonic + Silero. Needs `pip install 'bithuman-cli[local]'`. ~5 GB first-run download, then offline. |

```bash
export OPENAI_API_KEY=sk-...     # cloud (default)
bithuman run model.imx

# or, fully on-device:
pip install 'bithuman-cli[local]'
BITHUMAN_LOCAL=1 bithuman run model.imx
```

Hardware requirements for the on-device brain: macOS Apple Silicon
M3+ or Linux x86_64 / aarch64.

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
| [render-video.sh](render-video.sh) | Render a lip-synced MP4 from `.imx` + audio using `bithuman render` |
| [live-stream.sh](live-stream.sh) | Start the live avatar server using `bithuman run` |
| [mac-app.sh](mac-app.sh) | Wrapper for `bithuman install` + `bithuman run` |
| [rest-api.sh](rest-api.sh) | Quickstart: validate API key + make an agent speak via curl |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `BITHUMAN_API_SECRET` | Yes | Your API secret from [www.bithuman.ai/#developer](https://www.bithuman.ai/#developer) (`BITHUMAN_API_KEY` is accepted as an alias) |
| `OPENAI_API_KEY` | One of | Cloud brain for `bithuman run` (default path) |
| `BITHUMAN_LOCAL` | One of | `=1` flips `bithuman run` to the on-device brain |

## Documentation

- [CLI reference](https://docs.bithuman.ai/getting-started/cli)
- [REST API reference](https://docs.bithuman.ai/api-reference/overview)
- [Full documentation](https://docs.bithuman.ai)
