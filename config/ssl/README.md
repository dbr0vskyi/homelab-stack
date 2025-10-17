# SSL Certificate Setup

SSL certificates are automatically generated when you run `./scripts/setup.sh ssl`.

## Quick Setup

```bash
# Auto-detects Tailscale or generates self-signed certificate
./scripts/setup.sh ssl
```

The script automatically:

- 🔍 **Detects Tailscale** and uses your domain (recommended)
- 🔧 **Falls back** to self-signed certificate for localhost
- 🔒 **Sets proper permissions** and handles renewal

## Certificate Types

**Tailscale (Recommended)** - Fully trusted, zero config

## Files

- `cert.pem` - SSL certificate
- `key.pem` - Private key

## Manual Certificate Setup

Replace auto-generated certificates:

```bash
# Stop services
docker compose down

# Replace certificates
cp your-certificate.pem cert.pem
cp your-private-key.pem key.pem
chmod 644 cert.pem && chmod 600 key.pem

# Restart
docker compose up -d
```

```

```

3. **Update environment** (if needed):

   ```bash
   # Update N8N_HOST in .env to match your certificate
   N8N_HOST=yourdomain.com
   ```

4. **Restart services**:
   ```bash
   docker compose up -d
   ```

## Security Notes

- Keep private keys secure (600 permissions)
- Regularly renew certificates (Let's Encrypt expires every 90 days)
- Use strong encryption (4096-bit RSA or ECDSA)
- Consider using a certificate monitoring service
