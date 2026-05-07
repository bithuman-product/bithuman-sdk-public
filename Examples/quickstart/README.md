# bitHuman Quickstart

Try bitHuman in under 2 minutes. Pick one path below.

| File | What it does | Requirements |
|------|-------------|--------------|
| [cloud-avatar.py](cloud-avatar.py) | Cloud-hosted AI avatar via LiveKit + OpenAI | `BITHUMAN_API_SECRET`, `BITHUMAN_AGENT_ID`, LiveKit + OpenAI keys |
| [local-avatar.py](local-avatar.py) | Load a local `.imx` model, push audio, display frames | `BITHUMAN_API_SECRET`, `.imx` model file |
| [requirements.txt](requirements.txt) | Python dependencies for the examples above | -- |

For CLI and REST API quickstarts, see [cli/](../cli/) and [rest-api/](../rest-api/).

## Setup

```bash
# 1. Get your API secret at https://www.bithuman.ai (Developer section)
export BITHUMAN_API_SECRET="your_secret_here"

# 2. Install Python dependencies
pip install -r requirements.txt
```

## Next steps

- [Python examples](../python/) — full Docker stacks, AI conversation, cloud + local
- [Swift examples](../swift/) — native Mac/iPad/iPhone apps
- [CLI](../cli/) — render videos and stream without code
- [REST API](../rest-api/) — call from any language via HTTP
