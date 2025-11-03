# WiFi Connectivity Monitoring

Automated WiFi connectivity monitoring and recovery system for Raspberry Pi homelab environments.

## 🚀 Quick Start

### 1. Test the System

```bash
# Run comprehensive tests
./scripts/test-wifi-monitoring.sh full

# Quick connectivity test
./scripts/test-wifi-monitoring.sh quick
```

### 2. Start Monitoring

```bash
# Start the monitoring daemon
./scripts/wifi-monitor.sh start

# Or use the integrated management command
./scripts/manage.sh wifi-monitor-start
```

### 3. Check Status

```bash
# Check monitoring status
./scripts/manage.sh wifi-monitor-status

# View live logs
./scripts/wifi-monitor.sh logs-follow
```

## 📋 Features

### 🔍 **Continuous Monitoring**

- Multi-target connectivity testing (Cloudflare, Google, OpenDNS)
- Local network (gateway) connectivity verification
- Configurable check intervals and failure thresholds
- Smart recovery cooldown periods

### 🔧 **Automatic Recovery**

- **Soft Recovery**: Interface restart and reconnection
- **Hard Recovery**: NetworkManager service restart
- **Full Recovery**: Complete network stack reset
- Multiple recovery attempts with exponential backoff

### 📊 **Integration & Alerting**

- n8n webhook notifications for connectivity issues
- Structured logging for monitoring and debugging
- Prometheus metrics integration (planned)
- Systemd service for automatic startup

### 🛠️ **Management Tools**

- Interactive WiFi connection wizard
- Network scanning and connection management
- Configuration backup and restore
- Comprehensive diagnostics and troubleshooting

## 🔧 Installation & Setup

### Prerequisites

```bash
# Install NetworkManager (if not already installed)
sudo apt update
sudo apt install network-manager

# Ensure NetworkManager is running
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
```

### Quick Setup

```bash
# 1. Test the system
./scripts/test-wifi-monitoring.sh full

# 2. Start monitoring (foreground)
./scripts/wifi-monitor.sh start

# 3. Or install as a system service
sudo cp config/systemd/wifi-monitor.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable wifi-monitor
sudo systemctl start wifi-monitor
```

### Configuration

Environment variables in `/etc/systemd/system/wifi-monitor.service` or set before running:

```bash
# Monitoring intervals and thresholds
WIFI_MONITOR_INTERVAL=30        # Check every 30 seconds
WIFI_FAILURE_THRESHOLD=3        # Trigger recovery after 3 failures
WIFI_RECOVERY_COOLDOWN=300      # Wait 5 minutes between recoveries

# Debugging and alerts
WIFI_DEBUG=false                # Enable debug logging
N8N_WEBHOOK_URL=https://...     # Webhook for alerts (optional)
```

## 🎯 Usage Examples

### Basic Operations

```bash
# Show current WiFi status
./scripts/manage.sh wifi-status

# Scan for available networks
./scripts/manage.sh wifi-scan

# Connect to WiFi interactively
./scripts/manage.sh wifi-connect

# Perform manual recovery
./scripts/manage.sh wifi-recovery
```

### Advanced Management

```bash
# Backup WiFi configurations
./scripts/wifi-recovery.sh backup

# List saved connections
./scripts/wifi-recovery.sh list

# Remove saved connection
./scripts/wifi-recovery.sh forget "Old-Network"

# Run comprehensive diagnostics
./scripts/wifi-recovery.sh diagnostics
```

### Monitoring Operations

```bash
# Start/stop monitoring daemon
./scripts/wifi-monitor.sh start
./scripts/wifi-monitor.sh stop

# Check daemon status
./scripts/wifi-monitor.sh status

# View logs (last 50 lines)
./scripts/wifi-monitor.sh logs

# Follow logs in real-time
./scripts/wifi-monitor.sh logs-follow

# Test monitoring (5 cycles)
./scripts/wifi-monitor.sh test 5
```

## 📁 File Structure

```
scripts/
├── wifi-monitor.sh         # Main monitoring daemon
├── wifi-recovery.sh        # Manual recovery and management
├── test-wifi-monitoring.sh # Test suite
└── lib/
    └── wifi.sh            # WiFi management library

config/
├── wifi/                  # WiFi configuration and backups
│   ├── README.md         # Configuration documentation
│   ├── wifi-template.conf # Manual wpa_supplicant template
│   ├── backup/           # Automatic configuration backups
│   └── profiles/         # Network profile templates
└── systemd/
    ├── wifi-monitor.service # Systemd service definition
    └── README.md           # Service installation guide
```

## 🔍 Troubleshooting

### Common Issues

**WiFi monitoring not starting:**

```bash
# Check prerequisites
./scripts/test-wifi-monitoring.sh quick

# Verify NetworkManager
sudo systemctl status NetworkManager

# Check script permissions
chmod +x scripts/wifi-*.sh
```

**Recovery not working:**

```bash
# Manual recovery
./scripts/wifi-recovery.sh recovery-full

# Check WiFi hardware
lshw -C network

# Verify interface
ip link show
```

**Service installation issues:**

```bash
# Check service file paths
sudo nano /etc/systemd/system/wifi-monitor.service

# Update WorkingDirectory and ExecStart paths
# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart wifi-monitor
```

### Diagnostic Commands

```bash
# Complete system diagnostics
./scripts/wifi-recovery.sh diagnostics

# Test suite with different modes
./scripts/test-wifi-monitoring.sh connectivity
./scripts/test-wifi-monitoring.sh integration
./scripts/test-wifi-monitoring.sh full

# Check service logs
sudo journalctl -u wifi-monitor -f
```

## 🔐 Security Considerations

- Scripts require sudo privileges for network management
- WiFi passwords stored in NetworkManager's secure storage
- Service runs with security hardening (limited filesystem access)
- Configuration backups may contain sensitive connection details
- Use strong WPA2/WPA3 passwords for all networks

## 🛣️ Roadmap

### Planned Features

- **Prometheus Metrics**: WiFi connectivity metrics for Grafana dashboards
- **Multiple Network Profiles**: Quick switching between home/office/mobile setups
- **Emergency Hotspot Mode**: Automatic access point creation when WiFi fails
- **Mobile Failover**: Automatic switching to USB mobile dongles
- **Advanced Recovery**: Smart network priority and failover strategies

### Integration Goals

- Enhanced n8n workflow integration for network events
- Temperature correlation analysis (WiFi performance vs. thermal state)
- Automated network optimization based on usage patterns
- Remote management capabilities via Tailscale

## 📚 Related Documentation

- [Hardware Setup Guide](hardware-setup.md) - Raspberry Pi configuration
- [Monitoring Guide](monitoring.md) - Integration with Prometheus/Grafana
- [Tailscale Setup](tailscale-setup.md) - VPN and remote access setup
