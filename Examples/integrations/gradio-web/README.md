# Web UI — Gradio + FastRTC

Talk to a bitHuman avatar through your browser using Gradio and FastRTC.

## Prerequisites

- Python 3.9+
- `.imx` avatar model files (download from [www.bithuman.ai](https://www.bithuman.ai) > Community)
- bitHuman API secret ([www.bithuman.ai](https://www.bithuman.ai/#developer) → Developer → API Keys)
- OpenAI API key (for AI conversation via OpenAI Realtime API)

## Quick Start

```bash
pip install -r requirements.txt
cp .env.example .env
# Edit .env: set BITHUMAN_MODEL_ROOT, BITHUMAN_API_SECRET, OPENAI_API_KEY

python app.py
```

Opens a Gradio web interface at **http://localhost:7860**.

Select an avatar from the dropdown and click to start talking. All `.imx` files in `BITHUMAN_MODEL_ROOT` appear automatically -- named by their filename stem (e.g. `my-avatar.imx` shows as `"my-avatar"`).

## Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `BITHUMAN_MODEL_ROOT` | Yes | Directory containing `.imx` avatar files |
| `BITHUMAN_API_SECRET` | Yes | API secret from bithuman.ai |
| `OPENAI_API_KEY` | Yes | For AI conversation (OpenAI Realtime API) |

## Architecture

```
Browser ──WebRTC (FastRTC)──> Gradio App ──SDK──> .imx model (CPU)
   |                             |
   mic + camera              AI conversation
                              (OpenAI Realtime)
```

1. Gradio serves the web UI with avatar selection dropdown
2. FastRTC `AsyncAudioVideoStreamHandler` handles browser WebRTC
3. bitHuman SDK loads the selected `.imx` model and renders frames locally
4. OpenAI Realtime API provides AI conversation

## What It Demonstrates

- FastRTC `AsyncAudioVideoStreamHandler` for browser-based WebRTC
- Gradio UI with avatar selection dropdown
- Full AI conversation pipeline: mic → cloud LLM → bitHuman → video stream

## Troubleshooting

**No avatars in dropdown?**
Set `BITHUMAN_MODEL_ROOT` to a directory containing `.imx` files:
```bash
export BITHUMAN_MODEL_ROOT=/path/to/models
ls $BITHUMAN_MODEL_ROOT/*.imx   # Should list your avatar files
```

**WebRTC connection fails?**
Make sure port 7860 is accessible. If running remotely, use SSH port forwarding:
```bash
ssh -L 7860:localhost:7860 user@your-server
```

**No audio / avatar doesn't respond?**
Check that `OPENAI_API_KEY` is set and valid in `.env`.

## Files

| File | Description |
|------|-------------|
| `app.py` | Gradio + FastRTC application |
| `requirements.txt` | Python dependencies |
| `.env.example` | Environment variable template |
