#!/usr/bin/env bash
# Render a lip-synced video from an .imx model and audio file.
# Get your API secret at https://www.bithuman.ai (Developer section).
set -euo pipefail

export BITHUMAN_API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first}"

# Install the CLI if not already installed.
#   macOS:  brew install bithuman-product/bithuman/bithuman-cli
#   PyPI:   pip install bithuman-cli
# (See ./README.md for the curl one-liner that works on Linux too.)

MODEL="${1:?Usage: ./render-video.sh <model.imx>}"

# Download sample audio if you don't have one
if [ ! -f speech.wav ]; then
  curl -sO https://raw.githubusercontent.com/bithuman-product/bithuman-sdk-public/main/Examples/python/local-essence/speech.wav
fi

# Render: .imx + audio -> MP4
bithuman render "$MODEL" --audio speech.wav --output demo.mp4

echo "Done! Open demo.mp4 to see your avatar talking."
