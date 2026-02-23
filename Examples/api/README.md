# bitHuman Platform API

Manage agents, generate avatars, and download `.imx` models via REST API.
No SDK or local runtime needed -- just Python + HTTP.

## Setup

```bash
pip install -r requirements.txt
cp .env.example .env
# Edit .env -- add your API secret from https://www.bithuman.ai (Developer section)
```

## Scripts

| Script | What it does | Key endpoints |
|--------|-------------|---------------|
| `generation.py` | Generate agent, download `.imx` model | `POST /v1/agent/generate`, `GET /v1/agent/status/{id}` |
| `management.py` | Validate credentials, get/update agents | `POST /v1/validate`, `GET/POST /v1/agent/{code}` |
| `dynamics.py` | Generate gestures, list available gestures | `POST /v1/dynamics/generate`, `GET /v1/dynamics/{id}` |
| `context.py` | Make agent speak, inject background context | `POST /v1/agent/{code}/speak`, `POST /v1/agent/{code}/add-context` |
| `upload.py` | Upload files by URL or from disk | `POST /v1/files/upload` |

## Common Workflows

### Generate a new agent and download its .imx model

```bash
# Generate from a text prompt (~4 min) and download the .imx file
python generation.py --prompt "You are a fitness coach" --download

# Customize appearance with a face image
python generation.py --prompt "A news anchor" --image https://example.com/face.jpg --download

# Save .imx to a specific path
python generation.py --prompt "A tutor" --download --output ../essence-selfhosted/models/avatar.imx
```

### Download .imx for an existing agent

```bash
python generation.py --download --agent-id A91XMB7113
```

### Manage agents

```bash
# Validate your API secret
python management.py

# Get agent info
python management.py --agent-id A91XMB7113
```

### Gestures and dynamics

```bash
# List available gestures
python dynamics.py --agent-id A91XMB7113

# Generate new gestures
python dynamics.py --agent-id A91XMB7113 --generate
```

### Live session control

```bash
# Make an agent speak (agent must be in an active session)
python context.py --agent-id A91XMB7113 --speak "Hello! How can I help?"

# Inject background context silently
python context.py --agent-id A91XMB7113 --context "Customer is a VIP member since 2021."
```

### File upload

```bash
python upload.py --url https://example.com/avatar.jpg
python upload.py --file ./local-image.png
```

## API Reference

- **Base URL**: `https://api.bithuman.ai`
- **Auth**: `api-secret` header on every request
- **Full docs**: [docs.bithuman.ai/api-reference](https://docs.bithuman.ai/api-reference/overview)
