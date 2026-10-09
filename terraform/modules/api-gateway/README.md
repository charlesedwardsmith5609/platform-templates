# api-gateway

Envoy Proxy API gateway for EKS with IRSA (OIDC workload identity), per-route timeouts/retries, an OpenTelemetry sidecar, PodDisruptionBudget, and a baseline NetworkPolicy.

## Usage

```hcl
module "api_gateway" {
  source = "../../modules/api-gateway"

  service_name    = "checkout"
  namespace       = "checkout"
  oidc_issuer_url = "https://oidc.eks.us-west-2.amazonaws.com/id/EXAMPLE"
  replicas        = 3

  routes = [
    { prefix = "/api/v1/cart", cluster = "cart-service", timeout_s = 10 },
    { prefix = "/api/v1/order", cluster = "order-service", timeout_s = 30, retries = 2 },
    {
      prefix  = "/api/v1/payment"
      cluster = "payment-service"
      port    = 8080
      timeout_s = 45
      retries   = 0
    },
  ]

  otel_exporter_endpoint = "otel-collector.observability.svc.cluster.local:4317"

  tags = {
    Environment = "staging"
    Team        = "payments"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | ~> 5.0 |
| kubernetes | ~> 2.0 |

Providers must be configured by the root module (EKS kubeconfig / exec auth for `kubernetes`, standard AWS credentials/OIDC for `aws`).

## What it creates

| Resource | Purpose |
|----------|---------|
| `aws_iam_role` (+ optional policy attachments) | IRSA role trusted for one ServiceAccount `sub` and `aud` |
| `kubernetes_service_account` | SA annotated with the role ARN |
| `kubernetes_config_map` ×2 | Envoy bootstrap + OTel collector config |
| `kubernetes_deployment` | Envoy + OTel sidecar, rolling update `maxUnavailable=0` |
| `kubernetes_pod_disruption_budget` | `minAvailable=1` |
| `kubernetes_service` | ClusterIP on port 80 → 8080 |
| `kubernetes_network_policy` | Baseline ingress/egress (tighten per environment) |
| `kubernetes_namespace` (optional) | Created when `create_namespace=true` |

## Security notes

- Admin interface binds to `127.0.0.1:9901` and is **not** exposed on the Service.
- Readiness/liveness probe the data-plane `/ready` route on port 8080.
- Containers run as UID 101, drop all capabilities, read-only root FS.
- IRSA trust policy requires both `sub` and `aud`.
- Pin `envoy_image` / `otel_collector_image` to digests before production.

## Inputs / outputs

See [`variables.tf`](variables.tf) and [`outputs.tf`](outputs.tf).
