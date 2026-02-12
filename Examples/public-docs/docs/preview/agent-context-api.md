# Agent Context API

Send real-time messages to agents deployed on the [imaginex.bithuman.ai](https://imaginex.bithuman.ai) platform. Make agents speak proactively or inject background knowledge to improve their responses.

> **Note**: This API is for agents created on the imaginex platform, not for local SDK agents.

## Authentication

All requests require the `api-secret` header. Get your API secret from [imaginex.bithuman.ai](https://imaginex.bithuman.ai/#developer).

## Base URL

```
https://api.bithuman.ai
```

## Endpoints

### Make Agent Speak

```
POST /v1/agent/{agent_code}/speak
```

Triggers the agent to speak a message to users in the session.

**Headers**

| Header | Value |
|--------|-------|
| `Content-Type` | `application/json` |
| `api-secret` | Your API secret |

**Request Body**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `message` | string | Yes | Text the agent will speak |
| `room_id` | string | No | Target a specific room. If omitted, delivers to all active rooms. |

**Response**

```json
{
  "success": true,
  "message": "Speech triggered successfully",
  "data": {
    "agent_code": "A12345678",
    "delivered_to_rooms": 1,
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

**Example**

```python
import requests

response = requests.post(
    "https://api.bithuman.ai/v1/agent/A12345678/speak",
    headers={"Content-Type": "application/json", "api-secret": "YOUR_API_SECRET"},
    json={
        "message": "We have a 20% discount available today.",
        "room_id": "customer_session_1"
    }
)
print(response.json())
```

---

### Add Context

```
POST /v1/agent/{agent_code}/add-context
```

Adds background knowledge the agent will use to inform future responses. Can also be used to trigger speech by setting `type` to `speak`.

**Headers**

| Header | Value |
|--------|-------|
| `Content-Type` | `application/json` |
| `api-secret` | Your API secret |

**Request Body**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `context` | string | Yes | -- | Context text or message to speak |
| `type` | string | No | `add_context` | `add_context` to inject knowledge silently, `speak` to trigger speech |
| `room_id` | string | No | -- | Target a specific room. If omitted, delivers to all active rooms. |

**Response**

```json
{
  "success": true,
  "message": "Context added successfully",
  "data": {
    "agent_code": "A12345678",
    "context_type": "add_context",
    "delivered_to_rooms": 1,
    "timestamp": "2024-01-15T10:35:00Z"
  }
}
```

**Example -- adding background context**

```python
import requests

response = requests.post(
    "https://api.bithuman.ai/v1/agent/A12345678/add-context",
    headers={"Content-Type": "application/json", "api-secret": "YOUR_API_SECRET"},
    json={
        "context": "Customer has VIP status. Preferred name: Alex. Account since 2021.",
        "type": "add_context",
        "room_id": "vip_session_42"
    }
)
print(response.json())
```

**Example -- triggering speech via add-context**

```python
response = requests.post(
    "https://api.bithuman.ai/v1/agent/A12345678/add-context",
    headers={"Content-Type": "application/json", "api-secret": "YOUR_API_SECRET"},
    json={
        "context": "Your issue has been resolved. Let me know if you need anything else.",
        "type": "speak",
        "room_id": "support_session_1"
    }
)
```

## Error Codes

| HTTP Status | Error Code | Description |
|-------------|------------|-------------|
| `401` | `UNAUTHORIZED` | Invalid or missing `api-secret` |
| `404` | `AGENT_NOT_FOUND` | No agent with the given code exists |
| `404` | `NO_ACTIVE_ROOMS` | Agent has no active sessions |
| `422` | `VALIDATION_ERROR` | Invalid request body (e.g., bad `type` value) |

**Error response format:**

```json
{
  "success": false,
  "error": "AGENT_NOT_FOUND",
  "message": "Agent with code 'A12345678' not found"
}
```
