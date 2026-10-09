# API Gateway — Envoy on EKS with IRSA, per-route policy, and an OTel sidecar.

locals {
  # Selectors must be stable; do not include mutable metadata labels here.
  selector_labels = {
    "app.kubernetes.io/name"      = var.service_name
    "app.kubernetes.io/component" = "api-gateway"
  }

  labels = merge(local.selector_labels, {
    "app.kubernetes.io/managed-by" = "terraform"
  })

  environment = lookup(var.tags, "Environment", lookup(var.tags, "environment", "unspecified"))

  resolved_routes = [
    for r in var.routes : {
      prefix       = r.prefix
      cluster      = r.cluster
      cluster_host = coalesce(r.cluster_host, "${r.cluster}.${var.namespace}.svc.cluster.local")
      port         = r.port
      timeout_s    = r.timeout_s
      retries      = r.retries
    }
  ]
}

resource "kubernetes_namespace_v1" "this" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "platform.io/service"          = var.service_name
    }
  }
}

resource "kubernetes_service_account_v1" "gateway" {
  metadata {
    name      = "${var.service_name}-gateway"
    namespace = var.namespace
    labels    = local.labels
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.gateway.arn
    }
  }

  depends_on = [kubernetes_namespace_v1.this]
}

resource "kubernetes_config_map_v1" "envoy" {
  metadata {
    name      = "${var.service_name}-envoy-config"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    "envoy.yaml" = templatefile("${path.module}/templates/envoy.yaml.tpl", {
      service_name = var.service_name
      namespace    = var.namespace
      routes       = local.resolved_routes
    })
  }

  depends_on = [kubernetes_namespace_v1.this]
}

resource "kubernetes_config_map_v1" "otel" {
  metadata {
    name      = "${var.service_name}-otel-config"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    "config.yaml" = templatefile("${path.module}/templates/otel-collector.yaml.tpl", {
      service_name           = var.service_name
      namespace              = var.namespace
      environment            = local.environment
      otel_exporter_endpoint = var.otel_exporter_endpoint
      otel_exporter_insecure = var.otel_exporter_insecure
    })
  }

  depends_on = [kubernetes_namespace_v1.this]
}

resource "kubernetes_deployment_v1" "gateway" {
  metadata {
    name      = "${var.service_name}-gateway"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = local.selector_labels
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
          # Metrics are scraped by the OTel sidecar from loopback (admin is localhost-only).
          "platform.io/metrics" = "otel-sidecar"
        }
      }

      spec {
        service_account_name             = kubernetes_service_account_v1.gateway.metadata[0].name
        termination_grace_period_seconds = 30

        security_context {
          run_as_non_root = true
          run_as_user     = 101
          run_as_group    = 101
          fs_group        = 101
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "envoy"
          image = var.envoy_image

          args = ["--config-path", "/etc/envoy/envoy.yaml", "--log-level", "info"]

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          volume_mount {
            name       = "envoy-config"
            mount_path = "/etc/envoy"
            read_only  = true
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 8080
            }
            initial_delay_seconds = 3
            period_seconds        = 5
            failure_threshold     = 3
          }

          liveness_probe {
            http_get {
              path = "/ready"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            failure_threshold     = 3
          }
        }

        container {
          name  = "otel-collector"
          image = var.otel_collector_image

          args = ["--config", "/etc/otel/config.yaml"]

          port {
            name           = "otlp-grpc"
            container_port = 4317
            protocol       = "TCP"
          }

          port {
            name           = "otlp-http"
            container_port = 4318
            protocol       = "TCP"
          }

          volume_mount {
            name       = "otel-config"
            mount_path = "/etc/otel"
            read_only  = true
          }

          volume_mount {
            name       = "otel-tmp"
            mount_path = "/tmp"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }
        }

        volume {
          name = "envoy-config"
          config_map {
            name = kubernetes_config_map_v1.envoy.metadata[0].name
          }
        }

        volume {
          name = "otel-config"
          config_map {
            name = kubernetes_config_map_v1.otel.metadata[0].name
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }

        volume {
          name = "otel-tmp"
          empty_dir {}
        }
      }
    }
  }

  depends_on = [
    kubernetes_config_map_v1.envoy,
    kubernetes_config_map_v1.otel,
  ]
}

resource "kubernetes_pod_disruption_budget_v1" "gateway" {
  metadata {
    name      = "${var.service_name}-gateway"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    min_available = 1
    selector {
      match_labels = local.selector_labels
    }
  }

  depends_on = [kubernetes_namespace_v1.this]
}

resource "kubernetes_service_v1" "gateway" {
  metadata {
    name      = "${var.service_name}-gateway"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    type     = "ClusterIP"
    selector = local.selector_labels

    port {
      name        = "http"
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_namespace_v1.this]
}

resource "kubernetes_network_policy_v1" "gateway" {
  count = var.create_network_policy ? 1 : 0

  metadata {
    name      = "${var.service_name}-gateway"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    pod_selector {
      match_labels = local.selector_labels
    }

    policy_types = ["Ingress", "Egress"]

    # Allow HTTP from anywhere in the cluster; tighten per-environment as needed.
    ingress {
      ports {
        port     = 8080
        protocol = "TCP"
      }
    }

    # Allow all egress by default so arbitrary upstream ports work.
    # Tighten with explicit ports/CIDRs per environment before production.
    egress {}
  }

  depends_on = [kubernetes_namespace_v1.this]
}
