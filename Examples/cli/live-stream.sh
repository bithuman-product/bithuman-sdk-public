#!/usr/bin/env bash
# Start a local bitHuman avatar server.
#
# `bithuman run` brings up a self-contained LiveKit pool with an
# embedded livekit-server and serves a landing page that connects
# the browser to the avatar over WebRTC. Open the printed URL,
# grant mic permission, and talk.
#
# Prerequisites:
#   brew install bithuman-product/bithuman/bithuman-cli   # or the curl one-liner
#   export BITHUMAN_API_SECRET=your_secret
#   export OPENAI_API_KEY=sk-...                      # cloud brain (default)
#   #   ...or:  BITHUMAN_LOCAL=1                      # on-device brain
#
# Usage:
#   ./live-stream.sh <model.imx>
#   ./live-stream.sh <model.imx> --port 8088
#   ./live-stream.sh <model.imx> --port 8088 --host 0.0.0.0
set -euo pipefail

export BITHUMAN_API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"

MODEL="${1:?Usage: ./live-stream.sh <model.imx> [--port PORT] [--host HOST]}"
shift

# Defaults match the CLI (`bithuman run`).
PORT=8088
HOST="127.0.0.1"

# Parse optional flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "Starting bitHuman avatar server"
echo "  Model:  $MODEL"
echo "  Server: http://$HOST:$PORT"
echo ""
echo "Open the printed landing-page URL in your browser, grant mic"
echo "permission, and start talking. Press Ctrl+C to stop."
echo ""

bithuman run "$MODEL" --host "$HOST" --port "$PORT"
