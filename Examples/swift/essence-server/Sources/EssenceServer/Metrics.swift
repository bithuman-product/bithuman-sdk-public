// Metrics.swift — process-wide counters and a /metrics endpoint that
// emits Prometheus-compatible text. Lets operators scrape:
//
//   curl http://moraga:8089/metrics
//
// and graph "are sessions completing? are frames flowing? is the
// runtime keeping up?" without grepping logs.
//
// Counters are atomic (lock-free) so they're safe to bump from any
// thread (`Task.detached` framepump, byte-stream readers, the actor
// itself). Output is bog-standard Prometheus text v0.0.4 — works
// with Grafana, Datadog, and `promtool check metrics`.

import Foundation

/// Process-wide counter store. Each metric is a `os.Atomic<UInt64>`
/// (since macOS 26 ships with std atomics) — wrapped to give the
/// rest of the codebase a stable add/get API even if the underlying
/// primitive changes (e.g. distinguishing per-session vs aggregate).
public final class EssenceMetrics: @unchecked Sendable {

    /// Counters and gauges exposed at /metrics. Comment lines explain
    /// what each is so the Prometheus help text is meaningful.
    public struct Snapshot {
        public var sessionsActive: UInt64 = 0
        public var sessionsTotalStarted: UInt64 = 0
        public var sessionsTotalTerminated: UInt64 = 0
        public var sessionsLaunchFailed: UInt64 = 0
        public var framesPublishedTotal: UInt64 = 0
        public var audioChunksPublishedTotal: UInt64 = 0
        public var byteStreamChunksReceivedTotal: UInt64 = 0
        public var rpcPlaybackFinishedTotal: UInt64 = 0
        public var rpcClearBufferTotal: UInt64 = 0
        public var roomEmptyTerminationsTotal: UInt64 = 0
    }

    private let lock = NSLock()
    private var snap = Snapshot()
    private let processStart = Date()

    public static let shared = EssenceMetrics()

    public func setActiveSessions(_ n: UInt64) {
        lock.lock(); defer { lock.unlock() }
        snap.sessionsActive = n
    }
    public func incrSessionsStarted()           { incr(\.sessionsTotalStarted) }
    public func incrSessionsTerminated()        { incr(\.sessionsTotalTerminated) }
    public func incrLaunchFailed()              { incr(\.sessionsLaunchFailed) }
    public func incrFramesPublished()           { incr(\.framesPublishedTotal) }
    public func incrAudioChunksPublished()      { incr(\.audioChunksPublishedTotal) }
    public func incrByteStreamChunks()          { incr(\.byteStreamChunksReceivedTotal) }
    public func incrPlaybackFinished()          { incr(\.rpcPlaybackFinishedTotal) }
    public func incrClearBuffer()               { incr(\.rpcClearBufferTotal) }
    public func incrRoomEmptyTermination()      { incr(\.roomEmptyTerminationsTotal) }

    private func incr(_ kp: WritableKeyPath<Snapshot, UInt64>) {
        lock.lock(); defer { lock.unlock() }
        snap[keyPath: kp] &+= 1
    }

    /// Snapshot the whole struct under one lock. Cheaper than
    /// individual atomic reads at scrape time.
    public func snapshot() -> Snapshot {
        lock.lock(); defer { lock.unlock() }
        return snap
    }

    /// Render the snapshot as Prometheus text v0.0.4. Each metric
    /// gets a `# HELP` and `# TYPE` line; values follow on a single
    /// line each. Process uptime is included so dashboards can spot
    /// recent restarts.
    public func renderPrometheus() -> String {
        let s = snapshot()
        let uptime = Date().timeIntervalSince(processStart)
        var out = ""
        func emit(_ name: String, _ help: String, _ type: String, _ value: UInt64) {
            out += "# HELP essence_\(name) \(help)\n"
            out += "# TYPE essence_\(name) \(type)\n"
            out += "essence_\(name) \(value)\n"
        }
        func emitFloat(_ name: String, _ help: String, _ type: String, _ value: Double) {
            out += "# HELP essence_\(name) \(help)\n"
            out += "# TYPE essence_\(name) \(type)\n"
            out += "essence_\(name) \(value)\n"
        }
        emit("sessions_active", "Sessions currently running on this process", "gauge", s.sessionsActive)
        emit("sessions_started_total", "Sessions that successfully started since process boot", "counter", s.sessionsTotalStarted)
        emit("sessions_terminated_total", "Sessions that ended for any reason", "counter", s.sessionsTotalTerminated)
        emit("sessions_launch_failed_total", "/launch requests that failed before reserving a slot", "counter", s.sessionsLaunchFailed)
        emit("frames_published_total", "Real (non-reemitted) video frames published to LiveKit", "counter", s.framesPublishedTotal)
        emit("audio_chunks_published_total", "40 ms audio chunks published to LiveKit (paired with video frames)", "counter", s.audioChunksPublishedTotal)
        emit("byte_stream_chunks_received_total", "Audio chunks received from the brain via lk.audio_stream", "counter", s.byteStreamChunksReceivedTotal)
        emit("rpc_playback_finished_total", "lk.playback_finished RPCs sent to the brain", "counter", s.rpcPlaybackFinishedTotal)
        emit("rpc_clear_buffer_total", "lk.clear_buffer RPCs received from the brain", "counter", s.rpcClearBufferTotal)
        emit("room_empty_terminations_total", "Sessions self-stopped because the room emptied of real peers", "counter", s.roomEmptyTerminationsTotal)
        emitFloat("process_uptime_seconds", "Seconds since this essence-server process started", "gauge", uptime)
        return out
    }
}
