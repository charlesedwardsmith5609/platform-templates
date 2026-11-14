# Cross-account vendor access

A vendor account must not be able to assume a role in this account with only the account id. The `vendor-trust` module (`terraform/modules/vendor-trust`) builds one IAM role whose trust policy requires both of the following.

1. `sts:ExternalId` equals the configured string. An empty string is rejected. The vendor has to present the value. It is not a password. Treat it as an identifier the vendor already knows, and do not put it in a public repository.
2. At least one of `aws:SourceIp` (a non-empty CIDR list) or `aws:PrincipalOrgID`. A plan with neither is rejected.

The module attaches no permissions. A caller that wants the vendor to do something must attach a policy on purpose. Until then the role can be assumed and can do nothing.

The existing API gateway role is a different pattern. It trusts an EKS OIDC provider and a single ServiceAccount subject. It is not a vendor role, and this module does not change it.

`terraform test` in the module plans a policy that contains the condition keys, and it expects a failure when `external_id` is empty or when both the source IP list and the org id are absent.
