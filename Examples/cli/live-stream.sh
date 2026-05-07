#!/usr/bin/env bash
# Start a local bitHuman streaming server.
#
# This launches a WebSocket server that streams lip-synced video frames
# from an .imx model in real time. Clients connect over WebSocket and
# push audio; the server responds with animated video frames at 25 FPS.
#
# Prerequisites:
#   pip install bithuman
#   export BITHUMAN_API_SECRET=your_secret
#
# Usage:
#   ./live-stream.sh <model.imx>
#   ./live-stream.sh <model.imx> --port 9000
#   ./live-stream.sh <model.imx> --port 9000 --host 0.0.0.0
set -euo pipefail

export BITHUMAN_API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"

MODEL="${1:?Usage: ./live-stream.sh <model.imx> [--port PORT] [--host HOST]}"
shift

# Default port and host
PORT=8765
HOST="127.0.0.1"

# Parse optional flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Install the SDK if not already installed
pip install -q bithuman

echo "Starting bitHuman streaming server"
echo "  Model:  $MODEL"
echo "  Server: ws://$HOST:$PORT"
echo ""
echo "Connect a WebSocket client to ws://$HOST:$PORT to send audio and"
echo "receive lip-synced video frames in real time."
echo ""
echo "Press Ctrl+C to stop."
echo ""

bithuman stream "$MODEL" --port "$PORT" --host "$HOST"
