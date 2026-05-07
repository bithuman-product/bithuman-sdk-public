#!/usr/bin/env bash
# Upload a file (image, video, or audio) to the bitHuman platform via URL.
# Returns a hosted URL you can pass to agent generation endpoints.
# Usage: ./upload-file.sh [FILE_URL]
set -euo pipefail

API_SECRET="${BITHUMAN_API_SECRET:?Set BITHUMAN_API_SECRET first (get yours at https://www.bithuman.ai/#developer)}"
BASE="https://api.bithuman.ai"

FILE_URL="${1:?Usage: ./upload-file.sh <file-url>  (e.g. https://example.com/face.jpg)}"

echo "Uploading file: $FILE_URL"
echo ""

curl -s -X POST "$BASE/v1/files/upload" \
  -H "Content-Type: application/json" \
  -H "api-secret: $API_SECRET" \
  -d "{\"file_url\": \"$FILE_URL\"}" | python3 -m json.tool
