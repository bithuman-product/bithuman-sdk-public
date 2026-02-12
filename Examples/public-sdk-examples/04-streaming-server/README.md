# Streaming Server — WebSocket to LiveKit

Stream a bitHuman avatar to a LiveKit room, controlled via WebSocket.
Clients send audio; viewers watch the animated avatar in any LiveKit-compatible player.

## Run the server

```bash
pip install -r requirements.txt
python server.py --room my-room --avatar-model avatar.imx \
    --livekit-url wss://your-server.livekit.cloud \
    --livekit-api-key KEY --livekit-api-secret SECRET
```

## Send audio from the client

```bash
python client.py stream /path/to/speech.wav
python client.py interrupt  # stop current playback
```

## Architecture

```
WebSocket Client ──audio──▶ server.py ──▶ bitHuman Runtime
                                              │
                                   video + audio frames
                                              │
                                         LiveKit Room ──▶ Viewers
```
