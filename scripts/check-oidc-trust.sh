#!/usr/bin/env bash
# Fail when a trust policy trusts token.actions.githubusercontent.com and its
# sub condition is missing or contains a wildcard (*).
# Scans .tf, .json, and .hcl. Skips .git, .terraform, and testdata.
# Usage: scripts/check-oidc-trust.sh [root]
set -euo pipefail

ROOT="${1:-}"
if [[ -z "${ROOT}" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

host="token.actions.githubusercontent.com"
failures=0
checked=0

while IFS= read -r file; do
  [[ -n "${file}" ]] || continue
  rel="${file#"${ROOT}"/}"
  case "${rel}" in
    testdata/* | */testdata/*) continue ;;
  esac
  if ! grep -q "${host}" "${file}"; then
    continue
  fi
  checked=$((checked + 1))
  subs=()
  while IFS= read -r value; do
    [[ -n "${value}" ]] || continue
    subs+=("${value}")
  done < <(grep -E '^[[:space:]]*[^#[:space:]].*sub"[[:space:]]*[:=][[:space:]]*"[^"]*"' "${file}" \
    | sed -E 's/.*sub"[[:space:]]*[:=][[:space:]]*"([^"]*)".*/\1/' || true)

  if [[ ${#subs[@]} -eq 0 ]]; then
    echo "${file}: trusts ${host} but has no sub condition" >&2
    failures=$((failures + 1))
    continue
  fi
  for value in "${subs[@]}"; do
    if [[ -z "${value}" || "${value}" == "*" || "${value}" == *'*'* ]]; then
      echo "${file}: wildcard or empty sub for ${host}: ${value}" >&2
      failures=$((failures + 1))
    fi
  done
done < <(find "${ROOT}" -type f \
  ! -path '*/.git/*' ! -path '*/.terraform/*' \
  \( -name '*.tf' -o -name '*.json' -o -name '*.hcl' \) -print)

if [[ "${checked}" -eq 0 ]]; then
  echo "oidc trust check: no file trusts ${host}" >&2
  exit 1
fi

if [[ "${failures}" -gt 0 ]]; then
  echo "oidc trust check failed: ${failures} finding(s) in ${checked} file(s)" >&2
  exit 1
fi

echo "oidc trust check passed (${checked} file(s) trust ${host} with a specific sub)"
