# Quickstart — Your First bitHuman Avatar

Get a talking avatar running in about 5 minutes. You'll need an API key first.

## Step 1: Get your API key (30 seconds)

1. Go to [www.bithuman.ai](https://www.bithuman.ai) and create a free account
2. Click **Developer** → **API Keys**
3. Copy your API secret

```bash
export BITHUMAN_API_SECRET="paste_your_key_here"
```

## Step 2: Pick an example

| Example | What it does | Extra setup needed |
|---------|-------------|--------------------|
| **[local-avatar.py](local-avatar.py)** | Load an avatar model, play audio through it, see the animated face | None — auto-downloads a sample model on first run |
| **[cloud-avatar.py](cloud-avatar.py)** | Run a cloud-hosted avatar with AI conversation | LiveKit server + OpenAI API key |

**Recommended: start with `local-avatar.py`** — it has fewer dependencies.

## Step 3: Run it

### Option A: Local avatar (recommended first try)

```bash
# Install the SDK
pip install -r requirements.txt

# Run it — auto-downloads a sample avatar model (112 MB, one-time) if you don't specify one
python local-avatar.py

# Or use your own model:
python local-avatar.py --model your-avatar.imx --audio speech.wav
```

A window will open showing the avatar lip-syncing to the audio. Press `q` to quit.

> **First run is slow (up to 60 seconds).** The first time: the sample model downloads (112 MB), then the SDK may convert it from legacy format to v2. Both are one-time costs — subsequent runs start in under 2 seconds.

> **Want to use your own avatar?** Download a `.imx` file from [bithuman.ai → Explore](https://www.bithuman.ai/#explore) (click the **...** menu on any agent → **Download**) and pass it with `--model your-file.imx`.

> **Sample audio included.** This directory ships a `speech.wav` file you can use for testing. No need to find your own audio.

> **macOS warning about AVFAudioReceiver / libavdevice?** This is a harmless conflict between OpenCV and PyAV shipping their own FFmpeg libraries. It prints once at import and doesn't affect functionality. If it bothers you: `pip install opencv-python-headless` (which `bithuman` already depends on) and avoid installing the full `opencv-python` package.

### Option B: Cloud avatar (more setup, but no model download needed)

This requires a LiveKit server and OpenAI API key. See [.env.example](.env.example) for all required variables.

```bash
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your actual keys
python cloud-avatar.py dev
```

## What's next?

Once your first demo works, pick the path that matches what you're building:

| I want to build... | Go to |
|---|---|
| A web app with a talking avatar | [python/cloud-essence/](../python/cloud-essence/) |
| A server-side avatar (my own hardware) | [python/local-essence/](../python/local-essence/) |
| A Mac/iPad/iPhone app | [swift/](../swift/) |
| Something without writing code | [cli/](../cli/) |
| An integration in Java, Go, or another language | [rest-api/](../rest-api/) |

## Files in this directory

| File | Purpose |
|------|---------|
| [local-avatar.py](local-avatar.py) | Minimal Python script — loads a model, pushes audio, displays frames |
| [cloud-avatar.py](cloud-avatar.py) | LiveKit cloud agent with OpenAI voice chat |
| [speech.wav](speech.wav) | Sample 13-second audio clip for testing |
| [.env.example](.env.example) | Template for environment variables (copy to `.env` and fill in) |
| [requirements.txt](requirements.txt) | Python dependencies for both scripts |
