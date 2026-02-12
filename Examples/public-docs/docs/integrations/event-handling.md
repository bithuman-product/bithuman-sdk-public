# Event Handling

Webhooks deliver HTTP POST requests to your endpoint when avatar events occur. This page covers event types and basic handler examples. For setup instructions, see the [Webhook Integration Guide](webhook-integration.md).

---

## Event Types

### room.join

Fired once when a user connects to an avatar session.

```json
{
  "agent_id": "agent_customer_support",
  "event_type": "room.join",
  "data": {
    "room_name": "customer-support-room",
    "participant_count": 1,
    "session_id": "session_xyz789"
  },
  "timestamp": 1705312200.0
}
```

### chat.push

Fired for each message sent in the conversation (both user and agent).

```json
{
  "agent_id": "agent_customer_support",
  "event_type": "chat.push",
  "data": {
    "role": "user",
    "message": "I need help with my order #12345",
    "session_id": "session_xyz789",
    "timestamp": 1705312285.0
  },
  "timestamp": 1705312285.0
}
```

---

## Handler Examples

### Flask (Python)

```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/webhook', methods=['POST'])
def handle_webhook():
    data = request.json
    event_type = data.get('event_type')

    if event_type == 'room.join':
        session_id = data['data']['session_id']
        print(f"User joined session {session_id}")
    elif event_type == 'chat.push':
        role = data['data']['role']
        message = data['data']['message']
        print(f"[{role}] {message}")

    return jsonify({'status': 'ok'}), 200

if __name__ == '__main__':
    app.run(port=3000)
```

### Express (Node.js)

```javascript
const express = require('express');
const app = express();
app.use(express.json());

app.post('/webhook', (req, res) => {
  const { event_type, data } = req.body;

  if (event_type === 'room.join') {
    console.log(`User joined session ${data.session_id}`);
  } else if (event_type === 'chat.push') {
    console.log(`[${data.role}] ${data.message}`);
  }

  res.json({ status: 'ok' });
});

app.listen(3000, () => console.log('Listening on port 3000'));
```

---

## Async Processing

Return `200` immediately and process events in the background. Long-running work (database writes, API calls, analytics) should be offloaded to a task queue so your endpoint responds within the timeout window. Any standard job queue (Celery, BullMQ, Sidekiq, etc.) works.

---

## Resources

- [Webhook Integration Guide](webhook-integration.md) -- endpoint setup, signature verification, testing, and retry policy
- [Discord](https://discord.gg/yM7wRRqu) -- community support
