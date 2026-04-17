# bithuman Swift SDK — minimal example

An end-to-end demo of [`bithuman-product/bithuman-expression-swift`](https://github.com/bithuman-product/bithuman-expression-swift): load a packed `.imx` model, push synthetic audio, write the rendered avatar frames + paired audio to disk as a PNG sequence + WAV. Shows the exact lifecycle a real macOS app needs — construct, push, drain, flush, shutdown.

**What the example is NOT:** a real UI. Real apps feed frames into `CALayer` or `AVSampleBufferDisplayLayer` and audio into `AVAudioEngine`. This writes to disk so you can inspect the output in Finder.

For a fully-integrated reference app, see [**bitHuman Halo**](https://github.com/bithuman-product/halo) — the first app built on this SDK.

## Requirements

- macOS 14+
- **Apple Silicon, M3 or later**
- 16 GB RAM
- ~5 GB free disk (for the packed `.imx`)
- Xcode 16.3+ (Swift 6.1 tools)

## 1. Build the `.imx` model (one-time, ~3.7 GB)

Expression models ship as a single `.imx` container — all four weight files + the baked reference latent + a manifest, bundled by the Python CLI. Install `bithuman` (on any machine — the pack step doesn't run the model), grab the weight artifacts from Cloudflare R2, and pack:

```bash
pip install --upgrade bithuman

bithuman pack \
    --dit          path/to/dmd2_run9.safetensors \
    --wav2vec      path/to/wav2vec2.safetensors \
    --vae-encoder  path/to/vae_encoder.safetensors \
    --ane-decoder  path/to/turbo_vaed_ane_384.mlpackage \
    --ref-latent   path/to/default_ref_latent.npy \
    -o expression.imx
```

Drop `expression.imx` anywhere on disk — the example accepts a path as its first argument or reads `BITHUMAN_MODEL_PATH`. The conventional cache location `~/Library/Caches/com.bithuman.sdk/weights/expression.imx` is the fallback if neither is set.

> **macOS + Apple Silicon (M3+) only.** The DiT + ANE pipeline needs the GPU memory bandwidth of M3 (and the Neural Engine's `.mlpackage` ops). M1 and M2 Macs, and non-Apple platforms, won't run the Expression model.

## 2. (Optional) Enable billing / heartbeat

The example above runs the SDK **unmetered** — great for local exploration, not allowed for production use. Production apps call `Bithuman.create(modelPath:apiSecret:)` instead, passing an API secret you get at [bithuman.ai → Developer → API Keys](https://www.bithuman.ai/#developer).

```swift
let result = try await Bithuman.create(
    modelPath: modelPath,
    apiSecret: ProcessInfo.processInfo.environment["BITHUMAN_API_SECRET"]!
)
```

Billing matches the self-hosted Expression GPU container: **2 credits per minute**, metered by a background heartbeat that pings `api.bithuman.ai/v1/runtime-tokens/request` every 60 s. On `402 Payment Required` or `403 Account Suspended` the SDK flags the session fatal and subsequent `pushAudio` calls throw `BithumanAuthError`.

Check `await bithuman.billingError` at any time to surface a "top up your account" UI affordance.

## 3. Build + run

```bash
cd integrations/swift
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift run BithumanSwiftExample ~/Library/Caches/com.bithuman.sdk/weights/expression.imx
```

Expected output:

```
BithumanSwiftExample — bitHuman Swift SDK demo

→ Loading model from /Users/you/Library/Caches/com.bithuman.sdk/weights/expression.imx
✓ Loaded in 4.2s
✓ Frame size: 512×512
✓ Wrote static idle frame → output/frame_0000.png

→ Pushing 3.0s of synthetic audio
→ Draining frames…
  … 33 frames (total 33)
  … 24 frames (total 57)
  … 24 frames (total 81)

✓ 81 frames + 1 WAV written to ./output/
  Play audio + flip through PNGs at 25 FPS (40 ms each) to preview.
```

The `output/` directory ends up with:
- `frame_0000.png` — the static backdrop rendered from the reference latent during `Bithuman.create`
- `frame_0001.png` … `frame_NNNN.png` — the rendered avatar frames, 25 FPS
- `audio.wav` — the 24 kHz mono audio slice that pairs with those frames

Open them side-by-side to verify the lip-sync.

## What the code shows

1. **`Bithuman.create(modelPath:)`** — one-call bootstrap from a single `.imx` file. The container is opened, the manifest is validated (`model_type: "expression"`), weights are extracted into a temp directory held for the runtime's lifetime, and the MLX pipeline + ANE decoder come up ready to render. The metered variant `Bithuman.create(modelPath:apiSecret:)` wires the billing heartbeat on top.
2. **Audio push + chunk drain loop** — the core streaming pattern. In a real app a 25 FPS display timer drives the poll; here we just sleep 40 ms and try again.
3. **`bithuman.snapshot`** + **`chunkQueueCount`** — nonisolated status reads used to detect when all pushed audio has been rendered.
4. **Lifecycle signals** — `flush`, `shutdown`. `interrupt` is not exercised here (no mid-stream cutoff in a synthetic scenario). `shutdown()` deletes the extracted temp directory as its final step.
5. **Billing state (when `apiSecret` is set)** — `await bithuman.billingError` returns a typed `BithumanAuthError` on HTTP 402 / 403, nil while healthy. `pushAudio` throws the same error so a poll-before-push pattern isn't required.

## What the code deliberately skips

- **Real speech audio.** The synthetic tone complex is enough to drive visible mouth motion without needing a TTS dependency. For real speech, feed in the output of any TTS system that emits Float32 PCM.
- **Live display.** Writing to disk decouples the example from AppKit / UIKit / AVFoundation concerns. A real app replaces `writePNG` with `displayLayer.contents = frame as CFTypeRef` (CALayer) or a `CVPixelBuffer` conversion into `AVSampleBufferDisplayLayer`.
- **Identity swap.** `PipelineOps.swapIdentity(box:imageURL:)` is documented in the SDK DocC; this example uses the baked reference latent from the `.imx` to keep things simple.
- **Barge-in.** `bithuman.interrupt()` aborts in-flight rendering and clears the chunk queue. Exercise it by calling it from a second Task while audio is still being pushed.

## Extending the example

A few natural directions:

- **Pipe in real TTS.** Replace `synthSpeechAudio` with the float samples from OpenAI TTS, ElevenLabs, or an on-device Kokoro. Any Float32 PCM works — the SDK resamples internally.
- **Live preview.** Swap the `writePNG` loop for an `AVSampleBufferDisplayLayer` hosted in an NSView, and schedule the matching audio onto an `AVAudioEngine` player node.
- **Microphone in, avatar out.** Tap `AVAudioEngine.inputNode` at 16 kHz, forward buffers to `pushAudio`, and you've got a real-time mimic loop.
- **Bench harness.** Wrap the chunk-drain loop with `CFAbsoluteTimeGetCurrent()` calls to measure per-chunk latency. The SDK's performance contract is ≤ 40 ms p99 on M3 hardware.

## Troubleshooting

**`Bithuman.create: invalid model file — …`**
The `.imx` is missing a required entry or its manifest `model_type` is not `"expression"`. Rebuild with `bithuman pack` — the CLI validates every input and writes a stamped manifest.

**`error: could not resolve package dependencies` / authentication prompt**
The `bithuman-expression-swift` repo is currently private. You need a GitHub token with `Contents: Read` access to the repo. The simplest path: run `gh auth setup-git` once with an authenticated `gh` session. SPM will pick up the credential helper automatically.

**Tests hang for more than 30 s**
The synthesis function produces deliberately energetic audio. If the SDK appears to stall, check the Console for `[CoreML]` messages — a first-run `.mlpackage` compile can take 20+ seconds before the ANE decoder is ready.

**Frame rate below 25 FPS**
The SDK's performance contract assumes M3 hardware. M1 and M2 Macs are not supported in v0.x — the DiT model needs the GPU memory bandwidth of M3+ to sustain real-time generation.

## License

Apache 2.0 (matching the SDK). See [`../../LICENSE`](../../LICENSE).

Model weights are distributed under a separate license — see the SDK repo's `docs/WEIGHTS_LICENSE.md`.
