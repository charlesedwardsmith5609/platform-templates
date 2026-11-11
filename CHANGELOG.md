# Changelog

Format follows Keep a Changelog. Dates are UTC.

## [Unreleased] - 2026-11-11

- SHA-pin all third-party GitHub Actions `uses:` (commit + tag comment); CI pin-check job + `make check-action-pins`

## [Unreleased] - 2026-11-06

- Floci apply CI job + `make test-floci` for IRSA IAM and Secrets Manager (K8s stays on validate/render)
- Documented Floci coverage limits in README; audited workflows — no `pull_request_target`
- Digest-pinned image defaults with validation
- TFLint, Checkov, terraform test, actionlint in CI
- Fixed secrets-injection workflow so the piped secret is not overridden by a heredoc
