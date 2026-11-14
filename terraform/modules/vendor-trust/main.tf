locals {
  string_equals = merge(
    { "sts:ExternalId" = var.external_id },
    var.principal_org_id == null ? {} : { "aws:PrincipalOrgID" = var.principal_org_id },
  )

  condition = merge(
    { StringEquals = local.string_equals },
    length(var.source_ip_cidrs) == 0 ? {} : { IpAddress = { "aws:SourceIp" = var.source_ip_cidrs } },
  )
}

resource "aws_iam_role" "vendor" {
  name = var.role_name

  lifecycle {
    precondition {
      condition     = length(var.source_ip_cidrs) > 0 || (var.principal_org_id != null && var.principal_org_id != "")
      error_message = "Vendor trust requires aws:SourceIp or aws:PrincipalOrgID. Set source_ip_cidrs or principal_org_id."
    }
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${var.vendor_account_id}:root"
      }
      Action    = "sts:AssumeRole"
      Condition = local.condition
    }]
  })

  tags = var.tags
}
