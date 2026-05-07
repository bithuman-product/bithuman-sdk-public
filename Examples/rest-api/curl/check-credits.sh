#!/usr/bin/env bash
# Check your bitHuman credit balance.
# Credits are consumed by agent generation (250 credits) and streaming sessions.
set -euo pipefail

API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"
BASE="https://api.bithuman.ai"

echo "Checking credit balance..."
echo ""

curl -s -X POST "$BASE/v1/validate" \
  -H "Content-Type: application/json" \
  -H "api-secret: $API_SECRET" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('valid'):
    credits = data.get('credits', 'N/A')
    print(f'API secret: valid')
    print(f'Credits:    {credits}')
else:
    print('API secret: invalid')
    print('Check your BITHUMAN_API_SECRET value.')
    sys.exit(1)
"
