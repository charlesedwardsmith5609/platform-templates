output "role_name" {
  description = "Name of the vendor IAM role"
  value       = aws_iam_role.vendor.name
}

output "role_arn" {
  description = "ARN of the vendor IAM role"
  value       = aws_iam_role.vendor.arn
}

output "assume_role_policy" {
  description = "Trust policy JSON. Tests read this to prove the conditions are present."
  value       = aws_iam_role.vendor.assume_role_policy
}
