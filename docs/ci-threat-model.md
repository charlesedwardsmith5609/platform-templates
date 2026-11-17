# CI threat model

These workflows assume a GitHub token can be stolen the way LiteLLM described for the `v1.107.0` release. A committed admin key stayed valid for months, an unscoped GitHub CLI token belonged to an organization owner, branch protection was overridden, and the workflow runs that moved secrets and published the release were deleted.

Source: [The attack chain behind the v1.107.0 LiteLLM release](https://docs.litellm.ai/blog/security-incident-oct-21-2026-attack-chain) (TLDR InfoSec, 2026-11-09).

## Revoke any key that was ever committed

Deleting a file on a later commit leaves the secret in history, and it leaves the credential valid at the issuer. If a key, token, or password is pushed, including on a branch that never merges, revoke it where it was issued and replace it. Treat the old value as public for the whole time it remained valid.

## Alert on branch-protection overrides and deleted workflow runs

Page a human when an organization owner bypasses branch protection (a push that protection rejects, then a push that succeeds as an override, including a force-push) and when a workflow run is deleted. Those audit events are how the stolen owner token hid the workflow edit and the CI logs.

## No unscoped CLI tokens in automation

Automation uses scoped credentials: the workflow `GITHUB_TOKEN` with the per-job scopes in the [permission table](../README.md#workflow-token-permissions), and AWS via OIDC (`id-token: write`) with a short role session. A GitHub CLI OAuth token is unscoped, remains valid after 2FA, and sits outside the re-authentication GitHub asks for on sensitive organization actions. Keep that class of token, and any classic PAT or long-lived cloud access key, out of workflows, agents, and repository secrets.

## Mass probe PR

`ci.yml` runs on `pull_request`. Anyone who can open a pull request can open many of them. Each run shows which jobs start, which steps fail, and what the logs contain. That is enough to map the workflow without merging.

This page does not add a rate limit. The controls already in the tree are `permissions: {}` on each workflow, a short per-job permission list, and no `pull_request_target` trigger. `secrets-injection.yml` is `workflow_call` only. `service-onboarding.yml` runs on `workflow_dispatch` and `repository_dispatch` (type `onboard-service`). Whether a fork pull request starts `ci.yml` depends on repository and organization settings (needs verification).

needs verification: the exact token GitHub issues for a fork pull request against a private repository. The workflows set `permissions` so the job does not inherit an unscoped default. Confirm the fork token against the GitHub docs for the plan you use before treating that as a boundary.

## Workflow logs are a secret sink

A step that prints a token, a secret, or the process environment writes that value into the workflow log. Anyone who can read the log can read the value. Logs are a place secrets leak. Do not echo a secret to debug a failure. Deleting a run, which the source above lists among the LiteLLM actions, does not undo the time the value sat in the log. This wording follows the source summary in the first section; the source page was not re-checked offline (assumption). Prefer not printing it.

## Secrets Manager read path

This section is about the deploy role that reads Secrets Manager. It is separate from the LiteLLM chain above.

No workflow in this repository, and neither Terraform module, contains a `secretsmanager:GetSecretValue` statement. `vendor-trust` attaches no permissions. The api-gateway role attaches only the managed policy ARNs a caller passes in `additional_iam_policy_arns`. `secrets-injection.yml` calls `aws secretsmanager get-secret-value` once per run. The secret id defaults to `platform/<environment>/<service>/config`, and the `secret_id` input can replace it, so the caller chooses which id is requested.

The role in `AWS_DEPLOY_ROLE_ARN` is created outside this repository. That role should allow `secretsmanager:GetSecretValue` only on specific secret ARNs. CI does not see that policy, so this page does not claim the role is least privilege. Illustrative ARN only; this repository does not apply it. Secrets Manager appends a hyphen and six random characters to each secret ARN, so name the full ARN:

`arn:aws:secretsmanager:us-west-2:123456789012:secret:platform/production/checkout-api/config-AbCdEf`

`examples/floci-aws` attaches the AWS managed policy `ReadOnlyAccess` to an IRSA role in the local emulator. That policy document is not in this repository, so this page cannot show whether it allows a broad secret read. It is not a named secret ARN, and it is not the deploy role.

Hosts that run these workloads should require IMDSv2 (`http_tokens = required`). This repository does not manage EC2 instances or EKS node groups, and it does not set instance metadata options. Pods should use IRSA. The api-gateway module already trusts one ServiceAccount. Do not put long-term access keys in application config. Workflows in this repository assume roles with OIDC.

According to the November 2026 AWS announcement (not re-checked offline; assumption), Secrets Manager can replicate a secret to another account without a shared KMS key and without a cross-account resource policy. That is an option for disaster recovery. This repository does not configure replication. Check current AWS documentation for regions, pricing, and limits.
