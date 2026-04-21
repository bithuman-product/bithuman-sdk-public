# Expression + Self-Hosted + LiveKit Cloud

Same stack as [`expression-selfhosted/`](../expression-selfhosted/), but WebRTC is hosted by **LiveKit Cloud** instead of a local LiveKit + Redis pair. The browser connects directly over HTTPS — no SSH port forwarding, works from any machine.

## What's different from `expression-selfhosted/`

| | `expression-selfhosted` | This variant |
|---|---|---|
| Services | 5 (GPU, agent, frontend, LiveKit, Redis) | 3 (GPU, agent, frontend) |
| WebRTC transport | Local LiveKit on ports 17880 / 17881 / 50700-50720 | LiveKit Cloud over `wss://` |
| Remote access | SSH tunnel 3 ports | SSH tunnel 1 port (4202) |

Everything else — GPU requirements, image size, startup time, performance, `/health` / `/launch` HTTP API — is identical. See [expression-selfhosted/README.md](../expression-selfhosted/README.md) for prerequisites, GPU verification, architecture details, and troubleshooting.

## Setup

```bash
git clone https://github.com/bithuman-product/bithuman-examples.git
cd bithuman-examples/expression-selfhosted-livekit-cloud

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

Only these are new vs. `expression-selfhosted`:

| Variable | Required | Description |
|----------|----------|-------------|
| `LIVEKIT_URL` | Yes | `wss://<project>.livekit.cloud` |
| `LIVEKIT_API_KEY` | Yes | LiveKit Cloud API key |
| `LIVEKIT_API_SECRET` | Yes | LiveKit Cloud API secret |

All other vars (`BITHUMAN_API_SECRET`, `OPENAI_API_KEY`, `BITHUMAN_AVATAR_IMAGE`, `CUDA_VISIBLE_DEVICES`, `AGENT_PROMPT`, `OPENAI_VOICE`, `GPU_PORT`) work the same as in `../expression-selfhosted/.env.example`.

## Troubleshooting specific to this variant

**Agent can't connect to LiveKit Cloud?**
- `LIVEKIT_URL` must start with `wss://`, not `ws://`
- Verify `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET` match the project
- VPS must have outbound HTTPS (port 443) access

For GPU/image/model issues, see the [expression-selfhosted troubleshooting](../expression-selfhosted/README.md#troubleshooting).

## Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | 3-service stack (GPU + agent + frontend) |
| `.env.example` | Env template including LiveKit Cloud vars |
