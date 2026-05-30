# Makefile — cicd-pipeline-templates
# Run `make help` to see all available targets.

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# ── Variables ─────────────────────────────────────────────────────────────────
SCRIPTS_DIR   := scripts
TEMPLATES_DIR := github-actions gitlab-ci jenkins
PYTHON        := python3
PIP           := pip3

# Colours
BOLD  := \033[1m
GREEN := \033[0;32m
CYAN  := \033[0;36m
NC    := \033[0m

# ── Help ──────────────────────────────────────────────────────────────────────
.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "$(BOLD)cicd-pipeline-templates$(NC)"
	@echo "CI/CD pipeline templates by Barry Au Yeung"
	@echo ""
	@echo "$(BOLD)Usage:$(NC)"
	@echo "  make <target>"
	@echo ""
	@echo "$(BOLD)Targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  $(CYAN)%-22s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

# ── Lint ──────────────────────────────────────────────────────────────────────
.PHONY: lint
lint: lint-yaml lint-shell lint-jenkins ## Run all linters

.PHONY: lint-yaml
lint-yaml: ## Lint all YAML templates with yamllint
	@echo "$(GREEN)Linting YAML...$(NC)"
	@command -v yamllint >/dev/null 2>&1 || $(PIP) install --quiet yamllint
	@yamllint \
		--strict \
		--config-data '{extends: default, rules: {line-length: {max: 140}, truthy: {allowed-values: ["true", "false"]}}}' \
		github-actions/ gitlab-ci/ .github/workflows/
	@echo "$(GREEN)YAML lint passed.$(NC)"

.PHONY: lint-shell
lint-shell: ## Lint shell scripts with shellcheck
	@echo "$(GREEN)Linting shell scripts...$(NC)"
	@command -v shellcheck >/dev/null 2>&1 || (echo "Install shellcheck: apt-get install shellcheck / brew install shellcheck" && exit 1)
	@shellcheck --severity=warning $(SCRIPTS_DIR)/*.sh
	@echo "$(GREEN)Shell lint passed.$(NC)"

.PHONY: lint-jenkins
lint-jenkins: ## Validate Jenkinsfile structure
	@echo "$(GREEN)Validating Jenkinsfiles...$(NC)"
	@for f in jenkins/Jenkinsfile.*; do \
		grep -q 'pipeline {' "$$f" || (echo "FAIL: $$f missing 'pipeline {'" && exit 1); \
		grep -q 'stages {'   "$$f" || (echo "FAIL: $$f missing 'stages {'" && exit 1); \
		echo "  OK: $$f"; \
	done
	@echo "$(GREEN)Jenkinsfile validation passed.$(NC)"

# ── Test ──────────────────────────────────────────────────────────────────────
.PHONY: test
test: lint verify-permissions ## Run all tests (lint + permission checks)
	@echo "$(GREEN)All tests passed.$(NC)"

.PHONY: verify-permissions
verify-permissions: ## Verify all scripts have execute permission
	@echo "$(GREEN)Checking script permissions...$(NC)"
	@for s in $(SCRIPTS_DIR)/*.sh; do \
		test -x "$$s" || (echo "FAIL: $$s is not executable — run: chmod +x $$s" && exit 1); \
		echo "  OK: $$s"; \
	done
	@echo "$(GREEN)Permission check passed.$(NC)"

# ── Build / Install ───────────────────────────────────────────────────────────
.PHONY: build
build: ## Make all scripts executable and validate structure
	@echo "$(GREEN)Preparing scripts...$(NC)"
	@chmod +x $(SCRIPTS_DIR)/*.sh
	@echo "$(GREEN)Scripts ready.$(NC)"
	@$(MAKE) lint

.PHONY: install-tools
install-tools: ## Install local development tools (yamllint, shellcheck)
	@echo "$(GREEN)Installing tools...$(NC)"
	@$(PIP) install --quiet yamllint
	@command -v shellcheck >/dev/null 2>&1 || echo "Install shellcheck manually: apt-get install shellcheck / brew install shellcheck"
	@echo "$(GREEN)Tools installed.$(NC)"

# ── Release helpers ───────────────────────────────────────────────────────────
.PHONY: bump-patch
bump-patch: ## Bump patch version (1.2.3 → 1.2.4)
	@$(SCRIPTS_DIR)/semver-bump.sh patch

.PHONY: bump-minor
bump-minor: ## Bump minor version (1.2.3 → 1.3.0)
	@$(SCRIPTS_DIR)/semver-bump.sh minor

.PHONY: bump-major
bump-major: ## Bump major version (1.2.3 → 2.0.0)
	@$(SCRIPTS_DIR)/semver-bump.sh major

.PHONY: release-notes
release-notes: ## Print release notes since last tag
	@$(SCRIPTS_DIR)/release-notes.sh

# ── Clean ─────────────────────────────────────────────────────────────────────
.PHONY: clean
clean: ## Remove generated files and caches
	@echo "$(GREEN)Cleaning...$(NC)"
	@rm -f RELEASE_NOTES.md coverage.* *.pyc
	@find . -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)Clean complete.$(NC)"
