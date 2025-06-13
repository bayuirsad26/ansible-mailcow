#!/bin/bash
# Integration tests for monitoring stack

set -euo pipefail

GRAFANA_URL="https://grafana.${STAGING_HOST:-mail.summitethic.com}"
PROMETHEUS_URL="https://prometheus.${STAGING_HOST:-mail.summitethic.com}"

echo "Running monitoring integration tests..."

# Test 1: Grafana health check
echo -n "Testing Grafana... "
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${GRAFANA_URL}/api/health")
if [ "${HTTP_STATUS}" -eq 200 ]; then
    echo "PASS"
else
    echo "FAIL (HTTP ${HTTP_STATUS})"
    exit 1
fi

# Test 2: Prometheus health check
echo -n "Testing Prometheus... "
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "admin:${PROMETHEUS_PASSWORD}" \
    "${PROMETHEUS_URL}/-/healthy")
if [ "${HTTP_STATUS}" -eq 200 ]; then
    echo "PASS"
else
    echo "FAIL (HTTP ${HTTP_STATUS})"
    exit 1
fi

# Test 3: Check if metrics are being collected
echo -n "Testing metric collection... "
METRIC_COUNT=$(curl -s -u "admin:${PROMETHEUS_PASSWORD}" \
    "${PROMETHEUS_URL}/api/v1/query?query=up" | jq '.data.result | length')
if [ ${METRIC_COUNT} -gt 5 ]; then
    echo "PASS (${METRIC_COUNT} targets up)"
else
    echo "FAIL (Only ${METRIC_COUNT} targets up)"
    exit 1
fi

echo "All monitoring tests passed!"
