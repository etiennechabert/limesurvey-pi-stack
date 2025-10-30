#!/usr/bin/env python3
"""
Database Backup Script for LimeSurvey
Backs up MariaDB database and uploads to Google Drive
"""

import os
import subprocess
import datetime
import sys
import re
from pathlib import Path
from collections import defaultdict
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from googleapiclient.errors import HttpError

# Configuration from environment variables
MYSQL_HOST = os.getenv('MYSQL_HOST', 'database')
MYSQL_USER = os.getenv('MYSQL_USER', 'root')
MYSQL_PASSWORD = os.getenv('MYSQL_PASSWORD')
MYSQL_DATABASE = os.getenv('MYSQL_DATABASE', 'limesurvey')
GOOGLE_DRIVE_FOLDER_ID = os.getenv('GOOGLE_DRIVE_FOLDER_ID')
BACKUP_DIR = '/backups'
CREDENTIALS_FILE = '/app/credentials.json'

# Keep only last N local backups to save space
MAX_LOCAL_BACKUPS = 5

# Google Drive Backup Retention Policy
# Keep all hourly backups for last N hours
KEEP_HOURLY_FOR_HOURS = int(os.getenv('BACKUP_KEEP_HOURLY_HOURS', '24'))
# Keep one daily backup for last N days
KEEP_DAILY_FOR_DAYS = int(os.getenv('BACKUP_KEEP_DAILY_DAYS', '7'))
# Keep one weekly backup for last N weeks
KEEP_WEEKLY_FOR_WEEKS = int(os.getenv('BACKUP_KEEP_WEEKLY_WEEKS', '4'))
# Keep one monthly backup for last N months
KEEP_MONTHLY_FOR_MONTHS = int(os.getenv('BACKUP_KEEP_MONTHLY_MONTHS', '12'))
# Keep yearly backups forever (0 = disabled)
KEEP_YEARLY = os.getenv('BACKUP_KEEP_YEARLY', 'true').lower() == 'true'

# Backup Encryption
# Set BACKUP_ENCRYPTION_KEY to enable encryption (store in 1Password!)
BACKUP_ENCRYPTION_KEY = os.getenv('BACKUP_ENCRYPTION_KEY', '')
ENCRYPTION_ENABLED = bool(BACKUP_ENCRYPTION_KEY)

def log(message):
    """Print timestamped log message"""
    timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{timestamp}] {message}", flush=True)

def encrypt_backup(file_path):
    """
    Encrypt backup file using AES-256-CBC with password
    Uses openssl for encryption (compatible with standard tools)
    """
    if not ENCRYPTION_ENABLED:
        log("Encryption disabled (BACKUP_ENCRYPTION_KEY not set)")
        return file_path

    encrypted_path = f"{file_path}.enc"
    log(f"Encrypting backup with AES-256...")

    try:
        # Use openssl for AES-256-CBC encryption
        # -pbkdf2 uses modern key derivation (more secure than old -md5)
        # -iter 100000 makes brute force attacks much slower
        encrypt_cmd = [
            'openssl', 'enc', '-aes-256-cbc',
            '-salt',
            '-pbkdf2',
            '-iter', '100000',
            '-in', file_path,
            '-out', encrypted_path,
            '-pass', f'pass:{BACKUP_ENCRYPTION_KEY}'
        ]

        result = subprocess.run(
            encrypt_cmd,
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            log(f"ERROR: Encryption failed: {result.stderr}")
            return None

        # Verify encrypted file was created
        if not os.path.exists(encrypted_path):
            log("ERROR: Encrypted file was not created")
            return None

        encrypted_size = os.path.getsize(encrypted_path)
        log(f"Encryption successful: {encrypted_path} ({encrypted_size / 1024 / 1024:.2f} MB)")

        # Remove unencrypted file for security
        os.remove(file_path)
        log(f"Removed unencrypted backup: {file_path}")

        return encrypted_path

    except Exception as e:
        log(f"ERROR during encryption: {str(e)}")
        return None

def create_database_backup():
    """Create a mysqldump backup of the database"""
    timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_filename = f"limesurvey_backup_{timestamp}.sql.gz"
    backup_path = os.path.join(BACKUP_DIR, backup_filename)

    log(f"Creating database backup: {backup_filename}")

    try:
        # Create mysqldump and compress it
        dump_cmd = [
            'mysqldump',
            f'--host={MYSQL_HOST}',
            f'--user={MYSQL_USER}',
            f'--password={MYSQL_PASSWORD}',
            '--single-transaction',
            '--quick',
            '--lock-tables=false',
            MYSQL_DATABASE
        ]

        gzip_cmd = ['gzip', '-c']

        # Run mysqldump and pipe to gzip
        with open(backup_path, 'wb') as backup_file:
            dump_process = subprocess.Popen(
                dump_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            gzip_process = subprocess.Popen(
                gzip_cmd,
                stdin=dump_process.stdout,
                stdout=backup_file,
                stderr=subprocess.PIPE
            )

            dump_process.stdout.close()
            gzip_stdout, gzip_stderr = gzip_process.communicate()
            dump_stderr = dump_process.stderr.read()

            if dump_process.returncode != 0:
                log(f"ERROR: mysqldump failed: {dump_stderr.decode()}")
                return None

            if gzip_process.returncode != 0:
                log(f"ERROR: gzip failed: {gzip_stderr.decode()}")
                return None

        file_size = os.path.getsize(backup_path)
        log(f"Backup created successfully: {backup_path} ({file_size / 1024 / 1024:.2f} MB)")
        return backup_path

    except Exception as e:
        log(f"ERROR creating backup: {str(e)}")
        return None

def upload_to_google_drive(file_path):
    """Upload backup file to Google Drive"""
    if not os.path.exists(CREDENTIALS_FILE):
        log(f"ERROR: Credentials file not found at {CREDENTIALS_FILE}")
        return False

    if not GOOGLE_DRIVE_FOLDER_ID:
        log("ERROR: GOOGLE_DRIVE_FOLDER_ID not set")
        return False

    try:
        log("Authenticating with Google Drive...")
        credentials = service_account.Credentials.from_service_account_file(
            CREDENTIALS_FILE,
            scopes=['https://www.googleapis.com/auth/drive.file']
        )
        service = build('drive', 'v3', credentials=credentials)

        file_name = os.path.basename(file_path)
        log(f"Uploading {file_name} to Google Drive...")

        file_metadata = {
            'name': file_name,
            'parents': [GOOGLE_DRIVE_FOLDER_ID]
        }

        media = MediaFileUpload(
            file_path,
            mimetype='application/gzip',
            resumable=True
        )

        file = service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id, name, size'
        ).execute()

        log(f"Upload successful! File ID: {file.get('id')}")
        return True

    except HttpError as e:
        log(f"ERROR uploading to Google Drive: {str(e)}")
        return False
    except Exception as e:
        log(f"ERROR: {str(e)}")
        return False

def cleanup_old_local_backups():
    """Remove old local backups, keeping only the latest ones"""
    try:
        backup_files = sorted(
            Path(BACKUP_DIR).glob('limesurvey_backup_*.sql.gz'),
            key=lambda x: x.stat().st_mtime,
            reverse=True
        )

        if len(backup_files) > MAX_LOCAL_BACKUPS:
            for old_backup in backup_files[MAX_LOCAL_BACKUPS:]:
                log(f"Removing old local backup: {old_backup.name}")
                old_backup.unlink()

    except Exception as e:
        log(f"ERROR cleaning up old local backups: {str(e)}")

def parse_backup_timestamp(filename):
    """Extract timestamp from backup filename (handles both encrypted and unencrypted)"""
    # Format: limesurvey_backup_YYYYMMDD_HHMMSS.sql.gz or .sql.gz.enc
    match = re.search(r'limesurvey_backup_(\d{8})_(\d{6})\.sql\.gz', filename)
    if match:
        date_str = match.group(1)
        time_str = match.group(2)
        return datetime.datetime.strptime(f"{date_str}_{time_str}", "%Y%m%d_%H%M%S")
    return None

def cleanup_google_drive_backups():
    """
    Apply backup rotation policy to Google Drive backups

    Retention policy:
    - Hourly: Keep all backups from last N hours
    - Daily: Keep one backup per day for last N days
    - Weekly: Keep one backup per week for last N weeks
    - Monthly: Keep one backup per month for last N months
    - Yearly: Keep one backup per year (forever if enabled)
    """
    if not os.path.exists(CREDENTIALS_FILE):
        log("WARNING: Credentials file not found, skipping Google Drive cleanup")
        return

    if not GOOGLE_DRIVE_FOLDER_ID:
        log("WARNING: GOOGLE_DRIVE_FOLDER_ID not set, skipping Google Drive cleanup")
        return

    try:
        log("Cleaning up old Google Drive backups...")

        # Authenticate
        credentials = service_account.Credentials.from_service_account_file(
            CREDENTIALS_FILE,
            scopes=['https://www.googleapis.com/auth/drive']
        )
        service = build('drive', 'v3', credentials=credentials)

        # List all backup files in the folder
        query = f"'{GOOGLE_DRIVE_FOLDER_ID}' in parents and name contains 'limesurvey_backup_' and trashed=false"
        results = service.files().list(
            q=query,
            fields='files(id, name, createdTime)',
            orderBy='createdTime desc',
            pageSize=1000
        ).execute()

        files = results.get('files', [])

        if not files:
            log("No backup files found in Google Drive")
            return

        log(f"Found {len(files)} backup files in Google Drive")

        # Parse timestamps and categorize backups
        backups_by_time = []
        for file in files:
            timestamp = parse_backup_timestamp(file['name'])
            if timestamp:
                backups_by_time.append({
                    'id': file['id'],
                    'name': file['name'],
                    'timestamp': timestamp
                })

        if not backups_by_time:
            log("No valid backup files found")
            return

        # Sort by timestamp (newest first)
        backups_by_time.sort(key=lambda x: x['timestamp'], reverse=True)

        now = datetime.datetime.now()
        files_to_keep = set()
        files_to_delete = []

        # Category 1: Hourly backups (keep all from last N hours)
        hourly_cutoff = now - datetime.timedelta(hours=KEEP_HOURLY_FOR_HOURS)
        hourly_backups = [b for b in backups_by_time if b['timestamp'] >= hourly_cutoff]
        for backup in hourly_backups:
            files_to_keep.add(backup['id'])
        log(f"Keeping {len(hourly_backups)} hourly backups (last {KEEP_HOURLY_FOR_HOURS}h)")

        # Category 2: Daily backups (keep one per day for last N days)
        daily_cutoff = now - datetime.timedelta(days=KEEP_DAILY_FOR_DAYS)
        daily_backups_by_day = defaultdict(list)
        for backup in backups_by_time:
            if backup['timestamp'] < hourly_cutoff and backup['timestamp'] >= daily_cutoff:
                day_key = backup['timestamp'].strftime('%Y-%m-%d')
                daily_backups_by_day[day_key].append(backup)

        daily_kept = 0
        for day, backups in daily_backups_by_day.items():
            # Keep the latest backup from each day
            if backups:
                files_to_keep.add(backups[0]['id'])
                daily_kept += 1
        log(f"Keeping {daily_kept} daily backups (last {KEEP_DAILY_FOR_DAYS} days)")

        # Category 3: Weekly backups (keep one per week for last N weeks)
        weekly_cutoff = now - datetime.timedelta(weeks=KEEP_WEEKLY_FOR_WEEKS)
        weekly_backups_by_week = defaultdict(list)
        for backup in backups_by_time:
            if backup['timestamp'] < daily_cutoff and backup['timestamp'] >= weekly_cutoff:
                # ISO week number
                week_key = backup['timestamp'].strftime('%Y-W%W')
                weekly_backups_by_week[week_key].append(backup)

        weekly_kept = 0
        for week, backups in weekly_backups_by_week.items():
            if backups:
                files_to_keep.add(backups[0]['id'])
                weekly_kept += 1
        log(f"Keeping {weekly_kept} weekly backups (last {KEEP_WEEKLY_FOR_WEEKS} weeks)")

        # Category 4: Monthly backups (keep one per month for last N months)
        monthly_cutoff = now - datetime.timedelta(days=30 * KEEP_MONTHLY_FOR_MONTHS)
        monthly_backups_by_month = defaultdict(list)
        for backup in backups_by_time:
            if backup['timestamp'] < weekly_cutoff and backup['timestamp'] >= monthly_cutoff:
                month_key = backup['timestamp'].strftime('%Y-%m')
                monthly_backups_by_month[month_key].append(backup)

        monthly_kept = 0
        for month, backups in monthly_backups_by_month.items():
            if backups:
                files_to_keep.add(backups[0]['id'])
                monthly_kept += 1
        log(f"Keeping {monthly_kept} monthly backups (last {KEEP_MONTHLY_FOR_MONTHS} months)")

        # Category 5: Yearly backups (keep one per year forever)
        yearly_kept = 0
        if KEEP_YEARLY:
            yearly_backups_by_year = defaultdict(list)
            for backup in backups_by_time:
                if backup['timestamp'] < monthly_cutoff:
                    year_key = backup['timestamp'].strftime('%Y')
                    yearly_backups_by_year[year_key].append(backup)

            for year, backups in yearly_backups_by_year.items():
                if backups:
                    files_to_keep.add(backups[0]['id'])
                    yearly_kept += 1
            log(f"Keeping {yearly_kept} yearly backups")

        # Identify files to delete
        for backup in backups_by_time:
            if backup['id'] not in files_to_keep:
                files_to_delete.append(backup)

        # Delete old backups
        if files_to_delete:
            log(f"Deleting {len(files_to_delete)} old backups from Google Drive...")
            deleted_count = 0
            for backup in files_to_delete:
                try:
                    service.files().delete(fileId=backup['id']).execute()
                    log(f"  Deleted: {backup['name']} (from {backup['timestamp'].strftime('%Y-%m-%d %H:%M')})")
                    deleted_count += 1
                except HttpError as e:
                    log(f"  ERROR deleting {backup['name']}: {str(e)}")

            log(f"Successfully deleted {deleted_count} old backups")
        else:
            log("No old backups to delete")

        total_kept = len(files_to_keep)
        log(f"Total backups kept in Google Drive: {total_kept}")
        log(f"  - Hourly: {len(hourly_backups)}")
        log(f"  - Daily: {daily_kept}")
        log(f"  - Weekly: {weekly_kept}")
        log(f"  - Monthly: {monthly_kept}")
        if KEEP_YEARLY:
            log(f"  - Yearly: {yearly_kept}")

    except HttpError as e:
        log(f"ERROR during Google Drive cleanup: {str(e)}")
    except Exception as e:
        log(f"ERROR during Google Drive cleanup: {str(e)}")

def main():
    """Main backup routine"""
    log("=" * 60)
    log("Starting LimeSurvey database backup")
    if ENCRYPTION_ENABLED:
        log("Encryption: ENABLED")
    else:
        log("Encryption: DISABLED (set BACKUP_ENCRYPTION_KEY to enable)")
    log("=" * 60)

    # Create backup
    backup_path = create_database_backup()
    if not backup_path:
        log("Backup failed!")
        sys.exit(1)

    # Encrypt backup (if enabled)
    final_backup_path = encrypt_backup(backup_path)
    if not final_backup_path:
        log("Encryption failed!")
        sys.exit(1)

    # Upload to Google Drive (encrypted or unencrypted)
    upload_success = upload_to_google_drive(final_backup_path)
    if not upload_success:
        log("Upload to Google Drive failed!")
        sys.exit(1)

    # Cleanup old local backups
    cleanup_old_local_backups()

    # Cleanup old Google Drive backups (apply rotation policy)
    cleanup_google_drive_backups()

    log("Backup completed successfully!")
    log("=" * 60)

if __name__ == '__main__':
    main()
