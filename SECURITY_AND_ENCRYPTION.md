# Security & Encryption Guide

## Overview

This guide covers encryption and security recommendations for your LimeSurvey installation on Raspberry Pi.

## Current Security Baseline

### ✅ Already Implemented

| Component | Security Feature | Status |
|-----------|------------------|--------|
| **Web Traffic** | HTTPS via Cloudflare Tunnel | ✅ Encrypted |
| **Google Drive API** | TLS 1.3 | ✅ Encrypted |
| **Database Access** | Password authentication | ✅ Protected |
| **Admin Panel** | Password authentication | ✅ Protected |
| **Container Network** | Isolated Docker network | ✅ Protected |

### Security Enhancement Options

| Component | Current State | Recommendation |
|-----------|---------------|----------------|
| **Backup files** | ✅ AES-256 encryption available | Enable in .env (5 min setup) |
| **Database files** | Plain text on disk | Optional: Encrypt volume |
| **Survey responses** | Plain text in DB | Optional: Application-level encryption |
| **Docker volumes** | Unencrypted | Optional: Encrypt filesystem |

## Encryption Levels

```
┌─────────────────────────────────────────────────┐
│              Encryption Layers                  │
├─────────────────────────────────────────────────┤
│                                                 │
│  Level 1: Transport (Already Done)              │
│  ├─ HTTPS (Cloudflare)           ✅            │
│  └─ TLS (Google Drive API)       ✅            │
│                                                 │
│  Level 2: Backup Encryption (Recommended)       │
│  ├─ Encrypt SQL dumps            ✅ Done       │
│  └─ Encrypted Google Drive       ✅ Done       │
│                                                 │
│  Level 3: Database Encryption (Optional)        │
│  ├─ Encrypted volumes            🔧 Optional   │
│  └─ MariaDB encryption           🔧 Optional   │
│                                                 │
│  Level 4: Application Encryption (Advanced)     │
│  ├─ Field-level encryption       🔧 Advanced   │
│  └─ LimeSurvey plugins           🔧 Advanced   │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Recommended Implementation

### Priority 1: Encrypted Backups (High Priority) ✅ IMPLEMENTED

**Why:** Backups contain all your sensitive data and are stored off-site.

**Implementation:** Encrypt SQL dumps before uploading to Google Drive using AES-256.

**Pros:**
- ✅ Easy to implement (5-minute setup)
- ✅ Minimal performance impact
- ✅ Protects data in Google Drive
- ✅ Protects local backups
- ✅ Already integrated in backup script

**Cons:**
- ⚠️ Requires secure key storage (use 1Password)
- ⚠️ Manual decryption for restore

**Setup:**
1. Generate encryption key: `openssl rand -base64 32`
2. Store in 1Password
3. Add to `.env` file as `BACKUP_ENCRYPTION_KEY`
4. Rebuild backup service: `docker compose build db_backup && docker compose up -d db_backup`

**See detailed guide:** [ENCRYPTED_BACKUPS_GUIDE.md](ENCRYPTED_BACKUPS_GUIDE.md)

### Priority 2: LimeSurvey Built-in Security (Medium Priority)

**Why:** LimeSurvey has built-in security features you should enable.

**Implementation:** Configure LimeSurvey security settings.

**Features:**
- Password hashing (bcrypt)
- Session security
- CSRF protection
- XSS protection
- SQL injection protection

### Priority 3: Database Volume Encryption (Optional)

**Why:** Protects data if SD card is stolen.

**Implementation:** Use LUKS encryption for volumes.

**Pros:**
- ✅ Transparent encryption
- ✅ Protects all data at rest
- ✅ Military-grade security

**Cons:**
- ❌ Complex setup
- ❌ Performance overhead on Pi
- ❌ Manual unlock on boot
- ❌ Can't auto-start without key

### Priority 4: Application-Level Encryption (Advanced)

**Why:** Maximum security for specific sensitive fields.

**Implementation:** LimeSurvey plugins or custom code.

**Use cases:**
- Health data
- Financial information
- Personal identifiable information (PII)

## Detailed Implementation Guides

> **⚡ Quick Start:** We now have a simpler backup encryption implementation using AES-256 with a passphrase!
> **See:** [ENCRYPTED_BACKUPS_GUIDE.md](ENCRYPTED_BACKUPS_GUIDE.md) for a 5-minute setup guide.
> The GPG approach below is an alternative for advanced users who prefer public-key cryptography.

### 1. Encrypted Backups with AES-256 (Recommended - Simple Approach)

**Implementation:** Already integrated in backup script - just enable it!

**Setup:**
```bash
# 1. Generate encryption key
openssl rand -base64 32

# 2. Save in 1Password

# 3. Add to .env
BACKUP_ENCRYPTION_KEY=<your-generated-key>

# 4. Rebuild backup service
docker compose build db_backup
docker compose up -d db_backup
```

**See full guide:** [ENCRYPTED_BACKUPS_GUIDE.md](ENCRYPTED_BACKUPS_GUIDE.md)

**Encryption details:**
- Algorithm: AES-256-CBC
- Key derivation: PBKDF2 with SHA-256
- Iterations: 100,000
- Security: Government-grade encryption

**Pros:**
- ✅ Very easy to setup (5 minutes)
- ✅ Already implemented in backup script
- ✅ Passphrase stored in 1Password
- ✅ No GPG complexity
- ✅ Minimal performance impact

**Cons:**
- ⚠️ Single passphrase (not public-key cryptography)
- ⚠️ Must keep passphrase secure in 1Password

### 2. Encrypted Backups with GPG (Alternative - Advanced)

#### Step 1: Generate Encryption Key

```bash
# On Raspberry Pi
gpg --gen-key

# Follow prompts:
# - Real name: LimeSurvey Backup
# - Email: backup@yourdomain.com
# - Passphrase: [STRONG PASSWORD - SAVE IN PASSWORD MANAGER]

# Export public key (for encryption)
gpg --export -a "LimeSurvey Backup" > /home/pi/limesurvey-lykebo/backup-encryption-public.key

# Export private key (for decryption - KEEP SECURE!)
gpg --export-secret-key -a "LimeSurvey Backup" > /home/pi/limesurvey-lykebo/backup-encryption-private.key

# Secure the keys
chmod 600 /home/pi/limesurvey-lykebo/backup-encryption-*.key
```

#### Step 2: Backup Private Key

**CRITICAL:** Store private key in multiple secure locations:
- Password manager (e.g., 1Password, Bitwarden)
- Encrypted USB drive (off-site)
- Secure cloud storage (separate from Google Drive)

**Without the private key, you CANNOT decrypt backups!**

#### Step 3: Test Encryption/Decryption

```bash
# Test encryption
echo "Test data" | gpg --encrypt --recipient "LimeSurvey Backup" > test.gpg

# Test decryption
gpg --decrypt test.gpg
# Should show: "Test data"

# Cleanup
rm test.gpg
```

#### Step 4: Modify Backup Script

I'll create an encrypted version of the backup script.

### 2. LimeSurvey Security Hardening

#### In LimeSurvey Admin Panel

1. **Navigate to:** Configuration → Global settings → Security

2. **Enable these settings:**
   ```
   Force HTTPS: Yes
   Session lifetime: 3600 (1 hour)
   Password requirements: Strong
   Enable CAPTCHA: Yes (for public surveys)
   XSS filter: On
   IP address checking: Strict
   ```

3. **Configure database:**
   ```
   Use prepared statements: Yes
   Encrypt answers: Yes (if available in your version)
   ```

4. **User passwords:**
   - Force strong passwords
   - Regular password expiry (90 days)
   - Two-factor authentication (if available)

### 3. Database Connection Encryption

#### Enable SSL for MySQL Connections

**Benefits:**
- Encrypts data between containers
- Protects against network sniffing

**Note:** Less important since containers use isolated Docker network, but good practice.

**Implementation:**
1. Generate SSL certificates for MariaDB
2. Configure MariaDB to require SSL
3. Update LimeSurvey connection settings

**Complexity:** Medium
**Performance Impact:** Low (~5%)

### 4. Disk Encryption with LUKS

#### Full Disk Encryption

**When to use:**
- High-security requirements
- Pi located in unsecure location
- Compliance requirements (GDPR, HIPAA)

**Trade-offs:**
- ⚠️ Cannot auto-start on boot (needs passphrase)
- ⚠️ 10-15% performance overhead
- ⚠️ Complex recovery if forgotten passphrase

**Alternative: Encrypted Docker Volumes**

Encrypt only the database volume instead of full disk:

```bash
# Create encrypted volume
sudo cryptsetup luksFormat /path/to/volume
sudo cryptsetup open /path/to/volume db_encrypted
sudo mkfs.ext4 /dev/mapper/db_encrypted

# Mount and use
sudo mount /dev/mapper/db_encrypted /var/lib/docker/volumes/db_data
```

**Problem:** Requires manual unlock on every reboot.

## Recommended Strategy for Most Users

### Tier 1: Basic (Minimum Recommended)

**Implements:**
- ✅ HTTPS (already done via Cloudflare)
- ✅ Strong passwords
- ✅ LimeSurvey security settings
- ✅ Regular backups

**Effort:** Low
**Cost:** Free
**Suitable for:** Low-sensitivity surveys, internal use

### Tier 2: Enhanced (Recommended)

**Implements:**
- ✅ Everything from Tier 1
- ✅ Encrypted backups (AES-256 - 5 min setup)
- ✅ Secure key management (1Password)
- ✅ Restricted admin access

**Effort:** Low-Medium (1 hour total)
**Cost:** Free
**Suitable for:** Most production deployments

**Setup guide:** [ENCRYPTED_BACKUPS_GUIDE.md](ENCRYPTED_BACKUPS_GUIDE.md)

### Tier 3: High Security (Advanced)

**Implements:**
- ✅ Everything from Tier 2
- ✅ Encrypted Docker volumes
- ✅ Application-level encryption
- ✅ Regular security audits
- ✅ Compliance measures

**Effort:** High
**Cost:** Medium (time investment)
**Suitable for:** Healthcare, finance, PII data

## Password Management

### Database Passwords

**Current approach:**
- Passwords in `.env` file
- File permissions: 600 (owner only)

**Enhanced approach:**

1. **Use password manager:**
   ```bash
   # Generate strong passwords
   openssl rand -base64 32
   ```

2. **Rotate passwords regularly:**
   ```bash
   # Every 90 days:
   # 1. Update .env
   # 2. Restart containers
   # 3. Update documentation
   ```

3. **Never commit passwords:**
   ```bash
   # .gitignore already includes:
   .env
   google-credentials.json
   *.key
   ```

### LimeSurvey Admin Passwords

**Best practices:**
1. Minimum 16 characters
2. Mix of letters, numbers, symbols
3. Unique (not reused)
4. Stored in password manager
5. Changed every 90 days

**Two-factor authentication:**
- Enable if your LimeSurvey version supports it
- Use authenticator app (Google Authenticator, Authy)
- Backup recovery codes

## Compliance Considerations

### GDPR (European Data)

**Requirements:**
- ✅ Data encryption (backups)
- ✅ Access controls (passwords)
- ✅ Data retention policy (backup rotation)
- ✅ Right to erasure (manual process)
- ✅ Data portability (export features)

**Additional steps:**
1. Privacy policy in LimeSurvey
2. Cookie consent banner
3. Data processing agreement
4. Regular security audits

### HIPAA (US Healthcare)

**Requirements:**
- ✅ Encrypted data at rest (need to implement)
- ✅ Encrypted data in transit (done)
- ✅ Access controls (done)
- ✅ Audit logs (enable in LimeSurvey)
- ✅ Regular backups (done)

**Additional steps:**
1. Business Associate Agreement (BAA)
2. Risk assessment
3. Incident response plan
4. Staff training

### Other Regulations

- **CCPA (California):** Similar to GDPR
- **PIPEDA (Canada):** Data protection requirements
- **Industry-specific:** Check your requirements

## Key Management

### Encryption Keys Storage

**For GPG backup encryption:**

1. **Production key (private):**
   - Password manager (primary)
   - Encrypted USB drive (backup 1 - safe deposit box)
   - Secure cloud storage (backup 2 - different provider)

2. **Public key:**
   - Can be stored in git repository
   - Used only for encryption, not decryption

3. **Access control:**
   - Only trusted personnel
   - Document who has access
   - Rotate after personnel changes

### Key Rotation

**Recommendation:** Rotate encryption keys yearly.

**Process:**
1. Generate new key pair
2. Re-encrypt all existing backups with new key
3. Update backup script to use new key
4. Securely destroy old private key (after re-encryption verified)

## Monitoring & Auditing

### Security Monitoring

**Enable in LimeSurvey:**
1. Failed login attempts
2. Admin actions log
3. Survey access logs

**Monitor in Netdata:**
1. Unusual CPU spikes (crypto mining attack)
2. Network traffic anomalies
3. Failed SSH attempts

**Regular checks:**
```bash
# Failed SSH attempts
sudo journalctl -u ssh | grep "Failed password"

# Docker container logs
docker compose logs | grep -i "error\|failed\|unauthorized"

# Check open ports
sudo netstat -tlnp
```

### Security Audits

**Monthly:**
- Review admin access logs
- Check for failed login attempts
- Verify backup encryption working
- Test backup restoration

**Quarterly:**
- Update all passwords
- Review user permissions
- Check for LimeSurvey updates
- Security scan (optional)

**Yearly:**
- Full security audit
- Penetration testing (optional)
- Compliance review
- Update security policies

## Backup Security Checklist

### Before Implementing

- [ ] Backup current data
- [ ] Test restoration process
- [ ] Document current passwords
- [ ] Plan maintenance window

### Encrypted Backups

- [ ] Generate encryption key (`openssl rand -base64 32`)
- [ ] Save key in 1Password
- [ ] Add `BACKUP_ENCRYPTION_KEY` to `.env`
- [ ] Rebuild backup service (`docker compose build db_backup`)
- [ ] Test encrypted backup (`docker compose exec db_backup python /app/backup.py`)
- [ ] Verify `.enc` file in Google Drive
- [ ] Test decryption (dry run)
- [ ] Document key location

**See:** [ENCRYPTED_BACKUPS_GUIDE.md](ENCRYPTED_BACKUPS_GUIDE.md)

### Ongoing Maintenance

- [ ] Monthly: Verify backups
- [ ] Quarterly: Test restore
- [ ] Yearly: Rotate keys
- [ ] Update documentation

## FAQ

### Q: Should I encrypt everything?

**A:** Start with encrypted backups (Priority 1). Add more encryption based on your data sensitivity and compliance requirements.

### Q: What if I lose the encryption key?

**A:** **Your backups are permanently unrecoverable.** This is why you MUST:
- Store key in password manager
- Keep offline backup (USB drive in safe)
- Keep off-site backup (secure cloud storage)

### Q: Does encryption slow down the Pi?

**A:**
- Backup encryption: ~10% slower backups (acceptable)
- Volume encryption: ~15% slower database (noticeable)
- Application encryption: Depends on implementation

### Q: Can I encrypt just sensitive fields?

**A:** Yes, but requires custom development or LimeSurvey plugins. Complex to implement correctly.

### Q: Is Cloudflare Tunnel secure enough?

**A:** Yes, it provides:
- TLS 1.3 encryption
- DDoS protection
- No exposed ports
- Zero trust architecture

### Q: What about ransomware?

**A:** Best protection:
1. Regular backups (done)
2. Off-site backups (done - Google Drive)
3. Encrypted backups (implement)
4. Regular Pi OS updates
5. Strong passwords
6. Disable SSH password auth (use keys only)

### Q: How do I decrypt a backup?

**For AES-256 encrypted backups:**
```bash
# Download encrypted backup from Google Drive
# Decrypt with OpenSSL (replace YOUR_KEY with key from 1Password)
openssl enc -aes-256-cbc -d \
  -salt -pbkdf2 -iter 100000 \
  -in limesurvey_backup_20250130_120000.sql.gz.enc \
  -out limesurvey_backup_20250130_120000.sql.gz \
  -pass pass:YOUR_KEY

# Decompress
gunzip limesurvey_backup_20250130_120000.sql.gz

# Restore to database
docker compose exec -T database mysql -uroot -p$MYSQL_ROOT_PASSWORD limesurvey < limesurvey_backup_20250130_120000.sql
```

**See detailed restore guide:** [ENCRYPTED_BACKUPS_GUIDE.md](ENCRYPTED_BACKUPS_GUIDE.md)

## Next Steps

### Immediate (This Week)

1. **Implement encrypted backups (5 minutes):**
   - Follow [ENCRYPTED_BACKUPS_GUIDE.md](ENCRYPTED_BACKUPS_GUIDE.md)
   - Generate key: `openssl rand -base64 32`
   - Save in 1Password
   - Add to `.env` and rebuild backup service
   - Test encryption

2. **Harden LimeSurvey:**
   - Configure security settings
   - Enable strong passwords
   - Set up CAPTCHA

3. **Document:**
   - Where encryption key is stored (1Password)
   - Recovery procedure
   - Responsible personnel

### Short-term (This Month)

1. Review and update all passwords
2. Set up security monitoring alerts
3. Test encrypted backup restoration
4. Create incident response plan

### Long-term (Ongoing)

1. Regular security audits
2. Stay updated on LimeSurvey security advisories
3. Review and update security policies
4. Compliance reviews (if applicable)

## Resources

- **LimeSurvey Security:** https://manual.limesurvey.org/Security_issues
- **OWASP Top 10:** https://owasp.org/www-project-top-ten/
- **GPG Documentation:** https://gnupg.org/documentation/
- **GDPR Compliance:** https://gdpr.eu/
- **HIPAA Guidance:** https://www.hhs.gov/hipaa/

---

**Remember:** Security is a process, not a product. Regular reviews and updates are essential.
