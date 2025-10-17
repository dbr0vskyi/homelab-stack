# Tailscale SSL Setup

Automatically get trusted HTTPS certificates through Tailscale.

## Quick Setup

1. **Install Tailscale** and enable MagicDNS
2. **Run setup**: `./scripts/setup.sh ssl` (auto-detects Tailscale)
3. **Access**: `https://your-machine.tailnet.ts.net`

## Find Your Domain

```bash
# Generate certificate
./scripts/setup.sh ssl
```

## Troubleshooting

### Common Issues

**Certificate fails**: Enable MagicDNS at [admin console](https://login.tailscale.com/admin/dns)  
**Not logged in**: Run `tailscale up`  
**Permission denied**: See "Certificate Permissions" below

### Certificate Permissions (Linux/Raspberry Pi)

On Linux systems, certificate generation may require elevated permissions:

#### Automatic Setup (Recommended)

The setup script will automatically try to configure permissions:

```bash
./scripts/setup.sh  # Automatically handles permissions
```

#### Manual Setup

If automatic setup fails, run manually:

```bash
# Set your user as Tailscale operator (one-time setup)
sudo tailscale set --operator=$USER

# Then regenerate certificates
./scripts/setup.sh ssl
```

#### Troubleshooting Permissions

If you see "Access denied: cert access denied":

1. **Run setup script** - it will automatically attempt to fix permissions
2. **Manual fix**: `sudo tailscale set --operator=$USER`
3. **Use sudo**: The script will fall back to using sudo automatically

````

## Advanced Configuration

### Custom Domain with Tailscale

If you have a custom domain configured in Tailscale:

1. **Set up custom domain** in Tailscale admin console
2. **Update N8N_HOST**:
   ```env
   N8N_HOST=homelab.yourdomain.com
````

3. **Regenerate certificate**:
   ```bash
   ./scripts/setup.sh ssl
   ```

### Multiple Subdomains

For multiple services with subdomains:

```bash
# Generate wildcard certificate
tailscale cert --cert-file config/ssl/cert.pem --key-file config/ssl/key.pem "*.your-tailnet.ts.net"
```

### Certificate Automation

Add to crontab for automatic renewal:

```bash
# Check and renew Tailscale certificate monthly
0 1 1 * * /path/to/your/homelab/scripts/setup.sh ssl && docker compose restart n8n
```

## Security Benefits

### Network Security

- **Zero Trust**: Only devices in your Tailscale network can access services
- **Encrypted**: All traffic encrypted with WireGuard
- **No port forwarding**: Services not exposed to internet
- **Per-device access**: Control which devices can access which services

### Certificate Security

- **CA-signed**: Certificates signed by Tailscale's CA
- **Short-lived**: Automatic rotation reduces risk
- **Device-specific**: Certificates tied to specific Tailscale devices
- **Revocable**: Instant revocation through Tailscale admin

## Comparison with Other Methods

| Method              | Trust Level         | Setup Complexity | Maintenance        | External Access           |
| ------------------- | ------------------- | ---------------- | ------------------ | ------------------------- |
| **Tailscale Certs** | ✅ Fully Trusted    | 🟢 Simple        | 🟢 Automatic       | 🔒 Tailscale Network Only |
| Let's Encrypt       | ✅ Fully Trusted    | 🟡 Moderate      | 🟡 Renewal Scripts | 🌐 Internet Accessible    |
| Self-signed         | ❌ Browser Warnings | 🟢 Simple        | 🟡 Manual Renewal  | 🌐 Any Network            |

## Example Workflow

1. **Install Tailscale** on your homelab machine
2. **Enable MagicDNS** in Tailscale admin console
3. **Update .env** with your Tailscale domain
4. **Run setup**: `./scripts/setup.sh ssl`
5. **Access from any device** in your Tailscale network: `https://homelab.your-tailnet.ts.net`

Perfect for secure, remote access to your homelab without exposing services to the internet! 🔒✨
