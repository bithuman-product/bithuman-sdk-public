# Essence + Cloud

Run a bitHuman Essence (CPU) avatar using bitHuman's cloud infrastructure.
No local GPU, no `.imx` model files. Just an API secret and an agent ID.

## Prerequisites

- Python 3.9+ (or Docker)
- bitHuman API secret ([www.bithuman.ai](https://www.bithuman.ai) > Developer section)
- An agent ID (create one at [www.bithuman.ai](https://www.bithuman.ai) or via `../api/generation.py`)
- OpenAI API key (for `agent.py`)

## Quick Start (Full Stack)

```bash
# 1. Clone and enter the directory
git clone https://github.com/bithuman-product/examples.git
cd examples/essence-cloud

# 2. Create your .env file
cp .env.example .env
# Edit .env: set BITHUMAN_API_SECRET, BITHUMAN_AGENT_ID, and OPENAI_API_KEY

# 3. Start everything
docker compose up
```

Open **http://localhost:4202** in your browser. Click to start talking.

First frame arrives in 2-4 seconds. No model files to manage -- the cloud handles all rendering.

## Terminal Quickstart (no Docker)

```bash
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your API secret and agent ID
```

### Play an audio file through the avatar

A sample `speech.wav` is included in this directory. Or use your own:

```bash
python quickstart.py --avatar-id YOUR_AGENT_ID --audio-file speech.wav
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
| `BITHUMAN_AGENT_ID` | Yes | Agent code (e.g. `A78WKV4515`) |
| `OPENAI_API_KEY` | Yes | For AI conversation |
| `OPENAI_VOICE` | No | TTS voice, default `coral` |

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

## How It Works

1. The SDK connects to bitHuman's cloud with your `avatar_id`
2. Audio is sent to the cloud, which renders the avatar
3. Video frames stream back to your machine for display
4. First frame arrives in 2-4 seconds

No model files to manage. The cloud handles all rendering.

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

**Agent ID not set?**
```
Error: BITHUMAN_AGENT_ID is required
```
Set `BITHUMAN_AGENT_ID` in `.env`. Get your agent ID from [www.bithuman.ai](https://www.bithuman.ai).

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

**No audio / avatar doesn't talk?**
Check that `OPENAI_API_KEY` is set and valid in `.env`.

## Files

| File | Description |
|------|-------------|
| `quickstart.py` | Play audio through cloud avatar (terminal) |
| `agent.py` | LiveKit agent for Docker-based web app |
| `speech.wav` | Sample audio file for quickstart (13s, 16kHz) |
