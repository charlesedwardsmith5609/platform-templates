# GitHub Actions OIDC example

This file is the trust policy `scripts/check-oidc-trust.sh` audits in this repo. The subject is one repository and the `main` ref. A `sub` of `*` or `repo:*`, or a missing `sub`, fails the checker. The API gateway module trusts an EKS issuer, not `token.actions.githubusercontent.com`, so it is outside this check.
