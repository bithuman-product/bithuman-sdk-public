# `essence-server` — architecture & operations

A native Swift LiveKit avatar service. Drop-in replacement for the
Python `essence-avatar` pool; runs as 8 launchd-supervised processes
on a single Mac, uses the `bithuman-kit` Essence runtime for lipsync,
and republishes both video AND audio in lockstep through LiveKit
Cloud.

This document is the top-level overview. For implementation details
on a specific subsystem, see the source-file headers
(`EssenceSession.swift`, `Config.swift`, `Metrics.swift`) and the
`bithuman-product/bithuman-livekit-swift` fork's `MixerEngineObserver.swift`.

## Deployment topology (moraga)

```
┌──── browser (any Tailscale-connected Mac) ────────────────────────┐
│                                                                   │
│   https://my-mac.my-tailnet.ts.net/AGENT_CODE?rendering_mode=cloud│
│                                                                   │
└────────────────────────┬──────────────────────────────────────────┘
                         │ HTTPS via Tailscale Serve (port 443)
                         ▼
┌────────────── moraga (M4 Max, headless MBP) ──────────────────────┐
│                                                                   │
│   ┌─ agent-ui (Next.js dev) :3000 ──────────────────────────────┐ │
│   │   /pages/[agentCode].tsx → mints LK token, dispatches       │ │
│   │   `bithuman-swift-essence` agent                            │ │
│   └──────────────────────────┬──────────────────────────────────┘ │
│                              │                                    │
│   ┌─ OrbStack containers ────┼──────────────────────────────────┐ │
│   │  bithuman-agent (brain)  │ DataStreamAudioOutput            │ │
│   │  livekit-dev             │   (no track; byte-stream         │ │
│   │  bithuman-lb (nginx)     │    on lk.audio_stream topic)     │ │
│   │  bithuman-auth           │                                  │ │
│   └──────────────────────────┼──────────────────────────────────┘ │
│                              │ POST /launch via nginx LB          │
│                              ▼                                    │
│   ┌─ essence-server pool (8 procs × 12 sessions = 96 cap) ──────┐ │
│   │  ports 8089–8096                                            │ │
│   │  LaunchAgents (per-user, ProcessType=Interactive, Nice=-10) │ │
│   │  pmset -c powermode 2  (High Power Mode for full P-core    │ │
│   │                          boost on this clamshell-closed MBP)│ │
│   └────────────────────────────┬────────────────────────────────┘ │
│                                │ LiveKit room as                  │
│                                │ "bithuman-avatar-agent"           │
└────────────────────────────────┼──────────────────────────────────┘
                                 │
                                 ▼
                   ┌─── LiveKit Cloud (US Central) ───┐
                   │   Routes WebRTC media P2P /      │
                   │   via TURN; signals brain ↔      │
                   │   avatar ↔ user                  │
                   └──────────────────────────────────┘
```

**Why this shape?** moraga is a broken-display MBP M4 Max. macOS
imposes a P-core power cap when the lid is closed without an
external display, but `pmset -c powermode 2` overrides it (no
display required). The brain runs in OrbStack so we keep the Linux
deployment pathway working unchanged; only the avatar layer is
Swift-native on the host. nginx is what bridges OrbStack-network
agents into the host-network Swift pool via `host.docker.internal`.

See `~/.claude/.../memory/project_moraga_pcore_throttle.md` for the
hardware-config rationale.

## Per-session pipeline (one room)

```
                     LiveKit Room
                     ────────────
brain (Python)                                    user (browser)
─────────────                                     ──────────────
DataStreamAudio                                   subscribes to
   Output                                         avatar tracks
      │                                                ▲
      │ topic=lk.audio_stream                          │
      │ (Int16 PCM, 24 kHz mono,                       │
      │  paced ~10 chunks/s,                           │
      │  caller=agent-AJ_*)                            │
      ▼                                                │
┌──────── essence-server (Swift, this repo) ──────────┴──────┐
│                                                            │
│   handleAudioByteStream                                    │
│   ──────────────────────                                   │
│   on first chunk: recordBrainIdentity(callerIdentity)      │
│   per chunk:                                               │
│     renderer.render(buf)  ──► EssenceRuntime.pushAudio     │
│                                       │                    │
│                                       │ resampled to 16    │
│                                       │ kHz Int16 mono     │
│                                       ▼                    │
│   spawnFramePump (Task.detached, .userInitiated)           │
│   ────────────────────────────                             │
│   for await pair in runtime.framesWithAudio():             │
│     # `pair` is one (CGImage, [Int16]) — the runtime's     │
│     # 40 ms output: image AND the audio chunk that         │
│     # produced it. Same wall-clock for both.               │
│     ts = createTimeStampNs()                               │
│     capturer.capture(pair.image,    timeStampNs=ts)        │
│     mixer.capture(appAudio: pair.audioChunk)               │
│                       │                                    │
│                       ▼                                    │
│   AVAudioEngine ──► WebRTC ADM (manual rendering mode,     │
│                     no real audio device claim — see       │
│                     fork's MixerEngineObserver)            │
│                       │                                    │
│                       ▼                                    │
└────────────────  LocalAudioTrack + LocalVideoTrack  ───────┘
                          │
                          ▼
                  user hears + sees in sync
```

**Sync invariant:** every audio chunk we publish on the avatar's
audio track is the EXACT 40 ms slice the runtime processed for the
paired video frame. There is no separate "feed brain audio directly
to the audio track" path. The `framesWithAudio()` API is the only
audio source. See `EssenceSession.swift` header for the rationale.

## Components, by file

### `Examples/EssenceServer/Sources/EssenceServer/`

| File | Role |
|---|---|
| `main.swift` | HTTP server (Hummingbird), `/health`, `/ready`, `/status`, `/metrics`, `/launch` routes. Reads CLI flags + env vars into `EssenceServerConfig.shared`. |
| `EssenceSession.swift` | One LiveKit-participant session. Owns the runtime, audio renderer, framepump, RPC handlers, lifecycle. The interesting code. |
| `AudioRenderer.swift` | Bridge from a `RemoteAudioTrack` and the byte-stream handler into `runtime.pushAudio` (resampled to 16 kHz Int16). |
| `Config.swift` | Central tunables (frame size, fps, idle threshold, max-sessions). Honors env-var overrides at startup. |
| `Metrics.swift` | Process-wide counters; `/metrics` Prometheus text output. |
| `FixtureCache.swift` | One `EssenceFixture` per `avatar_id`, shared across all sessions in a process (so JPEG decode happens once per fixture per process). |
| `ModelStore.swift` | Resolves `avatar_id` → on-disk `.imx` path, downloading on cache miss. |

### `Sources/bitHumanKit/Essence/` (the runtime)

| File | Role |
|---|---|
| `EssenceRuntime.swift` | Public actor. `pushAudio` + `frames()` + `framesWithAudio()`. The pump runs at 25 fps internally; `framesWithAudio()` is what `essence-server` consumes. |
| `EssenceGenerator.swift` | The actual lipsync inference (mel STFT → ONNX → KNN → frame composite). |
| `MP4FrameReader.swift` | Loads and decodes the base video loop (the avatar's body / background). |
| `PatchReader.swift` | Loads and serves lip patches (the mouth region inserts). |

### Forked Swift LiveKit SDK

`bithuman-product/bithuman-livekit-swift` (branch `main`, tracks upstream
v2.14+) carries one patch:
[`MixerEngineObserver.wireAppAudioPath()`](https://github.com/bithuman-product/bithuman-livekit-swift/tree/main/Sources/LiveKit/Audio/MixerEngineObserver.swift)
— lets `mixer.capture(appAudio:)` work in manual rendering mode (no
audio device claim). Without it, multi-process deployments can't
publish audio: only one process at a time can hold the macOS audio
device.

Upstream PR: https://github.com/livekit/client-sdk-swift/pull/985.
Drop the fork pin in `Package.swift` once it's merged.

## Lifecycle & failure modes

### Startup (per process, ~1 s)
1. `main.swift` parses CLI + env, calls `EssenceServerConfig.applyEnv`.
2. `AudioManager.setManualRenderingMode(true)` engages the no-device
   audio path. If this fails, **all republished audio will be silent**
   — `/ready` returns 503 in that case.
3. Hummingbird starts on `--port` and serves `/health` immediately.
4. `/launch` is gated on the registry capacity (`--max-sessions`).

### Per session
1. `/launch` → `SessionRegistry.reserve(room:)` (race-safe).
2. `EssenceSession.start(url:, token:)` connects to the LK room as
   `bithuman-avatar-agent`, calls `setMicrophone(enabled:true)`
   (manual rendering = no real mic claim), publishes the video track.
3. Bootstrap with 1 s of silence so the first frame is produced
   before `publish()` awaits the dimensions completer.
4. Brain opens an `lk.audio_stream` byte-stream targeted at the
   avatar identity; per-chunk handler feeds the runtime.
5. The framepump publishes paired `(image, audioChunk)` per emitted
   runtime tick. RPCs (`lk.clear_buffer`, `lk.playback_finished`)
   handle interruption + turn-end.
6. When the room empties of real peers (no participants other than
   `agent-AJ_*` dispatcher identities), the session self-stops with
   `reason="room-empty"` and the slot is released.

### Common failure-mode decoder

| Symptom | Likely cause | Where to look |
|---|---|---|
| "Audio works, video lags by seconds" | Two parallel audio paths (legacy bug — fixed by `framesWithAudio()`) | `EssenceSession.swift` header |
| "Mouth moves but no sound" | Audio queue cap < runtime audio buffer (legacy bug — runtime kept audio we discarded) | runtime's `audioBufferCapacity` vs any local queue |
| "Avatar echoes user's voice" | `SessionAudioRenderer` attached to remote audio track + framepump publishing runtime output → user mic looped back | `handleSubscribedTrack` (must NOT attach renderer; documented inline) |
| "Audio plays before video starts" | WebRTC video keyframe latency on subscribe; not an A/V bug. Try incognito mode (cached browser session can confuse) | browser-side |
| "Many sessions but FPS drops" | (a) JPEG cache too small (pre-2026-05-05), (b) runtime hitting compute saturation. Check pool CPU and `aj_*` profile samples | `MP4FrameReader.jpegCap`, `sample` on a busy process |
| "Can't launch new sessions, /launch returns 503" | Pool at-cap. `/status` shows `at_capacity=true` | scale up `--max-sessions` if hardware allows; raise the LB's retry budget |
| "Sessions linger after browser close" | Was a bug pre-2026-05-05 (zombies until process restart). Now `participantDidDisconnect` → 1.5 s grace → self-stop | check `room-empty` log line in session log |

## Operations

### Quick references

```bash
# Deploy a code change end-to-end
~/code/platform/deploy/macos/redeploy.sh

# Re-deploy without rebuild (e.g. after just touching the plist)
~/code/platform/deploy/macos/redeploy.sh --skip-build

# Watch live pump-fps after deploy
~/code/platform/deploy/macos/redeploy.sh --watch

# Smoke test (single-session audio republish)
~/code/platform/tools/bench/bench smoke

# Capacity verification (current production cap)
~/code/platform/tools/bench/bench stress 96

# Per-process ceiling (hardware probe)
~/code/platform/tools/bench/bench stress-one 16

# Production mix (idle vs active)
~/code/platform/tools/bench/bench mixed 128 64

# Full e2e (brain dispatch through to user audio + video)
~/code/platform/tools/bench/bench e2e

# Read all per-instance metrics
for p in 8089 8090 8091 8092 8093 8094 8095 8096; do
    echo "--- :$p ---"
    curl -s http://127.0.0.1:$p/metrics | grep '^essence_' | head -8
done
```

### Tunable knobs (env vars at process start; see `Config.swift`)

| Env var | Default | Effect |
|---|---:|---|
| `ESSENCE_FRAME_WIDTH` | 1280 | Output video width |
| `ESSENCE_FRAME_HEIGHT` | 720 | Output video height |
| `ESSENCE_FPS` | 25 | Target framerate (also drives audio chunk size) |
| `ESSENCE_IDLE_SEC` | 0.8 | Playback monitor idle threshold |

CLI: `--max-sessions N` (per-process cap; pool cap = N × 8 procs).

### System-level requirements (set once on moraga)

```bash
sudo pmset -c powermode 2     # High Power Mode (essential — see memory note)
sudo pmset -c disablesleep 1  # Don't sleep on AC
```

The LaunchAgent plist (`deploy/macos/com.bithuman.essence-server.template.plist`)
also sets `ProcessType=Interactive` and `Nice=-10` so essence-server
runs on P-cores at elevated priority over background daemons.

## See also

- Architectural rule for A/V sync in lipsync runtimes:
  `~/.claude/.../memory/feedback_essence_av_sync.md`
- moraga performance setup (HPM + Interactive QoS + Nice -10):
  `~/.claude/.../memory/project_moraga_pcore_throttle.md`
- Forked SDK rationale (no-device app-audio):
  `~/.claude/.../memory/project_essence_server_audio.md`
