# Decisions

## 2026-11-13: Catch-up branch base

Context: `improve/tldr-2026-11-05` and `improve/tldr-2026-11-09` are behind `main` and contain no commits that `main` lacks. `cursor/harden-platform-templates` is an older tree that is missing the CI threat model, action pin checker, and Floci fixture already on `main`. It has no ExternalId or vendor trust policy.

Choice: `improve/tldr-catchup-2026-11-13` is cut from `origin/main`. The older branches are not merged.

Why: Reusing the harden branch would drop work that is already on main. Nothing on those branches implements the vendor, label, or OIDC items.

## 2026-11-13: Vendor trust is a new module

Context: Cross-account vendor trust must require `sts:ExternalId` and at least one of `aws:SourceIp` or `aws:PrincipalOrgID`. The repo already has an IRSA role for the API gateway.

Options: add the vendor conditions to the gateway role; add a separate module.

Choice: `terraform/modules/vendor-trust`. The gateway role is unchanged. The source-condition rule is a resource precondition, because a variable validation block cannot read another variable in the Terraform 1.7 floor. (Superseded in part: the rule is now "exactly one of source IP or VPC endpoint", see "Vendor second condition" below.) The role is created with no attached permissions.

Why: The gateway principal is an EKS OIDC provider, not a vendor account. Folding vendor conditions into it would change a working trust policy. No permissions on the new role fails closed until a caller attaches one.

## 2026-11-13: Workload isolation doc cites only fields this repo sets

Context: A page on isolating agent workloads on Kubernetes. The instruction is not to invent pod spec fields.

Options: name common pod fields from memory; describe options and mark unchecked fields as needs verification.

Choice: `docs/agent-workload-isolation.md` quotes the security context, ServiceAccount, and NetworkPolicy fields already present in `terraform/modules/api-gateway`. Host namespaces, a separate node pool, and admission rules are described without field names and marked needs verification.

Why: A field name that was not read from this repo or from a spec check would be a guess.

## 2026-11-13: Cost tags are required on the vendor role only

Context: Required cost-attribution tags are `team`, `service`, and `env`, with a test that fails when one is missing. The gateway module already tags with `Team` and `Environment`.

Options: rename the gateway tags; require the three lowercase keys only on the new vendor role.

Choice: `var.tags` on `vendor-trust` rejects a map that lacks any of the three keys or sets one to blank. The gateway module is unchanged.

Why: Renaming tags on a module that is already published would change caller state. The new keys are enforced where this branch adds a role. Empty values fail closed the same way a missing key does.

## 2026-11-13: Mass-probe note does not add a rate limit

Context: The threat model should describe an attacker opening many pull requests to watch workflow behavior, and should say that workflow logs are a secret sink.

Choice: docs only. No new workflow, no concurrency cap, and no new check. The note names the triggers already in `.github/workflows`. The fork-token behavior is marked needs verification.

Why: A guessed GitHub token rule would be presented as a control. The item asked for a section, not a gate.

## 2026-11-14: Vendor second condition is SourceIp or SourceVpce (D3)

Context: `aws:PrincipalOrgID` adds little because the principal is already one account.

Choice: `vendor-trust` requires exactly one of `source_ip_cidrs` (valid CIDRs, no `/0`) or `source_vpce_ids`. `principal_org_id` stays optional and additive. Setting both source conditions is rejected.

Why: Both conditions are ANDed in an IAM policy, and a request through a VPC endpoint does not carry a public source IP the vendor could list, so both together is almost certainly a mistake. Exactly-one is the stricter reading of D3 (assumption, D14). `source_ip_cidrs` is `nullable = false`, so a null is replaced by the empty default and then fails the role precondition.

## 2026-11-14: OIDC checker is structural (D4)

Choice: `scripts/check-oidc-trust.sh` replaces the line grep. JSON and `.json.tpl` go through jq. `.tf` and `.hcl` are converted to JSON by an awk tokenizer that understands `jsonencode({...})` object literals and `aws_iam_policy_document` blocks, then checked the same way. Every Allow statement needs a `sub` and an `aud` under `StringEquals` or `StringLike` (case-insensitive, `ForAnyValue:` allowed) with no `*` or `?`. `StringNot*`, `ForAllValues:` and `IfExists` fail on both `sub` and `aud`. `Deny` statements are not checked. A `.tf` file that names the host but uses `:sub` where the tokenizer cannot classify it (a `format()` key, a heredoc, `dynamic` blocks) fails. Directories named `testdata` are scanned unless `--skip-testdata` is passed. `--require-match` makes zero matches exit 1. Exit codes: 0 pass, 1 findings, 2 usage or read error.

Why: The grep passed several unsafe policies and failed a correct one. Failing closed on forms it cannot read is the D4 rule. Limits: HCL expressions (`var.x`, function calls) are opaque, so a sub or aud given as an expression fails as unverifiable. The checker reads source files, not `terraform show -json` output.

## 2026-11-13: GitHub OIDC check targets a new example

Context: Fail on wildcard `sub` claims in any trust policy that trusts `token.actions.githubusercontent.com`, with a negative fixture. The API gateway role trusts an EKS OIDC issuer URL from a variable. It does not mention `token.actions.githubusercontent.com`.

Options: parse every IAM trust policy and guess which issuer is GitHub; add an example policy that names the GitHub issuer and check that file.

Choice: `scripts/check-oidc-trust.sh` scans `.tf`, `.json`, and `.hcl` for that host. A missing `sub`, an empty `sub`, or a `sub` containing `*` fails the check. (The rules were later extended; see D4.) `scripts/testdata/oidc-trust/` holds a wildcard fixture and a missing-sub fixture, and the unit test requires those messages. The repo scan skips `testdata` so the bad fixtures do not fail CI. `examples/github-oidc-role` is the policy the repo scan must find. A scan that finds zero matching files exits 1 only with `--require-match`, which CI and `make check-oidc-trust` pass.

Why: The existing role is not a GitHub Actions trust policy. Inventing a match against the EKS issuer would flag the wrong thing. A missing `sub` is treated like a wildcard because both let any workflow assume the role. (Superseded by the structural checker in "OIDC checker is structural (D4)": the checker now evaluates every Allow statement, so a second statement with no `sub` fails.)
