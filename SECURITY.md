# Security Guide

## Quick Security Checklist

- [ ] Change all passwords in `.env` file
- [ ] Enable backup encryption (`BACKUP_ENCRYPTION_KEY`)
- [ ] Store encryption key in 1Password
- [ ] Secure `.env` permissions: `chmod 600 .env`
- [ ] Never commit `.env` or `google-credentials.json`
- [ ] Enable Cloudflare Access policies
- [ ] Test restore process monthly

## Current Security Status

| Component | Security Feature | Status |
|-----------|------------------|--------|
| **Web Traffic** | HTTPS via Cloudflare Tunnel | ✅ Encrypted |
| **API Calls** | TLS 1.3 (Google Drive) | ✅ Encrypted |
| **Passwords** | bcrypt hashing (LimeSurvey) | ✅ Protected |
| **Backups** | AES-256 encryption (optional) | ⚠️ Enable it! |
| **Database Access** | Password auth | ✅ Protected |
| **Container Network** | Isolated Docker network | ✅ Protected |

## User Password Security

### Already Protected ✅

LimeSurvey stores passwords using **bcrypt** (industry standard):
- Passwords are hashed, not stored in plain text
- Each password has a unique salt
- Computationally expensive to crack

### Why Encrypt Backups?

Even though passwords are hashed, backups should be encrypted because:
- Prevents rainbow table attacks on weak passwords
- Protects survey responses and data
- Required for GDPR/HIPAA compliance
- Defense in depth security

## Backup Encryption

### Enable AES-256 Encryption (5 minutes)

```bash
# 1. Generate key
openssl rand -base64 32

# 2. Save in 1Password immediately!

# 3. Add to .env
BACKUP_ENCRYPTION_KEY=<your-key>

# 4. Rebuild backup service
docker compose build db_backup && docker compose up -d db_backup
```

**Encryption details:**
- Algorithm: AES-256-CBC
- Key derivation: PBKDF2 with 100,000 iterations
- Same encryption used by governments

### Decryption (When Restoring)

```bash
openssl enc -aes-256-cbc -d \
  -salt -pbkdf2 -iter 100000 \
  -in backup.sql.gz.enc \
  -out backup.sql.gz \
  -pass pass:YOUR_KEY
```

## File Security

### Never Commit These

Protected by `.gitignore`:
- ❌ `.env` - Contains all passwords
- ❌ `google-credentials.json` - Google API key
- ❌ `backups/*.sql*` - Database backups
- ❌ `*.key`, `*.pem` - Encryption keys

### Before Each Commit

```bash
./scripts/pre-commit-check.sh
```

This script verifies no secrets are staged.

## Network Security

### Cloudflare Tunnel

- ✅ No ports opened on firewall
- ✅ Zero Trust architecture
- ✅ TLS 1.3 encryption
- ✅ DDoS protection
- ✅ No exposed IP address

### Optional: Cloudflare Access Policies

Add additional authentication:
1. Go to Cloudflare Zero Trust Dashboard
2. Access → Applications
3. Add policy for your LimeSurvey URL
4. Require email/Google/GitHub login

## LimeSurvey Security Settings

In LimeSurvey admin panel (Configuration → Security):

```
Force HTTPS: Yes
Session lifetime: 3600 seconds (1 hour)
Password strength: Strong
Enable CAPTCHA: Yes (public surveys)
XSS filter: On
SQL injection protection: On (automatic)
```

## Compliance

### GDPR (European Data)

✅ Covered by this setup:
- Data encryption (backups)
- Access controls (passwords)
- Data retention policy (backup rotation)
- Data portability (export features)

Still needed:
- Privacy policy in LimeSurvey
- Cookie consent banner
- Data processing agreement

### HIPAA (US Healthcare)

✅ Covered:
- Encrypted data in transit (HTTPS, TLS)
- Access controls (passwords)
- Regular backups
- Audit logs (enable in LimeSurvey)

Still needed for full compliance:
- Encrypted data at rest (enable backup encryption!)
- Business Associate Agreement (BAA)
- Risk assessment
- Incident response plan

## Security Monitoring

### Check Logs Regularly

```bash
# Failed login attempts (if SSH enabled)
sudo journalctl -u ssh | grep "Failed password"

# Docker container errors
docker compose logs | grep -i "error\|failed\|unauthorized"

# Backup encryption status
docker compose logs db_backup | grep "Encryption:"
```

### Netdata Alerts

Netdata monitors for:
- High CPU usage (potential crypto mining)
- Memory exhaustion (potential DOS)
- Disk space issues
- Container failures

Configure alerts in `monitoring/netdata/health.d/`

## Vulnerability Management

### Automated Scanning

GitHub Actions runs:
- **Daily** security scans
- **TruffleHog** secret scanning
- **Trivy** container vulnerability scanning
- **Dependabot** dependency updates

View results: https://github.com/etiennechabert/limesurvey-pi-stack/security

### Manual Updates

```bash
# Update all containers
docker compose pull
docker compose up -d

# Or let Watchtower do it automatically (daily 3:15 AM)
```

## Best Practices

### Passwords

- ✅ Use password manager (1Password, Bitwarden)
- ✅ Generate strong passwords: `openssl rand -base64 32`
- ✅ Unique passwords for each service
- ✅ Minimum 16 characters
- ✅ Rotate every 90 days

### Access Control

- ✅ Limit admin accounts
- ✅ Use strong passwords
- ✅ Enable 2FA (if LimeSurvey supports)
- ✅ Regular access reviews

### Backups

- ✅ Enable encryption
- ✅ Test restore monthly
- ✅ Store encryption key securely
- ✅ Monitor backup logs

### Updates

- ✅ Watchtower auto-updates (daily)
- ✅ Review Dependabot PRs (weekly)
- ✅ Check security advisories
- ✅ Test after major updates

## Incident Response

### If You Suspect a Breach

1. **Isolate**: Stop containers
   ```bash
   docker compose down
   ```

2. **Investigate**: Check logs
   ```bash
   docker compose logs > incident-logs.txt
   ```

3. **Rotate**: Change all passwords
   ```bash
   nano .env  # Update all passwords
   docker compose up -d
   ```

4. **Restore**: From known-good backup
   ```bash
   # Restore from backup before breach date
   ```

5. **Monitor**: Watch for unusual activity

### If Encryption Key is Lost

⚠️ **Backups are UNRECOVERABLE**

Prevention:
- Store in 1Password (primary)
- Write on paper in safe (backup)
- Store encrypted USB drive (backup)

## FAQ

**Q: Is Cloudflare Tunnel secure enough?**
A: Yes! TLS 1.3, DDoS protection, Zero Trust architecture. Better than opening ports.

**Q: Do I need to encrypt the database on disk?**
A: Not required for most use cases. Password hashing + encrypted backups is sufficient.

**Q: What if someone steals my Pi/SD card?**
A: Passwords are hashed (bcrypt). Enable backup encryption for full protection.

**Q: Should I enable disk encryption (LUKS)?**
A: Only if you have high-security requirements. Adds complexity and prevents auto-boot.

**Q: How do I know if I've been hacked?**
A: Monitor Netdata for unusual CPU/network activity. Check LimeSurvey admin logs.

## Security Levels

### Level 1: Basic (Minimum)
- ✅ Strong passwords
- ✅ HTTPS (Cloudflare)
- ✅ Regular backups
- Time: 0 hours (already configured)

### Level 2: Recommended
- ✅ Everything from Level 1
- ✅ Backup encryption
- ✅ Cloudflare Access policies
- ✅ Monthly restore tests
- Time: 1 hour setup

### Level 3: High Security
- ✅ Everything from Level 2
- ✅ 2FA on admin accounts
- ✅ IP restrictions
- ✅ Security audits
- ✅ Compliance documentation
- Time: Ongoing

## Resources

- LimeSurvey Security: https://manual.limesurvey.org/Security_issues
- OWASP Top 10: https://owasp.org/www-project-top-ten/
- Cloudflare Zero Trust: https://www.cloudflare.com/zero-trust/
- GDPR Compliance: https://gdpr.eu/

---

**Bottom line:** Enable backup encryption, use strong passwords, keep systems updated. You'll be well-protected! 🔒
