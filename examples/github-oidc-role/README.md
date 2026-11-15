# GitHub Actions OIDC example

This file is the trust policy `scripts/check-oidc-trust.sh` audits in this repo. The subject is one repository and the `main` ref, and the audience is `sts.amazonaws.com`. The checker fails a statement whose `sub` or `aud` is missing, empty, or contains `*` or `?`, and a `sub` or `aud` under an operator other than `StringEquals` or `StringLike`. The API gateway module trusts an EKS issuer, not `token.actions.githubusercontent.com`, so it is outside this check.

`main.tf` only defines a local value (`jsonencode` of the policy). It declares no provider and creates no resource, so there is nothing to apply.

```bash
bash scripts/check-oidc-trust.sh --skip-testdata --require-match
```
