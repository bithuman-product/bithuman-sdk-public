# Cloud Examples

bitHuman hosts the avatar infrastructure -- you bring an API key and an agent (or face image). No GPU, no model files, no containers to manage. This is the fastest path from zero to a talking avatar.

All cloud examples connect to bitHuman's GPU fleet over the network. You pay per minute of avatar runtime via [credits](https://docs.bithuman.ai/getting-started/pricing).

## When to use cloud

- You want the quickest possible integration (minutes, not hours).
- You do not have (or do not want to maintain) GPU hardware.
- You are building a prototype, demo, or low-to-medium-traffic product.
- You need the Expression model but lack an NVIDIA GPU.

## Examples

| Example | Model | Description | When to use |
|---------|-------|-------------|-------------|
| [essence-livekit/](essence-livekit/) | Essence (CPU) | Full-stack Docker Compose with LiveKit, AI agent, and web UI. The cloud renders the avatar from a pre-built `.imx` agent. | You have an agent ID and want a browser-based demo with voice conversation. |
| [expression-livekit/](expression-livekit/) | Expression (GPU) | Same full-stack setup, but the cloud runs the Expression model on any face image you provide. No local GPU required. | You want high-fidelity facial animation from any photo without owning a GPU. |
| [rest-api/](rest-api/) | N/A | Python scripts that call the bitHuman REST API directly -- create agents, generate avatars, manage dynamics, upload files. No LiveKit or real-time rendering. | You need programmatic agent management, CI/CD pipelines, or batch operations. |

## Prerequisites (all examples)

- Python 3.9+
- A bitHuman API secret -- get one at [www.bithuman.ai](https://www.bithuman.ai/#developer) (Developer > API Keys)
- An OpenAI API key (for the LiveKit agent examples; not needed for rest-api)

## Getting started

```bash
git clone https://github.com/bithuman-product/bithuman-sdk-public.git
cd bithuman-sdk-public/Examples/cloud/<example>
```

Each subdirectory has its own README with setup steps and configuration options.

**New to bitHuman?** Start with [essence-livekit/](essence-livekit/) -- two env vars, `docker compose up`, and you have a talking avatar in your browser.

## Documentation

- [Quickstart](https://docs.bithuman.ai/getting-started/quickstart)
- [Authentication](https://docs.bithuman.ai/getting-started/authentication)
- [Models overview](https://docs.bithuman.ai/getting-started/models)
- [API reference](https://docs.bithuman.ai/api-reference/overview)
- [Pricing](https://docs.bithuman.ai/getting-started/pricing)
