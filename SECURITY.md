# Security Policy

## Reporting a vulnerability

If you think you've found a security issue in `bitHumanKit` or any of the artifacts published from this repo, **please don't file a public GitHub issue**. Public reports give attackers a head start before we can ship a fix.

Email **security@bithuman.ai** with:

- A description of the issue and what an attacker could do with it.
- Steps to reproduce, ideally with a minimal sample project.
- The SDK version (`Package.resolved` entry or release tag) and the OS / Xcode version where you saw it.
- Your name or handle if you'd like credit in the advisory.

## What to expect

- We aim to acknowledge every report **within 48 hours** (usually much sooner during the work week).
- We'll keep you posted as we triage, reproduce, and fix.
- Once a fix ships, we'll publish a GitHub Security Advisory crediting you (unless you'd rather stay anonymous) and CVE if applicable.
- We support **coordinated disclosure** — we'll agree on a public disclosure date with you before we publish.

## Scope

In scope:

- The `bitHumanKit.xcframework` binaries attached to [Releases](https://github.com/bithuman-product/bithuman-sdk-public/releases).
- The published Python wheel.
- Examples and snippets in this repo.
- `docs.bithuman.ai` content served from `docs/`.

Out of scope (please report to **support@bithuman.ai** instead):

- Issues in third-party dependencies that are statically linked into the framework (we'll forward upstream where appropriate).
- Social-engineering or physical-access attacks against bitHuman staff or infrastructure.
- Findings that require a jailbroken device or disabled OS protections.

## PGP / encrypted reports

If you'd like to encrypt your report, email security@bithuman.ai first and we'll exchange a key. We don't publish a static PGP key on the repo because keys rotate.

Thanks for helping keep bitHuman users safe.
