# Example only. The OIDC subject is one repository and one ref.
# scripts/check-oidc-trust.sh fails if this subject becomes a wildcard.

locals {
  github_oidc_trust = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:example-org/example-repo:ref:refs/heads/main"
        }
      }
    }]
  })
}
