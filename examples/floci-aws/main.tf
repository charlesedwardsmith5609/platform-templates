# AWS-only apply fixture for Floci (local AWS emulator).
# Covers the module's IRSA IAM role shape plus a Secrets Manager secret
# (used by secrets-injection.yml). Kubernetes / EKS stay on validate + render CI.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "floci_endpoint" {
  description = "Floci base URL (AWS-compatible)"
  type        = string
  default     = "http://localhost:4566"
}

variable "service_name" {
  type    = string
  default = "checkout"
}

variable "namespace" {
  type    = string
  default = "checkout"
}

variable "oidc_issuer_url" {
  type    = string
  default = "https://oidc.eks.us-west-2.amazonaws.com/id/EXAMPLE"
}

variable "oidc_audience" {
  type    = string
  default = "sts.amazonaws.com"
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    iam            = var.floci_endpoint
    sts            = var.floci_endpoint
    secretsmanager = var.floci_endpoint
  }
}

data "aws_caller_identity" "current" {}

locals {
  oidc_provider = trimprefix(var.oidc_issuer_url, "https://")
  role_name     = "${var.service_name}-gateway"
  secret_id     = "platform/staging/${var.service_name}/config"
}

# Mirrors terraform/modules/api-gateway/iam.tf IRSA trust (sub + aud).
resource "aws_iam_role" "gateway" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider}:aud" = var.oidc_audience
          "${local.oidc_provider}:sub" = "system:serviceaccount:${var.namespace}:${var.service_name}-gateway"
        }
      }
    }]
  })

  tags = {
    Environment             = "staging"
    Team                    = "payments"
    "platform.io/service"   = var.service_name
    "platform.io/component" = "api-gateway"
  }
}

# Optional attachment path exercised by var.additional_iam_policy_arns in the module.
resource "aws_iam_role_policy_attachment" "readonly" {
  role       = aws_iam_role.gateway.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Pattern used by .github/workflows/secrets-injection.yml (not provisioned by the module).
resource "aws_secretsmanager_secret" "service_config" {
  name = local.secret_id

  tags = {
    Environment = "staging"
    Service     = var.service_name
  }
}

resource "aws_secretsmanager_secret_version" "service_config" {
  secret_id = aws_secretsmanager_secret.service_config.id
  secret_string = jsonencode({
    EXAMPLE_KEY = "floci-local-only"
  })
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "iam_role_arn" {
  value = aws_iam_role.gateway.arn
}

output "iam_role_name" {
  value = aws_iam_role.gateway.name
}

output "assume_role_policy" {
  value = aws_iam_role.gateway.assume_role_policy
}

output "secret_arn" {
  value = aws_secretsmanager_secret.service_config.arn
}

output "secret_id" {
  value = aws_secretsmanager_secret.service_config.name
}
