# Password Security: Protecting User Credentials

## Your Concern: User Password Leaks

You want to ensure that if someone gains access to:
- Your database
- Your backups (local or Google Drive)
- Your Raspberry Pi SD card

...they **CANNOT** obtain user passwords in plain text.

## Good News: LimeSurvey Already Protects Passwords ✅

### Password Hashing (Built-in)

**LimeSurvey DOES NOT store passwords in plain text.**

Instead, it uses **password hashing** with modern algorithms:

```
Plain Text Password          Hashed in Database
─────────────────────       ───────────────────────────────
MyPassword123        →      $2y$10$8K1p/a0dL3FRE...  (bcrypt)
```

**Key points:**
- ✅ Passwords are hashed using **bcrypt** or **SHA-256** (depending on version)
- ✅ Hashes are **one-way** - cannot be reversed to get original password
- ✅ Each password has unique **salt** (prevents rainbow table attacks)
- ✅ Even database admin cannot see user passwords

### How to Verify

#### Check Password Storage in Database

```bash
# Connect to database
docker compose exec database mysql -uroot -p$MYSQL_ROOT_PASSWORD limesurvey

# Look at users table
SELECT uid, users_name, password FROM users LIMIT 3;
```

**You'll see something like:**
```
+-----+-------------+--------------------------------------------------------------+
| uid | users_name  | password                                                     |
+-----+-------------+--------------------------------------------------------------+
|   1 | admin       | $2y$10$8K1p/a0dL3FRE...truncated...                           |
|   2 | surveymgr   | $2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi |
+-----+-------------+--------------------------------------------------------------+
```

**The `$2y$10$` prefix means bcrypt with cost factor 10 (very secure).**

#### Check Password in Backup

```bash
# Look at a backup file
gunzip -c backups/limesurvey_backup_*.sql.gz | grep "INSERT INTO.*users" | head -n 1
```

**You'll see hashed passwords, never plain text:**
```sql
INSERT INTO `users` VALUES (1,'admin','$2y$10$8K1p...',...);
```

## Remaining Risks & Mitigations

### Risk 1: Hashed Passwords Can Still Be Cracked

**Scenario:**
- Attacker gets database backup
- Runs password cracking tools
- Weak passwords can be cracked

**Example:**
```
Password: "password123"  → Cracked in seconds
Password: "p@ssw0rd"     → Cracked in minutes
Password: "MyDog2024!"   → Cracked in hours/days
Password: "kE9$mP2#vL8@qW4^"  → Virtually impossible
```

**Mitigation:**

1. **Enforce strong password policy in LimeSurvey:**
   - Minimum 12 characters
   - Require: uppercase, lowercase, numbers, symbols
   - Check against common passwords list

2. **Encrypted backups** (Priority!)
   - Even if attacker gets backup, they can't access it
   - Hashed passwords remain protected

### Risk 2: Backups Stored Unencrypted

**Current situation:**
- Backups on Google Drive contain hashed passwords
- If Google account compromised, attacker gets database dump
- Can attempt to crack weak passwords

**Mitigation: Encrypt Backups Before Upload** (Recommended!)

I'll create an implementation for this.

### Risk 3: Memory Dumps / Process Access

**Scenario:**
- Attacker gains root access to Pi
- Dumps memory of MariaDB process
- Might find passwords during authentication

**Mitigation:**
- Strong SSH security (key-based auth only)
- Firewall rules
- Regular updates
- Limited physical access to Pi

### Risk 4: Network Interception

**Scenario:**
- Attacker intercepts login requests
- Captures password during transmission

**Current Protection:**
- ✅ HTTPS via Cloudflare Tunnel (all traffic encrypted)
- ✅ TLS 1.3 (industry standard)

**Additional hardening:**
- Disable HTTP entirely (force HTTPS)
- Enable HSTS (HTTP Strict Transport Security)

## Recommended Security Configuration

### 1. LimeSurvey Password Policy

**Admin Panel → Configuration → Security:**

```
Minimum password length: 12
Maximum password age: 90 days
Require mixed case: Yes
Require numbers: Yes
Require special characters: Yes
Prevent password reuse: Last 5
Account lockout: 5 failed attempts
Lockout duration: 30 minutes
```

### 2. Two-Factor Authentication (2FA)

**If your LimeSurvey version supports it:**

Enable 2FA for admin accounts:
- TOTP (Time-based One-Time Password)
- Apps: Google Authenticator, Authy, 1Password
- Backup recovery codes

**Without 2FA, even strong passwords can be compromised by:**
- Keyloggers
- Phishing
- Social engineering

### 3. Encrypted Backups (High Priority)

Let me create the implementation...

## Implementation: Encrypted Backups

### Why Encrypt Backups?

**Defense in depth:**
- Even if Google account compromised → backups useless without key
- Even if SD card stolen → backups useless without key
- Protects hashed passwords from cracking attempts

### How It Works

```
Normal Backup:
Database → SQL dump → gzip → Google Drive
                               ↓
                      Anyone with access can read

Encrypted Backup:
Database → SQL dump → gzip → GPG encrypt → Google Drive
                                             ↓
                                  Need private key to read
```

### Setup (15 minutes)

I'll create an updated backup script with encryption...
