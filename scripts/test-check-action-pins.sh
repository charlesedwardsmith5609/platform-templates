#!/usr/bin/env bash
# Unit tests for check-action-pins.sh using good/bad fixture workflow trees.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${ROOT}/scripts/check-action-pins.sh"
FIXTURES="${ROOT}/scripts/testdata/action-pins"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

pass=0
fail=0

assert_exit() {
  local name="$1"
  local expected="$2"
  local root="$3"
  set +e
  out="$("${CHECK}" "${root}" 2>&1)"
  ec=$?
  set -e
  if [[ "${ec}" -eq "${expected}" ]]; then
    echo "PASS ${name}"
    pass=$((pass + 1))
  else
    echo "FAIL ${name}: expected exit ${expected}, got ${ec}" >&2
    echo "${out}" >&2
    fail=$((fail + 1))
  fi
}

# --- good: SHA-pinned third-party + local reusable workflow ---
good_root="${TMP}/good"
mkdir -p "${good_root}/.github/workflows"
cp "${FIXTURES}/good/"*.yml "${good_root}/.github/workflows/"
assert_exit "good fixtures accept SHA pins and local uses" 0 "${good_root}"

# --- bad: tag-only pin ---
bad_root="${TMP}/bad"
mkdir -p "${bad_root}/.github/workflows"
cp "${FIXTURES}/bad/"*.yml "${bad_root}/.github/workflows/"
assert_exit "bad fixtures reject tag-only uses" 1 "${bad_root}"

if [[ "${fail}" -gt 0 ]]; then
  echo "check-action-pins tests: ${fail} failed, ${pass} passed" >&2
  exit 1
fi
echo "check-action-pins tests: ${pass} passed"
