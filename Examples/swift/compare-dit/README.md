# CompareDiT

> ⚠️ **Preview / deferred.** This example depends on the standalone
> `Expression` Layer-1 product, which is **not yet published** (only the
> `bitHumanKit` umbrella ships today). It will not resolve against the current
> release. It builds once the `Expression` XCFramework is published — until then
> use [bench-essence](../bench-essence/) (Essence) via `bitHumanKit`.

Render a WAV through the bitHuman avatar engine to a lip-synced MP4, to
A/B fp16 vs int4 DiT quality side by side. Targets the Layer-1
**Expression** avatar engine directly (the `Expression` product) — no
STT/LLM/TTS umbrella.

## Run

```bash
cd Examples/swift/compare-dit
swift build -c release --product CompareDiT

# fp16 (default)
.build/release/CompareDiT --model expression.imx --audio ref.wav --output fp16.mp4

# int4 (quantized DiT)
FH_QUANTIZE_DIT=int4 .build/release/CompareDiT \
  --model expression.imx --audio ref.wav --output int4.mp4

# stack them
ffmpeg -i fp16.mp4 -i int4.mp4 \
  -filter_complex "[0:v][1:v]hstack" -map 0:a side-by-side.mp4
```

Flags: `--model/-m`, `--audio/-a`, `--output/-o`, `--identity/-i`,
`--driver/-d`, `--quality/-q {medium|high}`, `--putback`.

## Requires

- macOS 26+ (Tahoe), Apple Silicon M3+ (Expression is unsupported on
  M1/M2 — raises `ExpressionModelNotSupported`)
- An `.imx` Expression model and a reference WAV
