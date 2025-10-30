# Update & Recovery Strategy

## Overview

This LimeSurvey setup includes comprehensive health monitoring, automated updates, and intelligent recovery mechanisms to ensure maximum uptime on your Raspberry Pi.

## Health Checks

### What are Health Checks?

Health checks are automated tests that Docker runs periodically to verify each container is functioning properly. If a health check fails multiple times, Docker marks the container as "unhealthy".

### Configured Health Checks

| Container | Health Check | Interval | Purpose |
|-----------|-------------|----------|---------|
| **MariaDB** | Database connection test | 30s | Ensures database accepts connections |
| **LimeSurvey** | HTTP endpoint check | 30s | Verifies web application responds |
| **Adminer** | PHP internal check | 30s | Confirms admin interface is accessible |
| **Cloudflare Tunnel** | Tunnel ready endpoint | 30s | Validates tunnel connectivity |
| **Netdata** | API info endpoint | 30s | Checks monitoring service |
| **Backup Service** | Cron process check | 60s | Ensures backup scheduler is running |

### Viewing Health Status

```bash
# Check health status of all containers
docker compose ps

# Detailed health information
docker inspect limesurvey_app | grep -A 10 Health

# Watch health status in real-time (Netdata dashboard)
http://<pi-ip>:19999
```

## Automated Updates

### Watchtower - Automatic Container Updates

**What it does:**
- Checks for new Docker images daily at 3 AM
- Updates containers one at a time (rolling updates)
- Automatically restarts updated containers
- Cleans up old images to save disk space

**Benefits of using latest images:**
- ✅ Security patches automatically applied
- ✅ Bug fixes
- ✅ New features
- ✅ Performance improvements

**What is NOT updated:**
- ❌ Backup service (locally built) - must rebuild manually
- ❌ Custom configurations
- ❌ Database data (preserved in volumes)
- ❌ LimeSurvey survey data (preserved)

### Update Schedule

```
Daily at 3:00 AM (local time):
├── Watchtower wakes up
├── Checks Docker Hub for new images
├── Downloads new images if available
├── Updates containers one by one
├── Verifies health checks pass
└── Cleans up old images
```

### Manual Updates

```bash
# Update all containers immediately
cd ~/limesurvey-lykebo
docker compose pull
docker compose up -d

# Update specific container
docker compose pull limesurvey
docker compose up -d limesurvey

# Rebuild backup service after code changes
docker compose build db_backup
docker compose up -d db_backup

# View Watchtower logs
docker compose logs -f watchtower
```

### Disabling Automatic Updates

If you prefer manual control:

1. Stop Watchtower:
   ```bash
   docker compose stop watchtower
   ```

2. Or remove it entirely from `docker-compose.yml`

## Recovery Strategy

### Level 1: Container Restart (Automatic)

**Trigger:** Health check fails 3 times
**Action:** Docker automatically restarts the unhealthy container
**Duration:** ~10-30 seconds

This handles temporary glitches like memory leaks or transient errors.

### Level 2: Watchdog Container Restart

**Trigger:** Watchdog detects unhealthy/stopped containers
**Action:** Forcefully restart affected containers
**Duration:** ~30-60 seconds
**Frequency:** Checked every 5 minutes

The watchdog script (`scripts/watchdog/health-monitor.sh`) monitors all critical services and attempts restarts if needed.

### Level 3: Full System Restart

**Trigger:** Multiple container restarts fail within 1 hour
**Action:** `docker compose down` followed by `docker compose up -d`
**Duration:** ~1-2 minutes

This handles issues where container dependencies are broken.

### Level 4: Raspberry Pi Reboot (Last Resort)

**Trigger:** Full system restart fails 5+ times
**Action:** Complete Pi reboot
**Duration:** ~2-3 minutes

**When this happens:**
- Docker service is unresponsive
- Critical corruption or resource exhaustion
- Kernel-level issues

**Reboot tracking:**
- Logged in `/var/log/limesurvey-reboots.log`
- Check with: `sudo cat /var/log/limesurvey-reboots.log`

## Watchdog Service

### Setup

The health monitor watchdog runs every 5 minutes and checks system health.

**Install:**
```bash
# Make script executable
chmod +x scripts/watchdog/health-monitor.sh

# Install systemd service and timer
sudo cp limesurvey-watchdog.service /etc/systemd/system/
sudo cp limesurvey-watchdog.timer /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable limesurvey-watchdog.timer
sudo systemctl start limesurvey-watchdog.timer
```

**Monitor:**
```bash
# Check timer status
sudo systemctl status limesurvey-watchdog.timer

# View watchdog logs
sudo tail -f /var/log/limesurvey-watchdog.log

# View systemd logs
sudo journalctl -u limesurvey-watchdog.service -f
```

**Disable:**
```bash
sudo systemctl stop limesurvey-watchdog.timer
sudo systemctl disable limesurvey-watchdog.timer
```

## Startup Behavior

### On Raspberry Pi Boot

1. **Docker starts** (systemd)
2. **Image pull** - Downloads latest images (if network available)
3. **Build** - Rebuilds backup service
4. **Containers start** - All services launch
5. **Database restore** - Restores from Google Drive (if first run)
6. **Watchdog timer starts** - Monitoring begins after 5 minutes

### Benefits

- ✅ **Always up-to-date** - Latest images pulled on boot
- ✅ **Automatic recovery** - Database restored from cloud backup
- ✅ **No manual intervention** - Fully autonomous

### Image Pull on Startup

The systemd service includes:
```bash
ExecStartPre=/usr/bin/docker compose pull --quiet --ignore-buildable
```

This ensures you're running the latest versions even if Watchtower missed an update.

## Update Rollback

### If an Update Breaks Something

**Quick rollback:**
```bash
# Stop containers
docker compose down

# List available image versions
docker images martialblog/limesurvey

# Edit docker-compose.yml to pin specific version
# Change: image: martialblog/limesurvey:latest
# To:     image: martialblog/limesurvey:6.4.0-230909

# Start with pinned version
docker compose up -d
```

**Restore from backup:**
```bash
# Stop everything
docker compose down

# Remove database volume
docker volume rm limesurvey-lykebo_db_data

# Restart (will auto-restore from Google Drive)
docker compose up -d
```

## Monitoring Updates

### Watchtower Notifications

Get notified when updates occur:

**Setup Slack notifications:**
```bash
# Add to .env
WATCHTOWER_NOTIFICATIONS=slack
WATCHTOWER_NOTIFICATION_URL=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

**Setup Discord notifications:**
```bash
# Add to .env
WATCHTOWER_NOTIFICATIONS=discord
WATCHTOWER_NOTIFICATION_URL=https://discord.com/api/webhooks/YOUR/WEBHOOK
```

**Setup email notifications:**
```bash
# Add to .env
WATCHTOWER_NOTIFICATIONS=email
WATCHTOWER_NOTIFICATION_URL=smtp://username:password@smtp.gmail.com:587/?fromAddress=from@example.com&toAddresses=to@example.com
```

### Netdata Alerts

Netdata automatically sends alerts for:
- Container unhealthy status
- High CPU/RAM usage
- LimeSurvey response time > 3 seconds
- Service downtime

View alerts in the Netdata dashboard: `http://<pi-ip>:19999`

## Best Practices

### ✅ DO

- **Test updates in staging** - If possible, test on a dev Pi first
- **Monitor Netdata** - Keep an eye on resource usage trends
- **Check logs regularly** - `docker compose logs -f`
- **Keep backups** - Hourly backups to Google Drive
- **Update backup service** - Rebuild after Git pulls
- **Pin critical versions** - In production, consider pinning versions

### ❌ DON'T

- **Don't disable health checks** - They're your early warning system
- **Don't skip watchdog setup** - It's your safety net
- **Don't ignore reboot logs** - Multiple reboots indicate a problem
- **Don't disable Watchtower** - Unless you commit to manual updates
- **Don't forget to test restore** - Verify backup/restore works

## FAQ

### Q: Will updates cause downtime?

**A:** Yes, but minimal (usually 10-30 seconds per container). Watchtower uses rolling restarts, so only one container restarts at a time.

### Q: What if an update happens during an active survey?

**A:**
- Users will experience a brief disconnection
- Most browsers will automatically reconnect
- Unsaved survey responses may be lost during the restart
- Schedule updates during low-traffic periods if possible

### Q: How do I prevent automatic reboots?

**A:** Don't install the watchdog timer, or set a higher `REBOOT_THRESHOLD` in the watchdog script.

### Q: Can I update during business hours?

**A:** Change Watchtower schedule in `docker-compose.yml`:
```yaml
WATCHTOWER_SCHEDULE: "0 0 3 * * *"  # 3 AM daily
# Change to:
WATCHTOWER_SCHEDULE: "0 0 2 * * 0"  # 2 AM on Sundays only
```

### Q: How do I know if updates are working?

**A:** Check Watchtower logs:
```bash
docker compose logs watchtower | grep -i "updated"
```

### Q: What if Google Drive backup fails during an update?

**A:** Backups run independently (hourly). Update failures won't affect backups. Previous backups remain in Google Drive.

## Troubleshooting

### Containers constantly restarting

```bash
# Check logs for errors
docker compose logs --tail=100 <container-name>

# Check health check output
docker inspect <container-name> | grep -A 20 Health

# Temporarily disable health checks (for debugging)
# Comment out healthcheck section in docker-compose.yml
```

### Watchdog causing unnecessary reboots

```bash
# Check watchdog state
cat /var/run/limesurvey-watchdog.state

# View reboot history
cat /var/log/limesurvey-reboots.log

# Adjust thresholds in scripts/watchdog/health-monitor.sh
```

### Updates not applying

```bash
# Check Watchtower is running
docker compose ps watchtower

# Check Watchtower logs
docker compose logs watchtower

# Force immediate update check
docker restart limesurvey_watchtower
```

### Pi won't boot after update

**Recovery:**
1. Remove power, wait 10 seconds
2. Power on - systemd will retry startup
3. SSH in: `ssh pi@<pi-ip>`
4. Check status: `sudo systemctl status limesurvey.service`
5. View logs: `sudo journalctl -u limesurvey.service -n 100`
6. If needed, rollback to previous image version

## Summary

| Feature | Benefit | Maintenance |
|---------|---------|-------------|
| **Health Checks** | Early problem detection | None - automatic |
| **Watchtower** | Always up-to-date | None - automatic |
| **Watchdog** | Automatic recovery | Check logs monthly |
| **Image Pull on Boot** | Fresh start after reboot | None - automatic |
| **Rolling Updates** | Minimal downtime | None - automatic |
| **Pi Reboot (last resort)** | Ultimate recovery | Investigate if frequent |

Your LimeSurvey installation is designed to be **self-healing** and **self-updating**, requiring minimal manual intervention.
