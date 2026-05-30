# BenchEssence

Apples-to-apples Essence runtime perf + correctness bench harness. The
Swift sibling of the Python `bench_essence.py`; both emit byte-identical
CSV column names and `meta.json` keys so cross-binding parity can be
diffed directly.

## Run

```bash
cd Examples/swift/bench-essence
swift run -c release BenchEssence \
  --fixture path/to/avatar.imx \
  --audio   path/to/16k_mono.wav \
  --frames 300 --warmup 50 \
  --output ./bench-out \
  [--reference ./reference-frames]
```

Output:

- `<output>/bench.csv` — one row per measured frame (wall_time_ms,
  cluster_idx, frame_sha256, optional PSNR)
- `<output>/meta.json` — summary metrics + host info + fixture sha256s

## Important: internal test seam

This harness calls `EssenceRuntime.generateFrameDetailedForBench`, an
**internal test seam** that surfaces per-frame `cluster_idx`. That symbol
is NOT part of the public `bitHumanKit` / `Bithuman` API — the published
binary only exposes rendered frames via the `frames()` AsyncStream.

As a result the full per-frame **correctness** path compiles only against
an internal build of the framework that exposes the seam. The perf-only
path (timings + RSS, no `cluster_idx`/PSNR) works against the public
binary. See the source header for the metric definitions and warm-up
protocol.

## Requires

- macOS 26+ (Tahoe), Apple Silicon
- A `.imx` Essence model and a 16 kHz mono int16 WAV (no resampling)
