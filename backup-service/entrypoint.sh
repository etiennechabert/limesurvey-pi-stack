#!/bin/bash
set -e

echo "Starting LimeSurvey Backup Service"
echo "=================================="

# Wait for database to be ready
echo "Waiting for database to be ready..."
until mysqladmin ping -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --silent; do
    echo "Database is unavailable - sleeping"
    sleep 5
done
echo "Database is ready!"

# Set up cron job
BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-0 * * * *}"
echo "Setting up cron job with schedule: $BACKUP_SCHEDULE"

# Create cron job
echo "$BACKUP_SCHEDULE cd /app && /usr/local/bin/python /app/backup.py >> /var/log/cron.log 2>&1" > /etc/cron.d/backup-cron

# Give execution rights on the cron job
chmod 0644 /etc/cron.d/backup-cron

# Apply cron job
crontab /etc/cron.d/backup-cron

# Run initial backup
echo "Running initial backup..."
/usr/local/bin/python /app/backup.py

# Start cron in foreground
echo "Starting cron daemon..."
echo "Logs will be available in /var/log/cron.log"
cron && tail -f /var/log/cron.log
