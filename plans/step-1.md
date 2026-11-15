# Step 1 (HIGH): blockers 1-5

Findings: 1, 2, 3, 4, 5. Decisions: D3, D4, D12, D13.

## Types
- `vendor-trust` variable `source_ip_cidrs`: `list(string)`, `nullable = false`, each entry passes `can(cidrhost(c, 0))` and does not end in `/0`.
- New variable `source_vpce_ids`: `list(string)`, `nullable = false`, default `[]`, each matches `^vpce-[0-9a-f]{8,17}$`.
- `principal_org_id`: `string`, nullable, optional, additive only.
- Checker exit codes: 0 pass, 1 findings, 2 usage or read error.

## Ownership of shared state
- The `vendor-trust` module owns the trust policy; the checker owns no state and only reads files.
- The CI workflow owns `terraform init`. Tests own their fixtures under `scripts/testdata/oidc-trust/`.

## Tests (written failing first)
- CI job runs `terraform init -backend=false` before `terraform test` for vendor-trust.
- Checker fails (exit 1) for: StringNotEquals sub; `?` wildcard; minified JSON with two subs on one line; second statement without sub; wildcard in a multiline list; policy after a `//` comment; policy in a `testdata` dir; `.json.tpl` file; missing `aud`; `ForAllValues:` on sub; `.tf` mentioning `:sub` in an unclassifiable form.
- Checker passes a correct `aws_iam_policy_document` using `test = "StringEquals"` with `values`.
- Checker handles `ForAnyValue:` and case-insensitive keys.
- `--require-match` exits 1 with no match and passes otherwise; unreadable path exits 2.
- Testdata dirs are scanned unless the skip flag is passed.
- Module rejects `0.0.0.0/0`, `::/0`, garbage CIDRs, null CIDR list.
- Module fails when neither SourceIp nor SourceVpce is set, even if `principal_org_id` is set.
- Module accepts SourceVpce only; org ID is added to the policy only alongside a valid second condition; bad org ID fails.
- tftest decodes the policy with `jsondecode` and asserts Effect, Action, Principal, StringEquals ExternalId, IpAddress SourceIp.
- tftest failure cases: whitespace-only external_id, missing service tag, missing env tag, blank tag, bad org ID, both conditions set.

## Files
- .github/workflows/ci.yml
- scripts/check-oidc-trust.sh
- scripts/test-check-oidc-trust.sh
- scripts/testdata/oidc-trust/
- Makefile
- terraform/modules/vendor-trust/main.tf
- terraform/modules/vendor-trust/variables.tf
- terraform/modules/vendor-trust/tests/vendor.tftest.hcl
- terraform/modules/vendor-trust/README.md
- examples/vendor-trust/main.tf
- docs/vendor-access.md
- DECISIONS.md
