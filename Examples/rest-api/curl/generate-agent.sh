#!/usr/bin/env bash
# Generate a new AI avatar agent and poll until ready (~4 minutes).
# Usage: ./generate-agent.sh ["Your system prompt here"]
set -euo pipefail

API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"
BASE="https://api.bithuman.ai"

PROMPT="${1:-You are a friendly AI assistant.}"

echo "Starting agent generation..."
echo "  Prompt: $PROMPT"
echo ""

# 1. Start generation
RESPONSE=$(curl -s -X POST "$BASE/v1/agent/generate" \
  -H "Content-Type: application/json" \
  -H "api-secret: $API_SECRET" \
  -d "{\"prompt\": \"$PROMPT\", \"aspect_ratio\": \"16:9\"}")

echo "$RESPONSE" | python3 -m json.tool

# Extract agent_id from response
AGENT_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('agent_id', ''))")

if [ -z "$AGENT_ID" ]; then
  echo "Error: No agent_id in response. Check the output above."
  exit 1
fi

echo ""
echo "Agent ID: $AGENT_ID"
echo "Polling status (generation takes ~4 minutes)..."
echo ""

# 2. Poll until ready or failed
while true; do
  STATUS_RESPONSE=$(curl -s "$BASE/v1/agent/status/$AGENT_ID" \
    -H "Content-Type: application/json" \
    -H "api-secret: $API_SECRET")

  STATUS=$(echo "$STATUS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('data', {}).get('status', 'unknown'))")
  PROGRESS=$(echo "$STATUS_RESPONSE" | python3 -c "import sys, json; p = json.load(sys.stdin).get('data', {}).get('progress'); print(f'{int(p*100)}%' if p is not None else 'N/A')")

  echo "  Status: $STATUS  Progress: $PROGRESS"

  if [ "$STATUS" = "ready" ]; then
    echo ""
    echo "Agent is ready!"
    echo "$STATUS_RESPONSE" | python3 -m json.tool
    break
  fi

  if [ "$STATUS" = "failed" ]; then
    echo ""
    echo "Generation failed."
    echo "$STATUS_RESPONSE" | python3 -m json.tool
    exit 1
  fi

  sleep 10
done
