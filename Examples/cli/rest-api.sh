#!/usr/bin/env bash
# bitHuman REST API quickstart -- validate credentials, fetch agent info, and speak.
# Get your API secret at https://www.bithuman.ai (Developer section).
#
# Usage:
#   export BITHUMAN_API_SECRET=your_secret
#   ./rest-api.sh
#
#   # Optionally set an agent ID to test agent endpoints:
#   export BITHUMAN_AGENT_ID=AXXXXXXXXX
#   ./rest-api.sh
#
# For more curl examples, see ../rest-api/curl/
set -euo pipefail

API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"
BASE="https://api.bithuman.ai"

echo "bitHuman REST API Quickstart"
echo "============================"
echo ""

# 1. Validate your API secret
echo "1. Validating API secret..."
curl -sf -X POST "$BASE/v1/validate" \
  -H "Content-Type: application/json" \
  -H "api-secret: $API_SECRET" | python3 -m json.tool

# 2. Get agent info (if agent ID is set)
AGENT_ID="${BITHUMAN_AGENT_ID:-YOUR_AGENT_CODE}"
if [ "$AGENT_ID" != "YOUR_AGENT_CODE" ]; then
  echo ""
  echo "2. Fetching agent $AGENT_ID..."
  curl -sf "$BASE/v1/agent/$AGENT_ID" \
    -H "Content-Type: application/json" \
    -H "api-secret: $API_SECRET" | python3 -m json.tool

  # 3. Make the agent speak (agent must be in a live session)
  echo ""
  echo "3. Making agent $AGENT_ID speak..."
  curl -s -X POST "$BASE/v1/agent/$AGENT_ID/speak" \
    -H "Content-Type: application/json" \
    -H "api-secret: $API_SECRET" \
    -d '{"message": "Hello from the quickstart script!"}' | python3 -m json.tool
else
  echo ""
  echo "To test agent endpoints, set BITHUMAN_AGENT_ID:"
  echo "  export BITHUMAN_AGENT_ID=your_agent_code"
  echo "  ./rest-api.sh"
fi

echo ""
echo "Done. For more examples, see:"
echo "  ../rest-api/curl/   (individual curl scripts)"
echo "  ../rest-api/python/ (full Python scripts)"
