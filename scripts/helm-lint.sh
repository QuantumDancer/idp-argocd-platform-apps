#!/bin/bash

echo "Linting and validating Helm charts..."
mkdir -p reports

FAILED=0
FAILED_CHARTS=()

for chart in charts/*/Chart.yaml; do
  chart_dir=$(dirname "$chart")
  chart_name=$(basename "$chart_dir")

  echo "Processing $chart_name..."

  # Build dependencies if Chart.lock exists
  if [ -f "$chart_dir/Chart.lock" ]; then
    echo "  Rebuilding dependencies for $chart_name..."
    if ! helm dependency build "$chart_dir" >"reports/$chart_name-dependency.log" 2>&1; then
      echo "  ❌ ERROR: Failed to build dependencies for $chart_name"
      cat "reports/$chart_name-dependency.log"
      FAILED=1
      FAILED_CHARTS+=("$chart_name (dependency build)")
      continue
    fi
  else
    echo "  No dependencies to build for $chart_name"
  fi

  # Run helm lint
  echo "  Running helm lint on $chart_name..."
  if ! helm lint "$chart_dir" >"reports/$chart_name-lint.log" 2>&1; then
    echo "  ❌ ERROR: helm lint failed for $chart_name"
    cat "reports/$chart_name-lint.log"
    FAILED=1
    FAILED_CHARTS+=("$chart_name (lint)")
    continue
  else
    # Show lint output for transparency
    cat "reports/$chart_name-lint.log"
  fi

  # Run helm template.
  # When environment-specific values exist under environments/, template once per environment
  # so that CI validates each real deployment configuration. Without this, charts that rely
  # on environment overrides might fail to render from base values alone.
  env_dir="$chart_dir/environments"
  template_failed=false

  if [ -d "$env_dir" ] && ls "$env_dir"/*.yaml 1>/dev/null 2>&1; then
    for env_file in "$env_dir"/*.yaml; do
      env_name=$(basename "$env_file" .yaml)
      output_file="reports/$chart_name-$env_name-template.yaml"
      echo "  Running helm template on $chart_name (env: $env_name)..."
      if ! helm template "$chart_name" "$chart_dir" \
        --values "$chart_dir/values.yaml" \
        --values "$env_file" \
        >"$output_file" 2>&1; then
        echo "  ❌ ERROR: helm template failed for $chart_name (env: $env_name)"
        cat "$output_file"
        FAILED=1
        FAILED_CHARTS+=("$chart_name/$env_name (template)")
        template_failed=true
      fi
    done
  else
    output_file="reports/$chart_name-template.yaml"
    echo "  Running helm template on $chart_name..."
    if ! helm template "$chart_name" "$chart_dir" --values "$chart_dir/values.yaml" >"$output_file" 2>&1; then
      echo "  ❌ ERROR: helm template failed for $chart_name"
      cat "$output_file"
      FAILED=1
      FAILED_CHARTS+=("$chart_name (template)")
      template_failed=true
    fi
  fi

  if $template_failed; then
    continue
  fi

  # Validate templated output with kubectl dry-run if available
  if command -v kubectl &>/dev/null; then
    echo "  Validating templated manifests with kubectl..."
    for template_file in "reports/${chart_name}"-*template.yaml "reports/${chart_name}-template.yaml"; do
      [ -f "$template_file" ] || continue
      if ! kubectl apply --dry-run=client -f "$template_file" >/dev/null 2>&1; then
        echo "  ⚠️  WARNING: kubectl validation produced warnings for $template_file"
        # Don't fail on kubectl warnings as they might be environment-specific
      fi
    done
  fi

  echo "  ✅ $chart_name passed all checks"
  echo ""
done

echo ""
echo "================================"
echo "Validation Summary:"
echo "================================"

if [ $FAILED -eq 1 ]; then
  echo "❌ FAILURE: Some charts failed validation"
  echo ""
  echo "Failed charts:"
  for chart in "${FAILED_CHARTS[@]}"; do
    echo "  - $chart"
  done
  echo ""
  echo "Check reports/ directory for detailed logs"
else
  echo "✅ SUCCESS: All charts passed lint and template validation"
  echo ""
fi

echo "================================"

exit $FAILED
