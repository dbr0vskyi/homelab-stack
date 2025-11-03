# Systemd Service Installation Guide

## WiFi Monitor Service Setup

The WiFi monitor can be run as a systemd service for automatic startup and monitoring.

### Installation Steps

1. **Copy the service file:**

   ```bash
   sudo cp config/systemd/wifi-monitor.service /etc/systemd/system/
   ```

2. **Update the working directory path:**

   ```bash
   # Edit the service file to match your installation path
   sudo nano /etc/systemd/system/wifi-monitor.service

   # Change WorkingDirectory to your actual path:
   WorkingDirectory=/home/pi/homelab-stack  # or your path
   ExecStart=/home/pi/homelab-stack/scripts/wifi-monitor.sh start
   ExecStop=/home/pi/homelab-stack/scripts/wifi-monitor.sh stop
   ```

3. **Reload systemd and enable the service:**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable wifi-monitor.service
   sudo systemctl start wifi-monitor.service
   ```

### Service Management

```bash
# Check service status
sudo systemctl status wifi-monitor

# View service logs
sudo journalctl -u wifi-monitor -f

# Restart service
sudo systemctl restart wifi-monitor

# Stop service
sudo systemctl stop wifi-monitor

# Disable service (prevent auto-start)
sudo systemctl disable wifi-monitor
```

### Configuration

Environment variables can be configured in the service file:

- `WIFI_MONITOR_INTERVAL=30` - Check interval in seconds
- `WIFI_FAILURE_THRESHOLD=3` - Failures before recovery
- `WIFI_RECOVERY_COOLDOWN=300` - Seconds between recoveries
- `WIFI_DEBUG=false` - Enable debug logging

### Troubleshooting

1. **Service fails to start:**

   - Check file paths in service file
   - Verify script permissions: `chmod +x scripts/wifi-monitor.sh`
   - Check logs: `sudo journalctl -u wifi-monitor`

2. **Permission errors:**

   - Ensure scripts are owned by root or have proper sudo access
   - Check that log directories exist and are writable

3. **Network dependencies:**
   - Service waits for NetworkManager to be available
   - If using different network management, adjust dependencies in service file

### Security

The service includes security hardening:

- Runs with minimal privileges
- Protected filesystem access
- Resource limits to prevent abuse
- Restricted system access

For production deployments, review and adjust security settings as needed.
