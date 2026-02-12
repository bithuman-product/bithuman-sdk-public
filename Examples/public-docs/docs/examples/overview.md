# Examples

Working examples from basic to advanced, each with full source code.

![Example Agent Variety](assets/images/example-agent-images.jpg)

---

## SDK Examples

Progressive examples — each builds on the previous one.

| # | Example | What It Does | Source |
|---|---------|-------------|--------|
| 1 | **[Audio Clip](examples/avatar-with-audio-clip.md)** | Play audio file through avatar | [01-quickstart](https://github.com/bithuman-product/examples/tree/main/public-sdk-examples/01-quickstart) |
| 2 | **[Live Microphone](examples/avatar-with-microphone.md)** | Real-time mic → avatar | [02-microphone](https://github.com/bithuman-product/examples/tree/main/public-sdk-examples/02-microphone) |
| 3 | **[AI Conversation](examples/livekit-openai-agent.md)** | OpenAI voice chat with avatar | [03-ai-conversation](https://github.com/bithuman-product/examples/tree/main/public-sdk-examples/03-ai-conversation) |
| 4 | **Streaming Server** | WebSocket → LiveKit room | [04-streaming-server](https://github.com/bithuman-product/examples/tree/main/public-sdk-examples/04-streaming-server) |
| 5 | **Web UI** | Browser-based Gradio interface | [05-web-ui](https://github.com/bithuman-product/examples/tree/main/public-sdk-examples/05-web-ui) |

## Full-Stack Examples

| Example | What It Does | Source |
|---------|-------------|--------|
| **Docker App** | Complete app: LiveKit + OpenAI + Web UI | [public-docker-example](https://github.com/bithuman-product/examples/tree/main/public-docker-example) |
| **[Apple Local Agent](examples/livekit-apple-local.md)** | 100% offline on macOS (Siri + Ollama) | [public-macos-offline-example](https://github.com/bithuman-product/examples/tree/main/public-macos-offline-example) |
| **[Raspberry Pi](examples/livekit-raspberry-pi.md)** | Edge deployment on Raspberry Pi | — |
| **Java Client** | WebSocket streaming from Java | [public-java-example](https://github.com/bithuman-product/examples/tree/main/public-java-example) |
| **[Self-Hosted Plugin](examples/livekit-bithuman-plugin-self-hosted.md)** | Self-hosted LiveKit plugin | — |

---

## Prerequisites

```bash
pip install bithuman --upgrade
export BITHUMAN_API_SECRET="sk_bh_..."
```

- **API secret**: [imaginex.bithuman.ai](https://imaginex.bithuman.ai/#developer)
- **Avatar models**: Download `.imx` files from [Community Models](https://imaginex.bithuman.ai/#community)
- **All source code**: [github.com/bithuman-product/examples](https://github.com/bithuman-product/examples)

---

**New to bitHuman?** Start with [Audio Clip](examples/avatar-with-audio-clip.md) — you'll have an avatar running in 5 minutes.
