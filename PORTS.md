# Port Reference Guide

## Exposed Ports on Raspberry Pi

These ports are accessible from your local network:

| Port | Service | Purpose | Access |
|------|---------|---------|--------|
| **8080** | LimeSurvey | Survey application | `http://<pi-ip>:8080` |
| **8081** | Adminer | Database admin interface | `http://<pi-ip>:8081` |
| **19999** | Netdata | Monitoring dashboard | `http://<pi-ip>:19999` |

## Internal Ports (Docker Network Only)

These ports are only accessible within the Docker network:

| Port | Service | Purpose |
|------|---------|---------|
| 3306 | MariaDB | Database server |

## External Access

- **Cloudflare Tunnel**: Provides secure HTTPS access to LimeSurvey without exposing any ports to the internet
- No port forwarding required
- Access via: `https://your-domain.com`

## Firewall Configuration (Optional)

If you want to restrict access to monitoring/admin interfaces:

```bash
# Allow only local network access to admin ports
sudo ufw allow from 192.168.1.0/24 to any port 8081 comment 'Adminer - local only'
sudo ufw allow from 192.168.1.0/24 to any port 19999 comment 'Netdata - local only'

# Allow broader access to LimeSurvey (or use Cloudflare Tunnel only)
sudo ufw allow 8080 comment 'LimeSurvey'
```

## Security Best Practices

1. **Adminer** (8081): Only access from trusted devices on local network
2. **Netdata** (19999): Only access from local network (optional: set up authentication)
3. **LimeSurvey** (8080): Use Cloudflare Tunnel for public access instead of direct port exposure
4. Consider using SSH tunneling for remote admin access:
   ```bash
   ssh -L 8081:localhost:8081 -L 19999:localhost:19999 pi@<pi-ip>
   ```
