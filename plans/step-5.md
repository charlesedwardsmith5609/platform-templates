# Step 5: finish 2026-11-16 (CI queue time blocked, secrets read path gap-fill)

Branch: `improve/tldr-2026-11-16`, tracking `origin/improve/tldr-2026-11-16`. Base is `6701853`
(step 4, one commit on top of `origin/main` `40ab9b6`). Nothing in `6701853` is rewritten. New
work is new commits on top.

Assumptions (stated up front, per CLAUDE.md rule 9):

- The owner is not answering during this pass. Approval gates in the item text become notes and
  open questions. Items with their own stated default may be built on that default and are
  flagged "pending owner confirmation".
- The owner's brief asks to try to read the cited AWS URL. That counts as the prior approval
  for one outbound host (`aws.amazon.com`) that CLAUDE.md rule 11 requires. No other host is
  approved for this step.

## Item 1: CI queue time (BLOCKED, note only)

Blocked on data only the owner has: per-job durations from `gh run view` for recent runs. No
network call, no edit to `.github/workflows/ci.yml`.

Confirmed from code at plan time (grep on `.github/workflows/ci.yml`):

- No `concurrency:` key anywhere in the file. `grep -n concurrency .github/workflows/ci.yml`
  returns nothing.
- No `timeout-minutes` anywhere in the file. `grep -n timeout-minutes` returns nothing.
- Seven jobs: `terraform` (line 11), `tflint` (68), `checkov` (91), `workflow-lint` (107),
  `action-pins` (122), `oidc-trust` (134), `floci-apply` (149). The `on:` block starts at line 4.

Proposals, recorded only. The letters follow step 4's references ("CI item (b)" is the timeout,
`plans/step-4.md` line 44). The exact (a)-(d) text is not in the repository, so this mapping is
inferred from step 4's "Not in this step" list (line 59):

- (a) A workflow `concurrency` group keyed on workflow and ref, with `cancel-in-progress` for
  pull requests only, so superseded pushes stop holding runners.
- (b) `timeout-minutes` on each job, sized from the pasted durations (for example about 3x the
  p95), so a hung job releases its runner.
- (c) Path filters. Trap, stated plainly: if a workflow or job that a branch protection rule
  lists as a required check is skipped by `paths:`/`paths-ignore:`, the check never reports and
  the pull request waits forever ("Expected: waiting for status"). Path filtering needs either a
  job that always runs and reports, or filtering inside the job, never a skipped required check.
- (d) A Terraform provider plugin cache in the `terraform` and `floci-apply` jobs.

None of these is built. Each waits for the durations. No speedup is claimed.

Done when: this section exists in the plan and the implementer's report lists the item as
BLOCKED with the reason. No file changes for item 1.

## Item 2: Secrets read path (gap-fill on top of `6701853`)

### Check of `6701853` against the item

The item asks for: findings reported first from code, then a docs section with specific secret
ARNs, IMDSv2 and no long-term keys, and cross-account replication stated as an AWS option.

Covered by `docs/ci-threat-model.md` lines 31-45 (added in `6701853`):

- Findings first: line 35 says no workflow and neither module contains a
  `secretsmanager:GetSecretValue` statement. Re-checked at plan time:
  `grep -rnE 'secretsmanager|GetSecretValue' .github terraform` finds only
  `.github/workflows/secrets-injection.yml:135` (`aws secretsmanager get-secret-value`, a CLI
  call, not a grant). No wildcard grant exists in this repository's code.
- Specific secret ARNs (line 37), illustrative ARN (line 39).
- IMDSv2 and no long-term keys (line 43).
- Replication as an AWS option, not configured here (line 45).

Gaps found:

1. No file and line citations. COMMON rule: every statement about the repo cites code.
   Statements to cite:
   - `secrets-injection.yml` assumes `AWS_DEPLOY_ROLE_ARN` (line 67) with OIDC
     (`id-token: write`, line 51). The secret id defaults to `platform/<env>/<service>/config`
     and `secret_id` replaces it (line 58). The call is at line 135.
   - `additional_iam_policy_arns`: declared in `terraform/modules/api-gateway/variables.tf`
     line 75, attached by `aws_iam_role_policy_attachment.additional` in `iam.tf` lines 33-36.
   - `vendor-trust` has one resource, `aws_iam_role.vendor` (`terraform/modules/vendor-trust/main.tf`
     line 14), and attaches no policy.
   - `examples/floci-aws/main.tf` line 97 attaches `ReadOnlyAccess`.
   - `service-onboarding.yml` also assumes a role by OIDC (lines 86/92, 188/194, 274/280).
2. The replication paragraph says the announcement was "not re-checked offline (assumption)".
   The page was read at plan time (posted 2026-11-13). Per that page: a synchronized copy of a
   primary secret in a secondary account, no shared KMS key or cross-account secret policy,
   the replica is encrypted with a customer managed KMS key owned by the replica account,
   changes and rotations sync, a replica can be promoted to standalone. Reword to cite the page
   and keep it framed as an AWS option this repo does not configure. The implementer re-reads
   the page once; if it cannot be read, keep the current "assumption" wording and say so.
3. The "no long-term access keys in application config" sentence does not mention the two
   static key literals in examples: `examples/floci-aws/main.tf` line 44 (`access_key = "test"`,
   local Floci emulator) and `examples/api-gateway/main.tf` line 27 (`access_key = "mock"`, plan
   against a mock). Add one sentence: these are intended emulator/mock placeholders, not AWS
   credentials. Cite only what the code shows: the Floci provider points `iam`, `sts` and
   `secretsmanager` at `var.floci_endpoint` (`examples/floci-aws/main.tf` lines 50-54); the
   api-gateway example sets no endpoint override (`examples/api-gateway/main.tf` lines 20-28),
   so do not claim it cannot contact AWS, only that the literal is not a valid AWS key.
   (Plan-review finding 2, accepted.)
4. GuardDuty is in the item's Reason line, not its ask. Add one sentence: this repository does
   not configure GuardDuty. No recommendation beyond that (vendor advice, not a repo feature).

### Approach

Edit only the "Secrets Manager read path" section of `docs/ci-threat-model.md`. Keep its order:
findings first, then the deploy-role guidance, then IMDSv2/keys, then replication.

### Tests (written failing first)

Extend `scripts/test-docs-claims.sh` (keep every existing check):

- Assert the section contains `secrets-injection.yml:135`. Use the `path:line` citation form
  throughout the section so the assertions stay simple.
- Assert it contains `iam.tf` and `variables.tf` citations for `additional_iam_policy_arns`.
- Assert it contains `does not configure GuardDuty`.
- Assert it names the emulator placeholders: `examples/floci-aws/main.tf:44`.
- Assert it lacks `not re-checked offline` in the replication paragraph only if the page was
  read. If the page could not be read, skip this one assertion and say so in the report.

Run `bash scripts/test-docs-claims.sh` before the doc edit (must fail on the new checks), then
after (must pass).

### Gate

- `bash scripts/check.sh`. There is no `make check` target (`Makefile` has a help target and
  per-check targets only). Do not add one.
- Known at plan time: `terraform`, `tflint`, `shellcheck`, `actionlint`, `docker`, `jq` are not
  installed. `gitleaks` is at `~/go/bin` (add to `PATH`). The `shell` stage will SKIP, and a
  skip fails unless `ALLOW_SKIP=1`. Run once plain and once with `ALLOW_SKIP=1`; report every
  SKIP as NOT RUN. Do not install system packages.
- `bash scripts/cross-review.sh` on the diff before committing.

### Commit

One commit: "Cite code in the secrets read-path note" plus the COMMON trailer. CHANGELOG: add a
bullet under the existing `## [Unreleased] - 2026-11-16` heading.

### Build vs note-only

- Item 1: note only (blocked).
- Item 2: build (docs and doc tests only). No IAM policy, Terraform, or workflow change: the
  item says docs only unless the owner approves a policy change.

## Ownership of shared state

Docs only. `docs/ci-threat-model.md` owns the read-path claims. No runtime shared state.

## Files

- plans/step-5.md
- docs/ci-threat-model.md
- scripts/test-docs-claims.sh
- CHANGELOG.md

## Not in this step

- No edit to any workflow, action SHA, or `permissions` block.
- No validation on `additional_iam_policy_arns`.
- No README edit.

## Plan review (cross-model)

`bash scripts/plan-review.sh plans/step-5.md` ran on 2026-11-21 with openai (`gpt-6.1-sol`).
Saved under `.reviews/` (git-ignored). Findings:

1. HIGH: approval gates turned into notes; implementation without explicit approval conflicts
   with CLAUDE.md rules 1 and 9. Disagree for this pass, recorded: the owner's own brief for
   this pass (unattended policy) authorizes docs/test items and stated defaults, and requires
   open questions to be recorded instead of waiting. Item 2 is docs and doc tests only; no
   behavior change is made without approval. The owner can reject the commit on review.
2. MEDIUM: "never reach a real account" is not established by the key literals. Agree; gap 3
   reworded to cite the endpoint configuration and drop the guarantee.

## Open questions for the owner

1. CI durations: paste per-job durations (`gh run view <id> --json jobs`) for about 10 recent
   runs. Recommendation: then do (a) and (b) first; they need no required-check changes.
2. Path filters (c): which checks are required in branch protection? Recommendation: do not
   add path filters until that list is known.
3. Should `additional_iam_policy_arns` reject AWS managed broad policies (for example
   `ReadOnlyAccess`, `SecretsManagerReadWrite`)? Recommendation: yes, as a separate approved
   step with a `terraform test` failure case; docs only for now.
4. Should the Floci example use a narrower policy than `ReadOnlyAccess`? Recommendation: low
   priority; it runs only against the local emulator.
