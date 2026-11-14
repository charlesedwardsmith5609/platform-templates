#!/usr/bin/env bash
# Static checks on vendor-trust configuration that terraform test does not cover.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD="${ROOT}/terraform/modules/vendor-trust"
EX="${ROOT}/examples/vendor-trust"
fail=0

check() { # name, command...
  local name="$1"
  shift
  if "$@"; then
    echo "PASS ${name}"
  else
    echo "FAIL ${name}" >&2
    fail=$((fail + 1))
  fi
}
version_floor() { grep -qE 'required_version[[:space:]]*=[[:space:]]*">= 1\.7(\.0)?"' "$1"; }
# One h1: entry per locked platform; linux_amd64 and darwin_arm64 need two.
lock_platforms() { [[ "$(grep -c '"h1:' "$1")" -ge 2 ]]; }
no_placeholder() { ! grep -qiE 'replace-me|example-external-id|changeme' "$@"; }
uses_require_match() { grep -q 'check-oidc-trust.sh.*--require-match' "$1"; }

check "module required_version >= 1.7" version_floor "${MOD}/versions.tf"
check "example required_version >= 1.7" version_floor "${EX}/main.tf"
check "module lock file has linux_amd64 and darwin_arm64 hashes" lock_platforms "${MOD}/.terraform.lock.hcl"
check "example lock file has linux_amd64 and darwin_arm64 hashes" lock_platforms "${EX}/.terraform.lock.hcl"
check "module README uses no placeholder external_id" no_placeholder "${MOD}/README.md"
check "example uses no placeholder external_id" no_placeholder "${EX}/main.tf"
check "CI passes --require-match" uses_require_match "${ROOT}/.github/workflows/ci.yml"
check "Makefile passes --require-match" uses_require_match "${ROOT}/Makefile"

if [[ "${fail}" -gt 0 ]]; then
  echo "terraform config checks: ${fail} failed" >&2
  exit 1
fi
echo "terraform config checks: all passed"
