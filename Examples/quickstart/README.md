# bitHuman Quickstart

Try bitHuman in under 2 minutes. Pick one path below.

| File | What it does | Requirements |
|------|-------------|--------------|
| [cloud-avatar.py](cloud-avatar.py) | Run a cloud-hosted AI avatar with LiveKit + OpenAI | `BITHUMAN_API_SECRET`, `BITHUMAN_AGENT_ID`, LiveKit + OpenAI keys |
| [local-avatar.py](local-avatar.py) | Load a local `.imx` model, push audio, display frames | `BITHUMAN_API_SECRET`, a `.imx` model file |
| [generate-video.sh](generate-video.sh) | Render a lip-synced MP4 from .imx + audio (CLI) | `BITHUMAN_API_SECRET` + `.imx` file |
| [rest-api.sh](rest-api.sh) | Validate your API key and make an agent speak via curl | `BITHUMAN_API_SECRET`, an agent code |
| [requirements.txt](requirements.txt) | Python dependencies for the examples above | -- |

## Setup

```bash
# 1. Get your API secret at https://www.bithuman.ai (Developer section)
export BITHUMAN_API_SECRET="your_secret_here"

# 2. Install Python dependencies (for .py examples)
pip install -r requirements.txt
```

See the full [Examples](../) directory for more advanced use cases.
