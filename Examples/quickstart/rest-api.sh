#!/usr/bin/env bash
# bitHuman REST API quickstart -- validate credentials and make an agent speak.
# Get your API secret at https://www.bithuman.ai (Developer section).
set -euo pipefail

API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first}"
BASE="https://api.bithuman.ai"

# 1. Validate your API key
echo "Validating API key..."
curl -sf -X POST "$BASE/v1/validate" \
  -H "Content-Type: application/json" \
  -H "api-secret: $API_SECRET" | python3 -m json.tool

# 2. Make an agent speak (replace with your agent code)
AGENT_ID="${BITHUMAN_AGENT_ID:-YOUR_AGENT_CODE}"
if [ "$AGENT_ID" != "YOUR_AGENT_CODE" ]; then
  echo ""
  echo "Making agent $AGENT_ID speak..."
  curl -sf -X POST "$BASE/v1/agent/$AGENT_ID/speak" \
    -H "Content-Type: application/json" \
    -H "api-secret: $API_SECRET" \
    -d '{"message": "Hello from the quickstart script!"}' | python3 -m json.tool
else
  echo ""
  echo "Set BITHUMAN_AGENT_ID to test the speak endpoint."
  echo "  export BITHUMAN_AGENT_ID=your_agent_code"
fi
