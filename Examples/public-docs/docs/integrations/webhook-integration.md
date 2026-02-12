# Webhook Integration

Receive HTTP POST callbacks when avatar events occur. This guide covers endpoint setup, payload format, signature verification, and testing.

---

## Quick Setup

1. Go to [imaginex.bithuman.ai/#developer](https://imaginex.bithuman.ai/#developer) and open the **Webhooks** section.
2. Enter your endpoint URL (must be HTTPS).
3. Select events to receive: **room.join**, **chat.push**.
4. Optionally add authentication headers:

```http
Authorization: Bearer your-api-token
X-API-Key: your-secret-key
```

---

## Payload Format

All payloads follow the same structure:

| Field | Type | Description |
|-------|------|-------------|
| `agent_id` | string | The agent that triggered the event |
| `event_type` | string | Event name (`room.join` or `chat.push`) |
| `data` | object | Event-specific data (see below) |
| `timestamp` | float | Unix timestamp |

### room.join

```json
{
  "agent_id": "agent_abc123",
  "event_type": "room.join",
  "data": {
    "room_name": "customer-support",
    "participant_count": 1,
    "session_id": "session_xyz789"
  },
  "timestamp": 1705312200.0
}
```

### chat.push

```json
{
  "agent_id": "agent_abc123",
  "event_type": "chat.push",
  "data": {
    "role": "user",
    "message": "Hello, I need help with my order",
    "session_id": "session_xyz789",
    "timestamp": 1705312285.0
  },
  "timestamp": 1705312285.0
}
```

---

## Implementation Examples

### Flask (Python)

```python
from flask import Flask, request, jsonify
import hmac, hashlib

app = Flask(__name__)
WEBHOOK_SECRET = "your-webhook-secret"

@app.route('/webhook', methods=['POST'])
def handle_webhook():
    signature = request.headers.get('X-bitHuman-Signature', '')
    if not verify_signature(request.data, signature):
        return jsonify({'error': 'Invalid signature'}), 401

    data = request.json
    event_type = data.get('event_type')

    if event_type == 'room.join':
        print(f"User joined session {data['data']['session_id']}")
    elif event_type == 'chat.push':
        print(f"[{data['data']['role']}] {data['data']['message']}")

    return jsonify({'status': 'ok'})

def verify_signature(payload, signature):
    expected = hmac.new(
        WEBHOOK_SECRET.encode(), payload, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", signature)

if __name__ == '__main__':
    app.run(port=3000)
```

### Express (Node.js)

```javascript
const express = require('express');
const crypto = require('crypto');

const app = express();
app.use(express.json());
const WEBHOOK_SECRET = 'your-webhook-secret';

app.post('/webhook', (req, res) => {
  const signature = req.headers['x-bithuman-signature'] || '';
  if (!verifySignature(req.body, signature)) {
    return res.status(401).json({ error: 'Invalid signature' });
  }

  const { event_type, data } = req.body;
  if (event_type === 'room.join') {
    console.log(`User joined session ${data.session_id}`);
  } else if (event_type === 'chat.push') {
    console.log(`[${data.role}] ${data.message}`);
  }

  res.json({ status: 'ok' });
});

function verifySignature(payload, signature) {
  const expected = crypto
    .createHmac('sha256', WEBHOOK_SECRET)
    .update(JSON.stringify(payload))
    .digest('hex');
  return crypto.timingSafeEqual(
    Buffer.from(`sha256=${expected}`),
    Buffer.from(signature)
  );
}

app.listen(3000, () => console.log('Listening on port 3000'));
```

---

## Example: Database Logging

```python
def handle_room_join(data):
    session = UserSession(
        agent_id=data['agent_id'],
        session_id=data['data']['session_id'],
        room_name=data['data']['room_name'],
        participant_count=data['data']['participant_count'],
        started_at=data['timestamp']
    )
    db.session.add(session)
    db.session.commit()
```

---

## Signature Verification

All webhook requests include an `X-bitHuman-Signature` header. Verify it using HMAC SHA-256 with your webhook secret:

1. Compute `HMAC-SHA256(secret, raw_request_body)`.
2. Compare the hex digest against the signature header value (after stripping the `sha256=` prefix).
3. Use constant-time comparison to prevent timing attacks.

Always use HTTPS. HTTP endpoints are rejected.

---

## Testing

### Local development with ngrok

```bash
ngrok http 3000
# Use the resulting HTTPS URL as your webhook endpoint
```

### Dashboard test button

Use the **Test** button in the bitHuman developer dashboard to send sample events to your endpoint.

### Manual curl test

```bash
curl -X POST https://your-app.com/webhook \
  -H "Content-Type: application/json" \
  -H "X-bitHuman-Signature: sha256=test" \
  -d '{
    "agent_id": "test_agent",
    "event_type": "room.join",
    "data": {
      "room_name": "test-room",
      "participant_count": 1,
      "session_id": "session_123"
    },
    "timestamp": 1705312200.0
  }'
```

---

## Retry Policy

bitHuman retries failed deliveries (non-2xx responses) automatically:

| Attempt | Delay |
|---------|-------|
| 1st retry | 1 second |
| 2nd retry | 5 seconds |
| 3rd retry | 30 seconds |

Maximum 3 retries. Your endpoint must respond within 30 seconds.

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Signature invalid | Wrong secret or encoding | Verify HMAC SHA-256 against raw request body |
| Timeout errors | Slow processing | Return 200 immediately, process async |
| 404 Not Found | Incorrect URL | Check endpoint URL in dashboard |
| SSL errors | Invalid certificate | Use a valid HTTPS certificate |

---

## Resources

- [Event Handling Guide](event-handling.md) -- event types and handler patterns
- [Discord](https://discord.gg/yM7wRRqu) -- community support
- [API Docs](https://docs.bithuman.ai) -- full API reference
