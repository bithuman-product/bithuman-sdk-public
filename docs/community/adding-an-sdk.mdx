---
title: Adding an SDK binding
description: How to ship a new language SDK on top of the bitHuman engine.
---

A bitHuman SDK is a thin language binding over **libessence**, the
portable C ABI that drives audio-in/frames-out. Python and Rust are the
canonical examples — both wrap the same C entry points, ship the same
parity test corpus, and publish to their language's package index.

This page shows the path. The Python and Rust SDKs are the worked
examples to copy from.

## The C ABI surface

`libessence` is a small C library with a stable ABI. Every SDK calls the
same entry points:

```c
// load a fixture (model) once per process
be_handle_t be_fixture_load(const char* imx_path);
void        be_fixture_get_info(be_handle_t h, be_info_t* out);
void        be_fixture_close(be_handle_t h);

// per-runtime: cheap, many per fixture
be_runtime_t be_runtime_create(be_handle_t fixture);
int          be_runtime_tick_compose(be_runtime_t rt,
                                     const int16_t* pcm, size_t n_samples,
                                     uint8_t* bgr_out, size_t bgr_bytes);
void         be_runtime_close(be_runtime_t rt);
```

A binding's job: marshal language-native audio buffers in, expose the
BGR frame as the language-native image type (numpy array, `Vec<u8>`,
`UIImage`, etc.), and surface errors as the language's idiomatic error
type.

See `cpp/bindings/include/libessence.h` in the engine repo for the
full ABI.

## The parity contract

Every binding ships the **same** test corpus: a 122-tick speech clip,
checked against a recorded `cluster_idx` sequence. If your binding can
load the test `.imx`, feed the same PCM in, and produce the same
`cluster_idx` array, it's correct.

Reference harness: `cpp/bindings/validation/harness.py` in the engine
repo. The contract is a single assertion:

```python
assert produced_cluster_idx == golden_cluster_idx  # 0/122 mismatches
```

Python passes today. Rust passes today. A new binding is "done" when
this assertion holds in CI.

## Repo structure

```
bithuman-sdk/
  cpp/                     # libessence + C ABI (the engine)
  sdks/
    python/                # canonical example
    rust/                  # canonical example
    <your-language>/       # your binding goes here
      Cargo.toml | setup.py | Package.swift | ...
      src/                 # binding code
      tests/parity.<ext>   # runs the parity corpus
      README.md
```

Mirror Python's layout for dynamic languages; mirror Rust's layout for
compiled ones.

## Build system

The binding needs to link against `libessence.a` (static) or
`libessence.so` / `.dylib` / `.dll` (dynamic). CMake builds it from
`cpp/`. Add your binding's build step to:

- Local dev: `scripts/build-<lang>.sh`
- Release matrix: `.github/workflows/release.yml` — one job per target
  triple (linux-x86_64, linux-aarch64, macos-arm64, etc.)

Python uses scikit-build-core; Rust uses `cc` + `bindgen` via `build.rs`.
Copy whichever pattern matches your toolchain.

## Parity tests in CI

```yaml
# .github/workflows/release.yml
- name: Run parity harness (<lang>)
  run: |
    cd sdks/<lang>
    <run your parity script>
    # exits non-zero on any mismatch
```

The job must fail the release if parity drifts. This is the gate.

## Publishing

| Language | Index | How |
|---|---|---|
| Python | PyPI | `cibuildwheel` matrix → `twine upload` |
| Rust | crates.io | `cargo publish` (after tag push) |
| Swift | SwiftPM | binary xcframework on the public repo + `Package.swift` |
| Kotlin | Maven Central | Gradle publish plugin (see `kotlin/` for the worked config) |
| JS/TS | npm | `npm publish --access public` |

Tag the engine repo with `libessence-v<X.Y.Z>`. Release CI fans out to
each binding's publish step.

## Checklist

- [ ] Binding builds against `libessence.a` on all supported triples
- [ ] Parity corpus passes (0/122 mismatches)
- [ ] `README.md` shows install + 10-line hello-world
- [ ] CI matrix entry runs the parity harness
- [ ] Publish step wired to the language's package index
- [ ] Doc page added under `docs/sdks/<lang>.mdx`

Open an RFC first if the binding introduces a new public concept
(streaming model, callback shape, etc.) — see
[RFC process](/community/rfc-process).
