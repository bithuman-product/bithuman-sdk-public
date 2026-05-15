#!/usr/bin/env bash
# Start a local bitHuman streaming server.
#
# This launches an HTTP server that streams lip-synced video frames
# from an .imx model in real time. Clients POST audio to /audio and
# read the MJPEG stream from /video.mjpg at 25 FPS. (No WebSocket.)
#
# Prerequisites:
#   brew install bithuman-product/bithuman/bithuman   # or the curl one-liner
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

# Defaults match the CLI (`bithuman stream`).
PORT=3001
HOST="127.0.0.1"

# Parse optional flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "Starting bitHuman streaming server"
echo "  Model:  $MODEL"
echo "  Server: http://$HOST:$PORT"
echo ""
echo "Endpoints:"
echo "  POST http://$HOST:$PORT/audio        raw f32 PCM in"
echo "  GET  http://$HOST:$PORT/video.mjpg   lip-synced MJPEG out (25 FPS)"
echo "  POST http://$HOST:$PORT/action       action trigger"
echo "  GET  http://$HOST:$PORT/status       server status"
echo ""
echo "Drive it from another shell:  bithuman speak clip.wav --port $PORT"
echo "Press Ctrl+C to stop."
echo ""

bithuman stream --model "$MODEL" --port "$PORT" --host "$HOST"
