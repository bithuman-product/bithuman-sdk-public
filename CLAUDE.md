# bitHuman SDK -- Claude Code Instructions

## Project Overview

Public SDK repository for bitHuman, a real-time avatar animation platform. Audio in, lip-synced video out at 25 FPS. This repo contains the Swift SDK binary distribution (SwiftPM), Python SDK metadata, runnable examples for all platforms, and the docs.bithuman.ai source.

The Swift SDK source and Python SDK compiled internals are in private repos. This repo is the public surface for integration, examples, and documentation.

## Key Files to Read First

| File | What you learn |
|---|---|
| `AGENTS.md` | Full AI agent discovery guide (decision tree, API surface, patterns) |
| `README.md` | Human-facing overview, install instructions, quick start |
| `python/README.md` | Python SDK detailed docs (API surface, CLI, env vars, Expression) |
| `docs/llms.txt` | Machine-readable index of all documentation pages |
| `docs/api-reference/openapi.yaml` | OpenAPI 3.1 spec for the REST API |
| `Examples/AGENTS.md` | Examples-specific agent guide with decision tree |
| `Package.swift` | Swift SDK binary target and hardware requirements |

## Directory Structure

```
Package.swift           -- Swift SDK: SwiftPM binaryTarget (bitHumanKit.xcframework)
python/                 -- Python SDK: README, CHANGELOG, LICENSE (wheels on PyPI)
Examples/               -- Runnable examples for every integration path
  python/               -- 6 Python examples (cloud + local, Essence + Expression)
  swift/                -- 4 Swift examples (macOS, iOS, Essence playback)
  cli/                  -- Shell scripts for CLI tools
  rest-api/             -- curl and Python scripts for HTTP API
  integrations/         -- Next.js, Java, Gradio, offline Mac
  quickstart/           -- 2-minute try-it path
docs/                   -- docs.bithuman.ai source (Mintlify MDX)
  api-reference/        -- REST API docs + openapi.yaml
  getting-started/      -- Quickstart, models, auth, pricing, use cases
  deployment/           -- Avatar sessions, cloud plugin, self-hosted GPU
  swift-sdk/            -- Swift SDK guides (macOS, iOS, CLI, troubleshooting)
  examples/             -- Doc pages for each example category
  integrations/         -- Embed, webhooks, Flutter
  llms.txt              -- LLM-oriented doc index
  llms-full.txt         -- Full LLM-oriented doc content
```

## How to Run Examples

### Python examples

```bash
cd Examples/python/<example-dir>/
# Each directory has a README with setup instructions
# General pattern:
pip install bithuman --upgrade
export BITHUMAN_API_SECRET=your_secret
python main.py   # or agent.py, depending on the example
```

### Swift examples

Open the `.xcodeproj` or `Package.swift` in Xcode. Requires macOS 26+ (Tahoe) and Apple Silicon M3+.

### CLI examples

```bash
cd Examples/cli/
# Each .sh script is self-contained
bash render-video.sh
```

### REST API examples

```bash
cd Examples/rest-api/curl/
export BITHUMAN_API_SECRET=your_secret
bash validate.sh    # or any endpoint script
```

### Docs (local preview)

```bash
cd docs && npx mintlify@latest dev
# Requires Node 18+
```

## Code Conventions

- **Language**: All code, comments, and documentation in English.
- **Python**: Async-first (`AsyncBithuman` preferred over sync `Bithuman`). Use `os.environ` for secrets, never hardcode.
- **Swift**: Swift 6.0+, macOS 26.0+ / iOS 26.0+ minimum. Import `bitHumanKit`.
- **API keys**: Always via environment variables. Python/REST/CLI uses `BITHUMAN_API_SECRET`. Swift uses `BITHUMAN_API_KEY`.
- **Agent identifiers**: Use `agent_code` (e.g. `A91XMB7113`). Never use deprecated `figure_id`.
- **Examples**: Each example directory has its own README. Match the existing tone (conversational, not corporate).
- **Markdown**: Used for all docs. Code blocks with language tags. Tables for structured data.

## Testing Patterns

- No automated test suite in this public repo (SDK source is private).
- To validate examples: run them with a real API secret and a valid `.imx` model file.
- To validate docs: `cd docs && npx mintlify@latest dev` and check for build errors.
- To validate REST API calls: use the curl scripts in `Examples/rest-api/curl/` against `https://api.bithuman.ai`.
- Use `bithuman validate <path>` to check `.imx` model file integrity.
- Use `POST /v1/validate` to verify an API secret is valid.

## Key Technical Facts

- Python SDK: `pip install bithuman` -- wheels for Python 3.9-3.14, Linux/macOS/Windows.
- Swift SDK: Binary XCFramework via SwiftPM. All deps statically linked. Zero transitive dependencies.
- Hardware floor for Swift: macOS M3+, iPad Pro M4+, iPhone 16 Pro+ (A18 Pro).
- Expression on macOS auto-spawns `bithuman-expression-daemon` subprocess.
- Expression on unsupported hardware raises `ExpressionModelNotSupported` (not a crash).
- LiveKit plugin package: `pip install livekit-plugins-bithuman` or `pip install bithuman[agent]`.
- REST API base URL: `https://api.bithuman.ai`. Auth via `api-secret` header.
- Video output: 25 FPS, BGR uint8 numpy arrays (`frame.bgr_image`).
- Audio: int16 PCM, any sample rate (auto-resampled by SDK).

## What NOT to Do

- Do not reference or clone private repos (`bithuman-kit`, `bithuman-product/platform`).
- Do not hardcode API secrets in any file.
- Do not use `figure_id` (deprecated, returns 400).
- Do not pin Swift SDK below 0.8.1.
- Do not attempt to modify `Package.swift` versions (managed by release automation).
- Do not commit `.env` files, credentials, or API secrets.
