---
title: "Device matrix"
sidebarTitle: "Device matrix"
description: "Which avatar runs on which device, with hardware floors for every supported platform."
icon: "table-cells"
---

Use this page to verify your target device is supported before integrating. For a side-by-side feature comparison of the two models, see [Essence vs Expression](/getting-started/models). For ABI / version pinning across SDKs, see [Compatibility](/getting-started/compatibility). For SDK downloads and pre-built wheels, see [releases.bithuman.ai](https://releases.bithuman.ai).

## What ships in 2.3

2.3.0 is the first **split-wheel** release: the Python library
(`pip install bithuman`) and the CLI binary (`pip install bithuman-cli`
or `brew install bithuman-product/bithuman/bithuman-cli`) are now
separate packages. Pre-2.3 PyPI bundled both — 2.2.x with the bundled
CLI is still on PyPI and works, but consider it legacy; pin to 2.3+
for new projects.

| Platform | CLI binary | Python wheel | Swift SDK | Kotlin SDK |
|---|---|---|---|---|
| **macOS arm64 (M-series)** | ✅ Homebrew + `bithuman-cli` wheel | ✅ `bithuman` (3.10–3.14) | ✅ SwiftPM | — |
| **macOS x86_64 (Intel)** | ⚠️ Pending | ⚠️ Pending (1.x was last) | — | — |
| **Linux x86_64** | ✅ Tarball + `bithuman-cli` wheel | ✅ `bithuman` (manylinux) | — | — |
| **Linux aarch64** | ✅ Tarball + `bithuman-cli` wheel | ✅ `bithuman` (manylinux) | — | — |
| **Windows** | ⚠️ Not shipping (use WSL2) | ⚠️ Not shipping (1.9.0 was last) | — | — |
| **iOS / iPadOS** | — | — | ✅ SwiftPM | — |
| **Android** | — | — | — | ✅ Maven Central `ai.bithuman:sdk` |

✅ = published artifact, install commands in [CLI](/getting-started/cli)
and the SDK pages. ⚠️ Pending = on the 2.x roadmap, not currently
shipping; the [compatibility matrix](/getting-started/compatibility)
calls out the 1.x escape hatch for those targets.

## Essence

The default avatar model. Runs on virtually every supported platform — the right choice for mobile, edge, and any deployment without a discrete GPU.

| Host | Status | Notes |
|---|---|---|
| **Apple M-series Mac** | ✅ Real-time, large memory headroom | Any Apple Silicon (arm64) |
| **iPhone 17 Pro+** | ✅ Real-time, smallest memory footprint | iOS 26 |
| **iPad Pro M4+** | ✅ Real-time | Pairs comfortably with an on-device LLM |
| **Android (`arm64-v8a`)** | ✅ Real-time | Snapdragon 8 Gen 2+, Android 10+ |
| **Linux x86_64 / aarch64** | ✅ Real-time | Python SDK, modern CPU + 4 GB RAM |
| **Intel Mac** | ⚠️ Pending in 2.3 | Use 1.x wheel or run via Linux x86_64 |
| **Windows x86_64** | ⚠️ Not shipping in 2.3 | Use WSL2 today; native wheels on the roadmap |
| **Raspberry Pi 4B / 5** | ⚠️ Near real-time | Adequate for kiosks at modest FPS |
| **Apple Watch / wearables** | ❌ Not supported | Insufficient memory |

All hosts produce identical frames — your device decision is about form factor, memory, and latency budget, not visual quality.

## Expression

Heavier high-fidelity model. Runs on Apple Silicon on-device (demo apps) or on NVIDIA GPUs server-side.

| Host | Status | Notes |
|---|---|---|
| **Mac M3+ (arm64)** | ✅ On-device | Demo app target |
| **iPad Pro M4+** | ✅ On-device | Sized for 16 GB+ devices |
| **iPhone 17 Pro+** | ❌ Not supported | Exceeds iOS per-app memory budget. Use Essence on iPhone. |
| **Android** | ❌ Not supported | Use Essence. |
| **Linux + NVIDIA GPU** | ✅ Server | 8 GB+ VRAM via [Docker container](/guides/deployment) |
| **Mac Intel / Linux CPU / Windows** | ❌ Not supported | Requires Apple Silicon or NVIDIA GPU |
| **Raspberry Pi** | ❌ Not supported | Use Essence |

If you're deploying to iPhone today, choose **Essence**. The iPhone reference app is built around Essence and stays well inside Apple's per-app memory cap.

## Avatar resolutions

Resolution interacts with both model and host:

| Resolution | Best for |
|---|---|
| **384×384** | Mobile and edge — the default sweet spot |
| **512×512** | Mac and iPad Pro — comfortable on M-series |
| **1280×720** | Desktop and cloud streaming — default for the CLI and LiveKit plugin |

Frames are delivered at 1280×720 by every SDK; smaller avatars are letterboxed/pillarboxed into that frame.

## Quick host-picker

- **Mobile consumer app** → iPhone or iPad → Essence at 384×384 via the [Swift SDK](/sdks/swift) or [Flutter plugin](/integrations/flutter).
- **Mac desktop app (arm64)** → either model. Expression for dynamic faces; Essence for lighter footprint and gesture triggers.
- **Android consumer app** → Essence via the [Kotlin SDK](/sdks/kotlin).
- **Single-board edge** (Raspberry Pi, mini-PC) → Essence via `pip install bithuman`.
- **GPU server** → Expression via the [self-hosted GPU container](/guides/deployment).
- **No infrastructure** → [LiveKit Cloud Plugin](/guides/deployment). Either model.
- **Windows / Intel Mac dev box today** → run via WSL2 / Linux x86_64 wheel, or pin to the 1.x Python SDK per the [skew policy](/getting-started/compatibility#skew-policy).

For full deployment scenarios with device, model, and network combinations together, see [Deployment](/guides/deployment).
