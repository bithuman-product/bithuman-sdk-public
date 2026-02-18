# bitHuman SDK Examples

Build interactive AI avatars that respond to audio with real-time lip sync. These examples progress from simple to production-ready.

## Quick Setup

1. **Get an API secret** at [www.bithuman.ai](https://www.bithuman.ai) → SDK page
2. **Download an avatar model** (`.imx` file) from the [Community page](https://www.bithuman.ai/#community)
3. **Install the SDK**: `pip install bithuman`
4. **Set environment variables**:
   ```bash
   export BITHUMAN_API_SECRET='your_secret'
   export BITHUMAN_AVATAR_MODEL='/path/to/avatar.imx'
   ```

## Examples

| # | Example | What it does | Key concept |
|---|---------|-------------|-------------|
| 01 | [Quickstart](01-quickstart/) | Play an audio file through an avatar | `AsyncBithuman.create()`, `push_audio()`, frame loop |
| 02 | [Microphone](02-microphone/) | Talk into your mic, avatar animates live | Real-time audio capture, silence detection |
| 03 | [AI Conversation](03-ai-conversation/) | Voice chat with an AI through an avatar | OpenAI Realtime + bitHuman, local & WebRTC modes |
| 04 | [Streaming Server](04-streaming-server/) | WebSocket → bitHuman → LiveKit room | Multi-viewer streaming, client/server architecture |
| 05 | [Web UI](05-web-ui/) | Browser-based avatar chat with Gradio | FastRTC, avatar selection, zero-install viewer |

## Core API

```python
from bithuman import AsyncBithuman

runtime = await AsyncBithuman.create(model_path="avatar.imx", api_secret="...")

await runtime.start()
await runtime.push_audio(audio_bytes, sample_rate=16000, last_chunk=False)
await runtime.flush()  # marks end of speech

async for frame in runtime.run():
    frame.bgr_image     # numpy array (H, W, 3) — BGR video frame
    frame.audio_chunk   # synchronized audio (int16, 16kHz, mono)
    frame.end_of_speech # True when speech segment finishes

await runtime.stop()
```

## Requirements

- Python 3.9–3.14
- Linux x86_64/arm64 or macOS (Apple Silicon, macOS 15+)

## Links

- [bitHuman Documentation](https://docs.bithuman.ai)
- [bitHuman Console](https://www.bithuman.ai)
