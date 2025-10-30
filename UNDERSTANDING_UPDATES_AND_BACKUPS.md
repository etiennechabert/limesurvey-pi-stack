# Quick Guide: Updates vs Backups vs Restores

## The Most Important Thing to Understand

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Container Update  ≠  Data Restore                          │
│                                                             │
│  Your data lives in VOLUMES, not CONTAINERS                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Visual Explanation

### What Happens During Watchtower Update

```
BEFORE UPDATE:
┌─────────────────┐         ┌──────────────────┐
│ MariaDB v11.0   │         │   db_data        │
│ (container)     │─────────│   (volume)       │
│                 │ uses    │                  │
│                 │         │ • All surveys    │
│                 │         │ • All responses  │
│                 │         │ • All users      │
└─────────────────┘         └──────────────────┘

         ↓ Watchtower updates container

AFTER UPDATE:
┌─────────────────┐         ┌──────────────────┐
│ MariaDB v11.1   │         │   db_data        │
│ (NEW container) │─────────│   (SAME volume)  │
│                 │ uses    │                  │
│                 │         │ • All surveys    │← UNCHANGED!
│                 │         │ • All responses  │← UNCHANGED!
│                 │         │ • All users      │← UNCHANGED!
└─────────────────┘         └──────────────────┘

Result: Program updated, data preserved!
```

### When Restore Actually Happens

```
SCENARIO 1: Volume Deleted
┌─────────────────┐         ┌──────────────────┐
│ MariaDB         │         │   db_data        │
│ (container)     │    X    │   (DELETED!)     │
│                 │         │                  │
└─────────────────┘         └──────────────────┘

         ↓ Restart container

┌─────────────────┐         ┌──────────────────┐
│ MariaDB         │         │   db_data        │
│ (container)     │ finds   │   (EMPTY!)       │
│                 │ empty   │                  │
│ Triggers        │ volume  └──────────────────┘
│ restore         │                ↓
│ script          │         Downloads from
│                 │         Google Drive
│                 │                ↓
│                 │         ┌──────────────────┐
│                 │─────────│   db_data        │
│                 │         │ (RESTORED!)      │
└─────────────────┘         └──────────────────┘
```

## Real-World Examples

### Example 1: Watchtower Updates Database

**User Question:** "If Watchtower restarts my database, will it restore from Google Drive?"

**Answer:** NO

**What Actually Happens:**
```
3:15 AM - Watchtower runs
        ↓
Pulls MariaDB v11.4 (new version)
        ↓
Stops old container (v11.3)
        ↓
Starts new container (v11.4)
        ↓
New container connects to existing db_data volume
        ↓
Database picks up exactly where it left off
        ↓
✅ All your surveys, responses still there!
❌ NO restore from Google Drive
```

**Downtime:** ~30 seconds
**Data Lost:** NONE
**Backup Used:** None

### Example 2: First Installation

**Scenario:** Setting up on a new Raspberry Pi

**What Happens:**
```
docker compose up -d
        ↓
Creates new, empty db_data volume
        ↓
MariaDB starts
        ↓
Restore script runs (volume is empty)
        ↓
Finds latest backup in Google Drive
        ↓
Downloads and restores it
        ↓
Creates marker file (.restore_completed)
        ↓
✅ Database populated with your data!
```

**Data Lost:** Changes since last backup (max 1 hour)

### Example 3: SD Card Dies

**Scenario:** Pi won't boot, SD card corrupted

**Recovery Steps:**
```
1. New SD card + fresh Pi OS
2. Install Docker
3. Copy limesurvey-lykebo folder
4. docker compose up -d
        ↓
System detects empty volumes
        ↓
Automatically restores from Google Drive
        ↓
✅ Back online with your data!
```

**Data Lost:** Changes since last backup (max 1 hour)

## Backup Schedule & Update Schedule

### Timeline

```
2:00 AM ─── Hourly Backup runs ✓
3:00 AM ─── Hourly Backup runs ✓
3:15 AM ─── Watchtower checks for updates
            │
            ├─ No updates? → Does nothing
            │
            └─ Updates available?
                ↓
                Updates containers one-by-one
                (Database still running during others)
                ↓
                Database gets updated (~30 sec downtime)
                ↓
                Restarts with SAME volume
                ↓
                ✓ Update complete, data intact

4:00 AM ─── Hourly Backup runs ✓
```

### Why 3:15 AM for Watchtower?

To avoid conflicts with the 3:00 AM backup:

```
❌ BAD (old config):
3:00:00 AM - Backup starts
3:00:00 AM - Watchtower starts
          ↓
   BOTH TRY TO ACCESS DATABASE
          ↓
   Potential backup failure

✅ GOOD (new config):
3:00 AM - Backup runs
       ↓
  ~2 minutes to complete
       ↓
3:15 AM - Watchtower runs (backup is done)
       ↓
  No conflicts!
```

## Common Misconceptions

### ❌ MYTH: "Container restart = data loss"
**✅ REALITY:** Data persists in volumes, safe across restarts

### ❌ MYTH: "Updates restore from backup"
**✅ REALITY:** Updates only replace the program, not data

### ❌ MYTH: "I need to backup before every restart"
**✅ REALITY:** Hourly auto-backups cover you, manual backup not needed

### ❌ MYTH: "Watchtower will corrupt my database"
**✅ REALITY:** Watchtower only updates containers, volumes untouched

### ❌ MYTH: "Reboot = restore from cloud"
**✅ REALITY:** System uses existing volumes, no restore unless deleted

## When Should I Worry About Data Loss?

### 🔴 High Risk Scenarios

1. **Manual volume deletion**
   ```bash
   docker volume rm limesurvey-lykebo_db_data  # ⚠️ DATA DELETED!
   ```

2. **SD card failure**
   - Hardware failure
   - Corruption
   - Physical damage

3. **Manual file deletion**
   ```bash
   sudo rm -rf /var/lib/docker/volumes/  # ⚠️ ALL DATA DELETED!
   ```

### 🟡 Medium Risk Scenarios

1. **Backup fails for extended period**
   - Last backup is days old
   - SD card failure would lose recent data

2. **Google Drive storage full**
   - New backups can't upload
   - Only local backups available

### 🟢 Low Risk Scenarios (No Worries)

1. **Container restarts** ✅ Data safe
2. **Container updates** ✅ Data safe
3. **System reboots** ✅ Data safe
4. **Docker daemon restarts** ✅ Data safe
5. **Watchtower updates** ✅ Data safe

## Quick Reference Table

| Action | Data Persists? | Restore Triggered? | Backup Needed? |
|--------|----------------|-------------------|----------------|
| Container restart | ✅ YES | ❌ NO | ❌ NO |
| Watchtower update | ✅ YES | ❌ NO | ❌ NO |
| System reboot | ✅ YES | ❌ NO | ❌ NO |
| `docker compose restart` | ✅ YES | ❌ NO | ❌ NO |
| `docker compose up -d --force-recreate` | ✅ YES | ❌ NO | ❌ NO |
| Volume deletion | ❌ NO | ✅ YES (auto) | ✅ YES |
| SD card failure | ❌ NO | ✅ YES (auto) | ✅ YES |
| Fresh install | ❌ NO | ✅ YES (auto) | ✅ YES |

## Your Safety Net

### Multiple Layers of Protection

```
Layer 1: Docker Volumes (persistent storage)
         └─ Survives: restarts, updates, reboots

Layer 2: Local Backups (last 5 on disk)
         └─ Survives: accidental volume deletion

Layer 3: Google Drive Backups (unlimited, hourly)
         └─ Survives: SD card failure, Pi destruction

Layer 4: Automatic Restore (on empty volume)
         └─ Recovers: fresh installs, volume deletion

Layer 5: Health Checks + Watchdog
         └─ Prevents: prolonged service failures
```

## Testing Your Understanding

### Quiz

**Q1:** Watchtower updates MariaDB. Do you lose data?
**A:** NO - Data in volumes persists

**Q2:** You run `docker compose restart database`. Does it restore from Google Drive?
**A:** NO - Uses existing volume

**Q3:** SD card dies, you get a new one. Does data restore automatically?
**A:** YES - Empty volumes trigger restore

**Q4:** Watchtower runs at 3:00 AM during backup. What happens?
**A:** TRICK QUESTION - Watchtower runs at 3:15 AM to avoid this!

## Summary

### The Golden Rule

```
┌────────────────────────────────────────────────┐
│                                                │
│  Your data lives in volumes, not containers    │
│                                                │
│  Containers can be destroyed and recreated     │
│  Volumes persist until YOU explicitly delete   │
│                                                │
│  Updates = New container + Old volume          │
│  Restore = New volume + Google Drive backup    │
│                                                │
└────────────────────────────────────────────────┘
```

### What You Should Do

✅ **Trust the system** - It's designed to preserve your data
✅ **Test backups monthly** - Verify they work
✅ **Monitor backup logs** - Ensure hourly backups succeed
✅ **Understand volumes** - They're your data's home
✅ **Read [BACKUP_AND_PERSISTENCE.md](BACKUP_AND_PERSISTENCE.md)** - Deep dive

### What You Shouldn't Worry About

❌ Container restarts - Data safe
❌ Container updates - Data safe
❌ System reboots - Data safe
❌ Watchtower updates - Data safe
❌ Docker daemon restarts - Data safe

---

**Still confused? Check these docs:**
- [BACKUP_AND_PERSISTENCE.md](BACKUP_AND_PERSISTENCE.md) - Full technical details
- [UPDATE_STRATEGY.md](UPDATE_STRATEGY.md) - Update mechanisms explained
- [README.md](README.md) - Main documentation

**Questions?** Create an issue on GitHub!
