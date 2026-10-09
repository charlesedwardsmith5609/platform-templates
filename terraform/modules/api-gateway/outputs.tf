output "gateway_service_name" {
  description = "Kubernetes Service name for the gateway"
  value       = kubernetes_service_v1.gateway.metadata[0].name
}

output "gateway_service_port" {
  description = "Kubernetes Service port for the gateway"
  value       = kubernetes_service_v1.gateway.spec[0].port[0].port
}

output "iam_role_arn" {
  description = "IAM role ARN attached to the gateway pod via IRSA"
  value       = aws_iam_role.gateway.arn
}

output "service_account_name" {
  description = "Kubernetes ServiceAccount name used by the gateway"
  value       = kubernetes_service_account_v1.gateway.metadata[0].name
}

output "namespace" {
  description = "Namespace where the gateway was deployed"
  value       = var.namespace
}
