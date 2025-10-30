# Backup Performance Analysis & Frequency Guide

## Backup Time Estimates

### Small Database (10-50 MB uncompressed)
**Typical for:** New installation, 1-5 surveys, <1000 responses

```
Process breakdown:
├─ mysqldump:           2-5 seconds
├─ gzip compression:    1-2 seconds (reduces to ~5-10 MB)
├─ encryption (if on):  2-3 seconds
└─ Google Drive upload: 30-60 seconds (at 1 Mbps upload)
───────────────────────────────────────
Total: ~35-70 seconds (1 minute)
```

### Medium Database (100-200 MB uncompressed)
**Typical for:** Active use, 10-20 surveys, 5,000-10,000 responses

```
Process breakdown:
├─ mysqldump:           10-20 seconds
├─ gzip compression:    5-8 seconds (reduces to ~20-40 MB)
├─ encryption (if on):  5-8 seconds
└─ Google Drive upload: 2-5 minutes (at 1 Mbps upload)
───────────────────────────────────────
Total: ~3-6 minutes
```

### Large Database (500 MB - 1 GB uncompressed)
**Typical for:** Heavy use, 50+ surveys, 50,000+ responses

```
Process breakdown:
├─ mysqldump:           30-60 seconds
├─ gzip compression:    15-30 seconds (reduces to ~100-200 MB)
├─ encryption (if on):  15-30 seconds
└─ Google Drive upload: 10-20 minutes (at 1 Mbps upload)
───────────────────────────────────────
Total: ~12-22 minutes
```

### Very Large Database (2+ GB uncompressed)
**Typical for:** Enterprise use, 100+ surveys, 200,000+ responses

```
Process breakdown:
├─ mysqldump:           2-5 minutes
├─ gzip compression:    1-2 minutes (reduces to ~400-800 MB)
├─ encryption (if on):  1-2 minutes
└─ Google Drive upload: 30-60 minutes (at 1 Mbps upload)
───────────────────────────────────────
Total: ~35-70 minutes
```

## Resource Usage During Backup

### CPU Usage
```
Idle state:        5-10% (normal operations)
During backup:     25-40% spike
  ├─ mysqldump:    10-15% (database read)
  ├─ gzip:         15-20% (compression)
  └─ encryption:   10-15% (if enabled)

Duration: For duration of backup (see above)
Impact: Minimal impact on LimeSurvey performance
```

### RAM Usage
```
Backup container baseline:  ~100 MB
During backup:              +50-150 MB (temporary buffers)
Peak usage:                 ~150-250 MB total

After backup completes:     Returns to ~100 MB baseline
```

### Disk I/O
```
Database read:    Sustained read during mysqldump
Local write:      Writing compressed backup to /backups/
Cleanup:          Deletes old local backups (keeps last 5)

Impact: Low - MariaDB uses InnoDB with --single-transaction (no locks)
        LimeSurvey users won't notice any slowdown
```

### Network Usage
```
Upload bandwidth:  Saturates during Google Drive upload
Typical Pi upload: 1-5 Mbps (depends on ISP)

Impact: May slow down internet for other devices
        Only during upload portion of backup

Example: 50 MB backup at 2 Mbps = ~3 minutes of upload
```

## Backup Frequency Options

### Current: Every Hour (`0 * * * *`)

**Pros:**
- ✅ Maximum data protection (max 1 hour data loss)
- ✅ Frequent validation if RESTORE_ON_BOOT=true
- ✅ Fine for small/medium databases

**Cons:**
- ❌ 24 backups/day may be excessive
- ❌ Wasted bandwidth for databases that rarely change
- ❌ More Google Drive API calls

**Best for:**
- Active survey collection (multiple responses per hour)
- High-value data where 1-hour loss is unacceptable
- Small databases (backups complete in 1-2 minutes)

**Data at risk with RESTORE_ON_BOOT:** Max 1 hour

---

### Every 2 Hours (`0 */2 * * *`)

**Pros:**
- ✅ Good balance of protection and resource usage
- ✅ 12 backups/day instead of 24
- ✅ Less network congestion
- ✅ Suitable for most use cases

**Cons:**
- ⚠️ Max 2 hours data loss

**Best for:**
- Moderate survey activity (responses throughout day)
- Medium-sized databases
- Most production deployments

**Data at risk with RESTORE_ON_BOOT:** Max 2 hours

---

### Every 3 Hours (`0 */3 * * *`)

**Backups at:** 12 AM, 3 AM, 6 AM, 9 AM, 12 PM, 3 PM, 6 PM, 9 PM

**Pros:**
- ✅ 8 backups/day - good coverage
- ✅ Minimal resource impact
- ✅ Backup times align with typical work hours

**Cons:**
- ⚠️ Max 3 hours data loss

**Best for:**
- Surveys with responses during business hours
- Larger databases (3-5 minute backups)
- Limited upload bandwidth

**Data at risk with RESTORE_ON_BOOT:** Max 3 hours

---

### Every 4 Hours (`0 */4 * * *`)

**Backups at:** 12 AM, 4 AM, 8 AM, 12 PM, 4 PM, 8 PM

**Pros:**
- ✅ 6 backups/day
- ✅ Very low resource usage
- ✅ Good for large databases

**Cons:**
- ⚠️ Max 4 hours data loss
- ⚠️ Might miss peak activity windows

**Best for:**
- Low-frequency survey responses
- Large databases (10-20 minute backups)
- Limited internet connection

**Data at risk with RESTORE_ON_BOOT:** Max 4 hours

---

### Every 6 Hours (`0 */6 * * *`)

**Backups at:** 12 AM, 6 AM, 12 PM, 6 PM

**Pros:**
- ✅ 4 backups/day
- ✅ Minimal impact on system
- ✅ Suitable for very large databases

**Cons:**
- ⚠️ Max 6 hours data loss
- ⚠️ Less protection for active surveys

**Best for:**
- Infrequent survey responses (daily/weekly)
- Very large databases (20+ minute backups)
- Slow internet connection
- Archival/reference surveys

**Data at risk with RESTORE_ON_BOOT:** Max 6 hours

---

### Daily at 3 AM (`0 3 * * *`)

**Backups at:** 3:00 AM only

**Pros:**
- ✅ 1 backup/day
- ✅ Zero impact on business hours
- ✅ Minimal resource usage

**Cons:**
- ❌ Max 24 hours data loss
- ❌ Poor fit for RESTORE_ON_BOOT mode
- ❌ Risky for active surveys

**Best for:**
- Static/archival installations
- Testing environments
- Very slow internet connections
- **NOT recommended with RESTORE_ON_BOOT=true**

**Data at risk with RESTORE_ON_BOOT:** Max 24 hours ⚠️

## How to Change Backup Frequency

### Option 1: Edit docker-compose.yml (Recommended)

```bash
cd ~/limesurvey-lykebo
nano docker-compose.yml
```

Find the `db_backup` service and change `BACKUP_SCHEDULE`:

```yaml
db_backup:
  environment:
    BACKUP_SCHEDULE: "0 */2 * * *"  # Change this line
    # Examples:
    # Every hour:    "0 * * * *"
    # Every 2 hours: "0 */2 * * *"
    # Every 3 hours: "0 */3 * * *"
    # Every 6 hours: "0 */6 * * *"
    # Daily 3 AM:    "0 3 * * *"
```

Restart backup service:
```bash
docker compose up -d db_backup
```

### Option 2: Environment Variable (Alternative)

Add to `.env` file:
```bash
BACKUP_SCHEDULE="0 */2 * * *"
```

Update docker-compose.yml to use it:
```yaml
BACKUP_SCHEDULE: ${BACKUP_SCHEDULE:-0 * * * *}
```

## Recommendations by Use Case

### 🏃 High Activity Surveys
**Scenario:** Continuous survey responses, customer feedback, live events

**Recommendation:** Every 1-2 hours
```yaml
BACKUP_SCHEDULE: "0 */2 * * *"
```

**Reasoning:**
- Responses coming in frequently
- 1-2 hour data loss is acceptable
- Database likely small-medium size
- Backups complete quickly

---

### 📊 Moderate Activity Surveys
**Scenario:** Regular surveys, periodic responses, business use

**Recommendation:** Every 3 hours
```yaml
BACKUP_SCHEDULE: "0 */3 * * *"
```

**Reasoning:**
- Balanced protection vs. resource usage
- 8 backups/day covers business hours
- 3-hour data loss acceptable for most cases
- Good for medium-sized databases

---

### 📝 Low Activity Surveys
**Scenario:** Occasional responses, research surveys, archival

**Recommendation:** Every 6 hours
```yaml
BACKUP_SCHEDULE: "0 */6 * * *"
```

**Reasoning:**
- 4 backups/day is sufficient
- Database changes infrequently
- Minimal resource impact
- 6-hour data loss acceptable

---

### 🔬 Development/Testing
**Scenario:** Testing environment, not production

**Recommendation:** Every 6 hours or daily
```yaml
BACKUP_SCHEDULE: "0 */6 * * *"
# or
BACKUP_SCHEDULE: "0 3 * * *"
```

**Reasoning:**
- Test data is recreatable
- Minimal resource usage
- Can always trigger manual backups

---

### 🏢 Large Enterprise Deployment
**Scenario:** 50+ surveys, 50,000+ responses, large database

**Recommendation:** Every 4-6 hours
```yaml
BACKUP_SCHEDULE: "0 */4 * * *"
```

**Reasoning:**
- Backups take 10-20+ minutes
- Hourly would be too frequent
- 4-6 hour window acceptable with retention policy
- Reduces upload bandwidth usage

## Special Considerations

### With RESTORE_ON_BOOT=true

**Important:** Backup frequency = Maximum data loss on reboot

```
Scenario: Pi reboots unexpectedly

Hourly backups:     Max 1 hour of data lost
Every 2 hours:      Max 2 hours of data lost
Every 3 hours:      Max 3 hours of data lost
Every 6 hours:      Max 6 hours of data lost
Daily backups:      Max 24 hours of data lost ⚠️
```

**Recommendation:** Don't go below every 3 hours if using RESTORE_ON_BOOT=true

### Internet Bandwidth Limitations

If you have slow upload speeds (< 1 Mbps):

```bash
# Test your upload speed
curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
```

**Adjustments:**
- < 0.5 Mbps: Every 6 hours or daily
- 0.5-1 Mbps: Every 3-4 hours
- 1-5 Mbps: Every 2-3 hours
- 5+ Mbps: Hourly is fine

### Google Drive API Quotas

Google Drive API free tier limits:
- **1,000 requests per 100 seconds**
- **10,000 requests per day**

Each backup = ~3-5 API calls (list files, upload, delete old)

**Quota usage:**
- Hourly (24/day): ~100 API calls/day ✅ Fine
- Every 2 hours (12/day): ~50 API calls/day ✅ Fine
- No risk of hitting limits with any frequency

### Disk Space on Pi

Local backups (kept: last 5):

```
Small DB (10 MB):   5 × 10 MB = 50 MB
Medium DB (50 MB):  5 × 50 MB = 250 MB
Large DB (200 MB):  5 × 200 MB = 1 GB
```

**Recommendation:** Ensure you have 2-5 GB free on SD card for backups

## Testing Backup Performance

### Test Backup Time

```bash
# Trigger manual backup and time it
time docker compose exec db_backup python /app/backup.py
```

**Example output:**
```
real    0m45.234s   ← Total time
user    0m0.123s
sys     0m0.045s
```

### Check Database Size

```bash
# Check uncompressed size
docker compose exec database mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "
SELECT
  table_schema AS 'Database',
  ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
WHERE table_schema = 'limesurvey'
GROUP BY table_schema;"
```

### Check Backup File Size

```bash
# List recent backups with sizes
docker compose exec db_backup ls -lh /backups | tail -n 10
```

### Monitor Resource Usage During Backup

**Terminal 1:**
```bash
# Watch CPU/RAM
watch -n 1 'docker stats --no-stream'
```

**Terminal 2:**
```bash
# Trigger backup
docker compose exec db_backup python /app/backup.py
```

## Recommended Configuration

### For Most Users (Moderate Activity)

**Every 2-3 hours is the sweet spot:**

```yaml
# docker-compose.yml
db_backup:
  environment:
    BACKUP_SCHEDULE: "0 */2 * * *"  # Every 2 hours
```

**Reasoning:**
- 12 backups/day - good coverage
- Max 2 hours data loss on reboot (acceptable)
- Backups at: 12a, 2a, 4a, 6a, 8a, 10a, 12p, 2p, 4p, 6p, 8p, 10p
- Covers all business hours
- Low resource impact
- Quick backups even for medium DBs

**With backup rotation policy:**
- Hourly tier: Last 12 backups (24 hours coverage with 2-hour backups)
- Daily tier: Last 7 days
- Weekly tier: Last 4 weeks
- Monthly tier: Last 12 months
- Yearly tier: Forever

### Performance Summary

```
Expected performance for 2-hour frequency:

Database Size     Backup Time    Data at Risk    Backups/Day
─────────────────────────────────────────────────────────────
10-50 MB          1-2 min        Max 2 hours     12
100-200 MB        3-6 min        Max 2 hours     12
500 MB-1 GB       12-22 min      Max 2 hours     12
2+ GB             35-70 min      Max 2 hours     12

CPU Impact:       Low (25-40% spike during backup only)
RAM Impact:       Low (~150-250 MB during backup)
Network Impact:   Moderate (upload saturated for 1-10 min)
Disk Impact:      Low (no table locks, single-transaction)
```

## FAQ

### Q: Will backups slow down LimeSurvey?

**A:** Minimal impact. mysqldump uses `--single-transaction` which doesn't lock tables. Users may see a slight slowdown during backup, but it's barely noticeable.

### Q: What if backup runs during high traffic?

**A:** Backups will still complete, but may take slightly longer. Consider scheduling backups during low-traffic hours:
```yaml
# Every 4 hours starting at midnight (12a, 4a, 8a, 12p, 4p, 8p)
BACKUP_SCHEDULE: "0 */4 * * *"

# Or specific times (3am, 9am, 3pm, 9pm)
BACKUP_SCHEDULE: "0 3,9,15,21 * * *"
```

### Q: Can I reduce retention and increase frequency?

**A:** Yes! You can keep fewer backups but run more frequently:

```env
# Run every hour but keep less in each tier
BACKUP_SCHEDULE="0 * * * *"
BACKUP_KEEP_HOURLY_HOURS=12      # Instead of 24
BACKUP_KEEP_DAILY_DAYS=3         # Instead of 7
BACKUP_KEEP_WEEKLY_WEEKS=2       # Instead of 4
BACKUP_KEEP_MONTHLY_MONTHS=6     # Instead of 12
```

### Q: What if backup is still running when next one starts?

**A:** Cron will skip overlapping runs. If a backup takes 20 minutes and runs hourly, the next run won't start until the first completes.

### Q: Should I backup during Watchtower updates?

**A:** Watchtower runs at 3:15 AM. If using hourly backups, a backup runs at 3:00 AM (safe, 15 minutes before). Consider the schedule:
- Backup: 3:00 AM
- Watchtower: 3:15 AM (waits for backup to finish)

## Implementation Steps

### Step 1: Test Current Performance

```bash
# Time a manual backup
time docker compose exec db_backup python /app/backup.py

# Check database size
docker compose exec database mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "
  SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
  FROM information_schema.tables WHERE table_schema = 'limesurvey';"
```

### Step 2: Choose Frequency Based on Results

```
If backup takes:
  < 2 minutes:   Hourly is fine
  2-5 minutes:   Every 2 hours recommended
  5-10 minutes:  Every 3 hours recommended
  10-20 minutes: Every 4 hours recommended
  > 20 minutes:  Every 6 hours recommended
```

### Step 3: Update Configuration

```bash
nano docker-compose.yml
# Change BACKUP_SCHEDULE

# Restart backup service
docker compose up -d db_backup

# Verify new schedule
docker compose exec db_backup cat /etc/crontabs/root
```

### Step 4: Monitor First Few Backups

```bash
# Watch logs
docker compose logs -f db_backup

# Should see backups at new intervals
```

---

**Conclusion:** For most users, **every 2-3 hours** is the optimal balance between data protection, resource usage, and performance. Start there and adjust based on your actual backup times and data change frequency.
