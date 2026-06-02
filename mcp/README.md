# bitHuman MCP server

A [Model Context Protocol](https://modelcontextprotocol.io) server that exposes
the [bitHuman](https://bithuman.ai) avatar platform as tools any MCP-capable AI
agent can call — Claude Desktop, Claude Code, Cursor, and others.

It's a thin, fully-documented wrapper over the public REST API
(`https://api.bithuman.ai`). Every tool maps to one documented endpoint; see the
[API docs](https://docs.bithuman.ai/api/overview) and the
[OpenAPI spec](https://docs.bithuman.ai/api/openapi.yaml).

## Tools

The server exposes **21 tools**, each mapping to one documented REST endpoint:

| Tool | What it does |
|------|--------------|
| `validate_api_secret` | Check the API secret is valid (free). |
| `get_credit_balance` | Current credits, plan, and minutes estimate. |
| `get_usage` | Usage/metering history (paginated, date-filterable). |
| `list_voices` | Built-in (M1–M5 / F1–F5) and custom TTS voices. |
| `text_to_speech` | Synthesize speech → a WAV file. |
| `generate_agent` | Create an avatar agent from a prompt / image / video / audio. |
| `get_agent_status` | Poll agent generation progress. |
| `get_agent` | Fetch an existing agent's details. |
| `list_agents` | List your agents, newest first (paginated). |
| `update_agent_prompt` | Change an agent's system prompt. |
| `delete_agent` | Permanently delete an agent you own. |
| `agent_speak` | Make a live agent speak text in its active sessions. |
| `add_agent_context` | Silently inject knowledge into a live agent. |
| `get_dynamics` | List an agent's gesture animations. |
| `generate_dynamics` | Generate new gestures (wave, nod, laugh, idle…). |
| `create_embed_token` | Mint a 1-hour JWT to embed an agent on a website. |
| `upload_file` | Upload an asset (URL or local file) → CDN URL. |
| `create_webhook` / `list_webhooks` / `delete_webhook` / `test_webhook` | Manage signed event webhooks (agent.ready / agent.failed). |

## Setup

You need an API secret from the [Developer Dashboard](https://www.bithuman.ai/#developer).

Published on PyPI as [`bithuman-mcp`](https://pypi.org/project/bithuman-mcp/).
The easiest way to run it is with [`uvx`](https://docs.astral.sh/uv/)
(recommended for MCP clients), or `pip install bithuman-mcp`.

```bash
BITHUMAN_API_SECRET=sk_... uvx bithuman-mcp
```

## Use with Claude Desktop / Claude Code

Add it to your MCP client config. For **Claude Code**:

```bash
claude mcp add bithuman \
  -e BITHUMAN_API_SECRET=sk_your_secret \
  -- uvx bithuman-mcp
```

For **Claude Desktop** (`claude_desktop_config.json`) or any client that takes a
JSON server block:

```json
{
  "mcpServers": {
    "bithuman": {
      "command": "uvx",
      "args": ["bithuman-mcp"],
      "env": { "BITHUMAN_API_SECRET": "sk_your_secret" }
    }
  }
}
```

## Configuration

| Env var | Default | Purpose |
|---------|---------|---------|
| `BITHUMAN_API_SECRET` | _(required)_ | Your API secret. Never logged. |
| `BITHUMAN_API_BASE` | `https://api.bithuman.ai` | API origin. |
| `BITHUMAN_MCP_TRANSPORT` | `stdio` | `stdio` or `streamable-http`. |
| `BITHUMAN_MCP_TIMEOUT` | `120` | Per-request timeout (seconds). |

## Notes

- **Async work**: `generate_agent` and `generate_dynamics` return immediately
  with a `processing` status. Poll `get_agent_status` / `get_dynamics` until
  `ready` (generation takes 2–5 minutes).
- **Credits**: `generate_agent` (~250 credits) and `text_to_speech` consume
  credits. Check `get_credit_balance` first if cost matters.
- **Errors**: non-2xx responses come back as a structured `{error, status_code,
  body, hint}` object. The error catalog is at
  <https://docs.bithuman.ai/api/errors>.

## License

Apache-2.0.
