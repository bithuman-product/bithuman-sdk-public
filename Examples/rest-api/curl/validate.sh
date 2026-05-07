#!/usr/bin/env bash
# Validate your bitHuman API credentials.
# Returns {"valid": true} on success, 401 on bad credentials.
set -euo pipefail

API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"
BASE="https://api.bithuman.ai"

curl -s -X POST "$BASE/v1/validate" \
  -H "Content-Type: application/json" \
  -H "api-secret: $API_SECRET" | python3 -m json.tool
