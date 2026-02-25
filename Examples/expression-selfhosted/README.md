# Expression + Self-Hosted

Run a bitHuman Expression (GPU) avatar on your own hardware.
Full local control -- audio and video stay on your machine.

## Prerequisites

- NVIDIA GPU with 8 GB+ VRAM (any CUDA GPU — tested on H100, A100, RTX 4090, RTX 3090)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- Docker 24+ with Compose v2
- ~30 GB free disk space (19 GB image + 8 GB model weights)
- bitHuman API secret ([www.bithuman.ai](https://www.bithuman.ai) > Developer section)
- OpenAI API key (for the AI conversation agent)
- A face image (any JPEG/PNG, or use the default provided in `.env.example`)

> **GPU compatibility:** The container uses PyTorch + torch.compile, which works on any CUDA GPU. No pre-built TensorRT engines required.

## Verify GPU Access

```bash
docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu22.04 nvidia-smi
```

If this fails, install the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) first.

## Quick Start (Full Stack)

```bash
# 1. Clone and enter the directory
git clone https://github.com/bithuman-product/examples.git
cd examples/expression-selfhosted

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

First run pulls the container image (~10 GB download), then downloads model weights (~5 GB) and compiles the GPU kernels. Total: **5-20 minutes** depending on internet speed. Subsequent starts take ~80 seconds.

## Quick Start (GPU Container Only)

If you just want the GPU container (no agent, no frontend):

```bash
docker run --gpus all -p 8089:8089 \
    -e BITHUMAN_API_SECRET=your_secret \
    -v bithuman-models:/data/models \
    sgubithuman/expression-avatar:latest
```

Verify it works (once you see `Avatar Worker Ready` in the logs):

```bash
curl http://localhost:8089/health
curl http://localhost:8089/test-frame -o test.jpg   # check the output image
curl -X POST http://localhost:8089/benchmark         # check FPS
```

To run the interactive quickstart (requires a desktop with display + audio):

```bash
# From the cloned repo directory (expression-selfhosted/)
pip install -r requirements.txt
python quickstart.py --avatar-image face.jpg --audio-file speech.wav   # speech.wav included
```

> **Note:** `quickstart.py` opens an OpenCV window and plays audio. For headless/SSH servers, use the Full Stack path above (browser at localhost:4202) or the curl endpoints.

## Verify the GPU Container

```bash
# Health check
curl http://localhost:8089/health

# Readiness (model loaded + available capacity)
curl http://localhost:8089/ready

# Visual test -- generates frames and returns a JPEG
curl http://localhost:8089/test-frame -o test.jpg
# Open test.jpg in any image viewer to verify
```

## Architecture

The Docker Compose stack runs 5 services:

```
Browser ──WebRTC──> LiveKit ──dispatch──> Agent ──HTTP──> Expression Avatar (GPU)
                      |                     |                    |
                   port 17880          AI conversation      renders video
                                       (OpenAI)            port 8089
```

| Service | Description | Port |
|---------|-------------|------|
| **expression-avatar** | GPU rendering (1.3B parameter model) | 8089 |
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
| `CUDA_VISIBLE_DEVICES` | No | GPU index, default `0` |
| `OPENAI_VOICE` | No | TTS voice, default `coral` |
| `GPU_PORT` | No | External port for GPU container, default `8089` |
| `CUSTOM_GPU_TOKEN` | No | Optional auth token for GPU container |

\* Provide either `BITHUMAN_AVATAR_IMAGE` or `BITHUMAN_AGENT_ID`.

## Multi-GPU Machines

`CUDA_VISIBLE_DEVICES` in `.env` selects which physical GPU to use:

```bash
CUDA_VISIBLE_DEVICES=0   # First GPU (default)
CUDA_VISIBLE_DEVICES=1   # Second GPU
```

## Performance

| Metric | Value |
|--------|-------|
| First run | 5-20 min (10 GB image pull + 5 GB model download + compilation) |
| Cold start | ~80s (decrypt + torch.compile, cached after first run) |
| Warm start | 4-6s |
| Inference | 90+ FPS on H100 (3.5x+ real-time) |
| VRAM | ~4 GB shared + ~50 MB per session |
| Sessions per GPU | Up to 8 concurrent |
| Image size | ~19 GB (PyTorch-only, no TensorRT) |

## Troubleshooting

**GPU not detected?**
```bash
docker info | grep -i runtime    # Should show: nvidia
nvidia-smi                       # Should show your GPU
```

**Container won't start?**
```bash
docker compose logs expression-avatar
```

Common errors:
- `No CUDA GPUs are available` -- NVIDIA Container Toolkit not installed, or wrong CUDA_VISIBLE_DEVICES
- `BITHUMAN_API_SECRET is required` -- Set your API secret in `.env`
- `API key validation failed` -- Your API secret is invalid. Check at [bithuman.ai/dashboard](https://bithuman.ai/dashboard)
- `Missing required model files` -- Weight download may have failed. Remove volume and retry:
  ```bash
  docker compose down -v
  docker compose up
  ```
- `DiT safetensors not found after decryption` -- Encrypted volume may be corrupted. Remove and re-download:
  ```bash
  docker volume rm bithuman-models
  docker compose up
  ```

**Agent crashes?**
```bash
docker compose logs agent
```
- Check that `OPENAI_API_KEY` is set in `.env`
- Check that `BITHUMAN_AVATAR_IMAGE` is a valid URL or container path

**Slow first start?**
First run downloads ~5 GB of model weights. The `bithuman-models` volume caches them.
GPU compilation (torch.compile) takes ~48s on first inference.

**Port conflict?**
Change exposed ports in `.env`:
```bash
GPU_PORT=9089            # Expression avatar (default: 8089)
```

## Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Full stack (GPU + agent + frontend + LiveKit + Redis) |
| `quickstart.py` | Animate a face image with audio (standalone, no LiveKit) |
| `agent.py` | LiveKit agent connecting to local GPU container |
| `.env.example` | Environment variable template |
| `livekit.yaml` | LiveKit server configuration |
| `speech.wav` | Sample audio file for quickstart (13s, 16kHz) |

## API Reference

The expression-avatar container exposes these HTTP endpoints on port 8089:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/ready` | GET | Readiness + capacity |
| `/launch` | POST | Start avatar session (multipart form) |
| `/tasks` | GET | List active sessions |
| `/tasks/{id}` | GET | Session status |
| `/tasks/{id}/stop` | POST | Stop a session |
| `/test-frame` | GET | Generate test frame (JPEG) |
| `/benchmark` | POST | Run inference benchmark |
