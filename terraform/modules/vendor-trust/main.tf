locals {
  string_equals = merge(
    { "sts:ExternalId" = var.external_id },
    var.principal_org_id == null ? {} : { "aws:PrincipalOrgID" = var.principal_org_id },
    length(var.source_vpce_ids) == 0 ? {} : { "aws:SourceVpce" = var.source_vpce_ids },
  )

  condition = merge(
    { StringEquals = local.string_equals },
    length(var.source_ip_cidrs) == 0 ? {} : { IpAddress = { "aws:SourceIp" = var.source_ip_cidrs } },
  )
}

resource "aws_iam_role" "vendor" {
  name = var.role_name

  lifecycle {
    # aws:PrincipalOrgID does not count: the principal is already one account.
    precondition {
      condition     = (length(var.source_ip_cidrs) > 0) != (length(var.source_vpce_ids) > 0)
      error_message = "Vendor trust requires exactly one of source_ip_cidrs (aws:SourceIp) or source_vpce_ids (aws:SourceVpce). principal_org_id is optional and cannot replace them."
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
