#!/usr/bin/env bash
# Install and run the bitHuman live avatar via the `bithuman` CLI.
#
# `bithuman run` brings up a self-contained avatar server (LiveKit
# pool + embedded livekit-server) and prints a landing-page URL.
# Open it in a browser, grant mic permission, and talk.
#
# Brain selection (no flag — env-driven):
#   - cloud (default):  OPENAI_API_KEY=sk-...      (OpenAI Realtime)
#   - on-device:        BITHUMAN_LOCAL=1           (whisper.cpp +
#                                                   llama.cpp +
#                                                   Supertonic)
#                       Requires `pip install 'bithuman-cli[local]'`.
#
# Prerequisites:
#   - macOS with Apple Silicon M3+ (or Linux x86_64 / aarch64)
#   - Homebrew (https://brew.sh) for the install step
#   - A bitHuman API secret (https://www.bithuman.ai/#developer)
#
# Usage:
#   ./mac-app.sh install              Install the bithuman CLI via Homebrew
#   ./mac-app.sh run [model.imx]      Run the live avatar
set -euo pipefail

ACTION="${1:-help}"

if [[ "$ACTION" != "install" && "$ACTION" != "help" && "$ACTION" != "--help" && "$ACTION" != "-h" ]]; then
  export BITHUMAN_API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"
fi

case "$ACTION" in
  install)
    echo "Installing the bithuman CLI via Homebrew..."
    echo ""
    brew install bithuman-product/bithuman/bithuman-cli
    echo ""
    echo "Done. Run: bithuman doctor"
    ;;

  run)
    MODEL="${2:?Usage: ./mac-app.sh run <model.imx>}"
    echo "Starting the live avatar."
    echo "Open the printed landing-page URL in your browser, grant"
    echo "mic permission, and talk."
    echo ""
    echo "Brain: set OPENAI_API_KEY=sk-... for the cloud backend,"
    echo "       or BITHUMAN_LOCAL=1 for the on-device backend."
    echo "Press Ctrl+C to stop."
    echo ""
    bithuman run "$MODEL"
    ;;

  help|--help|-h)
    echo "bitHuman CLI live avatar"
    echo ""
    echo "Usage:"
    echo "  ./mac-app.sh install            Install the bithuman CLI via Homebrew"
    echo "  ./mac-app.sh run <model.imx>    Run the live avatar"
    echo ""
    echo "Environment:"
    echo "  BITHUMAN_API_SECRET   Your API secret (required)"
    echo "  OPENAI_API_KEY        Cloud brain (default path)"
    echo "  BITHUMAN_LOCAL        =1 for on-device brain"
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
