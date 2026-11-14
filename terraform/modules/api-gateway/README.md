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
| terraform | >= 1.5 (`terraform test` uses `mock_provider`, which needs 1.7 or later) |
| aws | ~> 5.0 |
| kubernetes | ~> 2.0 |

Providers must be configured by the root module (EKS kubeconfig / exec auth for `kubernetes`, standard AWS credentials/OIDC for `aws`).

## What it creates

| Resource | Purpose |
|----------|---------|
| `aws_iam_role` (+ optional `aws_iam_role_policy_attachment`) | IRSA role trusted for one ServiceAccount `sub` and `aud` |
| `kubernetes_service_account_v1` | SA annotated with the role ARN |
| `kubernetes_config_map_v1` ×2 | Envoy bootstrap + OTel collector config |
| `kubernetes_deployment_v1` | Envoy + OTel sidecar, rolling update `maxUnavailable=0` |
| `kubernetes_pod_disruption_budget_v1` | `minAvailable=1` |
| `kubernetes_service_v1` | ClusterIP on port 80 → 8080 |
| `kubernetes_network_policy_v1` (when `create_network_policy`) | Baseline policy: ingress on TCP 8080, empty `egress` block (allows all egress). Tighten per environment |
| `kubernetes_namespace_v1` (optional) | Created when `create_namespace=true` |

## Security notes

- Admin interface binds to `127.0.0.1:9901` and is **not** exposed on the Service.
- Readiness/liveness probe the data-plane `/ready` route on port 8080.
- Pod runs as non-root UID/GID 101 with `seccomp_profile` `RuntimeDefault`. Both containers drop all capabilities, disallow privilege escalation, and use a read-only root FS.
- IRSA trust policy requires both `sub` and `aud`.
- `envoy_image` / `otel_collector_image` defaults are digest-pinned (`tag@sha256:…`); variable validation rejects unpinned overrides.

## Tests

```bash
terraform init -backend=false
terraform test
```

See [`tests/gateway.tftest.hcl`](tests/gateway.tftest.hcl) for plan assertions (IRSA trust, localhost admin, digest pin) and validation failure cases.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `service_name` | `string` | none (required) | Service the gateway fronts. Lowercase alphanumerics and hyphens, 3 to 63 characters. Names the role, ServiceAccount, and other objects `<service_name>-gateway`. |
| `namespace` | `string` | `"platform"` | Kubernetes namespace to deploy into. |
| `create_namespace` | `bool` | `true` | Create the namespace. |
| `replicas` | `number` | `2` | Gateway replicas. Must be >= 2. |
| `envoy_image` | `string` | digest-pinned `envoyproxy/envoy:v1.29.7@sha256:…` | Must end in `@sha256:` plus 64 hex characters. |
| `otel_collector_image` | `string` | digest-pinned `otel/opentelemetry-collector-contrib:0.100.0@sha256:…` | Same digest rule. |
| `oidc_issuer_url` | `string` | none (required) | EKS OIDC issuer URL. Must start with `https://`. |
| `oidc_audience` | `string` | `"sts.amazonaws.com"` | Expected `aud` in the IRSA trust policy. |
| `additional_iam_policy_arns` | `list(string)` | `[]` | Managed policy ARNs attached to the role. |
| `otel_exporter_endpoint` | `string` | `"otel-collector.observability.svc.cluster.local:4317"` | OTLP gRPC endpoint for the sidecar. |
| `otel_exporter_insecure` | `bool` | `true` | Disable TLS to the OTLP endpoint. |
| `routes` | `list(object)` | `[]` | Each route has `prefix` (must start with `/`), `cluster`, optional `cluster_host`, `port` (default 80, > 0), `timeout_s` (default 15, > 0), and `retries` (default 3, >= 0). |
| `create_network_policy` | `bool` | `true` | Create the baseline NetworkPolicy. |
| `tags` | `map(string)` | `{}` | AWS tags on the IAM role. The module adds `platform.io/service` and `platform.io/component`. |

## Outputs

| Name | Description |
|------|-------------|
| `gateway_service_name` | Kubernetes Service name for the gateway. |
| `gateway_service_port` | Kubernetes Service port (80). |
| `iam_role_arn` | IAM role ARN attached to the gateway pod via IRSA. |
| `service_account_name` | ServiceAccount name used by the gateway. |
| `namespace` | Namespace the gateway was deployed to (`var.namespace`). |
