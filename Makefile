# Local helpers mirroring CI. Default goal is help.

.PHONY: help test-floci fmt-check check-action-pins test-check-action-pins check-oidc-trust test-check-oidc-trust

help:
	@echo "Targets:"
	@echo "  test-floci              Start Floci, terraform apply/destroy examples/floci-aws"
	@echo "  fmt-check               terraform fmt -check -recursive terraform examples"
	@echo "  check-action-pins       Fail if any third-party uses: lacks a 40-char SHA"
	@echo "  test-check-action-pins  Unit tests for the action pin checker"
	@echo "  check-oidc-trust        Fail on wildcard or missing GitHub Actions OIDC sub"
	@echo "  test-check-oidc-trust   Unit tests for the OIDC trust checker"

test-floci:
	./scripts/test-floci.sh

fmt-check:
	terraform fmt -check -recursive terraform examples

check-action-pins:
	./scripts/check-action-pins.sh

test-check-action-pins:
	./scripts/test-check-action-pins.sh

check-oidc-trust:
	./scripts/check-oidc-trust.sh

test-check-oidc-trust:
	./scripts/test-check-oidc-trust.sh
