// EssenceServer — drop-in Swift replacement for platform/services/essence-avatar.
//
// Hosts N concurrent `EssenceRuntime` instances. Each /launch request joins a
// LiveKit room as a participant, subscribes to the bot's TTS audio (published
// by agent-worker), pipes it through bitHumanKit's Essence runtime, and
// publishes the resulting lip-synced video back to the same room.
//
// Running:
//   swift build -c release --product essence-server
//   ./.build/release/essence-server --port 8089 --agent-root ~/agents
//
// Same wire protocol as the Python dispatcher:
//   POST /launch   form: avatar_id, room_name, livekit_url, livekit_token,
//                        async_mode, model_url, tags, api_secret, user_id
//   GET  /health   { status: "ok" }
//   GET  /ready    { status: "ok" }   (503 when at capacity, body still ok)
//   GET  /status   { mode, pool_size, active_workers, idle_workers,
//                    available_slots, at_capacity, rooms, active_rooms }

import Foundation
import Hummingbird
import LiveKit
import bitHumanKit

// MARK: - CLI

struct CLIOpts: Sendable {
    var port: Int = 8089
    var host: String = "0.0.0.0"
    var agentRoot: String = NSHomeDirectory() + "/agents"
    var maxSessions: Int = 32

    static func parse() -> CLIOpts {
        var o = CLIOpts()
        let raw = Array(CommandLine.arguments.dropFirst())
        var i = 0
        while i < raw.count {
            let a = raw[i]; defer { i += 1 }
            switch a {
            case "--port":         i += 1; o.port = Int(raw[i]) ?? o.port
            case "--host":         i += 1; o.host = raw[i]
            case "--agent-root":   i += 1; o.agentRoot = raw[i]
            case "--max-sessions": i += 1; o.maxSessions = Int(raw[i]) ?? o.maxSessions
            case "-h", "--help":
                print("""
                essence-server — Swift Essence runtime, LiveKit-participant edition.

                  --port <N>           HTTP port (default 8089)
                  --host <addr>        HTTP bind address (default 0.0.0.0)
                  --agent-root <dir>   Where to look up <code>/model.imx (default ~/agents)
                  --max-sessions <N>   Reject /launch beyond this (default 32)
                """)
                exit(0)
            default:
                FileHandle.standardError.write(Data("warning: ignored arg \(a)\n".utf8))
            }
        }
        return o
    }
}

// MARK: - Session registry

actor SessionRegistry {
    enum Slot {
        case reserving                  // /launch in flight, no session yet
        case active(EssenceSession)     // start() succeeded
    }

    let maxSessions: Int
    private var slots: [String: Slot] = [:]

    init(maxSessions: Int) { self.maxSessions = maxSessions }

    func count() -> Int { slots.count }
    func atCapacity() -> Bool { slots.count >= maxSessions }
    func rooms() -> [String] { Array(slots.keys).sorted() }

    /// Reserve a slot for `room`. Returns false if at capacity OR the
    /// room is already in use (race-safe gate; caller responds 503).
    func reserve(room: String) -> Bool {
        guard slots.count < maxSessions, slots[room] == nil else { return false }
        slots[room] = .reserving
        return true
    }

    /// Promote a reservation to an active session once `start()`
    /// returned successfully.
    func attach(room: String, session: EssenceSession) {
        slots[room] = .active(session)
    }

    /// Free the slot. Returns the active session if any, so the caller
    /// can finalize. Idempotent.
    func release(room: String) -> EssenceSession? {
        let prior = slots.removeValue(forKey: room)
        if case .active(let s) = prior { return s }
        return nil
    }
}

// MARK: - Wire types

struct HealthResp: Encodable { let status: String }

struct StatusResp: Encodable {
    let mode: String
    let pool_size: Int
    let active_workers: Int
    let idle_workers: Int
    let available_slots: Int
    let at_capacity: Bool
    let rooms: [String]
    let active_rooms: [String]
}

struct LaunchSuccess: Encodable {
    let status: String
    let message: String
    let mode: String
    let isAsync: Bool
    let duration: Double
    let request_id: String
    let dispatch_time: Double
    enum CodingKeys: String, CodingKey {
        case status, message, mode
        case isAsync = "async"
        case duration, request_id, dispatch_time
    }
}

struct ErrorResp: Encodable { let detail: String }

// MARK: - Form parsing

/// Parse `application/x-www-form-urlencoded` into a flat dict.
/// Tolerant: silently skips malformed pairs.
func parseForm(_ s: String) -> [String: String] {
    var out: [String: String] = [:]
    for pair in s.split(separator: "&", omittingEmptySubsequences: true) {
        guard let eq = pair.firstIndex(of: "=") else { continue }
        let kRaw = String(pair[..<eq])
        let vRaw = String(pair[pair.index(after: eq)...]).replacingOccurrences(of: "+", with: " ")
        let k = kRaw.removingPercentEncoding ?? kRaw
        let v = vRaw.removingPercentEncoding ?? vRaw
        out[k] = v
    }
    return out
}

struct LaunchForm {
    let livekitURL: String
    let livekitToken: String
    let roomName: String
    let avatarID: String        // "*" if caller omitted
    let isAsync: Bool
    let modelURL: URL?
    let tags: String?
    let apiSecret: String?
    let userID: String?

    static func parse(_ form: [String: String]) throws -> LaunchForm {
        func required(_ k: String) throws -> String {
            guard let v = form[k], !v.isEmpty else {
                throw FormError.missing(k)
            }
            return v
        }
        let asyncRaw = (form["async_mode"] ?? "false").lowercased()
        let isAsync = (asyncRaw == "true" || asyncRaw == "1" || asyncRaw == "yes")
        return LaunchForm(
            livekitURL:   try required("livekit_url"),
            livekitToken: try required("livekit_token"),
            roomName:     try required("room_name"),
            avatarID:     form["avatar_id"].flatMap { $0.isEmpty ? nil : $0 } ?? "*",
            isAsync:      isAsync,
            modelURL:     form["model_url"].flatMap { URL(string: $0) },
            tags:         form["tags"],
            apiSecret:    form["api_secret"],
            userID:       form["user_id"]
        )
    }

    enum FormError: Error, CustomStringConvertible {
        case missing(String)
        var description: String {
            switch self { case .missing(let k): return "missing required field: \(k)" }
        }
    }
}

// MARK: - JSON helper

func jsonResponse<T: Encodable>(_ value: T, status: HTTPResponse.Status = .ok) -> Response {
    let data: Data
    do {
        data = try JSONEncoder().encode(value)
    } catch {
        let fallback = #"{"detail":"internal: failed to encode response"}"#
        return Response(
            status: .internalServerError,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: .init(string: fallback))
        )
    }
    return Response(
        status: status,
        headers: [.contentType: "application/json"],
        body: .init(byteBuffer: ByteBuffer(bytes: data))
    )
}

// MARK: - HTTP

struct EssenceServerMain {
    static func main() async throws {
        let opts = CLIOpts.parse()
        // Set up the central config bag from CLI + env. Subsequent
        // session-level code reads from EssenceServerConfig.shared
        // instead of hard-coded constants. See Config.swift for the
        // list of env vars (ESSENCE_FRAME_WIDTH, ESSENCE_FPS, etc.).
        EssenceServerConfig.applyEnv(maxSessionsPerProcess: opts.maxSessions)

        let registry = SessionRegistry(maxSessions: opts.maxSessions)
        let modelStore = ModelStore(agentRoot: URL(fileURLWithPath: opts.agentRoot))
        let fixtureCache = FixtureCache()

        // Put the WebRTC ADM into manual rendering mode so the audio path
        // never opens a real device. Multiple essence-server processes
        // share one Mac and can't all claim the mic, so the no-device
        // path is the only way to publish audio from N processes
        // concurrently. Per-session, we let
        // `LocalParticipant.setMicrophone(enabled: true)` bring the
        // engine up — that is what the SDK's own
        // `testManualRenderingModePublishAudio` does, and in manual
        // rendering mode it doesn't claim the mic device.
        do {
            try AudioManager.shared.setManualRenderingMode(true)
            FileHandle.standardError.write(Data(
                "essence-server: manual rendering enabled (isManualRenderingMode=\(AudioManager.shared.isManualRenderingMode))\n".utf8))
        } catch {
            FileHandle.standardError.write(Data(
                "essence-server: setManualRenderingMode failed: \(error) — audio republish will be silent\n".utf8))
        }

        let router = Router()

        // /health is liveness-only — process is up and answering. Use
        // it for "is the server breathing"; never for routing.
        router.get("/health") { _, _ -> Response in
            jsonResponse(HealthResp(status: "ok"))
        }

        // /ready is what the LB should use for traffic routing. Returns
        // 200 only when:
        //   * manual rendering mode is engaged (audio republish path
        //     is operational; without it, audio publishes silently),
        //   * the registry isn't at the per-process cap (otherwise
        //     /launch will reject anyway, so don't waste the
        //     handshake).
        // 503 means "skip me" — the LB should retry on another
        // instance. Different from /health which says "the process
        // is alive" and is fine even when we can't accept work.
        router.get("/ready") { _, _ -> Response in
            let atCap = await registry.atCapacity()
            let manualRendering = AudioManager.shared.isManualRenderingMode
            let ready = !atCap && manualRendering
            let detail = ready ? "ok" :
                "atCap=\(atCap) manualRendering=\(manualRendering)"
            return jsonResponse(HealthResp(status: detail),
                                status: ready ? .ok : .serviceUnavailable)
        }

        // /metrics emits Prometheus-text format counters. Scrape with
        //   curl http://moraga:8089/metrics
        // No auth (HTTP-internal). Counters are process-local — each
        // of the 8 instances has its own; aggregate via Prometheus's
        // `sum by (instance) (...)`.
        router.get("/metrics") { _, _ -> Response in
            let body = EssenceMetrics.shared.renderPrometheus()
            return Response(
                status: .ok,
                headers: [.contentType: "text/plain; version=0.0.4; charset=utf-8"],
                body: .init(byteBuffer: ByteBuffer(string: body))
            )
        }

        router.get("/status") { _, _ -> Response in
            let n = await registry.count()
            let rooms = await registry.rooms()
            return jsonResponse(StatusResp(
                mode: "swift-pool",
                pool_size: opts.maxSessions,
                active_workers: n,
                idle_workers: max(0, opts.maxSessions - n),
                available_slots: max(0, opts.maxSessions - n),
                at_capacity: n >= opts.maxSessions,
                rooms: rooms,
                active_rooms: rooms
            ))
        }

        router.post("/launch") { req, _ -> Response in
            let t0 = Date()

            // 1. Capacity gate (mirror Python: refuse early so the LB can reroute).
            if await registry.atCapacity() {
                return jsonResponse(ErrorResp(detail: "at capacity"),
                                    status: .serviceUnavailable)
            }

            // 2. Parse form.
            let raw = try await req.body.collect(upTo: 16 * 1024)
            let bodyText = String(buffer: raw)
            let form: LaunchForm
            do {
                form = try LaunchForm.parse(parseForm(bodyText))
            } catch {
                return jsonResponse(ErrorResp(detail: "\(error)"),
                                    status: .badRequest)
            }

            // 3. Reserve a slot. Race-safe: registry rejects if cap was filled
            //    between step 1 and now.
            guard await registry.reserve(room: form.roomName) else {
                return jsonResponse(ErrorResp(detail: "at capacity"),
                                    status: .serviceUnavailable)
            }

            // 4. Resolve model on disk (download if needed). Releases the
            //    slot on every error path so a bad request can't poison capacity.
            let imxPath: URL
            do {
                imxPath = try await modelStore.resolve(
                    avatarID: form.avatarID, modelURL: form.modelURL)
            } catch let err as ModelStore.ModelError {
                _ = await registry.release(room: form.roomName)
                let status: HTTPResponse.Status = {
                    if case .notFound = err { return .badRequest }
                    return .internalServerError
                }()
                return jsonResponse(ErrorResp(detail: "\(err)"), status: status)
            } catch {
                _ = await registry.release(room: form.roomName)
                return jsonResponse(ErrorResp(detail: "model resolve: \(error)"),
                                    status: .internalServerError)
            }

            // 5. Warm the shared fixture (one-time per avatarID) and
            //    grab the reference; the session builds its own runtime
            //    off it via `Bithuman.createRuntime(fixture:)`.
            let fixture: EssenceFixture
            do {
                fixture = try await fixtureCache.get(avatarID: form.avatarID, imxPath: imxPath)
            } catch {
                _ = await registry.release(room: form.roomName)
                return jsonResponse(ErrorResp(detail: "fixture: \(error)"),
                                    status: .internalServerError)
            }

            // 6. Build session, connect to LiveKit, publish video. Sync
            //    mode (matches Python pool-mode): block on start() so the
            //    caller has backpressure-correct success semantics.
            let session = EssenceSession(
                roomName: form.roomName,
                fixture: fixture,
                onTerminate: { name in
                    _ = await registry.release(room: name)
                    EssenceMetrics.shared.incrSessionsTerminated()
                    EssenceMetrics.shared.setActiveSessions(UInt64(await registry.count()))
                }
            )
            do {
                try await session.start(url: form.livekitURL, token: form.livekitToken)
                EssenceMetrics.shared.incrSessionsStarted()
                EssenceMetrics.shared.setActiveSessions(UInt64(await registry.count()))
            } catch {
                EssenceMetrics.shared.incrLaunchFailed()
                // start() failed → release the slot. The session itself is
                // dead in the water; no need to call stop() since start()
                // is responsible for its own partial-state cleanup on throw.
                _ = await registry.release(room: form.roomName)
                return jsonResponse(ErrorResp(detail: "session start: \(error)"),
                                    status: .internalServerError)
            }
            await registry.attach(room: form.roomName, session: session)

            let dispatchTime = Date().timeIntervalSince(t0)
            return jsonResponse(LaunchSuccess(
                status: "success",
                message: "Avatar worker launched/dispatched for room: \(form.roomName)",
                mode: "swift-pool",
                isAsync: form.isAsync,
                duration: dispatchTime,
                request_id: "\(form.roomName)-\(Int(t0.timeIntervalSince1970 * 1000))",
                dispatch_time: dispatchTime
            ))
        }

        let app = Application(
            router: router,
            configuration: .init(address: .hostname(opts.host, port: opts.port),
                                 serverName: "essence-server")
        )

        FileHandle.standardError.write(Data(
            "essence-server listening on \(opts.host):\(opts.port) (max sessions \(opts.maxSessions); agents at \(opts.agentRoot))\n".utf8))

        try await app.runService()
    }
}

try await EssenceServerMain.main()
