// SessionAudioRenderer — bridge from a LiveKit `RemoteAudioTrack` into
// `EssenceRuntime.pushAudio`.
//
// The Swift LiveKit SDK delivers audio as `AVAudioPCMBuffer` in whatever
// format WebRTC negotiated (typically 48 kHz Int16 mono, sometimes
// float32). EssenceRuntime expects 16 kHz Int16 mono, so we resample
// every incoming buffer through an `AVAudioConverter` (lazily set up
// from the first buffer's format).
//
// The SDK calls `render(pcmBuffer:)` on its audio thread. We do the
// resample synchronously there (cheap; AVAudioConverter is C-level)
// and dispatch the actual `pushAudio` call into a Task so the audio
// thread is never blocked on the actor.
//
// We also track playback timing so EssenceSession can report
// `lk.playback_finished` back to the brain (livekit-agents avatar
// protocol). The audio thread updates `lastFrameAt` and accumulates
// the current speech turn's duration; the session's monitor task
// reads it to decide when speech ended (silence ≥ idleThreshold).
//
// `@unchecked Sendable` — the SDK serializes calls to render(), and
// our internal mutable state is guarded by `stateLock` for the rare
// cross-thread reader (the playback monitor).

import AVFoundation
import LiveKit
import bitHumanKit

final class SessionAudioRenderer: NSObject, AudioRenderer, @unchecked Sendable {

    static let outFormat: AVAudioFormat = {
        // 16 kHz mono Int16, interleaved (single channel = trivially "interleaved").
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        )!
    }()

    private let runtime: EssenceRuntime
    private var converter: AVAudioConverter?
    private var lastInFormat: AVAudioFormat?

    // Playback-tracking state. Touched from both the SDK audio thread
    // (in render()) and the session's monitor task (via the public
    // accessors below). Guarded by stateLock.
    private let stateLock = NSLock()
    private var _lastFrameAt: TimeInterval = 0       // monotonic, last non-empty render
    private var _turnStartedAt: TimeInterval = 0     // when current speech turn began (0 = idle)
    private var _turnSamples: Int = 0                // samples accumulated this turn (16 kHz)
    private var _dropUntil: TimeInterval = 0         // drop incoming audio while now < this

    init(runtime: EssenceRuntime) {
        self.runtime = runtime
    }

    /// Snapshot of playback state for the monitor task to decide
    /// whether to fire `playback_finished`.
    func snapshotForMonitor() -> (active: Bool, lastFrameAt: TimeInterval, position: TimeInterval) {
        stateLock.lock()
        defer { stateLock.unlock() }
        let active = _turnStartedAt != 0
        let position = active ? Double(_turnSamples) / Self.outFormat.sampleRate : 0
        return (active, _lastFrameAt, position)
    }

    /// Called by EssenceSession when (a) the brain sent `lk.clear_buffer`
    /// or (b) we just emitted `playback_finished` ourselves. Resets the
    /// turn counters so the next inbound audio starts a fresh turn.
    /// Returns the playback position (seconds) of the turn that just ended.
    /// `dropForMs` causes incoming audio to be discarded for that window —
    /// approximates draining the runtime's already-buffered audio after
    /// an interrupt (the runtime itself has no clear-buffer API).
    func resetTurn(dropForMs: Int = 0) -> TimeInterval {
        stateLock.lock()
        defer { stateLock.unlock() }
        let position = _turnStartedAt != 0
            ? Double(_turnSamples) / Self.outFormat.sampleRate
            : 0
        _turnStartedAt = 0
        _turnSamples = 0
        if dropForMs > 0 {
            _dropUntil = monotonicNow() + Double(dropForMs) / 1000.0
        }
        return position
    }

    func render(pcmBuffer: AVAudioPCMBuffer) {
        let now = monotonicNow()

        stateLock.lock()
        if now < _dropUntil {
            stateLock.unlock()
            return  // post-interrupt window; drop residual audio
        }
        stateLock.unlock()

        let inFmt = pcmBuffer.format

        // Lazily build / rebuild converter when the incoming format changes.
        if converter == nil || lastInFormat?.isEqual(inFmt) != true {
            converter = AVAudioConverter(from: inFmt, to: Self.outFormat)
            lastInFormat = inFmt
            if converter == nil {
                FileHandle.standardError.write(Data(
                    "audio-renderer: AVAudioConverter init failed (in=\(inFmt))\n".utf8))
                return
            }
        }
        guard let converter else { return }

        let inFrames = pcmBuffer.frameLength
        guard inFrames > 0 else { return }

        let ratio = Self.outFormat.sampleRate / inFmt.sampleRate
        let outCapacity = AVAudioFrameCount((Double(inFrames) * ratio).rounded(.up)) + 32
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: Self.outFormat, frameCapacity: outCapacity)
        else { return }

        var consumed = false
        let inputBlock: AVAudioConverterInputBlock = { _, statusOut in
            if consumed {
                statusOut.pointee = .noDataNow
                return nil
            }
            consumed = true
            statusOut.pointee = .haveData
            return pcmBuffer
        }

        var nsErr: NSError?
        let status = converter.convert(to: outBuf, error: &nsErr, withInputFrom: inputBlock)
        if status == .error || nsErr != nil {
            FileHandle.standardError.write(Data(
                "audio-renderer: convert error: \(String(describing: nsErr))\n".utf8))
            return
        }

        let outFrames = Int(outBuf.frameLength)
        guard outFrames > 0,
              let int16Ptr = outBuf.int16ChannelData?[0]
        else { return }

        // Update playback-tracking state under the lock.
        stateLock.lock()
        if _turnStartedAt == 0 { _turnStartedAt = now }
        _lastFrameAt = now
        _turnSamples += outFrames
        stateLock.unlock()

        let samples = Array(UnsafeBufferPointer(start: int16Ptr, count: outFrames))

        // Hand off to the actor without blocking the audio thread.
        let runtime = self.runtime
        Task { await runtime.pushAudio(samples) }
    }
}

// Module-private monotonic clock for the renderer + monitor.
@inline(__always)
internal func monotonicNow() -> TimeInterval {
    var ts = timespec()
    clock_gettime(CLOCK_MONOTONIC, &ts)
    return Double(ts.tv_sec) + Double(ts.tv_nsec) / 1_000_000_000.0
}
