# vendor-trust

Cross-account IAM role for a vendor. The trust policy requires `sts:ExternalId` and exactly one of `aws:SourceIp` (`source_ip_cidrs`, valid CIDRs, no `/0`) or `aws:SourceVpce` (`source_vpce_ids`). `aws:PrincipalOrgID` (`principal_org_id`) is optional and is only added next to one of those; it cannot satisfy the rule alone. The role has no attached permissions.

See [docs/vendor-access.md](../../../docs/vendor-access.md).

```hcl
module "vendor" {
  source            = "../../terraform/modules/vendor-trust"
  vendor_account_id = "111122223333"
  external_id       = "replace-me"
  source_ip_cidrs   = ["203.0.113.0/24"]

  tags = {
    team    = "platform"
    service = "vendor-bridge"
    env     = "prod"
  }
}
```
