#!/usr/bin/env bash
# LOCAL TO platform-templates. This is NOT a kit profile (the kit has no terraform/shell profile).
# Run by scripts/check.sh via .pairing-profiles ("shell .") from the repo root.
#
# Stages: shellcheck, repo shell tests, terraform fmt/test per module, Floci apply (docker).
# A stage whose tool is missing is reported as a loud SKIP, never PASS. By default any SKIP
# fails this check; set ALLOW_SKIP=1 to let skips through (they are still listed at the end).
# Terraform binary: $TF_BIN, else `terraform` on PATH. CI pins 1.9.8.
# Terraform runs in a temp copy so `terraform init` never touches the working tree.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root" || exit 2
fail=0 skips=""
stage() { printf '\n== shell: %s\n' "$1"; }
skip() { printf '*** SKIP *** %s: %s\n' "$1" "$2"; skips="$skips\n  $1: $2"; }
run() { # name, command...
  local name="$1"; shift
  if "$@"; then echo "PASS $name"; else echo "FAIL $name"; fail=1; fi
}

tf="${TF_BIN:-terraform}"
have_tf=0; command -v "$tf" >/dev/null 2>&1 && have_tf=1

stage "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  run "shellcheck scripts/*.sh scripts/checks/*.sh" shellcheck -x scripts/*.sh scripts/checks/*.sh
else
  skip "shellcheck" "shellcheck not installed"
fi

stage "repo shell tests"
run "test-check-action-pins" bash scripts/test-check-action-pins.sh
run "test-check-oidc-trust" bash scripts/test-check-oidc-trust.sh
run "test-docs-claims" bash scripts/test-docs-claims.sh
run "check-action-pins (repo)" bash scripts/check-action-pins.sh
run "check-oidc-trust (repo)" bash scripts/check-oidc-trust.sh --skip-testdata --require-match

stage "test-terraform-config"
# Static greps on vendor-trust config; needs no terraform binary.
run "test-terraform-config" bash scripts/test-terraform-config.sh

stage "terraform fmt / test"
if [ "$have_tf" = 1 ]; then
  run "terraform fmt -check -recursive terraform examples" "$tf" fmt -check -recursive terraform examples
  tmp=$(mktemp -d) || exit 2
  trap 'rm -rf "$tmp"' EXIT
  cp -R terraform examples "$tmp/"
  for m in terraform/modules/*/; do
    m="${m%/}"
    if ls "$m"/tests/*.tftest.hcl >/dev/null 2>&1; then
      # shellcheck disable=SC2016  # $1..$3 expand inside the inner bash
      run "terraform test $m" bash -c 'cd "$1/$2" && "$3" init -backend=false -input=false >/dev/null && "$3" test' _ "$tmp" "$m" "$tf"
    else
      echo "no tests in $m"
    fi
  done
else
  skip "terraform fmt/test" "terraform not on PATH (set TF_BIN; CI pins 1.9.8)"
fi

stage "test-floci (docker)"
if command -v docker >/dev/null 2>&1 && [ "$have_tf" = 1 ] && docker info >/dev/null 2>&1; then
  run "test-floci" env TF_BIN="$tf" bash scripts/test-floci.sh
else
  skip "test-floci" "docker (daemon) or terraform missing"
fi

if [ -n "$skips" ]; then
  printf '\n*** SKIPPED STAGES (not passed, not run) ***%b\n' "$skips"
  if [ "${ALLOW_SKIP:-0}" = 1 ]; then
    echo "ALLOW_SKIP=1: skips do not fail this check."
  else
    echo "FAIL: skipped stages; install the tools or set ALLOW_SKIP=1 to accept."
    fail=1
  fi
fi
exit "$fail"
