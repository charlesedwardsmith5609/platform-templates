# Step 7: mTLS termination note, Dependabot cooldown

Branch: `improve/tldr-2026-11-20`, stacked on `improve/tldr-2026-11-17` (step 6 plan).

Assumptions (stated up front, per CLAUDE.md rule 9):

- The owner is not answering during this pass (unattended policy in the owner's brief). Item 1
  is docs only and item 2 has a stated default (7 days), so both may be built, each as its own
  commit, flagged "pending owner confirmation". Nothing else is built.
- The owner's brief names the source URLs and asks to read them. That counts as approval for
  outbound reads of `aws.amazon.com` and `docs.github.com` only (CLAUDE.md rule 11). The planner
  already read the Dependabot reference at plan time (results below); the implementer re-reads
  once to confirm nothing changed.

## Item 1: `docs/mtls-termination.md` (design note, build: docs + doc tests)

### Findings from code (the module, not the examples)

The module configures no TLS and no mTLS on the request path. Say this plainly in the note.

- Envoy listener `ingress` binds `0.0.0.0:8080`
  (`terraform/modules/api-gateway/templates/envoy.yaml.tpl` lines 11-15). Its `filter_chains`
  (line 16) hold only `http_connection_manager` (line 18). There is no `transport_socket`, no
  `DownstreamTlsContext`, no `require_client_certificate`, and no `forward_client_cert_details`
  anywhere in the template (`grep -niE 'tls|transport_socket|forward_client_cert'` on the
  template returns nothing).
- Upstream clusters (`envoy.yaml.tpl` lines 63-77) are `STRICT_DNS` to
  `${route.cluster_host}:${route.port}` with no `transport_socket`: plain TCP/HTTP to backends.
- Envoy admin binds `127.0.0.1:9901` (lines 1-7).
- Kubernetes Service `kubernetes_service_v1.gateway` is `ClusterIP`, port 80 to target 8080
  (`terraform/modules/api-gateway/main.tf` lines 298-318). The module creates no
  `LoadBalancer` Service, no Ingress, and no AWS load balancer (resources listed at `main.tf`
  lines 28, 40, 53, 71, 91, 281, 298, 320).
- NetworkPolicy allows ingress to 8080 from anywhere in the cluster (`main.tf` lines 336-341).
- The only TLS knob is `otel_exporter_insecure` (`variables.tf` lines 87-89), which is for the
  OTLP export from the sidecar, not client traffic.

So today: TLS and client authentication, if any, end before the module, in whatever the caller
puts in front of the ClusterIP Service. The module itself never sees a client certificate.

### Comparison the note must make

Option A: mTLS at Envoy (not built today; would need a `DownstreamTlsContext` on the listener,
a mounted CA bundle and server cert, and `require_client_certificate`).

Option B: mTLS at an AWS NLB in front (the vendor walkthrough).

For each option state: where TLS ends; where client authentication ends; what the backend can
see (with B the client cert identity stops at the NLB, Envoy sees only what the NLB passes
on; do not claim the NLB forwards cert identity unless the source says so); where revocation is
checked; who owns the trust store (with B an AWS-side trust store, owned by whoever owns the
NLB, outside this module; with A a Kubernetes Secret/ConfigMap the module or caller owns); what
moves out of this repository.

NLB feature claims (trust store, revocation checks, certificate identity filters) come only from
the blog https://aws.amazon.com/blogs/networking-and-content-delivery/introducing-mtls-for-network-load-balancer/
and are labelled as vendor claims. At plan time the blog body could not be read (the fetch
returned only site navigation). The implementer tries once more; if it still cannot be read,
the note says so and states the NLB features only as "the TLDR summary says", with no detail
beyond the item text.

Source rule (plan-review finding 2): if the blog is still unreadable, the Option B column is
limited to what the item text itself says (NLB supports mTLS with a trust store, revocation
checks, certificate identity filters), attributed as "per the TLDR summary, not verified". The
trust-store owner, where authentication ends, and identity forwarding are then marked
"unresolved: source not read", and the note makes no recommendation for B. Option A and the
current-state section use only verified module code.

Open question recorded in the note: does either option belong in this repository?

### Tests (written failing first)

Extend `scripts/test-docs-claims.sh`:

- `docs/mtls-termination.md` exists.
- It contains `configures no mTLS` (exact phrase, so the plain statement cannot be dropped).
- It cites `envoy.yaml.tpl:` and `main.tf:` (at least one `path:line` each).
- It contains `Open question`.
- It lacks `transport_socket` claims of the form `the module sets transport_socket` (negative).

Run before writing the doc (fails), then after (passes).

### Done

Doc written, every module claim has `path:line`, doc test passes, CHANGELOG bullet under a new
`## [Unreleased] - 2026-11-20` heading, README gets one link line next to the other docs links
(`README.md` line 143 area). One commit: "Add mTLS termination design note". No Terraform change.

## Item 2: Dependabot cooldown, 7 days (build on the stated default)

### Docs check (done at plan time, from docs.github.com)

Read: Dependabot options reference, `cooldown` section, and the linked tutorial
"Optimizing PR creation for version updates".

- Keys: `default-days`, `semver-major-days`, `semver-minor-days`, `semver-patch-days`,
  `include`, `exclude` (each list up to 150 items, wildcards allowed; `exclude` wins over
  `include`). Day values 1 to 90 (tutorial).
- `github-actions` and `terraform` do NOT support the `semver-*` keys; only `default-days`
  applies to them (support table; read from the table's cell labels, so the implementer
  re-confirms).
- Security updates are exempt: "The `cooldown` option is only available for version updates,
  not security updates." Confirmed, the owner's belief holds.
- Not confirmed: whether a cooldown entry also changes grouped updates. Not relevant here (no
  groups in `.github/dependabot.yml`).

### Change

`.github/dependabot.yml` (current entries at lines 3-7, 9-13, 15-19). Add to each of the three
entries:

```yaml
    cooldown:
      default-days: 7
```

No `semver-*`, no include/exclude. Schedules, directories and limits unchanged.

`DECISIONS.md`: new entry "2026-11-20: Dependabot cooldown is 7 days (pending owner
confirmation)". Context: compromised releases (agent-framework on PyPI, WPPConnect) were caught
within days; Chainguard uses a 7-day cooldown (vendor claims, cited by URL, not verified
here). Choice: `default-days: 7` on all three entries. Why: a signed or provenance-attested
release can still be malicious, so provenance is not safety; waiting lets the ecosystem flag a
bad release first. Security updates are not delayed (docs quote above). Cost: version bumps
land up to a week later.

`README.md` line 290: cadence column becomes "Weekly Dependabot, 7-day cooldown on version
updates; merge after CI green". Line 292 unchanged.

`CHANGELOG.md`: bullet under the 2026-11-20 heading, marked pending owner confirmation.

### Tests (written failing first)

New `scripts/test-dependabot-config.sh` (bash + awk only; no `yq`/`jq`, those are not allowed
dependencies and `jq` is not installed here):

- For each `- package-ecosystem:` block, fail unless it contains `cooldown:` followed by
  `default-days: 7`.
- Fail if any `github-actions` or `terraform` block has a `semver-` key (unsupported there).
- Fail if the file has fewer than 3 entries (guards against the awk matching nothing).
- Fixture cases (plan-review finding 3): the checker takes a file path argument (default
  `.github/dependabot.yml`). Fixture A: three otherwise-valid entries, one missing `cooldown`,
  must fail. Fixture B: three valid entries, must pass. Fixture C: a `terraform` entry with
  `semver-major-days`, must fail. Fixtures are here-docs written to a `mktemp` dir.

Wire it into `scripts/checks/shell.sh` under "repo shell tests" (one `run` line next to line
34). Run it before editing `dependabot.yml` (fails), then after (passes).

One commit: "Add 7-day Dependabot cooldown". Flag "implemented on the stated default, pending
owner confirmation".

## Gate (both items)

- `bash scripts/check.sh`; there is no `make check` target.
- At plan time `terraform`, `tflint`, `shellcheck`, `actionlint`, `docker`, `jq` are missing;
  `gitleaks` is in `~/go/bin` (add to `PATH`). Expect `shell` to fail on SKIPs; rerun with
  `ALLOW_SKIP=1` and report each SKIP as NOT RUN. actionlint is CI-only anyway; the
  `dependabot.yml` schema is therefore not machine-validated locally (say so).
- `bash scripts/cross-review.sh` on each item's diff before its commit.
- Action SHAs and every job's `permissions` block are untouched (no workflow file edits).

## Ownership of shared state

None at runtime. `docs/mtls-termination.md` owns the termination claims; `.github/dependabot.yml`
owns the update policy, recorded in `DECISIONS.md`.

## Files

- plans/step-7.md
- docs/mtls-termination.md
- scripts/test-docs-claims.sh
- .github/dependabot.yml
- scripts/test-dependabot-config.sh
- scripts/checks/shell.sh
- DECISIONS.md
- README.md
- CHANGELOG.md

## Plan review (cross-model)

`bash scripts/plan-review.sh plans/step-7.md` ran on 2026-11-21 with openai (`gpt-6.1-sol`),
saved under `.reviews/` (git-ignored).

1. HIGH: implementing without explicit approval breaks CLAUDE.md rules 1 and 5. Disagree,
   recorded. The human-authorized exception is the owner's brief for this pass ("Unattended
   policy": do not stop for approval; docs, tests, or items with a stated default MAY be
   implemented on that default as their own commit, flagged pending owner confirmation).
   Item 1 is docs; item 2 has the stated 7-day default. Commits stay local, unpushed, and
   revertible. Open question 0 asks the owner to confirm.
2. MEDIUM: unverified NLB claims could become guidance. Agree; source rule added to item 1.
3. MEDIUM: one-entry negative fixture is masked by the 3-entry guard. Agree; three fixtures.

## Open questions for the owner

0. (Gate disagreement, see Plan review.) Confirm the unattended commits for items 1 and 2, or
   reset them. Recommendation: review both diffs; they are docs and a config default only.
1. Does mTLS belong in this repo at all, and if so, at Envoy or at an NLB? Recommendation:
   neither as a default. If the NLB source is verified and callers need mTLS, document the NLB
   option (keeps the module small); add Envoy mTLS only when a backend needs the client
   identity.
2. Is 7 days right for both ecosystems? Recommendation: yes; consider 3 days for `terraform`
   providers if provider bug fixes are urgent more often than not.
3. Add a Dependabot entry for `terraform/modules/vendor-trust` and `examples/vendor-trust`
   (README line 292 says none exists)? Recommendation: yes, with the same cooldown, in a
   separate approved step.
