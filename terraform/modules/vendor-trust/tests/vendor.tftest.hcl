# The vendor role must not plan without ExternalId and a source condition.
# Policies are decoded with jsondecode and checked field by field.

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

run "source_ip_trust_policy_structure" {
  command = plan

  assert {
    condition     = length(jsondecode(aws_iam_role.vendor.assume_role_policy).Statement) == 1
    error_message = "Trust policy must have exactly one statement."
  }
  assert {
    condition     = jsondecode(aws_iam_role.vendor.assume_role_policy).Statement[0].Effect == "Allow"
    error_message = "Effect must be Allow."
  }
  assert {
    condition     = jsondecode(aws_iam_role.vendor.assume_role_policy).Statement[0].Action == "sts:AssumeRole"
    error_message = "Action must be sts:AssumeRole."
  }
  assert {
    condition     = jsondecode(aws_iam_role.vendor.assume_role_policy).Statement[0].Principal.AWS == "arn:aws:iam::111122223333:root"
    error_message = "Principal must be the vendor account root."
  }
  assert {
    condition     = jsondecode(aws_iam_role.vendor.assume_role_policy).Statement[0].Condition.StringEquals["sts:ExternalId"] == "vendor-external-id"
    error_message = "StringEquals must require sts:ExternalId."
  }
  assert {
    condition     = jsondecode(aws_iam_role.vendor.assume_role_policy).Statement[0].Condition.IpAddress["aws:SourceIp"] == ["203.0.113.0/24"]
    error_message = "IpAddress must require aws:SourceIp."
  }
  assert {
    condition     = !contains(keys(jsondecode(aws_iam_role.vendor.assume_role_policy).Statement[0].Condition.StringEquals), "aws:PrincipalOrgID")
    error_message = "Org id condition must be absent when principal_org_id is null."
  }
}

run "vpce_only_is_accepted" {
  command = plan

  variables {
    source_ip_cidrs = []
    source_vpce_ids = ["vpce-0123456789abcdef0"]
  }

  assert {
    condition     = jsondecode(aws_iam_role.vendor.assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceVpce"] == ["vpce-0123456789abcdef0"]
    error_message = "StringEquals must require aws:SourceVpce."
  }
  assert {
    condition     = !contains(keys(jsondecode(aws_iam_role.vendor.assume_role_policy).Statement[0].Condition), "IpAddress")
    error_message = "IpAddress must be absent when only a VPC endpoint is set."
  }
}

run "org_id_is_added_next_to_a_valid_second_condition" {
  command = plan

  variables {
    principal_org_id = "o-abc1234567"
  }

  assert {
    condition     = jsondecode(aws_iam_role.vendor.assume_role_policy).Statement[0].Condition.StringEquals["aws:PrincipalOrgID"] == "o-abc1234567"
    error_message = "Org id must be added to StringEquals."
  }
  assert {
    condition     = jsondecode(aws_iam_role.vendor.assume_role_policy).Statement[0].Condition.IpAddress["aws:SourceIp"] == ["203.0.113.0/24"]
    error_message = "Source IP must still be required."
  }
}

run "org_id_alone_fails" {
  command = plan

  variables {
    source_ip_cidrs  = []
    principal_org_id = "o-abc1234567"
  }

  expect_failures = [
    aws_iam_role.vendor,
  ]
}

run "neither_source_condition_fails" {
  command = plan

  variables {
    source_ip_cidrs  = []
    source_vpce_ids  = []
    principal_org_id = null
  }

  expect_failures = [
    aws_iam_role.vendor,
  ]
}

run "both_source_conditions_fail" {
  command = plan

  variables {
    source_vpce_ids = ["vpce-0123456789abcdef0"]
  }

  expect_failures = [
    aws_iam_role.vendor,
  ]
}

run "ipv4_any_fails" {
  command = plan

  variables {
    source_ip_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [
    var.source_ip_cidrs,
  ]
}

run "ipv6_any_fails" {
  command = plan

  variables {
    source_ip_cidrs = ["::/0"]
  }

  expect_failures = [
    var.source_ip_cidrs,
  ]
}

run "garbage_cidr_fails" {
  command = plan

  variables {
    source_ip_cidrs = ["not-a-cidr"]
  }

  expect_failures = [
    var.source_ip_cidrs,
  ]
}

# nullable = false: a null list is replaced by the default (empty), so with no
# VPC endpoint either the role precondition rejects it.
run "null_cidr_list_fails" {
  command = plan

  variables {
    source_ip_cidrs = null
  }

  expect_failures = [
    aws_iam_role.vendor,
  ]
}

run "bad_vpce_id_fails" {
  command = plan

  variables {
    source_ip_cidrs = []
    source_vpce_ids = ["vpce-XYZ"]
  }

  expect_failures = [
    var.source_vpce_ids,
  ]
}

run "bad_org_id_fails" {
  command = plan

  variables {
    principal_org_id = "org-123"
  }

  expect_failures = [
    var.principal_org_id,
  ]
}

run "empty_external_id_fails" {
  command = plan

  variables {
    external_id = ""
  }

  expect_failures = [
    var.external_id,
  ]
}

run "whitespace_external_id_fails" {
  command = plan

  variables {
    external_id = "   "
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

run "missing_service_tag_fails" {
  command = plan

  variables {
    tags = {
      team = "platform"
      env  = "prod"
    }
  }

  expect_failures = [
    var.tags,
  ]
}

run "missing_env_tag_fails" {
  command = plan

  variables {
    tags = {
      team    = "platform"
      service = "vendor-bridge"
    }
  }

  expect_failures = [
    var.tags,
  ]
}

run "blank_tag_fails" {
  command = plan

  variables {
    tags = {
      team    = "platform"
      service = "   "
      env     = "prod"
    }
  }

  expect_failures = [
    var.tags,
  ]
}
