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

  # When environment-specific values exist under environments/, scan once per environment
  # so that CI validates each real deployment configuration. Without this, charts that rely
  # on environment overrides might fail to render from base values alone.
  env_dir="$chart_dir/environments"
  render_failed=false

  if [ -d "$env_dir" ] && ls "$env_dir"/*.yaml 1>/dev/null 2>&1; then
    for env_file in "$env_dir"/*.yaml; do
      env_name=$(basename "$env_file" .yaml)
      output_file="reports/$chart_name-$env_name-trivy.json"
      log_file="/tmp/trivy-$chart_name-$env_name.log"

      echo "Scanning $chart_name (env: $env_name)..."
      # trivy-overrides.yaml provides scan-only values (e.g. to work around trivy's
      # Helm renderer not populating .Release.Namespace). It has no effect on deployments.
      trivy_overrides=()
      if [ -f "$chart_dir/trivy-overrides.yaml" ]; then
        trivy_overrides=(--helm-values "$chart_dir/trivy-overrides.yaml")
      fi
      trivy config \
        --helm-values "$chart_dir/values.yaml" \
        --helm-values "$env_file" \
        "${trivy_overrides[@]}" \
        --severity HIGH,CRITICAL \
        --exit-code 0 \
        --format json \
        --output "$output_file" \
        "$chart_dir" 2>&1 | tee "$log_file"

      if [ ${PIPESTATUS[0]} -ne 0 ] || grep -q "Failed to render Chart files" "$log_file"; then
        echo "❌ ERROR: Failed to render Helm chart for $chart_name (env: $env_name)"
        RENDER_FAILED=1
        FAILED_CHARTS+=("$chart_name/$env_name")
        render_failed=true
        continue
      fi

      if [ -f "$output_file" ]; then
        VULN_COUNT=$(jq '[.Results[]?.Misconfigurations[]? | select(.Severity == "HIGH" or .Severity == "CRITICAL")] | length' "$output_file" 2>/dev/null || echo "0")
        if [ "$VULN_COUNT" -gt 0 ]; then
          echo "⚠️  Found $VULN_COUNT HIGH/CRITICAL vulnerabilities in $chart_name (env: $env_name)"
          VULNERABILITIES_FOUND=1
          VULNERABLE_CHARTS+=("$chart_name/$env_name ($VULN_COUNT issues)")
        else
          echo "✅ No HIGH/CRITICAL vulnerabilities in $chart_name (env: $env_name)"
        fi
      fi
    done
  else
    output_file="reports/$chart_name-trivy.json"
    log_file="/tmp/trivy-$chart_name.log"

    echo "Scanning $chart_name..."
    trivy_overrides=()
    if [ -f "$chart_dir/trivy-overrides.yaml" ]; then
      trivy_overrides=(--helm-values "$chart_dir/trivy-overrides.yaml")
    fi
    trivy config \
      --helm-values "$chart_dir/values.yaml" \
      "${trivy_overrides[@]}" \
      --severity HIGH,CRITICAL \
      --exit-code 0 \
      --format json \
      --output "$output_file" \
      "$chart_dir" 2>&1 | tee "$log_file"

    if [ ${PIPESTATUS[0]} -ne 0 ] || grep -q "Failed to render Chart files" "$log_file"; then
      echo "❌ ERROR: Failed to render Helm chart for $chart_name"
      RENDER_FAILED=1
      FAILED_CHARTS+=("$chart_name")
      render_failed=true
    elif [ -f "$output_file" ]; then
      VULN_COUNT=$(jq '[.Results[]?.Misconfigurations[]? | select(.Severity == "HIGH" or .Severity == "CRITICAL")] | length' "$output_file" 2>/dev/null || echo "0")
      if [ "$VULN_COUNT" -gt 0 ]; then
        echo "⚠️  Found $VULN_COUNT HIGH/CRITICAL vulnerabilities in $chart_name"
        VULNERABILITIES_FOUND=1
        VULNERABLE_CHARTS+=("$chart_name ($VULN_COUNT issues)")
      else
        echo "✅ No HIGH/CRITICAL vulnerabilities in $chart_name"
      fi
    fi
  fi

  if $render_failed; then
    continue
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
