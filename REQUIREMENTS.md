## Review fixes 2026-11-14

Source: `.review/findings.md` (PR #29), decisions D1-D14 in `.review/DECISIONS.md`.

- CI initialises the vendor-trust module before `terraform test`.
- `scripts/check-oidc-trust.sh` checks trust policies structurally (jq over JSON and `.json.tpl`), requires `aud` and a `sub` under `StringEquals`/`StringLike`, rejects `Not*`, `ForAllValues:`, `*` and `?`, fails on unclassifiable `.tf`, supports `--require-match`, and scans testdata only when told to skip it.
- `vendor-trust` requires a valid `aws:SourceIp` (no `/0`) or `aws:SourceVpce`; `aws:PrincipalOrgID` is optional and additive.
- `external_id` matches the STS character set and length and rejects placeholder values.
- Tests decode the policy JSON and assert Effect, Action, Principal and conditions, plus failure cases.
- `required_version` is `>= 1.7`; lock files cover linux_amd64 and darwin_arm64.
- Docs: ExternalId is a non-secret per-customer identifier; fork-PR claim is marked needs verification; "can do nothing" is corrected; the isolation doc states the namespace is conditional.
