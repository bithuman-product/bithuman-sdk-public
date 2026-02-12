# AI Conversation — Voice Agent with Avatar

Talk to an AI and watch it respond through a lip-synced bitHuman avatar.

## Local mode (no server needed)

```bash
pip install -r requirements.txt

# Set in .env:
#   BITHUMAN_AVATAR_MODEL=/path/to/avatar.imx
#   BITHUMAN_API_SECRET=your_secret
#   OPENAI_API_KEY=your_openai_key

python local_agent.py
```

## WebRTC mode (LiveKit room, multiple viewers)

```bash
# Also set in .env:
#   LIVEKIT_URL=wss://your-server.livekit.cloud
#   LIVEKIT_API_KEY=your_key
#   LIVEKIT_API_SECRET=your_secret

python webrtc_agent.py dev
```

## What it demonstrates

- **local_agent.py**: OpenAI Realtime → bitHuman avatar in a local window
- **webrtc_agent.py**: Same AI, but published to a LiveKit room via `VideoGenerator`
- Both use the same `AsyncBithuman.create()` runtime under the hood
