#!/bin/bash
# Deployment validation script

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MAIL_SERVER="${1:-mail.summitethic.com}"
CHECKS_PASSED=0
CHECKS_FAILED=0

# Helper functions
print_header() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
}

# Start validation
echo "Starting deployment validation for: ${MAIL_SERVER}"
echo "Time: $(date)"

# DNS Checks
print_header "DNS Configuration"

# Check A record
if host "${MAIL_SERVER}" >/dev/null 2>&1; then
    check_pass "A record exists for ${MAIL_SERVER}"
else
    check_fail "A record missing for ${MAIL_SERVER}"
fi

# Check MX record
if host -t MX "${MAIL_SERVER#mail.}" | grep -q "${MAIL_SERVER}"; then
    check_pass "MX record points to ${MAIL_SERVER}"
else
    check_fail "MX record not properly configured"
fi

# Check SPF record
if host -t TXT "${MAIL_SERVER#mail.}" | grep -q "v=spf1"; then
    check_pass "SPF record exists"
else
    check_fail "SPF record missing"
fi

# Check DKIM record
if host -t TXT "dkim._domainkey.${MAIL_SERVER#mail.}" | grep -q "v=DKIM1"; then
    check_pass "DKIM record exists"
else
    check_fail "DKIM record missing"
fi

# Check DMARC record
if host -t TXT "_dmarc.${MAIL_SERVER#mail.}" | grep -q "v=DMARC1"; then
    check_pass "DMARC record exists"
else
    check_fail "DMARC record missing"
fi

# Service Checks
print_header "Service Availability"

# Check HTTPS
if curl -sf -o /dev/null "https://${MAIL_SERVER}"; then
    check_pass "HTTPS web interface accessible"
else
    check_fail "HTTPS web interface not accessible"
fi

# Check SMTP
if nc -zv "${MAIL_SERVER}" 25 2>&1 | grep -q succeeded; then
    check_pass "SMTP port 25 open"
else
    check_fail "SMTP port 25 not accessible"
fi

# Check Submission
if nc -zv "${MAIL_SERVER}" 587 2>&1 | grep -q succeeded; then
    check_pass "Submission port 587 open"
else
    check_fail "Submission port 587 not accessible"
fi

# Check IMAPS
if nc -zv "${MAIL_SERVER}" 993 2>&1 | grep -q succeeded; then
    check_pass "IMAPS port 993 open"
else
    check_fail "IMAPS port 993 not accessible"
fi

# SSL Certificate Check
print_header "SSL Certificate"

CERT_INFO=$(echo | openssl s_client -servername "${MAIL_SERVER}" -connect "${MAIL_SERVER}:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
if [ $? -eq 0 ]; then
    check_pass "SSL certificate valid"
    
    # Check expiration
    EXPIRE_DATE=$(echo "$CERT_INFO" | grep notAfter | cut -d= -f2)
    EXPIRE_EPOCH=$(date -d "${EXPIRE_DATE}" +%s)
    CURRENT_EPOCH=$(date +%s)
    DAYS_LEFT=$(( (EXPIRE_EPOCH - CURRENT_EPOCH) / 86400 ))
    
    if [ ${DAYS_LEFT} -gt 30 ]; then
        check_pass "SSL certificate expires in ${DAYS_LEFT} days"
    else
        check_fail "SSL certificate expires soon (${DAYS_LEFT} days)"
    fi
else
    check_fail "SSL certificate check failed"
fi

# Mail Delivery Test
print_header "Mail Delivery Test"

# This requires swaks to be installed
if command -v swaks >/dev/null 2>&1; then
    if swaks --to test@example.com \
             --from test@"${MAIL_SERVER#mail.}" \
             --server "${MAIL_SERVER}" \
             --port 25 \
             --quit-after RCPT \
             --hide-all \
             --silent \
             2>&1 | grep -q "250"; then
        check_pass "SMTP accepts mail (RCPT TO)"
    else
        check_fail "SMTP rejects mail"
    fi
else
    echo "swaks not installed, skipping mail delivery test"
fi

# Summary
print_header "Validation Summary"
echo "Checks passed: ${CHECKS_PASSED}"
echo "Checks failed: ${CHECKS_FAILED}"

if [ ${CHECKS_FAILED} -eq 0 ]; then
    echo -e "\n${GREEN}All checks passed! Deployment appears healthy.${NC}"
    exit 0
else
    echo -e "\n${RED}Some checks failed. Please review the deployment.${NC}"
    exit 1
fi
