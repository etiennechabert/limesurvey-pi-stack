# Backup Rotation Policy

## Overview

The LimeSurvey backup system now includes an intelligent **backup rotation policy** that automatically manages your Google Drive backups. This prevents unlimited backup accumulation while ensuring you always have the right balance of recent and historical backups.

## Rotation Strategy: Grandfather-Father-Son

The system uses a classic "grandfather-father-son" backup rotation:

```
┌─────────────────────────────────────────────────────────┐
│                    Backup Timeline                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌────────────┐  ┌────────┐  ┌────────┐  ┌────────┐  │
│  │  Hourly    │  │ Daily  │  │ Weekly │  │ Monthly│  │
│  │  (24h)     │  │ (7d)   │  │  (4w)  │  │ (12m)  │  │
│  └────────────┘  └────────┘  └────────┘  └────────┘  │
│                                                         │
│  <── Recent ──────────────────────── Historical ──>    │
│  <── Frequent ─────────────────────── Sparse ───────>  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Default Retention Policy

| Tier | Frequency | Duration | Total Backups | Example |
|------|-----------|----------|---------------|---------|
| **Hourly** | Every hour | 24 hours | ~24 backups | Last day |
| **Daily** | Once per day | 7 days | ~7 backups | Last week |
| **Weekly** | Once per week | 4 weeks | ~4 backups | Last month |
| **Monthly** | Once per month | 12 months | ~12 backups | Last year |
| **Yearly** | Once per year | Forever | Unlimited | Archives |

**Total backups kept: ~47 + yearly archives**

## How It Works

### Timeline Example

Imagine it's **January 30, 2025, 15:00**:

```
HOURLY (Last 24 hours):
✓ Jan 30 15:00  ← Just created
✓ Jan 30 14:00
✓ Jan 30 13:00
... (all hourly backups back to Jan 29 15:00)

DAILY (Last 7 days):
✓ Jan 29 - keeps latest from that day (23:00)
✓ Jan 28 - keeps latest from that day
✓ Jan 27
✓ Jan 26
✓ Jan 25
✓ Jan 24
✓ Jan 23

WEEKLY (Last 4 weeks):
✓ Week of Jan 20  - keeps latest from that week
✓ Week of Jan 13
✓ Week of Jan 6
✓ Week of Dec 30

MONTHLY (Last 12 months):
✓ December 2024 - keeps latest from that month
✓ November 2024
✓ October 2024
... (back to February 2024)

YEARLY (Forever):
✓ 2024 - keeps latest from that year
✓ 2023
✓ 2022
... (all previous years)
```

### What Gets Deleted

After each backup completes:
1. System lists all backups in Google Drive
2. Categorizes them into tiers based on age
3. Within each tier, keeps only the required backups
4. Deletes everything else

**Example:**
- You have 3 backups from January 25 (01:00, 12:00, 23:00)
- January 25 is in the "daily" tier (older than 24h, within 7 days)
- System keeps only the latest one (23:00)
- Deletes 01:00 and 12:00

## Configuration

### Environment Variables

Configure retention in `.env`:

```bash
# Keep all hourly backups for last N hours (default: 24)
BACKUP_KEEP_HOURLY_HOURS=24

# Keep one backup per day for last N days (default: 7)
BACKUP_KEEP_DAILY_DAYS=7

# Keep one backup per week for last N weeks (default: 4)
BACKUP_KEEP_WEEKLY_WEEKS=4

# Keep one backup per month for last N months (default: 12)
BACKUP_KEEP_MONTHLY_MONTHS=12

# Keep one backup per year forever (default: true)
BACKUP_KEEP_YEARLY=true
```

### Example Configurations

#### Conservative (Keep More)
```bash
BACKUP_KEEP_HOURLY_HOURS=48        # 2 days
BACKUP_KEEP_DAILY_DAYS=14          # 2 weeks
BACKUP_KEEP_WEEKLY_WEEKS=8         # 2 months
BACKUP_KEEP_MONTHLY_MONTHS=24      # 2 years
BACKUP_KEEP_YEARLY=true
```
**Total: ~78 + yearly**

#### Aggressive (Save Space)
```bash
BACKUP_KEEP_HOURLY_HOURS=12        # 12 hours
BACKUP_KEEP_DAILY_DAYS=3           # 3 days
BACKUP_KEEP_WEEKLY_WEEKS=2         # 2 weeks
BACKUP_KEEP_MONTHLY_MONTHS=6       # 6 months
BACKUP_KEEP_YEARLY=false           # No yearly archives
```
**Total: ~23 backups**

#### Production Recommended
```bash
BACKUP_KEEP_HOURLY_HOURS=24        # 1 day
BACKUP_KEEP_DAILY_DAYS=7           # 1 week
BACKUP_KEEP_WEEKLY_WEEKS=4         # 1 month
BACKUP_KEEP_MONTHLY_MONTHS=12      # 1 year
BACKUP_KEEP_YEARLY=true            # Forever
```
**Total: ~47 + yearly (default)**

## Benefits

### Space Efficiency

**Before rotation policy:**
```
1 year = 365 days × 24 hours = 8,760 backups
8,760 backups × 50MB avg = 438 GB
```

**After rotation policy:**
```
1 year = 24 + 7 + 4 + 12 + 1 = 48 backups
48 backups × 50MB avg = 2.4 GB
```

**Savings: 99.5% reduction in storage usage!**

### Recovery Options

Despite fewer backups, you still have excellent recovery options:

| Scenario | Recovery Point | Example |
|----------|---------------|---------|
| **Oops, just deleted something** | Last hour | Restore from 30 min ago |
| **Yesterday's data was wrong** | Last day | Restore from 23:00 yesterday |
| **Need last week's state** | Last 7 days | Restore from 7 days ago |
| **Need last month's data** | Last 4 weeks | Restore from 3 weeks ago |
| **Compliance requirement** | Last year | Restore from 10 months ago |
| **Historical archive** | Any previous year | Restore from 2022 |

## Monitoring

### Check Retention Status

View logs after each backup:

```bash
docker compose logs db_backup | grep -A 10 "Cleaning up"
```

**Sample output:**
```
[2025-01-30 15:00:45] Cleaning up old Google Drive backups...
[2025-01-30 15:00:47] Found 156 backup files in Google Drive
[2025-01-30 15:00:48] Keeping 24 hourly backups (last 24h)
[2025-01-30 15:00:48] Keeping 7 daily backups (last 7 days)
[2025-01-30 15:00:48] Keeping 4 weekly backups (last 4 weeks)
[2025-01-30 15:00:48] Keeping 12 monthly backups (last 12 months)
[2025-01-30 15:00:48] Keeping 2 yearly backups
[2025-01-30 15:00:49] Deleting 107 old backups from Google Drive...
[2025-01-30 15:00:52] Successfully deleted 107 old backups
[2025-01-30 15:00:52] Total backups kept in Google Drive: 49
```

### Verify Backup Counts

```bash
# Count backups in Google Drive (via web interface)
# Navigate to your backup folder
# Check file count matches expected retention
```

## Safety Features

### Gradual Transition

When you first enable rotation:
- Doesn't immediately delete all old backups
- Gradually trims to target count over multiple backup cycles
- Always keeps at least the minimum required backups

### Error Handling

- If cleanup fails, backup still succeeds
- Cleanup errors logged but don't stop backups
- Next backup attempt will retry cleanup

### No Local Impact

- Rotation only affects Google Drive backups
- Local backups remain at 5 most recent (unchanged)
- Two-tier protection: local + cloud

## Testing the Rotation

### Dry Run (Safe Test)

Check what would be deleted without actually deleting:

1. Temporarily disable deletion in `backup.py`:
   ```python
   # Comment out the deletion line:
   # service.files().delete(fileId=backup['id']).execute()
   ```

2. Run backup:
   ```bash
   docker compose exec db_backup python /app/backup.py
   ```

3. Review logs to see what would be deleted

### Verify After First Run

After enabling rotation:

```bash
# 1. Trigger manual backup
docker compose exec db_backup python /app/backup.py

# 2. Check logs
docker compose logs db_backup --tail=50

# 3. Check Google Drive
# Verify backup count matches expected retention

# 4. Check older backups are deleted
# Verify files older than retention policy are gone
```

## Migration from Unlimited Backups

If you already have many backups in Google Drive:

**Before:**
```
Google Drive: 500+ backups accumulated over time
```

**After first backup with rotation:**
```
Google Drive: ~47 backups (trimmed to policy)
Deleted: ~450+ old backups
```

**Space reclaimed immediately!**

### Migration Steps

1. **Backup your backup folder** (optional paranoia):
   - Make a copy of your Google Drive backup folder
   - Or download a few recent backups locally

2. **Enable rotation** (already done by default)

3. **Run manual backup** to trigger cleanup:
   ```bash
   docker compose exec db_backup python /app/backup.py
   ```

4. **Verify results** in logs and Google Drive

## FAQ

### Q: What happens to existing backups?

**A:** They'll be deleted according to the rotation policy on the next backup cycle.

### Q: Can I disable rotation?

**A:** Yes, set all retention values very high:
```bash
BACKUP_KEEP_HOURLY_HOURS=9999
BACKUP_KEEP_DAILY_DAYS=9999
BACKUP_KEEP_WEEKLY_WEEKS=9999
BACKUP_KEEP_MONTHLY_MONTHS=9999
```

### Q: What if I accidentally set retention too low?

**A:** You can't recover deleted backups. Start conservative and adjust downward.

### Q: How much Google Drive space will I use?

**A:**
- ~47 backups (default policy)
- ~50MB per backup (average)
- **Total: ~2.4 GB** (vs 438 GB without rotation)

### Q: Can I keep more weekly backups?

**A:** Yes! Just increase `BACKUP_KEEP_WEEKLY_WEEKS`:
```bash
BACKUP_KEEP_WEEKLY_WEEKS=12  # Keep 12 weeks (3 months)
```

### Q: Do I need to rebuild the container?

**A:** Yes, after changing .env:
```bash
docker compose build db_backup
docker compose up -d db_backup
```

### Q: What if cleanup fails?

**A:** Backup still succeeds. Cleanup will retry next hour. Check logs for errors.

### Q: Can I manually run cleanup?

**A:** Yes:
```bash
docker compose exec db_backup python /app/backup.py
# Cleanup runs at the end of each backup
```

## Best Practices

### ✅ DO

- **Start conservative** - Use default policy or higher
- **Monitor first cleanup** - Watch logs carefully
- **Test restore** - Verify backups work before deleting old ones
- **Adjust gradually** - Make small changes to retention
- **Keep yearly archives** - Good for compliance

### ❌ DON'T

- **Don't set retention too low** - You can't undo deletions
- **Don't disable all tiers** - Keep at least hourly backups
- **Don't forget to rebuild** - Changes need container rebuild
- **Don't panic on first cleanup** - It's supposed to delete old backups

## Advanced: Custom Retention Logic

If you need custom retention (e.g., keep every hour during business hours):

1. Modify `cleanup_google_drive_backups()` in `backup-service/backup.py`
2. Add custom logic for your use case
3. Rebuild container

## Summary

| Aspect | Before Rotation | After Rotation |
|--------|----------------|----------------|
| **Backups per year** | ~8,760 | ~47 + yearly |
| **Storage usage** | ~438 GB | ~2.4 GB |
| **Recovery points** | Overwhelming | Strategic |
| **Management** | Manual | Automatic |
| **Cost** | High | Minimal |

**Result: Same protection, 99.5% less storage!**

---

**Configuration file:** `.env`
**Implementation:** `backup-service/backup.py`
**Logs:** `docker compose logs db_backup`
