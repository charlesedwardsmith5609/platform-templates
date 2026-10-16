# Security policy

## Supported templates

This repository publishes reference templates, not a hosted service. Consumers are responsible for reviewing IAM trust policies, secret paths, image digests, and NetworkPolicies before use in production.

## Reporting

If you discover a vulnerability in these templates (for example unsafe defaults or secret leakage in workflows), please open a private security advisory on the GitHub repository or contact the maintainers. Do not file a public issue with exploit details.

## Design expectations

- No long-lived cloud access keys in GitHub Secrets
- IRSA / OIDC trust policies scoped by `sub` and `aud`
- Secret values must not be written to `$GITHUB_ENV`, workspace files, or process argv
- Envoy admin interfaces must not be Service-exposed
- Container images should be pinned to digests prior to production rollout
