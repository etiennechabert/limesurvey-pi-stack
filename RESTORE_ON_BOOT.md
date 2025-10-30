# Restore on Boot - Stateless Mode

## Table of Contents
- [Overview](#overview)
- [Trade-offs](#trade-offs)
- [Setup](#setup)
- [Verification](#verification)
- [Use Cases](#use-cases)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

## Overview

When enabled, Pi deletes all Docker volumes and restores from latest Google Drive backup on every boot.

**What happens:**
1. Boot → delete volumes → restore from Google Drive → start services
2. Google Drive becomes single source of truth
3. Local data is ephemeral

**Normal mode:** Docker volumes persist across reboots
**Restore mode:** Volumes deleted, fresh restore every boot

## Trade-offs

**Benefits:**
- Validates backups work every boot
- Stateless infrastructure (disposable Pi)
- Easy disaster recovery
- Fresh start eliminates accumulated issues

**Costs:**
- Data loss between backups (max 1 hour with hourly backups)
- Slower boot (~5-7 min vs ~2 min)
- Requires internet connection on boot
- Needs valid Google Drive credentials

## Setup

**1. Enable in `.env`:**
```bash
cd ~/limesurvey-pi-stack
nano .env
# Set: RESTORE_ON_BOOT=true
```

**2. Make script executable:**
```bash
chmod +x scripts/restore-on-boot.sh
```

**3. Update systemd:**
```bash
sudo cp limesurvey.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl restart limesurvey.service
```

**4. Test:**
```bash
sudo reboot
```

## Verification

**Check logs:**
```bash
# View restore process
sudo journalctl -u limesurvey.service | grep -A 10 "RESTORE_ON_BOOT"

# Verify database restore
docker compose logs database | grep -i restore
```

**Expected output:**
```
RESTORE_ON_BOOT ENABLED
Deleting volumes...
✓ Deleted: db_data
✓ Deleted: limesurvey_data
✓ Deleted: limesurvey_config
Volume cleanup complete!
```

## Use Cases

**Enable if:**
- Testing/development environment
- Need backup validation
- Disposable infrastructure desired
- Can tolerate 1-hour data loss

**Disable if:**
- Continuous survey responses
- Unreliable internet
- Large database (slow restore)
- Fast boot time required

## Troubleshooting

**Volumes still persist:**
```bash
# Verify setting
grep RESTORE_ON_BOOT .env

# Check logs
sudo journalctl -u limesurvey.service -b | grep "RESTORE_ON_BOOT"

# Manual test
./scripts/restore-on-boot.sh
```

**Restore fails:**
```bash
# Check credentials
ls -la google-credentials.json

# Check internet
ping -c 3 google.com

# View errors
docker compose logs database
```

**Boot takes too long:**
```bash
# Check backup size
docker compose exec db_backup ls -lh /backups

# If > 500MB, consider disabling or optimizing database
```

## FAQ

**Q: Will I lose uploaded files?**
A: No, if uploaded before last backup. The `limesurvey_data` volume is backed up.

**Q: Can I restore a specific backup?**
A: Yes, manually:
```bash
# Download specific backup from Google Drive
docker compose down
docker volume rm limesurvey-pi-stack_db_data
docker compose up -d database
sleep 30
docker compose exec -T database mariadb -uroot -p$MYSQL_ROOT_PASSWORD limesurvey < backup.sql
docker compose up -d
```

**Q: Affects Netdata data?**
A: No. Netdata volumes are not deleted.

**Q: What if Google Drive is down?**
A: Boot fails until Google Drive is accessible or you disable `RESTORE_ON_BOOT`.

**Q: Keep local backups as fallback?**
A: Yes. Last 5 local backups kept in `/backups/` folder.

**Q: Disable restore mode?**
A:
```bash
nano .env
# Set: RESTORE_ON_BOOT=false
sudo systemctl daemon-reload  # Optional
```

## Data Loss Window

```
1:00 PM - Backup taken
2:00 PM - Backup taken (latest)
2:30 PM - Pi reboots
         └─> Data since 2:00 PM is lost
2:35 PM - Restored from 2:00 PM backup
```

**Max data at risk:** Time since last hourly backup (max 1 hour)

**Minimize risk:** Reboot shortly after the hour (e.g., 3:05 PM)
