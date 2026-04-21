# bitHuman Examples

Build and deploy AI avatars with real-time lip sync. Pick the approach that fits your use case.

Full documentation at **[docs.bithuman.ai](https://docs.bithuman.ai)**.

## Platform API

Programmatic agent management — no SDK or local runtime needed.

| Example | Description |
|---------|-------------|
| [api/](api/) | Create agents, poll status, update prompts, generate dynamics, upload files |

## Avatar Integration

**Essence** avatars are pre-built `.imx` bundles that run on CPU. **Expression** avatars accept any face image and render via a 1.3B-parameter model — on a Linux + NVIDIA GPU box, on bitHuman Cloud, or entirely on-device on Apple Silicon (M3+).

| Example | Model | Deployment | Host Requirement |
|---------|-------|------------|------------------|
| [essence-cloud/](essence-cloud/) | Essence | bitHuman Cloud | API secret + agent ID |
| [essence-selfhosted/](essence-selfhosted/) | Essence | Your machine | API secret + `.imx` file |
| [expression-cloud/](expression-cloud/) | Expression | bitHuman Cloud | API secret + face image |
| [expression-selfhosted/](expression-selfhosted/) | Expression | Your Linux + NVIDIA box | NVIDIA GPU 8 GB+ VRAM |
| [expression-selfhosted-livekit-cloud/](expression-selfhosted-livekit-cloud/) | Expression | Self-hosted GPU + LiveKit Cloud | Above + LiveKit Cloud project |
| [apple-expression/](apple-expression/) | Expression | On-device macOS | Apple Silicon M3+ |

## Language & Framework Integrations

| Example | Description |
|---------|-------------|
| [integrations/java/](integrations/java/) | Java WebSocket client for streaming avatar frames |
| [integrations/nextjs-ui/](integrations/nextjs-ui/) | Drop-in Next.js web interface for LiveKit rooms |
| [integrations/web-ui/](integrations/web-ui/) | Gradio browser UI with FastRTC |
| [integrations/macos-offline/](integrations/macos-offline/) | 100% offline macOS with Ollama + Apple Speech |

## Quick Start

```bash
git clone https://github.com/bithuman-product/bithuman-examples.git
cd bithuman-examples/<example>     # see table above
```

Each example has its own README with prerequisites and a runnable path.

**New to bitHuman?** Start with [`essence-cloud/`](essence-cloud/) — no model download, no GPU.

## Resources

- [Documentation](https://docs.bithuman.ai)
- [Platform](https://www.bithuman.ai) · [API Keys](https://www.bithuman.ai/#developer)
- [Python SDK (PyPI)](https://pypi.org/project/bithuman/)

## License

MIT
