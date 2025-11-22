# Alertmanager Mixin Makefile
#
# This Makefile compiles the alertmanager-mixin Jsonnet into dashboards,
# alerts, and recording rules for deployment to Kubernetes.

JSONNET_FMT := jsonnetfmt -n 2 --max-blank-lines 2 --string-style s --comment-style s
MIXTOOL := mixtool

DASHBOARDS_DIR := ../../charts/grafana-dashboards/dashboards/alertmanager
RULES_DIR := ../../charts/grafana-dashboards/rules/alertmanager

.PHONY: all
all: dashboards alerts rules

.PHONY: install
install:
	jb install

.PHONY: update
update:
	jb update

.PHONY: dashboards
dashboards: mixin.libsonnet
	@echo "Generating dashboards..."
	@mkdir -p $(DASHBOARDS_DIR)
	$(MIXTOOL) generate dashboards -d $(DASHBOARDS_DIR) mixin.libsonnet

.PHONY: alerts
alerts: mixin.libsonnet
	@echo "Generating alerts..."
	@mkdir -p $(RULES_DIR)
	$(MIXTOOL) generate alerts mixin.libsonnet > $(RULES_DIR)/alerts.yaml

.PHONY: rules
rules: mixin.libsonnet
	@echo "Generating recording rules..."
	@mkdir -p $(RULES_DIR)
	$(MIXTOOL) generate rules mixin.libsonnet > $(RULES_DIR)/rules.yaml

.PHONY: lint
lint: mixin.libsonnet
	@echo "Linting mixin..."
	$(MIXTOOL) lint mixin.libsonnet

.PHONY: fmt
fmt:
	@echo "Formatting Jsonnet files..."
	find . -name '*.libsonnet' -o -name '*.jsonnet' | xargs -n 1 -- $(JSONNET_FMT) -i

.PHONY: clean
clean:
	@echo "Cleaning generated files..."
	rm -rf $(DASHBOARDS_DIR)
	rm -rf $(RULES_DIR)

.PHONY: clean-all
clean-all: clean
	@echo "Cleaning vendor directory..."
	rm -rf vendor/

.PHONY: help
help:
	@echo "Alertmanager Mixin Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all          - Generate dashboards, alerts, and rules (default)"
	@echo "  install      - Install Jsonnet dependencies via jb"
	@echo "  update       - Update Jsonnet dependencies"
	@echo "  dashboards   - Generate Grafana dashboards only"
	@echo "  alerts       - Generate Prometheus alerts only"
	@echo "  rules        - Generate Prometheus recording rules only"
	@echo "  lint         - Lint the mixin for errors"
	@echo "  fmt          - Format Jsonnet files"
	@echo "  clean        - Remove generated files"
	@echo "  clean-all    - Remove generated files and vendor directory"
	@echo "  help         - Show this help message"
