# bitHuman Examples

Build and deploy AI avatars with real-time lip sync. Two avatar models, three runtime surfaces — pick the row in the table that matches what you're shipping.

Full documentation at **[docs.bithuman.ai](https://docs.bithuman.ai)**.

## Two models

- **Essence** — CPU-only, pre-built `.imx` model from your photo or video. Supports gestures, animal mode, full body. No idle timeout.
- **Expression** — AI-generated facial animation from any face image. Runs on NVIDIA GPU server-side **or** on-device Apple Silicon M3+.

See [docs.bithuman.ai/getting-started/models](https://docs.bithuman.ai/getting-started/models) for the full comparison.

## Avatar integration examples

| Example | Model | Surface | Host requirement |
|---|---|---|---|
| [essence-cloud/](essence-cloud/) | Essence | bitHuman Cloud (LiveKit plugin) | API secret + agent ID |
| [essence-selfhosted/](essence-selfhosted/) | Essence | Your machine (Python SDK) | API secret + `.imx` file |
| [expression-cloud/](expression-cloud/) | Expression | bitHuman Cloud (LiveKit plugin) | API secret + face image |
| [expression-selfhosted/](expression-selfhosted/) | Expression | Your Linux + NVIDIA GPU box | NVIDIA GPU 8 GB+ VRAM |
| [expression-selfhosted-livekit-cloud/](expression-selfhosted-livekit-cloud/) | Expression | Self-hosted GPU + LiveKit Cloud | Above + LiveKit Cloud project |
| [apple-expression/](apple-expression/) | Expression | On-device macOS (Python SDK) | Apple Silicon M3+ |

## Apple Silicon Swift SDK

Native on-device voice + lip-synced avatar for **Mac, iPad, iPhone**. Ships as a SwiftPM binary package — no transitive Swift Package dependencies.

| | What |
|---|---|
| **[`bithuman-product/bithuman-sdk-public`](https://github.com/bithuman-product/bithuman-sdk-public)** | Public SwiftPM binary package. `import bitHumanKit`. Hardware floor: M3+ Mac / M4+ iPad Pro / iPhone 16 Pro+. |
| **[`bithuman-product/bithuman-apps`](https://github.com/bithuman-product/bithuman-apps)** | Annotated Mac / iPad / iPhone reference apps that consume the SDK. Clone, run one command, get a working avatar. |
| **`bithuman-cli`** ([Homebrew tap](https://github.com/bithuman-product/homebrew-bithuman)) | No-code Mac tool. `brew install bithuman-cli` → `bithuman-cli video`. |

Quickstart: [docs.bithuman.ai/swift-sdk/quickstart](https://docs.bithuman.ai/swift-sdk/quickstart).

## Platform API (REST)

Programmatic agent management — no SDK or local runtime needed.

| Example | Description |
|---|---|
| [api/](api/) | Create agents, poll status, update prompts, generate dynamics, upload files |

Reference: [docs.bithuman.ai/api-reference/overview](https://docs.bithuman.ai/api-reference/overview).

## Language & framework integrations

| Example | Description |
|---|---|
| [integrations/java/](integrations/java/) | Java WebSocket client for streaming avatar frames |
| [integrations/nextjs-ui/](integrations/nextjs-ui/) | Drop-in Next.js web interface for LiveKit rooms |
| [integrations/web-ui/](integrations/web-ui/) | Gradio browser UI with FastRTC |
| [integrations/macos-offline/](integrations/macos-offline/) | 100% offline macOS with Ollama + Apple Speech (Essence + local voice stack) |

## Quick start

```bash
git clone https://github.com/bithuman-product/bithuman-sdk-public.git
cd bithuman-sdk-public/Examples/<example>     # see table above
```

Each example has its own README with prerequisites and a runnable path.

**New to bitHuman?** Start with [`essence-cloud/`](essence-cloud/) — no model download, no GPU. **Building a Mac/iPad/iPhone app?** Jump to [docs.bithuman.ai/swift-sdk/quickstart](https://docs.bithuman.ai/swift-sdk/quickstart).

## Documentation

- **Site**: [docs.bithuman.ai](https://docs.bithuman.ai)
- **Quickstart**: [docs.bithuman.ai/getting-started/quickstart](https://docs.bithuman.ai/getting-started/quickstart) (Python) · [docs.bithuman.ai/swift-sdk/quickstart](https://docs.bithuman.ai/swift-sdk/quickstart) (Swift)
- **Authentication**: [docs.bithuman.ai/getting-started/authentication](https://docs.bithuman.ai/getting-started/authentication)
- **Pricing & credits**: [docs.bithuman.ai/getting-started/pricing](https://docs.bithuman.ai/getting-started/pricing)
- **AI-agent ingest**: [docs.bithuman.ai/llms.txt](https://docs.bithuman.ai/llms.txt) · [llms-full.txt](https://docs.bithuman.ai/llms-full.txt) · [openapi.yaml](https://docs.bithuman.ai/api-reference/openapi.yaml)

## Other resources

- [Platform dashboard](https://www.bithuman.ai) · [Get an API key](https://www.bithuman.ai/#developer)
- [Python SDK on PyPI](https://pypi.org/project/bithuman/)
- [Discord community](https://discord.gg/ES953n7bPA)
- [Status](https://status.bithuman.ai)

## License

MIT for the example code in this repo. The bitHuman SDK and model weights are governed by the [bitHuman Terms of Service](https://www.bithuman.ai/terms).
