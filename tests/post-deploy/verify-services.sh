#!/bin/bash
# Post-deployment service verification script

set -euo pipefail

MAIL_SERVER="${PRODUCTION_HOST:-mail.summitethic.com}"
RESULTS_FILE="/tmp/service-verification-$(date +%Y%m%d-%H%M%S).json"

echo "Starting post-deployment verification..."

# Initialize results
cat > ${RESULTS_FILE} <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "server": "${MAIL_SERVER}",
  "tests": []
}
EOF

# Function to add test result
add_result() {
    local test_name=$1
    local status=$2
    local message=$3
    
    jq --arg name "$test_name" \
       --arg status "$status" \
       --arg msg "$message" \
       '.tests += [{"name": $name, "status": $status, "message": $msg}]' \
       ${RESULTS_FILE} > ${RESULTS_FILE}.tmp && mv ${RESULTS_FILE}.tmp ${RESULTS_FILE}
}

# Test 1: HTTPS Web Interface
echo -n "Testing HTTPS web interface... "
if curl -sf -o /dev/null "https://${MAIL_SERVER}"; then
    echo "PASS"
    add_result "https_web" "pass" "Web interface accessible"
else
    echo "FAIL"
    add_result "https_web" "fail" "Web interface not accessible"
fi

# Test 2: SMTP STARTTLS
echo -n "Testing SMTP with STARTTLS... "
if echo "QUIT" | openssl s_client -starttls smtp -connect ${MAIL_SERVER}:587 -servername ${MAIL_SERVER} 2>/dev/null | grep -q "Verify return code: 0"; then
    echo "PASS"
    add_result "smtp_starttls" "pass" "SMTP STARTTLS working"
else
    echo "FAIL"
    add_result "smtp_starttls" "fail" "SMTP STARTTLS not working"
fi

# Test 3: IMAPS
echo -n "Testing IMAPS... "
if echo "QUIT" | openssl s_client -connect ${MAIL_SERVER}:993 -servername ${MAIL_SERVER} 2>/dev/null | grep -q "Verify return code: 0"; then
    echo "PASS"
    add_result "imaps" "pass" "IMAPS working"
else
    echo "FAIL"
    add_result "imaps" "fail" "IMAPS not working"
fi

# Test 4: DNS Records
echo -n "Testing DNS configuration... "
MX_RECORD=$(dig +short MX ${MAIL_SERVER#mail.} | grep -o "${MAIL_SERVER}.$")
if [ ! -z "${MX_RECORD}" ]; then
    echo "PASS"
    add_result "dns_mx" "pass" "MX record configured correctly"
else
    echo "FAIL"
    add_result "dns_mx" "fail" "MX record not found"
fi

# Test 5: SPF Record
echo -n "Testing SPF record... "
SPF_RECORD=$(dig +short TXT ${MAIL_SERVER#mail.} | grep "v=spf1")
if [ ! -z "${SPF_RECORD}" ]; then
    echo "PASS"
    add_result "dns_spf" "pass" "SPF record found"
else
    echo "FAIL"
    add_result "dns_spf" "fail" "SPF record not found"
fi

# Test 6: DKIM Record
echo -n "Testing DKIM record... "
DKIM_RECORD=$(dig +short TXT dkim._domainkey.${MAIL_SERVER#mail.} | grep "v=DKIM1")
if [ ! -z "${DKIM_RECORD}" ]; then
    echo "PASS"
    add_result "dns_dkim" "pass" "DKIM record found"
else
    echo "WARNING"
    add_result "dns_dkim" "warning" "DKIM record not found - may need manual configuration"
fi

# Test 7: Monitoring Stack
echo -n "Testing Grafana... "
if curl -sf -o /dev/null "https://grafana.${MAIL_SERVER}/api/health"; then
    echo "PASS"
    add_result "monitoring_grafana" "pass" "Grafana is healthy"
else
    echo "FAIL"
    add_result "monitoring_grafana" "fail" "Grafana not accessible"
fi

# Display summary
echo ""
echo "Verification Summary:"
jq -r '.tests[] | "\(.name): \(.status) - \(.message)"' ${RESULTS_FILE}

# Check overall status
FAILED_TESTS=$(jq '[.tests[] | select(.status == "fail")] | length' ${RESULTS_FILE})
if [ ${FAILED_TESTS} -eq 0 ]; then
    echo ""
    echo "✅ All tests passed! Deployment successful."
    exit 0
else
    echo ""
    echo "❌ ${FAILED_TESTS} tests failed. Please review the deployment."
    exit 1
fi
