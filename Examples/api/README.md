# bitHuman Platform API

Manage agents, generate new avatars, trigger gestures, and control live sessions via REST API.
No SDK or local runtime needed -- just HTTP requests.

## Setup

1. Get your API secret from [www.bithuman.ai](https://www.bithuman.ai) (Developer section)
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Set environment:
   ```bash
   cp .env.example .env
   # Edit .env with your API secret
   ```

## Examples

| Script | What it does | Key endpoints |
|--------|-------------|---------------|
| `management.py` | Validate credentials, get/update agents | `POST /v1/validate`, `GET/POST /v1/agent/{code}` |
| `generation.py` | Create agent from prompt, poll status | `POST /v1/agent/generate`, `GET /v1/agent/status/{id}` |
| `dynamics.py` | Generate gestures, list available gestures | `POST /v1/dynamics/generate`, `GET /v1/dynamics/{id}` |
| `context.py` | Make agent speak, inject background context | `POST /v1/agent/{code}/speak`, `POST /v1/agent/{code}/add-context` |
| `upload.py` | Upload files by URL or from disk | `POST /v1/files/upload` |

## Run

```bash
# Validate your API secret
python management.py

# Get agent details
python management.py --agent-id A91XMB7113

# Generate a new agent (~4 min)
python generation.py --prompt "You are a fitness coach"

# Generate with a custom face
python generation.py --prompt "You are a news anchor" --image https://example.com/face.jpg

# Generate and download the .imx model for self-hosted use
python generation.py --prompt "You are a tutor" --download

# Download .imx model for an existing agent
python generation.py --download --agent-id A91XMB7113

# Check dynamics / gestures
python dynamics.py --agent-id A91XMB7113

# Generate new dynamics
python dynamics.py --agent-id A91XMB7113 --generate

# Make an agent speak (must be in a live session)
python context.py --agent-id A91XMB7113 --speak "Hello! How can I help?"

# Inject background context silently
python context.py --agent-id A91XMB7113 --context "Customer is a VIP member since 2021."

# Upload a file
python upload.py --url https://example.com/avatar.jpg
python upload.py --file ./local-image.png
```

## API Reference

- **Base URL**: `https://api.bithuman.ai`
- **Auth**: `api-secret` header on every request
- **Full docs**: [docs.bithuman.ai/api-reference](https://docs.bithuman.ai/api-reference/overview)
