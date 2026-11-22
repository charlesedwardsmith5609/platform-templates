# Where TLS and client authentication end for the gateway

Status: design note, docs only. No Terraform changed. Written 2026-11-21 as part of the 2026-11-20 pass; the choice between the options is left to the owner (see Open question).

## Current state: the module configures no mTLS

The api-gateway module configures no TLS and no mTLS on the request path. It never sees a client certificate.

- The Envoy listener `ingress` binds `0.0.0.0:8080` (`terraform/modules/api-gateway/templates/envoy.yaml.tpl:10-15`). Its `filter_chains` (`envoy.yaml.tpl:16`) hold only the `http_connection_manager` filter (`envoy.yaml.tpl:18`). The template has no `transport_socket`, no `DownstreamTlsContext`, no `require_client_certificate`, and no `forward_client_cert_details`: `grep -niE 'tls|transport_socket|forward_client_cert'` on the template returns nothing.
- Upstream clusters are `STRICT_DNS` to `${route.cluster_host}:${route.port}` with no `transport_socket` (`envoy.yaml.tpl:62-77`), so Envoy talks plain TCP/HTTP to backends.
- The Envoy admin interface binds `127.0.0.1:9901` (`envoy.yaml.tpl:1-7`).
- The Kubernetes Service is `ClusterIP`, port 80 to target port 8080 (`terraform/modules/api-gateway/main.tf:298-312`). The module creates no `LoadBalancer` Service, no Ingress, and no AWS load balancer; its resources are listed at `main.tf:28, 40, 53, 71, 91, 281, 298, 320`.
- The NetworkPolicy allows ingress to TCP 8080 from any source in the cluster (`main.tf:337-341`).
- The only TLS-related input is `otel_exporter_insecure` (`terraform/modules/api-gateway/variables.tf:87`). It concerns OTLP export from the sidecar, not client traffic.

So today TLS and client authentication, if any, end before this module, in whatever the caller puts in front of the ClusterIP Service.

## Option A: mTLS at Envoy (not built)

Not present in the module. It would need a `DownstreamTlsContext` on the listener, a server certificate and a CA bundle mounted into the pod, and `require_client_certificate`.

- TLS and client authentication end at Envoy, inside the cluster.
- Envoy can see the client certificate identity and could pass it to backends (for example with `forward_client_cert_details`); that is Envoy behaviour, not something this module does today.
- Revocation: not configured. It would be Envoy's CRL support or an external check, owned by whoever writes the config. Not verified here.
- Trust store: a Kubernetes Secret or ConfigMap that the module or its caller would own and rotate.
- Cost: the module takes on certificate mounting, rotation, and the TLS settings.

## Option B: mTLS at an AWS NLB in front (vendor walkthrough)

Source: the AWS networking blog "Introducing mTLS for Network Load Balancer" (https://aws.amazon.com/blogs/networking-and-content-delivery/introducing-mtls-for-network-load-balancer/), read 2026-11-21. Everything in this section is a vendor claim from that post, not verified against a running NLB.

- The NLB terminates TLS and authenticates clients in "verify mode", checking the certificate chain, expiry, and the `clientAuth` EKU. Per the post, failures close the connection and appear in NLB access logs.
- Trust store: you upload a CA bundle (and optionally a CRL) to S3 and create a trust store attached to the TLS listener. It is an AWS resource owned by whoever owns the NLB, outside this module.
- Revocation: checked by the NLB against the CRL held in the trust store, if one is added.
- Identity: optional client certificate filters admit only matching OU, CN, DNS name, or SPIFFE ID, enforced at the handshake.
- What the backend can no longer see: per the post, targets receive no client certificate data and the NLB does not pass certificate fields to them. Envoy and the backends therefore cannot log or authorize on the client identity; only the NLB filters can.
- What moves out of this repository: certificate validation, revocation, and identity filtering. What stays: the NLB itself and its target wiring are not in this module (it only offers a ClusterIP Service), so a caller would add them.
- Trust boundary (this repository's analysis, not from the post): the NLB authenticates only traffic that passes through it. The NetworkPolicy today admits port 8080 from any source in the cluster (`main.tf:337-341`), so a pod that reaches the Service directly would bypass NLB client authentication. Relying on Option B requires restricting gateway ingress to the NLB path (for example by narrowing that NetworkPolicy) as a prerequisite.
- Not read or not stated in the post: pricing, limits, supported regions, and how the NLB would reach a ClusterIP Service. Check AWS documentation before relying on it.

## Open question

Does either option belong in this repository? Recommendation: neither by default. If callers need mTLS and the NLB claims above hold, document the NLB option and keep the module small, but only together with restricting gateway ingress to the NLB path (see the trust boundary bullet). Add Envoy mTLS only when a backend needs the client identity, since Option B hides it from Envoy.
