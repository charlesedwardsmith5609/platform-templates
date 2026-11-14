# api-gateway example

Root-module wiring used by CI to `terraform validate` the module composition.

Providers are stubbed so validation works without credentials. This configuration is **not** meant to be applied.

```bash
terraform init -backend=false
terraform validate
```

The committed `.terraform.lock.hcl` lists a single `h1:` hash for each of the `aws` and `kubernetes` providers. Only the vendor-trust module and example carry two.

For a real cluster, replace the provider blocks with your EKS exec/kubeconfig auth and normal AWS credentials (or OIDC).
