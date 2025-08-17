GO ?= go
SHELL := /bin/bash
ROOT := $(abspath .)
export GOWORK := $(ROOT)/go.work

DETECTED_MODULE_DIRS := $(shell { \
  command -v find >/dev/null 2>&1 && \
  find . -mindepth 1 -maxdepth 2 -name go.mod -print0 | xargs -0 -n1 dirname | sed 's|^\./||' | sort; } || true)

KNOWN_MODULE_DIRS := dbx httpx configx cmd/dbx-migrate
MODULE_DIRS := $(if $(strip $(DETECTED_MODULE_DIRS)),$(DETECTED_MODULE_DIRS),$(KNOWN_MODULE_DIRS))

# -------- Release parameters --------
# Usage: make release MODULE=configx [PART=patch|minor|major]
MODULE ?=
PART ?= patch

# ========================== Help / Info ===============================

.PHONY: help
help:
	@echo "Incode Go Monorepo — targets"
	@echo ""
	@echo "Core:"
	@echo "  make modules             # list detected modules"
	@echo "  make work-init           # create go.work with all modules"
	@echo "  make work-use            # ensure all modules are in go.work"
	@echo "  make tidy                # go mod tidy for each module"
	@echo "  make build               # go build ./... in each module"
	@echo "  make test                # go test ./... in each module"
	@echo "  make lint                # run golangci-lint (if installed) per module"
	@echo "  make ci                  # tidy + build + test"
	@echo "  make clean               # remove ./cmd/*/dist (if any)"
	@echo ""
	@echo "Local linking helper:"
	@echo "  make link-local MODULE=dbx DEP=github.com/incodemx/incode-go/configx DIR=../configx"
	@echo ""
	@echo "Release (auto-bump per module):"
	@echo "  make release MODULE=configx [PART=patch|minor|major]"
	@echo "    -> auto-bumps latest tag for MODULE and pushes it (e.g., configx/v0.1.5)"

.PHONY: modules
modules:
	@echo "Modules:"
	@printf "  %s\n" $(MODULE_DIRS)

# ======================== Workspace ops ===============================

.PHONY: work-init
work-init:
	@echo "Initializing go.work with all modules..."
	$(GO) work init $(MODULE_DIRS)

.PHONY: work-use
work-use:
	@echo "Adding modules to go.work..."
	$(GO) work use $(MODULE_DIRS)

.PHONY: ensure-workspace
ensure-workspace:
	@if [ ! -f "$(GOWORK)" ]; then \
		$(GO) work init $(MODULE_DIRS); \
	fi
	$(GO) work use $(MODULE_DIRS)
	-$(GO) work sync

# ======================== Per-module ops ==============================

.PHONY: tidy
tidy: ensure-workspace
	@set -e; \
	for d in $(MODULE_DIRS); do \
	  echo ">> go mod tidy in $$d"; \
	  $(GO) -C $$d mod tidy; \
	done

.PHONY: build
build: ensure-workspace
	@set -e; \
	for d in $(MODULE_DIRS); do \
	  echo ">> go build in $$d"; \
	  $(GO) -C $$d build ./...; \
	done

.PHONY: test
test: ensure-workspace
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
	  echo ">> golangci-lint run in $$d"; \
	  (cd $$d && golangci-lint run); \
	done

.PHONY: ci
ci: tidy build test

.PHONY: clean
clean:
	@echo "Cleaning ./cmd/*/dist (if any)..."
	@rm -rf cmd/*/dist 2>/dev/null || true

# ======================= Local link helper ============================

# Link a local module into another module's go.mod
# Usage:
#   make link-local MODULE=dbx DEP=github.com/incodemx/incode-go/configx DIR=../configx
.PHONY: link-local
link-local:
	@if [ -z "$(MODULE)" ] || [ -z "$(DEP)" ] || [ -z "$(DIR)" ]; then \
		echo "Usage: make link-local MODULE=<moduleDir> DEP=<modulePath> DIR=<relativePath>"; \
		exit 2; \
	fi
	$(GO) -C $(MODULE) mod edit -replace=$(DEP)=$(DIR)
	$(GO) -C $(MODULE) mod edit -require=$(DEP)@v0.0.0
	$(GO) -C $(MODULE) mod tidy

# ========================= Release (auto-bump) ========================

# make release MODULE=configx [PART=patch|minor|major]
.PHONY: release
release:
	@if [ -z "$(MODULE)" ]; then \
	  echo "Usage: make release MODULE=<moduleDir> [PART=patch|minor|major]"; \
	  echo "Example: make release MODULE=configx PART=minor"; \
	  exit 2; \
	fi
	@if [ ! -d "$(MODULE)" ] || [ ! -f "$(MODULE)/go.mod" ]; then \
	  echo "Module directory '$(MODULE)' with go.mod not found"; \
	  exit 2; \
	fi
	@echo ">> Validating module path in $(MODULE)/go.mod..."
	@awk 'NR==1 {print $$0}' "$(MODULE)/go.mod" | grep -q "module github.com/incodemx/incode-go/$(MODULE)" || { \
	  echo "First line of $(MODULE)/go.mod must be: module github.com/incodemx/incode-go/$(MODULE)"; exit 2; }
	@$(MAKE) ensure-workspace
	@echo ">> Fetching tags..."
	@git fetch --tags --quiet || true
	@echo ">> Finding latest tag for $(MODULE)..."
	@LATEST_TAG=$$(git tag --list "$(MODULE)/v*" --sort=-v:refname | head -n 1); \
	if [ -z "$$LATEST_TAG" ]; then \
	  echo "No tags found for $(MODULE), starting at v0.1.0"; \
	  NEW_TAG="$(MODULE)/v0.1.0"; \
	else \
	  echo "Latest tag: $$LATEST_TAG"; \
	  VERSION=$$(echo $$LATEST_TAG | sed -E 's|.*/v||'); \
	  IFS=. read MAJ MIN PATCH <<<$$VERSION; \
	  case "$(PART)" in \
	    major) MAJ=$$((MAJ+1)); MIN=0; PATCH=0 ;; \
	    minor) MIN=$$((MIN+1)); PATCH=0 ;; \
	    patch) PATCH=$$((PATCH+1)) ;; \
	    *) echo "Invalid PART=$(PART), must be major|minor|patch"; exit 2 ;; \
	  esac; \
	  NEW_TAG="$(MODULE)/v$$MAJ.$$MIN.$$PATCH"; \
	fi; \
	echo ">> New tag: $$NEW_TAG"; \
	echo ">> Tidying & testing $(MODULE) before tagging..."; \
	$(GO) -C $(MODULE) mod tidy; \
	$(GO) -C $(MODULE) test ./...; \
	echo ">> Creating tag $$NEW_TAG"; \
	git tag $$NEW_TAG; \
	echo ">> Pushing tag $$NEW_TAG"; \
	git push origin $$NEW_TAG; \
	echo "Done. Consumers can now:"; \
	echo "  go get github.com/incodemx/incode-go/$(MODULE)@$$(echo $$NEW_TAG | sed 's|.*/||')"
