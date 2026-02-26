# Essence + Self-Hosted

Run a bitHuman Essence (CPU) avatar locally using `.imx` model files.
No GPU needed. Audio stays on your machine -- only authentication calls the cloud.

## Prerequisites

- Python 3.9+ (or Docker)
- bitHuman API secret ([www.bithuman.ai](https://www.bithuman.ai) > Developer section)
- `.imx` model file (see below)
- OpenAI API key (for `conversation.py` and `agent.py`)

## Get an .imx Model

Option A -- **Download from the console**: Browse [www.bithuman.ai](https://www.bithuman.ai) > Community

Option B -- **Generate via API**: Use the [api/](../api/) scripts to create a new agent and download its model:
```bash
cd ../api
pip install -r requirements.txt
export BITHUMAN_API_SECRET=your_secret

# Generate a new agent and download the .imx file (~4 min)
python generation.py --prompt "You are a friendly assistant" --download --output ../essence-selfhosted/models/avatar.imx
```

## Quick Start (Full Stack)

```bash
# 1. Clone and enter the directory
git clone https://github.com/bithuman-product/examples.git
cd examples/essence-selfhosted

# 2. Place your .imx model(s)
mkdir -p models
cp /path/to/avatar.imx models/

# 3. Create your .env file
cp .env.example .env
# Edit .env: set BITHUMAN_API_SECRET and OPENAI_API_KEY

# 4. Start everything
docker compose up
```

Open **http://localhost:4202** in your browser. Click to start talking.

First frame takes ~20 seconds (model loading), then runs at real-time 25 FPS.

## Terminal Quickstart (no Docker)

```bash
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your API secret
```

### Play an audio file through the avatar

A sample `speech.wav` is included in this directory. Or use your own:

```bash
python quickstart.py --model models/avatar.imx --audio-file speech.wav
```

Press `Q` to quit.

### Real-time microphone input

```bash
python microphone.py --model models/avatar.imx
python microphone.py --model models/avatar.imx --echo   # hear yourself back
```

### AI conversation (OpenAI Realtime)

```bash
python conversation.py --model models/avatar.imx
```

Speak into your mic, hear the AI respond, watch the avatar lip-sync.

## Architecture

The Docker Compose stack runs 4 services:

```
Browser ──WebRTC──> LiveKit ──dispatch──> Agent ──local SDK──> .imx model (CPU)
                      |                     |
                   port 17880          AI conversation
                                       (OpenAI)
```

| Service | Description | Port |
|---------|-------------|------|
| **livekit** | WebRTC media server | 17880 |
| **agent** | AI conversation + local .imx rendering | (internal) |
| **frontend** | Web UI | 4202 |
| **redis** | LiveKit state | (internal) |

## Configuration

All configuration is via `.env`. See `.env.example` for all options.

| Variable | Required | Description |
|----------|----------|-------------|
| `BITHUMAN_API_SECRET` | Yes | API secret from bithuman.ai |
| `OPENAI_API_KEY` | Yes | For AI conversation |
| `BITHUMAN_MODEL_PATH` | CLI only | Path to `.imx` file (for terminal scripts) |
| `OPENAI_VOICE` | No | TTS voice, default `coral` |
| `AGENT_PROMPT` | No | AI persona / system prompt (see [Customization](#customization)) |

## Customization

Edit `.env` to change the avatar's personality or voice:

```bash
# AI persona -- controls how the avatar responds
AGENT_PROMPT="You are a friendly tech support agent. Help users troubleshoot issues step by step."

# Voice -- OpenAI TTS voice (options: alloy, ash, ballad, coral, echo, fable, onyx, nova, sage, shimmer, verse)
OPENAI_VOICE=sage
```

To use a different avatar, place a new `.imx` file in `./models/`. The agent auto-discovers the first `.imx` file in that directory.

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

## How It Works

1. The bitHuman SDK loads the `.imx` model file (pre-built avatar, ~500 MB)
2. Audio is processed locally on your CPU -- no GPU needed
3. The SDK produces video frames (BGR numpy arrays) and synchronized audio
4. Only authentication requires an internet connection

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

**No .imx model files?**
Place at least one `.imx` file in the `./models/` directory. Download from [www.bithuman.ai](https://www.bithuman.ai) > Community, or generate via `../api/generation.py`.

**Model path wrong?**
The Docker stack mounts `./models/` to `/imx-models` inside the container. The agent auto-discovers `.imx` files in that directory.

**Slow first start?**
First frame takes ~20 seconds while the model loads. Subsequent sessions in the same container start instantly.

**Agent crashes?**
```bash
docker compose logs agent
```
- Check that `OPENAI_API_KEY` is set in `.env`
- Check that `.imx` files are in `./models/`

## Files

| File | Description |
|------|-------------|
| `quickstart.py` | Simplest example: play audio, display avatar |
| `microphone.py` | Real-time mic input with silence detection |
| `conversation.py` | Full AI voice chat (OpenAI Realtime, no LiveKit) |
| `agent.py` | LiveKit agent for the Docker-based web app |
| `speech.wav` | Sample audio file for quickstart (13s, 16kHz) |
