---
title: Adding an integration
description: How to ship a Layer 4 integration that consumes the SDK.
---

An **integration** is code that *consumes* a bitHuman SDK to plug it
into a third-party framework — a LiveKit plugin, a Pipecat processor,
a LangChain tool, a Discord bot. It doesn't extend the engine; it wraps
it for a specific runtime.

This page is for Layer 4 contributors. SDK changes (new entry points,
new ABI surface) follow [Adding an SDK binding](/community/adding-an-sdk)
instead.

## Where integrations live

Integrations live **upstream**, in the framework's own repo. The
LiveKit pattern is the model:

```
livekit/agents/
  livekit-plugins/livekit-plugins-bithuman/   # upstream owns this
```

bitHuman maintains a **contract test** in this repo that verifies our
SDK exposes everything the upstream plugin uses. When upstream releases
a new version, the contract test catches breakage before users do.

## The contract test pattern

```
bithuman-sdk/
  integrations/
    <integration-name>/
      README.md             # what this integration is + upstream link
      contract_test.py      # asserts SDK surface the plugin imports
      compat.yaml           # known-compatible upstream versions
```

### `README.md`

One paragraph:
- What the integration is (e.g. "LiveKit Agents plugin for bitHuman avatars")
- Where it lives upstream (link to repo + package)
- Maintenance status (community / official / archived)
- Install command for the user

### `contract_test.py`

Imports the bits the upstream plugin uses and asserts they still exist
with the expected signatures. Example:

```python
# integrations/livekit-plugins-bithuman/contract_test.py
import inspect
from bithuman import AsyncBithuman

# The plugin calls .from_token() — assert it still exists
assert hasattr(AsyncBithuman, "from_token")
sig = inspect.signature(AsyncBithuman.from_token)
assert "api_secret" in sig.parameters
assert "model_path" in sig.parameters

# The plugin calls .push_audio() and .video_iterator() — assert signatures
rt = AsyncBithuman  # type-check shape, not a live instance
assert hasattr(rt, "push_audio")
assert hasattr(rt, "video_iterator")
```

Run in CI. Failures mean either:
1. The SDK broke a contract (revert or version-bump signal)
2. The upstream plugin needs to update its pin

### `compat.yaml`

```yaml
upstream_package: livekit-plugins-bithuman
upstream_repo: https://github.com/livekit/agents
known_compatible:
  - sdk: "2.3.x"
    plugin: ">=1.4.0,<2.0.0"
  - sdk: "2.2.x"
    plugin: ">=1.2.0,<1.4.0"
```

## Case study: livekit-plugins-bithuman

The integration is owned by LiveKit upstream. We ship the contract test
here.

When 2.3.0 changed the audio push API, the upstream plugin pinned to
`bithuman<2.3` to keep working. That blocked users from upgrading.

Two fixes ran in parallel:
1. **Upstream PR** to relax the pin: livekit/agents#5882 (open)
2. **Inline fallback** in `bithuman-cli`: `bithuman_cli._avatar_bridge`
   exposes the same shape the plugin needs, so `bithuman run` works
   today without waiting for the upstream merge

Once #5882 merges and a new `livekit-plugins-bithuman` release ships,
the inline bridge becomes redundant and is removed.

This is the recommended pattern: **don't block users on upstream**.
Ship an inline fallback in the CLI and remove it once upstream catches
up.

## Adding a new integration

1. Open an [RFC](/community/rfc-process) describing the integration and
   the contract surface
2. Add `integrations/<name>/` with README + contract test + compat.yaml
3. Add the contract test to CI (`make test-integrations` or similar)
4. Ship the integration in the upstream framework's repo
5. Add a doc page under `docs/integrations/<name>.mdx` linking users to
   install instructions

## Checklist

- [ ] RFC opened + accepted
- [ ] `integrations/<name>/README.md` written
- [ ] `contract_test.py` runs in CI and exits non-zero on drift
- [ ] `compat.yaml` lists at least one known-compatible upstream version
- [ ] Upstream PR open (or upstream release shipped)
- [ ] Doc page under `docs/integrations/` links to install instructions
- [ ] If upstream is blocked: inline fallback added to `bithuman-cli`
