# Tailscale Setup Guide

Complete guide for Tailscale SSL certificates and Funnel integration.

## Quick Setup

1. **Install Tailscale** and enable MagicDNS
2. **Run setup**: `./scripts/setup.sh` (includes SSL and optional funnel)
3. **Access**: `https://your-machine.tailnet.ts.net`

## SSL Certificates

### Automatic Setup

```bash
# Setup SSL certificates (auto-detects Tailscale)
./scripts/setup.sh ssl
```

### Essential Commands

```bash
# Check Tailscale domain
tailscale status

# Check certificate
openssl x509 -enddate -noout -in config/ssl/cert.pem

# Restart services
docker compose restart n8n

# View logs
docker compose logs n8n
```

### SSL Troubleshooting

| Problem                      | Solution                                  |
| ---------------------------- | ----------------------------------------- |
| **Secure cookie error**      | Use HTTPS or run `./scripts/setup.sh ssl` |
| **Can't access from remote** | Enable Tailscale MagicDNS                 |
| **Certificate warnings**     | Expected for self-signed certificates     |
| **Can't access remotely**    | Check N8N_HOST in .env matches access URL |
| **Port 443 in use**          | `sudo lsof -i :443` and kill process      |

**Certificate fails**: Enable MagicDNS at [admin console](https://login.tailscale.com/admin/dns)  
**Not logged in**: Run `tailscale up`  
**Permission denied**: See "Certificate Permissions" below

### Certificate Permissions (Linux/Raspberry Pi)

The setup script automatically handles permissions. If manual setup is needed:

```bash
# Set your user as Tailscale operator (one-time setup)
sudo tailscale set --operator=$USER

# Then regenerate certificates
./scripts/setup.sh ssl
```

## Funnel Integration

### Overview

Tailscale funnel exposes your n8n instance to the public internet for external webhook integrations.

### Setup Commands

```bash
# Setup Tailscale funnel for n8n
./scripts/setup.sh funnel

# Stop Tailscale funnel
./scripts/setup.sh funnel-stop

# Check funnel status
./scripts/setup.sh funnel-status
```

### Configuration

- **External Port**: 443 (HTTPS)
- **Internal Port**: 8443 (n8n HTTP)
- **Protocol**: HTTPS termination at Tailscale, HTTP backend to n8n

### Webhook URLs

Once funnel is active:

- **Base URL**: `https://your-machine.tailnet.ts.net/`
- **Telegram Webhook**: `https://your-machine.tailnet.ts.net/webhook/telegram`
- **Generic Webhooks**: `https://your-machine.tailnet.ts.net/webhook/your-path`

### Telegram Webhook Setup

1. **Enable Funnel**: `./scripts/setup.sh funnel`
2. **Create n8n Workflow**: Add Webhook trigger with path `telegram`, method `POST`
3. **Configure Bot**:
   ```bash
   curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
     -H "Content-Type: application/json" \
     -d '{"url": "https://your-machine.tailnet.ts.net/webhook/telegram"}'
   ```

### Funnel Troubleshooting

**Funnel Not Starting**:

- Check connection: `tailscale status`
- Ensure funnel enabled in tailnet settings
- Verify n8n running: `docker ps`

**Webhook 404 Errors**:

- Create and activate webhook workflow in n8n
- Check webhook path matches n8n configuration
- Verify workflow is saved and active

**Connection Issues**:

- Test local: `curl -I http://localhost:8443/healthz`
- Test funnel: `curl -I https://your-machine.tailnet.ts.net/healthz`
- Check status: `./scripts/setup.sh funnel-status`

## Security Considerations

### SSL Security

- **Zero Trust**: Only Tailscale network devices can access
- **Encrypted**: WireGuard encryption for all traffic
- **CA-signed**: Certificates signed by Tailscale's CA
- **Device-specific**: Certificates tied to specific devices

### Funnel Security

- **Public Exposure**: Funnel exposes n8n to the internet
- **Authentication**: Ensure n8n has proper auth enabled
- **Webhook Auth**: Consider webhook authentication in workflows
- **Monitoring**: Monitor access logs for suspicious activity

## Architecture

### SSL Only (Network Access)

```
Tailscale Device → Tailscale SSL (HTTPS:8443) → n8n → Workflows
```

### SSL + Funnel (Internet Access)

```
Internet → Tailscale Funnel (HTTPS:443) → n8n (HTTP:8443) → Workflows
```

## Prerequisites

- Tailscale installed and connected
- MagicDNS enabled in Tailscale admin console
- n8n running on port 8443
- Funnel feature enabled in tailnet (for external access)

## Advanced Configuration

### Custom Domain

1. Set up custom domain in Tailscale admin console
2. Update `.env`: `N8N_HOST=homelab.yourdomain.com`
3. Regenerate certificate: `./scripts/setup.sh ssl`

### Certificate Automation

```bash
# Monthly certificate renewal
0 1 1 * * /path/to/homelab/scripts/setup.sh ssl && docker compose restart n8n
```

Perfect for secure homelab access with optional public webhook support! 🔒✨
