# platform-templates

Reusable Terraform modules and GitHub Actions workflows for platform engineering teams. Patterns covered: Envoy API gateway on EKS, OIDC workload identity (IRSA), service onboarding automation, and deploy-time secrets sync without long-lived cloud credentials.

The goal: make the safe path the easy path.

> These are **reference templates**. Wire them to your org’s cluster names, IAM boundaries, and observability backends before production use. Pin container images to digests and tighten NetworkPolicies per environment.

## Contents

### Terraform modules

| Module | What it provisions |
|--------|--------------------|
| [`terraform/modules/api-gateway`](terraform/modules/api-gateway) | Envoy gateway on EKS with IRSA, OTel sidecar, PDB, and baseline NetworkPolicy |

### GitHub Actions workflows

| Workflow | What it does |
|----------|-------------|
| [`.github/workflows/service-onboarding.yml`](.github/workflows/service-onboarding.yml) | Namespace, IRSA ServiceAccount, OTel ConfigMap, smoke checks, runbook PR |
| [`.github/workflows/secrets-injection.yml`](.github/workflows/secrets-injection.yml) | Reusable workflow: OIDC → STS → Secrets Manager → Kubernetes Secret → rollout |
| [`.github/workflows/ci.yml`](.github/workflows/ci.yml) | `terraform fmt` / `validate` and actionlint on PRs |

### Examples

| Example | Purpose |
|---------|---------|
| [`examples/api-gateway`](examples/api-gateway) | Root-module composition used by CI `terraform validate` |

---

## API Gateway module

Provisions an Envoy Proxy API gateway on EKS with:

- IRSA (OIDC) workload identity — trust policy scoped by `sub` and `aud`
- OpenTelemetry sidecar (OTLP ingest + Envoy metrics scrape on loopback)
- PodDisruptionBudget and rolling updates with `maxUnavailable=0`
- Configurable per-route timeouts, retries, and upstream ports
- Hardened pod security context; Envoy admin bound to localhost only

```hcl
module "api_gateway" {
  source = "./terraform/modules/api-gateway"

  service_name    = "checkout"
  namespace       = "checkout"
  oidc_issuer_url = "https://oidc.eks.us-west-2.amazonaws.com/id/EXAMPLE"
  replicas        = 3

  routes = [
    { prefix = "/api/v1/cart", cluster = "cart-service", timeout_s = 10 },
    { prefix = "/api/v1/order", cluster = "order-service", timeout_s = 30, retries = 2 },
    { prefix = "/api/v1/payment", cluster = "payment-service", port = 8080, timeout_s = 45, retries = 0 },
  ]

  otel_exporter_endpoint = "otel-collector.observability.svc.cluster.local:4317"

  tags = {
    Environment = "staging"
    Team        = "payments"
  }
}
```

Full input/output reference: [`terraform/modules/api-gateway/README.md`](terraform/modules/api-gateway/README.md).

---

## Service onboarding workflow

Replaces a multi-day “get a service onto the platform” checklist with one workflow run.

**In one run it:**

1. Validates service name, team slug, and SLO target  
2. Creates/labels the namespace and an IRSA-annotated ServiceAccount  
3. Deploys an OTel ConfigMap with service metadata  
4. Smoke-checks those resources  
5. Opens a PR with a runbook stub  

**Required repository secrets:** `AWS_PLATFORM_ROLE_ARN`, `AWS_REGION`, `AWS_ACCOUNT_ID`, `EKS_OIDC_PROVIDER` (e.g. `oidc.eks.us-west-2.amazonaws.com/id/EXAMPLE`), `OTEL_EXPORTER_ENDPOINT`

```yaml
# Trigger from the Actions UI or repository_dispatch (type: onboard-service)
workflow_dispatch:
  inputs:
    service_name: "checkout-api"
    team_slug:    "payments-team"
    slo_target:   "0.999"
    environment:  "staging"
```

---

## Secrets injection workflow

Deploy-time pattern (no long-lived `AWS_SECRET_ACCESS_KEY` in GitHub):

```
GitHub OIDC token → AWS STS AssumeRoleWithWebIdentity → scoped IAM role → Secrets Manager
                 → Kubernetes Secret (stringData via stdin) → Deployment envFrom → rollout
```

Sessions default to 15 minutes and use a per-run role session name. Prefer [External Secrets Operator](https://external-secrets.io/) or the Secrets Store CSI driver for continuous sync; this workflow covers deploy-time bootstrap.

```yaml
# From a service repo deploy workflow
jobs:
  deploy:
    uses: your-org/platform-templates/.github/workflows/secrets-injection.yml@main
    with:
      service_name: checkout-api
      environment:  production
    secrets:
      AWS_DEPLOY_ROLE_ARN: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
      AWS_REGION:          ${{ secrets.AWS_REGION }}
```

---

## Local checks

```bash
terraform fmt -check -recursive terraform examples
cd terraform/modules/api-gateway && terraform init -backend=false && terraform validate
cd examples/api-gateway && terraform init -backend=false && terraform validate
```

---

## Philosophy

- **OIDC everywhere** — no long-lived cloud credentials in CI or on pods  
- **OTel by default** — new services get trace/metric wiring on day one  
- **Onboarding is a product** — time-to-safe-production is a platform metric  
- **Safe by default** — PDBs, `maxUnavailable=0`, localhost admin, IRSA `aud`+`sub`, smoke checks before success  

## Contributing

PRs welcome. Each Terraform module should include:

- `main.tf` (resources), `variables.tf`, `outputs.tf`, `versions.tf`
- `README.md` with a usage example
- Templates under `templates/` when ConfigMaps are rendered
- CI coverage via `terraform validate` (see `.github/workflows/ci.yml`)
