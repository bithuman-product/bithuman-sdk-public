# bitHuman SDK -- GitHub Copilot Instructions

## What is bitHuman

bitHuman is a real-time avatar animation platform. You push audio in and get lip-synced video frames out at 25 FPS. Two models: Essence (CPU, `.imx` files) and Expression (GPU or Apple Silicon M3+, any face image). Four integration paths: Python SDK, Swift SDK, CLI, and REST API.

## Repository Structure

This is the public SDK repo. It contains:

- `Package.swift` -- Swift SDK binary target (SwiftPM, `bitHumanKit` XCFramework)
- `python/` -- Python SDK docs and changelog (wheels on PyPI: `pip install bithuman`)
- `Examples/` -- Runnable examples for all platforms and integration paths
- `docs/` -- Source for docs.bithuman.ai (Mintlify MDX)
- `docs/api-reference/openapi.yaml` -- OpenAPI 3.1 spec

The Swift SDK source and Python SDK internals are private.

## Authentication

- Python / REST / CLI: set `BITHUMAN_API_SECRET` environment variable
- Swift SDK: set `BITHUMAN_API_KEY` environment variable
- REST API: pass `api-secret: YOUR_SECRET` header
- Get keys at https://www.bithuman.ai/#developer

Never hardcode API secrets in source code. Always use environment variables.

## Python SDK Quick Reference

Install: `pip install bithuman --upgrade`
LiveKit plugin: `pip install livekit-plugins-bithuman` or `pip install bithuman[agent]`

### Core imports

```python
from bithuman import AsyncBithuman, Bithuman
from bithuman import AudioChunk, VideoFrame, VideoControl
from bithuman.audio import load_audio, float32_to_int16
```

### Core pattern

```python
import asyncio, os
from bithuman import AsyncBithuman
from bithuman.audio import load_audio, float32_to_int16

async def main():
    runtime = await AsyncBithuman.create(
        model_path="avatar.imx",
        api_secret=os.environ["BITHUMAN_API_SECRET"],
    )
    await runtime.start()

    pcm, sr = load_audio("speech.wav")
    pcm = float32_to_int16(pcm)
    chunk = sr // 25  # one chunk per video frame
    for i in range(0, len(pcm), chunk):
        await runtime.push_audio(pcm[i : i + chunk].tobytes(), sr)
    await runtime.flush()

    async for frame in runtime.run():
        if frame.has_image:
            image = frame.bgr_image       # np.ndarray (H,W,3) uint8 BGR
        if frame.end_of_speech:
            break
    await runtime.stop()

asyncio.run(main())
```

### Key methods

| Method | Purpose |
|---|---|
| `AsyncBithuman.create(model_path, api_secret)` | Create async runtime |
| `runtime.start()` | Initialize frame loop |
| `runtime.push_audio(pcm_bytes, sample_rate)` | Push int16 PCM audio |
| `runtime.flush()` | Signal end of audio segment |
| `runtime.interrupt()` | Cancel current playback |
| `runtime.run()` | Async iterator yielding VideoFrame |
| `runtime.push(VideoControl(action="wave"))` | Trigger gesture (Essence only) |
| `runtime.set_identity("face.jpg")` | Swap face (Expression only) |
| `runtime.stop()` | Shut down |

### Frame properties

| Property | Type | Description |
|---|---|---|
| `frame.bgr_image` | `np.ndarray` (H,W,3) uint8 | BGR image |
| `frame.audio_chunk` | bytes | Synchronized audio |
| `frame.has_image` | bool | Whether frame contains image |
| `frame.end_of_speech` | bool | Last frame of segment |
| `frame.frame_index` | int | Frame sequence number |

## Swift SDK Quick Reference

SwiftPM: `https://github.com/bithuman-product/bithuman-sdk-public.git` from `"0.8.1"`

```swift
import bitHumanKit
// Key types: BitHuman, VoiceAgent, AvatarView, HardwareCheck
```

Hardware floor: macOS M3+, iPad Pro M4+, iPhone 16 Pro+ (A18 Pro).
Do NOT pin below 0.8.1. The SDK internals are closed-source — consume the binary via `bithuman-sdk-public`.

## REST API Quick Reference

Base URL: `https://api.bithuman.ai`

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/v1/validate` | Verify API secret |
| POST | `/v1/agent/generate` | Create agent (prompt + image/video/audio) |
| GET | `/v1/agent/status/{agent_id}` | Poll generation (5s interval) |
| GET | `/v1/agent/{code}` | Get agent details |
| POST | `/v1/agent/{code}` | Update system prompt |
| POST | `/v1/agent/{code}/speak` | Make avatar speak text |
| POST | `/v1/agent/{code}/add-context` | Inject context silently |
| POST | `/v1/files/upload` | Upload media (URL or base64) |
| GET | `/v2/credit-summaries` | Check credit balance |
| POST | `/v1/embed-tokens/request` | Generate JWT for embed |
| POST | `/v1/dynamics/generate` | Create gesture animations |
| GET | `/v1/dynamics/{agent_id}` | List gestures |

Error format: `{"error": {"code": "...", "message": "...", "httpStatus": N}, "status": "error"}`

## CLI Quick Reference

```bash
export BITHUMAN_API_SECRET=your_secret
bithuman demo                                     # zero-arg hello world
bithuman generate avatar.imx --audio speech.wav   # render MP4
bithuman stream avatar.imx                        # local server on :3001
bithuman speak audio.wav                          # send to running server
bithuman info avatar.imx                          # model metadata
bithuman validate avatar.imx                      # check integrity
```

Homebrew alternative: `brew install bithuman-product/bithuman/bithuman`

## Two Models

| | Essence | Expression |
|---|---|---|
| Compute | CPU (any platform) | NVIDIA GPU or Apple Silicon M3+ |
| Source | Pre-built `.imx` file | Any face image |
| Gestures | Yes | No |
| Identity swap | No | Yes |

## Pricing (credits per minute)

- Essence self-hosted: 1 cr/min, cloud: 2 cr/min
- Expression self-hosted: 2 cr/min, cloud: 4 cr/min
- Agent generation: 250 cr one-time
- Free tier: 99 cr/month

## Example Locations

| Goal | Directory |
|---|---|
| Cloud Essence (Python) | `Examples/python/cloud-essence/` |
| Cloud Expression (Python) | `Examples/python/cloud-expression/` |
| Local Essence CPU (Python) | `Examples/python/local-essence/` |
| Local Expression GPU (Docker) | `Examples/python/local-expression-gpu/` |
| Local Expression Mac (Python) | `Examples/python/local-expression-mac/` |
| macOS voice agent (Swift) | `Examples/swift/macos-voice/` |
| macOS avatar (Swift) | `Examples/swift/macos-avatar/` |
| iOS avatar (Swift) | `Examples/swift/ios-avatar/` |
| CLI tools | `Examples/cli/` |
| REST API curl | `Examples/rest-api/curl/` |
| Next.js frontend | `Examples/integrations/nextjs-ui/` |
| Gradio web UI | `Examples/integrations/gradio-web/` |
| Offline Mac | `Examples/integrations/offline-mac/` |

## Common Mistakes to Avoid

- The SDK internals are closed-source; consume only the published binaries.
- Do not hardcode API secrets. Use environment variables.
- Do not use deprecated `figure_id`. Use `agent_code`.
- Do not pin Swift SDK below 0.8.1.
- Do not run Expression models on CPU (requires GPU or M3+).
- Do not poll agent status faster than every 5 seconds.
- Do not use `BITHUMAN_API_KEY` in Python -- use `BITHUMAN_API_SECRET`.

## Key Documentation Links

- Full docs: https://docs.bithuman.ai
- OpenAPI spec: https://docs.bithuman.ai/api-reference/openapi.yaml
- LLM-optimized: https://docs.bithuman.ai/llms.txt
- Python PyPI: https://pypi.org/project/bithuman/
- Discord: https://discord.gg/ES953n7bPA
