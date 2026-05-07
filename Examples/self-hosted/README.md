# Self-Hosted Examples

Run the bitHuman avatar on your own hardware. You get full control over latency, data privacy, and cost at scale -- in exchange for managing the infrastructure yourself.

All self-hosted examples use the `bithuman` Python SDK ([PyPI](https://pypi.org/project/bithuman/)) and require a bitHuman API secret for authentication. Audio and video stay on your machine; only auth calls reach the cloud (or even those can be eliminated with an offline token for enterprise).

## When to use self-hosted

- You need data to stay on-premise (privacy, compliance).
- You want to eliminate per-minute cloud costs at scale.
- You need the lowest possible latency (no round-trip to cloud GPUs).
- You are deploying always-on kiosks, museum exhibits, or embedded devices.

## Examples

| Example | Model | Description | When to use |
|---------|-------|-------------|-------------|
| [essence-cpu/](essence-cpu/) | Essence | CPU-only avatar from a `.imx` model file. Includes terminal quickstart, microphone demo, full AI conversation, and a Docker Compose LiveKit stack. | You have a CPU-only machine and want full local rendering. |
| [expression-gpu/](expression-gpu/) | Expression | GPU-accelerated avatar on your own NVIDIA hardware. Docker Compose stack with the Expression container, LiveKit, agent, and web UI. | You own an NVIDIA GPU and want the highest-fidelity face animation locally. |
| [expression-gpu-livekit-cloud/](expression-gpu-livekit-cloud/) | Expression | Same GPU rendering as above, but WebRTC is handled by LiveKit Cloud instead of a local LiveKit server. Fewer containers, easier remote access. | You self-host the GPU but want LiveKit Cloud to handle WebRTC transport. |
| [expression-apple/](expression-apple/) | Expression | On-device rendering on Apple Silicon M3+ using the bundled Swift daemon. No Docker, no Linux, no cloud GPU. | You are on a Mac and want a minimal, terminal-only Expression demo. |

## Hardware requirements

| Example | CPU | GPU | RAM | Disk | OS |
|---------|-----|-----|-----|------|----|
| essence-cpu | Any modern x86/ARM | None | 4 GB+ | ~500 MB per `.imx` model | Linux, macOS |
| expression-gpu | Any | NVIDIA, 8 GB+ VRAM | 16 GB+ | ~30 GB (image + weights) | Linux |
| expression-gpu-livekit-cloud | Any | NVIDIA, 8 GB+ VRAM | 16 GB+ | ~30 GB (image + weights) | Linux |
| expression-apple | Apple Silicon M3+ | Integrated (ANE/GPU) | 16 GB+ | ~5 GB | macOS 14+ |

Tested GPUs for Expression: H100, A100, RTX 4090, RTX 3090. Any CUDA-capable GPU with 8 GB+ VRAM should work.

## Prerequisites (all examples)

- Python 3.9+
- A bitHuman API secret -- get one at [www.bithuman.ai](https://www.bithuman.ai/#developer) (Developer > API Keys)
- Docker 24+ with Compose v2 (for the Docker-based examples)
- An OpenAI API key (for the AI conversation agents)

GPU examples additionally require the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html).

## Getting started

```bash
git clone https://github.com/bithuman-product/bithuman-sdk-public.git
cd bithuman-sdk-public/Examples/self-hosted/<example>
```

Each subdirectory has its own README with detailed setup, configuration, deployment scenarios, and troubleshooting.

## Documentation

- [Quickstart](https://docs.bithuman.ai/getting-started/quickstart)
- [Self-hosted GPU deployment](https://docs.bithuman.ai/deployment/self-hosted-gpu)
- [Models overview](https://docs.bithuman.ai/getting-started/models)
- [Python SDK on PyPI](https://pypi.org/project/bithuman/)
