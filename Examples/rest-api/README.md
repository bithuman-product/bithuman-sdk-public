# bitHuman REST API

HTTP API for managing agents, generating avatars, controlling live sessions, and uploading files. Works from any language -- Python, curl, JavaScript, Go, Java, or anything that can make HTTP requests.

**Base URL:** `https://api.bithuman.ai`

**Auth:** Include your API secret in the `api-secret` header on every request. Get yours at [www.bithuman.ai/#developer](https://www.bithuman.ai/#developer).

## Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/v1/validate` | Validate API credentials and check credit balance |
| `GET` | `/v1/agent/{code}` | Get agent details (name, status, model URL, prompt) |
| `POST` | `/v1/agent/{code}` | Update agent settings (system prompt) |
| `POST` | `/v1/agent/generate` | Start agent generation (~4 min) |
| `GET` | `/v1/agent/status/{code}` | Poll agent generation status and progress |
| `POST` | `/v1/agent/{code}/speak` | Make a live agent speak a message (requires active session*) |
| `POST` | `/v1/agent/{code}/add-context` | Inject background context into a live session (requires active session*) |
| `POST` | `/v1/dynamics/generate` | Generate gesture dynamics for an agent |
| `GET` | `/v1/dynamics/{code}` | Get dynamics status and available gestures |
| `POST` | `/v1/files/upload` | Upload a file (image, video, audio) by URL or base64 |
| `GET` | `/v2/credit-summaries` | Check credit balance and plan details |

> *\*Active session required:* The `/speak` and `/add-context` endpoints only work when someone is connected to the agent (via the web viewer, a LiveKit room, or the dashboard). If no session is active, you'll get "No active rooms found."

## Authentication

Every request requires the `api-secret` header:

```
Content-Type: application/json
api-secret: your_api_secret_here
```

## Examples

### Python

Full-featured scripts with argument parsing, progress bars, and error handling.

| Script | What it does |
|--------|-------------|
| [python/test.py](python/test.py) | Validate API credentials (quick health check) |
| [python/generation.py](python/generation.py) | Generate an agent, poll status, download .imx model |
| [python/management.py](python/management.py) | Validate credentials, get/update agent info |
| [python/dynamics.py](python/dynamics.py) | Generate and list gesture dynamics |
| [python/context.py](python/context.py) | Make an agent speak or inject background context |
| [python/upload.py](python/upload.py) | Upload files by URL or from local disk |

Setup:

```bash
cd python/
pip install -r requirements.txt
export BITHUMAN_API_SECRET="your_secret"
python test.py
```

### curl

Minimal, self-contained bash scripts. Each one demonstrates a single endpoint.

| Script | What it does |
|--------|-------------|
| [curl/validate.sh](curl/validate.sh) | Validate API credentials |
| [curl/check-credits.sh](curl/check-credits.sh) | Check your credit balance |
| [curl/list-agents.sh](curl/list-agents.sh) | Get agent details |
| [curl/speak.sh](curl/speak.sh) | Make a live agent speak |
| [curl/add-context.sh](curl/add-context.sh) | Inject background context |
| [curl/generate-agent.sh](curl/generate-agent.sh) | Generate an agent and poll until ready |
| [curl/upload-file.sh](curl/upload-file.sh) | Upload a file by URL |

Setup:

```bash
export BITHUMAN_API_SECRET="your_secret"
cd curl/
./validate.sh
```

## Quick examples

### Validate credentials

```bash
curl -s -X POST https://api.bithuman.ai/v1/validate \
  -H "Content-Type: application/json" \
  -H "api-secret: $BITHUMAN_API_SECRET"
# {"valid": true}
# To check credits, use GET /v2/credit-summaries (see curl/check-credits.sh)
```

### Get agent info

```bash
curl -s https://api.bithuman.ai/v1/agent/A91XMB7113 \
  -H "Content-Type: application/json" \
  -H "api-secret: $BITHUMAN_API_SECRET"
```

### Make an agent speak

```bash
curl -s -X POST https://api.bithuman.ai/v1/agent/A91XMB7113/speak \
  -H "Content-Type: application/json" \
  -H "api-secret: $BITHUMAN_API_SECRET" \
  -d '{"message": "Hello! How can I help you today?"}'
```

### Start agent generation

```bash
curl -s -X POST https://api.bithuman.ai/v1/agent/generate \
  -H "Content-Type: application/json" \
  -H "api-secret: $BITHUMAN_API_SECRET" \
  -d '{"prompt": "You are a fitness coach", "aspect_ratio": "16:9"}'
# {"success": true, "agent_id": "AXXXXXXXXX"}
```

### Upload a file

```bash
curl -s -X POST https://api.bithuman.ai/v1/files/upload \
  -H "Content-Type: application/json" \
  -H "api-secret: $BITHUMAN_API_SECRET" \
  -d '{"file_url": "https://example.com/face.jpg"}'
```

## OpenAPI Spec

The full machine-readable API specification is available at:

- [docs.bithuman.ai/api-reference/openapi.yaml](https://docs.bithuman.ai/api-reference/openapi.yaml)

## Documentation

- [API reference](https://docs.bithuman.ai/api-reference/overview)
- [Authentication](https://docs.bithuman.ai/getting-started/authentication)
- [Pricing](https://docs.bithuman.ai/getting-started/pricing)
- [llms.txt](https://docs.bithuman.ai/llms.txt) / [llms-full.txt](https://docs.bithuman.ai/llms-full.txt)
