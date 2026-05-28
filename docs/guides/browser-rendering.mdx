---
title: "Browser rendering — ONNX in the user's tab"
sidebarTitle: "Browser rendering"
description: "Move avatar rendering out of your server and into the browser. ONNX Runtime + WASM does the mel spectrogram, audio encoder, and frame compositing client-side. The agent worker keeps the brain (STT/LLM/TTS); the video never leaves the user's machine."
keywords:
  - browser avatar rendering
  - ONNX Runtime Web
  - WebAssembly lip sync
  - client-side avatar
  - WASM avatar
  - rendering_mode
  - offline avatar browser
  - bithuman browser
---

`rendering_mode=browser` and `rendering_mode=avatar` are two URL-toggled
modes on every bitHuman agent landing page. They move the avatar
rendering pipeline (mel spectrogram → ONNX audio encoder → KNN cluster
lookup → frame composite) **out of your server and into the user's
browser**, using ONNX Runtime Web on a WebAssembly backend. The agent
worker keeps the brain; the GPU on the server is free.

Production-deployed since Feb 2026. No install, no SDK call — flip one
URL parameter on an existing agent landing page.

```
# Browser-side rendering, agent brain still cloud:
https://agent.viewer.bithuman.ai/<AGENT_CODE>?rendering_mode=browser

# Pure client-side puppet (mic-driven, no LiveKit, no agent worker):
https://agent.viewer.bithuman.ai/?rendering_mode=avatar&model_url=<IMX_URL>
```

[Try it on a showcase agent →](https://agent.viewer.bithuman.ai/A74NWD9723?rendering_mode=browser)

## When you'd reach for it

- **Server video egress is the bottleneck.** Cloud rendering publishes
  H.264 over LiveKit; browser rendering publishes only the agent's TTS
  audio. Bandwidth drops ~10–20×.
- **You're paying for avatar GPU on the server.** Browser mode skips
  the avatar worker dispatch entirely — the agent-worker pipeline
  runs STT/LLM/TTS only.
- **Privacy: the rendered video never leaves the user's machine.**
  Useful for kiosks, healthcare, education.
- **Offline / cached.** In `avatar` mode the IMX is cached in
  IndexedDB after the first load. Subsequent sessions need no network
  for the avatar — the brain still does, unless you also run
  [local mode](/guides/local-mode).
- **Cross-device parity.** The same WASM pipeline runs in Safari /
  Chrome / Firefox on macOS, Windows, Linux, iOS, and Android. No
  per-platform native build.

## The three rendering modes

| Mode | Where avatar runs | Where brain runs | LiveKit | Audio source |
|---|---|---|---|---|
| `cloud` *(default)* | Server (H.264 video published) | Server | Yes — video track | Server TTS, server-side |
| `browser` | **Browser** (ONNX WASM, 25 FPS canvas) | Server | Yes — audio track only | Agent TTS over LiveKit audio |
| `avatar` | **Browser** (ONNX WASM, 25 FPS canvas) | None — pure puppet | No | User's microphone (getUserMedia) |

`cloud` is the production default. The new modes are opt-in via URL
parameter — your existing deployments are unchanged.

## Activate it

It's a URL parameter on the agent landing page:

```
# Replace AGENT_CODE with your code from bithuman.ai → Developer.
https://agent.viewer.bithuman.ai/<AGENT_CODE>?rendering_mode=browser
```

For `avatar` mode (no agent worker, no LiveKit), pass the IMX model URL
directly:

```
https://agent.viewer.bithuman.ai/?rendering_mode=avatar&model_url=https://your-storage/avatar.imx
```

The browser downloads the IMX (~50–200 MB, per-agent), the ONNX audio
encoder (2.7 MB, shared across all agents), then runs the lip-sync
pipeline at 25 FPS on a `<canvas>`.

## What the browser does

```
MediaStreamTrack (TTS or mic)
  ↓ AudioContext + AudioWorklet (16 kHz, 640-sample chunks)
  ↓ Mel spectrogram (80 bins × 16 frames, Bluestein FFT)
  ↓ ONNX audio encoder (WASM, 512-D embedding)
  ↓ KNN cluster lookup (183 clusters, L2 distance)
  ↓ Frame composite (base frame + mouth patch, alpha-blended)
  ↓ <canvas> @ 25 FPS
```

The pipeline is bit-compatible with [`libessence`](/getting-started/architecture)
on the server — same `.imx` file, same cluster centroids, same encoder
weights. The browser just runs the inference loop in WASM.

## Latency budget

40 ms per frame (25 FPS) on a modest laptop:

| Stage | Typical |
|---|---|
| Mel FFT | 5–10 ms |
| ONNX encoder (WASM) | 10–20 ms |
| KNN lookup + composite | 5–10 ms |

Network adds the LiveKit audio-track RTT in `browser` mode (typically
50–150 ms one-way to nearest LiveKit edge). In `avatar` mode there's no
network in the loop at all once the IMX is cached.

## Browser requirements

- **SharedArrayBuffer** for ONNX Runtime Web multi-threading. Your page
  needs both `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: credentialless` (or `require-corp`)
  headers. The bitHuman-hosted landing page is already configured.
- **WebAssembly** + `AudioWorklet` — all current Safari, Chrome,
  Firefox, Edge.
- **IndexedDB** ~50–200 MB of free quota for the IMX cache (per-agent).
- **`requestVideoFrameCallback`** for smooth frame pacing (optional —
  the pipeline falls back to `requestAnimationFrame` on older Safari).

## Cloud vs browser vs avatar — side by side

| | **cloud** | **browser** | **avatar** |
|---|---|---|---|
| Server avatar GPU | yes | **no** | none |
| Server brain (STT/LLM/TTS) | yes | yes | none |
| LiveKit subscription | video + audio | **audio only** | none |
| Browser ML work | none | mel + ONNX + composite | mel + ONNX + composite |
| Server → browser bandwidth | 0.5–2 Mbps video | 32–64 kbps audio | 0 |
| Offline-capable | no | partial (brain still needs net) | **yes (post-cache)** |
| Setup | `bithuman run` / cloud session | append `?rendering_mode=browser` | append `?rendering_mode=avatar&model_url=…` |

## Try it

- [Showcase agent — browser mode](https://agent.viewer.bithuman.ai/A74NWD9723?rendering_mode=browser) — server brain, client-rendered avatar
- [Showcase agent — cloud mode](https://agent.viewer.bithuman.ai/A74NWD9723) — for comparison

## Future work

The browser pipeline is currently distributed via the hosted
agent-landing page only. A standalone JS/TS SDK that wraps the same
pipeline for embedding in your own React / Vue / vanilla app is
[on the roadmap](/roadmap). Track or comment in [Discord](https://discord.gg/ES953n7bPA).

## See also

- [Local mode](/guides/local-mode) — fully on-device *brain* (whisper.cpp + llama.cpp + Supertonic). Pair with browser rendering for an end-to-end no-cloud loop.
- [Architecture](/getting-started/architecture) — how `libessence` powers every renderer
- [Roadmap](/roadmap) — JS/TS SDK is exploring; this guide will grow into a real client integration story when that lands
