#!/usr/bin/env bash
# =============================================================================
# validate-release.sh — completeness + sanity check for a published `bithuman`
#                        PyPI release, across the whole target matrix.
#
# WHY THIS EXISTS (motivating incident):
#   Releases 1.12.0 through 1.17.3 silently shipped ONLY:
#       - cp311 wheels for Linux (manylinux_2_28 x86_64 + aarch64)
#       - cp313 wheel for macOS arm64
#   Every other interpreter (cp39 / cp310 / cp312, all macOS non-3.13, etc.)
#   404'd on a plain `pip install bithuman` for the affected Python. No sdist
#   exists (intentional), so a missing wheel == an uninstallable package for
#   that interpreter, with zero signal at publish time. This script makes that
#   class of gap a hard, loud, non-zero-exit failure.
#
# SINGLE SOURCE OF TRUTH:
#   The EXPECTED_PYTAGS / EXPECTED_PLATFORMS config block below is THE matrix.
#   When macOS Intel (macosx_*_x86_64), Windows, or a new Python minor lands,
#   edit ONLY that block — everything else derives from it.
#
# USAGE:
#   scripts/validate-release.sh [VERSION]
#       VERSION   bithuman version to validate. Default: latest on PyPI.
#
# EXIT CODES:
#   0  all phases passed
#   1  Phase 1 coverage gap (a required {pytag}x{platform} wheel is missing)
#   2  Phase 2 install failure (a locally-available Python could not install /
#      import the package)
#   3  Phase 3 example smoke failure
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# CONFIG BLOCK — THE SINGLE SOURCE OF TRUTH. Edit here when the matrix changes.
# -----------------------------------------------------------------------------

# Python minors that MUST have a wheel. (pytag form: cp39 == Python 3.9)
EXPECTED_PYTAGS=(cp39 cp310 cp311 cp312 cp313)

# Platform tags that MUST be present for EACH pytag above.
# A wheel's platform tag is matched as a SUBSTRING (PyPI bakes the macOS
# deployment target into the tag, e.g. macosx_26_0_arm64), so we list the
# stable, version-independent fragment here.
#
# Currently shipping:
EXPECTED_PLATFORMS=(
  "macosx_*_arm64"            # macOS Apple Silicon
  "manylinux_2_28_x86_64"     # Linux x86_64
  "manylinux_2_28_aarch64"    # Linux aarch64
)
# NOT YET SHIPPING — uncomment as each target's wheels start publishing:
#   "macosx_*_x86_64"         # macOS Intel  (being added separately)
#   "win_amd64"               # Windows x86_64
#   "win_arm64"               # Windows arm64

# Map pytag -> the X.Y string `uv` understands.
pytag_to_xy() {
  case "$1" in
    cp39)  echo "3.9"  ;;
    cp310) echo "3.10" ;;
    cp311) echo "3.11" ;;
    cp312) echo "3.12" ;;
    cp313) echo "3.13" ;;
    cp314) echo "3.14" ;;
    *)     echo "" ;;
  esac
}

# Public-repo Examples root (read-only; we only smoke-test imports).
# Derived from this script's location — it lives in scripts/ at the repo
# root, so the examples are one level up. Override with the
# BITHUMAN_EXAMPLES_REPO env var when running the script from outside a
# checkout (e.g. against a separate clone).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLES_REPO="${BITHUMAN_EXAMPLES_REPO:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# -----------------------------------------------------------------------------
# Internals
# -----------------------------------------------------------------------------
PKG="bithuman"
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/validate-release.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

banner() {
  printf '\n'
  printf '=%.0s' {1..78}; printf '\n'
  printf '  %s\n' "$1"
  printf '=%.0s' {1..78}; printf '\n'
}

section() { printf '\n--- %s ---\n' "$1"; }

# Resolve version (arg or PyPI latest).
RESOLVED_JSON="$WORKDIR/pypi.json"
if ! curl -fsS "https://pypi.org/pypi/${PKG}/json" -o "$RESOLVED_JSON"; then
  echo "FATAL: could not reach PyPI JSON API for ${PKG}" >&2
  exit 2
fi

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["info"]["version"])' "$RESOLVED_JSON")"
fi

banner "bithuman release validation — version ${VERSION}"
echo "PyPI:      https://pypi.org/project/${PKG}/${VERSION}/"
echo "Workdir:   ${WORKDIR}"
echo "Matrix:    ${#EXPECTED_PYTAGS[@]} pytags x ${#EXPECTED_PLATFORMS[@]} platforms = $(( ${#EXPECTED_PYTAGS[@]} * ${#EXPECTED_PLATFORMS[@]} )) required wheels"

# Pull the filename list for this exact version.
WHEEL_LIST="$WORKDIR/wheels.txt"
python3 - "$RESOLVED_JSON" "$VERSION" > "$WHEEL_LIST" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
ver = sys.argv[2]
files = data.get("releases", {}).get(ver, [])
for f in sorted(x["filename"] for x in files):
    print(f)
PY

if [[ ! -s "$WHEEL_LIST" ]]; then
  echo "FATAL: version ${VERSION} has NO files published on PyPI." >&2
  exit 1
fi

# =============================================================================
# PHASE 1 — COVERAGE
# =============================================================================
banner "PHASE 1 — wheel coverage"
echo "Published files for ${VERSION}:"
sed 's/^/  /' "$WHEEL_LIST"

# Glob-match helper: does any published filename contain pytag AND match the
# platform fragment (which may contain a '*' wildcard for the macOS target)?
wheel_present() {
  local pytag="$1" plat="$2" line
  while IFS= read -r line; do
    [[ "$line" == *.whl ]] || continue
    [[ "$line" == *"-${pytag}-"* ]] || continue
    # shellcheck disable=SC2053
    if [[ "$line" == *${plat}.whl ]]; then
      return 0
    fi
  done < "$WHEEL_LIST"
  return 1
}

section "PASS / MISS matrix"
printf '  %-8s %-26s %s\n' "PYTAG" "PLATFORM" "RESULT"
printf '  %-8s %-26s %s\n' "-----" "--------" "------"

COVERAGE_MISSES=0
for pytag in "${EXPECTED_PYTAGS[@]}"; do
  for plat in "${EXPECTED_PLATFORMS[@]}"; do
    if wheel_present "$pytag" "$plat"; then
      printf '  %-8s %-26s PASS\n' "$pytag" "$plat"
    else
      printf '  %-8s %-26s *** MISS ***\n' "$pytag" "$plat"
      COVERAGE_MISSES=$(( COVERAGE_MISSES + 1 ))
    fi
  done
done

if (( COVERAGE_MISSES > 0 )); then
  echo
  echo "PHASE 1 RESULT: FAIL — ${COVERAGE_MISSES} required wheel(s) missing."
  echo "This is exactly the 1.12.0–1.17.3 regression class (silent partial"
  echo "interpreter coverage). Affected interpreters cannot 'pip install ${PKG}'."
else
  echo
  echo "PHASE 1 RESULT: PASS — all $(( ${#EXPECTED_PYTAGS[@]} * ${#EXPECTED_PLATFORMS[@]} )) required wheels present."
fi

# =============================================================================
# PHASE 2 — INSTALLABILITY (local, uv venvs only — never system/conda Python)
# =============================================================================
banner "PHASE 2 — installability (isolated uv venvs)"

if ! command -v uv >/dev/null 2>&1; then
  echo "uv not found on PATH — cannot run Phase 2. Treating all as SKIPPED."
fi

INSTALL_FAILURES=0
INSTALL_OK=0
INSTALL_SKIPPED=0
SUMMARY_PHASE2=()

# A venv we can reuse for Phase 3 (first successful install).
PHASE3_VENV=""
PHASE3_XY=""

for pytag in "${EXPECTED_PYTAGS[@]}"; do
  XY="$(pytag_to_xy "$pytag")"
  if [[ -z "$XY" ]]; then
    echo "  ${pytag}: no X.Y mapping — SKIPPED"
    SUMMARY_PHASE2+=("${pytag}: SKIPPED (no version mapping)")
    INSTALL_SKIPPED=$(( INSTALL_SKIPPED + 1 ))
    continue
  fi

  section "Python ${XY} (${pytag})"

  if ! command -v uv >/dev/null 2>&1; then
    echo "  uv unavailable — SKIPPED"
    SUMMARY_PHASE2+=("${pytag} (py${XY}): SKIPPED (no uv)")
    INSTALL_SKIPPED=$(( INSTALL_SKIPPED + 1 ))
    continue
  fi

  VENV="$WORKDIR/venv-${pytag}"
  # `uv venv --python X.Y` only uses an already-obtainable interpreter when we
  # forbid downloads; if not present locally we SKIP (don't fail) per spec.
  if ! UV_PYTHON_DOWNLOADS=never uv venv --python "$XY" "$VENV" >/dev/null 2>&1; then
    echo "  Python ${XY} not locally obtainable via uv — SKIPPED"
    SUMMARY_PHASE2+=("${pytag} (py${XY}): SKIPPED (interpreter not local)")
    INSTALL_SKIPPED=$(( INSTALL_SKIPPED + 1 ))
    continue
  fi
  echo "  venv created: ${VENV}"

  if ! uv pip install --python "$VENV/bin/python" "${PKG}==${VERSION}" >/dev/null 2>&1; then
    echo "  *** pip install ${PKG}==${VERSION} FAILED on Python ${XY} ***"
    SUMMARY_PHASE2+=("${pytag} (py${XY}): FAIL (install)")
    INSTALL_FAILURES=$(( INSTALL_FAILURES + 1 ))
    continue
  fi
  echo "  installed ${PKG}==${VERSION}"

  # Import + API-surface smoke (mirrors build-wheel-in-container.sh smoke test).
  if BITHUMAN_UNMETERED=1 "$VENV/bin/python" - <<'PY'
import bithuman
from bithuman import Avatar          # core class must import
from bithuman import AsyncBithuman   # async runtime entrypoint
from bithuman import AudioChunk, VideoFrame, VideoControl
print(f"OK: bithuman {bithuman.__version__} ABI={getattr(bithuman,'__abi_version__','?')}")
print("API surface OK: Avatar / AsyncBithuman / AudioChunk / VideoFrame / VideoControl")
PY
  then
    echo "  smoke: PASS"
    SUMMARY_PHASE2+=("${pytag} (py${XY}): PASS")
    INSTALL_OK=$(( INSTALL_OK + 1 ))
    if [[ -z "$PHASE3_VENV" ]]; then
      PHASE3_VENV="$VENV"
      PHASE3_XY="$XY"
    fi
  else
    echo "  *** import / API-surface smoke FAILED on Python ${XY} ***"
    SUMMARY_PHASE2+=("${pytag} (py${XY}): FAIL (smoke)")
    INSTALL_FAILURES=$(( INSTALL_FAILURES + 1 ))
  fi
done

echo
echo "PHASE 2 RESULT: ${INSTALL_OK} PASS / ${INSTALL_FAILURES} FAIL / ${INSTALL_SKIPPED} SKIPPED"

# =============================================================================
# PHASE 3 — EXAMPLE SMOKE (imports only; no network / auth / model files)
# =============================================================================
banner "PHASE 3 — vanilla example smoke"

PHASE3_STATUS="SKIPPED"
EXAMPLE_USED=""

if [[ -z "$PHASE3_VENV" ]]; then
  echo "No installed venv available from Phase 2 — SKIPPED."
else
  # Simplest local Essence example: quickstart/local-avatar.py — minimal deps
  # (bithuman + opencv-python-headless), no LiveKit/OpenAI stack.
  EX_DIR="${EXAMPLES_REPO}/Examples/quickstart"
  EX_FILE="${EX_DIR}/local-avatar.py"
  REQ_MINIMAL=(opencv-python-headless)   # bithuman already installed in venv

  if [[ ! -f "$EX_FILE" ]]; then
    # Fallback to the local-essence quickstart if the layout differs.
    EX_DIR="${EXAMPLES_REPO}/Examples/python/local-essence"
    EX_FILE="${EX_DIR}/quickstart.py"
  fi

  if [[ ! -f "$EX_FILE" ]]; then
    echo "Could not locate a simple local example under ${EXAMPLES_REPO} — SKIPPED."
  else
    echo "Example:    ${EX_FILE}"
    echo "Venv:       ${PHASE3_VENV} (Python ${PHASE3_XY})"
    echo "Exercising: install minimal deps + resolve the example's imports"
    echo "            (NO model file / NO API secret / NO network calls)"

    if uv pip install --python "$PHASE3_VENV/bin/python" "${REQ_MINIMAL[@]}" >/dev/null 2>&1; then
      echo "  installed minimal example deps: ${REQ_MINIMAL[*]}"
    else
      echo "  WARNING: could not install ${REQ_MINIMAL[*]} — attempting import check anyway"
    fi

    # The example calls argparse + AsyncBithuman.create() which needs a model
    # file & auth at *runtime*; we never reach that. We only assert that every
    # top-level import the example performs resolves in the installed wheel +
    # its declared deps. Python compiles the whole module on import, so we
    # exec the import lines extracted from the example.
    if EX_FILE="$EX_FILE" BITHUMAN_UNMETERED=1 "$PHASE3_VENV/bin/python" - <<'PY'
import ast, importlib, os, sys

ex = os.environ["EX_FILE"]
src = open(ex).read()
tree = ast.parse(src, ex)

mods = set()
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        for a in node.names:
            mods.add(a.name.split(".")[0])
    elif isinstance(node, ast.ImportFrom):
        if node.module and node.level == 0:
            mods.add(node.module.split(".")[0])

# Stdlib / always-present — not part of the wheel contract.
ignore = {"argparse", "asyncio", "os", "threading", "sys", "ast",
          "importlib", "json", "time", "pathlib", "typing"}
checked, failed = [], []
for m in sorted(mods - ignore):
    try:
        importlib.import_module(m)
        checked.append(m)
    except Exception as e:  # noqa: BLE001
        failed.append(f"{m} ({e.__class__.__name__}: {e})")

print(f"example: {os.path.basename(ex)}")
print(f"imports resolved: {', '.join(checked) if checked else '(none)'}")
if failed:
    print(f"imports FAILED: {'; '.join(failed)}")
    sys.exit(1)
print("EXAMPLE IMPORT SMOKE: PASS")
PY
    then
      PHASE3_STATUS="PASS"
      EXAMPLE_USED="$EX_FILE"
      echo "PHASE 3 RESULT: PASS"
    else
      PHASE3_STATUS="FAIL"
      EXAMPLE_USED="$EX_FILE"
      echo "PHASE 3 RESULT: FAIL — example imports do not resolve against the wheel"
    fi
  fi
fi

# =============================================================================
# FINAL SUMMARY
# =============================================================================
banner "SUMMARY — bithuman ${VERSION}"

echo "Phase 1 (coverage):"
if (( COVERAGE_MISSES > 0 )); then
  echo "  FAIL — ${COVERAGE_MISSES} required wheel(s) MISSING (see matrix above)"
else
  echo "  PASS — full ${#EXPECTED_PYTAGS[@]}x${#EXPECTED_PLATFORMS[@]} wheel matrix present"
fi

echo "Phase 2 (installability):"
echo "  ${INSTALL_OK} PASS / ${INSTALL_FAILURES} FAIL / ${INSTALL_SKIPPED} SKIPPED"
for line in "${SUMMARY_PHASE2[@]:-}"; do
  [[ -n "$line" ]] && echo "    - $line"
done

echo "Phase 3 (example smoke):"
echo "  ${PHASE3_STATUS}${EXAMPLE_USED:+ — $EXAMPLE_USED}"

# Exit code precedence: coverage > install > example.
EXIT=0
if (( COVERAGE_MISSES > 0 )); then
  EXIT=1
elif (( INSTALL_FAILURES > 0 )); then
  EXIT=2
elif [[ "$PHASE3_STATUS" == "FAIL" ]]; then
  EXIT=3
fi

echo
echo "OVERALL: $( ((EXIT==0)) && echo 'PASS' || echo "FAIL (exit ${EXIT})" )"
exit "$EXIT"
