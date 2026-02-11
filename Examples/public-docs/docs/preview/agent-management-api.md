# 🤖 Agent Management API

> **Agent Validation, Retrieval & Prompt Updates**
> Validate API credentials, retrieve agent details, and update agent prompts through our cloud-hosted REST API.

## 🔑 Authentication

Get your API secret from [imaginex.bithuman.ai](https://imaginex.bithuman.ai/#developer)

## 📡 Base URL
```
https://api.bithuman.ai
```

## 🚀 Endpoints

### Validate API Secret

**`POST /v1/validate`**

Verify that your API secret is valid before making other API calls. Useful for client-side credential checks and onboarding flows.

**Headers:**
```http
api-secret: YOUR_API_SECRET
```

**Request Body:** None required

**Response (valid):**
```json
{
  "valid": true
}
```

**Response (invalid):**
```json
{
  "valid": false
}
```

**Example Request:**
```python
import requests

url = "https://api.bithuman.ai/v1/validate"
headers = {
    "api-secret": "YOUR_API_SECRET"
}

response = requests.post(url, headers=headers)
result = response.json()

if result["valid"]:
    print("API secret is valid!")
else:
    print("Invalid API secret. Get one at https://imaginex.bithuman.ai/#developer")
```

```javascript
// JavaScript/Node.js
const response = await fetch('https://api.bithuman.ai/v1/validate', {
  method: 'POST',
  headers: {
    'api-secret': 'YOUR_API_SECRET'
  }
});

const result = await response.json();
console.log('Valid:', result.valid);
```

---

### Get Agent Info

**`GET /v1/agent/{code}`**

Retrieve detailed information about an agent by its code identifier. Returns agent configuration, status, and metadata.

**Headers:**
```http
api-secret: YOUR_API_SECRET
```

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `code` | string | The agent code identifier (e.g., `A12345678`) |

**Response:**
```json
{
  "success": true,
  "data": {
    "agent_id": "A91XMB7113",
    "event_type": "lip_created",
    "status": "ready",
    "error_message": null,
    "created_at": "2025-08-01T13:58:51.907177+00:00",
    "updated_at": "2025-08-01T09:59:15.159901+00:00",
    "system_prompt": "You are a friendly AI assistant",
    "image_url": "https://storage.supabase.co/image.jpg",
    "video_url": "https://storage.supabase.co/video.mp4",
    "name": "My Agent",
    "model_url": "https://storage.supabase.co/model.imx"
  }
}
```

**Error Response (agent not found):**
```json
{
  "success": false,
  "error": "AGENT_NOT_FOUND",
  "message": "Agent not found for code: A12345678"
}
```

**Example Request:**
```python
import requests

code = "A91XMB7113"
url = f"https://api.bithuman.ai/v1/agent/{code}"
headers = {
    "api-secret": "YOUR_API_SECRET"
}

response = requests.get(url, headers=headers)
data = response.json()

if data["success"]:
    agent = data["data"]
    print(f"Agent: {agent['name']}")
    print(f"Status: {agent['status']}")
    print(f"Prompt: {agent['system_prompt']}")
```

```javascript
// JavaScript/Node.js
const code = 'A91XMB7113';
const response = await fetch(`https://api.bithuman.ai/v1/agent/${code}`, {
  headers: {
    'api-secret': 'YOUR_API_SECRET'
  }
});

const data = await response.json();
if (data.success) {
  console.log('Agent:', data.data.name);
  console.log('Status:', data.data.status);
}
```

> **Note:** This endpoint uses the agent **code** (e.g., `A91XMB7113`), which is the same as the agent ID used across the platform. For checking generation progress specifically, you can also use [`GET /v1/agent/status/{agent_id}`](./agent-generation-api.md).

---

### Update Agent Prompt

**`POST /v1/agent/{code}`**

Update the system prompt of an existing agent. This allows you to change the agent's behavior and personality after creation without regenerating the agent.

**Headers:**
```http
Content-Type: application/json
api-secret: YOUR_API_SECRET
```

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `code` | string | The agent code identifier (e.g., `A12345678`) |

**Request Body:**
```json
{
  "system_prompt": "string (required)"
}
```

**Parameters:**

| Parameter | Type | Description | Example |
|-----------|------|-------------|----------|
| `system_prompt` | string | The new system prompt for the agent | `"You are a helpful customer service agent who speaks Spanish"` |

**Response:**
```json
{
  "success": true,
  "data": {
    "agent_code": "A91XMB7113",
    "updated": true
  }
}
```

**Error Response (missing prompt):**
```json
{
  "success": false,
  "error": "MISSING_PARAM",
  "message": "Missing 'system_prompt' parameter"
}
```

**Example Request:**
```python
import requests

code = "A91XMB7113"
url = f"https://api.bithuman.ai/v1/agent/{code}"
headers = {
    "Content-Type": "application/json",
    "api-secret": "YOUR_API_SECRET"
}
payload = {
    "system_prompt": "You are a professional sales assistant who helps customers find the perfect product. Be enthusiastic but not pushy."
}

response = requests.post(url, headers=headers, json=payload)
print(response.json())
```

```javascript
// JavaScript/Node.js
const code = 'A91XMB7113';
const response = await fetch(`https://api.bithuman.ai/v1/agent/${code}`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'api-secret': 'YOUR_API_SECRET'
  },
  body: JSON.stringify({
    system_prompt: 'You are a professional sales assistant who helps customers find the perfect product.'
  })
});

const result = await response.json();
console.log('Update result:', result);
```

**Complete Example — Create, Check, and Update:**
```python
import requests
import time

headers = {
    "Content-Type": "application/json",
    "api-secret": "YOUR_API_SECRET"
}

# Step 1: Create agent
response = requests.post(
    "https://api.bithuman.ai/v1/agent/generate",
    headers=headers,
    json={"prompt": "You are a friendly greeter."}
)
agent_id = response.json()["agent_id"]
print(f"Created agent: {agent_id}")

# Step 2: Wait for agent to be ready
while True:
    status = requests.get(
        f"https://api.bithuman.ai/v1/agent/status/{agent_id}",
        headers={"api-secret": "YOUR_API_SECRET"}
    ).json()

    if status["data"]["status"] == "ready":
        break
    time.sleep(5)

# Step 3: Get agent info
info = requests.get(
    f"https://api.bithuman.ai/v1/agent/{agent_id}",
    headers={"api-secret": "YOUR_API_SECRET"}
).json()
print(f"Current prompt: {info['data']['system_prompt']}")

# Step 4: Update the prompt
update = requests.post(
    f"https://api.bithuman.ai/v1/agent/{agent_id}",
    headers=headers,
    json={"system_prompt": "You are now a technical support specialist."}
).json()
print(f"Prompt updated: {update}")
```

## 🔧 Error Handling

**Common HTTP Status Codes:**
- `200` - Success
- `400` - Bad Request (invalid parameters)
- `401` - Unauthorized (invalid API secret)
- `404` - Agent not found
- `500` - Internal Server Error

**Error Response Format:**
```json
{
  "success": false,
  "error": "ERROR_CODE",
  "message": "Human-readable error description"
}
```

**Common Error Codes:**
- `UNAUTHORIZED` - Invalid or missing API secret
- `MISSING_PARAM` - Required parameter not provided
- `AGENT_NOT_FOUND` - No agent found with the given code
- `VALIDATION_ERROR` - Invalid request body format
- `INTERNAL_ERROR` - Server-side error

## 🔗 Related APIs

- [Agent Generation API](./agent-generation-api.md) - Create new agents
- [Agent Context API](./agent-context-api.md) - Add context and trigger speech
- [Dynamics API](./dynamics-api.md) - Generate agent movements
- [File Upload API](./file-upload-api.md) - Upload media assets
