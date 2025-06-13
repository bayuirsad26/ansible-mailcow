#!/bin/bash
# Integration tests for mail server functionality

set -euo pipefail

MAIL_SERVER="${STAGING_HOST:-mail.summitethic.com}"
TEST_EMAIL="test@summitethic.com"
API_KEY="${MAILCOW_API_KEY}"

echo "Running mail server integration tests..."

# Test 1: Check if mail server is responding
echo -n "Testing SMTP connection... "
if nc -zv ${MAIL_SERVER} 25 2>&1 | grep -q succeeded; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 2: Check IMAP
echo -n "Testing IMAP connection... "
if nc -zv ${MAIL_SERVER} 993 2>&1 | grep -q succeeded; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 3: Check API health
echo -n "Testing Mailcow API... "
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-API-Key: ${API_KEY}" \
    "https://${MAIL_SERVER}/api/v1/get/status/containers")
    
if [ "${HTTP_STATUS}" -eq 200 ]; then
    echo "PASS"
else
    echo "FAIL (HTTP ${HTTP_STATUS})"
    exit 1
fi

# Test 4: Check SSL certificate
echo -n "Testing SSL certificate... "
CERT_DAYS=$(echo | openssl s_client -servername ${MAIL_SERVER} -connect ${MAIL_SERVER}:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2 | xargs -I {} date -d {} +%s)
CURRENT_DATE=$(date +%s)
DAYS_LEFT=$(( (CERT_DAYS - CURRENT_DATE) / 86400 ))

if [ ${DAYS_LEFT} -gt 30 ]; then
    echo "PASS (${DAYS_LEFT} days remaining)"
else
    echo "FAIL (Only ${DAYS_LEFT} days remaining)"
    exit 1
fi

echo "All tests passed!"
