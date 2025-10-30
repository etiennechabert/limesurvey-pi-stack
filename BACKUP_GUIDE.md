# Backup Guide

Complete guide for backup configuration, encryption, and restore operations.

## Quick Start

### Enable Encryption (Recommended - 5 minutes)

```bash
# 1. Generate encryption key
openssl rand -base64 32

# 2. Save in 1Password

# 3. Add to .env
nano .env
# Add: BACKUP_ENCRYPTION_KEY=<your-generated-key>

# 4. Rebuild backup service
docker compose build db_backup
docker compose up -d db_backup

# 5. Verify
docker compose logs db_backup | grep "Encryption: ENABLED"
```

## Backup Configuration

### Frequency

Default: **Hourly** (configurable in `.env`)

```bash
# In .env file:
BACKUP_SCHEDULE=0 * * * *  # Every hour (default)

# Options:
# Every 2 hours: 0 */2 * * *
# Every 3 hours: 0 */3 * * *
# Every 6 hours: 0 */6 * * *
# Daily 3 AM:    0 3 * * *
```

**Recommendation:** Keep hourly for maximum protection (max 1 hour data loss).

### Retention Policy

Intelligent rotation saves 99% of storage space:

```bash
# Default retention (configurable in .env):
BACKUP_KEEP_HOURLY_HOURS=24      # Last 24 hours
BACKUP_KEEP_DAILY_DAYS=7         # Last 7 days
BACKUP_KEEP_WEEKLY_WEEKS=4       # Last 4 weeks
BACKUP_KEEP_MONTHLY_MONTHS=12    # Last 12 months
BACKUP_KEEP_YEARLY=true          # Forever
```

**Result:** ~47 backups instead of thousands!

### Encryption

**AES-256-CBC** with PBKDF2 (100,000 iterations)

- Files end with `.sql.gz.enc`
- Key stored in 1Password
- Government-grade security

## Restore Operations

### From Encrypted Backup

```bash
# 1. Download backup from Google Drive
# 2. Get key from 1Password
# 3. Decrypt
openssl enc -aes-256-cbc -d \
  -salt -pbkdf2 -iter 100000 \
  -in backup_20250130_120000.sql.gz.enc \
  -out backup.sql.gz \
  -pass pass:YOUR_KEY

# 4. Decompress
gunzip backup.sql.gz

# 5. Restore
docker compose down
docker volume rm limesurvey-lykebo_db_data
docker compose up -d database
sleep 30
docker compose exec -T database mysql -uroot -p$MYSQL_ROOT_PASSWORD limesurvey < backup.sql
docker compose up -d
```

### Manual Backup

```bash
docker compose exec db_backup python /app/backup.py
```

### Check Backup Status

```bash
# View logs
docker compose logs db_backup

# List local backups
ls -lh backups/

# Check Google Drive
# Visit your Google Drive folder
```

## Performance

### Expected Timing

| Database Size | Backup Time | Upload @ 2 Mbps |
|--------------|-------------|-----------------|
| 10-50 MB | ~5 sec | ~30-60 sec |
| 100-200 MB | ~20 sec | ~2-5 min |
| 500 MB-1 GB | ~60 sec | ~10-20 min |

### Resource Usage

- **CPU**: 25-40% spike during backup
- **RAM**: +50-150 MB temporary
- **Impact**: Minimal - users won't notice

## Data Persistence

### What Persists Across Reboots

✅ **Persists** (stored in Docker volumes):
- Survey data and responses
- User accounts and permissions
- Uploaded files
- LimeSurvey configuration

❌ **Does NOT trigger restore**:
- Container updates (Watchtower)
- Container restarts
- Pi reboots (unless RESTORE_ON_BOOT=true)

### When Restore Happens

Restore ONLY happens when:
1. ✅ First installation (empty database)
2. ✅ Manual volume deletion
3. ✅ RESTORE_ON_BOOT=true (every boot)

**Docker volumes persist across container updates!**

## Troubleshooting

### Backup Failing

```bash
# Check logs
docker compose logs db_backup

# Common issues:
# 1. Google credentials missing/invalid
ls -la google-credentials.json

# 2. Folder ID incorrect
grep GOOGLE_DRIVE_FOLDER_ID .env

# 3. Service account permissions
# Verify service account has Editor access to folder
```

### Encryption Not Working

```bash
# Check encryption is enabled
docker compose logs db_backup | grep "Encryption:"

# Should see: "Encryption: ENABLED"
# If not, check .env has BACKUP_ENCRYPTION_KEY set

# Rebuild if needed
docker compose build db_backup
docker compose up -d db_backup
```

### Restore Failing

```bash
# Check database logs
docker compose logs database

# Verify volume is empty
docker volume ls | grep db_data

# Check credentials in backups directory
docker compose exec database ls -la /backups/google-credentials.json
```

## FAQ

**Q: What if I lose the encryption key?**
A: Backups are permanently unrecoverable. Store key in 1Password + offline backup!

**Q: Can I change backup frequency?**
A: Yes, edit `BACKUP_SCHEDULE` in `.env` then rebuild: `docker compose up -d db_backup`

**Q: How much space do backups use?**
A: ~47 backups with rotation policy. Typical: 10-200 MB per backup (compressed + encrypted).

**Q: Does backup slow down LimeSurvey?**
A: Minimal impact. Uses `--single-transaction` (no table locks).

**Q: What happens if Google Drive is down?**
A: Backup fails but local copy is kept. Next hourly backup will retry.

**Q: Can I test restore without deleting data?**
A: Yes, decrypt to a file and inspect:
```bash
openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 \
  -in backup.sql.gz.enc -pass pass:YOUR_KEY | gunzip | head -n 20
```

## Best Practices

- ✅ Enable encryption
- ✅ Store key in 1Password + offline
- ✅ Test restore monthly
- ✅ Monitor backup logs weekly
- ✅ Keep hourly frequency
- ✅ Use RESTORE_ON_BOOT=true to validate backups work

## See Also

- [RESTORE_ON_BOOT.md](RESTORE_ON_BOOT.md) - Stateless Pi mode
- [README.md](README.md) - Main documentation
