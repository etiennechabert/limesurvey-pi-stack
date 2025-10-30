# Restore on Boot - Stateless Pi Mode

## What is Restore on Boot?

When enabled, your Raspberry Pi will **delete all Docker volumes and restore from the latest Google Drive backup on every boot**. This makes your Pi completely stateless - Google Drive becomes your single source of truth.

## Why Use This?

### ✅ Benefits

1. **Validates Backups Work**
   - Every reboot proves your backup/restore process works
   - You'll know immediately if backups fail
   - Confidence in disaster recovery

2. **Fresh Start Every Boot**
   - No accumulated issues or corruption
   - Clean slate every time
   - Eliminates "works on my machine" problems

3. **Stateless Infrastructure**
   - Pi is disposable/replaceable
   - Easy to migrate to new hardware
   - Google Drive is the only persistent storage

4. **Simplifies Disaster Recovery**
   - Pi dies? Just boot a new one with same config
   - SD card corrupted? No problem, restore from cloud
   - Testing recovery is effortless

### ⚠️ Trade-offs

1. **Data Loss Between Backups**
   - Backups run hourly (on the hour)
   - Reboot at 2:30 PM? You lose changes since 2:00 PM backup
   - **Max 1 hour of data at risk**

2. **Slower Boot Time**
   - Must download and restore backup on every boot
   - Adds ~2-5 minutes to boot time (depends on backup size)
   - Normal mode: ~2 min boot, Restore mode: ~5-7 min boot

3. **Requires Working Google Drive Connection**
   - Can't boot if Google Drive is unreachable
   - Need internet connection on boot
   - Backup credentials must be valid

## How It Works

```
┌─────────────────────────────────────────────────────┐
│          Normal Boot (RESTORE_ON_BOOT=false)        │
├─────────────────────────────────────────────────────┤
│                                                     │
│  1. Pi boots                                        │
│  2. Systemd starts limesurvey.service              │
│  3. Docker volumes persist from last run            │
│  4. Containers start with existing data             │
│  5. Only restores if volumes are empty (first boot) │
│                                                     │
│  Boot time: ~2 minutes                              │
│  Data: Persists across reboots                      │
│                                                     │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│       Restore on Boot (RESTORE_ON_BOOT=true)        │
├─────────────────────────────────────────────────────┤
│                                                     │
│  1. Pi boots                                        │
│  2. Systemd starts limesurvey.service              │
│  3. restore-on-boot.sh runs                         │
│     ├─ Stops containers (if running)                │
│     ├─ Deletes all Docker volumes                   │
│     └─ Logs what was deleted                        │
│  4. Docker Compose starts containers                │
│  5. Database sees empty volume                      │
│  6. restore-db.sh downloads latest backup           │
│  7. Database restored from Google Drive             │
│  8. All services start with fresh data              │
│                                                     │
│  Boot time: ~5-7 minutes                            │
│  Data: Fresh from Google Drive every time           │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Setup (2 Minutes)

### Step 1: Enable in .env

```bash
cd ~/limesurvey-lykebo
nano .env
```

Change this line:
```bash
RESTORE_ON_BOOT=true
```

Save and exit (`Ctrl+X`, `Y`, `Enter`)

### Step 2: Make Script Executable

```bash
chmod +x scripts/restore-on-boot.sh
```

### Step 3: Update Systemd Service

```bash
# Copy updated service file
sudo cp limesurvey.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Restart to test
sudo systemctl restart limesurvey.service
```

### Step 4: Verify It's Working

```bash
# Watch systemd logs during boot
sudo journalctl -u limesurvey.service -f

# You should see:
# "RESTORE_ON_BOOT ENABLED"
# "Deleting volumes..."
# "✓ Deleted: db_data"
# "Volume cleanup complete!"
# "On startup, database will restore from latest Google Drive backup."
```

### Step 5: Test with Reboot

```bash
sudo reboot
```

After reboot:
```bash
# Check logs
sudo journalctl -u limesurvey.service | grep -A 10 "RESTORE_ON_BOOT"

# Check database was restored
docker compose logs database | grep -i "restore"

# Access LimeSurvey - should have data from latest backup
```

## Monitoring & Verification

### Check Restore Logs

```bash
# View full startup log
sudo journalctl -u limesurvey.service -b

# View only restore process
sudo journalctl -u limesurvey.service -b | grep -A 20 "RESTORE_ON_BOOT"

# View database restore
docker compose logs database | grep -i restore
```

### Expected Log Output

```
[systemd] Starting LimeSurvey Docker Compose Application...
==========================================
RESTORE_ON_BOOT ENABLED
==========================================
This will DELETE all Docker volumes and restore from Google Drive backup.
Google Drive is your source of truth.

Volumes to be deleted:
limesurvey-lykebo_db_data
limesurvey-lykebo_limesurvey_data
limesurvey-lykebo_limesurvey_config

Deleting volumes...
✓ Deleted: db_data
✓ Deleted: limesurvey_data
✓ Deleted: limesurvey_config

✓ Volume cleanup complete!
On startup, database will restore from latest Google Drive backup.
==========================================
[systemd] Started LimeSurvey Docker Compose Application.
```

## Use Cases

### When to Enable RESTORE_ON_BOOT

1. **Development/Testing Environment**
   - Need fresh state for testing
   - Want to test backup/restore frequently
   - Don't care about losing recent changes

2. **High Confidence Needed**
   - Mission-critical surveys
   - Must verify backups work
   - Can tolerate 1-hour data loss

3. **Stateless Infrastructure**
   - Treating Pi as disposable
   - Want to replicate to multiple Pis
   - Easy failover to backup hardware

4. **Trust Issues**
   - New to Docker/LimeSurvey
   - Want proof backups work
   - Peace of mind

### When to Keep Normal Mode (RESTORE_ON_BOOT=false)

1. **Production with Frequent Changes**
   - Surveys running continuously
   - Can't afford to lose 1 hour of responses
   - Prefer local persistence

2. **Limited Internet**
   - Unreliable internet connection
   - Slow download speeds
   - Can't wait for restore on boot

3. **Large Databases**
   - Multi-GB backups
   - Restore takes too long
   - Boot time is critical

4. **Trust in Infrastructure**
   - Confident in local storage
   - Backups are for disaster recovery only
   - Prefer fast boot times

## Disaster Recovery Scenarios

### Scenario 1: SD Card Corruption

**With RESTORE_ON_BOOT:**
```bash
# 1. Flash new SD card with Pi OS
# 2. Reinstall Docker
# 3. Copy project files
# 4. Copy .env and google-credentials.json
# 5. Enable limesurvey.service
# 6. Reboot
# → Automatically restores latest backup ✅
```

**Without RESTORE_ON_BOOT:**
```bash
# Same as above, but must manually:
# 7. Stop containers
# 8. Delete db_data volume
# 9. Start containers
# → Manual restore required ⚠️
```

### Scenario 2: Pi Hardware Failure

**With RESTORE_ON_BOOT:**
```bash
# 1. Get new Pi
# 2. Setup from scratch (QUICKSTART.md)
# 3. Boot
# → Up and running with latest data ✅
```

**Without RESTORE_ON_BOOT:**
```bash
# Same, but restore is manual
```

### Scenario 3: Accidental Data Deletion

**With RESTORE_ON_BOOT:**
```bash
# Just reboot the Pi
# Data from last hourly backup restored
# Lost: max 1 hour of data
```

**Without RESTORE_ON_BOOT:**
```bash
# Manual restore process:
docker compose down
docker volume rm limesurvey-lykebo_db_data
docker compose up -d
```

## Best Practices

### 1. Understand the Data Loss Window

```
Timeline of backups and data at risk:

1:00 PM - Backup #1 taken
         ↓ (changes made)
2:00 PM - Backup #2 taken  ← Latest backup
         ↓ (changes made)
2:30 PM - Pi reboots       ← Data since 2:00 PM is lost!
         ↓
2:35 PM - Restored from Backup #2 (2:00 PM)
3:00 PM - Backup #3 taken  ← New data now backed up
```

**Data at risk:** Changes between last backup and reboot (max 1 hour)

### 2. Time Your Reboots

**Best times to reboot:**
- Just after the hour (e.g., 3:05 PM)
- Minimizes data loss
- Backup just completed

**Worst times to reboot:**
- Just before the hour (e.g., 2:55 PM)
- Maximum data at risk
- Almost a full hour of changes lost

### 3. Monitor Backup Health

```bash
# Check when last backup was taken
docker compose exec db_backup ls -lth /backups | head -n 5

# Ensure backups are succeeding hourly
docker compose logs db_backup | grep "Backup completed successfully"

# Check Google Drive has recent backups
# (Go to Google Drive folder, verify files are recent)
```

### 4. Test Restore Regularly

**If RESTORE_ON_BOOT=true:**
- Every reboot tests restore (automatic!)
- No manual testing needed

**If RESTORE_ON_BOOT=false:**
- Test restore monthly:
  ```bash
  docker compose down
  docker volume rm limesurvey-lykebo_db_data
  docker compose up -d
  docker compose logs database -f
  ```

### 5. Keep Multiple Backup Copies

```bash
# Current retention policy:
# - 24 hourly backups (last 24 hours)
# - 7 daily backups (last week)
# - 4 weekly backups (last month)
# - 12 monthly backups (last year)
# - Yearly backups (forever)

# This means you have multiple restore points
# If latest backup is corrupted, you can restore an older one
```

## Troubleshooting

### Boot Fails After Enabling

**Check logs:**
```bash
sudo journalctl -u limesurvey.service -b
```

**Common issues:**
1. Script not executable
   - Fix: `chmod +x scripts/restore-on-boot.sh`

2. Wrong path in systemd service
   - Fix: Update WorkingDirectory in limesurvey.service

3. .env file not found
   - Fix: Ensure .env exists in project directory

### Restore Takes Too Long

**If backup is large:**
```bash
# Check backup size
docker compose exec db_backup ls -lh /backups

# If > 500MB, consider:
# 1. Cleaning up old survey data
# 2. Archiving old surveys
# 3. Using RESTORE_ON_BOOT=false for faster boots
```

### Restore Fails

**Check Google Drive credentials:**
```bash
# Verify credentials file exists
ls -la google-credentials.json

# Test Google Drive access
docker compose exec database ls -la /backups/google-credentials.json
```

**Check internet connection:**
```bash
ping -c 3 google.com
```

**Check backup exists:**
```bash
# View database logs for restore errors
docker compose logs database | grep -i "error\|fail"
```

### Data Still Persists After Reboot

**Verify RESTORE_ON_BOOT is enabled:**
```bash
grep RESTORE_ON_BOOT .env
# Should show: RESTORE_ON_BOOT=true
```

**Check if script ran:**
```bash
sudo journalctl -u limesurvey.service -b | grep "RESTORE_ON_BOOT"
# Should show volume deletion logs
```

**Manually test script:**
```bash
./scripts/restore-on-boot.sh
# Should delete volumes and show confirmation
```

## FAQ

### Q: Will I lose uploaded files (survey attachments, images)?

**A:** No, if they were uploaded before the last backup. The `limesurvey_data` volume (which stores uploads) is also backed up and restored.

### Q: Can I restore a specific backup, not the latest?

**A:** Yes, but requires manual process:
```bash
# 1. Download specific backup from Google Drive
# 2. Stop containers: docker compose down
# 3. Delete volume: docker volume rm limesurvey-lykebo_db_data
# 4. Start database only: docker compose up -d database
# 5. Wait 30 seconds
# 6. Restore specific backup:
docker compose exec -T database mysql -uroot -p$MYSQL_ROOT_PASSWORD limesurvey < backup.sql
# 7. Start all: docker compose up -d
```

### Q: Does this affect Netdata monitoring data?

**A:** No. Netdata volumes are NOT deleted to preserve your monitoring history and custom configurations.

### Q: What happens if Google Drive is down on boot?

**A:** Boot will fail. Database container will keep retrying to download backup. You can:
1. Wait for Google Drive to come back online
2. Disable RESTORE_ON_BOOT temporarily
3. Manually restore from local backup in `/backups/` folder

### Q: Can I keep local backups as fallback?

**A:** Yes! The backup script keeps the last 5 local backups in `/backups/` folder. These persist even when volumes are deleted.

### Q: How do I switch back to normal mode?

**A:**
```bash
# Edit .env
nano .env

# Change to:
RESTORE_ON_BOOT=false

# Reload systemd (optional, takes effect on next boot)
sudo systemctl daemon-reload
```

## Recommendation

### For Most Users: Enable It! 🚀

**Why:**
- Peace of mind that backups work
- 1 hour max data loss is acceptable for surveys
- Stateless infrastructure is modern best practice
- Easy disaster recovery

**Perfect for:**
- Survey platforms with responses coming hourly/daily
- Personal/small business use
- Learning/testing environments
- Risk-averse users who want backup validation

### Consider Disabling If:

- You have continuous survey responses (multiple per minute)
- Internet connection is unreliable
- Backups are very large (multi-GB)
- Boot time is critical
- You prefer manual restore control

## Next Steps

1. **Enable the feature:**
   ```bash
   # Set RESTORE_ON_BOOT=true in .env
   nano .env
   ```

2. **Test it:**
   ```bash
   sudo reboot
   # Watch it restore from backup!
   ```

3. **Monitor first few boots:**
   ```bash
   sudo journalctl -u limesurvey.service -f
   ```

4. **Celebrate!** 🎉
   - Your Pi is now stateless
   - Backups are validated on every boot
   - Disaster recovery is automatic
   - Google Drive is your source of truth

---

**Remember:** With great automation comes great responsibility. Understand the 1-hour data loss window and plan accordingly!
