# BitHuman Essence Cloud API — Java Example

A minimal, **zero-dependency** Java example for integrating with the bitHuman Essence Cloud REST API.

## Prerequisites

- **Java 11+** (uses `java.net.http.HttpClient`)
- **bitHuman API secret** — get one at [imaginex.bithuman.ai](https://imaginex.bithuman.ai/#developer) (starts with `sk_bh_`)

## Quick Start

```bash
# Set your API secret
export BITHUMAN_API_SECRET=sk_bh_your_secret_here

# Compile and run
javac BitHumanExample.java
java BitHumanExample
```

## What It Demonstrates

| Step | API Endpoint | Description |
|------|-------------|-------------|
| 1 | `POST /v1/validate` | Validate your API secret |
| 2 | `POST /v1/agent/generate` | Create a new avatar agent |
| 3 | `GET /v1/agent/status/{id}` | Poll until the agent is ready |
| 4 | `GET /v1/agent/{code}` | Retrieve agent details |
| 5 | `POST /v1/agent/{code}` | Update the agent's system prompt |
| 6 | `POST /v1/agent/{code}/speak` | Make the agent speak (requires active session) |
| 7 | `POST /v1/agent/{code}/add-context` | Add background knowledge to the agent |
| 8 | `POST /v1/dynamics/generate` | Generate gestures / animations |
| 9 | `POST /v1/files/upload` | Upload a file via URL |

## API Base URL

```
https://public.api.bithuman.ai
```

## Authentication

All requests require the `api-secret` header:

```java
HttpRequest req = HttpRequest.newBuilder()
    .uri(URI.create("https://public.api.bithuman.ai/v1/validate"))
    .header("api-secret", "sk_bh_your_secret_here")
    .POST(HttpRequest.BodyPublishers.ofString("{}"))
    .build();
```

## Using with Maven/Gradle (Optional)

The example is intentionally dependency-free. If your project uses a JSON library (Jackson, Gson, etc.), replace the `extractJsonString()` helper with proper parsing:

```java
// With Jackson
ObjectMapper mapper = new ObjectMapper();
JsonNode root = mapper.readTree(responseBody);
String agentId = root.get("agent_id").asText();
```

```java
// With Gson
JsonObject root = JsonParser.parseString(responseBody).getAsJsonObject();
String agentId = root.get("agent_id").getAsString();
```

## Streaming Demo

Want real-time video/audio streaming with the avatar? See the [streaming/](streaming/) directory for a complete Java server that:
- Generates LiveKit room tokens (zero-dependency JWT)
- Serves a web client with avatar video + microphone input
- Controls the avatar via bitHuman REST API (speak, add context)

```bash
cd streaming/
javac BitHumanStreamingDemo.java
java BitHumanStreamingDemo
# Open http://localhost:8080
```

## Next Steps

- Try the [Streaming Demo](streaming/) for real-time avatar interaction
- Explore the full [API documentation](../../docs/preview/)
- Try the [Python LiveKit agent example](../agent.py) for real-time WebRTC avatar sessions
- Join the [Discord community](https://discord.gg/ES953n7bPA) for support

## Related APIs

- [Agent Generation API](../../../docs/preview/agent-generation-api.md)
- [Agent Management API](../../../docs/preview/agent-management-api.md)
- [Agent Context API](../../../docs/preview/agent-context-api.md)
- [Dynamics API](../../../docs/preview/dynamics-api.md)
- [File Upload API](../../../docs/preview/file-upload-api.md)
- [LiveKit Cloud Plugin](../../../docs/preview/livekit-cloud-plugin.md)
