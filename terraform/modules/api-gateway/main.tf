# API Gateway Module
# Provisions an Envoy-based API gateway on EKS with:
#   - OIDC workload identity for downstream service auth
#   - Configurable per-route timeout and retry policies
#   - OpenTelemetry sidecar for distributed tracing
#   - PodDisruptionBudget for zero-downtime deploys

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws        = { source = "hashicorp/aws",       version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.0" }
    helm       = { source = "hashicorp/helm",       version = "~> 2.0" }
  }
}

# ── Variables ──────────────────────────────────────────────────────────────

variable "service_name" {
  description = "Name of the service this gateway fronts (used in labels and OTel resource attributes)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into"
  type        = string
  default     = "platform"
}

variable "replicas" {
  description = "Number of gateway replicas (minimum 2 for PDB)"
  type        = number
  default     = 2
}

variable "envoy_image" {
  description = "Envoy Proxy container image"
  type        = string
  default     = "envoyproxy/envoy:v1.29-latest"
}

variable "otel_collector_image" {
  description = "OpenTelemetry Collector sidecar image"
  type        = string
  default     = "otel/opentelemetry-collector-contrib:0.100.0"
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster (for workload identity)"
  type        = string
}

variable "otel_exporter_endpoint" {
  description = "OTLP endpoint for trace/metric export (e.g. Chronosphere, Jaeger)"
  type        = string
  default     = "http://otel-collector.observability:4317"
}

variable "routes" {
  description = "List of route definitions: {prefix, cluster, timeout_s, retries}"
  type = list(object({
    prefix    = string
    cluster   = string
    timeout_s = optional(number, 15)
    retries   = optional(number, 3)
  }))
  default = []
}

variable "tags" {
  description = "AWS resource tags"
  type        = map(string)
  default     = {}
}

# ── Locals ─────────────────────────────────────────────────────────────────

locals {
  labels = {
    "app.kubernetes.io/name"       = var.service_name
    "app.kubernetes.io/component"  = "api-gateway"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

# ── OIDC Workload Identity ──────────────────────────────────────────────────

resource "aws_iam_role" "gateway" {
  name = "${var.service_name}-gateway"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${trimprefix(var.oidc_issuer_url, "https://")}" }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${trimprefix(var.oidc_issuer_url, "https://")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_name}-gateway"
        }
      }
    }]
  })

  tags = var.tags
}

data "aws_caller_identity" "current" {}

resource "kubernetes_service_account" "gateway" {
  metadata {
    name      = "${var.service_name}-gateway"
    namespace = var.namespace
    labels    = local.labels
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.gateway.arn
    }
  }
}

# ── Envoy ConfigMap ────────────────────────────────────────────────────────

resource "kubernetes_config_map" "envoy" {
  metadata {
    name      = "${var.service_name}-envoy-config"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    "envoy.yaml" = templatefile("${path.module}/templates/envoy.yaml.tpl", {
      service_name           = var.service_name
      routes                 = var.routes
      otel_exporter_endpoint = var.otel_exporter_endpoint
    })
  }
}

# ── Deployment ─────────────────────────────────────────────────────────────

resource "kubernetes_deployment" "gateway" {
  metadata {
    name      = "${var.service_name}-gateway"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = local.labels
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_unavailable = 0
        max_surge       = 1
      }
    }

    template {
      metadata {
        labels = local.labels
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "9901"
          "prometheus.io/path"   = "/stats/prometheus"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.gateway.metadata[0].name

        container {
          name  = "envoy"
          image = var.envoy_image

          args = ["--config-path", "/etc/envoy/envoy.yaml", "--log-level", "info"]

          port { container_port = 8080; name = "http" }
          port { container_port = 9901; name = "admin" }

          volume_mount {
            name       = "envoy-config"
            mount_path = "/etc/envoy"
            read_only  = true
          }

          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "500m", memory = "512Mi" }
          }

          liveness_probe {
            http_get { path = "/healthz/ready"; port = 9901 }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }

        # OTel collector sidecar
        container {
          name  = "otel-collector"
          image = var.otel_collector_image

          args = ["--config", "/etc/otel/config.yaml"]

          port { container_port = 4317; name = "otlp-grpc" }
          port { container_port = 4318; name = "otlp-http" }

          volume_mount {
            name       = "otel-config"
            mount_path = "/etc/otel"
            read_only  = true
          }

          resources {
            requests = { cpu = "50m",  memory = "64Mi" }
            limits   = { cpu = "200m", memory = "256Mi" }
          }
        }

        volume {
          name = "envoy-config"
          config_map { name = kubernetes_config_map.envoy.metadata[0].name }
        }

        volume {
          name = "otel-config"
          config_map { name = "${var.service_name}-otel-config" }
        }
      }
    }
  }
}

# ── Pod Disruption Budget ──────────────────────────────────────────────────

resource "kubernetes_pod_disruption_budget_v1" "gateway" {
  metadata {
    name      = "${var.service_name}-gateway"
    namespace = var.namespace
  }
  spec {
    min_available = 1
    selector {
      match_labels = local.labels
    }
  }
}

# ── Service ────────────────────────────────────────────────────────────────

resource "kubernetes_service" "gateway" {
  metadata {
    name      = "${var.service_name}-gateway"
    namespace = var.namespace
    labels    = local.labels
  }
  spec {
    selector = local.labels
    port {
      name        = "http"
      port        = 80
      target_port = 8080
    }
    type = "ClusterIP"
  }
}

# ── Outputs ────────────────────────────────────────────────────────────────

output "gateway_service_name" {
  value       = kubernetes_service.gateway.metadata[0].name
  description = "Kubernetes service name for the gateway"
}

output "iam_role_arn" {
  value       = aws_iam_role.gateway.arn
  description = "IAM role ARN attached to the gateway pod via OIDC"
}
