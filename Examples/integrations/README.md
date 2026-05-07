# Integrations

Framework and language bridges that show how to connect bitHuman to different stacks. Each integration demonstrates a specific runtime, language, or deployment pattern -- pick the one closest to what you are building.

## Examples

| Example | Stack | Description | When to use |
|---------|-------|-------------|-------------|
| [nextjs-ui/](nextjs-ui/) | Next.js 14, TypeScript, Tailwind, LiveKit | Drop-in web interface for LiveKit-based avatar sessions. Glassmorphism UI with voice activity detection, responsive layout, and integrated controls. | You need a production-ready browser frontend for your avatar agent. |
| [java-websocket/](java-websocket/) | Java 17, Maven, WebSocket | Java client that streams PCM audio to a Python bitHuman server over WebSocket and receives JPEG video frames back. Includes the full wire protocol spec. | You are integrating bitHuman into a Java backend, Android app, or Spring service. |
| [gradio-web/](gradio-web/) | Python, Gradio, FastRTC | Browser UI powered by Gradio with FastRTC for WebRTC transport. Select an avatar from a dropdown, talk through your mic, see the avatar respond. | You want a quick browser demo without LiveKit or Node.js -- pure Python. |
| [offline-mac/](offline-mac/) | macOS, Docker, Ollama, Apple Speech | 100% offline avatar agent on macOS. Uses Ollama for LLM, Apple Speech Recognition for STT, Apple Voices for TTS, and the bitHuman SDK for avatar rendering. | You need a fully local agent with no cloud dependencies (enterprise, air-gapped, privacy-sensitive). |

## Prerequisites

Each integration has its own prerequisites listed in its README. Common requirements:

- A bitHuman API secret -- get one at [www.bithuman.ai](https://www.bithuman.ai/#developer) (Developer > API Keys)
- `.imx` model files for Essence-based integrations (download from [www.bithuman.ai](https://www.bithuman.ai))

## Getting started

```bash
git clone https://github.com/bithuman-product/bithuman-sdk-public.git
cd bithuman-sdk-public/Examples/integrations/<example>
```

Each subdirectory has its own README with setup steps.

## Documentation

- [Quickstart (Python)](https://docs.bithuman.ai/getting-started/quickstart)
- [Quickstart (Swift)](https://docs.bithuman.ai/swift-sdk/quickstart)
- [API reference](https://docs.bithuman.ai/api-reference/overview)
- [Python SDK on PyPI](https://pypi.org/project/bithuman/)
