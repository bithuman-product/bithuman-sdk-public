#!/usr/bin/env bash
# Check your bitHuman credit balance and plan details.
# Uses GET /v2/credit-summaries (the validate endpoint does NOT return credits).
set -euo pipefail

API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"
BASE="https://api.bithuman.ai"

echo "Checking credit balance..."
echo ""

curl -s -X GET "$BASE/v2/credit-summaries" \
  -H "Content-Type: application/json" \
  -H "api-secret: $API_SECRET" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'error' in data:
    print(f'Error: {data[\"error\"]}')
    sys.exit(1)
credits = data.get('credits', data.get('data', {}).get('credits', 'unknown'))
plan = data.get('plan', data.get('data', {}).get('plan', 'unknown'))
print(f'Credits remaining: {credits}')
print(f'Plan:             {plan}')
print()
print('Pricing: 1 cr/min (Essence self-hosted), 2 cr/min (cloud or Expression self-hosted), 4 cr/min (Expression cloud)')
print('Top up:  https://www.bithuman.ai → Settings → Billing')
"
