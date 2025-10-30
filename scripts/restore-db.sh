#!/bin/bash
set -e

echo "LimeSurvey Database Restore Script"
echo "==================================="

# Check if credentials file exists
CREDENTIALS_FILE="/backups/google-credentials.json"
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "Google credentials not found at $CREDENTIALS_FILE"
    echo "Skipping restore - starting with fresh database"
    exit 0
fi

# Check if restore was already done (marker file)
RESTORE_MARKER="/var/lib/mysql/.restore_completed"
if [ -f "$RESTORE_MARKER" ]; then
    echo "Database restore already completed, skipping..."
    exit 0
fi

echo "Installing Python and required packages..."
apt-get update > /dev/null 2>&1
apt-get install -y python3 python3-pip > /dev/null 2>&1
pip3 install --quiet google-api-python-client google-auth-httplib2 google-auth-oauthlib > /dev/null 2>&1

# Create Python script to download latest backup
cat > /tmp/download_backup.py << 'PYTHON_SCRIPT'
#!/usr/bin/env python3
import os
import sys
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload

CREDENTIALS_FILE = os.getenv('CREDENTIALS_FILE', '/backups/google-credentials.json')
GOOGLE_DRIVE_FOLDER_ID = os.getenv('GOOGLE_DRIVE_FOLDER_ID')
DOWNLOAD_PATH = '/tmp/latest_backup.sql.gz'

def download_latest_backup():
    """Download the latest backup from Google Drive"""
    if not GOOGLE_DRIVE_FOLDER_ID:
        print("ERROR: GOOGLE_DRIVE_FOLDER_ID not set")
        return None

    try:
        print("Authenticating with Google Drive...")
        credentials = service_account.Credentials.from_service_account_file(
            CREDENTIALS_FILE,
            scopes=['https://www.googleapis.com/auth/drive.readonly']
        )
        service = build('drive', 'v3', credentials=credentials)

        # List files in the backup folder, sorted by creation date (newest first)
        print(f"Searching for backups in folder: {GOOGLE_DRIVE_FOLDER_ID}")
        results = service.files().list(
            q=f"'{GOOGLE_DRIVE_FOLDER_ID}' in parents and name contains 'limesurvey_backup_' and trashed=false",
            orderBy='createdTime desc',
            pageSize=1,
            fields='files(id, name, createdTime)'
        ).execute()

        files = results.get('files', [])

        if not files:
            print("No backup files found in Google Drive")
            return None

        latest_file = files[0]
        print(f"Found latest backup: {latest_file['name']} (created: {latest_file['createdTime']})")

        # Download the file
        request = service.files().get_media(fileId=latest_file['id'])

        with open(DOWNLOAD_PATH, 'wb') as f:
            downloader = MediaIoBaseDownload(f, request)
            done = False
            while not done:
                status, done = downloader.next_chunk()
                if status:
                    print(f"Download progress: {int(status.progress() * 100)}%")

        print(f"Download completed: {DOWNLOAD_PATH}")
        return DOWNLOAD_PATH

    except Exception as e:
        print(f"ERROR downloading backup: {str(e)}")
        return None

if __name__ == '__main__':
    result = download_latest_backup()
    if result:
        sys.exit(0)
    else:
        sys.exit(1)
PYTHON_SCRIPT

# Export environment variable for Python script
export CREDENTIALS_FILE="$CREDENTIALS_FILE"

# Run Python script to download latest backup
echo "Downloading latest backup from Google Drive..."
if python3 /tmp/download_backup.py; then
    if [ -f "/tmp/latest_backup.sql.gz" ]; then
        echo "Backup downloaded successfully"
        echo "Restoring database..."

        # Wait for MySQL to be ready
        echo "Waiting for MySQL to be ready..."
        until mysqladmin ping -h"localhost" -u"root" -p"${MYSQL_ROOT_PASSWORD}" --silent 2>/dev/null; do
            echo "MySQL is unavailable - sleeping"
            sleep 2
        done

        # Restore the backup
        echo "Decompressing and restoring backup..."
        gunzip -c /tmp/latest_backup.sql.gz | mysql -h"localhost" -u"root" -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}"

        # Create marker file to prevent re-restore
        touch "$RESTORE_MARKER"

        # Cleanup
        rm -f /tmp/latest_backup.sql.gz
        rm -f /tmp/download_backup.py

        echo "Database restore completed successfully!"
    else
        echo "Backup file not found after download"
        echo "Starting with fresh database"
    fi
else
    echo "Failed to download backup from Google Drive"
    echo "Starting with fresh database"
fi

echo "Restore script finished"
