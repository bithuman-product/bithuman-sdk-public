# Expression + Self-Hosted + LiveKit Cloud

Same stack as [`expression-gpu/`](../expression-gpu/), but WebRTC is hosted by **LiveKit Cloud** instead of a local LiveKit + Redis pair. The browser connects directly over HTTPS — no SSH port forwarding, works from any machine.

## What's different from `expression-gpu/`

| | `expression-gpu` | This variant |
|---|---|---|
| Services | 5 (GPU, agent, frontend, LiveKit, Redis) | 3 (GPU, agent, frontend) |
| WebRTC transport | Local LiveKit on ports 17880 / 17881 / 50700-50720 | LiveKit Cloud over `wss://` |
| Remote access | SSH tunnel 3 ports | SSH tunnel 1 port (4202) |

Everything else — GPU requirements, image size, startup time, performance, `/health` / `/launch` HTTP API — is identical. See [expression-gpu/README.md](../expression-gpu/README.md) for prerequisites, GPU verification, architecture details, and troubleshooting.

## Setup

```bash
git clone https://github.com/bithuman-product/bithuman-sdk-public.git
cd bithuman-sdk-public/Examples/python/local-expression-gpu-livekit-cloud

cp .env.example .env
# Edit .env: set BITHUMAN_API_SECRET, OPENAI_API_KEY, and LiveKit Cloud creds.
# Get LiveKit creds at https://cloud.livekit.io — create a project, copy
# LIVEKIT_URL (wss://...), LIVEKIT_API_KEY, LIVEKIT_API_SECRET.

docker compose up
```

First start pulls the ~10 GB GPU image and downloads ~5 GB of model weights (cached in the `bithuman-models` volume). Subsequent starts: ~80 s.

Open **http://localhost:4202** on the same machine, or tunnel one port from your laptop:

```bash
ssh -L 4202:localhost:4202 user@VPS_IP
```

## Extra environment variables

Only these are new vs. `expression-gpu`:

| Variable | Required | Description |
|----------|----------|-------------|
| `LIVEKIT_URL` | Yes | `wss://<project>.livekit.cloud` |
| `LIVEKIT_API_KEY` | Yes | LiveKit Cloud API key |
| `LIVEKIT_API_SECRET` | Yes | LiveKit Cloud API secret |

All other vars (`BITHUMAN_API_SECRET`, `OPENAI_API_KEY`, `BITHUMAN_AVATAR_IMAGE`, `CUDA_VISIBLE_DEVICES`, `AGENT_PROMPT`, `OPENAI_VOICE`, `GPU_PORT`) work the same as in `../expression-gpu/.env.example`.

## Terminal-only quickstart (no LiveKit)

Once the GPU container is running on port 8089, `quickstart.py` drives it directly through the SDK — useful for benchmarking or for piping audio in from your own code without the LiveKit/frontend layers.

```bash
pip install -r requirements.txt
python quickstart.py --avatar-image face.jpg --audio-file speech.wav
```

Press `Q` to quit. Override `--gpu-url` if the container is on another host or port.

## Troubleshooting specific to this variant

**Agent can't connect to LiveKit Cloud?**
- `LIVEKIT_URL` must start with `wss://`, not `ws://`
- Verify `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET` match the project
- VPS must have outbound HTTPS (port 443) access

For GPU/image/model issues, see the [expression-gpu troubleshooting](../expression-gpu/README.md#troubleshooting).

## Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | 3-service stack (GPU + agent + frontend) |
| `agent.py` | LiveKit agent that dispatches to the local GPU container |
| `quickstart.py` | Terminal-only demo — drives the GPU container directly via the SDK |
| `.env.example` | Env template including LiveKit Cloud vars |
| `speech.wav` | Sample audio bundled for testing |

For a curl-only path that hits the GPU container's HTTP API without Python, see [Quick Start (GPU Container Only)](../expression-gpu/README.md#quick-start-gpu-container-only) in the sibling example.
