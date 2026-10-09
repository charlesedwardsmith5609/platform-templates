data "aws_caller_identity" "current" {}

locals {
  oidc_provider = trimprefix(var.oidc_issuer_url, "https://")
}

resource "aws_iam_role" "gateway" {
  name = "${var.service_name}-gateway"

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

  tags = merge(var.tags, {
    "platform.io/service"   = var.service_name
    "platform.io/component" = "api-gateway"
  })
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = toset(var.additional_iam_policy_arns)

  role       = aws_iam_role.gateway.name
  policy_arn = each.value
}
