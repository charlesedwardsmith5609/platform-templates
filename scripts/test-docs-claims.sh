#!/usr/bin/env bash
# Greps docs for claims the review found wrong or unverified.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VA="${ROOT}/docs/vendor-access.md"
TM="${ROOT}/docs/ci-threat-model.md"
WI="${ROOT}/docs/agent-workload-isolation.md"
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
has() { grep -qiE -- "$1" "$2"; }
lacks() { ! grep -qiE -- "$1" "$2"; }

check "no 'can do nothing'" lacks 'can do nothing' "${VA}"
check "no secrecy framing (not a password)" lacks 'not a password' "${VA}"
check "no public repository warning" lacks 'public repository' "${VA}"
check "externalid is non-secret" has 'non-secret' "${VA}"
check "externalid unique per customer" has 'unique per customer' "${VA}"
check "GetCallerIdentity noted" has 'GetCallerIdentity' "${VA}"
check "resource policies noted" has 'resource polic' "${VA}"
fork_marked() { grep -iE 'fork pull request.*(starts|runs)' "${TM}" | grep -qi 'needs verification'; }
check "fork PR sentence needs verification" fork_marked
check "LiteLLM sentence no longer claims chain used deletion to hide an edit" \
  lacks 'used to hide an edit' "${TM}"
check "namespace conditional on create_namespace" has 'create_namespace' "${WI}"
check "specific secret ARNs" has 'specific secret ARN' "${TM}"
check "replication not configured here" has 'does not configure replication' "${TM}"
check "metadata options not set here" has 'does not set instance metadata' "${TM}"
check "secrets read path cites secrets-injection.yml:135" has 'secrets-injection\.yml:135' "${TM}"
check "secrets read path cites iam.tf" has 'terraform/modules/api-gateway/iam\.tf:3[0-9]' "${TM}"
check "secrets read path cites variables.tf" has 'terraform/modules/api-gateway/variables\.tf:75' "${TM}"
check "GuardDuty not configured" has 'does not configure GuardDuty' "${TM}"
check "emulator placeholder keys named" has 'examples/floci-aws/main\.tf:44' "${TM}"
check "replication cites AWS announcement URL" has 'about-aws/whats-new/2026/11/secrets-manager-cross-account' "${TM}"
check "replication paragraph cites the AWS page" lacks 'not re-checked offline \(assumption\)\. Secrets|announcement \(not re-checked offline; assumption\)' "${TM}"

if [[ "${fail}" -gt 0 ]]; then
  echo "docs claims: ${fail} failed" >&2
  exit 1
fi
echo "docs claims: all passed"
