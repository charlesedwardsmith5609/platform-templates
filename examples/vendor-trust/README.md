# vendor-trust example

Composition used by CI `terraform validate`. It does not apply a real role. The external id here (`acme-7f3a9c1e-prod`) is an example value, not a secret. It restricts the role to one documentation CIDR (`203.0.113.0/24`) with `source_ip_cidrs`.

Requires Terraform 1.7.0 or later. The committed `.terraform.lock.hcl` lists two `h1:` hashes for the `aws` provider. `examples/api-gateway` and `examples/floci-aws` lock files list one hash per provider.

```bash
terraform init -backend=false
terraform validate
```
