#!/usr/bin/env bash
# Add background context to a live agent's conversation (silent injection).
# The agent uses this context for future responses but does not speak it aloud.
# The agent must be in an active session.
# Usage: ./add-context.sh [AGENT_ID] [CONTEXT]
set -euo pipefail

API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"
BASE="https://api.bithuman.ai"

AGENT_ID="${1:-${BITHUMAN_AGENT_ID:?Provide agent ID as argument or set BITHUMAN_AGENT_ID}}"
CONTEXT="${2:-The customer is a VIP member since 2021. Offer them premium support.}"

echo "Adding context to agent $AGENT_ID..."
echo "  Context: \"$CONTEXT\""
echo ""

curl -s -X POST "$BASE/v1/agent/$AGENT_ID/add-context" \
  -H "Content-Type: application/json" \
  -H "api-secret: $API_SECRET" \
  -d "{\"context\": \"$CONTEXT\", \"type\": \"add_context\"}" | python3 -m json.tool
