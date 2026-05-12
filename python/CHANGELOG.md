# Changelog

All notable changes to the `bithuman` package are documented here.

## [1.11.3] - 2026-05-12

### Fixed
- **Dynamics .imx files no longer crash on load when built without similarity matrices.** The `VideoGraph` now returns a zero matrix instead of raising `FileNotFoundError` when similarity data between video clips is missing. This allows dynamics-enabled models to load with hard-cut transitions between gestures and talking video, without requiring the expensive ~20 min filler-frame generation pipeline.
- **Peak memory display on macOS now shows correct units.** `resource.getrusage` returns bytes on macOS vs KB on Linux; the CLI now handles both correctly (was showing ~1.9 PB instead of ~1.9 GB).
- **Token refresh log noise reduced.** The per-minute "Token refreshed successfully" message moved from DEBUG to TRACE level so it no longer clutters stdout in long-running scripts.

## [1.10.6] - 2026-04-21

### Fixed
- **`bithuman generate` and `bithuman stream` now read `$BITHUMAN_API_SECRET`.** Previously these two CLI subcommands required `$BITHUMAN_API_KEY` — every other surface (`bithuman demo`, the Python SDK, the docs) used `BITHUMAN_API_SECRET`, so users who set the documented env var hit a hard "API key required" error on the Essence video-render path. Both commands now fall back to `$BITHUMAN_API_SECRET` first, then the legacy `$BITHUMAN_API_KEY` for backwards compatibility.

### Changed
- **`bithuman pack` now defaults to 512×512.** Expression renderers ship at 384 / 448 / 512; the packer's default was 384 ("realtime-safe"), but on current M3+ hardware 512 at `quality="medium"` runs at 1.14× realtime with visibly sharper output. Bundles packed without an explicit `--resolution` flag now produce 512×512 output. Pass `--resolution 384` explicitly for the performance-optimized variant on lower-power devices.
- **SDK README restructured** — Essence (cross-platform, default) leads with its own Quick Start; Expression on macOS M3+ is called out as an optional, clearly-fenced section. Which runtime ships by default and which is host-specific is now unmistakable.

## [1.10.5] - 2026-04-21

### Added
- **`bithuman demo` now works with zero arguments.** `--model` is optional — when omitted, the CLI auto-downloads a pre-packed demo `.imx` (~3.7 GB, one-time) from R2 to `~/.cache/bithuman/models/` and runs against it. First run: `pip install bithuman && bithuman demo`.
- **`--identity` accepts URLs.** Pass `--identity https://…/portrait.jpg` and the CLI downloads + caches the portrait under `~/.cache/bithuman/identities/` before handing it to the runtime. Works with any bitHuman agent portrait (see the Halo gallery at docs.bithuman.ai).

## [1.10.4] - 2026-04-21

### Added
- **`bithuman demo` CLI** — zero-friction hello-world. `pip install bithuman` gives you `bithuman demo --model expression.imx` and writes a lip-synced `demo.mp4` in one command, using a bundled sample audio clip. No git clone or example script required. Pass `--audio`, `--identity`, `--output` to customize.
- Bundled `bithuman/assets/demo_sample.wav` — 700 KB of test speech the `demo` subcommand uses when no `--audio` is passed.

### Fixed
- **Friendlier missing-dependency errors.** `bithuman demo` pre-flights on ffmpeg, the model file, the API secret, and opencv-python before spinning up any ML state. Previously these failures landed as cryptic subprocess / import errors mid-run.

## [1.10.3] - 2026-04-21

### Fixed
- **Daemon build now produces the MLX Metal shader library** by switching from `swift build` to `xcodebuild`. Plain SwiftPM doesn't compile MLX's `.metal` shaders into a `.metallib`; only Xcode's build system does. Without the metallib the daemon crashed at runtime on first MLX eval. (1.10.1 and 1.10.2 both tagged but neither shipped to PyPI — the release workflow's `verify` gate caught the missing metallib and failed-closed.)

## [1.10.2] - 2026-04-21

### Added
- **Lifecycle parity between Essence + Expression runtimes.** The same `create() → start() → push_audio/flush/run → stop()` idiom now works for both model types:
    - `SwiftExpressionRuntime.start()` — no-op added for API symmetry; accepts and ignores the same keyword args as `AsyncBithuman.start()`.
    - `SwiftExpressionRuntime.stop()` — alias for `shutdown()`.
    - `AsyncBithuman.shutdown()` — alias for `stop()`.
    - `AsyncBithuman.set_identity()` — raises `NotImplementedError` with a clear message pointing at `bithuman pack --reference-face`, so Expression-shaped code fails loud and fast on Essence models instead of silently doing nothing.

### Fixed
- **Wheel was missing the MLX Metal shader library.** 1.10.0 shipped the `bithuman-expression-daemon` binary without its `Resources/default.metallib`, so any Expression session crashed on first MLX eval with `Failed to load the default metallib`, surfaced to Python as `Daemon exited without a ready event`. 1.10.2 bundles the metallib alongside the daemon.
- **Wheel bundled a pre-identity daemon.** The release workflow was pinned to Swift SDK `v0.4.0`, which predates the `identity=` IPC keys. The bundled daemon is now `v0.6.1`, which accepts `identity_image` / `identity_pre_encoded` in the `load` header and the new `set_identity` op.

Users who pinned `bithuman==1.10.0` should upgrade to `1.10.2`. No API changes. (1.10.1 was tagged but its release workflow caught a missing metallib locator and failed-closed before the wheel uploaded — no 1.10.1 ever shipped.)

## [1.10.0] - 2026-04-20

### Added
- **`identity=` on `AsyncBithuman.create()`** (Expression models). Picks the avatar face the model animates, separately from the model weights:
    - `identity=None` (default) — use the default reference face baked into the `.imx` bundle.
    - `identity="portrait.jpg"` (or `.png`) — encode on load via the face encoder shipping in the bundle (~300 ms on M3+). One model bundle, unlimited agent faces.
    - `identity="cached.npy"` — pre-encoded reference face from `encode-ref-latent` or a previous swap (~instant).
- **`runtime.set_identity(path)`** — runtime swap without reloading the model. Same path forms as the `identity=` parameter. In-flight audio remains associated with the OLD identity; call `interrupt()` first if you want a clean cut.
- Together these let developers ship one ~3.5 GB model bundle and parameterize avatar identity per-agent, instead of packing one bundle per face.

### Daemon IPC (companion swift v0.6.1)
- `load` op accepts optional `identity_image` or `identity_pre_encoded` strings.
- New `set_identity` IPC op.

## [1.9.0] - 2026-04-20

### Added
- **`quality` parameter on `AsyncBithuman.create()`** (Expression models). `"medium"` (default) = realtime-safe, ~1.8× realtime at 384×384. `"high"` = ~2× slower render for visibly crisper output — recommended for offline video generation. Raises `ValueError` for other strings; ignored for Essence models.
- **Per-chunk frame-dimension handling in `swift_expression/runtime.py`**. The Python unpacker honors `frame_width` / `frame_height` from the daemon's chunk header instead of assuming the ready-event frame size. Required for any Expression model packed with a non-384 face renderer — the model bundle now round-trips correctly at 384×384, 448×448, or 512×512.

### Changed
- **`bithuman pack` CLI: user-friendly argument names.** ML-jargon flags were renamed with old names kept as hidden aliases so existing build scripts keep working:

  | Old flag | New flag | What it is |
  |----------|----------|------------|
  | `--dit` | `--animator` | Animator weights (`.safetensors`) |
  | `--wav2vec` | `--speech-encoder` | Speech encoder weights (`.safetensors`) |
  | `--vae-encoder` | `--face-encoder` | Face encoder weights (`.safetensors`) |
  | `--ane-decoder` | `--face-renderer` | Face renderer (`.mlpackage`) |
  | `--ref-latent` | `--reference-face` | Reference face file (`.npy`) |
  | `--pos-conv` | `--speech-filter` | Optional pre-computed speech filter (`.npy`) |

### Fixed
- **Cython `annotation_typing` left on** caused `Optional[str] = None` parameters to become hard runtime type checks. `agent_code=None` from `start_token_refresh` triggered `Argument 'agent_code' has incorrect type (expected str, got bool)` on every Essence model. Disabled the directive in `setup.py`.
- **`lib/generator.py:add_video` missed the BytesIO widening** that landed on `VideoData.__init__` in 1.8.5. The IMX v2 fast path still failed with `Argument 'video_data_path' has incorrect type (expected str, got _io.BytesIO)` on every dynamics-enabled agent. Widened the annotation to `Union[str, io.BytesIO]`.
- **`_unpack_chunk` reshape crash** when the Expression daemon emitted 384×384 frames but the ready event advertised 512×512. The chunk header carries the actual dims; honor those and fall back to the ready-event size only when the header is silent.

### Documentation
- README: new Expression section covering the `quality` preset, realtime-factor table, and packing recipes at multiple resolutions. User-facing language throughout replaces ML jargon (DiT → animator, wav2vec → speech encoder, VAE → face encoder/decoder, ANE → face renderer, latent → encoded face).
- Docstrings across `runtime_async.py`, `swift_expression/runtime.py`, and `swift_expression/_binary.py` scrubbed of internal ML-architecture references in public-facing text.

## [1.8.5] - 2026-04-20

### Fixed
- **Dynamics video loading crash**: Cython compilation of `video_data.py` and `generator.py` enforced strict `str` type on `video_data_path`, rejecting `BytesIO` objects used by the IMX fast path. This caused all agents with dynamics videos to crash on model load with `Argument 'video_data_path' has incorrect type (expected str, got _io.BytesIO)`. Fixed by widening the type annotation to `Union[str, io.BytesIO]`.

## [1.8.4] - 2026-04-17

### Security
- **Wheel hardening**: `auth.py`, `lib/generator.py`, `engine/video_reader.py`, `engine/patch_reader.py`, `engine/video_data.py`, `runtime.py`, and `runtime_async.py` now ship as Cython-compiled `.so` only — no plaintext `.py` in the wheel. This is light obfuscation (key constants are still recoverable via `strings` on the `.so`), not real protection; the long-term fix remains server-authoritative token validation.
- Source repo (`bithuman-product/bithuman-python-sdk`) is now private; the compiled wheel is the only public distribution channel.

### Changed
- No runtime behavior changes. Install flow (`pip install bithuman`) and public API surface (`AsyncBithuman`, `Bithuman`, CLI, `swift_expression`) are bit-exact identical to 1.8.3.

## [1.8.3] - 2026-04-17

### Fixed
- Release workflow no longer injects an empty `MACOSX_DEPLOYMENT_TARGET` env var on non-arm64 matrix jobs. 1.8.2 broke the macOS Intel build with `packaging.version.InvalidVersion: Invalid version:`. Moved the arm64-only override into `[[tool.cibuildwheel.overrides]]` in pyproject.toml so the arch scoping is declarative.

## [1.8.2] - 2026-04-17

### Fixed
- macOS arm64 wheel now declares MACOSX_DEPLOYMENT_TARGET=14.0 to match the bundled `bithuman-expression-daemon` binary (AVFoundation + MLX pin to macOS 14+). Previously `delocate-wheel` rejected the 14.0-linked daemon inside a `macosx_11_0` wheel. Intel + Linux + Windows wheels keep their default targets.

## [1.8.1] - 2026-04-17

### Fixed
- Release workflow now selects Xcode 16 before building the `bithuman-expression-daemon` binary so the macOS arm64 runner has Swift 6.0 (the runner's default is Swift 5.10, which can't open the SDK's `Package.swift`). 1.8.0 tag never shipped to PyPI because of this; 1.8.1 is the first successful release cut from the standalone repo.

## [1.8.0] - 2026-04-17

First release cut from the standalone `bithuman-python-sdk` repo.
Previously the package shipped from an internal monorepo; it has been moved into a dedicated repo.

### Added
- **Expression model support on macOS Apple Silicon (M3+, M3+ recommended)**:
  - `bithuman.swift_expression.SwiftExpressionRuntime` binds to the native Swift SDK at [`bithuman-expression-swift`](https://github.com/bithuman-product/bithuman-expression-swift) via the new `bithuman-expression-daemon` binary. The macOS arm64 wheel ships the daemon pre-built (built against `bithuman-expression-swift` v0.4.0 by default — override via the `BITHUMAN_EXPRESSION_SWIFT_REF` repo variable).
  - `AsyncBithuman.create()` auto-detects `.imx` files whose manifest stamps `model_type: "expression"` and dispatches transparently — same public API (`push_audio`, `flush`, `run`, `shutdown`) for both Essence and Expression models.
  - On Linux, Windows, and Intel macOS the new `ExpressionModelNotSupported` exception is raised at `create()` with install guidance.
- **`bithuman pack` CLI subcommand**: writes an IMX v2 container that bundles the four Expression weight artifacts (DiT, Wav2Vec2, VAE encoder, ANE decoder) plus the baked reference latent plus a stamped manifest into a single `.imx` — the Swift SDK's public `Bithuman.create(modelPath:)` consumes it directly.
- **`ExpressionModelNotSupported`** typed exception, exported from the package root alongside the existing error hierarchy.

### Performance
- Python ↔ daemon IPC benches at **1512 FPS sustained throughput**, **0.66 ms amortized per 512×512 frame**, **0.04 ms per 1 s audio push** — under 2 % of the 40 ms real-time frame budget.

### Changed
- Repository moved into a dedicated repo at [`bithuman-product/bithuman-python-sdk`](https://github.com/bithuman-product/bithuman-python-sdk). PyPI wheel name + install commands are unchanged.
- Release tag pattern changed from `bithuman-v*` to `v*` (matching the new standalone-repo workflow at `.github/workflows/release.yml`).

### Tests
- 155 passing, 14 skipped (integration tests that need bundled model artifacts).

## [1.7.4] - 2026-02-27

### Fixed
- **Lip-sync resolution mismatch**: `get_blended_frame()` now resizes lip-sync composited frames to the native MP4 resolution. Previously, lip-sync frames were output at the lower H5 `frame_wh` (e.g. 535x720), while action clips played at native resolution (e.g. 832x1120), causing a visible quality jump between talking and gestures.

## [1.7.3] - 2026-02-19

### Fixed
- **OOM in essence containers**: `PRELOAD_TO_MEMORY` no longer caches decoded frames for SingleActionVideos. Only LoopingVideos (ping-pong) need frame caching. Agents with many videos (e.g. 13 videos × ~400 MB = 5+ GB) previously exceeded the 4 GB container memory limit.

### Reverted
- **Ping-pong re-encoding removed** (from 1.7.1/1.7.2): The load-time re-encoding of ping-pong videos caused laggy playback because FrameMeta indices serve dual purpose (video frame position + patch lookup). Ping-pong LoopingVideos now use the original frame cache approach, caching only looping videos (~465 MB) instead of all videos.

### Added
- **`MP4VideoReader.from_bytes()`**: New classmethod to create a reader from in-memory H.264 bytes without a file path (retained from 1.7.1).

## [1.7.0] - 2026-02-15

### Added
- New `bithuman gadget` command: converts full-size IMX v2 models (85-137 MB) to compact 240x240 square gadget models (20-28 MB) for browser/embedded avatar display.
  - Re-clusters audio from 183 to 64 lip-sync clusters via KMeans
  - Face-aware square cropping centered on median face position
  - Full face crop patches with browser-matching 8px mask edge feathering for seamless blending
  - Configurable resolution (`--max-resolution`), cluster count (`--clusters`), and WebP quality (`--quality`)

## [1.6.7] - 2026-02-10

### Fixed
- Memory leak: `BlobReader.close()` now releases `_preloaded` data, `_decoded_cache`, and `_offsets` (hundreds of MB per session with PRELOAD_TO_MEMORY).
- Memory leak: `PatchReader.close()` now releases `_cached_base` and nulls sub-readers.
- Memory leak: `MP4VideoReader.close()` now clears `_frame_cache`, `_current_frame`, and `_decoder`.
- Memory leak: `Bithuman.cleanup()` now closes all video/avatar readers, clears graph caches, and calls `gc.collect()`.
- Memory leak: `AsyncBithuman.stop()` now drains the frame queue and calls parent `cleanup()`.
- ONNX session cache eviction now explicitly deletes evicted sessions.
- `VideoCapture` usage now checks `isOpened()` before reading properties.

## [1.6.4] - 2026-02-10

### Fixed
- `CONVERT_THREADS=0` caused `ValueError: max_workers must be greater than 0` in ThreadPoolExecutor during model conversion. Now falls back to auto-detect (80% of CPU cores).
- `CONVERT_THREADS=""` (empty string) caused `ValueError` during model conversion. Now treated the same as unset.

### Added
- macOS startup check: detects `opencv-python` (full) installed alongside `av` (PyAV) and prints a fix suggestion to switch to `opencv-python-headless`.

## [1.6.3] - 2026-02-10

### Fixed
- `/videos` endpoint on the stream server returned `500 Internal Server Error` (`AttributeError: 'str' object has no attribute 'name'`). The code iterated over dict keys instead of dict values.

## [1.6.2] - 2026-02-10

### Fixed
- Model conversion (`bithuman convert`) and auto-conversion at runtime failed with `TypeError: an integer is required`. The `stream.thread_count` was set to `None` (PyAV requires an integer) when `CONVERT_THREADS` was unset or `0`.

## [1.6.1] - 2026-02-09

### Changed
- Upgraded `cibuildwheel` from v2.22 to v3.3 for Python 3.14 wheel builds.

## [1.6.0] - 2026-02-09

### Added
- Initial public release with full CLI toolset (`generate`, `stream`, `speak`, `action`, `convert`, `validate`, `info`, `list-videos`).
- Async and sync Python APIs (`AsyncBithuman`, `Bithuman`).
- IMX v2 optimized model format.
- LiveKit Agent integration.
- Cross-platform wheels (Linux x86/ARM, macOS Intel/ARM, Windows).
