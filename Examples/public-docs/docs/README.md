# bitHuman SDK

> **Create lifelike digital avatars that respond to audio in real-time.**

- **[bitHuman + OpenAI](https://github.com/bithuman-product/examples/tree/main/public-docker-example)** -- Complete Docker setup with web UI. Cloud-powered AI conversations via LiveKit + OpenAI + Web Interface.
- **[bitHuman + Apple](https://github.com/bithuman-product/examples/tree/main/public-macos-offline-example)** -- 100% local, most cost effective. Private on-device AI via Apple Speech + Siri + Ollama LLM.

---

## What is bitHuman SDK?

bitHuman SDK lets you build **interactive avatars** for your applications:

- **CPU-Only Operation** -- Runs entirely on host CPU, no GPU required.
- **10x Lower Costs** -- Choose host device or CPU cloud for significant cost savings.
- **Real-time Animation** -- 25 FPS video with dynamic movement.
- **Audio-driven** -- Realistic facial movements from any audio input.
- **Easy Integration** -- 3 lines of code to get started.
- **Web Ready** -- Deploy to browsers with LiveKit integration.

---

## Quick Start

### Complete Docker Demo

Full end-to-end bitHuman + LiveKit app with web UI.

**What you get:** Visual agent with real-time conversation, web interface, and audio support.

**[Full Example Repository](https://github.com/bithuman-product/examples/tree/main/public-docker-example)**

#### 1. Get Your Credentials
- **Free API Secret** -- [imaginex.bithuman.ai](https://imaginex.bithuman.ai)

  ![Free API Secret](assets/images/example-api-secret.jpg)

- **Download Avatar** -- [Community Models](https://imaginex.bithuman.ai/#community)

  ![Download Avatar](assets/images/example-download-button.jpg)

#### 2. Clone and Setup
```bash
# Clone the complete demo
git clone https://github.com/bithuman-product/examples.git
cd public-docker-example

# Create environment file
echo "BITHUMAN_API_SECRET=your_api_secret_here" > .env
echo "OPENAI_API_KEY=your_openai_key_here" >> .env

# Add your .imx model files to models/ directory
mkdir -p models
# Copy your downloaded .imx files here
```

#### 3. Launch Complete App
```bash
# Start all services (LiveKit + Agent + Web UI + Redis)
docker compose up

# Open your browser to http://localhost:4202
```

You now have a complete bitHuman application with:
- Real-time avatar animation
- Voice conversation capabilities
- Professional web interface
- Full LiveKit integration

---

### Alternative: SDK Integration

For custom applications, integrate bitHuman directly:

#### Install and Setup
```bash
# Install SDK
pip install bithuman --upgrade

# Set environment
export BITHUMAN_API_SECRET="your_secret"
export BITHUMAN_MODEL_PATH="/path/to/model.imx"
```

#### Your First Avatar (3 lines)
```python
from bithuman import AsyncBithuman

runtime = await AsyncBithuman.create(model_path="model.imx", api_secret="secret")
async for frame in runtime.run():
    display_frame(frame)
```

---

## What You Can Build

### Desktop Apps
- Voice assistants
- Interactive kiosks
- Custom interfaces

### Web Applications
- Video chat avatars
- Customer service bots
- Virtual receptionists

### IoT and Edge
- Smart home assistants
- Retail demonstrations
- Industrial interfaces

---

## Documentation Structure

### [Getting Started](getting-started/overview.md)
Quick setup, prompts, media uploads, and animal mode.

### [Examples](examples/overview.md)
5 examples from basic to advanced.

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **Linux (x86_64)** | Full Support | Production ready |
| **Linux (ARM64)** | Full Support | Suitable for edge deployments |
| **macOS (Apple Silicon)** | Full Support | M2+ recommended, M4 ideal |
| **Windows** | Full Support | Via WSL |
