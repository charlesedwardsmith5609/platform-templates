# Step 6: gateway ownership tags (REPORT ONLY)

Branch: `improve/tldr-2026-11-17`, stacked on `improve/tldr-2026-11-16` (plan commit for step 5).

Status: report only. The item says do not change behavior without owner approval. Under the
unattended policy nothing in the "If approved" list below is built in this pass. The only file
this step writes is this plan.

Reason line (vendor claim, not verified here): cloud overspend traces to unclear ownership
(TLDR IT 2026-11-17, networkworld.com article 4249100). It motivates the question; it is not
evidence about this repository.

## Findings from code

vendor-trust requires the three keys:

- `terraform/modules/vendor-trust/variables.tf` lines 77-87: `variable "tags"` is
  `map(string)` with no default, and a `validation` block requires
  `length(trimspace(lookup(var.tags, key, ""))) > 0` for each of `team`, `service`, `env`
  (lines 81-85). Error message: "tags must include non-empty team, service, and env."
- `terraform/modules/vendor-trust/tests/vendor.tftest.hcl`: default `tags` with all three keys
  (lines 10-15); failure runs `missing_team_tag_fails` (224), `missing_service_tag_fails` (239),
  `missing_env_tag_fails` (254), `blank_tag_fails` (269), each with `expect_failures = [var.tags]`.

api-gateway treats tags as optional:

- `terraform/modules/api-gateway/variables.tf` lines 120-124: `variable "tags"`, `map(string)`,
  `default = {}`, no validation.
- `terraform/modules/api-gateway/iam.tf` lines 27-30: the IAM role gets
  `merge(var.tags, { "platform.io/service" = var.service_name, "platform.io/component" = "api-gateway" })`.
- `terraform/modules/api-gateway/main.tf` line 14: `local.environment` reads `Environment`, then
  `environment`, else `"unspecified"`. It is passed to the OTel collector template
  (`main.tf` line 82) as `deployment.environment`
  (`templates/otel-collector.yaml.tpl` lines 29-30). A lowercase `env` key is not read.

Callers inside this repository use different key names:

- `examples/api-gateway/main.tf` lines 51-54: `Environment = "staging"`, `Team = "payments"`.
  No `service` key.
- `terraform/modules/api-gateway/tests/gateway.tftest.hcl` lines 29-32: same two keys.
- `README.md` lines 113-116: same two keys in the usage snippet.
- `terraform/modules/api-gateway/README.md` line 94: tags row says default `{}`.

Prior decision: `DECISIONS.md` lines 31-39 ("Cost tags are required on the vendor role only")
chose to leave the gateway unchanged because renaming tags on a published module changes caller
state. Any change here reverses that decision and needs a new DECISIONS entry.

## What would break if api-gateway required `team`, `service`, `env`

- Every existing caller without those exact lowercase keys fails at plan with a validation
  error. That includes `examples/api-gateway`, the gateway test defaults (so every run in
  `gateway.tftest.hcl` fails), and anyone who copied the README snippet.
- IAM tag keys are case-insensitive (IAM user guide, "Tagging IAM resources": two tags whose
  keys differ only in case cannot coexist on one IAM resource; plan-review finding 1, not
  re-read offline, implementer verifies). So a caller cannot keep `Team` and add `team` on the
  gateway role: the apply would fail or collide. The only path is renaming `Team` to `team`
  (an in-place tag update on `aws_iam_role`). Cost allocation reports keyed on `Team` must be
  re-pointed by their owners; that migration needs owner sign-off.
- `local.environment` keeps reading `Environment`/`environment`. A caller who moves to `env`
  only would see `deployment.environment = "unspecified"` in telemetry unless line 14 also reads
  `env`.
- `service` duplicates `platform.io/service`, which the module already sets from
  `var.service_name` (`iam.tf` line 28). Requiring the caller to type it again can drift.

## Proposal (recommendation)

Recommend: yes, require the same three keys, but in a way that does not double-enter or break
telemetry:

- Require non-empty `team` and `env` with the same validation pattern as vendor-trust.
- For `service`: either require it from the caller (strict parity) or have the module set it
  from `var.service_name`, placed AFTER `var.tags` in the `iam.tf` merge so the generated value
  is authoritative and a caller value is overwritten (plan-review finding 2). Recommendation:
  module-set and authoritative, so it cannot drift from `platform.io/service`. Validation then
  checks only `team` and `env`. This is owner question 2.
- Change `main.tf` line 14 to read `env` first, then `Environment`, then `environment`.
- Ship as a breaking change with a CHANGELOG note and a migration line ("rename `Team` to
  `team` and add `env`; IAM tag keys are case-insensitive, so both spellings cannot coexist;
  re-point cost reports keyed on `Team`"). `Environment` may stay next to `env` (different key).

## If approved: exact change list

1. `terraform/modules/api-gateway/variables.tf`: on `variable "tags"`, remove `default = {}`,
   update the description, and add the vendor-trust validation block verbatim (keys list per
   question 2):
   ```hcl
   validation {
     condition = alltrue([
       for key in ["team", "service", "env"] : length(trimspace(lookup(var.tags, key, ""))) > 0
     ])
     error_message = "tags must include non-empty team, service, and env."
   }
   ```
2. `terraform/modules/api-gateway/main.tf` line 14: read `env` first.
   If `service` is module-set (question 2): `terraform/modules/api-gateway/iam.tf` lines 27-30
   merge becomes `merge(var.tags, { service = var.service_name, "platform.io/service" = ..., ... })`
   and the validation keys list is `["team", "env"]`.
3. `terraform/modules/api-gateway/tests/gateway.tftest.hcl`:
   - Default `tags` replace `Team` with `team` and add `env` (and `service` only if required).
     Keep `Environment` (a different key from `env`). Do not keep `Team` next to `team`.
   - New failing runs, each `expect_failures = [var.tags]`: `missing_team_tag_fails`,
     `missing_service_tag_fails` (only if `service` is required), `missing_env_tag_fails`,
     `blank_tag_fails` (whitespace value), `empty_tags_fails` (`tags = {}`).
   - New passing run `all_ownership_tags_pass` that asserts `aws_iam_role.gateway.tags["team"]`
     and the two `platform.io/*` tags are present.
   - If `service` is module-set: run `caller_service_tag_is_overwritten` passes
     `tags.service = "other"` and asserts the role tag equals `var.service_name`.
   - If `env` drives telemetry: assert the rendered collector config carries the `env` value.
4. `examples/api-gateway/main.tf` lines 51-54: `Team` becomes `team`, add `env`.
5. `README.md` lines 113-116: same keys in the snippet.
6. `terraform/modules/api-gateway/README.md` line 94: tags row becomes required, lists the
   three keys, and still names the two added `platform.io/*` tags.
7. `CHANGELOG.md`: new dated heading with a **Breaking** bullet and the migration line.
8. `DECISIONS.md`: new entry superseding lines 31-39 for the gateway, with the reason.

Gate for that future step: `terraform test` in `terraform/modules/api-gateway` (needs
terraform 1.9.8; not installed on this machine at plan time, so it would SKIP = NOT RUN here),
`terraform validate` on `examples/api-gateway`, then `bash scripts/check.sh`.

## Tests for this step

None. Report only; no code or docs outside this plan change.

## Done criteria

- This plan is committed on `improve/tldr-2026-11-17`.
- No file other than `plans/step-6.md` changes on this branch.
- The report lists the item as "report only, awaiting owner approval".

## Ownership of shared state

None. No runtime state.

## Files

- plans/step-6.md

## Plan review (cross-model)

`bash scripts/plan-review.sh plans/step-6.md` ran on 2026-11-21 with openai (`gpt-6.1-sol`),
saved under `.reviews/` (git-ignored). Two MEDIUM findings, both accepted and folded in:

1. IAM tag keys are case-insensitive, so "keep `Team` next to `team`" is unsafe. Agree; the
   migration is now a rename plus a cost-report re-point. Not re-verified offline against AWS
   docs; the implementer of an approved step checks the IAM tagging page first.
2. Putting the `service` default before `var.tags` lets callers override it, so it does not
   prevent drift. Agree; the module-set value goes after `var.tags` and gets its own test.

## Open questions for the owner

1. Require the three keys on api-gateway at all? Recommendation: yes, as a breaking change in
   the next tagged release, reversing DECISIONS.md lines 31-39 for the gateway.
2. `service`: required from the caller, or set by the module from `var.service_name`
   (authoritative, overwrites a caller value)? Recommendation: module-set.
5. Who owns the cost reports keyed on `Team`, and can they move to `team` in the same release?
   Recommendation: confirm before approving item 1; the rename is the only migration path.
3. Keep reading `Environment` for telemetry after the change? Recommendation: read `env` first,
   fall back to the old keys, drop the fallback one release later.
4. Should vendor-trust also add `platform.io/component` for parity? Recommendation: optional,
   low value; leave unless cost reports need it.
