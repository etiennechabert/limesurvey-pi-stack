# Quick Start Guide

## Prerequisites Checklist

- [ ] Raspberry Pi 5 with 8GB+ RAM
- [ ] Raspberry Pi OS (64-bit) installed
- [ ] Internet connection
- [ ] Domain name (for Cloudflare Tunnel)

## Step-by-Step Setup (30 minutes)

### 1. Install Docker (5 minutes)

```bash
# Run on Raspberry Pi
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo apt-get install docker-compose-plugin -y
sudo reboot
```

### 2. Copy Files to Raspberry Pi (2 minutes)

```bash
cd ~
# Copy this folder to ~/limesurvey-lykebo
# Or clone from git: git clone <your-repo> limesurvey-lykebo
cd limesurvey-lykebo
```

### 3. Google Drive Setup (10 minutes)

1. Go to https://console.cloud.google.com/
2. Create project
3. Enable Google Drive API
4. Create Service Account
5. Download JSON key → save as `google-credentials.json`
6. Create folder in Google Drive
7. Share folder with service account email
8. Copy folder ID from URL

### 4. Cloudflare Tunnel Setup (8 minutes)

1. Go to https://one.dash.cloudflare.com/
2. Add your domain
3. Navigate to Access → Tunnels
4. Create tunnel → Copy token
5. Add public hostname:
   - Subdomain: `survey`
   - Service: `http://limesurvey:8080`

### 5. Configure Environment (3 minutes)

```bash
cp .env.example .env
nano .env
```

Fill in all values:
- Database passwords
- LimeSurvey admin credentials
- Google Drive folder ID
- Cloudflare tunnel token

### 6. Start Everything (2 minutes)

```bash
chmod +x scripts/restore-db.sh backup-service/entrypoint.sh
docker compose up -d
docker compose logs -f
```

Wait for all containers to start (look for "ready" or "started" messages).

### 7. Enable Auto-Start (2 minutes)

```bash
sudo cp limesurvey.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable limesurvey.service
sudo systemctl start limesurvey.service
```

## Verify Installation

### Check Containers

```bash
docker compose ps
```

All containers should show "Up" status.

### Test Access

1. **LimeSurvey**: http://\<raspberry-pi-ip\>:8080
   - Login with LIMESURVEY_ADMIN_USER and LIMESURVEY_ADMIN_PASSWORD

2. **Adminer**: http://\<raspberry-pi-ip\>:8081
   - Server: `database`
   - Username: `limesurvey` or `root`
   - Password: from `.env`

3. **Netdata**: http://\<raspberry-pi-ip\>:19999
   - Should show live metrics immediately

4. **Public URL**: https://survey.yourdomain.com
   - Should access LimeSurvey via Cloudflare Tunnel

## First Backup Test

```bash
# Trigger manual backup
docker compose exec db_backup python /app/backup.py

# Check if backup appeared in Google Drive
# Should see file like: limesurvey_backup_20250130_123456.sql.gz
```

## Optional: Enable Backup Encryption (Recommended - 5 minutes)

Protect user passwords by encrypting backups before uploading to Google Drive.

```bash
# Generate encryption key
openssl rand -base64 32

# Save the output in 1Password immediately!

# Add to .env file
nano .env
# Add line: BACKUP_ENCRYPTION_KEY=<paste-your-generated-key>

# Rebuild and restart backup service
docker compose build db_backup
docker compose up -d db_backup

# Test encrypted backup
docker compose exec db_backup python /app/backup.py

# Check logs for "Encryption: ENABLED"
docker compose logs db_backup --tail=20 | grep -i encrypt
```

**See detailed guide:** [ENCRYPTED_BACKUPS_GUIDE.md](ENCRYPTED_BACKUPS_GUIDE.md)

## Optional: Enable Restore on Boot (Recommended - 2 minutes)

Make your Pi stateless - restores from Google Drive backup on every boot. This validates your backups work!

```bash
# Edit .env
nano .env
# Set: RESTORE_ON_BOOT=true

# Make script executable
chmod +x scripts/restore-on-boot.sh

# Update systemd (if already installed)
sudo cp limesurvey.service /etc/systemd/system/
sudo systemctl daemon-reload

# Test with reboot
sudo reboot
```

**Benefits:**
- ✅ Proves backups work every boot
- ✅ Pi becomes stateless (Google Drive is source of truth)
- ✅ Easy disaster recovery

**Trade-off:**
- ⚠️ Max 1 hour of data at risk (between hourly backups)
- ⚠️ Slower boot time (~5-7 min vs ~2 min)

**See detailed guide:** [RESTORE_ON_BOOT.md](RESTORE_ON_BOOT.md)

## Next Steps

1. Configure your first survey in LimeSurvey
2. **Enable backup encryption** (see above - highly recommended!)
3. **Enable restore on boot** (see above - validates backups work!)
4. Set up Netdata alerts (optional)
5. Configure Cloudflare Access policies (optional)
6. Set up regular monitoring schedule

## Troubleshooting

### Container won't start
```bash
docker compose logs <container-name>
```

### Can't access services
```bash
# Check firewall
sudo ufw status

# Check if ports are listening
sudo netstat -tlnp | grep -E '8080|8081|19999'

# Find Raspberry Pi IP
hostname -I
```

### Backup failing
```bash
# Check credentials
ls -la google-credentials.json

# Test backup manually
docker compose exec db_backup python /app/backup.py
```

## Common Issues

**Issue**: "Permission denied" for google-credentials.json
**Fix**: `chmod 600 google-credentials.json`

**Issue**: Can't connect to Adminer
**Fix**: Use server name `database`, not `localhost`

**Issue**: Cloudflare tunnel not working
**Fix**: Check token in `.env`, verify public hostname configuration

**Issue**: Services don't start after reboot
**Fix**: `sudo systemctl status limesurvey.service` to check systemd service

## Getting Help

See the full README.md for detailed documentation and troubleshooting.
