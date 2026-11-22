#!/usr/bin/env bash
# Checks that every Dependabot update entry has a 7-day cooldown (default-days only for
# github-actions and terraform, which take no semver-* keys per the GitHub docs read 2026-11-21).
# Usage: bash scripts/test-dependabot-config.sh [path]   (default .github/dependabot.yml)
# With no path it also runs three fixture cases to prove the checker can fail.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# check_file FILE: exit 0 when valid; print reasons and exit 1 otherwise.
check_file() {
  awk '
    function finish() {
      if (eco == "") return
      n++
      if (!has_cool || days != "7") { printf "entry %d (%s): missing cooldown default-days: 7\n", n, eco; bad = 1 }
      if (semver) { printf "entry %d (%s): semver-* key not supported here\n", n, eco; bad = 1 }
    }
    /^[[:space:]]*-[[:space:]]*package-ecosystem:/ {
      finish(); eco = $0; sub(/.*package-ecosystem:[[:space:]]*/, "", eco); gsub(/["\047]/, "", eco)
      has_cool = 0; days = ""; semver = 0; incool = 0; next
    }
    /^[[:space:]]*cooldown:/ { has_cool = 1; incool = 1; next }
    incool && /^[[:space:]]*default-days:/ { d = $0; sub(/.*default-days:[[:space:]]*/, "", d); sub(/[[:space:]#].*/, "", d); days = d; next }
    /^[[:space:]]*semver-(major|minor|patch)-days:/ { if (eco == "github-actions" || eco == "terraform") semver = 1; next }
    /^[[:space:]]*(schedule|directory|open-pull-requests-limit):/ { incool = 0 }
    END { finish(); if (n < 3) { printf "only %d entries found, expected at least 3\n", n; bad = 1 } exit bad }
  ' "$1"
}

if [[ $# -ge 1 ]]; then
  check_file "$1"
  exit $?
fi

fails=0
expect() { # name, want(0|1), file
  local rc=0
  check_file "$3" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq "$2" ]]; then echo "PASS $1"; else echo "FAIL $1: expected exit $2, got $rc" >&2; fails=$((fails + 1)); fi
}

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
entry() { # ecosystem, dir, extra-lines
  printf '  - package-ecosystem: %s\n    directory: %s\n    schedule:\n      interval: weekly\n%b    open-pull-requests-limit: 5\n\n' "$1" "$2" "$3"
}
cool='    cooldown:\n      default-days: 7\n'
{ echo 'version: 2'; echo 'updates:'; entry github-actions / "$cool"; entry terraform /a "$cool"; entry terraform /b "$cool"; } > "$tmp/good.yml"
{ echo 'version: 2'; echo 'updates:'; entry github-actions / "$cool"; entry terraform /a ""; entry terraform /b "$cool"; } > "$tmp/missing.yml"
{ echo 'version: 2'; echo 'updates:'; entry github-actions / "$cool"; entry terraform /a "$cool    semver-major-days: 7\n"; entry terraform /b "$cool"; } > "$tmp/semver.yml"
{ echo 'version: 2'; echo 'updates:'; entry github-actions / "$cool"; } > "$tmp/short.yml"

expect "three valid entries pass" 0 "$tmp/good.yml"
expect "entry without cooldown fails" 1 "$tmp/missing.yml"
expect "terraform entry with semver key fails" 1 "$tmp/semver.yml"
expect "fewer than three entries fails" 1 "$tmp/short.yml"
expect "repository .github/dependabot.yml passes" 0 "${ROOT}/.github/dependabot.yml"

if [[ "$fails" -gt 0 ]]; then echo "dependabot config: ${fails} failed" >&2; exit 1; fi
echo "dependabot config: all passed"
