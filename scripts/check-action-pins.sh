#!/usr/bin/env bash
# Fail if any third-party GitHub Actions `uses:` lacks a full 40-char commit SHA.
# Local reusable workflows / actions (./...) are allowed. docker:// refs are rejected.
set -euo pipefail

ROOT="${1:-}"
if [[ -z "${ROOT}" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

WORKFLOWS_DIR="${ROOT}/.github/workflows"
if [[ ! -d "${WORKFLOWS_DIR}" ]]; then
  echo "No .github/workflows directory at ${WORKFLOWS_DIR}" >&2
  exit 1
fi

sha_re='^[0-9a-f]{40}$'
failures=0
checked=0

shopt -s nullglob
files=("${WORKFLOWS_DIR}"/*.yml "${WORKFLOWS_DIR}"/*.yaml)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No workflow files under ${WORKFLOWS_DIR}" >&2
  exit 1
fi

for file in "${files[@]}"; do
  line_no=0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line_no=$((line_no + 1))
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    # Step or job uses: key only (ignore prose mentioning "uses:").
    if [[ ! "${line}" =~ ^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*([^[:space:]#]+) ]]; then
      continue
    fi

    ref="${BASH_REMATCH[1]}"
    ref="${ref%\"}"
    ref="${ref#\"}"
    ref="${ref%\'}"
    ref="${ref#\'}"

    if [[ "${ref}" == ./* ]]; then
      continue
    fi
    if [[ "${ref}" == docker://* ]]; then
      echo "${file}:${line_no}: docker:// actions are not SHA-pinnable here; use image digests instead: ${ref}" >&2
      failures=$((failures + 1))
      continue
    fi

    checked=$((checked + 1))
    if [[ ! "${ref}" =~ @([^@]+)$ ]]; then
      echo "${file}:${line_no}: missing @ref on uses: ${ref}" >&2
      failures=$((failures + 1))
      continue
    fi
    pin="${BASH_REMATCH[1]}"
    if [[ ! "${pin}" =~ ${sha_re} ]]; then
      echo "${file}:${line_no}: uses: must pin a 40-char commit SHA (got '${pin}'): ${ref}" >&2
      failures=$((failures + 1))
    fi
  done < "${file}"
done

if [[ "${failures}" -gt 0 ]]; then
  echo "action pin check failed: ${failures} unpinned third-party uses: (checked ${checked})" >&2
  exit 1
fi

echo "action pin check passed (${checked} third-party uses: SHA-pinned)"
