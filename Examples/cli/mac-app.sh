#!/usr/bin/env bash
# Install and run bitHuman conversation modes via the `bithuman` CLI.
#
# The `bithuman` binary runs voice / text / browser-avatar
# conversations locally on Apple Silicon (M3 or later) — no agent ID,
# no separate desktop app. Conversations are driven by `.imx` models.
#
# Prerequisites:
#   - macOS with Apple Silicon M3+ (or Linux x86_64 / aarch64)
#   - Homebrew (https://brew.sh) for the install step
#   - A bitHuman API secret (https://www.bithuman.ai/#developer)
#
# Usage:
#   ./mac-app.sh install                 Install the bithuman CLI via Homebrew
#   ./mac-app.sh voice                   Voice conversation (microphone)
#   ./mac-app.sh text                    Text chat (type messages)
#   ./mac-app.sh avatar [model.imx]      Browser-served lip-synced avatar
set -euo pipefail

ACTION="${1:-help}"

if [[ "$ACTION" != "install" && "$ACTION" != "help" && "$ACTION" != "--help" && "$ACTION" != "-h" ]]; then
  export BITHUMAN_API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"
fi

# Optional second arg: a model .imx path for `avatar`. If omitted, the
# CLI uses the bundled sample avatar. `voice`/`text` need no model.
MODEL_ARG=()
if [[ -n "${2:-}" ]]; then
  MODEL_ARG=(--model "$2")
fi

case "$ACTION" in
  install)
    echo "Installing the bithuman CLI via Homebrew..."
    echo ""
    brew install bithuman-product/bithuman/bithuman
    echo ""
    echo "Done. Run: bithuman doctor"
    ;;

  voice)
    echo "Starting voice conversation."
    echo "Speak into your microphone; the model replies aloud."
    echo "Set OPENAI_API_KEY for the instant cloud backend, or add --local."
    echo "Press Ctrl+C to stop."
    echo ""
    bithuman voice
    ;;

  text)
    echo "Starting text chat. Type messages; the model replies as text."
    echo "Set OPENAI_API_KEY for the instant cloud backend, or add --local."
    echo "Press Ctrl+C to stop."
    echo ""
    bithuman text
    ;;

  avatar)
    echo "Starting the browser-served avatar at http://127.0.0.1:8080"
    echo "Open the URL, grant mic permission, and talk."
    echo "Press Ctrl+C to stop."
    echo ""
    bithuman avatar "${MODEL_ARG[@]}"
    ;;

  help|--help|-h)
    echo "bitHuman CLI conversation modes"
    echo ""
    echo "Usage:"
    echo "  ./mac-app.sh install              Install the bithuman CLI via Homebrew"
    echo "  ./mac-app.sh voice                Voice conversation (microphone)"
    echo "  ./mac-app.sh text                 Text chat (type messages)"
    echo "  ./mac-app.sh avatar [model.imx]   Browser-served lip-synced avatar"
    echo ""
    echo "Environment:"
    echo "  BITHUMAN_API_SECRET   Your API secret (required for avatar mode)"
    echo "  OPENAI_API_KEY        Optional — enables the instant cloud backend"
    echo ""
    echo "Requirements:"
    echo "  - macOS Apple Silicon M3+ (or Linux x86_64 / aarch64)"
    echo "  - Homebrew (https://brew.sh) for the install step"
    ;;

  *)
    echo "Unknown action: $ACTION"
    echo "Run ./mac-app.sh help for usage."
    exit 1
    ;;
esac
