# WiFi Configuration Directory

This directory contains WiFi configuration files, templates, and backups for the homelab stack.

## Files and Structure

- `README.md` - This file
- `wifi-template.conf` - Template for manual wpa_supplicant configuration
- `backup/` - Directory for WiFi configuration backups
- `profiles/` - Predefined network profiles for common setups

## Usage

### Configuration Backups

WiFi configurations are automatically backed up when using the WiFi management scripts:

```bash
# Create backup
./scripts/wifi-recovery.sh backup

# Backups are stored as:
# config/wifi/wifi-backup-YYYYMMDD-HHMMSS.json
```

### Network Profiles

Network profiles can be created for common network setups (home, office, mobile hotspot, etc.) to enable quick switching between known configurations.

### Manual Configuration

If NetworkManager is not available, you can use the `wifi-template.conf` as a starting point for manual wpa_supplicant configuration.

## Integration

The WiFi management system integrates with:

- **Monitoring**: Prometheus metrics for connectivity status
- **Alerting**: n8n webhook notifications for connection issues
- **Logging**: Structured logs in `/var/log/homelab/`
- **Recovery**: Automatic recovery procedures for connection failures

## Security Notes

- WiFi passwords are stored in NetworkManager's secure storage
- Backup files may contain connection details - protect accordingly
- Use strong WPA2/WPA3 passwords for all networks
- Consider MAC address randomization for privacy
