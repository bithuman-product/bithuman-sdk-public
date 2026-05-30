# CompareLLM

Load each on-device LLM choice (the iOS vs macOS model split) and run a
fixed avatar-style prompt set, so the split can be sanity-checked from a
Mac before shipping.

This tool depends only on the upstream OSS packages that bitHumanKit's
`LLMClient` is built on (`mlx-swift-lm`, `swift-transformers`,
`swift-huggingface`) — no bitHuman binary framework — and uses the same
load/generate path, so what you measure here is what ships.

## Run

```bash
cd Examples/swift/compare-llm
swift run -c release CompareLLM            # both models, all prompts
swift run -c release CompareLLM --model ios    # iOS choice (Gemma 3 1B QAT)
swift run -c release CompareLLM --model macos  # macOS choice (Gemma 3n E2B)
```

Models download into `~/.cache/huggingface/hub` on first run. Reports
load time, generation time, and tokens/sec per model.

## Requires

- macOS 26+ (Tahoe), Apple Silicon
- ~3–5 GB free disk for the model weights
