/**
 * BitHuman Essence Cloud — Java Streaming Demo
 *
 * A self-contained Java server that lets you talk to a bitHuman cloud-hosted
 * Essence avatar in real time through your browser.
 *
 * What it does:
 *   1. Starts an HTTP server on localhost:8080
 *   2. Generates LiveKit room tokens (zero-dependency JWT via javax.crypto)
 *   3. Serves a minimal web page that connects to the avatar via LiveKit WebRTC
 *   4. Provides REST endpoints to control the avatar (speak, add context)
 *
 * Architecture:
 *   ┌──────────────┐   WebRTC (audio/video)   ┌────────────────────┐
 *   │  Browser UI  │ ◄══════════════════════► │  LiveKit Cloud     │
 *   │  (served by  │                          │                    │
 *   │   this Java  │                          │  ┌──────────────┐  │
 *   │   server)    │                          │  │ Python       │  │
 *   └──────┬───────┘                          │  │ agent.py     │  │
 *          │ HTTP                              │  │ (LiveKit     │  │
 *   ┌──────▼───────┐                          │  │  Agent)      │  │
 *   │  This Java   │  REST API                │  └──────┬───────┘  │
 *   │  Server      │─────────────────────────►│         │          │
 *   │  :8080       │  (speak, add-context)    │         ▼          │
 *   └──────────────┘                          │  bitHuman Cloud    │
 *                                             │  (avatar rendering)│
 *                                             └────────────────────┘
 *
 * Prerequisites:
 *   - Java 11+
 *   - A LiveKit Cloud account (https://livekit.io) — free tier works
 *   - A bitHuman API secret (https://imaginex.bithuman.ai/#developer)
 *   - Python agent.py running (see ../agent.py)
 *
 * Quick start:
 *   # Terminal 1: Start the Python avatar agent
 *   cd ../
 *   python agent.py dev
 *
 *   # Terminal 2: Start this Java server
 *   export LIVEKIT_API_KEY=APIxxxxxxxx
 *   export LIVEKIT_API_SECRET=xxxxxxxxxxxxxxxx
 *   export LIVEKIT_URL=wss://your-project.livekit.cloud
 *   export BITHUMAN_API_SECRET=sk_bh_xxxxxxxx
 *   export BITHUMAN_AVATAR_ID=A31KJC8622
 *
 *   javac BitHumanStreamingDemo.java
 *   java BitHumanStreamingDemo
 *
 *   # Open http://localhost:8080 in your browser
 */

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.UUID;

public class BitHumanStreamingDemo {

    // ── Configuration (from environment variables) ─────────────────────
    private static final String LIVEKIT_API_KEY    = env("LIVEKIT_API_KEY", "");
    private static final String LIVEKIT_API_SECRET = env("LIVEKIT_API_SECRET", "");
    private static final String LIVEKIT_URL        = env("LIVEKIT_URL", "");
    private static final String BITHUMAN_API_SECRET = env("BITHUMAN_API_SECRET", "");
    private static final String BITHUMAN_AVATAR_ID  = env("BITHUMAN_AVATAR_ID", "A31KJC8622");
    private static final String BITHUMAN_API_BASE   = "https://api.bithuman.ai";
    private static final int    PORT = Integer.parseInt(env("PORT", "8080"));

    private static final HttpClient HTTP = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    // ── Main ───────────────────────────────────────────────────────────
    public static void main(String[] args) throws Exception {
        // Validate required config
        if (LIVEKIT_API_KEY.isEmpty() || LIVEKIT_API_SECRET.isEmpty() || LIVEKIT_URL.isEmpty()) {
            System.err.println("ERROR: Missing LiveKit configuration.");
            System.err.println("Set these environment variables:");
            System.err.println("  LIVEKIT_API_KEY     — from https://cloud.livekit.io");
            System.err.println("  LIVEKIT_API_SECRET  — from https://cloud.livekit.io");
            System.err.println("  LIVEKIT_URL         — e.g. wss://your-project.livekit.cloud");
            System.exit(1);
        }
        if (BITHUMAN_API_SECRET.isEmpty()) {
            System.err.println("WARNING: BITHUMAN_API_SECRET not set. REST API control will not work.");
            System.err.println("Get one at https://imaginex.bithuman.ai/#developer");
        }

        HttpServer server = HttpServer.create(new InetSocketAddress(PORT), 0);
        server.createContext("/",            new PageHandler());
        server.createContext("/api/token",   new TokenHandler());
        server.createContext("/api/speak",   new SpeakHandler());
        server.createContext("/api/context", new ContextHandler());
        server.setExecutor(null);
        server.start();

        System.out.println("==============================================");
        System.out.println("  BitHuman Streaming Demo");
        System.out.println("  Open http://localhost:" + PORT + " in your browser");
        System.out.println("==============================================");
        System.out.println("LiveKit URL : " + LIVEKIT_URL);
        System.out.println("Avatar ID   : " + BITHUMAN_AVATAR_ID);
        System.out.println();
        System.out.println("Make sure the Python agent.py is running:");
        System.out.println("  cd ../ && python agent.py dev");
        System.out.println();
    }

    // ════════════════════════════════════════════════════════════════════
    //  HTTP Handlers
    // ════════════════════════════════════════════════════════════════════

    /** GET / — Serve the web client page */
    static class PageHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange ex) throws IOException {
            if (!"GET".equals(ex.getRequestMethod())) {
                ex.sendResponseHeaders(405, -1);
                return;
            }
            byte[] page = getHtmlPage().getBytes(StandardCharsets.UTF_8);
            ex.getResponseHeaders().set("Content-Type", "text/html; charset=utf-8");
            ex.sendResponseHeaders(200, page.length);
            try (OutputStream os = ex.getResponseBody()) { os.write(page); }
        }
    }

    /** GET /api/token?room=xxx — Generate a LiveKit access token */
    static class TokenHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange ex) throws IOException {
            if (!"GET".equals(ex.getRequestMethod())) {
                ex.sendResponseHeaders(405, -1);
                return;
            }
            String query = ex.getRequestURI().getQuery();
            String room = paramValue(query, "room");
            if (room == null || room.isEmpty()) {
                room = "room-" + BITHUMAN_AVATAR_ID + "-" + randomId(4);
            }
            String identity = "java-user-" + randomId(4);

            try {
                String token = createLiveKitToken(identity, room);
                String json = String.format(
                        "{\"token\":\"%s\",\"room\":\"%s\",\"identity\":\"%s\",\"wsUrl\":\"%s\"}",
                        token, room, identity, LIVEKIT_URL);
                sendJson(ex, 200, json);
            } catch (Exception e) {
                sendJson(ex, 500, "{\"error\":\"" + escapeJson(e.getMessage()) + "\"}");
            }
        }
    }

    /** POST /api/speak — Make the avatar speak via bitHuman Context API */
    static class SpeakHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange ex) throws IOException {
            if (!"POST".equals(ex.getRequestMethod())) { ex.sendResponseHeaders(405, -1); return; }
            String body = readBody(ex);
            try {
                String resp = bithumanPost("/v1/agent/" + BITHUMAN_AVATAR_ID + "/speak", body);
                sendJson(ex, 200, resp);
            } catch (Exception e) {
                sendJson(ex, 500, "{\"error\":\"" + escapeJson(e.getMessage()) + "\"}");
            }
        }
    }

    /** POST /api/context — Add background context to the avatar */
    static class ContextHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange ex) throws IOException {
            if (!"POST".equals(ex.getRequestMethod())) { ex.sendResponseHeaders(405, -1); return; }
            String body = readBody(ex);
            try {
                String resp = bithumanPost("/v1/agent/" + BITHUMAN_AVATAR_ID + "/add-context", body);
                sendJson(ex, 200, resp);
            } catch (Exception e) {
                sendJson(ex, 500, "{\"error\":\"" + escapeJson(e.getMessage()) + "\"}");
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  LiveKit Token Generation (zero-dependency JWT)
    // ════════════════════════════════════════════════════════════════════

    /**
     * Generate a LiveKit access token (JWT) using only Java stdlib.
     * The token grants the participant permission to join the room,
     * publish audio, and subscribe to all tracks.
     */
    static String createLiveKitToken(String identity, String room) throws Exception {
        long now = Instant.now().getEpochSecond();
        long exp = now + 86400; // 24 hours

        // JWT Header
        String header = base64url("{\"alg\":\"HS256\",\"typ\":\"JWT\"}");

        // JWT Payload — LiveKit access token claims
        String payload = base64url(String.format(
                "{\"iss\":\"%s\","
              + "\"sub\":\"%s\","
              + "\"name\":\"%s\","
              + "\"nbf\":%d,"
              + "\"exp\":%d,"
              + "\"video\":{"
              +   "\"room\":\"%s\","
              +   "\"roomJoin\":true,"
              +   "\"canPublish\":true,"
              +   "\"canPublishData\":true,"
              +   "\"canSubscribe\":true"
              + "}}",
                LIVEKIT_API_KEY, identity, identity, now, exp, room));

        // HMAC-SHA256 signature
        String sigInput = header + "." + payload;
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(LIVEKIT_API_SECRET.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        String signature = Base64.getUrlEncoder().withoutPadding()
                .encodeToString(mac.doFinal(sigInput.getBytes(StandardCharsets.UTF_8)));

        return sigInput + "." + signature;
    }

    // ════════════════════════════════════════════════════════════════════
    //  BitHuman REST API helpers
    // ════════════════════════════════════════════════════════════════════

    static String bithumanPost(String path, String jsonBody)
            throws IOException, InterruptedException {
        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(BITHUMAN_API_BASE + path))
                .header("Content-Type", "application/json")
                .header("api-secret", BITHUMAN_API_SECRET)
                .timeout(Duration.ofSeconds(15))
                .POST(HttpRequest.BodyPublishers.ofString(jsonBody))
                .build();
        return HTTP.send(req, HttpResponse.BodyHandlers.ofString()).body();
    }

    // ════════════════════════════════════════════════════════════════════
    //  Utility methods
    // ════════════════════════════════════════════════════════════════════

    static String env(String key, String fallback) {
        String v = System.getenv(key);
        return v != null && !v.isEmpty() ? v : fallback;
    }

    static String base64url(String s) {
        return Base64.getUrlEncoder().withoutPadding()
                .encodeToString(s.getBytes(StandardCharsets.UTF_8));
    }

    static String randomId(int len) {
        return UUID.randomUUID().toString().replace("-", "").substring(0, len);
    }

    static String paramValue(String query, String key) {
        if (query == null) return null;
        for (String pair : query.split("&")) {
            String[] kv = pair.split("=", 2);
            if (kv.length == 2 && kv[0].equals(key)) return kv[1];
        }
        return null;
    }

    static String readBody(HttpExchange ex) throws IOException {
        try (InputStream is = ex.getRequestBody()) {
            return new String(is.readAllBytes(), StandardCharsets.UTF_8);
        }
    }

    static void sendJson(HttpExchange ex, int code, String json) throws IOException {
        byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().set("Content-Type", "application/json");
        ex.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
        ex.sendResponseHeaders(code, bytes.length);
        try (OutputStream os = ex.getResponseBody()) { os.write(bytes); }
    }

    /** Escape special characters for safe JSON string embedding */
    static String escapeJson(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"")
                .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t");
    }

    // ════════════════════════════════════════════════════════════════════
    //  Embedded Web Client (HTML + LiveKit JS SDK)
    // ════════════════════════════════════════════════════════════════════

    /** Build the HTML page with config values injected. */
    static String getHtmlPage() {
        return HTML_TEMPLATE
                .replace("{{LIVEKIT_URL}}", escapeJson(LIVEKIT_URL))
                .replace("{{AVATAR_ID}}", escapeJson(BITHUMAN_AVATAR_ID));
    }

    static final String HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>BitHuman Streaming Demo (Java)</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
         background: #0a0a0f; color: #e0e0e0; min-height: 100vh;
         display: flex; flex-direction: column; align-items: center; }
  h1 { margin: 24px 0 8px; font-size: 1.4em; color: #8b9cf7; }
  .subtitle { font-size: 0.85em; color: #666; margin-bottom: 16px; }
  #video-container { position: relative; width: 640px; height: 480px;
                     background: #111; border-radius: 12px; overflow: hidden;
                     border: 1px solid #222; }
  #video-container video { width: 100%; height: 100%; object-fit: cover; }
  #status-overlay { position: absolute; top: 50%; left: 50%;
                    transform: translate(-50%, -50%); text-align: center;
                    color: #888; font-size: 0.95em; }
  .spinner { width: 32px; height: 32px; border: 3px solid #333;
             border-top-color: #8b9cf7; border-radius: 50%;
             animation: spin 0.8s linear infinite; margin: 0 auto 12px; }
  @keyframes spin { to { transform: rotate(360deg); } }
  .controls { display: flex; gap: 10px; margin: 16px 0; flex-wrap: wrap;
              justify-content: center; }
  button { padding: 10px 20px; border: 1px solid #333; border-radius: 8px;
           background: #1a1a2e; color: #e0e0e0; cursor: pointer;
           font-size: 0.9em; transition: all 0.2s; }
  button:hover { background: #252545; border-color: #8b9cf7; }
  button:disabled { opacity: 0.4; cursor: not-allowed; }
  button.active { background: #2a2a5e; border-color: #8b9cf7; }
  button.danger { border-color: #e74c3c; }
  button.danger:hover { background: #3c1a1a; }
  .input-row { display: flex; gap: 8px; margin: 8px 0; width: 640px; }
  .input-row input { flex: 1; padding: 10px 14px; border: 1px solid #333;
                     border-radius: 8px; background: #111; color: #e0e0e0;
                     font-size: 0.9em; }
  .input-row input::placeholder { color: #555; }
  .input-row button { flex-shrink: 0; }
  #log { width: 640px; max-height: 160px; overflow-y: auto; margin: 12px 0 24px;
         padding: 12px; background: #0d0d14; border: 1px solid #1a1a2a;
         border-radius: 8px; font-family: 'SF Mono', monospace; font-size: 0.78em;
         color: #6a6a8a; line-height: 1.5; }
</style>
</head>
<body>
  <h1>BitHuman Streaming Demo</h1>
  <p class="subtitle">Avatar: {{AVATAR_ID}} &mdash; Powered by Java + LiveKit + bitHuman Cloud</p>

  <div id="video-container">
    <div id="status-overlay">
      <p>Click <b>Connect</b> to start</p>
    </div>
  </div>

  <div class="controls">
    <button id="btn-connect" onclick="doConnect()">Connect</button>
    <button id="btn-mic" onclick="toggleMic()" disabled>Unmute Mic</button>
    <button id="btn-disconnect" class="danger" onclick="doDisconnect()" disabled>Disconnect</button>
  </div>

  <div class="input-row">
    <input id="speak-input" placeholder="Type a message for the avatar to speak..."
           onkeydown="if(event.key==='Enter')doSpeak()">
    <button onclick="doSpeak()">Speak</button>
  </div>
  <div class="input-row">
    <input id="context-input" placeholder="Add background context for the avatar..."
           onkeydown="if(event.key==='Enter')doAddContext()">
    <button onclick="doAddContext()">Add Context</button>
  </div>

  <div id="log"></div>

  <!-- LiveKit Client SDK from CDN -->
  <script src="https://cdn.jsdelivr.net/npm/livekit-client@2/dist/livekit-client.umd.js"></script>
  <script>
    const { Room, RoomEvent, Track, ConnectionState } = LivekitClient;

    let room = null;
    let micEnabled = false;

    function log(msg) {
      const el = document.getElementById('log');
      const ts = new Date().toLocaleTimeString();
      const entry = document.createElement('div');
      entry.textContent = '[' + ts + '] ' + msg;
      el.appendChild(entry);
      el.scrollTop = el.scrollHeight;
    }

    function setStatus(text) {
      document.getElementById('status-overlay').textContent = text;
    }

    function setStatusConnecting(text) {
      const overlay = document.getElementById('status-overlay');
      overlay.textContent = '';
      const spinner = document.createElement('div');
      spinner.className = 'spinner';
      overlay.appendChild(spinner);
      const p = document.createElement('p');
      p.textContent = text;
      overlay.appendChild(p);
    }

    async function doConnect() {
      document.getElementById('btn-connect').disabled = true;
      setStatusConnecting('Requesting token...');
      log('Requesting LiveKit token...');

      try {
        const resp = await fetch('/api/token');
        const data = await resp.json();
        if (data.error) throw new Error(data.error);

        log('Token received. Room: ' + data.room + ', Identity: ' + data.identity);
        setStatusConnecting('Connecting to LiveKit...');

        room = new Room({ adaptiveStream: true, dynacast: true });

        room.on(RoomEvent.TrackSubscribed, (track, pub, participant) => {
          log('Track subscribed: ' + track.kind + ' from ' + participant.identity);
          const container = document.getElementById('video-container');

          if (track.kind === 'video') {
            document.getElementById('status-overlay').style.display = 'none';
            const el = track.attach();
            el.style.width = '100%';
            el.style.height = '100%';
            el.style.objectFit = 'cover';
            container.appendChild(el);
          } else if (track.kind === 'audio') {
            const el = track.attach();
            el.style.display = 'none';
            container.appendChild(el);
          }
        });

        room.on(RoomEvent.TrackUnsubscribed, (track) => {
          track.detach().forEach(el => el.remove());
        });

        room.on(RoomEvent.Disconnected, () => {
          log('Disconnected from room.');
          resetUI();
        });

        room.on(RoomEvent.ParticipantConnected, (p) => {
          log('Participant joined: ' + p.identity);
        });

        room.on(RoomEvent.ParticipantDisconnected, (p) => {
          log('Participant left: ' + p.identity);
        });

        await room.connect(data.wsUrl, data.token);
        log('Connected to LiveKit room!');
        setStatusConnecting('Waiting for avatar...');

        document.getElementById('btn-mic').disabled = false;
        document.getElementById('btn-disconnect').disabled = false;

        await room.localParticipant.setMicrophoneEnabled(true);
        micEnabled = true;
        document.getElementById('btn-mic').textContent = 'Mute Mic';
        document.getElementById('btn-mic').classList.add('active');
        log('Microphone enabled. Speak to the avatar!');

      } catch (e) {
        log('ERROR: ' + e.message);
        setStatus('Connection failed: ' + e.message);
        document.getElementById('btn-connect').disabled = false;
      }
    }

    async function toggleMic() {
      if (!room) return;
      micEnabled = !micEnabled;
      await room.localParticipant.setMicrophoneEnabled(micEnabled);
      document.getElementById('btn-mic').textContent = micEnabled ? 'Mute Mic' : 'Unmute Mic';
      document.getElementById('btn-mic').classList.toggle('active', micEnabled);
      log(micEnabled ? 'Microphone enabled.' : 'Microphone muted.');
    }

    async function doDisconnect() {
      if (room) { room.disconnect(); room = null; }
      resetUI();
    }

    function resetUI() {
      document.getElementById('btn-connect').disabled = false;
      document.getElementById('btn-mic').disabled = true;
      document.getElementById('btn-disconnect').disabled = true;
      document.getElementById('btn-mic').textContent = 'Unmute Mic';
      document.getElementById('btn-mic').classList.remove('active');
      micEnabled = false;
      const container = document.getElementById('video-container');
      container.querySelectorAll('video, audio').forEach(el => el.remove());
      document.getElementById('status-overlay').style.display = '';
      setStatus('Disconnected. Click Connect to start again.');
    }

    async function doSpeak() {
      const input = document.getElementById('speak-input');
      const msg = input.value.trim();
      if (!msg) return;
      input.value = '';
      log('Sending speak command: "' + msg + '"');
      try {
        const resp = await fetch('/api/speak', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: msg })
        });
        const data = await resp.json();
        log('Speak response: ' + JSON.stringify(data));
      } catch (e) { log('Speak error: ' + e.message); }
    }

    async function doAddContext() {
      const input = document.getElementById('context-input');
      const ctx = input.value.trim();
      if (!ctx) return;
      input.value = '';
      log('Adding context: "' + ctx + '"');
      try {
        const resp = await fetch('/api/context', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ context: ctx, type: 'add_context' })
        });
        const data = await resp.json();
        log('Context response: ' + JSON.stringify(data));
      } catch (e) { log('Context error: ' + e.message); }
    }

    log('Ready. Click Connect to join the avatar session.');
  </script>
</body>
</html>
""";
}
