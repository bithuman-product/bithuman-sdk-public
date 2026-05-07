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
resp = json.load(sys.stdin)
data = resp.get('data', resp)

balance = data.get('balance', 'unknown')
plan_credits = data.get('plan_credits', 'unknown')
topup_credits = data.get('topup_credits', 0)
is_enterprise = data.get('is_enterprise', False)
minutes = data.get('minutes_estimate', {})

print(f'Balance:        {balance} credits')
print(f'Plan credits:   {plan_credits}/month')
print(f'Top-up credits: {topup_credits}')
print(f'Enterprise:     {is_enterprise}')
if minutes:
    print(f'Estimated minutes remaining:')
    for model, mins in minutes.items():
        print(f'  {model}: {mins:.0f} min')
print()
print('Pricing: 1 cr/min (Essence self-hosted), 2 cr/min (cloud or Expression), 4 cr/min (Expression cloud)')
print('Top up:  https://www.bithuman.ai -> Settings -> Billing')
"
