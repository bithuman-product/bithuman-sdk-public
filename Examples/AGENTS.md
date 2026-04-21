# bitHuman Examples — repo guide

A collection of runnable examples that wire the [bithuman](https://pypi.org/project/bithuman/) Python SDK and the Platform API into end-to-end stacks. One canonical example per (model × deployment) combination — minimal business logic, so the avatar integration stays readable.

## What is bitHuman?

Real-time avatar animation. Drives face images or pre-built `.imx` bundles into lifelike talking avatars with audio-locked lip sync at 25 FPS. Used for voice agents with faces, tutors, support bots, NPCs, accessibility UIs.

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

- Each stack ships a `quickstart.py` (standalone), optionally an `agent.py` (LiveKit), a `docker-compose.yml`, and a `.env.example`. Keep those filenames stable — the docs link to them.
- READMEs should stay short and task-focused: prerequisites, one-command run, a short config table, troubleshooting only for failures users actually hit. Don't duplicate content across siblings — link to the canonical README.
- Use `BITHUMAN_API_SECRET` (new style), not `BITHUMAN_RUNTIME_TOKEN`. The token flow is still supported upstream but is legacy here.
- Don't commit large binaries. Sample audio (`speech.wav`, ~700 KB) is fine; rendered MP4s are not.

## Authoritative docs

- Product / API / deployment: [docs.bithuman.ai](https://docs.bithuman.ai) (source in [`bithuman-docs/`](bithuman-docs/))
- Python SDK surface: [pypi.org/project/bithuman](https://pypi.org/project/bithuman/) and the [SDK repo](https://github.com/bithuman-product/bithuman-python-sdk)
- REST API: [`docs.bithuman.ai/api-reference/openapi.yaml`](https://docs.bithuman.ai/api-reference/openapi.yaml)

Do not re-document the full API or SDK surface inside this repo. Link out.
