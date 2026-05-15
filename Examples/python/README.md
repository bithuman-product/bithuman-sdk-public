# Python SDK Examples

All Python examples use `pip install bithuman`. Pick the one that matches where you want the avatar to run.

## Quick decision

| I want to... | Example | What I need |
|---|---|---|
| Fastest cloud demo (no GPU) | [cloud-essence/](cloud-essence/) | API key + agent ID |
| Cloud with custom face image | [cloud-expression/](cloud-expression/) | API key + face image |
| Run on my own server (CPU) | [local-essence/](local-essence/) | API key + `.imx` file |
| Run on NVIDIA GPU | [local-expression-gpu/](local-expression-gpu/) | NVIDIA GPU 8 GB+ |
| Run on Mac M3+ (Python) | [local-expression-mac/](local-expression-mac/) | Apple Silicon M3+ |
| GPU + LiveKit Cloud WebRTC | [local-expression-gpu-livekit-cloud/](local-expression-gpu-livekit-cloud/) | GPU + LiveKit Cloud project |

## Learning path

If you're new to bitHuman, follow this order:

1. **Start with** [cloud-essence/](cloud-essence/) — no model files, no GPU, just an API key. Gives you a working avatar in minutes.
2. **Try local rendering** with [local-essence/](local-essence/) — download a `.imx` model and run it on your own machine (CPU only).
3. **Add AI conversation** — the `conversation.py` script in local-essence/ wires OpenAI for voice chat.
4. **Explore Expression** with [cloud-expression/](cloud-expression/) or [local-expression-gpu/](local-expression-gpu/) for dynamic faces from any image.

## Install

```bash
pip install bithuman --upgrade

# For LiveKit agent examples (cloud-* and docker stacks):
pip install bithuman[agent]
```

Pre-built wheels for Python 3.9-3.14 on Linux x86_64 + ARM64, macOS Intel + Apple Silicon, Windows x86_64.

## Example structure

Every example ships:
- **README.md** — prerequisites, one-command run, config table
- **.env.example** — copy to `.env` and fill in your keys
- **requirements.txt** — Python dependencies

Most also include:
- **docker-compose.yml** — full stack (LiveKit + agent + web UI)
- **agent.py** — LiveKit agent entry point
- **quickstart.py** — standalone script (no LiveKit needed)

## Two models

| | **Essence** | **Expression** |
|---|---|---|
| Avatar source | `.imx` file from [bithuman.ai](https://www.bithuman.ai/#explore) | Any face image |
| Compute | CPU only | NVIDIA GPU or Apple M3+ |
| Pricing (self-hosted) | 1 cr/min | 2 cr/min |
| Pricing (cloud) | 2 cr/min | 4 cr/min |

## Documentation

- [Python quickstart](https://docs.bithuman.ai/getting-started/quickstart)
- [Avatar sessions](https://docs.bithuman.ai/guides/deployment)
- [Self-hosted GPU](https://docs.bithuman.ai/guides/deployment)
- [LiveKit Cloud plugin](https://docs.bithuman.ai/guides/deployment)
