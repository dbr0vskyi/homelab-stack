# SSL Troubleshooting

## Quick Fixes

**Secure cookie error**: Use HTTPS or run `./scripts/setup.sh ssl`

**Certificate warnings**: Expected for self-signed certificates

**Can't access remotely**: Check N8N_HOST in .env matches access URL

## Commands

```bash
# Regenerate certificate
./scripts/setup.sh ssl

# Check certificate
openssl x509 -enddate -noout -in config/ssl/cert.pem

# View logs
docker compose logs n8n
```
