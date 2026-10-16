variable "service_name" {
  description = "Name of the service this gateway fronts (used in labels and OTel resource attributes)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,61}[a-z0-9]$", var.service_name))
    error_message = "service_name must be lowercase alphanumeric with hyphens, 3–63 characters."
  }
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into"
  type        = string
  default     = "platform"
}

variable "create_namespace" {
  description = "Whether to create the Kubernetes namespace if it does not exist"
  type        = bool
  default     = true
}

variable "replicas" {
  description = "Number of gateway replicas (minimum 2 so the PDB can protect availability)"
  type        = number
  default     = 2

  validation {
    condition     = var.replicas >= 2
    error_message = "replicas must be >= 2 so PodDisruptionBudget min_available=1 is meaningful."
  }
}

variable "envoy_image" {
  description = "Envoy Proxy container image (pin to a digest in production)"
  type        = string
  default     = "envoyproxy/envoy:v1.29.7"
}

variable "otel_collector_image" {
  description = "OpenTelemetry Collector sidecar image (pin to a digest in production)"
  type        = string
  default     = "otel/opentelemetry-collector-contrib:0.100.0"
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster (e.g. https://oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE)"
  type        = string

  validation {
    condition     = startswith(var.oidc_issuer_url, "https://")
    error_message = "oidc_issuer_url must be an https:// URL."
  }
}

variable "oidc_audience" {
  description = "Expected audience claim on the IRSA web identity token"
  type        = string
  default     = "sts.amazonaws.com"
}

variable "additional_iam_policy_arns" {
  description = "Optional IAM managed policy ARNs to attach to the gateway IRSA role (e.g. Secrets Manager read for a specific prefix)"
  type        = list(string)
  default     = []
}

variable "otel_exporter_endpoint" {
  description = "OTLP gRPC endpoint for the sidecar to export traces/metrics to (in-cluster collector recommended)"
  type        = string
  default     = "otel-collector.observability.svc.cluster.local:4317"
}

variable "otel_exporter_insecure" {
  description = "Disable TLS when exporting to the OTLP endpoint (typical for in-cluster collectors)"
  type        = bool
  default     = true
}

variable "routes" {
  description = "Upstream route definitions. cluster is the Kubernetes service DNS short name in the same namespace unless cluster_host is set."
  type = list(object({
    prefix       = string
    cluster      = string
    cluster_host = optional(string)
    port         = optional(number, 80)
    timeout_s    = optional(number, 15)
    retries      = optional(number, 3)
  }))
  default = []

  validation {
    condition = alltrue([
      for r in var.routes :
      startswith(r.prefix, "/") && r.timeout_s > 0 && r.retries >= 0 && r.port > 0
    ])
    error_message = "Each route needs a /prefix, timeout_s > 0, retries >= 0, and port > 0."
  }
}

variable "create_network_policy" {
  description = "Create a baseline NetworkPolicy (disable on clusters without a policy-capable CNI)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "AWS resource tags applied to the IAM role"
  type        = map(string)
  default     = {}
}
