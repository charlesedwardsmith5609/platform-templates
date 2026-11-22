# Changelog

Format follows Keep a Changelog. Dates are UTC.

## [Unreleased] - 2026-11-20

- New design note `docs/mtls-termination.md` (docs only, no Terraform change): the api-gateway module configures no TLS or mTLS; compares terminating mTLS at Envoy with an AWS NLB in front. NLB details are vendor claims from the AWS blog. Whether either option belongs here is an open question. Doc tests added to `scripts/test-docs-claims.sh`.

## [Unreleased] - 2026-11-16

- Document that the deploy role should name specific Secrets Manager ARNs. Note IMDSv2, no long-term keys in application config, and cross-account replication as an AWS disaster-recovery option this repository does not configure.
- Secrets read-path note now cites file and line for each repository claim, states the example `access_key` literals are emulator/mock placeholders, says the repository does not configure GuardDuty, and cites the AWS cross-account replication announcement (read 2026-11-21). Doc tests extended in `scripts/test-docs-claims.sh`.

## [Unreleased] - 2026-11-14

- `vendor-trust` now requires exactly one of `source_ip_cidrs` (valid CIDRs, no `/0`) or `source_vpce_ids` (`aws:SourceVpce`). `principal_org_id` is optional and additive and no longer counts as the second condition. This replaces the 2026-11-11 wording "`aws:SourceIp` or `aws:PrincipalOrgID`". Both list variables are `nullable = false`.
- `external_id` must be 2 to 1224 characters from the STS set (`A-Za-z0-9+=,.@:/_-`) and not `replace-me`, `example-external-id`, or `changeme` (case-insensitive).
- `vendor-trust` and `examples/vendor-trust` require Terraform `>= 1.7.0` (was 1.5 for the earlier module draft; the tests use `mock_provider`). Their lock files carry two `h1:` hashes; other lock files carry one per provider, including `examples/api-gateway`.
- `scripts/check-oidc-trust.sh` is structural: jq for `.json` and `.json.tpl`, an awk converter for `.tf` and `.hcl`. It requires `sub` and `aud` under `StringEquals`/`StringLike` with no `*` or `?`, rejects `StringNot*`, `ForAllValues:` and `IfExists`, and fails on `.tf`/`.hcl` forms it cannot classify. `--require-match` exits 1 when nothing matches, `--skip-testdata` skips `testdata` directories (scanned by default). Exit codes 0, 1, 2. Fixtures in `scripts/testdata/oidc-trust/`.
- `vendor.tftest.hcl` decodes the trust policy and asserts Effect, Action, Principal, and conditions, plus failure cases (27 runs).
- CI: new `oidc-trust` job (checker unit test, `scripts/test-terraform-config.sh`, repo scan with `--skip-testdata --require-match`); `terraform init` runs before the vendor-trust `terraform test`; the vendor-trust example is validated. TFLint and Checkov remain CI-only (GitHub Actions) and are not run by `scripts/check.sh`.
- `bash scripts/check.sh` is the local gate: misbehavior and assertion helpers, then `scripts/checks/shell.sh` (shellcheck, shell tests, `terraform fmt`/`test`, Floci with docker). A skipped stage fails unless `ALLOW_SKIP=1`; `TF_BIN` selects the terraform binary. Added pairing-kit helper scripts, `skills/`, `plans/`, `CLAUDE.md`/`AGENTS.md`, and `REQUIREMENTS.md`.
- Docs corrected: ExternalId is a non-secret per-customer identifier; "can do nothing" replaced by the `sts:GetCallerIdentity` and resource-policy caveat; the fork pull request token claim is marked needs verification; `docs/ci-threat-model.md` now lists `repository_dispatch` for `service-onboarding.yml`; the isolation doc says the namespace is created only when `create_namespace` is true. README now covers vendor-trust, the OIDC checker, the `oidc-trust` job, and local checks. The api-gateway README lists inputs, outputs, and `_v1` resource names.

## [Unreleased] - 2026-11-11

- OIDC trust check fails when a policy that trusts `token.actions.githubusercontent.com` has a missing or wildcard `sub`. Negative fixtures prove the failure. The live example is `examples/github-oidc-role`.
- CI threat model: a mass of pull requests can probe `pull_request` workflows, and workflow logs are a secret sink.
- Vendor role tags must include non-empty `team`, `service`, and `env`. `terraform test` fails when `team` is missing.
- `docs/agent-workload-isolation.md` lists Kubernetes isolation options for agent workloads. Unverified pod spec fields are marked needs verification.
- Vendor trust module requires `sts:ExternalId` and `aws:SourceIp` or `aws:PrincipalOrgID`. `terraform test` fails when either is absent. See `docs/vendor-access.md`.
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
