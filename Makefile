# Local helpers mirroring CI. Default goal is help.

.PHONY: help test-floci fmt-check check-action-pins test-check-action-pins

help:
	@echo "Targets:"
	@echo "  test-floci              Start Floci, terraform apply/destroy examples/floci-aws"
	@echo "  fmt-check               terraform fmt -check -recursive terraform examples"
	@echo "  check-action-pins       Fail if any third-party uses: lacks a 40-char SHA"
	@echo "  test-check-action-pins  Unit tests for the action pin checker"

test-floci:
	./scripts/test-floci.sh

fmt-check:
	terraform fmt -check -recursive terraform examples

check-action-pins:
	./scripts/check-action-pins.sh

test-check-action-pins:
	./scripts/test-check-action-pins.sh
