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
| **[local-avatar.py](local-avatar.py)** | Load an avatar model file, play audio through it, see the animated face | Download a `.imx` model file (see below) |
| **[cloud-avatar.py](cloud-avatar.py)** | Run a cloud-hosted avatar with AI conversation | LiveKit server + OpenAI API key |

**Recommended: start with `local-avatar.py`** — it has fewer dependencies.

## Step 3: Run it

### Option A: Local avatar (recommended first try)

```bash
# Install the SDK
pip install -r requirements.txt

# Download a sample avatar model from bithuman.ai:
#   Go to https://www.bithuman.ai/#explore
#   Click the ... menu on any agent → Download
#   Save the .imx file to this directory

# Run it (replace avatar.imx with your downloaded file name)
python local-avatar.py --model avatar.imx --audio speech.wav
```

A window will open showing the avatar lip-syncing to the audio. Press `q` to quit.

> **Don't have a .wav file?** The full examples in [python/local-essence/](../python/local-essence/) include a sample `speech.wav` you can copy.

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
| [.env.example](.env.example) | Template for environment variables (copy to `.env` and fill in) |
| [requirements.txt](requirements.txt) | Python dependencies for both scripts |
