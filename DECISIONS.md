# Decisions

## 2026-11-13: Catch-up branch base

Context: `improve/tldr-2026-11-05` and `improve/tldr-2026-11-09` are behind `main` and contain no commits that `main` lacks. `cursor/harden-platform-templates` is an older tree that is missing the CI threat model, action pin checker, and Floci fixture already on `main`. It has no ExternalId or vendor trust policy.

Choice: `improve/tldr-catchup-2026-11-13` is cut from `origin/main`. The older branches are not merged.

Why: Reusing the harden branch would drop work that is already on main. Nothing on those branches implements the vendor, label, or OIDC items.

## 2026-11-13: Vendor trust is a new module

Context: Cross-account vendor trust must require `sts:ExternalId` and at least one of `aws:SourceIp` or `aws:PrincipalOrgID`. The repo already has an IRSA role for the API gateway.

Options: add the vendor conditions to the gateway role; add a separate module.

Choice: `terraform/modules/vendor-trust`. The gateway role is unchanged. The "at least one of source IP or org id" rule is a resource precondition, because a variable validation block cannot read another variable. The role is created with no attached permissions.

Why: The gateway principal is an EKS OIDC provider, not a vendor account. Folding vendor conditions into it would change a working trust policy. No permissions on the new role fails closed until a caller attaches one.
