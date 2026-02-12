# Quickstart — Audio File to Avatar

The simplest bitHuman example: play an audio file and watch the avatar lip-sync in real time.

## Run

```bash
pip install -r requirements.txt
python play_audio.py --model /path/to/avatar.imx --audio-file speech.wav
```

Press `q` to quit.

## What it demonstrates

- Creating a `AsyncBithuman` runtime with a `.imx` model
- Streaming audio chunks and calling `flush()` to mark end of speech
- Consuming video frames (`frame.bgr_image`) and audio (`frame.audio_chunk`)
