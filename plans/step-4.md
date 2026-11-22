# Step 4: secrets read-path note

Assumption: the original request still says to implement after review, except CI speed edits stay unproposed until Charles pastes per-job durations. `REQUIREMENTS.md` stays as the 2026-11-14 record. This step does not rewrite it.

Base: `origin/main` at `40ab9b6`. Branch `improve/tldr-2026-11-16` is reset to that commit. Unpushed `2c3acff` was written against `cursor/harden-platform-templates` and is not replayed.

## Findings already checked (no code change in this list)

CI (`.github/workflows/ci.yml`): no `concurrency:` and no `timeout-minutes`. Seven jobs: `terraform`, `tflint`, `checkov`, `workflow-lint`, `action-pins`, `oidc-trust`, `floci-apply`. Every third-party `uses:` is a 40-character SHA with a tag comment. Workflow permissions are `{}`; each job sets its own `permissions` block. This step does not edit the workflow.

Secrets, from this repo only:

- None explicitly in the workflows or either Terraform module: no `secretsmanager:GetSecretValue` statement and no Secrets Manager `Resource`. The Floci example attaches AWS managed `ReadOnlyAccess`, whose document is not in this repo, so an offline read cannot rule out a broad secret read.
- `vendor-trust` writes a trust policy only. No permissions are attached.
- `api-gateway` writes an IRSA trust policy (`sub` + `aud`) and attaches whatever ARNs the caller passes in `additional_iam_policy_arns` (default empty). It does not inspect those ARNs.
- `secrets-injection.yml` calls `aws secretsmanager get-secret-value` once per run after assuming `AWS_DEPLOY_ROLE_ARN`. The secret id defaults to `platform/<environment>/<service>/config` and the `secret_id` input can replace it, so the caller chooses the id. The role policy is not in this repo.
- `examples/floci-aws` (an example, not a module) attaches `arn:aws:iam::aws:policy/ReadOnlyAccess` to the IRSA role. That managed policy's statements are not in this repo.

## This step

Add one short section, "Secrets Manager read path", at the end of `docs/ci-threat-model.md`. It is a deploy-role note, not part of the LiteLLM chain above it.

The section states:

- The deploy role behind `AWS_DEPLOY_ROLE_ARN` should allow `secretsmanager:GetSecretValue` only on specific secret ARNs. This repo does not define that policy, so CI does not prove the role is least privilege.
- Each workflow call names one secret id, chosen by the caller.
- `additional_iam_policy_arns` will attach any managed policy a caller passes.
- The Floci example attaches `ReadOnlyAccess`. That is a local emulator fixture, not a named secret ARN, and not the deploy role.
- Hosts should require IMDSv2. This repo does not manage EC2 or node groups and does not set metadata options. Pods should use IRSA, which the api-gateway module already does. Do not put long-term access keys in application config. Workflows in this repo assume roles with OIDC.
- According to the November 2026 AWS announcement, Secrets Manager can replicate a secret to another account without a shared KMS key and without a cross-account resource policy. That is a disaster-recovery option. This repo does not configure it.

One illustrative ARN in the section, labelled as not applied by this repo. Use the full secret ARN, including the hyphen and six-character suffix. No policy JSON is added to Terraform.

Extend `scripts/test-docs-claims.sh` so it fails unless the threat model says specific secret ARNs, says this repo does not configure replication, and says this repo does not set instance metadata options. Existing doc assertions stay.

Add one bullet under a new `## [Unreleased] - 2026-11-16` heading in `CHANGELOG.md`.

The documentation, the new assertions, the changelog bullet, and this plan file are one commit. No second commit in this step.

## Tests (written failing first)

- `scripts/test-docs-claims.sh` gains the three assertions above and fails before the section exists.
- Then `bash scripts/check.sh`. There is no `make check` target. Do not add one.
- Do not add a timeout shell test. That waits on approval of CI item (b).

## Ownership of shared state

Each doc file owns its claims. `docs/ci-threat-model.md` owns this section. No runtime shared state.

## Files

- docs/ci-threat-model.md
- scripts/test-docs-claims.sh
- CHANGELOG.md
- plans/step-4.md

## Not in this step

- No edit to `.github/workflows/ci.yml` or any other workflow: no concurrency group, no `timeout-minutes`, no path filters, no provider cache.
- No change to action SHAs or any `permissions` block.
- No Terraform or IAM policy change, including `additional_iam_policy_arns` validation.
- No README edit.
- No pull request, and no speedup claim. CI proposals (a) through (d) wait until Charles pastes per-job durations from `gh run view`. Path filters stay unproposed; when they are proposed, the required-check skip trap gets its own warning.
