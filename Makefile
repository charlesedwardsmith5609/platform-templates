# Local helpers mirroring CI. Default goal is help.

.PHONY: help test-floci fmt-check

help:
	@echo "Targets:"
	@echo "  test-floci   Start Floci, terraform apply/destroy examples/floci-aws"
	@echo "  fmt-check    terraform fmt -check -recursive terraform examples"

test-floci:
	./scripts/test-floci.sh

fmt-check:
	terraform fmt -check -recursive terraform examples
