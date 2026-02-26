# bitHuman Examples

## What is bitHuman?

Real-time avatar animation API. Turns face images or pre-built `.imx` models
into lifelike talking avatars with audio-driven lip sync at 25 FPS.

Use bitHuman to build: AI companions, customer support avatars, virtual tutors,
digital receptionists, game NPCs, accessibility tools, and any application
that needs a visual character that speaks.

## Repository Structure

```
essence-cloud/          Cloud CPU avatar (no GPU, no model files needed)
essence-selfhosted/     Local CPU avatar (uses .imx model files, no GPU)
expression-cloud/       Cloud GPU avatar (any face image, no local GPU)
expression-selfhosted/  Self-hosted GPU avatar (NVIDIA 8GB+ VRAM required)
api/                    REST API scripts (generation, management, dynamics, upload)
integrations/
  web-ui/               Gradio + FastRTC browser interface
  flutter/              Flutter + Python backend
  java/                 Java integration
  nextjs-ui/            Next.js frontend
  macos-offline/        macOS local agent
```

## Quick Start

```bash
# Any example directory:
cp .env.example .env    # Set BITHUMAN_API_SECRET, OPENAI_API_KEY
docker compose up       # For Docker examples
# Open http://localhost:4202

# For CLI scripts:
pip install -r requirements.txt
python quickstart.py    # Each directory has its own scripts
```

## API

- **Base URL**: `https://api.bithuman.ai`
- **Auth**: `api-secret` header on every request
- **Docs**: https://docs.bithuman.ai
- **OpenAPI Spec**: https://docs.bithuman.ai/api-reference/openapi.yaml

### Key Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/validate` | POST | Verify API secret is valid |
| `/v1/agent/generate` | POST | Generate new agent (image/video/audio + prompt) |
| `/v1/agent/status/{id}` | GET | Poll generation status (processing/ready/failed) |
| `/v1/agent/{code}` | GET | Retrieve agent details |
| `/v1/agent/{code}` | POST | Update agent system prompt |
| `/v1/agent/{code}/speak` | POST | Make avatar say text (agent must be in active session) |
| `/v1/agent/{code}/add-context` | POST | Inject silent background knowledge |
| `/v1/files/upload` | POST | Upload image/video/audio (by URL or base64) |
| `/v1/dynamics/generate` | POST | Generate gesture animations for agent |
| `/v1/dynamics/{agent_id}` | GET | List available gestures |

## Key Packages

```
pip install bithuman                     # Python SDK — local CPU avatar rendering
pip install livekit-plugins-bithuman     # LiveKit plugin — real-time WebRTC sessions
```

### GPU Container (self-hosted)

```bash
docker run --gpus all -p 8089:8089 \
    -e BITHUMAN_API_SECRET=your_secret \
    -v bithuman-models:/data/models:rw \
    sgubithuman/expression-avatar:latest
```

The `-v bithuman-models:/data/models` volume mount is **required** — it caches ~5 GB of
model weights. Without it, weights re-download on every container restart.

GPU container HTTP API: `/health`, `/ready`, `/launch` (POST, multipart form),
`/tasks`, `/tasks/{id}/stop`, `/test-frame`, `/benchmark` (POST).

## Python SDK Core API

```python
from bithuman import AsyncBithuman

runtime = await AsyncBithuman.create(model_path="avatar.imx", api_secret="...")
await runtime.start()
await runtime.push_audio(audio_bytes, sample_rate=16000)
await runtime.flush()

async for frame in runtime.run():
    frame.bgr_image       # numpy array (H, W, 3)
    frame.audio_chunk     # synchronized audio output
    frame.end_of_speech   # True when utterance ends
```

## LiveKit Plugin API

```python
from livekit.plugins import bithuman

# Cloud mode (no GPU needed)
avatar = bithuman.AvatarSession(avatar_id="AGENT_CODE", api_secret="...")

# Self-hosted CPU mode (local .imx file)
avatar = bithuman.AvatarSession(model_path="/models/avatar.imx", api_secret="...")

# Self-hosted GPU mode (any face image)
avatar = bithuman.AvatarSession(api_url="http://localhost:8089/launch", api_secret="...", avatar_image="face.jpg")

await avatar.start(session, room=ctx.room)
```

## Environment Variables

| Variable | Used By | Description |
|----------|---------|-------------|
| `BITHUMAN_API_SECRET` | All | API secret from www.bithuman.ai/#developer |
| `BITHUMAN_AGENT_ID` | Cloud examples | Agent code (e.g. A78WKV4515) |
| `BITHUMAN_AVATAR_IMAGE` | Expression examples | Face image URL or path |
| `BITHUMAN_MODEL_PATH` | Essence self-hosted | Path to .imx model file |
| `OPENAI_API_KEY` | Agent examples | For AI conversation (STT/LLM/TTS) |
| `LIVEKIT_URL` | Docker stacks | LiveKit server URL |
| `LIVEKIT_API_KEY` | Docker stacks | LiveKit API key |
| `LIVEKIT_API_SECRET` | Docker stacks | LiveKit API secret |
| `AGENT_PROMPT` | Agent examples | AI persona / system prompt (default: "You are a helpful assistant. Respond concisely.") |
| `OPENAI_VOICE` | Agent examples | OpenAI TTS voice (default: `coral`) |
| `CUDA_VISIBLE_DEVICES` | GPU examples | GPU index for multi-GPU machines |

## Requirements

- Python 3.9+
- Docker 24+ with Compose v2 (for Docker examples)
- NVIDIA GPU 8GB+ VRAM + Container Toolkit (for expression-selfhosted only)
- bitHuman API secret from https://www.bithuman.ai
- OpenAI API key (for AI conversation examples)

## Links

- Documentation: https://docs.bithuman.ai
- Dashboard: https://www.bithuman.ai
- Discord: https://discord.gg/ES953n7bPA
- Status: https://status.bithuman.ai
