#!/bin/bash
# Emergency rollback script for critical failures

set -euo pipefail

# Configuration
MAILCOW_PATH="/opt/mailcow-dockerized"
BACKUP_PATH="/backup/mailcow"
LOG_FILE="/var/log/emergency-rollback.log"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

log "EMERGENCY ROLLBACK INITIATED"

# Stop all services
log "Stopping all Mailcow services..."
cd "${MAILCOW_PATH}"
docker compose down

# Find latest backup
LATEST_BACKUP=$(find "${BACKUP_PATH}" -maxdepth 1 -type d -name "mailcow_backup_*" -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)

if [ -z "${LATEST_BACKUP}" ]; then
    log "ERROR: No backup found for rollback"
    exit 1
fi

log "Using backup: ${LATEST_BACKUP}"

# Restore from backup
log "Restoring from backup..."
cd "${MAILCOW_PATH}"
./helper-scripts/backup_and_restore.sh restore "${LATEST_BACKUP}"

# Start services
log "Starting services..."
docker compose up -d

# Wait for services to be healthy
log "Waiting for services to be healthy..."
sleep 30

# Verify services
if docker compose ps | grep -q "unhealthy"; then
    log "WARNING: Some services are unhealthy after rollback"
else
    log "All services appear healthy"
fi

log "EMERGENCY ROLLBACK COMPLETED"
log "Please verify all services manually"

# Send notification
if [ -n "${ADMIN_EMAIL:-}" ]; then
    echo "Emergency rollback completed at $(date). Please check the system." | \
        mail -s "[EMERGENCY] Rollback completed on $(hostname)" "${ADMIN_EMAIL}"
fi
