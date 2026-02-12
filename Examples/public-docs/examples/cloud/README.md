# bitHuman Cloud Examples

Run AI-powered avatars in the cloud — no GPU required on your machine.

## Setup

```bash
pip install -r requirements.txt

# Required in .env:
BITHUMAN_API_SECRET=your_secret
LIVEKIT_URL=wss://your-server.livekit.cloud
LIVEKIT_API_KEY=your_key
LIVEKIT_API_SECRET=your_secret
OPENAI_API_KEY=your_openai_key
```

## Examples

| File | What it does |
|------|-------------|
| `quickstart.py` | Minimal cloud agent (~40 lines) |
| `custom_avatar.py` | Use your own image as the avatar face |
| `gestures.py` | Trigger avatar gestures from speech keywords |
| `custom_endpoint.py` | Point to a self-hosted GPU endpoint |
| `diagnose.py` | Pre-flight check for environment and credentials |

## Run

```bash
python quickstart.py dev
python custom_avatar.py dev
python gestures.py dev
python custom_endpoint.py dev
python diagnose.py
```
