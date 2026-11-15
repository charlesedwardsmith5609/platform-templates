# Step 3 (LOW): documentation findings 8-12

Decisions: D9, D14.

## Types
Docs only; no types.

## Ownership of shared state
- Each doc file owns its own claims. `docs/vendor-access.md` is the single source for the ExternalId stance.

## Tests (written failing first)
- Shell test greps for forbidden phrases and fails first: "can do nothing", and the "not a password ... do not put it in a public repository" secrecy framing.
- `docs/vendor-access.md` states ExternalId is a non-secret, per-customer identifier that must be unique per customer, and that the role can still call GetCallerIdentity and reach resource policies that trust it.
- `docs/ci-threat-model.md` fork-PR sentence carries "needs verification" and no unconditional claim; the LiteLLM summary is reworded to match only what the cited source says (source not verified offline; recorded as an assumption).
- `docs/agent-workload-isolation.md` says the namespace is created only when `create_namespace` is true.

## Files
- docs/vendor-access.md
- docs/ci-threat-model.md
- docs/agent-workload-isolation.md
- scripts/test-docs-claims.sh
- Makefile
