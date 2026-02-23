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

## Terminal Quickstart (no Docker)

```bash
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your API secret
```

### Play an audio file through the avatar

```bash
python quickstart.py --model models/avatar.imx --audio-file speech.wav
```

Press `Q` to quit.

### Real-time microphone input

```bash
python microphone.py --model avatar.imx
python microphone.py --model avatar.imx --echo   # hear yourself back
```

### AI conversation (OpenAI Realtime)

```bash
python conversation.py --model avatar.imx
```

Speak into your mic, hear the AI respond, watch the avatar lip-sync.

## Full App with Docker

For a complete web application with frontend UI:

```bash
# 1. Place your .imx model(s) in ./models/
mkdir -p models
cp /path/to/avatar.imx models/

# 2. Configure environment
cp .env.example .env
# Edit .env with your API secret and OpenAI key

# 3. Start all services
docker compose up
```

Open [http://localhost:4202](http://localhost:4202) in your browser.

The Docker stack runs 4 services:
- **LiveKit**: WebRTC server (ports 17880-17881)
- **Agent**: AI conversation handler with local .imx model
- **Frontend**: Web interface (port 4202)
- **Redis**: State management

## How It Works

1. The bitHuman SDK loads the `.imx` model file (pre-built avatar, ~500 MB)
2. Audio is processed locally on your CPU -- no GPU needed
3. The SDK produces video frames (BGR numpy arrays) and synchronized audio
4. Only authentication requires an internet connection

## Files

| File | Description |
|------|-------------|
| `quickstart.py` | Simplest example: play audio, display avatar |
| `microphone.py` | Real-time mic input with silence detection |
| `conversation.py` | Full AI voice chat (OpenAI Realtime, no LiveKit) |
| `agent.py` | LiveKit agent for the Docker-based web app |
