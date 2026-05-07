#!/usr/bin/env bash
# Make an agent speak a message out loud.
#
# IMPORTANT: The agent must be in an active session for this to work.
# An "active session" means someone is connected to the agent via:
#   - The web viewer (https://agent.viewer.bithuman.ai/AGENT_CODE)
#   - A LiveKit room (from one of the Python/Docker examples)
#   - The ImagineX dashboard (www.bithuman.ai)
#
# If no one is connected, you'll get: "No active rooms found for agent"
# To test without a session, use the dashboard at www.bithuman.ai instead.
#
# Usage: ./speak.sh [AGENT_ID] [MESSAGE]
set -euo pipefail

API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"
BASE="https://api.bithuman.ai"

AGENT_ID="${1:-${BITHUMAN_AGENT_ID:?Provide agent ID as argument or set BITHUMAN_AGENT_ID}}"
MESSAGE="${2:-Hello from the bitHuman API!}"

echo "Making agent $AGENT_ID speak: \"$MESSAGE\""
echo ""
echo "(Note: the agent must be in an active session — see comments in this script)"
echo ""

RESPONSE=$(curl -s -X POST "$BASE/v1/agent/$AGENT_ID/speak" \
  -H "Content-Type: application/json" \
  -H "api-secret: $API_SECRET" \
  -d "{\"message\": \"$MESSAGE\"}")

echo "$RESPONSE" | python3 -m json.tool

# Check for common error
if echo "$RESPONSE" | grep -qi "no active"; then
  echo ""
  echo "Tip: Start a session first by opening https://agent.viewer.bithuman.ai/$AGENT_ID"
  echo "     or by running one of the Docker examples in Examples/python/cloud-essence/"
fi
