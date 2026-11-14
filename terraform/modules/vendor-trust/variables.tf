variable "vendor_account_id" {
  description = "AWS account id of the vendor that may assume this role"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.vendor_account_id))
    error_message = "vendor_account_id must be a 12 digit AWS account id."
  }
}

variable "external_id" {
  description = "Value required in sts:ExternalId. The vendor must present this exact string."
  type        = string

  validation {
    condition     = length(var.external_id) > 0 && length(var.external_id) <= 1224
    error_message = "external_id must be 1 to 1224 characters. An empty value is not a secret."
  }
}

variable "source_ip_cidrs" {
  description = "CIDRs for aws:SourceIp. Empty is allowed only when principal_org_id is set."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.source_ip_cidrs : length(cidr) > 0])
    error_message = "source_ip_cidrs entries must be non-empty. The role precondition requires this list or principal_org_id."
  }
}

variable "principal_org_id" {
  description = "Optional aws:PrincipalOrgID. Set this or source_ip_cidrs. Null means the condition is omitted."
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
