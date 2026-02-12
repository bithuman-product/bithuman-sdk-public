# Web UI — Gradio + FastRTC

Talk to a bitHuman avatar through your browser using Gradio and FastRTC.

## Run

```bash
pip install -r requirements.txt

# Set in .env:
#   BITHUMAN_MODEL_ROOT=/path/to/models  (directory with .imx files)
#   BITHUMAN_API_SECRET=your_secret
#   OPENAI_API_KEY=your_openai_key

python app.py
```

Opens a Gradio web interface where you can select an avatar and start talking.

## What it demonstrates

- FastRTC `AsyncAudioVideoStreamHandler` for browser-based WebRTC
- Gradio UI with avatar selection dropdown
- Full AI conversation pipeline: mic → OpenAI Realtime → bitHuman → video stream
