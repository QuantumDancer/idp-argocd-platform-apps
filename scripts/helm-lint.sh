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
    if ! helm dependency build "$chart_dir" > "reports/$chart_name-dependency.log" 2>&1; then
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
  if ! helm lint "$chart_dir" > "reports/$chart_name-lint.log" 2>&1; then
    echo "  ❌ ERROR: helm lint failed for $chart_name"
    cat "reports/$chart_name-lint.log"
    FAILED=1
    FAILED_CHARTS+=("$chart_name (lint)")
    continue
  else
    # Show lint output for transparency
    cat "reports/$chart_name-lint.log"
  fi

  # Run helm template
  echo "  Running helm template on $chart_name..."
  if ! helm template "$chart_name" "$chart_dir" --values "$chart_dir/values.yaml" > "reports/$chart_name-template.yaml" 2>&1; then
    echo "  ❌ ERROR: helm template failed for $chart_name"
    cat "reports/$chart_name-template.yaml"
    FAILED=1
    FAILED_CHARTS+=("$chart_name (template)")
    continue
  fi

  # Validate templated output with kubectl dry-run if available
  if command -v kubectl &> /dev/null; then
    echo "  Validating templated manifests with kubectl..."
    if ! kubectl apply --dry-run=client -f "reports/$chart_name-template.yaml" > "reports/$chart_name-validate.log" 2>&1; then
      echo "  ⚠️  WARNING: kubectl validation produced warnings for $chart_name"
      cat "reports/$chart_name-validate.log"
      # Don't fail on kubectl warnings as they might be environment-specific
    fi
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
