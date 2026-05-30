// EssenceSession — one LiveKit-participant session, one EssenceRuntime.
//
// Pipeline (paired A/V from the runtime — matches Python's
// `BithumanGenerator._stream_impl` which yields VideoFrame +
// AudioFrame interleaved per output):
//
//   brain TTS via byte-stream  ──► SessionAudioRenderer
//   topic=lk.audio_stream           (resample 24 k Int16 → 16 k Int16)
//                                       │
//                                       ▼
//                                EssenceRuntime.pushAudio
//                                       │
//                                       ▼
//                                runtime.framesWithAudio()
//                                AsyncStream<EssenceRuntimeFrame>
//                                       │  (pairs: image + 16 kHz
//                                       │   mono Int16 chunk that
//                                       │   produced it)
//                                       ▼
//             ┌──────── pair.image ──────────┐
//             ▼                              ▼
//   CGImage → CVPixelBuffer            mixer.capture(appAudio: chunk)
//             │                              │  (16 kHz Int16 wrapped
//             ▼                              │   as AVAudioPCMBuffer)
//   BufferCapturer.capture                   ▼
//             │                       AVAudioEngine mainMixer
//             ▼                              │
//   LocalVideoTrack (H264,                   ▼
//   simulcast=false)                  WebRTC ADM samples
//             │                              │
//             ▼                              ▼
//   local participant publishes        LocalAudioTrack (mic-source,
//   video to room                      manual rendering)
//                                            │
//                                            ▼
//                                     local participant publishes
//                                     audio to room
//
// **Sync invariant:** every audio chunk we publish on the avatar's
// audio track is the EXACT 40 ms slice the runtime processed for the
// paired video frame. This is the only audio path — there is no
// parallel "feed brain audio directly to mixer.capture" branch
// (which used to exist and caused multi-second A/V drift since the
// direct path played at real-time while the runtime path lagged by
// per-turn cold-start latency). The user's mic track is also NOT
// fed into the runtime — see `handleSubscribedTrack` — because
// anything fed to the runtime gets republished, which would loop
// the user's voice back as the avatar's audio.
//
// Lifecycle quirks worth knowing:
//
//   - We seed the runtime with 1 s of silence at start so the first
//     frame (an idle frame) is produced before `publish()` runs. Without
//     it, `BufferCapturer.dimensionsCompleter` never fires and publish()
//     stalls for the full `.defaultCaptureStart` (10 s) and throws
//     `Code=101 Timed out`. (Side effect: that 1 s of silence comes
//     out of `framesWithAudio()` as actual zero-valued audio chunks
//     and is published as silence on the audio track. This is fine —
//     just zero bytes on the wire.)
//
//   - `runtime.framesWithAudio()` yields a frame with `audioChunk = nil`
//     during silent stretches (>100 ms with no real input audio). We
//     re-emit the cached lastBuffer so the encoder keeps emitting RTP
//     packets — without that, the SUBSCRIBER PC's DTLS keep-alive
//     expires and the SDK starts reconnecting. Audio publish is
//     skipped on these nil-chunk frames, so silence on the wire is
//     truly silent.
//
//   - The SDK fires `didDisconnectWithError(nil)` mid-`cleanUp(isFullReconnect:
//     true)` whenever it tries to reconnect after a transport hiccup.
//     We hook `didUpdateConnectionState` instead and only stop on
//     transitions FROM `.connected`/`.reconnecting` TO `.disconnected`
//     where the SDK isn't going back to `.reconnecting`.
//
//   - LiveKit's `Room` is `@unchecked Sendable`. `BufferCapturer` and
//     the runtime are likewise actor-friendly. The frame pump is a
//     detached Task that captures these directly so it doesn't fight
//     the actor for the lock 25× per second (the actor-bound version
//     observed 12.5 FPS — half the requested rate — and starved the
//     SDK signaling task).

import AVFoundation
import CoreVideo
import CoreGraphics
import Foundation
import LiveKit
import bitHumanKit

actor EssenceSession {

    enum SessionError: Error, CustomStringConvertible {
        case capturerCastFailed
        case pixelBufferAllocFailed(OSStatus)
        case runtimeBuildFailed(any Error)
        var description: String {
            switch self {
            case .capturerCastFailed:           return "EssenceSession: BufferCapturer cast failed"
            case .pixelBufferAllocFailed(let s): return "EssenceSession: CVPixelBufferCreate failed (status=\(s))"
            case .runtimeBuildFailed(let e):     return "EssenceSession: runtime build failed: \(e)"
            }
        }
    }

    // Pull video frame size and rate from `EssenceServerConfig.shared`
    // (set in `main.swift` from CLI flags + env vars). These shadow
    // the historical hard-coded constants so most call-sites can
    // continue using `Self.frameWidth` / `Self.frameHeight` / `Self.fps`
    // unchanged. `frameIntervalNs` is derived; updates if `fps` changes.
    private static var frameWidth: Int { EssenceServerConfig.shared.frameWidth }
    private static var frameHeight: Int { EssenceServerConfig.shared.frameHeight }
    private static var fps: Int { EssenceServerConfig.shared.fps }
    fileprivate static var frameIntervalNs: UInt64 {
        UInt64(1_000_000_000 / EssenceServerConfig.shared.fps)
    }

    let roomName: String
    private let fixture: EssenceFixture
    private let onTerminate: @Sendable (String) async -> Void

    private var runtime: EssenceRuntime?
    private var room: Room?
    private var capturer: BufferCapturer?
    private var pixelBufferPool: CVPixelBufferPool?
    private var publication: LocalTrackPublication?
    private var audioTrack: LocalAudioTrack?
    private var audioPublication: LocalTrackPublication?
    private var pumpTask: Task<Void, Never>?
    private var idleTickerTask: Task<Void, Never>?
    private var audioRenderer: SessionAudioRenderer?
    private var subscribedAudioTrack: RemoteAudioTrack?
    private var delegate: SessionRoomDelegate?
    private var hasBeenConnected = false
    private var stopped = false

    // livekit-agents avatar-protocol state. The brain (agent-worker)
    // calls `lk.clear_buffer` on us to interrupt; we reply
    // `lk.playback_finished` so the brain releases the speech turn.
    // Brain identity is set on first clear_buffer call and persisted
    // for subsequent playback_finished sends.
    private var brainIdentity: Participant.Identity?
    private var playbackMonitorTask: Task<Void, Never>?
    private static var playbackIdleThresholdSec: TimeInterval {
        EssenceServerConfig.shared.playbackIdleThresholdSec
    }

    init(roomName: String,
         fixture: EssenceFixture,
         onTerminate: @escaping @Sendable (String) async -> Void)
    {
        self.roomName = roomName
        self.fixture = fixture
        self.onTerminate = onTerminate
    }

    func start(url: String, token: String) async throws {
        // 1. Build a per-session runtime off the shared fixture.
        let runtime: EssenceRuntime
        do {
            runtime = try Bithuman.createRuntime(fixture: fixture)
        } catch {
            throw SessionError.runtimeBuildFailed(error)
        }
        self.runtime = runtime

        // 1b. Per-session CVPixelBuffer pool. Reusing IOSurface-backed
        //     buffers across frames avoids kernel allocs at 25 fps × N
        //     sessions. Pool size 4 covers the SDK's pipeline depth
        //     (capture → encode → transmit) with a slack buffer.
        let poolAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Self.frameWidth,
            kCVPixelBufferHeightKey as String: Self.frameHeight,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]
        let auxAttrs: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 4,
        ]
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, auxAttrs as CFDictionary,
                                poolAttrs as CFDictionary, &pool)
        self.pixelBufferPool = pool

        // 2. Set up Room + delegate (track-subscribe + connection-state hooks).
        let delegate = SessionRoomDelegate()
        let room = Room(delegate: delegate)
        delegate.onSubscribedTrack = { [weak self] pub in
            Task { await self?.handleSubscribedTrack(pub) }
        }
        delegate.onConnectionState = { [weak self] new, old in
            Task { await self?.handleConnectionState(new: new, old: old) }
        }
        delegate.onParticipantDisconnect = { [weak self] participant, remaining in
            Task { await self?.handleParticipantDisconnect(participant, remaining: remaining) }
        }
        self.delegate = delegate
        self.room = room

        // 3. Connect signaling (sends JOIN, awaits primary transport).
        try await room.connect(url: url, token: token)

        // 3b. Register the avatar-side RPC handlers expected by the
        //     livekit-agents avatar protocol. Without `lk.clear_buffer`
        //     the brain raises "Method not supported at destination"
        //     on every interrupt and times out the speech turn.
        try await room.registerRpcMethod("lk.clear_buffer") { [weak self] data in
            await self?.handleClearBuffer(callerIdentity: data.callerIdentity)
            return "ok"
        }

        // 3b-2. Subscribe to the brain's audio data stream
        //       (livekit-agents `DataStreamAudioOutput` writes raw PCM
        //       chunks under topic `lk.audio_stream`). This is how the
        //       agent's TTS audio reaches us — the brain does NOT
        //       publish audio as a regular RTC track. We feed each
        //       chunk into the runtime (for lip-sync) and into
        //       `AudioManager.shared.mixer.capture(appAudio:)` so the
        //       audio is also republished on our outgoing track.
        try await room.registerByteStreamHandler(for: "lk.audio_stream") { [weak self] reader, callerIdentity in
            await self?.handleAudioByteStream(reader: reader, callerIdentity: callerIdentity)
        }

        // 3c. Publish an outgoing audio track so users in the room can
        //     hear what the brain says. The actual PCM is fed into the
        //     audio engine via `mixer.capture(appAudio:)` in the byte-
        //     stream handler — the track itself is the wire path.
        //
        //     Disable voice-processing I/O before initializing the
        //     audio track. Voice-processing IO (vp-IO) requires audio-
        //     session entitlements that ad-hoc-signed CLI binaries
        //     don't have on macOS, and fails with kAudioUnitErr_
        //     FailedInitialization (-9000). RemoteIO without voice
        //     processing has no such requirement — and we don't need
        //     echo cancellation here anyway since we're not capturing
        //     a mic, only republishing already-rendered TTS audio.
        do {
            try AudioManager.shared.setVoiceProcessingEnabled(false)
        } catch {
            FileHandle.standardError.write(Data(
                "essence-session: setVoiceProcessingEnabled(false) warned: \(error)\n".utf8))
        }
        // Use setMicrophone(enabled: true) rather than building a custom
        // LocalAudioTrack: in manual rendering mode this is what the SDK
        // expects — it starts the WebRTC ADM in the no-device branch and
        // brings the AVAudioEngine up so `mixer.capture(appAudio:)` can
        // pump brain audio into mainMixer → published track. Mirrors the
        // SDK's own `testManualRenderingModePublishAudio` test pattern.
        // Disable echo cancellation / AGC / noise suppression — we are
        // not capturing a real mic, just republishing rendered TTS.
        let captureOpts = AudioCaptureOptions(
            echoCancellation: false,
            autoGainControl: false,
            noiseSuppression: false,
            highpassFilter: false,
            typingNoiseDetection: false
        )
        do {
            let pub = try await room.localParticipant.setMicrophone(
                enabled: true,
                captureOptions: captureOpts
            )
            self.audioTrack = pub?.track as? LocalAudioTrack
            self.audioPublication = pub
            FileHandle.standardError.write(Data(
                "essence-session: mic-source audio track published (manual rendering — no device claim)\n".utf8))
        } catch {
            FileHandle.standardError.write(Data(
                "essence-session: setMicrophone(enabled:true) failed (\(error)) — proceeding without audio republish\n".utf8))
            self.audioTrack = nil
            self.audioPublication = nil
        }

        // 3c. Kick off the playback monitor — fires
        //     `lk.playback_finished` to the brain when audio rendering
        //     stops for >`playbackIdleThresholdSec`. This is what
        //     releases the brain from waiting for playback to complete.
        playbackMonitorTask = startPlaybackMonitor()

        // 4. Build the publishing pipeline.
        let opts = BufferCaptureOptions(
            dimensions: Dimensions(width: Int32(Self.frameWidth),
                                   height: Int32(Self.frameHeight)),
            fps: Self.fps
        )
        let track = LocalVideoTrack.createBufferTrack(
            name: "avatar_video",
            source: .camera,
            options: opts
        )
        guard let cap = track.capturer as? BufferCapturer else {
            throw SessionError.capturerCastFailed
        }
        self.capturer = cap

        // 5. Audio renderer — gets attached once we see a remote audio track.
        self.audioRenderer = SessionAudioRenderer(runtime: runtime)

        // 6. Pump runtime.frames() → CVPixelBuffer → capturer. Detached so
        //    it doesn't fight the actor for the lock 25×/s.
        pumpTask = Self.spawnFramePump(
            runtime: runtime,
            capturer: cap,
            width: Self.frameWidth,
            height: Self.frameHeight,
            pool: pool,
            roomName: self.roomName
        )

        // 7. Bootstrap: push 1 s of silence so the runtime emits a real
        //    first frame before `publish()` awaits the dimensionsCompleter.
        let silence = [Int16](repeating: 0, count: 16_000)
        await runtime.pushAudio(silence)

        // 8. Publish.
        let pub = try await room.localParticipant.publish(
            videoTrack: track,
            options: VideoPublishOptions(
                name: "avatar_video",
                simulcast: false,
                preferredCodec: .h264
            )
        )
        self.publication = pub

        // 9. If there's already a subscribed audio track, attach now
        //    (handles the rare case where the agent published before us).
        for participant in room.remoteParticipants.values {
            for trackPub in participant.audioTracks {
                if let p = trackPub as? RemoteTrackPublication {
                    await handleSubscribedTrack(p)
                }
            }
        }
    }

    // MARK: - Frame pump

    /// Drains `runtime.frames()` and forwards each yielded CGImage to
    /// the LiveKit `BufferCapturer`. Detached so it doesn't fight the
    /// actor lock 25× per second.
    ///
    /// The runtime emits frames in a bursty pattern (25 in a fast
    /// burst as the audio buffer drains, then quieter while it
    /// rebuffers — including a synthetic silent-chunk path that loops
    /// the idle video at 25 FPS). This produces ~14 FPS at the encoder
    /// after WebRTC's adaptive throttling, with elevated jitter. A
    /// fixed-cadence DispatchSourceTimer was tried (decoupling consume
    /// from capture); it produced lower jitter but higher
    /// frame loss because the timer races the consumer at startup
    /// (slot empty for the first few ticks → no key frame; the
    /// encoder's session establishment fails). Reverted to the
    /// straight `for await` until we have a real audio source driving
    /// the runtime — then the cadence becomes steady on its own.
    private static func spawnFramePump(
        runtime: EssenceRuntime,
        capturer: BufferCapturer,
        width: Int,
        height: Int,
        pool: CVPixelBufferPool?,
        roomName: String
    ) -> Task<Void, Never> {
        // 16 kHz mono int16 — the runtime's internal audio format,
        // also the format the runtime hands back per-frame audio
        // chunks in. Built once and reused for every chunk's
        // AVAudioPCMBuffer.
        let runtimeAudioFormat: AVAudioFormat? = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        )
        return Task.detached(priority: .userInitiated) {
            // Use the paired audio+video stream: each yielded element
            // is the runtime's image AND the 40 ms audio slice that
            // produced it. Publishing both together gives perfect
            // lipsync — same wall-clock instant for the video frame
            // and its corresponding audio. Mirrors Python's
            // `BithumanGenerator._stream_impl` which yields paired
            // VideoFrame + AudioFrame.
            let stream = await runtime.framesWithAudio()
            var lastBuffer: CVPixelBuffer?
            var realFrames = 0
            var reemittedFrames = 0
            var windowStart = monotonicNow()
            for await pair in stream {
                if Task.isCancelled { break }
                let ts = VideoCapturer.createTimeStampNs()
                if let cgImage = pair.image {
                    if let pb = makePixelBuffer(from: cgImage, width: width, height: height, pool: pool) {
                        lastBuffer = pb
                        capturer.capture(pb, timeStampNs: ts)
                        realFrames += 1
                        EssenceMetrics.shared.incrFramesPublished()
                    }
                } else if let pb = lastBuffer {
                    capturer.capture(pb, timeStampNs: ts)
                    reemittedFrames += 1
                }
                // Publish audio for THIS frame at the same wall-clock
                // instant the video was captured. `audioChunk == nil`
                // means runtime synthesised a silent tick — skip
                // publishing rather than wasting bytes on silence.
                if let chunk = pair.audioChunk, let fmt = runtimeAudioFormat {
                    publishRuntimeAudioChunk(chunk, format: fmt)
                    EssenceMetrics.shared.incrAudioChunksPublished()
                }
                let elapsed = monotonicNow() - windowStart
                if elapsed >= 1.0 {
                    let total = realFrames + reemittedFrames
                    let realFps = Double(realFrames) / elapsed
                    let totalFps = Double(total) / elapsed
                    FileHandle.standardError.write(Data(
                        "essence-session: pump fps room=\(roomName) real=\(String(format: "%.1f", realFps)) total=\(String(format: "%.1f", totalFps))\n".utf8))
                    realFrames = 0
                    reemittedFrames = 0
                    windowStart = monotonicNow()
                }
            }
        }
    }

    /// Wrap a runtime audio chunk (16 kHz mono int16, 640 samples =
    /// 40 ms) into an `AVAudioPCMBuffer` and feed it to the SDK's
    /// app-audio path. Called from the framepump per emitted frame.
    private static func publishRuntimeAudioChunk(_ chunk: [Int16], format: AVAudioFormat) {
        guard !chunk.isEmpty else { return }
        guard let buf = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(chunk.count)
        ) else { return }
        buf.frameLength = AVAudioFrameCount(chunk.count)
        if let dst = buf.int16ChannelData?[0] {
            chunk.withUnsafeBufferPointer { srcPtr in
                if let srcBase = srcPtr.baseAddress {
                    memcpy(dst, srcBase, chunk.count * MemoryLayout<Int16>.size)
                }
            }
        }
        AudioManager.shared.mixer.capture(appAudio: buf)
    }

    // MARK: - Delegate handlers

    private func handleSubscribedTrack(_ pub: RemoteTrackPublication) async {
        guard subscribedAudioTrack == nil,
              let audioTrack = pub.track as? RemoteAudioTrack
        else { return }

        // We track the subscribed audio track only as a fallback path
        // for `inferAudioPublisher` (used when brainIdentity isn't
        // known yet). We do NOT attach the SessionAudioRenderer here
        // — the renderer feeds the runtime, and the only audio that
        // should drive the runtime is the brain's TTS arriving via
        // the `lk.audio_stream` byte-stream. Attaching the renderer
        // to the user's mic would loop the user's voice into the
        // runtime → which the framepump would then republish on the
        // avatar's audio track → user hears their own voice played
        // back by the avatar.
        FileHandle.standardError.write(Data(
            "essence-session: tracking remote audio track \(pub.sid.stringValue) (NOT fed to runtime — runtime is driven by brain byte-stream only)\n".utf8))
        subscribedAudioTrack = audioTrack
        _ = audioRenderer
    }

    /// Handle the brain's audio byte stream (livekit-agents
    /// `DataStreamAudioOutput`). Each chunk is raw Int16 PCM at
    /// `sample_rate` Hz / `num_channels` channels (set as stream
    /// attributes by the sender). For each chunk we:
    ///   1. Convert to AVAudioPCMBuffer in the sender's format.
    ///   2. Feed the runtime via SessionAudioRenderer.render() — drives
    ///      lip-sync (resampled to 16 kHz Int16 mono inside).
    ///   3. Push to AudioManager.shared.mixer.capture(appAudio:) so the
    ///      same audio is republished on our outgoing audio track for
    ///      users to hear.
    nonisolated private func handleAudioByteStream(
        reader: ByteStreamReader,
        callerIdentity: Participant.Identity
    ) async {
        let info = reader.info
        let sampleRate = Double(info.attributes["sample_rate"] ?? "") ?? 48_000
        let numChannels = AVAudioChannelCount(info.attributes["num_channels"] ?? "1") ?? 1
        guard let inFmt = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: numChannels,
            interleaved: true
        ) else { return }

        FileHandle.standardError.write(Data(
            "essence-session: byte-stream OPEN  topic=\(info.topic) caller=\(callerIdentity) sr=\(Int(sampleRate)) ch=\(numChannels)\n".utf8))

        // Capture the brain's identity from the very first audio
        // byte-stream. Without this, the avatar only learns the brain
        // identity when the brain sends `lk.clear_buffer` (an
        // interruption); a non-interrupted greeting playback means
        // we never get clear_buffer, never know the brain, and never
        // fire `lk.playback_finished` — the brain then hangs in its
        // "speaking" state forever and the UI sticks at "connecting".
        // Brain uses `DataStreamAudioOutput`, so it never publishes a
        // mic track; the byte-stream caller IS the brain.
        await self.recordBrainIdentity(callerIdentity)

        // Pull the renderer reference once (actor-isolated read). The
        // renderer itself is @unchecked Sendable; we call into it from
        // the byte-stream's executor.
        let renderer = await self.audioRenderer

        var totalBytes = 0
        var totalChunks = 0
        var lastLogAt = monotonicNow()

        do {
            for try await chunk in reader {
                guard !chunk.isEmpty else { continue }
                let bytesPerFrame = 2 * Int(numChannels)  // Int16 mono/stereo
                let frameCount = chunk.count / bytesPerFrame
                guard frameCount > 0 else { continue }

                guard let buf = AVAudioPCMBuffer(
                    pcmFormat: inFmt,
                    frameCapacity: AVAudioFrameCount(frameCount)
                ) else { continue }
                buf.frameLength = AVAudioFrameCount(frameCount)

                if let dst = buf.int16ChannelData?[0] {
                    chunk.withUnsafeBytes { rawPtr in
                        if let srcBase = rawPtr.baseAddress {
                            memcpy(dst, srcBase, chunk.count)
                        }
                    }
                }

                // Feed runtime; the runtime's audio→video pump emits
                // paired (image, 40 ms audio chunk) tuples that the
                // framepump publishes together. We do NOT call
                // `mixer.capture(appAudio:)` here — the framepump
                // does it per emitted frame using the runtime's
                // OUTPUT audio (the same 40 ms slice that produced
                // the image). That's what locks A/V sync regardless
                // of brain bursting or runtime startup latency.
                renderer?.render(pcmBuffer: buf)

                totalBytes += chunk.count
                totalChunks += 1
                EssenceMetrics.shared.incrByteStreamChunks()
                let now = monotonicNow()
                if now - lastLogAt > 1.0 {
                    FileHandle.standardError.write(Data(
                        "essence-session: byte-stream rcv  chunks=\(totalChunks) bytes=\(totalBytes) — last frameCount=\(frameCount)\n".utf8))
                    lastLogAt = now
                }
            }
        } catch {
            FileHandle.standardError.write(Data(
                "essence-session: audio byte-stream error: \(error) (after \(totalChunks) chunks, \(totalBytes) bytes)\n".utf8))
        }
        FileHandle.standardError.write(Data(
            "essence-session: byte-stream CLOSE  totalChunks=\(totalChunks) totalBytes=\(totalBytes)\n".utf8))
    }

    // MARK: - livekit-agents avatar-protocol RPC

    /// Brain interrupted us — drop in-flight queued audio and report
    /// `playback_finished(interrupted: true)` so the brain releases the
    /// turn. EssenceRuntime has no clear-buffer API, so we approximate
    /// by dropping new audio for a short window (the runtime's already-
    /// buffered audio plays out — typically <300 ms).
    private func handleClearBuffer(callerIdentity: Participant.Identity) async {
        EssenceMetrics.shared.incrClearBuffer()
        if brainIdentity == nil {
            brainIdentity = callerIdentity
        }
        let position = audioRenderer?.resetTurn(dropForMs: 250) ?? 0
        await firePlaybackFinished(interrupted: true, position: position)
    }

    /// Set `brainIdentity` if it isn't already known. Called from the
    /// audio byte-stream handler with the caller identity, since the
    /// brain (livekit-agents `DataStreamAudioOutput`) never publishes
    /// a mic track and `lk.clear_buffer` only fires on interruption.
    private func recordBrainIdentity(_ identity: Participant.Identity) {
        if brainIdentity == nil {
            brainIdentity = identity
        }
    }

    private func firePlaybackFinished(interrupted: Bool, position: TimeInterval) async {
        guard let room, let brain = brainIdentity else { return }
        // Schema must match livekit.agents.voice.io.PlaybackFinishedEvent.
        let payload = """
        {"playback_position": \(position), "interrupted": \(interrupted ? "true" : "false")}
        """
        do {
            _ = try await room.localParticipant.performRpc(
                destinationIdentity: brain,
                method: "lk.playback_finished",
                payload: payload
            )
            EssenceMetrics.shared.incrPlaybackFinished()
        } catch {
            FileHandle.standardError.write(Data(
                "essence-session: playback_finished rpc failed: \(error)\n".utf8))
        }
    }

    /// Polls the audio renderer 4×/sec; when a turn was active and the
    /// last audio frame was >`playbackIdleThresholdSec` ago, treat the
    /// turn as ended and report `playback_finished(interrupted: false)`.
    private func startPlaybackMonitor() -> Task<Void, Never> {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)  // 250 ms
                await self?.tickPlaybackMonitor()
            }
        }
    }

    private func tickPlaybackMonitor() async {
        guard let renderer = audioRenderer else { return }
        let snap = renderer.snapshotForMonitor()
        guard snap.active else { return }
        let elapsed = monotonicNow() - snap.lastFrameAt
        guard elapsed >= Self.playbackIdleThresholdSec else { return }
        // We need a brain identity to send to. If none yet (no
        // clear_buffer ever fired), fall back to the audio-track
        // publisher.
        if brainIdentity == nil,
           let track = subscribedAudioTrack,
           let participant = inferAudioPublisher(of: track)
        {
            brainIdentity = participant.identity
        }
        let position = renderer.resetTurn()
        guard brainIdentity != nil else { return }  // can't notify — drop
        await firePlaybackFinished(interrupted: false, position: position)
    }

    private func inferAudioPublisher(of track: RemoteAudioTrack) -> RemoteParticipant? {
        guard let room else { return nil }
        for p in room.remoteParticipants.values {
            for pub in p.audioTracks {
                if (pub as? RemoteTrackPublication)?.track?.sid == track.sid {
                    return p
                }
            }
        }
        return nil
    }

    private func handleConnectionState(new: ConnectionState, old: ConnectionState) async {
        FileHandle.standardError.write(Data(
            "essence-session: connection \(old) → \(new)\n".utf8))

        if case .connected = new {
            hasBeenConnected = true
            return
        }

        // The SDK fires `.connected → .reconnecting → .disconnected` mid
        // `cleanUp(isFullReconnect:)` and then transitions back to
        // `.connecting → .connected`. Reacting to `.disconnected`
        // synchronously would interrupt that recovery. Instead, schedule
        // a delayed recheck — if the SDK has recovered by then, the
        // state will be `.connected` (or `.reconnecting`/`.connecting`)
        // and we leave it alone. If it's still `.disconnected`, the
        // recovery genuinely failed and we should release the slot.
        if case .disconnected = new, hasBeenConnected, !stopped {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await self?.confirmTerminalDisconnect()
            }
        }
    }

    /// Brain or user (or both) left the room. When EVERY remote
    /// participant has gone, the avatar is alone — there is nobody
    /// left to receive its frames. Self-stop instead of lingering as
    /// a zombie until process restart, which used to be the only way
    /// to free the slot. (Slot leakage was the workaround we did
    /// dozens of times during stress testing — `launchctl bootout`+
    /// `bootstrap` to reset every process.)
    ///
    /// `remaining` is the count AFTER the just-disconnected
    /// participant left, so 0 means the room is empty of remotes.
    private func handleParticipantDisconnect(_ participant: RemoteParticipant, remaining: Int) async {
        FileHandle.standardError.write(Data(
            "essence-session: participant disconnected: \(participant.identity?.stringValue ?? "?") (sdk-reported remaining=\(remaining))\n".utf8))
        guard !stopped else { return }
        // Don't gate on `remaining` here — it sometimes includes the
        // just-disconnected participant or counts agent-dispatcher
        // identities the SDK lists as remote. Always schedule a
        // grace-period recheck and let `confirmEmptyRoom` make the
        // decision against the room's settled state.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5 s
            await self?.confirmEmptyRoom()
        }
    }

    private func confirmEmptyRoom() async {
        guard !stopped, let room else { return }
        // Filter out the avatar participants the SDK sometimes
        // exposes via `remoteParticipants` (livekit-cloud agent
        // dispatcher identities, etc.). What we care about is real
        // peers that are subscribing to our audio/video — typically
        // the brain (agent-worker) and the user (browser). If both
        // are gone, we have no consumers.
        let realPeers = room.remoteParticipants.values.filter { p in
            // Skip the LiveKit agent-dispatcher pseudo-participant
            // (identities like "agent-AJ_xxxxx"). They're metadata,
            // not consumers.
            let id = p.identity?.stringValue ?? ""
            return !id.hasPrefix("agent-AJ_")
        }
        guard realPeers.isEmpty else {
            FileHandle.standardError.write(Data(
                "essence-session: room still has \(realPeers.count) real peer(s) — not stopping\n".utf8))
            return
        }
        FileHandle.standardError.write(Data(
            "essence-session: room empty (no real peers) after grace; self-stopping\n".utf8))
        EssenceMetrics.shared.incrRoomEmptyTermination()
        await stop(reason: "room-empty")
    }

    private func confirmTerminalDisconnect() async {
        guard !stopped, let room else { return }
        let state = room.connectionState
        if state == .disconnected {
            await stop(reason: "connection-state-terminal")
        } else {
            FileHandle.standardError.write(Data(
                "essence-session: skipping terminal stop, state=\(state)\n".utf8))
        }
    }

    // MARK: - Lifecycle

    func stop(reason: String = "explicit") async {
        guard !stopped else { return }
        stopped = true
        FileHandle.standardError.write(Data(
            "essence-session: stop room=\(roomName) reason=\(reason)\n".utf8))

        pumpTask?.cancel()
        idleTickerTask?.cancel()
        playbackMonitorTask?.cancel()
        pumpTask = nil
        idleTickerTask = nil
        playbackMonitorTask = nil

        // Note: SessionAudioRenderer is no longer attached to remote
        // tracks (see handleSubscribedTrack), so there is no
        // `track.remove(audioRenderer:)` to do here. Just drop the
        // refs and let ARC clean up.
        subscribedAudioTrack = nil
        audioRenderer = nil
        audioTrack = nil
        audioPublication = nil

        if let runtime { await runtime.stop() }
        runtime = nil

        await room?.disconnect()
        room = nil
        capturer = nil
        publication = nil
        delegate = nil

        await onTerminate(roomName)
    }
}

// MARK: - CGImage → CVPixelBuffer (BGRA)

/// Draws `image` into a 32BGRA pixel buffer of the given size,
/// letterboxing / scaling via Core Graphics. If a `pool` is provided,
/// recycles a buffer from it (preferred — avoids IOSurface kernel
/// allocs per frame). Otherwise allocates one. Returns nil on alloc
/// failure (rare).
func makePixelBuffer(from image: CGImage, width: Int, height: Int,
                     pool: CVPixelBufferPool? = nil) -> CVPixelBuffer? {
    var pb: CVPixelBuffer?
    let status: CVReturn
    if let pool {
        status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pb)
    } else {
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]
        status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pb
        )
    }
    guard status == kCVReturnSuccess, let buf = pb else { return nil }

    CVPixelBufferLockBaseAddress(buf, [])
    defer { CVPixelBufferUnlockBaseAddress(buf, []) }

    guard let ctx = CGContext(
        data: CVPixelBufferGetBaseAddress(buf),
        width: width, height: height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                  | CGBitmapInfo.byteOrder32Little.rawValue
    ) else { return nil }

    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return buf
}

// MARK: - RoomDelegate adapter

/// LiveKit's RoomDelegate is `@objc` so it must be an NSObject. We
/// bounce events into closures that the actor can wire to its own
/// methods.
final class SessionRoomDelegate: NSObject, RoomDelegate, @unchecked Sendable {
    var onSubscribedTrack: (@Sendable (RemoteTrackPublication) -> Void)?
    var onConnectionState: (@Sendable (ConnectionState, ConnectionState) -> Void)?
    var onParticipantDisconnect: (@Sendable (RemoteParticipant, Int) -> Void)?

    func room(_ room: Room,
              participant: RemoteParticipant,
              didSubscribeTrack publication: RemoteTrackPublication)
    {
        onSubscribedTrack?(publication)
    }

    func room(_ room: Room,
              didUpdateConnectionState connectionState: ConnectionState,
              from oldConnectionState: ConnectionState)
    {
        onConnectionState?(connectionState, oldConnectionState)
    }

    func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        // Pass the *remaining* remote count so the actor handler can
        // decide if the room is empty without re-reading state.
        onParticipantDisconnect?(participant, room.remoteParticipants.count)
    }
}
