#!/bin/bash
set -e

# Restore on Boot Script
# This script is called by systemd before starting Docker containers
# If RESTORE_ON_BOOT=true, it deletes all volumes to force a fresh restore from Google Drive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
else
    echo "ERROR: .env file not found at $PROJECT_DIR/.env"
    exit 1
fi

# Check if RESTORE_ON_BOOT is enabled
if [ "$RESTORE_ON_BOOT" != "true" ]; then
    echo "RESTORE_ON_BOOT is disabled. Skipping volume cleanup."
    echo "Volumes will persist across reboots (normal mode)."
    exit 0
fi

echo "=========================================="
echo "RESTORE_ON_BOOT ENABLED"
echo "=========================================="
echo "This will DELETE all Docker volumes and restore from Google Drive backup."
echo "Google Drive is your source of truth."
echo ""

# Change to project directory
cd "$PROJECT_DIR"

# Check if containers are running
if docker compose ps --quiet 2>/dev/null | grep -q .; then
    echo "Stopping running containers..."
    docker compose down
fi

# List volumes that will be deleted
echo ""
echo "Volumes to be deleted:"
docker volume ls | grep limesurvey-lykebo || echo "No volumes found (first boot?)"
echo ""

# Delete volumes (this triggers restore on next startup)
echo "Deleting volumes..."
docker volume rm limesurvey-lykebo_db_data 2>/dev/null && echo "✓ Deleted: db_data" || echo "- db_data not found (may not exist yet)"
docker volume rm limesurvey-lykebo_limesurvey_data 2>/dev/null && echo "✓ Deleted: limesurvey_data" || echo "- limesurvey_data not found (may not exist yet)"
docker volume rm limesurvey-lykebo_limesurvey_config 2>/dev/null && echo "✓ Deleted: limesurvey_config" || echo "- limesurvey_config not found (may not exist yet)"

# Note: We don't delete Netdata volumes as they contain monitoring configuration
echo ""
echo "✓ Volume cleanup complete!"
echo "On startup, database will restore from latest Google Drive backup."
echo "=========================================="
