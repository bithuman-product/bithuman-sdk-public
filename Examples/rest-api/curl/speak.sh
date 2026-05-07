#!/usr/bin/env bash
# Make a live agent speak a message out loud.
# The agent must be in an active session (connected via LiveKit or web UI).
# Usage: ./speak.sh [AGENT_ID] [MESSAGE]
set -euo pipefail

API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"
BASE="https://api.bithuman.ai"

AGENT_ID="${1:-${BITHUMAN_AGENT_ID:?Provide agent ID as argument or set BITHUMAN_AGENT_ID}}"
MESSAGE="${2:-Hello from the bitHuman API!}"

echo "Making agent $AGENT_ID speak: \"$MESSAGE\""

curl -s -X POST "$BASE/v1/agent/$AGENT_ID/speak" \
  -H "Content-Type: application/json" \
  -H "api-secret: $API_SECRET" \
  -d "{\"message\": \"$MESSAGE\"}" | python3 -m json.tool
