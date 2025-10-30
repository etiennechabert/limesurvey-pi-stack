# Your Question: What Happens When Watchtower Restarts the Database?

## Your Specific Question

> "Say WATCHTOWER would restart my database? Would it take into account my backup upload to the cloud? The database restarting would also restart from the last cloud backup right?"

## Short Answer

**NO, the database will NOT restore from cloud backup when Watchtower updates it.**

Your data persists in Docker volumes and is NOT lost during updates.

## Detailed Explanation

### What You Thought Would Happen ❌

```
Watchtower updates database
         ↓
Database restarts
         ↓
System downloads latest backup from Google Drive
         ↓
Database restores from that backup
```

**This is INCORRECT**

### What Actually Happens ✅

```
Watchtower updates database
         ↓
Old container stops
         ↓
New container starts
         ↓
New container connects to EXISTING volume (db_data)
         ↓
Database continues with all your existing data
         ↓
NO restore happens
         ↓
All your surveys, responses, and data are exactly as they were
```

## Why This Is Good News!

### Benefits of Volume Persistence

1. **Updates are FAST** - No time wasted downloading/restoring backups
2. **No data loss** - Everything stays intact
3. **No downtime** - Only ~30 seconds for container restart
4. **No restore lag** - Immediate availability after update

### If It Worked Your Way (restore on every update)

**Problems that would occur:**

```
❌ 3:15 AM - Watchtower runs
❌ Downloads 500MB backup from Google Drive (slow!)
❌ Restores database (takes 5-10 minutes)
❌ Loses all changes since last backup (up to 1 hour of data!)
❌ Users lose survey responses submitted after 3:00 AM
❌ Massive unnecessary cloud bandwidth usage
```

**This would be BAD!**

## The Role of Volumes

### Think of It Like This

```
Container = The MariaDB program (the app)
Volume = The database files (your data)

┌─────────────────┐         ┌──────────────────┐
│   Container     │         │     Volume       │
│                 │         │                  │
│  Like your      │         │  Like your       │
│  phone's        │ uses    │  phone's         │
│  WhatsApp app   │────────>│  chat history    │
│                 │         │                  │
│  Can be         │         │  Stays on        │
│  updated        │         │  your phone      │
│  without        │         │  after update    │
│  losing chats   │         │                  │
└─────────────────┘         └──────────────────┘

Update WhatsApp = Container update
Your chats stay = Volume persists
```

## When DOES Restore Happen?

### Only These Scenarios

#### Scenario 1: First Installation
```bash
# Brand new setup
cd ~/limesurvey-lykebo
docker compose up -d

# Volume is empty (first time)
# ✅ Restore runs automatically
```

#### Scenario 2: Volume Deleted
```bash
# You manually delete the volume
docker volume rm limesurvey-lykebo_db_data

# Restart containers
docker compose up -d

# Volume is empty (because you deleted it)
# ✅ Restore runs automatically
```

#### Scenario 3: New SD Card / Pi Replacement
```bash
# Old Pi died, new Pi with new SD card
# Install Docker, copy files
docker compose up -d

# Volume is empty (new system)
# ✅ Restore runs automatically
```

### When Restore Does NOT Happen

- ❌ Container restart
- ❌ Container update (Watchtower)
- ❌ System reboot
- ❌ Docker daemon restart
- ❌ Manual `docker compose restart`
- ❌ Health check triggers restart

## About Backup Timing

### Your Concern About Backup Conflicts

You asked: *"Would it take into account my backup upload to the cloud?"*

**Answer:** Yes! We've configured it to avoid conflicts:

```
OLD (problematic):
3:00 AM - Backup starts
3:00 AM - Watchtower starts
         ↓
   BOTH ACCESS DATABASE SIMULTANEOUSLY
         ↓
   Potential backup failure

NEW (fixed):
3:00 AM - Backup starts and completes (~2 min)
3:15 AM - Watchtower starts
         ↓
   NO CONFLICT!
   Backup is done before Watchtower runs
```

### What If They Do Conflict Somehow?

**Worst case scenario:**
1. Backup at 3:00 AM fails
2. But backup at 2:00 AM succeeded
3. And backup at 4:00 AM will succeed
4. You still have protection!

**Safety net:**
- 5 local backups on disk
- Unlimited backups in Google Drive
- Missing one hourly backup = no big deal

## Data Flow Diagram

### Normal Operation (No Updates)

```
Your LimeSurvey
       ↓
User submits survey
       ↓
Data written to db_data volume
       ↓
Every hour: Backup to Google Drive
       ↓
Data is in 2 places:
1. db_data volume (primary)
2. Google Drive (backup)
```

### During Watchtower Update

```
Your LimeSurvey
       ↓
Watchtower detects new MariaDB version
       ↓
Stops old MariaDB container
       ↓
Starts new MariaDB container
       ↓
New container mounts db_data volume
       ↓
Database reads existing data from volume
       ↓
Everything continues as normal
       ↓
❌ NO download from Google Drive
❌ NO restore process
✅ All data intact
```

### During Restore (First Install Only)

```
Fresh Raspberry Pi
       ↓
docker compose up -d
       ↓
MariaDB starts, finds empty db_data volume
       ↓
Restore script runs
       ↓
Downloads latest backup from Google Drive
       ↓
Unzips and imports to database
       ↓
Creates marker file: .restore_completed
       ↓
✅ Database now has your data
       ↓
Future restarts will NOT restore again (marker exists)
```

## Real World Timeline

### Typical Day in the Life

```
12:00 AM - Backup runs ✓
1:00 AM - Backup runs ✓
2:00 AM - Backup runs ✓
3:00 AM - Backup runs ✓
3:15 AM - Watchtower checks for updates
        - Finds new MariaDB image
        - Updates database container
        - 30 seconds downtime
        - NO restore, uses existing volume ✓
4:00 AM - Backup runs ✓
...
11:00 PM - Backup runs ✓

Your data: Continuous, uninterrupted, safe ✓
```

## How to Verify This

### Test 1: Check Volume Persistence

```bash
# 1. Check current data
docker compose exec database mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SELECT COUNT(*) FROM limesurvey.surveys;"
# Say it shows: 10 surveys

# 2. Force update a container
docker compose up -d --force-recreate database

# 3. Check data again
docker compose exec database mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SELECT COUNT(*) FROM limesurvey.surveys;"
# Still shows: 10 surveys ✓

# Conclusion: Data persisted through container recreation
```

### Test 2: Check Restore Marker

```bash
# Check if restore marker exists
docker compose exec database ls -la /var/lib/mysql/.restore_completed

# If it exists:
# - Restore has already run (first install)
# - Will NOT run again even if you restart

# If it doesn't exist:
# - Fresh install
# - Will run on next startup
```

### Test 3: Monitor Backup Schedule

```bash
# Check backup logs
docker compose logs db_backup | grep "Backup completed"

# You should see entries every hour:
# [2025-01-30 01:00:15] Backup completed successfully!
# [2025-01-30 02:00:15] Backup completed successfully!
# [2025-01-30 03:00:15] Backup completed successfully!
# [2025-01-30 04:00:15] Backup completed successfully!
```

## Summary - Your Questions Answered

| Your Question | Answer |
|---------------|--------|
| "Would Watchtower restart my database?" | Yes, during updates (~30 sec) |
| "Would it take into account backup upload?" | Yes, scheduled at 3:15 AM (after 3:00 AM backup) |
| "Would it restart from last cloud backup?" | **NO** - Uses existing volume, NO restore |

## Key Takeaways

✅ **Updates preserve data** - No restore happens
✅ **Volumes are persistent** - Data survives container changes
✅ **Backups run hourly** - Your safety net
✅ **Restore only on first install** - Or after manual volume deletion
✅ **Timing is safe** - Backup at 3:00, Watchtower at 3:15

## Still Confused?

### Read These (In Order)

1. **[UNDERSTANDING_UPDATES_AND_BACKUPS.md](UNDERSTANDING_UPDATES_AND_BACKUPS.md)** - Visual explanations
2. **[BACKUP_AND_PERSISTENCE.md](BACKUP_AND_PERSISTENCE.md)** - Deep technical details
3. **[UPDATE_STRATEGY.md](UPDATE_STRATEGY.md)** - Update mechanisms

### Quick Mental Model

Think of it like your computer:

```
Software Update:
- Updates Windows/MacOS (the program)
- Your files stay on the hard drive
- No restore from backup needed

Database Update:
- Updates MariaDB container (the program)
- Your data stays in the volume (the hard drive)
- No restore from backup needed

Same concept!
```

---

**Hope this clears it up! Your data is safe during updates.** 🎉
