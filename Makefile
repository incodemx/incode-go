# -------- Config --------
GO ?= go
SHELL := /bin/bash

# Auto-detect all submodules that have their own go.mod (depth 2 covers cmd/*)
# Falls back to KNOWN_MODULE_DIRS if find/xargs isn't available.
DETECTED_MODULE_DIRS := $(shell { \
  command -v find >/dev/null 2>&1 && \
  find . -mindepth 1 -maxdepth 2 -name go.mod -print0 | xargs -0 -n1 dirname | sed 's|^\./||' | sort; } || true)

KNOWN_MODULE_DIRS := dbx configx cmd/dbx-migrate
MODULE_DIRS := $(if $(strip $(DETECTED_MODULE_DIRS)),$(DETECTED_MODULE_DIRS),$(KNOWN_MODULE_DIRS))

# Release params:
#   make release MODULE=configx VERSION=0.1.0
MODULE ?=
VERSION ?=
TAG := $(MODULE)/v$(VERSION)

# -------- Helpers --------
.PHONY: help
help:
	@echo "Targets:"
	@echo "  make modules             # List detected modules"
	@echo "  make work-init           # Create go.work and add all modules"
	@echo "  make work-use            # Ensure all modules are in go.work"
	@echo "  make tidy                # go mod tidy for each module"
	@echo "  make build               # go build ./... in each module"
	@echo "  make test                # go test ./... in each module"
	@echo "  make lint                # golangci-lint run (if installed) per module"
	@echo "  make clean               # remove build artifacts under cmd/*/dist"
	@echo "  make release MODULE=mod VERSION=X.Y.Z  # tag 'mod/vX.Y.Z' and push"
	@echo "  make ci                  # tidy + build + test (no workspace changes)"
	@echo ""
	@echo "Tips:"
	@echo "  • Use go.work for local dev across modules."
	@echo "  • Consumers import like: github.com/incodemx/incode-go/configx/database"
	@echo "  • Publish by tagging per module: configx/v0.1.0, dbx/v1.2.3, etc."

.PHONY: modules
modules:
	@echo "Modules:"
	@printf "  %s\n" $(MODULE_DIRS)

# -------- Workspace --------
.PHONY: work-init
work-init:
	@echo "Initializing go.work with all modules..."
	$(GO) work init $(MODULE_DIRS)

.PHONY: work-use
work-use:
	@echo "Adding modules to go.work..."
	$(GO) work use $(MODULE_DIRS)

# -------- Module ops --------
.PHONY: tidy
tidy:
	@set -e; \
	for d in $(MODULE_DIRS); do \
	  echo ">> go mod tidy in $$d"; \
	  $(GO) -C $$d mod tidy; \
	done

.PHONY: build
build:
	@set -e; \
	for d in $(MODULE_DIRS); do \
	  echo ">> go build in $$d"; \
	  $(GO) -C $$d build ./...; \
	done

.PHONY: test
test:
	@set -e; \
	for d in $(MODULE_DIRS); do \
	  echo ">> go test in $$d"; \
	  $(GO) -C $$d test ./...; \
	done

.PHONY: lint
lint:
	@command -v golangci-lint >/dev/null 2>&1 || { echo "golangci-lint not installed"; exit 1; }
	@set -e; \
	for d in $(MODULE_DIRS); do \
	  echo ">> golangci-lint in $$d"; \
	  (cd $$d && golangci-lint run); \
	done

# -------- CI convenience --------
.PHONY: ci
ci: tidy build test

# -------- Release (per-module semver tags) --------
# Usage: make release MODULE=configx VERSION=0.1.0
.PHONY: release
release:
	@if [ -z "$(MODULE)" ] || [ -z "$(VERSION)" ]; then \
	  echo "Usage: make release MODULE=<moduleDir> VERSION=<semver>"; \
	  echo "Example: make release MODULE=configx VERSION=0.1.0"; \
	  exit 2; \
	fi
	@if [ ! -d "$(MODULE)" ] || [ ! -f "$(MODULE)/go.mod" ]; then \
	  echo "Module directory '$(MODULE)' with go.mod not found"; \
	  exit 2; \
	fi
	@echo ">> Validating module path matches directory..."
	@awk 'NR==1 {print $$0}' "$(MODULE)/go.mod" | grep -q "module github.com/incodemx/incode-go/$(MODULE)" || { \
	  echo "First line of $(MODULE)/go.mod must be: module github.com/incodemx/incode-go/$(MODULE)"; exit 2; }
	@echo ">> Tidying and testing before release..."
	$(GO) -C $(MODULE) mod tidy
	$(GO) -C $(MODULE) test ./...
	@echo ">> Creating tag $(TAG)"
	git tag $(TAG)
	@echo ">> Pushing tag $(TAG)"
	git push origin $(TAG)
	@echo "Done. Consumers can now:"
	@echo "  go get github.com/incodemx/incode-go/$(MODULE)@v$(VERSION)"

# -------- Clean --------
.PHONY: clean
clean:
	@echo "Cleaning ./cmd/*/dist (if any)..."
	@rm -rf cmd/*/dist 2>/dev/null || true
