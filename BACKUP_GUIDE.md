# Backup Guide

## Table of Contents
- [Enable Encryption](#enable-encryption)
- [Configuration](#configuration)
- [Restore Operations](#restore-operations)
- [Performance](#performance)
- [Data Persistence](#data-persistence)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

## Enable Encryption

```bash
# Generate key
openssl rand -base64 32

# Add to .env
BACKUP_ENCRYPTION_KEY=<your-key>

# Rebuild
docker compose build db_backup && docker compose up -d db_backup

# Verify
docker compose logs db_backup | grep "Encryption: ENABLED"
```

**Algorithm:** AES-256-CBC with PBKDF2 (100,000 iterations)

## Configuration

### Frequency

Default: Hourly (`BACKUP_SCHEDULE=0 * * * *`)

```bash
# In .env:
0 */2 * * *  # Every 2 hours
0 */6 * * *  # Every 6 hours
0 3 * * *    # Daily at 3 AM
```

### Retention Policy

Grandfather-father-son rotation (configurable in `.env`):

```bash
BACKUP_KEEP_HOURLY_HOURS=24      # Last 24 hours
BACKUP_KEEP_DAILY_DAYS=7         # Last 7 days
BACKUP_KEEP_WEEKLY_WEEKS=4       # Last 4 weeks
BACKUP_KEEP_MONTHLY_MONTHS=12    # Last 12 months
BACKUP_KEEP_YEARLY=true          # Keep yearly backups
```

Typical result: ~47 backups retained instead of thousands.

## Restore Operations

### From Encrypted Backup

```bash
# 1. Decrypt
openssl enc -aes-256-cbc -d \
  -salt -pbkdf2 -iter 100000 \
  -in backup_20250130_120000.sql.gz.enc \
  -out backup.sql.gz \
  -pass pass:YOUR_KEY

# 2. Decompress
gunzip backup.sql.gz

# 3. Restore
docker compose down
docker volume rm limesurvey-pi-stack_db_data
docker compose up -d database
sleep 30
docker compose exec -T database mariadb -uroot -p$MYSQL_ROOT_PASSWORD limesurvey < backup.sql
docker compose up -d
```

### Manual Backup

```bash
docker compose exec db_backup python /app/backup.py
```

### Check Status

```bash
# Logs
docker compose logs db_backup

# Local backups
ls -lh backups/

# Google Drive: Check your backup folder
```

## Performance

**Timing estimates:**

| Database Size | Backup | Upload (2 Mbps) |
|--------------|--------|-----------------|
| 10-50 MB | ~5 sec | ~30-60 sec |
| 100-200 MB | ~20 sec | ~2-5 min |
| 500 MB-1 GB | ~60 sec | ~10-20 min |

**Resource usage:**
- CPU: 25-40% spike during backup
- RAM: +50-150 MB temporary

## Data Persistence

**Persists across reboots (Docker volumes):**
- Survey data and responses
- User accounts
- Uploaded files
- LimeSurvey configuration

**Does NOT trigger restore:**
- Container updates (Watchtower)
- Container restarts
- Pi reboots (unless `RESTORE_ON_BOOT=true`)

**Restore happens when:**
- First installation (empty database)
- Manual volume deletion
- `RESTORE_ON_BOOT=true` (every boot)

## Troubleshooting

**Backup failing:**
```bash
# Check logs
docker compose logs db_backup

# Common issues:
ls -la google-credentials.json  # Missing credentials
grep GOOGLE_DRIVE_FOLDER_ID .env  # Wrong folder ID
# Verify service account has Editor access in Google Drive
```

**Encryption not working:**
```bash
# Check encryption enabled
docker compose logs db_backup | grep "Encryption:"

# Rebuild if needed
docker compose build db_backup && docker compose up -d db_backup
```

**Restore failing:**
```bash
# Check database logs
docker compose logs database

# Verify credentials
docker compose exec database ls -la /backups/google-credentials.json
```

## FAQ

**Q: Lost encryption key?**
A: Backups are unrecoverable. Store key in password manager + offline backup.

**Q: Change backup frequency?**
A: Edit `BACKUP_SCHEDULE` in `.env`, then: `docker compose up -d db_backup`

**Q: How much space?**
A: ~47 backups with rotation. Typical size: 10-200 MB per backup (compressed + encrypted).

**Q: Backup performance impact?**
A: Minimal. Uses `--single-transaction` (no table locks).

**Q: Google Drive down?**
A: Backup fails but local copy kept. Next backup will retry.

**Q: Test restore without deleting data?**
A: Decrypt and inspect:
```bash
openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 \
  -in backup.sql.gz.enc -pass pass:YOUR_KEY | gunzip | head -n 20
```
