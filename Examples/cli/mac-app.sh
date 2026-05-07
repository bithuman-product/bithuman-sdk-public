#!/usr/bin/env bash
# Install and run the bitHuman desktop app on macOS via Homebrew.
#
# bithuman-cli is a native Mac application that runs an AI avatar with
# voice conversation, text chat, or video input -- all locally on
# Apple Silicon (M3 or later).
#
# Prerequisites:
#   - macOS with Apple Silicon M3+ (M3, M3 Pro/Max, M4, M4 Pro/Max)
#   - Homebrew (https://brew.sh)
#   - A bitHuman API secret (https://www.bithuman.ai/#developer)
#
# Usage:
#   ./mac-app.sh install        Install bithuman-cli via Homebrew
#   ./mac-app.sh voice           Voice conversation mode (microphone)
#   ./mac-app.sh text            Text chat mode (type messages)
#   ./mac-app.sh video           Video chat mode (webcam)
set -euo pipefail

export BITHUMAN_API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"

ACTION="${1:-help}"

case "$ACTION" in
  install)
    echo "Installing bithuman-cli via Homebrew..."
    echo ""
    brew tap bithuman-product/tap
    brew install bithuman-cli
    echo ""
    echo "Done. Run: bithuman-cli --help"
    ;;

  voice)
    AGENT_ID="${2:-${BITHUMAN_AGENT_ID:?Provide agent ID as second argument or set BITHUMAN_AGENT_ID}}"
    echo "Starting voice conversation with agent $AGENT_ID..."
    echo "Speak into your microphone. The avatar responds in real time."
    echo "Press Ctrl+C to stop."
    echo ""
    bithuman-cli --agent-id "$AGENT_ID" --mode voice
    ;;

  text)
    AGENT_ID="${2:-${BITHUMAN_AGENT_ID:?Provide agent ID as second argument or set BITHUMAN_AGENT_ID}}"
    echo "Starting text chat with agent $AGENT_ID..."
    echo "Type messages and the avatar speaks them aloud."
    echo "Press Ctrl+C to stop."
    echo ""
    bithuman-cli --agent-id "$AGENT_ID" --mode text
    ;;

  video)
    AGENT_ID="${2:-${BITHUMAN_AGENT_ID:?Provide agent ID as second argument or set BITHUMAN_AGENT_ID}}"
    echo "Starting video chat with agent $AGENT_ID..."
    echo "Uses your webcam and microphone for face-to-face conversation."
    echo "Press Ctrl+C to stop."
    echo ""
    bithuman-cli --agent-id "$AGENT_ID" --mode video
    ;;

  help|--help|-h)
    echo "bitHuman Desktop App (macOS)"
    echo ""
    echo "Usage:"
    echo "  ./mac-app.sh install              Install bithuman-cli via Homebrew"
    echo "  ./mac-app.sh voice [AGENT_ID]     Voice conversation (microphone)"
    echo "  ./mac-app.sh text  [AGENT_ID]     Text chat (type messages)"
    echo "  ./mac-app.sh video [AGENT_ID]     Video chat (webcam)"
    echo ""
    echo "Environment:"
    echo "  BITHUMAN_API_SECRET   Your API secret (required)"
    echo "  BITHUMAN_AGENT_ID     Default agent ID (used if not passed as argument)"
    echo ""
    echo "Requirements:"
    echo "  - macOS with Apple Silicon M3 or later"
    echo "  - Homebrew (https://brew.sh)"
    ;;

  *)
    echo "Unknown action: $ACTION"
    echo "Run ./mac-app.sh help for usage."
    exit 1
    ;;
esac
