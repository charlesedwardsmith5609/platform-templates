# CI-only composition that exercises templatefile() without AWS/Kubernetes providers.

terraform {
  required_version = ">= 1.5"
}

locals {
  rendered_envoy = templatefile("${path.module}/../../terraform/modules/api-gateway/templates/envoy.yaml.tpl", {
    service_name = "checkout"
    namespace    = "checkout"
    routes = [{
      prefix       = "/api/v1/cart"
      cluster      = "cart-service"
      cluster_host = "cart-service.checkout.svc.cluster.local"
      port         = 80
      timeout_s    = 10
      retries      = 3
    }]
  })

  rendered_otel = templatefile("${path.module}/../../terraform/modules/api-gateway/templates/otel-collector.yaml.tpl", {
    service_name           = "checkout"
    namespace              = "checkout"
    environment            = "staging"
    otel_exporter_endpoint = "otel-collector.observability.svc.cluster.local:4317"
    otel_exporter_insecure = true
  })
}

output "envoy" {
  value = local.rendered_envoy
}

output "otel" {
  value = local.rendered_otel
}
