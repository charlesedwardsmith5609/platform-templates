# platform-templates

Reusable Terraform modules and GitHub Actions workflows for platform engineering teams. Built from patterns used in production at scale — API gateway architecture, OIDC workload identity, service onboarding automation, and secrets injection without long-lived credentials.

The goal: make the safe path the easy path.

## Contents

### Terraform modules

| Module | What it provisions |
|--------|--------------------|
| `terraform/modules/api-gateway` | Envoy Proxy gateway on EKS with OIDC workload identity and OTel sidecar |

### GitHub Actions workflows

| Workflow | What it does |
|----------|-------------|
| `github-actions/service-onboarding.yml` | Full service onboarding: namespace, OIDC identity, OTel config, smoke test, runbook PR — in one workflow |
| `github-actions/secrets-injection.yml` | Zero long-lived credentials deployment via OIDC → AWS STS → Secrets Manager |

---

## API Gateway module

Provisions an Envoy Proxy API gateway on EKS with:
- OIDC workload identity (no long-lived IAM credentials on pods)
- OpenTelemetry sidecar for distributed tracing
- PodDisruptionBudget for zero-downtime rolling updates
- Configurable per-route timeouts and retry policies

```hcl
module "api_gateway" {
  source = "./terraform/modules/api-gateway"

  service_name    = "checkout"
  namespace       = "checkout"
  oidc_issuer_url = "https://oidc.eks.us-west-2.amazonaws.com/id/EXAMPLE"
  replicas        = 3

  routes = [
    { prefix = "/api/v1/cart",   cluster = "cart-service",   timeout_s = 10 },
    { prefix = "/api/v1/order",  cluster = "order-service",  timeout_s = 30, retries = 2 },
    { prefix = "/api/v1/payment",cluster = "payment-service",timeout_s = 45, retries = 0 },
  ]

  otel_exporter_endpoint = "http://otel-collector.observability:4317"
}
```

---

## Service Onboarding workflow

Replaces the typical days-long "get a service onto the platform" process with a single GitHub Actions workflow trigger.

**What it does in one run:**
1. Validates service name and SLO target
2. Bootstraps OIDC workload identity (EKS service account + IAM role binding)
3. Creates and labels Kubernetes namespace
4. Deploys OTel ConfigMap with service metadata pre-populated
5. Runs smoke tests
6. Opens a PR with an auto-generated runbook stub for the team to fill in

```yaml
# Trigger from GitHub Actions UI or via repository_dispatch
workflow_dispatch:
  inputs:
    service_name: "checkout-api"
    team_slug:    "payments-team"
    slo_target:   "0.999"
    environment:  "staging"
```

---

## Secrets Injection workflow

Zero long-lived credentials pattern:

```
GitHub OIDC token → AWS STS AssumeRoleWithWebIdentity → scoped IAM role → Secrets Manager
```

No `AWS_SECRET_ACCESS_KEY` ever stored in GitHub Secrets or touches a runner. Sessions are scoped to 15 minutes and tied to a specific deploy run ID.

```yaml
# Call from your service repo's deploy workflow
jobs:
  deploy:
    uses: your-org/platform-templates/.github/workflows/secrets-injection.yml@main
    with:
      service_name: checkout-api
      environment:  production
    secrets: inherit
```

---

## Philosophy

These templates encode the operational lessons from running platform infrastructure at scale:

- **OIDC everywhere** — no long-lived credentials, ever
- **OTel by default** — every new service ships with trace instrumentation on day one
- **Onboarding is a product** — the time from "we have a new service" to "it's safely in production" is a metric worth measuring and reducing
- **Safe by default** — PodDisruptionBudgets, rolling updates with max_unavailable=0, smoke tests before marking success

## Contributing

PRs welcome. Each module should include:
- `main.tf` with all resources
- `variables.tf` with documented inputs
- `outputs.tf`
- `README.md` with usage example
- At minimum a `terratest` or `terraform validate` in CI
