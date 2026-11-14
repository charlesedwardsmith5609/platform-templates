terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

module "vendor" {
  source            = "../../terraform/modules/vendor-trust"
  vendor_account_id = "111122223333"
  external_id       = "example-external-id"
  source_ip_cidrs   = ["203.0.113.0/24"]
}

output "role_name" {
  description = "Example vendor role name"
  value       = module.vendor.role_name
}
