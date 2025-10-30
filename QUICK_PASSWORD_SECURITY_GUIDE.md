# Quick Guide: Protecting User Passwords

## Your Concern

> "My main concern is to not potentially leak unencrypted login/password of my users"

## TL;DR - What You Need to Know

### ✅ GOOD NEWS: Passwords Are Already Hashed

**LimeSurvey NEVER stores passwords in plain text.**

- Passwords are hashed with **bcrypt** (industry standard)
- Database shows: `$2y$10$8K1p/a0dL3FRE...` (not: `MyPassword123`)
- Backups contain hashed passwords (not plain text)
- **Even you cannot see user passwords**

### ⚠️ REMAINING RISK: Backups Can Be Used for Cracking

**Problem:**
- Your Google Drive backups contain hashed passwords
- If someone gets your Google account credentials
- They can download backups and run password cracking tools
- Weak passwords can be cracked (even when hashed)

**Solution:**
- **Encrypt backups before uploading** (Priority #1)
- **Enforce strong password policies** (Priority #2)

## What This Means in Practice

### Scenario 1: Someone Gets Your Google Drive Backup

#### Without Encryption (Current):
```
Attacker downloads: limesurvey_backup_20250130.sql.gz
Attacker extracts: SQL file with hashed passwords
Attacker runs: hashcat (password cracking tool)

Results:
├─ "password123"  → Cracked in 2 seconds   ❌
├─ "Summer2024!"  → Cracked in 3 hours     ❌
└─ "kE9$mP2#vL"   → Not crackable          ✅
```

#### With Encryption (Recommended):
```
Attacker downloads: limesurvey_backup_20250130.sql.gz.gpg
Attacker tries to open: Requires GPG private key

Results:
└─ Cannot decrypt without key  ✅
   All passwords safe regardless of strength!
```

### Scenario 2: Someone Gets Your Raspberry Pi SD Card

#### Current State:
```
Attacker removes SD card from Pi
Attacker reads: /var/lib/docker/volumes/db_data
Attacker finds: Database files with hashed passwords

Results:
├─ Can copy database files       ⚠️
├─ Can attempt to crack passwords ⚠️
└─ Weak passwords at risk        ❌
```

#### With Encrypted Volumes (Optional):
```
Attacker removes SD card
Attacker tries to read: Encrypted filesystem
Requires passphrase to unlock

Results:
└─ Cannot access data  ✅
```

## Action Plan (Prioritized)

### Priority 1: Encrypt Backups (DO THIS FIRST) 🔥

**Time:** 30 minutes
**Complexity:** Medium
**Impact:** HIGH - Protects all backups

**Steps:**
1. Generate GPG encryption key
2. Backup the private key (3 secure locations!)
3. Modify backup script to encrypt before upload
4. Test encryption and decryption

**I can create the implementation for you.**

### Priority 2: Strong Password Policy

**Time:** 10 minutes
**Complexity:** Easy
**Impact:** HIGH - Prevents weak passwords

**Steps:**
1. Login to LimeSurvey admin
2. Go to: Configuration → Global Settings → Security
3. Set minimum password requirements:
   - Length: 12 characters minimum
   - Require: uppercase, lowercase, numbers, symbols
4. Save changes

### Priority 3: Review Existing User Passwords

**Time:** 15 minutes
**Complexity:** Easy
**Impact:** MEDIUM - Fix weak existing passwords

**Steps:**
1. Check if any users have old/weak passwords
2. Force password reset for all users
3. Notify users of new requirements

### Priority 4: Enable 2FA (If Available)

**Time:** 20 minutes per user
**Complexity:** Medium
**Impact:** HIGH - Prevents account compromise

**Steps:**
1. Check if your LimeSurvey version supports 2FA
2. Enable for admin accounts first
3. Use Google Authenticator or Authy
4. Save backup codes securely

## What You DON'T Need to Do

### ❌ Don't Encrypt the Entire Database

**Why:**
- Complex setup
- Significant performance impact on Pi
- Requires manual unlock on every reboot
- Backups are the real risk, not the running database

### ❌ Don't Implement Custom Password Encryption

**Why:**
- LimeSurvey already uses bcrypt (better than most custom solutions)
- Risk of implementing it wrong
- No benefit over proper backup encryption

### ❌ Don't Panic About Existing Backups

**Why:**
- Passwords are already hashed
- Only weak passwords are at risk
- Implement encryption going forward
- Optionally: re-encrypt old backups

## Quick Verification

### Check That Passwords Are Hashed

```bash
# Connect to database
docker compose exec database mysql -uroot -p$MYSQL_ROOT_PASSWORD

# Check password format
USE limesurvey;
SELECT uid, users_name, LEFT(password, 20) as pwd_start FROM users;
```

**Expected output:**
```
+-----+-------------+----------------------+
| uid | users_name  | pwd_start            |
+-----+-------------+----------------------+
|   1 | admin       | $2y$10$8K1p/a0dL3FR |
|   2 | john        | $2y$10$92IXUNpkjO0r |
+-----+-------------+----------------------+
```

**If you see:**
- `$2y$` = bcrypt (GOOD ✅)
- `$6$` = SHA-512 (acceptable)
- Plain text = PROBLEM ❌ (shouldn't happen)

## FAQ

### Q: Are my users' passwords safe right now?

**A:**
- **Strong passwords:** YES - bcrypt hashing protects them
- **Weak passwords:** AT RISK - if someone gets your backups, they could crack them
- **Solution:** Encrypt backups + enforce strong password policy

### Q: What if someone hacks my Google account?

**Current:** They get backups with hashed passwords (weak passwords at risk)
**With encryption:** They get encrypted backups (useless without key)

### Q: Can I see user passwords as admin?

**A:** NO - and that's a good thing! Even database admins cannot see plain passwords.

### Q: What about passwords in transit (during login)?

**A:** Already secure - Cloudflare Tunnel uses TLS 1.3 encryption.

### Q: Do I need to re-hash existing passwords?

**A:** NO - LimeSurvey automatically uses bcrypt. Existing hashes are fine.

### Q: What happens if I lose the encryption key?

**A:** **Your backups are permanently unrecoverable.** That's why you MUST:
- Save key in password manager
- Keep encrypted USB backup (safe deposit box)
- Keep secure cloud backup (different provider)

## Summary

| Security Measure | Status | Priority | Action |
|------------------|--------|----------|--------|
| **Password hashing** | ✅ Done (bcrypt) | - | None needed |
| **HTTPS encryption** | ✅ Done (Cloudflare) | - | None needed |
| **Strong password policy** | ⚠️ To configure | HIGH | 10 min setup |
| **Backup encryption** | ❌ Not yet | **CRITICAL** | 30 min setup |
| **2FA** | ⚠️ If available | HIGH | 20 min/user |
| **Volume encryption** | ❌ Not needed | LOW | Skip for now |

## Next Steps

1. **Read:** `SECURITY_AND_ENCRYPTION.md` (comprehensive guide)
2. **Implement:** Backup encryption (Priority 1)
3. **Configure:** Strong password policy in LimeSurvey
4. **Test:** Verify encryption working
5. **Document:** Where you stored the encryption key

## Need Help?

Let me know and I can:
1. Create the encrypted backup script for you
2. Provide step-by-step setup instructions
3. Create a testing checklist
4. Help with troubleshooting

---

**Bottom line:** Your passwords are already hashed (good!), but you should encrypt backups to prevent even hashed passwords from being cracked.
