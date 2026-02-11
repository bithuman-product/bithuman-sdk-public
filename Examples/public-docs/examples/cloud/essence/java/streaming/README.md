# BitHuman Essence Cloud — Java Streaming Demo

A **self-contained, zero-dependency** Java server that lets you talk to a bitHuman cloud-hosted Essence avatar in real time through your browser.

## How It Works

```
┌──────────────┐   WebRTC (audio/video)   ┌────────────────────┐
│  Browser     │ ◄═══════════════════════► │  LiveKit Cloud     │
│  (localhost) │                           │                    │
└──────┬───────┘                           │  ┌──────────────┐  │
       │ HTTP                              │  │ Python       │  │
┌──────▼───────┐                           │  │ agent.py     │  │
│  Java Server │  bitHuman REST API        │  │ (orchestrator│  │
│  :8080       │──────────────────────────►│  └──────┬───────┘  │
│  (this demo) │  (speak, add-context)     │         ▼          │
└──────────────┘                           │  bitHuman Cloud    │
                                           │  (avatar rendering)│
                                           └────────────────────┘
```

1. **Python `agent.py`** runs as a LiveKit Agent — it wires up the LLM (OpenAI), voice activity detection, and bitHuman cloud avatar rendering
2. **This Java server** generates LiveKit room tokens and serves a minimal web client
3. **Your browser** connects to the LiveKit room via WebRTC, streams your microphone audio, and receives the avatar's video + audio response

## Prerequisites

| Requirement | Where to get it |
|-------------|----------------|
| **Java 11+** | Pre-installed on most systems |
| **Python 3.9+** | For running `agent.py` |
| **bitHuman API secret** (`sk_bh_…`) | [imaginex.bithuman.ai](https://imaginex.bithuman.ai/#developer) |
| **OpenAI API key** (`sk-proj_…`) | [platform.openai.com](https://platform.openai.com/api-keys) |
| **LiveKit Cloud account** | [livekit.io](https://livekit.io) (free tier works) |

## Quick Start

### Step 1 — Set up the Python avatar agent

```bash
cd /path/to/public-docs/examples/cloud/essence

# Create a virtual environment and install dependencies
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Create a `.env` file in the `essence/` directory:

```bash
BITHUMAN_API_SECRET=sk_bh_your_secret_here
OPENAI_API_KEY=sk-proj_your_key_here
LIVEKIT_API_KEY=APIyour_key
LIVEKIT_API_SECRET=your_secret
LIVEKIT_URL=wss://your-project.livekit.cloud
```

### Step 2 — Start the Python agent (Terminal 1)

```bash
cd /path/to/public-docs/examples/cloud/essence
source .venv/bin/activate
python agent.py dev
```

Wait for: `Agent is ready and waiting for participants`

### Step 3 — Start the Java server (Terminal 2)

```bash
cd /path/to/public-docs/examples/cloud/essence/java/streaming

# Set environment variables (same LiveKit + bitHuman credentials)
export LIVEKIT_API_KEY=APIyour_key
export LIVEKIT_API_SECRET=your_secret
export LIVEKIT_URL=wss://your-project.livekit.cloud
export BITHUMAN_API_SECRET=sk_bh_your_secret_here
export BITHUMAN_AVATAR_ID=A31KJC8622    # optional, defaults to demo avatar

# Compile and run
javac BitHumanStreamingDemo.java
java BitHumanStreamingDemo
```

### Step 4 — Open your browser

Navigate to **http://localhost:8080** and:

1. Click **Connect** to join the LiveKit room
2. Grant microphone permissions when prompted
3. Wait ~30 seconds for the avatar to initialize
4. Start talking — the avatar responds with video + audio!

## Features

| Feature | How |
|---------|-----|
| **Real-time video/audio** | WebRTC via LiveKit — avatar streams video, you stream microphone audio |
| **Voice conversation** | Speak into your mic, avatar responds via OpenAI LLM |
| **Make avatar speak** | Type a message in the "Speak" input — avatar says it out loud |
| **Add context** | Inject background knowledge — avatar uses it in future responses |
| **Mic toggle** | Mute/unmute your microphone during the session |

## API Endpoints (Java Server)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Web client page |
| `/api/token` | GET | Generate a LiveKit room token |
| `/api/speak` | POST | Make the avatar speak a message |
| `/api/context` | POST | Add background context to the avatar |

### Example: Make avatar speak from curl

```bash
curl -X POST http://localhost:8080/api/speak \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from the Java integration!"}'
```

### Example: Add context from curl

```bash
curl -X POST http://localhost:8080/api/context \
  -H "Content-Type: application/json" \
  -d '{"context": "The user is a Java developer integrating bitHuman.", "type": "add_context"}'
```

## How the Token Generation Works

The Java server generates LiveKit access tokens (JWTs) using only `javax.crypto.Mac` — no external libraries required. The token structure:

```
Header:  {"alg":"HS256","typ":"JWT"}
Payload: {
  "iss": "<LIVEKIT_API_KEY>",     // issuer = your API key
  "sub": "<participant-identity>", // unique participant ID
  "exp": <unix-timestamp>,         // 24h expiration
  "video": {                       // LiveKit room permissions
    "room": "<room-name>",
    "roomJoin": true,
    "canPublish": true,
    "canSubscribe": true
  }
}
Signature: HMAC-SHA256(header.payload, LIVEKIT_API_SECRET)
```

## Customization

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `LIVEKIT_API_KEY` | _(required)_ | LiveKit Cloud API key |
| `LIVEKIT_API_SECRET` | _(required)_ | LiveKit Cloud API secret |
| `LIVEKIT_URL` | _(required)_ | LiveKit WebSocket URL |
| `BITHUMAN_API_SECRET` | _(optional)_ | bitHuman API secret for REST control |
| `BITHUMAN_AVATAR_ID` | `A31KJC8622` | Avatar agent ID |
| `PORT` | `8080` | HTTP server port |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Waiting for avatar..." never resolves | Check that `agent.py` is running and connected to the same LiveKit project |
| No audio from avatar | Check browser audio permissions, try a different browser |
| Token errors | Verify `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET` match your LiveKit Cloud project |
| Avatar not responding to speech | Verify `OPENAI_API_KEY` is set in the agent's `.env` file |
| `BITHUMAN_API_SECRET` warnings | Get a secret at [imaginex.bithuman.ai](https://imaginex.bithuman.ai/#developer) |

## Integration Into Your Java Application

The key components you can reuse in your own Java project:

1. **`createLiveKitToken()`** — Zero-dependency LiveKit JWT generation
2. **`bithumanPost()`** — bitHuman REST API client (speak, add-context, agent management)
3. **Token endpoint pattern** — Your Java backend generates tokens, web/mobile clients connect to LiveKit

For production, consider using the official [LiveKit Server SDK for Java](https://github.com/livekit/server-sdk-java) (`io.livekit:livekit-server`) for token generation.

## Related Resources

- [BitHuman REST API Example](../BitHumanExample.java) — Agent management without streaming
- [Python Agent Example](../../agent.py) — The server-side avatar orchestrator
- [LiveKit Cloud Plugin Docs](../../../../docs/preview/livekit-cloud-plugin.md)
- [Agent Context API Docs](../../../../docs/preview/agent-context-api.md)
- [LiveKit Agents Playground](https://agents-playground.livekit.io) — Alternative web client for testing
