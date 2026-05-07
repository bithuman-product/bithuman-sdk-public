# Contributing

Thanks for taking the time to look at this. A quick orientation before you file an issue or open a PR.

## What this repo is

This is the **public binary distribution** of `bitHumanKit`. The Swift source for the framework itself is private. What ships here:

- `Package.swift` — a SwiftPM `binaryTarget` pointing at the `bitHumanKit.xcframework.zip` attached to each [GitHub Release](https://github.com/bithuman-product/bithuman-sdk-public/releases).
- `Examples/` — annotated sample apps and integration recipes.
- `docs/` — the source for [docs.bithuman.ai](https://docs.bithuman.ai) (Mintlify).
- `python/` — packaging metadata for the Python wheel publish.

Because the SDK source is closed, **most "the SDK does X wrong" reports cannot be fixed by a PR to this repo.** Read on for where to send what.

## Where to send issues

### File an issue here when…

- The `binaryTarget` checksum, URL, or version range in `Package.swift` is broken.
- A release artifact (the `.xcframework.zip`) is missing, corrupted, or won't notarize.
- Documentation under `docs/` is wrong, stale, or unclear.
- An example under `Examples/` doesn't build or behaves unexpectedly.
- The Python wheel (`python/`) packaging is broken.

For these, please use [Bug report](.github/ISSUE_TEMPLATE/bug_report.md) and include the SDK version, OS, Xcode version, and a minimal repro.

### Don't file an issue here for…

- **SDK runtime behavior** (lipsync drift, audio glitches, model loading, hardware gating, API design). The implementation is private. Please email **support@bithuman.ai** or post in our [Discord](https://discord.gg/ES953n7bPA) instead — your report still reaches the engineers, just through the right channel.
- **API key, billing, or credit issues** — email **support@bithuman.ai**.
- **Security vulnerabilities** — see [SECURITY.md](SECURITY.md). Please don't open a public issue.

## PRs we welcome

Pull requests are welcome for:

- `Examples/` — new sample apps, fixes to existing ones, integration recipes.
- `docs/` — typo fixes, clarifications, new guides, better diagrams.
- `README.md` and other repo metadata.

PRs that try to modify `Package.swift` versions or release artifacts will usually be closed — those are bumped by our release automation when a new framework build ships. If you think the package manifest itself has a real bug, open an issue first and we'll talk through it.

## Working on examples or docs

```sh
git clone https://github.com/bithuman-product/bithuman-sdk-public.git
cd bithuman-sdk-public

# Examples (Python)
cd Examples/<example-you-want>
# Follow the README in that directory

# Docs (Mintlify — requires Node 18+)
cd docs && npx mintlify@latest dev
```

Keep changes focused — one example or one doc page per PR is easiest to review. Match the surrounding tone (the docs lean conversational, not corporate). If you're adding a new example, please include a short `README.md` in its directory explaining what it demonstrates and what hardware it needs.

## Code of conduct

Be kind. Assume good intent. We'll do the same.
