// Config.swift — central place for the tunables that used to live
// scattered across EssenceSession.swift, main.swift, plist files, and
// system commands. Anything that's "what knobs does the server have?"
// should live here so:
//
//   1. There's one greppable file to answer "is X configurable?"
//   2. Operations changes (raising max-sessions, narrowing the
//      playback idle threshold, switching codecs for testing) don't
//      require touching the inner-loop code.
//   3. Future env-var or YAML overrides land in one parser instead of
//      sprinkled across the codebase.
//
// Usage: read static fields. Call `EssenceServerConfig.applyEnv()` at
// process start to honor env-var overrides; tests can construct a
// custom config instance with the public init.

import Foundation

/// Values that affect the avatar's render + publish pipeline. The
/// defaults here match the production deployment on moraga as of
/// 2026-05-05 (8 procs × 8 sessions = 64 cap, 720 p @ 25 fps).
public struct EssenceServerConfig: Sendable {
    // MARK: - Video

    /// Output frame width in pixels. Avatar runtime composes at this
    /// width regardless of the model's native frame_wh — the runtime
    /// internally resizes.
    public let frameWidth: Int

    /// Output frame height in pixels.
    public let frameHeight: Int

    /// Target capture rate. The runtime drives this — the LiveKit
    /// `BufferCaptureOptions.fps` is just an encoder hint.
    public let fps: Int

    // MARK: - Audio

    /// How long the playback monitor waits after the last non-empty
    /// audio frame before considering a turn finished and emitting
    /// `lk.playback_finished`. Should be ≥ ~ runtime audio buffer
    /// drain time so we don't fire prematurely between TTS chunks.
    public let playbackIdleThresholdSec: TimeInterval

    // MARK: - Pool / capacity

    /// Per-process session cap. The pool (8 procs) multiplies this
    /// for the Mac-wide cap. Set via `--max-sessions` on the CLI;
    /// also written to the plist by `redeploy.sh`. Default 8 here
    /// matches the launchd template.
    public let maxSessionsPerProcess: Int

    // MARK: - Init

    public init(
        frameWidth: Int = 1280,
        frameHeight: Int = 720,
        fps: Int = 25,
        playbackIdleThresholdSec: TimeInterval = 0.8,
        maxSessionsPerProcess: Int = 8
    ) {
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight
        self.fps = fps
        self.playbackIdleThresholdSec = playbackIdleThresholdSec
        self.maxSessionsPerProcess = maxSessionsPerProcess
    }

    /// The active config for this process. Writeable so tests can
    /// install fixtures; production overrides via `applyEnv()` below.
    /// Reads of this must happen on `EssenceServerConfig.shared`
    /// (avoids the global-let-vs-actor-isolation pitfall).
    nonisolated(unsafe) public static var shared = EssenceServerConfig()

    /// Honor environment-variable overrides. Called once at startup
    /// from `main.swift` before any session is constructed. Variables:
    ///
    ///   - `ESSENCE_FRAME_WIDTH`   (Int, default 1280)
    ///   - `ESSENCE_FRAME_HEIGHT`  (Int, default 720)
    ///   - `ESSENCE_FPS`           (Int, default 25)
    ///   - `ESSENCE_IDLE_SEC`      (Double, default 0.8)
    ///
    /// Pool size is set per-process via the existing `--max-sessions`
    /// CLI flag; this method does NOT override that since the launchd
    /// plist passes it explicitly.
    public static func applyEnv(maxSessionsPerProcess: Int) {
        let env = ProcessInfo.processInfo.environment

        func intVar(_ key: String, _ fallback: Int) -> Int {
            guard let s = env[key], let v = Int(s) else { return fallback }
            return v
        }
        func doubleVar(_ key: String, _ fallback: Double) -> Double {
            guard let s = env[key], let v = Double(s) else { return fallback }
            return v
        }

        let cfg = EssenceServerConfig(
            frameWidth: intVar("ESSENCE_FRAME_WIDTH", 1280),
            frameHeight: intVar("ESSENCE_FRAME_HEIGHT", 720),
            fps: intVar("ESSENCE_FPS", 25),
            playbackIdleThresholdSec: doubleVar("ESSENCE_IDLE_SEC", 0.8),
            maxSessionsPerProcess: maxSessionsPerProcess
        )
        EssenceServerConfig.shared = cfg

        // Surface the final config so operators see what's actually in
        // effect, not just what they intended.
        FileHandle.standardError.write(Data(
            "essence-server: config frame=\(cfg.frameWidth)x\(cfg.frameHeight) fps=\(cfg.fps) idle=\(cfg.playbackIdleThresholdSec)s max-sessions=\(cfg.maxSessionsPerProcess)\n".utf8))
    }
}
