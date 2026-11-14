# vendor-trust

Cross-account IAM role for a vendor. The trust policy requires `sts:ExternalId` and exactly one of `aws:SourceIp` (`source_ip_cidrs`, valid CIDRs, no `/0`) or `aws:SourceVpce` (`source_vpce_ids`). `aws:PrincipalOrgID` (`principal_org_id`) is optional and is only added next to one of those; it cannot satisfy the rule alone. The role has no attached permissions.

`external_id` is 2 to 1224 characters from the STS set (`A-Za-z0-9+=,.@:/_-`). Three fixed placeholder strings are rejected, case-insensitively (the list is in `variables.tf` and `docs/vendor-access.md`). The ExternalId is a non-secret, per-customer identifier.

See [docs/vendor-access.md](../../../docs/vendor-access.md).

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.7.0 (`mock_provider` in the tests) |
| aws | ~> 5.0 |

The module has no `kubernetes` dependency. The committed [`.terraform.lock.hcl`](.terraform.lock.hcl) lists two `h1:` hashes for the `aws` provider (the commit that added the second one describes them as `linux_amd64` and `darwin_arm64`). The other lock files in the repo list one.

## Usage

```hcl
module "vendor" {
  source            = "../../terraform/modules/vendor-trust"
  vendor_account_id = "111122223333"
  external_id       = "acme-7f3a9c1e-prod"
  source_ip_cidrs   = ["203.0.113.0/24"]

  tags = {
    team    = "platform"
    service = "vendor-bridge"
    env     = "prod"
  }
}
```

The `source` path above is relative to [`examples/vendor-trust`](../../../examples/vendor-trust).

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `vendor_account_id` | `string` | none (required) | Vendor AWS account id. Must be 12 digits. The principal is `arn:aws:iam::<id>:root`. |
| `external_id` | `string` | none (required) | Required `sts:ExternalId` value. 2 to 1224 characters from the STS set; the three fixed placeholder strings are rejected. |
| `source_ip_cidrs` | `list(string)` | `[]` | CIDRs for `aws:SourceIp`. Valid CIDR blocks only; a `/0` range is rejected. `nullable = false`. Set this or `source_vpce_ids`, not both. |
| `source_vpce_ids` | `list(string)` | `[]` | VPC endpoint ids for `aws:SourceVpce`, each `vpce-` plus 8 to 17 lowercase hex digits. `nullable = false`. Set this or `source_ip_cidrs`, not both. |
| `principal_org_id` | `string` | `null` | Optional `aws:PrincipalOrgID` (`o-` plus 10 to 32 lowercase letters or digits). Added to the conditions when set. Never enough on its own. |
| `role_name` | `string` | `"vendor-access"` | IAM role name, 1 to 64 characters from the IAM role name set. |
| `tags` | `map(string)` | none (required) | Tags on the role. `team`, `service`, and `env` must be present and non-empty. |

A `precondition` on the role fails the plan unless exactly one of `source_ip_cidrs` and `source_vpce_ids` is non-empty.

## Outputs

| Name | Description |
|------|-------------|
| `role_name` | Name of the vendor IAM role. |
| `role_arn` | ARN of the vendor IAM role. |
| `assume_role_policy` | Trust policy JSON. The tests read it to check the conditions. |

## Tests

```bash
terraform init -backend=false
terraform test
```

[`tests/vendor.tftest.hcl`](tests/vendor.tftest.hcl) uses a mocked `aws` provider, decodes the trust policy, and covers accepted and rejected inputs (27 runs).
