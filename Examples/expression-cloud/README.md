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

\* Provide either `BITHUMAN_AVATAR_IMAGE` or `BITHUMAN_AGENT_ID`.

## Remote / VPS Deployment

The stack auto-detects the server address — no extra configuration needed.
Just open the required firewall ports:

```bash
sudo ufw allow 4202/tcp          # Web UI
sudo ufw allow 17880/tcp         # LiveKit signaling
sudo ufw allow 17881/tcp         # LiveKit TCP fallback
sudo ufw allow 50700:50720/udp   # LiveKit WebRTC media
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
