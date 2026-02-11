/**
 * BitHuman Essence Cloud API — Java Integration Example
 *
 * A minimal, dependency-free example (Java 11+) that shows how to:
 *   1. Validate your API secret
 *   2. Create (generate) an avatar agent
 *   3. Poll until the agent is ready
 *   4. Retrieve agent details
 *   5. Update the agent's system prompt
 *   6. Make the agent speak in a live session
 *   7. Add background context to the agent
 *   8. Generate dynamics (gestures/animations)
 *   9. Upload a file (URL-based)
 *
 * Prerequisites:
 *   - Java 11 or later (uses java.net.http.HttpClient)
 *   - A bitHuman API secret (starts with sk_bh_…)
 *     → Get one at https://imaginex.bithuman.ai/#developer
 *
 * Compile & run:
 *   javac BitHumanExample.java
 *   java BitHumanExample
 *
 * Or set your secret via environment variable:
 *   export BITHUMAN_API_SECRET=sk_bh_your_secret_here
 *   java BitHumanExample
 */

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

public class BitHumanExample {

    // ── Configuration ──────────────────────────────────────────────────
    private static final String BASE_URL   = "https://public.api.bithuman.ai";
    private static final String API_SECRET = System.getenv("BITHUMAN_API_SECRET") != null
            ? System.getenv("BITHUMAN_API_SECRET")
            : "sk_bh_your_secret_here";                       // ← replace or use env var

    private static final HttpClient HTTP = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    // ── Main ───────────────────────────────────────────────────────────
    public static void main(String[] args) throws Exception {

        // 1) Validate API secret
        System.out.println("=== 1. Validate API Secret ===");
        String validateBody = post("/v1/validate", "{}");
        System.out.println(validateBody);
        if (validateBody.contains("\"valid\":false") || validateBody.contains("\"valid\": false")) {
            System.err.println("Invalid API secret. Get one at https://imaginex.bithuman.ai/#developer");
            return;
        }

        // 2) Generate a new agent
        System.out.println("\n=== 2. Generate Agent ===");
        String genPayload = """
                {
                  "prompt": "You are a friendly customer service assistant. Be helpful and concise.",
                  "duration": 10
                }
                """;
        String genBody = post("/v1/agent/generate", genPayload);
        System.out.println(genBody);

        String agentId = extractJsonString(genBody, "agent_id");
        if (agentId == null) {
            System.err.println("Failed to create agent.");
            return;
        }
        System.out.println("Agent ID: " + agentId);

        // 3) Poll until ready (or failed)
        System.out.println("\n=== 3. Wait for Agent Ready ===");
        String status = pollUntilReady(agentId);
        System.out.println("Final status: " + status);
        if (!"ready".equals(status)) {
            System.err.println("Agent generation did not complete successfully.");
            return;
        }

        // 4) Get agent info
        System.out.println("\n=== 4. Get Agent Info ===");
        String infoBody = get("/v1/agent/" + agentId);
        System.out.println(infoBody);

        // 5) Update the system prompt
        System.out.println("\n=== 5. Update Agent Prompt ===");
        String updatePayload = """
                {
                  "system_prompt": "You are a technical support specialist who explains complex topics in simple terms."
                }
                """;
        String updateBody = post("/v1/agent/" + agentId, updatePayload);
        System.out.println(updateBody);

        // 6) Make the agent speak (requires an active LiveKit session)
        System.out.println("\n=== 6. Make Agent Speak ===");
        String speakPayload = """
                {
                  "message": "Hello from the Java integration! How can I help you today?"
                }
                """;
        String speakBody = post("/v1/agent/" + agentId + "/speak", speakPayload);
        System.out.println(speakBody);

        // 7) Add background context
        System.out.println("\n=== 7. Add Context ===");
        String ctxPayload = """
                {
                  "context": "The user is a premium enterprise customer interested in API integrations.",
                  "type": "add_context"
                }
                """;
        String ctxBody = post("/v1/agent/" + agentId + "/add-context", ctxPayload);
        System.out.println(ctxBody);

        // 8) Generate dynamics (gestures / animations)
        System.out.println("\n=== 8. Generate Dynamics ===");
        String dynPayload = String.format("""
                {
                  "agent_id": "%s",
                  "duration": 3,
                  "model": "seedance"
                }
                """, agentId);
        String dynBody = post("/v1/dynamics/generate", dynPayload);
        System.out.println(dynBody);

        // 9) Upload a file via URL
        System.out.println("\n=== 9. Upload File (URL) ===");
        String uploadPayload = """
                {
                  "file_url": "https://upload.wikimedia.org/wikipedia/commons/4/47/PNG_transparency_demonstration_1.png",
                  "file_type": "image"
                }
                """;
        String uploadBody = post("/v1/files/upload", uploadPayload);
        System.out.println(uploadBody);

        System.out.println("\nDone! All API calls completed.");
    }

    // ── Polling helper ─────────────────────────────────────────────────
    private static String pollUntilReady(String agentId) throws Exception {
        int maxAttempts = 60;          // up to 5 minutes (60 × 5s)
        for (int i = 0; i < maxAttempts; i++) {
            String body = get("/v1/agent/status/" + agentId);
            String status = extractJsonString(body, "status");
            System.out.printf("  [%d/%d] status = %s%n", i + 1, maxAttempts, status);

            if ("ready".equals(status) || "failed".equals(status)) {
                return status;
            }
            Thread.sleep(5_000);       // wait 5 seconds between polls
        }
        return "timeout";
    }

    // ── HTTP helpers (no external dependencies) ────────────────────────
    private static String get(String path) throws IOException, InterruptedException {
        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(BASE_URL + path))
                .header("api-secret", API_SECRET)
                .timeout(Duration.ofSeconds(30))
                .GET()
                .build();
        return HTTP.send(req, HttpResponse.BodyHandlers.ofString()).body();
    }

    private static String post(String path, String jsonBody) throws IOException, InterruptedException {
        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(BASE_URL + path))
                .header("Content-Type", "application/json")
                .header("api-secret", API_SECRET)
                .timeout(Duration.ofSeconds(30))
                .POST(HttpRequest.BodyPublishers.ofString(jsonBody))
                .build();
        return HTTP.send(req, HttpResponse.BodyHandlers.ofString()).body();
    }

    // ── Minimal JSON string extractor (avoids external JSON libs) ──────
    /** Extracts the first occurrence of "key":"value" from a JSON string. */
    private static String extractJsonString(String json, String key) {
        String pattern = "\"" + key + "\"";
        int idx = json.indexOf(pattern);
        if (idx == -1) return null;

        // skip past the key, colon, and opening quote
        int colon = json.indexOf(':', idx + pattern.length());
        if (colon == -1) return null;

        int openQuote = json.indexOf('"', colon + 1);
        if (openQuote == -1) return null;

        int closeQuote = json.indexOf('"', openQuote + 1);
        if (closeQuote == -1) return null;

        return json.substring(openQuote + 1, closeQuote);
    }
}
