#!/usr/bin/env bash
# The bad fixtures must fail. The good fixture and this repo must pass.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${ROOT}/scripts/check-oidc-trust.sh"
FIXTURES="${ROOT}/scripts/testdata/oidc-trust"

pass=0
fail=0

assert_exit() {
  local name="$1"
  local expected="$2"
  local needle="$3"
  local target="$4"
  set +e
  out="$("${CHECK}" "${target}" 2>&1)"
  ec=$?
  set -e
  if [[ "${ec}" -eq "${expected}" ]] && grep -q "${needle}" <<<"${out}"; then
    echo "PASS ${name}"
    pass=$((pass + 1))
  else
    echo "FAIL ${name}: expected exit ${expected} and '${needle}', got ${ec}" >&2
    echo "${out}" >&2
    fail=$((fail + 1))
  fi
}

assert_exit "wildcard sub fails" 1 "wildcard or empty sub" "${FIXTURES}/bad-wildcard"
assert_exit "missing sub fails" 1 "no sub condition" "${FIXTURES}/bad-missing"
assert_exit "specific sub passes" 0 "oidc trust check passed" "${FIXTURES}/good"
assert_exit "repository example passes" 0 "oidc trust check passed" "${ROOT}"

if [[ "${fail}" -gt 0 ]]; then
  echo "check-oidc-trust tests: ${fail} failed, ${pass} passed" >&2
  exit 1
fi
echo "check-oidc-trust tests: ${pass} passed"
