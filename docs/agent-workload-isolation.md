# Agent workload isolation on Kubernetes

This page lists isolation options. It does not add a module. Fields named below are copied from `terraform/modules/api-gateway`. Anything this repo does not already set is marked needs verification. Do not treat an unverified field as a control.

## One workload, one identity

The gateway module creates one namespace and one ServiceAccount, and the IAM trust policy sets the OIDC `sub` to `system:serviceaccount:<namespace>:<service>-gateway`. An agent should follow that shape: one namespace and one ServiceAccount per agent, and a trust policy whose subject is that pair. A shared ServiceAccount shares the cloud role.

## Network

The gateway NetworkPolicy sets `policy_types` to Ingress and Egress, selects pods with `pod_selector`, allows ingress on port 8080, and then sets an empty `egress` block. That empty block allows all egress. An agent that can call tools should not copy the empty egress block. The policy that denies egress except named ports is needs verification: this repo does not contain that rule, so the field list is not copied from here.

## Pod hardening already in the gateway module

The gateway pod template sets these fields today:

- `service_account_name`
- `security_context.run_as_non_root`, `run_as_user`, `run_as_group`, `fs_group`
- `security_context.seccomp_profile.type` = `RuntimeDefault`
- container `security_context.allow_privilege_escalation` = false
- container `security_context.read_only_root_filesystem` = true
- container `security_context.capabilities.drop` = `ALL`
- container `resources.requests` and `resources.limits`

An agent workload can start from that same block. It is not a new API.

## Needs verification

These ideas are not implemented in this repo. The pod spec fields that would express them were not checked against a Kubernetes version here, so they are not named:

- refusing host namespaces (network, PID, IPC)
- a separate node pool or cluster so the agent does not share a kernel with other tenants
- a runtime class or a seccomp profile other than `RuntimeDefault`
- an admission policy that rejects pods missing the fields above

Until those are checked, the controls you can point at in this repo are the namespace, the ServiceAccount, the scoped OIDC subject, the NetworkPolicy, and the security context block listed above.
