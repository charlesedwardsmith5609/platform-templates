#!/usr/bin/env bash
# Every bad fixture must fail with its own message. Good fixtures and this repo must pass.
# Exit codes of the checker: 0 pass, 1 findings, 2 usage or read error.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${ROOT}/scripts/check-oidc-trust.sh"
FIXTURES="${ROOT}/scripts/testdata/oidc-trust"

pass=0
fail=0

# assert_run name expected_exit needle checker-args...
assert_run() {
  local name="$1" expected="$2" needle="$3"
  shift 3
  local out ec
  set +e
  out="$("${CHECK}" "$@" 2>&1)"
  ec=$?
  set -e
  if [[ "${ec}" -eq "${expected}" ]] && grep -q -- "${needle}" <<<"${out}"; then
    echo "PASS ${name}"
    pass=$((pass + 1))
  else
    echo "FAIL ${name}: expected exit ${expected} and '${needle}', got ${ec}" >&2
    echo "${out}" >&2
    fail=$((fail + 1))
  fi
}

F="${FIXTURES}"
assert_run "wildcard sub in jsonencode fails" 1 "wildcard or empty sub" "${F}/bad-wildcard"
assert_run "missing sub fails" 1 "no sub condition" "${F}/bad-missing"
assert_run "StringNotEquals sub fails" 1 "unsupported operator" "${F}/bad-notequals"
assert_run "? wildcard fails" 1 "wildcard or empty sub" "${F}/bad-qmark"
assert_run "minified two statements, wildcard in second, fails" 1 "wildcard or empty sub" "${F}/bad-minified"
assert_run "second statement without sub fails" 1 "no sub condition" "${F}/bad-second-statement"
assert_run "wildcard in multiline list fails" 1 "wildcard or empty sub" "${F}/bad-multiline-list"
assert_run "sub only in comments fails" 1 "no sub condition" "${F}/bad-after-comment"
assert_run "testdata dir is scanned by default" 1 "wildcard or empty sub" "${F}/bad-testdata"
assert_run "testdata dir skipped with flag" 0 "no file trusts" --skip-testdata "${F}/bad-testdata"
assert_run ".json.tpl is scanned" 1 "wildcard or empty sub" "${F}/bad-tpl"
assert_run "missing aud fails" 1 "no aud condition" "${F}/bad-no-aud"
assert_run "ForAllValues on sub fails" 1 "ForAllValues" "${F}/bad-forallvalues"
assert_run "unclassifiable :sub in .tf fails" 1 "unclassifiable" "${F}/bad-unclassifiable"

assert_run "specific sub in jsonencode passes" 0 "oidc trust check passed" "${F}/good"
assert_run "aws_iam_policy_document with test/values passes" 0 "oidc trust check passed" "${F}/good-policy-document"
assert_run "ForAnyValue and mixed case keys pass" 0 "oidc trust check passed" "${F}/good-foranyvalue"
assert_run "repository passes with testdata skipped" 0 "oidc trust check passed" --skip-testdata "${ROOT}"
assert_run "repository with testdata scanned fails" 1 "finding" "${ROOT}"

assert_run "no match passes without --require-match" 0 "no file trusts" "${F}/no-github-oidc"
assert_run "no match fails with --require-match" 1 "no file trusts" --require-match "${F}/no-github-oidc"
assert_run "match passes with --require-match" 0 "oidc trust check passed" --require-match "${F}/good"
assert_run "unreadable root exits 2" 2 "cannot read" "${F}/does-not-exist"
assert_run "unknown flag exits 2" 2 "usage" --bogus "${F}/good"

if [[ "${fail}" -gt 0 ]]; then
  echo "check-oidc-trust tests: ${fail} failed, ${pass} passed" >&2
  exit 1
fi
echo "check-oidc-trust tests: ${pass} passed"
