# EssenceServer

A native Swift LiveKit avatar service. Hosts N `EssenceRuntime` instances
behind an HTTP `/launch` endpoint, joins LiveKit rooms as a participant,
and republishes lip-synced video **and** audio in lockstep. Drop-in
replacement for the Python `essence-avatar` pool; designed to run as
launchd-supervised processes on a single Mac.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the deployment topology,
process model, and subsystem layout.

## Run

```bash
cd Examples/swift/essence-server
swift run -c release EssenceServer
```

Then `POST /launch` with a room/agent payload to spawn an avatar into a
LiveKit room. Configuration (port, LiveKit URL/keys, fixture roots) is
read from the environment — see `Config.swift`.

## Dependencies beyond the SDK

Unlike the app examples, this server pulls in three public SwiftPM
packages that are **not** bundled into the `bitHumanKit` binary (they're
a server concern, not an SDK concern):

- `bithuman-livekit-swift` — bitHuman fork of `client-sdk-swift` with a
  no-device app-audio patch (lets a headless server publish audio in
  manual-render mode without claiming the mic). Drop the fork once
  [livekit/client-sdk-swift#985](https://github.com/livekit/client-sdk-swift/pull/985)
  merges + tags.
- `jwt-kit` — LiveKit access-token minting.
- `hummingbird` — the HTTP server hosting `/launch`.

## Requires

- macOS 26+ (Tahoe), Apple Silicon
- LiveKit Cloud (or self-hosted) credentials
- One or more `.imx` Essence fixtures
- Microphone permission (embedded `Info.plist` declares
  `NSMicrophoneUsageDescription`; TCC grants the mic so LiveKit's
  `LocalAudioTrack` can initialize for audio republish)
