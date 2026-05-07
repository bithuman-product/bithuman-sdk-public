# bitHuman Examples — repo guide

A collection of runnable examples that wire the [bithuman](https://pypi.org/project/bithuman/) Python SDK, the [bitHumanKit](https://github.com/bithuman-product/bithuman-sdk-public) Swift SDK, and the Platform REST API into end-to-end stacks. One canonical example per (model x surface) combination — minimal business logic, so the avatar integration stays readable.

## What is bitHuman?

Real-time avatar animation. Drives face images or pre-built `.imx` bundles into lifelike talking avatars with audio-locked lip sync at 25 FPS. Used for voice agents with faces, tutors, support bots, NPCs, accessibility UIs.

## Two models, three surfaces

- **Models:** `Essence` (CPU, pre-rendered `.imx`, gestures, no idle timeout) and `Expression` (GPU server-side or Apple Silicon M3+ on-device, dynamic face from any image).
- **Surfaces:** bitHuman Cloud (REST API + LiveKit plugin), self-hosted server (Python SDK on CPU; Docker container on NVIDIA GPU), on-device Apple Silicon (Swift Package + Homebrew CLI).
- **Auth:** `BITHUMAN_API_SECRET` env var for Python / REST / LiveKit; `BITHUMAN_API_KEY` for the Swift SDK. Get one at https://www.bithuman.ai/#developer.

## Layout

```
quickstart/                           Try bitHuman in under 2 minutes
cloud/
  essence-livekit/                    Essence (CPU) via bitHuman Cloud + LiveKit
  expression-livekit/                 Expression (GPU) via bitHuman Cloud + LiveKit
  rest-api/                           Platform REST API scripts (any language)
self-hosted/
  essence-cpu/                        Essence (CPU) with local .imx file
  expression-gpu/                     Expression on your Linux + NVIDIA box
  expression-gpu-livekit-cloud/       Same, but WebRTC via LiveKit Cloud
  expression-apple/                   Expression on-device on Apple Silicon (M3+)
swift/                                Native Apple apps (Mac/iPad/iPhone) — links to docs
integrations/
  java-websocket/                     Java WebSocket client
  offline-mac/                        Fully offline macOS (Ollama + Apple Speech)
  nextjs-ui/                          Drop-in Next.js LiveKit frontend
  gradio-web/                         Gradio + FastRTC browser UI
../docs/                              Mintlify source for docs.bithuman.ai
```

## Conventions

- Every stack ships a `.env.example` + `docker-compose.yml`. Stacks that have a standalone, no-LiveKit entry point also ship a `quickstart.py`. Stacks that route through LiveKit (cloud + self-hosted GPU) ship `agent.py` instead. Keep filenames stable — the docs link to them.
- READMEs should stay short and task-focused: prerequisites, one-command run, a short config table, troubleshooting only for failures users actually hit. Don't duplicate content across siblings — link to the canonical README.
- Use `BITHUMAN_API_SECRET` (new style), not `BITHUMAN_RUNTIME_TOKEN`. The token flow is still supported upstream but is legacy here.
- Don't commit large binaries. Sample audio (`speech.wav`, ~700 KB) is fine; rendered MP4s are not.

## Authoritative docs

- Product / API / deployment: [docs.bithuman.ai](https://docs.bithuman.ai) (source in [`../docs/`](../docs/))
- Python SDK surface: [pypi.org/project/bithuman](https://pypi.org/project/bithuman/) (the SDK source repo is private; internal links from PyPI point at docs.bithuman.ai)
- Swift SDK: [github.com/bithuman-product/bithuman-sdk-public](https://github.com/bithuman-product/bithuman-sdk-public) — binary Swift Package (XCFramework). Source is private; the public package wraps the released framework via `binaryTarget`.
- Swift reference apps (Mac, iPad, iPhone): private repo (`bithuman-apps`). Only compiled binaries ship publicly — see [docs.bithuman.ai/swift-sdk/quickstart](https://docs.bithuman.ai/swift-sdk/quickstart) for the latest download.
- bithuman-cli (Homebrew): `brew tap bithuman-product/bithuman && brew install bithuman-cli`
- REST API: [`docs.bithuman.ai/api-reference/openapi.yaml`](https://docs.bithuman.ai/api-reference/openapi.yaml)
- Compact AI-agent ingest: [`docs.bithuman.ai/llms.txt`](https://docs.bithuman.ai/llms.txt) · Comprehensive: [`docs.bithuman.ai/llms-full.txt`](https://docs.bithuman.ai/llms-full.txt)

Do not re-document the full API or SDK surface inside this repo. Link out.

## For AI coding agents

If you are an AI agent (Claude, Cursor, Copilot, etc.) wiring bitHuman into a user's codebase:

### Decision tree (which example folder to copy)

| User says they want... | Recommend | Why |
|---|---|---|
| "Mac / iPad / iPhone app, runs locally, privacy" | [Swift SDK quickstart](https://docs.bithuman.ai/swift-sdk/quickstart) | All inference on-device. M3+ Mac / M4+ iPad Pro / iPhone 16 Pro+. |
| "No setup, fastest demo on a Mac" | `brew install bithuman-cli` → `bithuman-cli video`. See [/swift-sdk/cli](https://docs.bithuman.ai/swift-sdk/cli). | No code. Voice + avatar window in 30 seconds. |
| "Web app, fastest cloud demo" | [`cloud/essence-livekit/`](cloud/essence-livekit/) | LiveKit plugin, no GPU, no model files. |
| "Web app with custom face from a photo" | [`cloud/expression-livekit/`](cloud/expression-livekit/) | Same plugin, `model="expression"` + `avatar_image`. |
| "Kiosk / 24/7 display / edge box" | [`self-hosted/essence-cpu/`](self-hosted/essence-cpu/) | CPU only, no idle timeout, gestures supported. |
| "On-prem with NVIDIA GPU, custom faces" | [`self-hosted/expression-gpu/`](self-hosted/expression-gpu/) | Docker container, dynamic face from any image. |
| "Just calling the REST API from any language" | [`cloud/rest-api/`](cloud/rest-api/) + [/api-reference/overview](https://docs.bithuman.ai/api-reference/overview) | `curl https://api.bithuman.ai/v1/...`. |
| "100% offline Mac (no cloud agent)" | [`integrations/offline-mac/`](integrations/offline-mac/) | Essence + Ollama + Apple Speech. M2+ enough. |

### Onboarding script (use this verbatim with the user)

1. **Get an API key**: tell the user to sign in at https://www.bithuman.ai → Developer → API Keys. Set `BITHUMAN_API_SECRET` (Python/REST/LiveKit) or `BITHUMAN_API_KEY` (Swift SDK). Audio-only Swift mode skips this entirely. See [/getting-started/authentication](https://docs.bithuman.ai/getting-started/authentication).
2. **Pick the model**: Essence (`.imx`, CPU, gestures) or Expression (any face, GPU/M3+). See [/getting-started/models](https://docs.bithuman.ai/getting-started/models).
3. **Copy the example folder** from the decision tree above. Every folder ships a `.env.example` + a one-command run path.
4. **Verify pricing fits**: see [/getting-started/pricing](https://docs.bithuman.ai/getting-started/pricing). Free tier is 99 credits/month (~50 minutes of cloud Essence).

### Machine-readable surfaces

- **OpenAPI**: [`docs.bithuman.ai/api-reference/openapi.yaml`](https://docs.bithuman.ai/api-reference/openapi.yaml) — full REST contract; import into code generation or LLM tool-use chains.
- **llms.txt**: [`docs.bithuman.ai/llms.txt`](https://docs.bithuman.ai/llms.txt) — curated index for LLM consumption.
- **llms-full.txt**: [`docs.bithuman.ai/llms-full.txt`](https://docs.bithuman.ai/llms-full.txt) — every doc page concatenated. Single fetch covers the whole surface.
- **Repo guide**: this file.

### What NOT to do

- Don't add `bithuman-kit.git` (private) as an SPM dependency. Use `bithuman-sdk-public.git`.
- Don't try to clone the source for the Swift SDK or the reference apps (`bithuman-apps`) — both are intentionally private. Suggest the public binary package or the prebuilt reference app linked from the docs.
- Don't hardcode API keys in source. Use env vars; for production Swift apps, fetch from Keychain or bundle into the `.app` Info.plist via a build script (see [authentication docs](https://docs.bithuman.ai/getting-started/authentication)).
- Don't pin the Swift SDK below 0.8.1 — earlier versions had a different (now-replaced) auth model.
