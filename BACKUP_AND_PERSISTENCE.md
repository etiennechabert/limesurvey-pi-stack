# Backup, Restore & Data Persistence Guide

## Critical Understanding: Container Restarts ≠ Data Loss

### The Key Concept: Docker Volumes

**Your data lives in Docker volumes, NOT in containers:**

```
Container (ephemeral)          Volume (persistent)
┌─────────────────┐           ┌──────────────────┐
│  MariaDB        │           │   db_data        │
│  (the program)  │───uses───>│   (your data)    │
│                 │           │                   │
│  Can be:        │           │  NEVER deleted   │
│  - Updated      │           │  unless you      │
│  - Restarted    │           │  explicitly      │
│  - Replaced     │           │  remove it       │
└─────────────────┘           └──────────────────┘
```

### What Persists Across Container Restarts/Updates

| Data Type | Storage Location | Survives Restart? | Survives Update? |
|-----------|------------------|-------------------|------------------|
| **Database data** | `db_data` volume | ✅ YES | ✅ YES |
| **Survey responses** | `db_data` volume | ✅ YES | ✅ YES |
| **LimeSurvey uploads** | `limesurvey_data` volume | ✅ YES | ✅ YES |
| **LimeSurvey config** | `limesurvey_config` volume | ✅ YES | ✅ YES |
| **Local backups** | `./backups/` folder | ✅ YES | ✅ YES |
| **Netdata config** | `netdata_config` volume | ✅ YES | ✅ YES |
| **Container itself** | Docker image | ❌ NO | ❌ NO (replaced) |

## When Does Database Restore from Cloud Happen?

### ✅ Automatic Restore Triggers

**ONLY these scenarios trigger cloud restore:**

#### 1. First Installation (Empty Volume)
```bash
cd ~/limesurvey-lykebo
docker compose up -d
# Database volume is empty → Restore runs
```

#### 2. Manual Volume Deletion
```bash
docker compose down
docker volume rm limesurvey-lykebo_db_data
docker compose up -d
# Volume deleted → Restore runs
```

### ❌ What Does NOT Trigger Restore

These actions do NOT restore from cloud (data persists):

#### Container Restart
```bash
docker compose restart database
# Uses existing volume → No restore
```

#### Container Update (Watchtower)
```bash
# Watchtower updates database image
# Uses existing volume → No restore
```

#### Container Recreate
```bash
docker compose up -d --force-recreate
# Uses existing volume → No restore
```

#### System Reboot
```bash
sudo reboot
# Containers start, use existing volumes → No restore
```

#### Manual Stop/Start
```bash
docker compose stop database
docker compose start database
# Uses existing volume → No restore
```

## The Restore Logic

### How the System Knows to Restore or Not

**Marker File Check:**
```bash
# Location: /var/lib/mysql/.restore_completed

# First run:
if [ -f "$RESTORE_MARKER" ]; then
    echo "Already restored, skipping"  # Marker exists
    exit 0
else
    echo "New installation, restoring"  # Marker missing
    # Download from Google Drive
    # Restore database
    touch "$RESTORE_MARKER"  # Create marker
fi
```

**Once the marker file exists, restore NEVER runs again.**

## Backup Strategy

### Hourly Backups to Google Drive

**Schedule:** Every hour at :00 (1:00, 2:00, 3:00, etc.)

**What happens:**
```
1. Backup cron wakes up
2. Runs mysqldump (database snapshot)
3. Compresses with gzip
4. Uploads to Google Drive
5. Keeps last 5 local backups
6. Deletes older local backups
```

**Important notes:**
- ✅ Backup runs WHILE database is running (no downtime)
- ✅ Uses `--single-transaction` (consistent snapshot)
- ✅ Does NOT lock tables
- ✅ Survey users can continue working

### Backup Timing vs Watchtower Updates

**Previous Problem (FIXED):**
```
❌ OLD:
3:00 AM - Backup runs
3:00 AM - Watchtower runs
         ↓
     CONFLICT!
```

**New Schedule (SAFE):**
```
✅ NEW:
3:00 AM - Backup completes
3:15 AM - Watchtower runs
         ↓
    NO CONFLICT!
```

**Watchtower now runs at 3:15 AM** to avoid the 3:00 AM backup.

### What If Backup Fails During Update?

**Scenario:** Watchtower updates database, backup fails

**Safety nets:**
1. **Previous backups preserved** - Last backup still in Google Drive
2. **Next hourly backup** - Will succeed at 4:00 AM
3. **5 local backups** - Still available on disk
4. **Rolling updates** - Watchtower updates one container at a time

**Worst case:** You lose 1 hour of backup (between 3:00 and 4:00 AM)

**Impact:** Minimal, since you have backups from 2:00 AM and earlier

## Data Loss Scenarios & Recovery

### Scenario 1: Accidental Volume Deletion

**What happened:**
```bash
docker volume rm limesurvey-lykebo_db_data  # Oops!
```

**Recovery (automatic):**
```bash
docker compose up -d
# System detects empty volume
# Automatically restores latest backup from Google Drive
# ✅ Data recovered!
```

**Data lost:** Changes since last backup (max 1 hour)

### Scenario 2: Database Container Update

**What happened:**
```
Watchtower updated MariaDB from v11.0 to v11.1
```

**Recovery:**
```
NO RECOVERY NEEDED
Volume persists, data intact
✅ No data lost!
```

### Scenario 3: Pi SD Card Failure

**What happened:**
```
SD card corrupted, Pi won't boot
```

**Recovery:**
```bash
# 1. New SD card with fresh Raspberry Pi OS
# 2. Reinstall Docker
# 3. Copy limesurvey-lykebo folder
# 4. Start containers
docker compose up -d
# System detects empty volumes
# Automatically restores from Google Drive
# ✅ Data recovered!
```

**Data lost:** Changes since last backup (max 1 hour)

### Scenario 4: Google Drive Backup Deleted

**What happened:**
```
All backups accidentally deleted from Google Drive
```

**Recovery:**
```bash
# Local backups still exist!
ls backups/
# limesurvey_backup_20250130_020000.sql.gz  ← 2 AM
# limesurvey_backup_20250130_010000.sql.gz  ← 1 AM
# limesurvey_backup_20250130_000000.sql.gz  ← 12 AM
# ...

# Manual restore
docker compose down
docker volume rm limesurvey-lykebo_db_data
docker compose up -d database

# Wait for database to initialize, then:
gunzip -c backups/limesurvey_backup_20250130_020000.sql.gz | \
  docker compose exec -T database mysql -uroot -p$MYSQL_ROOT_PASSWORD limesurvey
```

**Data lost:** Changes since that backup

### Scenario 5: Container Restart During Backup

**What happened:**
```
3:00 AM - Backup starts
3:05 AM - Docker restarts database (health check failure)
3:05 AM - Backup fails
```

**Recovery:**
```
NO RECOVERY NEEDED
4:00 AM - Next backup runs successfully
Previous backup (2:00 AM) still in Google Drive
✅ Minimal impact!
```

**Data lost:** None! Next backup will catch up.

## Manual Backup & Restore

### Force Immediate Backup

```bash
# Trigger backup manually
docker compose exec db_backup python /app/backup.py

# Check if it succeeded
docker compose logs db_backup | tail -20

# Verify in Google Drive
# Should see: limesurvey_backup_YYYYMMDD_HHMMSS.sql.gz
```

### Restore from Specific Backup

```bash
# 1. Stop everything
docker compose down

# 2. Remove database volume
docker volume rm limesurvey-lykebo_db_data

# 3. Start database only
docker compose up -d database

# 4. Wait for database to initialize (30 seconds)
sleep 30

# 5. Download specific backup from Google Drive manually
# Or use local backup

# 6. Restore
gunzip -c backups/limesurvey_backup_20250130_120000.sql.gz | \
  docker compose exec -T database mysql -uroot -p$MYSQL_ROOT_PASSWORD limesurvey

# 7. Start other services
docker compose up -d
```

### Restore from Google Drive (Manual)

If you need to restore from a specific Google Drive backup:

```bash
# 1. Go to Google Drive
# 2. Download specific backup file
# 3. Copy to backups/ folder
# 4. Follow "Restore from Specific Backup" steps above
```

## Testing Your Backups

### Verify Backups Are Working

```bash
# 1. Check backup logs
docker compose logs db_backup | grep -i "success"

# 2. Check local backups exist
ls -lh backups/

# 3. Check Google Drive
# Go to your backup folder, should see recent files

# 4. Verify backup age
ls -lt backups/ | head -n 2
# Should show file from last hour
```

### Test Restore Process (SAFE)

**Create a test environment:**

```bash
# 1. Create test directory
mkdir -p ~/limesurvey-test
cd ~/limesurvey-test

# 2. Copy compose file and credentials
cp ~/limesurvey-lykebo/docker-compose.yml .
cp ~/limesurvey-lykebo/google-credentials.json .
cp ~/limesurvey-lykebo/.env .

# 3. Edit docker-compose.yml, change ports to avoid conflicts
# 8080 → 8090, 8081 → 8091, etc.

# 4. Start (will restore from Google Drive)
docker compose up -d

# 5. Check if restore worked
docker compose logs database | grep -i "restore"

# 6. Verify LimeSurvey has your data
# Go to http://<pi-ip>:8090

# 7. Cleanup test environment
docker compose down -v
cd ~
rm -rf ~/limesurvey-test
```

## Backup Retention Policy

### Local Backups (on Pi)

- **Retention:** Last 5 backups only
- **Location:** `./backups/`
- **Space:** ~50-200MB depending on data size
- **Cleanup:** Automatic after each backup

### Google Drive Backups

- **Retention:** ∞ (unlimited, unless you manually delete)
- **Location:** Your Google Drive folder
- **Space:** Uses your Google Drive quota
- **Cleanup:** Manual (optional)

**Recommendation:**
Periodically clean up old Google Drive backups to save space:
- Keep daily backups for last 7 days
- Keep weekly backups for last 4 weeks
- Keep monthly backups for last 12 months

## Best Practices

### ✅ DO

- **Test restore regularly** - At least monthly
- **Monitor backup logs** - Check they're succeeding
- **Keep local backups** - Don't delete `./backups/` folder
- **Verify Google Drive** - Check backups are uploading
- **Document restore procedures** - For future you
- **Keep credentials safe** - `google-credentials.json`

### ❌ DON'T

- **Don't delete volumes casually** - Data will be lost
- **Don't assume updates restore data** - They don't!
- **Don't skip backup verification** - Test your backups!
- **Don't rely on one backup** - Google Drive + local is safer
- **Don't share credentials** - Keep them secret

## Monitoring Backups

### Netdata Backup Alerts

Netdata monitors the backup service:
- ✅ Backup cron is running
- ✅ Container is healthy
- ❌ Cannot detect if backups are uploading successfully

### Check Backup Success

```bash
# View recent backup logs
docker compose logs db_backup --tail=100 | grep -A 5 "Starting"

# Check for errors
docker compose logs db_backup | grep -i error

# Verify latest backup timestamp
ls -lth backups/ | head -n 2

# Check backup age (should be < 1 hour old)
find backups/ -name "*.sql.gz" -mmin -70 -ls
```

### Setup Backup Monitoring (Optional)

**Get notified when backups fail:**

1. **Option A: Modify backup script to send email on failure**
2. **Option B: Use external monitoring (UptimeRobot, etc.)**
3. **Option C: Check Netdata regularly**

## FAQ

### Q: Will Watchtower delete my data?

**A:** NO. Watchtower only updates container images, not volumes. Your data is safe.

### Q: How often should I test restores?

**A:** At least once a month, or before major changes.

### Q: Can I disable hourly backups?

**A:** Yes, change `BACKUP_SCHEDULE` in `docker-compose.yml`. Example for daily:
```yaml
BACKUP_SCHEDULE: "0 0 2 * * *"  # 2 AM daily
```

### Q: What if I run out of Google Drive space?

**A:** Backups will fail. Clean up old backups or upgrade Google Drive storage.

### Q: Can I backup to a different cloud provider?

**A:** Yes, but you'll need to modify `backup.py` to use different API (S3, Dropbox, etc.).

### Q: Will survey respondents lose data during an update?

**A:**
- **Completed responses:** NO, saved to database
- **In-progress responses:** Depends on LimeSurvey's session handling
- **Recommendation:** Schedule updates during low-traffic hours

### Q: How do I backup survey files (PDFs, images)?

**A:** They're in `limesurvey_data` volume. To backup:
```bash
docker run --rm -v limesurvey-lykebo_limesurvey_data:/data -v $(pwd):/backup \
  ubuntu tar czf /backup/limesurvey_files_backup.tar.gz /data
```

## Summary

| Event | Data Persists? | Backup Needed? | Restore Triggered? |
|-------|----------------|----------------|-------------------|
| Container restart | ✅ YES | ❌ NO | ❌ NO |
| Container update | ✅ YES | ❌ NO | ❌ NO |
| System reboot | ✅ YES | ❌ NO | ❌ NO |
| Volume deletion | ❌ NO | ✅ YES | ✅ YES (auto) |
| SD card failure | ❌ NO | ✅ YES | ✅ YES (auto) |
| Fresh install | ❌ NO | ✅ YES | ✅ YES (auto) |

**Key Takeaway:** Your data is safe in volumes. Updates and restarts do NOT cause data loss or restoration.
