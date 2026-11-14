# Step 2 (MEDIUM): findings 6, 7, 13, 14

Decisions: D9, D12, D13, D14.

## Types
- `external_id`: `string`, 2-1224 characters, regex `^[A-Za-z0-9+=,.@:/_-]+$`, not in a placeholder list (`replace-me`, `example-external-id`, `changeme`, case-insensitive).
- `required_version`: `>= 1.7.0`.
- `--require-match` is a boolean flag on the checker (added in step 1; step 2 only wires its use into callers).

## Ownership of shared state
- versions.tf owns the Terraform version floor; each lock file belongs to its module or example directory.

## Tests (written failing first)
- External ID of 1 character, 1225 characters, with a space, or with a placeholder value fails the variable validation.
- A valid 2-character and a valid 1224-character ID passes.
- Placeholder check is case-insensitive.
- Module README and example use a non-placeholder value and still plan.
- `required_version` is `>= 1.7` (asserted by a grep-based CI check or a shell test).
- Lock files list both linux_amd64 and darwin_arm64 hashes (shell test counting `h1:` entries per provider).
- CI and Makefile invoke the checker with `--require-match`; running it on a tree with no GitHub OIDC trust exits 1 with that flag and 0 without it.

## Files
- terraform/modules/vendor-trust/variables.tf
- terraform/modules/vendor-trust/versions.tf
- terraform/modules/vendor-trust/tests/vendor.tftest.hcl
- terraform/modules/vendor-trust/README.md
- terraform/modules/vendor-trust/.terraform.lock.hcl
- examples/vendor-trust/main.tf
- examples/vendor-trust/.terraform.lock.hcl
- .github/workflows/ci.yml
- Makefile
