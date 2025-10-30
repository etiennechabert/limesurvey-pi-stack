# Encrypted Backups - Simple Setup Guide

## Why Encrypt Backups?

**Your concern:** Not leaking user login/passwords

**Good news:** Passwords are already hashed in the database (bcrypt)

**Remaining risk:** If someone gets your Google Drive backups, they can attempt to crack weak passwords

**Solution:** Encrypt backups with AES-256 before uploading to Google Drive

## How It Works

```
Normal Backup (Current):
Database → SQL dump → gzip → Google Drive
                               ↓
                        Plain text (hashes visible)

Encrypted Backup (New):
Database → SQL dump → gzip → AES-256 encrypt → Google Drive
                                                  ↓
                                          Encrypted (unreadable)
```

**Result:** Even if someone gets your Google Drive account, they cannot read backups without your encryption key!

## Setup (5 Minutes)

### Step 1: Generate Encryption Key

On your computer (NOT on Pi yet):

```bash
# Generate a random 32-character password
openssl rand -base64 32
```

**Example output:**
```
kE9$mP2#vL8@qW4^nR7%tY3&xF6*uH5!
```

**SAVE THIS IN 1PASSWORD IMMEDIATELY!**

### Step 2: Add to 1Password

1. Open 1Password
2. Create new entry: "LimeSurvey Backup Encryption Key"
3. Paste the generated key
4. Add notes: "Used to encrypt/decrypt LimeSurvey backups on Google Drive"
5. Save

### Step 3: Add to `.env` File

On your Raspberry Pi:

```bash
cd ~/limesurvey-lykebo
nano .env
```

Add this line (with YOUR generated key):

```bash
BACKUP_ENCRYPTION_KEY=kE9$mP2#vL8@qW4^nR7%tY3&xF6*uH5!
```

Save and exit (`Ctrl+X`, `Y`, `Enter`)

### Step 4: Rebuild and Restart

```bash
# Rebuild backup service
docker compose build db_backup

# Restart backup service
docker compose up -d db_backup

# Check it's working
docker compose logs -f db_backup
```

**Look for:** `Encryption: ENABLED` in the logs

### Step 5: Test Encryption

```bash
# Trigger manual backup
docker compose exec db_backup python /app/backup.py

# Check logs for encryption
docker compose logs db_backup --tail=50 | grep -i encrypt
```

**You should see:**
```
[2025-01-30 15:00:30] Encryption: ENABLED
[2025-01-30 15:00:45] Encrypting backup with AES-256...
[2025-01-30 15:00:48] Encryption successful: /backups/limesurvey_backup_*.sql.gz.enc
[2025-01-30 15:00:48] Removed unencrypted backup
```

**Check Google Drive:** File should end with `.sql.gz.enc`

## Done! ✅

Your backups are now encrypted before uploading to Google Drive.

---

## How to Restore from Encrypted Backup

### Quick Restore

If you ever need to restore from an encrypted backup:

#### Step 1: Download Encrypted Backup

From Google Drive, download the backup file:
```
limesurvey_backup_20250130_150000.sql.gz.enc
```

#### Step 2: Get Encryption Key

From 1Password, copy your `BACKUP_ENCRYPTION_KEY`

#### Step 3: Decrypt

```bash
# On Raspberry Pi or your computer
# Replace YOUR_KEY with the key from 1Password

openssl enc -aes-256-cbc -d \
  -salt \
  -pbkdf2 \
  -iter 100000 \
  -in limesurvey_backup_20250130_150000.sql.gz.enc \
  -out limesurvey_backup_20250130_150000.sql.gz \
  -pass pass:YOUR_KEY
```

#### Step 4: Decompress

```bash
gunzip limesurvey_backup_20250130_150000.sql.gz
```

You now have: `limesurvey_backup_20250130_150000.sql`

#### Step 5: Restore to Database

```bash
# Stop containers
docker compose down

# Remove old database
docker volume rm limesurvey-lykebo_db_data

# Start database
docker compose up -d database

# Wait for database to start
sleep 30

# Restore backup
docker compose exec -T database mysql -uroot -p$MYSQL_ROOT_PASSWORD limesurvey < limesurvey_backup_20250130_150000.sql

# Start everything
docker compose up -d
```

### One-Command Restore (Advanced)

```bash
# Download, decrypt, decompress, and restore in one command
curl "GOOGLE_DRIVE_DOWNLOAD_URL" | \
  openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 -pass pass:YOUR_KEY | \
  gunzip | \
  docker compose exec -T database mysql -uroot -p$MYSQL_ROOT_PASSWORD limesurvey
```

---

## FAQ

### Q: What if I lose the encryption key?

**A:** Your backups are **permanently unrecoverable**. This is why you MUST save it in 1Password!

### Q: Can I change the encryption key?

**A:** Yes, but:
1. Old backups will still need the old key
2. New backups will use the new key
3. Recommended: Keep old key for 30 days, then change

**To change:**
1. Update `BACKUP_ENCRYPTION_KEY` in `.env`
2. Rebuild: `docker compose build db_backup`
3. Restart: `docker compose up -d db_backup`
4. Save new key in 1Password with date

### Q: Does encryption slow down backups?

**A:** Minimal impact (~5-10 seconds per backup). Worth it for security!

### Q: What about existing backups in Google Drive?

**A:** They remain unencrypted. Options:
1. Leave them (delete manually later)
2. Download, encrypt locally, re-upload
3. Let them age out per retention policy

New backups will be encrypted automatically.

### Q: Can I disable encryption later?

**A:** Yes, just remove `BACKUP_ENCRYPTION_KEY` from `.env` and rebuild container. Future backups will be unencrypted.

### Q: Is AES-256 secure enough?

**A:** Yes! AES-256 with PBKDF2 (100,000 iterations) is:
- Used by governments for classified data
- Would take billions of years to crack with brute force
- Industry standard for encryption

### Q: What encryption algorithm is used?

**A:**
- Algorithm: AES-256-CBC
- Key derivation: PBKDF2 with SHA-256
- Iterations: 100,000
- Salt: Random (included with encrypted file)

### Q: Do I need to back up the encryption key somewhere else?

**A:** YES! Store in multiple places:
- 1Password (primary)
- Written on paper in safe (backup)
- Encrypted USB drive (backup)
- Share with trusted colleague (optional)

**Without the key, backups are useless!**

### Q: How do I test decryption without restoring?

```bash
# Test that you can decrypt (dry run)
openssl enc -aes-256-cbc -d \
  -salt -pbkdf2 -iter 100000 \
  -in backup.sql.gz.enc \
  -pass pass:YOUR_KEY | \
  gunzip | head -n 20

# Should show SQL commands
```

---

## Security Checklist

After enabling encryption:

- [ ] Generated strong encryption key (`openssl rand -base64 32`)
- [ ] Saved key in 1Password
- [ ] Added key to `.env` file
- [ ] Secured `.env` file permissions (`chmod 600 .env`)
- [ ] Rebuilt backup container
- [ ] Tested manual backup
- [ ] Verified `.enc` file in Google Drive
- [ ] Tested decryption (dry run)
- [ ] Documented where key is stored
- [ ] Added calendar reminder to test restore monthly

---

## Troubleshooting

### Error: "Encryption failed"

**Check logs:**
```bash
docker compose logs db_backup --tail=100
```

**Common causes:**
- `BACKUP_ENCRYPTION_KEY` is empty
- Special characters in key need escaping
- OpenSSL not installed (shouldn't happen)

**Fix:** Check `.env` file has correct key without quotes

### Error: "bad decrypt" when restoring

**Cause:** Wrong encryption key

**Fix:** Get correct key from 1Password, try again

### Backups still showing as `.sql.gz` (not `.enc`)

**Cause:** Container not rebuilt after adding key

**Fix:**
```bash
docker compose build db_backup
docker compose up -d db_backup
```

### Want to verify encryption is working

```bash
# Check recent backup logs
docker compose logs db_backup | grep -A 5 "Encryption:"

# Should show: "Encryption: ENABLED"
```

---

## Summary

| What | Status | Action |
|------|--------|--------|
| **Password security** | ✅ Hashed (bcrypt) | None needed |
| **Backup encryption** | ⚠️ Optional | **Enable now!** |
| **HTTPS** | ✅ Enabled | None needed |
| **Encryption key storage** | ⚠️ Required | **Save in 1Password!** |

**Time to setup:** 5 minutes
**Security benefit:** Massive
**Complexity:** Low

**DO IT NOW!** 🔒
