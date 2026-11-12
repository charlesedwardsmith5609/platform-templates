# Changelog

Format follows Keep a Changelog. Dates are UTC.

## [Unreleased] - 2026-11-11

- Pin the actionlint installer to commit 3795ba2 (v1.7.12) instead of the main branch
- Document CI threat-model controls: revoke committed keys, alert on branch-protection overrides and deleted workflow runs, keep unscoped CLI tokens out of automation
- Set workflow `permissions: {}` and document the per-job token scope table
- SHA-pin all third-party GitHub Actions `uses:` (commit + tag comment); CI pin-check job + `make check-action-pins`
- Document image/base-OS digest refresh cadence and ownership in README

## [Unreleased] - 2026-11-06

- Floci apply CI job + `make test-floci` for IRSA IAM and Secrets Manager (K8s stays on validate/render)
- Documented Floci coverage limits in README; audited workflows — no `pull_request_target`
- Digest-pinned image defaults with validation
- TFLint, Checkov, terraform test, actionlint in CI
- Fixed secrets-injection workflow so the piped secret is not overridden by a heredoc
