# Expression + Cloud

Run a bitHuman Expression (GPU) avatar using bitHuman's cloud infrastructure.
No local GPU needed. Provide any face image and the cloud renders a high-fidelity talking avatar.

## Prerequisites

- Python 3.9+ (or Docker)
- bitHuman API secret ([www.bithuman.ai](https://www.bithuman.ai) > Developer section)
- A face image (JPEG/PNG -- any photo with a clear face)
- OpenAI API key (for `agent.py`)

## Quick Start (Full Stack)

```bash
# 1. Clone and enter the directory
git clone https://github.com/bithuman-product/examples.git
cd examples/expression-cloud

# 2. Create your .env file
cp .env.example .env
# Edit .env: set BITHUMAN_API_SECRET and OPENAI_API_KEY

# 3. (Optional) Use your own face image
mkdir -p avatars
cp /path/to/face.jpg avatars/
# Then in .env set: BITHUMAN_AVATAR_IMAGE=/app/avatars/face.jpg

# 4. Start everything
docker compose up
```

Open **http://localhost:4202** in your browser. Click to start talking.

First frame arrives in 4-6 seconds. The cloud handles all GPU rendering.

## Terminal Quickstart (no Docker)

```bash
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your API secret
```

### Animate any face from an image

A sample `speech.wav` is included in this directory. Or use your own:

```bash
# Using a local image
python quickstart.py --avatar-image face.jpg --audio-file speech.wav

# Using a URL
python quickstart.py --avatar-image https://tmoobjxlwcwvxvjeppzq.supabase.co/storage/v1/object/public/bithuman/A74NWD9723/image_20251122_000244_372799.jpg --audio-file speech.wav
```

Press `Q` to quit.

## Architecture

The Docker Compose stack runs 4 services:

```
Browser ──WebRTC──> LiveKit ──dispatch──> Agent ──cloud API──> bitHuman GPU
                      |                     |
                   port 17880          AI conversation
                                       (OpenAI)
```

| Service | Description | Port |
|---------|-------------|------|
| **livekit** | WebRTC media server | 17880 |
| **agent** | AI conversation + avatar orchestration | (internal) |
| **frontend** | Web UI | 4202 |
| **redis** | LiveKit state | (internal) |

## Configuration

All configuration is via `.env`. See `.env.example` for all options.

| Variable | Required | Description |
|----------|----------|-------------|
| `BITHUMAN_API_SECRET` | Yes | API secret from bithuman.ai |
| `OPENAI_API_KEY` | Yes | For AI conversation |
| `BITHUMAN_AVATAR_IMAGE` | Yes* | Face image URL or container path |
| `BITHUMAN_AGENT_ID` | Yes* | Or use a pre-configured agent ID |
| `OPENAI_VOICE` | No | TTS voice, default `coral` |
| `AGENT_PROMPT` | No | AI persona / system prompt (see [Customization](#customization)) |

\* Provide either `BITHUMAN_AVATAR_IMAGE` or `BITHUMAN_AGENT_ID`.

## Customization

Edit `.env` to change the avatar's personality, voice, or face:

```bash
# AI persona -- controls how the avatar responds
AGENT_PROMPT="You are a friendly tech support agent. Help users troubleshoot issues step by step."

# Voice -- OpenAI TTS voice (options: alloy, ash, ballad, coral, echo, fable, onyx, nova, sage, shimmer, verse)
OPENAI_VOICE=sage

# Face -- any JPEG/PNG with a clear face
BITHUMAN_AVATAR_IMAGE=https://example.com/your-face.jpg
# Or use a local file:
# BITHUMAN_AVATAR_IMAGE=/app/avatars/face.jpg
```

After changing `.env`, restart the agent:
```bash
docker compose restart agent
```

If left unset, `AGENT_PROMPT` defaults to `"You are a helpful assistant. Respond concisely."` and `OPENAI_VOICE` defaults to `coral`.

## Deployment Scenarios

### Scenario A: Everything on One Machine (Local)

When your browser and the stack run on the **same machine**:

```bash
docker compose up
```

Open **http://localhost:4202** in your browser. No firewall changes needed.

### Scenario B: Remote VPS + SSH Tunnel (Browser on Your Laptop)

When the stack runs on a **remote server** and you open the browser on your **laptop**. Easiest approach when the VPS has a restricted firewall.

**On the VPS** — start the stack:
```bash
docker compose up
```

**On your laptop** — open an SSH tunnel, then open the browser:
```bash
ssh -L 4202:localhost:4202 -L 17880:localhost:17880 -L 17881:localhost:17881 user@VPS_IP
```

Open **http://localhost:4202** in your laptop browser. The tunnels forward:
- **4202** — Web UI (Next.js frontend)
- **17880** — LiveKit WebSocket signaling
- **17881** — LiveKit TCP media (audio/video stream)

No `.env` changes needed — the stack auto-detects `localhost` from your browser's address.

### Scenario C: Remote VPS with Open Firewall

If you can open ports on your VPS:

```bash
sudo ufw allow 4202/tcp          # Web UI
sudo ufw allow 17880/tcp         # LiveKit signaling
sudo ufw allow 17881/tcp         # LiveKit TCP fallback
sudo ufw allow 50700:50720/udp   # LiveKit WebRTC media (UDP)
```

Then access `http://YOUR_VPS_IP:4202` from any browser.

## Essence vs Expression

| | Essence (CPU) | Expression (GPU) |
|---|---|---|
| **Model** | Pre-built `.imx` avatars | Any face image |
| **Quality** | Good, full-body | High-fidelity face |
| **First frame** | 2-4s | 4-6s |
| **GPU** | Not needed | Cloud handles it |

## How It Works

1. The SDK sends your face image to bitHuman's cloud GPU
2. The Expression model (1.3B parameter DiT) generates real-time lip-sync video
3. Video frames stream back to your machine
4. First frame arrives in 4-6 seconds, then runs at 25+ FPS

## Verify It Works

```bash
# Check all containers are running
docker compose ps

# Check agent logs for errors
docker compose logs agent

# Check frontend is accessible
curl -s http://localhost:4202 | head -5
```

## Troubleshooting

**Invalid face image?**
```
Error: Could not detect a face in the image
```
Use a clear photo with one face visible. Avoid profile shots or heavy occlusion.

**Blank avatar / no video?**
Check that `BITHUMAN_AVATAR_IMAGE` is a valid URL or container path in `.env`. The URL must be publicly accessible.

**Invalid API secret?**
```
Error: 401 Unauthorized
```
Check `BITHUMAN_API_SECRET` in `.env`. Copy the full secret from [Developer Dashboard](https://www.bithuman.ai/#developer).

**Port 4202 already in use?**
```bash
# Find what's using the port
lsof -i :4202
# Or change the port in docker-compose.yml
```

## Files

| File | Description |
|------|-------------|
| `quickstart.py` | Animate any face image with audio (terminal) |
| `agent.py` | LiveKit agent for Docker-based web app |
| `speech.wav` | Sample audio file for quickstart (13s, 16kHz) |
