# The vendor role must not plan without ExternalId and a second condition.

mock_provider "aws" {}

variables {
  vendor_account_id = "111122223333"
  external_id       = "vendor-external-id"
  source_ip_cidrs   = ["203.0.113.0/24"]
  role_name         = "vendor-access"
  tags = {
    team    = "platform"
    service = "vendor-bridge"
    env     = "prod"
  }
}

run "source_ip_trust_contains_external_id_and_source_ip" {
  command = plan

  assert {
    condition = (
      strcontains(aws_iam_role.vendor.assume_role_policy, "sts:ExternalId")
      && strcontains(aws_iam_role.vendor.assume_role_policy, "aws:SourceIp")
      && strcontains(aws_iam_role.vendor.assume_role_policy, "203.0.113.0/24")
    )
    error_message = "Trust policy must require sts:ExternalId and aws:SourceIp."
  }
}

run "org_id_trust_contains_external_id_and_org" {
  command = plan

  variables {
    source_ip_cidrs  = []
    principal_org_id = "o-abc1234567"
  }

  assert {
    condition = (
      strcontains(aws_iam_role.vendor.assume_role_policy, "sts:ExternalId")
      && strcontains(aws_iam_role.vendor.assume_role_policy, "aws:PrincipalOrgID")
      && strcontains(aws_iam_role.vendor.assume_role_policy, "o-abc1234567")
    )
    error_message = "Trust policy must require sts:ExternalId and aws:PrincipalOrgID when no source IP is set."
  }
}

run "missing_external_id_fails" {
  command = plan

  variables {
    external_id = ""
  }

  expect_failures = [
    var.external_id,
  ]
}

run "missing_team_tag_fails" {
  command = plan

  variables {
    tags = {
      service = "vendor-bridge"
      env     = "prod"
    }
  }

  expect_failures = [
    var.tags,
  ]
}

run "missing_source_ip_and_org_fails" {
  command = plan

  variables {
    source_ip_cidrs  = []
    principal_org_id = null
  }

  expect_failures = [
    aws_iam_role.vendor,
  ]
}
