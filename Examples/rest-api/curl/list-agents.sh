#!/usr/bin/env bash
# Get details for a specific agent (name, status, model URL, system prompt).
# Usage: ./list-agents.sh [AGENT_ID]
set -euo pipefail

API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"
BASE="https://api.bithuman.ai"

AGENT_ID="${1:-${BITHUMAN_AGENT_ID:?Provide agent ID as argument or set BITHUMAN_AGENT_ID}}"

echo "Fetching agent $AGENT_ID..."
echo ""

curl -s "$BASE/v1/agent/$AGENT_ID" \
  -H "Content-Type: application/json" \
  -H "api-secret: $API_SECRET" | python3 -m json.tool
