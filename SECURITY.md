# Security Guide

## Table of Contents
- [Security Checklist](#security-checklist)
- [Current Status](#current-status)
- [Backup Encryption](#backup-encryption)
- [File Security](#file-security)
- [Network Security](#network-security)
- [Compliance](#compliance)
- [Vulnerability Management](#vulnerability-management)
- [Incident Response](#incident-response)
- [FAQ](#faq)

## Security Checklist

- [ ] Change default passwords in `.env`
- [ ] Enable backup encryption
- [ ] Secure `.env` permissions: `chmod 600 .env`
- [ ] Test restore process monthly
- [ ] Never commit `.env` or `google-credentials.json`

## Current Status

| Component | Security Feature |
|-----------|------------------|
| Web Traffic | HTTPS via Cloudflare Tunnel |
| API Calls | TLS 1.3 (Google Drive) |
| Passwords | bcrypt hashing |
| Backups | AES-256 encryption (optional) |
| Database | Password protected |
| Network | Isolated Docker network |

## Backup Encryption

**Enable encryption:**
```bash
# Generate key
openssl rand -base64 32

# Add to .env
BACKUP_ENCRYPTION_KEY=<your-key>

# Rebuild
docker compose build db_backup && docker compose up -d db_backup
```

**Algorithm:** AES-256-CBC with PBKDF2 (100,000 iterations)

**Decrypt:**
```bash
openssl enc -aes-256-cbc -d \
  -salt -pbkdf2 -iter 100000 \
  -in backup.sql.gz.enc \
  -out backup.sql.gz \
  -pass pass:YOUR_KEY
```

**Store encryption key:**
- Password manager (1Password, Bitwarden)
- Offline backup
- If lost, backups are unrecoverable

## File Security

**Never commit to git:**
- `.env` (passwords)
- `google-credentials.json` (API key)
- `backups/*.sql*` (database dumps)
- `*.key`, `*.pem` (encryption keys)

**Check before commit:**
```bash
./scripts/pre-commit-check.sh
```

## Network Security

**Cloudflare Tunnel:**
- No open firewall ports
- TLS 1.3 encryption
- DDoS protection
- Zero Trust architecture

**Optional - Cloudflare Access:**
Add authentication layer (email/SSO) via Cloudflare Zero Trust Dashboard.

## Compliance

**GDPR:**
- Encryption at rest (enable backup encryption)
- Access controls (passwords, admin accounts)
- Data retention (backup rotation policy)
- Privacy policy and cookie consent (configure in LimeSurvey)

**HIPAA:**
- Encrypted transit (HTTPS, TLS)
- Encrypted backups (enable encryption)
- Access controls
- Audit logs (enable in LimeSurvey)
- Business Associate Agreement (obtain separately)

## Vulnerability Management

**Automated:**
- Daily security scans (GitHub Actions)
- TruffleHog secret scanning
- Trivy container scanning
- Dependabot dependency updates
- Watchtower daily container updates (3:15 AM)

**Manual updates:**
```bash
docker compose pull && docker compose up -d
```

## Incident Response

**Breach response:**
1. Stop containers: `docker compose down`
2. Save logs: `docker compose logs > incident-logs.txt`
3. Change passwords in `.env`
4. Restore from pre-breach backup
5. Monitor for unusual activity

**Password guidelines:**
- Use password manager
- Minimum 16 characters
- Unique per service
- Generate: `openssl rand -base64 32`

## FAQ

**Q: Is Cloudflare Tunnel secure?**
A: TLS 1.3, DDoS protection, Zero Trust architecture. No open ports required.

**Q: Database encryption needed?**
A: Passwords are bcrypt-hashed. Encrypted backups provide additional protection.

**Q: Physical access to Pi/SD card?**
A: Passwords remain hashed. Enable backup encryption for full protection.

**Q: Detect compromise?**
A: Monitor Netdata for unusual CPU/network activity. Check LimeSurvey audit logs.

**Q: Disk encryption (LUKS)?**
A: Optional for high-security requirements. Prevents auto-boot.

## Resources

- LimeSurvey Security: https://manual.limesurvey.org/Security_issues
- OWASP Top 10: https://owasp.org/www-project-top-ten/
- Cloudflare Zero Trust: https://www.cloudflare.com/zero-trust/
- GDPR: https://gdpr.eu/
