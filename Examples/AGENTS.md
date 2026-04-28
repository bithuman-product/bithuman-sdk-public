# bitHuman Examples — repo guide

A collection of runnable examples that wire the [bithuman](https://pypi.org/project/bithuman/) Python SDK, the [bitHumanKit](https://github.com/bithuman-product/bithuman-kit-public) Swift SDK, and the Platform REST API into end-to-end stacks. One canonical example per (model × surface) combination — minimal business logic, so the avatar integration stays readable.

## What is bitHuman?

Real-time avatar animation. Drives face images or pre-built `.imx` bundles into lifelike talking avatars with audio-locked lip sync at 25 FPS. Used for voice agents with faces, tutors, support bots, NPCs, accessibility UIs.

## Two models, three surfaces

- **Models:** `Essence` (CPU, pre-rendered `.imx`, gestures, no idle timeout) and `Expression` (GPU server-side or Apple Silicon M3+ on-device, dynamic face from any image).
- **Surfaces:** bitHuman Cloud (REST API + LiveKit plugin), self-hosted server (Python SDK on CPU; Docker container on NVIDIA GPU), on-device Apple Silicon (Swift Package + Homebrew CLI).
- **Auth:** `BITHUMAN_API_SECRET` env var for Python / REST / LiveKit; `BITHUMAN_API_KEY` for the Swift SDK. Get one at https://www.bithuman.ai/#developer.

## Layout

```
api/                                  Platform REST API scripts
essence-cloud/                        Essence (CPU) via bitHuman Cloud
essence-selfhosted/                   Essence (CPU) with local .imx file
expression-cloud/                     Expression (GPU) via bitHuman Cloud
expression-selfhosted/                Expression (GPU) on your Linux + NVIDIA box
expression-selfhosted-livekit-cloud/  ↑ same, but WebRTC via LiveKit Cloud
apple-expression/                     Expression on-device on Apple Silicon (M3+)
integrations/
  java/                               Java WebSocket client
  macos-offline/                      Fully offline macOS (Ollama + Apple Speech)
  nextjs-ui/                          Drop-in Next.js LiveKit frontend
  web-ui/                             Gradio + FastRTC browser UI
bithuman-docs/                        Mintlify source for docs.bithuman.ai
```

## Conventions

- Every stack ships a `.env.example` + `docker-compose.yml`. Stacks that have a standalone, no-LiveKit entry point also ship a `quickstart.py`. Stacks that route through LiveKit (cloud + self-hosted GPU) ship `agent.py` instead. Keep filenames stable — the docs link to them.
- READMEs should stay short and task-focused: prerequisites, one-command run, a short config table, troubleshooting only for failures users actually hit. Don't duplicate content across siblings — link to the canonical README.
- Use `BITHUMAN_API_SECRET` (new style), not `BITHUMAN_RUNTIME_TOKEN`. The token flow is still supported upstream but is legacy here.
- Don't commit large binaries. Sample audio (`speech.wav`, ~700 KB) is fine; rendered MP4s are not.

## Authoritative docs

- Product / API / deployment: [docs.bithuman.ai](https://docs.bithuman.ai) (source in [`bithuman-docs/`](bithuman-docs/))
- Python SDK surface: [pypi.org/project/bithuman](https://pypi.org/project/bithuman/) (the SDK source repo is private; internal links from PyPI point at docs.bithuman.ai)
- Swift SDK: [github.com/bithuman-product/bithuman-kit-public](https://github.com/bithuman-product/bithuman-kit-public) — binary Swift Package (XCFramework). Source is private; the public package wraps the released framework via `binaryTarget`.
- Swift reference apps (Mac, iPad, iPhone): [github.com/bithuman-product/bithuman-apps](https://github.com/bithuman-product/bithuman-apps)
- bithuman-cli (Homebrew): `brew tap bithuman-product/bithuman && brew install bithuman-cli`
- REST API: [`docs.bithuman.ai/api-reference/openapi.yaml`](https://docs.bithuman.ai/api-reference/openapi.yaml)
- Compact AI-agent ingest: [`docs.bithuman.ai/llms.txt`](https://docs.bithuman.ai/llms.txt) · Comprehensive: [`docs.bithuman.ai/llms-full.txt`](https://docs.bithuman.ai/llms-full.txt)

Do not re-document the full API or SDK surface inside this repo. Link out.

## For AI coding agents

If you are an AI agent (Claude, Cursor, Copilot, etc.) wiring bitHuman into a user's codebase:

1. Decide the surface from what the user is shipping — Mac/iPad/iPhone app → Swift SDK; web app or backend → Cloud LiveKit plugin or REST; on-prem privacy/edge → self-hosted Python (Essence) or Docker (Expression).
2. Tell the user to grab an API secret at https://www.bithuman.ai/#developer; set `BITHUMAN_API_SECRET` (or `BITHUMAN_API_KEY` for Swift).
3. Pick the model: Essence (`.imx`, CPU, gestures) or Expression (any face, GPU/M3+). See [docs.bithuman.ai/getting-started/models](https://docs.bithuman.ai/getting-started/models).
4. Copy the vanilla example for that surface from this repo — every surface has a working folder under the layout above.
5. Read [llms-full.txt](https://docs.bithuman.ai/llms-full.txt) for the full API surface in one fetch.
