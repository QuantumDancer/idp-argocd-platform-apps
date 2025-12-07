#!/bin/bash

echo "Scanning Helm charts for vulnerabilities..."
mkdir -p reports

RENDER_FAILED=0
VULNERABILITIES_FOUND=0
FAILED_CHARTS=()
VULNERABLE_CHARTS=()

for chart in charts/*/Chart.yaml; do
  chart_dir=$(dirname "$chart")
  chart_name=$(basename "$chart_dir")

  # Skip charts without dependencies
  if [ ! -f "$chart_dir/Chart.lock" ]; then
    echo "Skipping $chart_name (no dependencies)"
    continue
  fi

  echo "Rebuild dependencies for $chart_name..."
  if ! helm dependency build "$chart_dir"; then
    echo "❌ ERROR: Failed to update dependencies for $chart_name"
    RENDER_FAILED=1
    FAILED_CHARTS+=("$chart_name")
    continue
  fi

  echo "Scanning $chart_name..."

  # Scan Chart.yaml and dependencies for issues
  # Capture output to check for rendering errors
  trivy config "$chart_dir" \
    --severity HIGH,CRITICAL \
    --exit-code 0 \
    --format json \
    --output "reports/$chart_name-trivy.json" 2>&1 | tee "/tmp/trivy-$chart_name.log"

  TRIVY_EXIT=$?

  # Check for rendering errors in the output
  if [ $TRIVY_EXIT -ne 0 ] || grep -q "Failed to render Chart files" "/tmp/trivy-$chart_name.log"; then
    echo "❌ ERROR: Failed to render Helm chart for $chart_name"
    RENDER_FAILED=1
    FAILED_CHARTS+=("$chart_name")
    continue
  fi

  # Check if vulnerabilities were found in the JSON report
  if [ -f "reports/$chart_name-trivy.json" ]; then
    VULN_COUNT=$(jq '[.Results[]?.Misconfigurations[]? | select(.Severity == "HIGH" or .Severity == "CRITICAL")] | length' "reports/$chart_name-trivy.json" 2>/dev/null || echo "0")
    if [ "$VULN_COUNT" -gt 0 ]; then
      echo "⚠️  Found $VULN_COUNT HIGH/CRITICAL vulnerabilities in $chart_name"
      VULNERABILITIES_FOUND=1
      VULNERABLE_CHARTS+=("$chart_name ($VULN_COUNT issues)")
    else
      echo "✅ No HIGH/CRITICAL vulnerabilities in $chart_name"
    fi
  fi
done

echo ""
echo "================================"
echo "Scan Summary:"
echo "================================"

if [ $RENDER_FAILED -eq 1 ]; then
  echo "❌ FAILURE: Some charts failed to render"
  echo ""
  echo "Failed charts:"
  for chart in "${FAILED_CHARTS[@]}"; do
    echo "  - $chart"
  done
  echo ""
fi

if [ $VULNERABILITIES_FOUND -eq 1 ]; then
  echo "⚠️  WARNING: Vulnerabilities found in charts"
  echo ""
  echo "Vulnerable charts:"
  for chart in "${VULNERABLE_CHARTS[@]}"; do
    echo "  - $chart"
  done
  echo ""
fi

if [ $RENDER_FAILED -eq 0 ] && [ $VULNERABILITIES_FOUND -eq 0 ]; then
  echo "✓ SUCCESS: All charts scanned, no HIGH or CRITICAL vulnerabilities detected"
  echo ""
fi

echo "Check reports/ artifacts for detailed findings"
echo "================================"

# Exit with failure only if rendering failed (process error)
# Vulnerabilities are warnings but don't fail the job (allow_failure handles this)
exit $RENDER_FAILED
