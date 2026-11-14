# Cross-account vendor access

A vendor account must not be able to assume a role in this account with only the account id. The `vendor-trust` module (`terraform/modules/vendor-trust`) builds one IAM role whose trust policy requires both of the following.

1. `sts:ExternalId` equals the configured string. An empty string is rejected. The vendor has to present the value. It is a non-secret identifier. It guards against the confused deputy problem, not against a vendor who is already trusted. It must be unique per customer, so that one customer cannot use a value they know to act on behalf of another. It may appear in configuration and in the repository. It must also not be a placeholder.
2. Exactly one of `aws:SourceIp` (`source_ip_cidrs`: valid CIDR blocks, no `/0` range) or `aws:SourceVpce` (`source_vpce_ids`: `vpce-` ids). A plan with neither, or with both, is rejected. `aws:PrincipalOrgID` is optional and is only added next to one of them. It does not count as the second condition, because the principal is already pinned to one account.

The module attaches no permissions. A caller that wants the vendor to do something must attach a policy on purpose. Until then the role can still be assumed. An assumed session can call `sts:GetCallerIdentity`, and it can reach any resource whose own resource policy (an S3 bucket policy or a KMS key policy, for example) trusts this role or the account. "No attached permissions" is not "no access".

The existing API gateway role is a different pattern. It trusts an EKS OIDC provider and a single ServiceAccount subject. It is not a vendor role, and this module does not change it.

`terraform test` in the module plans a policy that contains the condition keys, and it decodes the trust policy and checks Effect, Action, Principal, the ExternalId condition, and the SourceIp or SourceVpce condition. It expects failures for a blank `external_id`, a `/0` or malformed CIDR, a bad VPC endpoint or org id, a missing source condition (even with an org id), both source conditions together, and a missing or blank `team`, `service`, or `env` tag.
