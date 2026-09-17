# Transikey developer tasks. Run `make help` for the list.

COMPOSE      := docker compose -f dev/docker-compose.yml
BAO_ADDR     ?= http://127.0.0.1:8200
BAO_TOKEN    ?= root

UNAME := $(shell uname -s)
ifeq ($(UNAME),Darwin)
  PLATFORM := macos
else ifeq ($(UNAME),Linux)
  PLATFORM := linux
else
  PLATFORM := windows
endif

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "} {printf "  %-18s %s\n", $$1, $$2}'

# --- setup -------------------------------------------------------------------

.PHONY: deps
deps: ## Fetch Dart and Flutter packages
	flutter pub get

.PHONY: gen
gen: deps ## Generate Freezed, JSON and BDD code
	dart run build_runner build --delete-conflicting-outputs

.PHONY: watch
watch: deps ## Regenerate code on every change
	dart run build_runner watch --delete-conflicting-outputs

# --- quality -----------------------------------------------------------------

.PHONY: format
format: ## Format Dart sources
	dart format lib test

.PHONY: analyze
analyze: ## Run the static analyzer
	flutter analyze

.PHONY: test
test: ## Run unit and BDD tests (no server needed)
	flutter test --exclude-tags integration

.PHONY: test-integration
test-integration: ## Run live tests against the dev stack (make dev-up first)
	BAO_ADDR=$(BAO_ADDR) BAO_TOKEN=$(BAO_TOKEN) flutter test test/integration

.PHONY: check
check: analyze test ## Analyzer plus offline tests

# --- app ---------------------------------------------------------------------

.PHONY: run
run: ## Run the app on this machine (debug)
	flutter run -d $(PLATFORM)

.PHONY: build
build: ## Release build for this machine's platform
	flutter build $(PLATFORM) --release

.PHONY: build-macos build-linux build-windows
build-macos: ## Release build for macOS (needs a macOS host)
	flutter build macos --release
build-linux: ## Release build for Linux (needs a Linux host)
	flutter build linux --release
build-windows: ## Release build for Windows (needs a Windows host)
	flutter build windows --release

# --- dev stack: OpenBao + PostgreSQL ------------------------------------------

.PHONY: dev-up
dev-up: ## Start OpenBao (dev mode), PostgreSQL and OpenLDAP, then configure them
	$(COMPOSE) up -d --wait openbao postgres openldap
	$(COMPOSE) up init

.PHONY: dev-down
dev-down: ## Stop the dev stack and delete its data
	$(COMPOSE) down -v

.PHONY: dev-reset
dev-reset: dev-down dev-up ## Recreate the dev stack from scratch

.PHONY: dev-logs
dev-logs: ## Follow dev stack logs
	$(COMPOSE) logs -f

.PHONY: dev-status
dev-status: ## Show dev stack containers
	$(COMPOSE) ps

.PHONY: dev-approle
# Prints a secret_id to the terminal on purpose: dev stack only, in-memory server.
dev-approle: ## Print a fresh AppRole role_id / secret_id pair for the dev stack
	@$(COMPOSE) exec -T -e BAO_TOKEN=$(BAO_TOKEN) openbao bao read -field=role_id auth/approle/role/transikey/role-id | sed 's/^/role_id:   /'
	@$(COMPOSE) exec -T -e BAO_TOKEN=$(BAO_TOKEN) openbao bao write -f -field=secret_id auth/approle/role/transikey/secret-id | sed 's/^/secret_id: /'

# --- housekeeping ------------------------------------------------------------

.PHONY: clean
clean: ## Remove build output and generated code
	flutter clean
	find lib test \( -name '*.g.dart' -o -name '*.freezed.dart' \) -exec rm -f {} +
