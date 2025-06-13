#!/bin/bash
# Security audit script for SummitEthic infrastructure

set -euo pipefail

# Configuration
REPORT_FILE="/root/security-audit-$(date +%Y%m%d-%H%M%S).txt"
TEMP_DIR="/tmp/security-audit-$$"

# Create temp directory
mkdir -p "${TEMP_DIR}"
trap "rm -rf ${TEMP_DIR}" EXIT

# Start report
{
    echo "Security Audit Report"
    echo "===================="
    echo "Date: $(date)"
    echo "Hostname: $(hostname)"
    echo ""
    
    # System information
    echo "System Information"
    echo "------------------"
    uname -a
    echo ""
    
    # Check for security updates
    echo "Security Updates"
    echo "----------------"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update >/dev/null 2>&1
        UPDATES=$(apt-get -s upgrade | grep -i security | wc -l)
        echo "Security updates available: ${UPDATES}"
    fi
    echo ""
    
    # Check SSH configuration
    echo "SSH Configuration"
    echo "-----------------"
    grep -E "^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|Port)" /etc/ssh/sshd_config || true
    echo ""
    
    # Check open ports
    echo "Open Ports"
    echo "----------"
    ss -tlnp | grep LISTEN
    echo ""
    
    # Check for unauthorized users
    echo "System Users"
    echo "------------"
    echo "Users with UID 0:"
    awk -F: '($3 == "0") {print $1}' /etc/passwd
    echo ""
    echo "Users with login shell:"
    grep -v -E "(nologin|false)$" /etc/passwd
    echo ""
    
    # Check sudo configuration
    echo "Sudo Configuration"
    echo "------------------"
    echo "Sudoers:"
    grep -v '^#' /etc/sudoers | grep -v '^$' || true
    if [ -d /etc/sudoers.d ]; then
        for file in /etc/sudoers.d/*; do
            if [ -f "$file" ]; then
                echo "File: $file"
                grep -v '^#' "$file" | grep -v '^$' || true
            fi
        done
    fi
    echo ""
    
    # Check for suspicious cron jobs
    echo "Cron Jobs"
    echo "---------"
    for user in $(cut -f1 -d: /etc/passwd); do
        crontab -u "$user" -l 2>/dev/null | grep -v '^#' | grep -v '^$' && echo "(User: $user)" || true
    done
    echo ""
    
    # Check file permissions
    echo "Sensitive File Permissions"
    echo "--------------------------"
    ls -la /etc/passwd /etc/shadow /etc/group /etc/gshadow
    echo ""
    
    # Check for world-writable files
    echo "World-writable files (sample):"
    find /etc -type f -perm -002 2>/dev/null | head -20 || true
    echo ""
    
    # Docker security
    echo "Docker Security"
    echo "---------------"
    docker version --format 'Docker version: {{.Server.Version}}'
    echo "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    # Firewall status
    echo "Firewall Status"
    echo "---------------"
    if command -v ufw >/dev/null 2>&1; then
        ufw status verbose
    fi
    echo ""
    
    # Check fail2ban
    echo "Fail2ban Status"
    echo "---------------"
    if command -v fail2ban-client >/dev/null 2>&1; then
        fail2ban-client status
    fi
    echo ""
    
    # Check for listening services
    echo "Listening Services"
    echo "------------------"
    netstat -tlnp 2>/dev/null || ss -tlnp
    echo ""
    
    # Kernel security parameters
    echo "Kernel Security Parameters"
    echo "--------------------------"
    sysctl -a 2>/dev/null | grep -E "(forward|send_redirects|accept_source|syncookies)" | sort
    echo ""
    
    echo "Audit completed: $(date)"
    
} > "${REPORT_FILE}"

echo "Security audit completed. Report saved to: ${REPORT_FILE}"

# Optional: Run additional security tools if available
if command -v lynis >/dev/null 2>&1; then
    echo "Running Lynis audit..."
    lynis audit system --quick --quiet >> "${REPORT_FILE}" 2>&1
fi

if command -v rkhunter >/dev/null 2>&1; then
    echo "Running rkhunter..."
    rkhunter --check --skip-keypress --report-warnings-only >> "${REPORT_FILE}" 2>&1
fi

echo "Full audit report: ${REPORT_FILE}"
