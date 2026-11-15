variable "vendor_account_id" {
  description = "AWS account id of the vendor that may assume this role"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.vendor_account_id))
    error_message = "vendor_account_id must be a 12 digit AWS account id."
  }
}

variable "external_id" {
  description = "Value required in sts:ExternalId. The vendor must present this exact string. Not a secret, but unique per customer."
  type        = string

  validation {
    condition     = length(var.external_id) >= 2 && length(var.external_id) <= 1224
    error_message = "external_id must be 2 to 1224 characters."
  }

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@:/_-]+$", var.external_id))
    error_message = "external_id may only contain letters, digits, and + = , . @ : / _ - (the STS ExternalId character set)."
  }

  validation {
    condition     = !contains(["replace-me", "example-external-id", "changeme"], lower(var.external_id))
    error_message = "external_id must not be a placeholder value. Use a unique per-customer value."
  }
}

variable "source_ip_cidrs" {
  description = "CIDRs for aws:SourceIp. Set this or source_vpce_ids, not both. A /0 range is rejected."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for cidr in var.source_ip_cidrs : can(cidrhost(cidr, 0)) && !endswith(cidr, "/0")])
    error_message = "source_ip_cidrs entries must be valid CIDR blocks and must not be a /0 range."
  }
}

variable "source_vpce_ids" {
  description = "VPC endpoint ids for aws:SourceVpce. Set this or source_ip_cidrs, not both."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for id in var.source_vpce_ids : can(regex("^vpce-[0-9a-f]{8,17}$", id))])
    error_message = "source_vpce_ids entries must look like vpce-0123456789abcdef0."
  }
}

variable "principal_org_id" {
  description = "Optional aws:PrincipalOrgID, added on top of the source condition. It is never enough on its own. Null omits it."
  type        = string
  default     = null

  validation {
    condition     = var.principal_org_id == null || can(regex("^o-[a-z0-9]{10,32}$", var.principal_org_id))
    error_message = "principal_org_id must look like o- followed by 10 to 32 lowercase letters or digits."
  }
}

variable "role_name" {
  description = "Name of the IAM role the vendor assumes"
  type        = string
  default     = "vendor-access"

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.role_name))
    error_message = "role_name must be 1 to 64 characters from the IAM role name set."
  }
}

variable "tags" {
  description = "Cost-attribution tags. team, service, and env are required and must be non-empty."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["team", "service", "env"] : length(trimspace(lookup(var.tags, key, ""))) > 0
    ])
    error_message = "tags must include non-empty team, service, and env."
  }
}
