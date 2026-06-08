#!/usr/bin/env bash
# List the agents on your account (id, name, status, model).
# Usage: ./list-agents.sh
set -euo pipefail

API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"
BASE="https://api.bithuman.ai"

echo "Listing your agents..."
echo ""

curl -s "$BASE/v1/agents" \
  -H "Content-Type: application/json" \
  -H "api-secret: $API_SECRET" | python3 -m json.tool
