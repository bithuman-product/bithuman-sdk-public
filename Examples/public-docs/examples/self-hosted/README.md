# Self-Hosted bitHuman Agent Examples

Run bitHuman avatar agents on your own infrastructure using LiveKit Agents.

## Examples

| File | Description |
|------|-------------|
| `agent.py` | Basic agent -- native `AsyncBithuman` runtime with the `VideoGenerator` interface |
| `agent_with_dynamics.py` | Adds keyword-triggered gestures via `VideoControl` (voice + text input) |
| `pipecat/` | Pipecat-based agents with Daily.co or LiveKit transport (see [pipecat/README.md](pipecat/README.md)) |

## Prerequisites

1. **bitHuman API secret** from [platform.bithuman.ai](https://platform.bithuman.ai)
2. **Avatar model file** (`.imx` format)
3. **OpenAI API key** (GPT-4o Realtime)
4. **LiveKit server** (Cloud or self-hosted)

## Quick start

```bash
cd examples/self-hosted
pip install -r requirements.txt
cp env.example .env   # then fill in your keys
python agent.py dev
```

## Environment variables

```env
# Required
BITHUMAN_API_SECRET=your_api_secret
BITHUMAN_MODEL_PATH=/path/to/avatar.imx
OPENAI_API_KEY=your_openai_key
LIVEKIT_URL=wss://your-livekit-server.com
LIVEKIT_API_KEY=your_livekit_key
LIVEKIT_API_SECRET=your_livekit_secret

# Optional (dynamics agent only)
BITHUMAN_AGENT_ID=your_agent_id   # enables Dynamics API gesture discovery
BITHUMAN_API_TOKEN=your_token     # optional auth token
```

## How it works

### agent.py

1. Connects to a LiveKit room and waits for a participant.
2. Creates an `AsyncBithuman` runtime from the local `.imx` model.
3. Wraps it in a `BithumanVideoGenerator` (implements LiveKit's `VideoGenerator`).
4. Starts an `AvatarRunner` that publishes video/audio tracks to the room.
5. Runs an `AgentSession` with OpenAI Realtime for conversation.

### agent_with_dynamics.py

Builds on the above and adds:

- **Keyword detection** -- scans voice transcriptions and text chat for trigger words.
- **Gesture triggering** -- sends `VideoControl(action=...)` to the runtime.
- **Cooldown** -- prevents the same gesture from firing repeatedly (default 3 s).
- **Dynamics API** -- if `BITHUMAN_AGENT_ID` is set, fetches available gestures and auto-builds keyword mappings.
- **Prewarm** -- pre-loads VAD and optionally the bitHuman runtime for faster cold starts.

Default keyword mappings (customizable in code):

| Keywords | Gesture |
|----------|---------|
| laugh, laughing, haha, funny | `laugh_react` |
| hello, hi, hey, goodbye, bye | `mini_wave_hello` |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Model loading error | Verify `BITHUMAN_MODEL_PATH` points to a valid `.imx` file |
| API auth failure | Check `BITHUMAN_API_SECRET` |
| LiveKit connection timeout | Verify `LIVEKIT_URL` and credentials; check network |
| High memory usage | Increase `job_memory_warn_mb` or use a smaller model |

## Support

- [bitHuman docs](https://docs.bithuman.ai)
- [GitHub Issues](https://github.com/bithuman-product/examples/issues)
- [Discord](https://discord.gg/bithuman)
