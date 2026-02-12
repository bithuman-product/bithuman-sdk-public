# Live Avatar — Microphone Input

Talk into your microphone and watch the avatar animate in real time.

## Run

```bash
pip install -r requirements.txt
python live_avatar.py --model /path/to/avatar.imx
python live_avatar.py --model /path/to/avatar.imx --echo  # hear yourself back
```

## What it demonstrates

- Real-time microphone capture via LiveKit audio utilities
- Silence detection to avoid pushing dead air
- Streaming audio to the runtime with `push_audio(..., last_chunk=False)`
- Low-latency local display with `LocalVideoPlayer`
