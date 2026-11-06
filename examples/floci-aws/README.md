# floci-aws

Apply-level fixture for [Floci](https://github.com/floci-io/floci), a free local AWS emulator.

Exercises the AWS-only pieces of this repo against `http://localhost:4566`:

- IRSA-shaped `aws_iam_role` (same trust policy shape as `terraform/modules/api-gateway/iam.tf`)
- Optional managed-policy attachment
- Secrets Manager secret + version (pattern used by `secrets-injection.yml`)

Kubernetes / EKS resources are intentionally **not** applied here; those stay on `terraform validate`, `terraform test`, and `examples/template-render`.

## Run

```bash
# From repo root (starts Floci, apply, destroy):
make test-floci
```

Or manually with Floci already listening on `:4566`:

```bash
cd examples/floci-aws
terraform init
terraform apply -auto-approve
terraform destroy -auto-approve
```
