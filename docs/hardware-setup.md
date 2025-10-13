# Hardware Setup Guide

## Raspberry Pi 5 Setup

### Hardware Requirements

**Minimum Configuration:**

- Raspberry Pi 5 (4GB RAM)
- 64GB MicroSD Card (Class 10, A2 rated)
- Official Pi 5 Power Supply (27W USB-C)
- Ethernet cable or Wi-Fi connection

**Recommended Configuration:**

- Raspberry Pi 5 (8GB RAM)
- 128GB+ MicroSD Card (SanDisk Extreme Pro)
- Official Pi 5 Active Cooler
- External SSD via USB 3.0 (for better performance)

**Optimal Configuration (This Guide):**

- Raspberry Pi 5 (16GB RAM) - Enables large AI models
- 256GB+ NVMe SSD with M.2 HAT or USB 3.0 adapter
- Official Pi 5 Active Cooler (essential for sustained workloads)
- Gigabit Ethernet connection (recommended for stability)
- Quality power supply with sufficient amperage

### Operating System Installation

1. **Download Raspberry Pi Imager**

   ```bash
   # macOS
   brew install --cask raspberry-pi-imager

   # Or download from https://rpi.org/imager
   ```

2. **Flash Raspberry Pi OS**

   - Use "Raspberry Pi OS (64-bit)"
   - Enable SSH in advanced options
   - Set username/password
   - Configure Wi-Fi if needed

3. **Initial Boot Setup**

   ```bash
   # SSH into Pi
   ssh pi@raspberrypi.local

   # Update system
   sudo apt update && sudo apt upgrade -y

   # Enable container features
   echo 'cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory' | sudo tee -a /boot/firmware/cmdline.txt

   # Reboot
   sudo reboot
   ```

### Docker Installation on Pi

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, then test
docker --version
docker compose version
```

### Performance Optimization

#### Memory Configuration for 16GB Pi 5

```bash
# Optimize GPU memory for AI workloads (reduce GPU allocation)
echo 'gpu_mem=32' | sudo tee -a /boot/firmware/config.txt

# Enable 64-bit mode and optimize memory management
echo 'arm_64bit=1' | sudo tee -a /boot/firmware/config.txt
echo 'arm_boost=1' | sudo tee -a /boot/firmware/config.txt

# Increase CMA memory for better large allocation handling
echo 'cma=512' | sudo tee -a /boot/firmware/cmdline.txt
```

#### Storage Optimization

```bash
# Move Docker data to external SSD (optional)
sudo systemctl stop docker
sudo mkdir -p /mnt/ssd/docker
sudo rsync -aP /var/lib/docker/ /mnt/ssd/docker/

# Configure Docker to use external storage
sudo nano /etc/docker/daemon.json
```

```json
{
  "data-root": "/mnt/ssd/docker",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

#### Swap Configuration for 16GB Pi

```bash
# With 16GB RAM, swap can be smaller but still useful for large models
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# Set CONF_SWAPSIZE=4096 (4GB swap for 16GB RAM)
sudo dphys-swapfile setup
sudo dphys-swapfile swapon

# Alternative: Create zram swap for better performance
sudo apt install zram-tools
echo 'ALGO=lz4' | sudo tee -a /etc/default/zramswap
echo 'PERCENT=25' | sudo tee -a /etc/default/zramswap  # 4GB zram
sudo systemctl enable zramswap
```

### Monitoring and Maintenance

#### Temperature Monitoring

```bash
# Check CPU temperature
vcgencmd measure_temp

# Monitor in real-time
watch -n 1 'vcgencmd measure_temp && cat /sys/class/thermal/thermal_zone0/temp'
```

#### System Resources

```bash
# Install htop for monitoring
sudo apt install htop

# Check disk usage
df -h

# Check memory usage
free -h

# Monitor Docker containers
docker stats
```

#### AI Workload Optimization (16GB Pi 5)

```bash
# CPU Governor for sustained performance
echo 'performance' | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Increase file descriptor limits for AI workloads
echo '* soft nofile 65536' | sudo tee -a /etc/security/limits.conf
echo '* hard nofile 65536' | sudo tee -a /etc/security/limits.conf

# Optimize network buffer sizes for better API performance
echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' | sudo tee -a /etc/sysctl.conf

# Apply changes
sudo sysctl -p
```

#### Docker Optimization for Large Models

```bash
# Configure Docker daemon for AI workloads
sudo nano /etc/docker/daemon.json
```

```json
{
  "data-root": "/mnt/ssd/docker",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  },
  "default-ulimits": {
    "memlock": {
      "Hard": -1,
      "Name": "memlock",
      "Soft": -1
    }
  },
  "max-concurrent-downloads": 6,
  "max-concurrent-uploads": 3,
  "storage-driver": "overlay2"
}
```

## macOS (Apple Silicon) Setup

### Prerequisites

**System Requirements:**

- macOS 12+ (Monterey or later)
- Apple Silicon Mac (M1, M2, M3)
- 8GB+ RAM (16GB recommended)
- 50GB+ available storage

### Docker Installation

1. **Install Docker Desktop**

   ```bash
   # Using Homebrew (recommended)
   brew install --cask docker

   # Or download from docker.com
   ```

2. **Configure Docker Desktop**

   - Open Docker Desktop
   - Go to Settings → Resources
   - Allocate 4-6GB RAM for containers
   - Enable "Use Rosetta for x86/amd64 emulation on Apple Silicon"

3. **Verify Installation**

   ```bash
   docker --version
   docker compose version

   # Test with hello-world
   docker run hello-world
   ```

### Performance Optimization

#### Resource Allocation

```bash
# Recommended Docker Desktop settings:
# - CPUs: 4-6 cores
# - Memory: 4-6 GB
# - Swap: 1 GB
# - Disk image size: 60+ GB
```

#### File Sharing Optimization

- Use consistent file sharing for better performance
- Avoid mounting large directories when possible
- Use named volumes instead of bind mounts for data

### Development Tools

```bash
# Install useful tools via Homebrew
brew install wget curl jq tree htop

# Install VS Code for editing
brew install --cask visual-studio-code

# Install terminal multiplexer
brew install tmux
```

## Network Configuration

### Local Network Setup

#### Static IP Configuration (Pi)

```bash
# Edit dhcpcd.conf
sudo nano /etc/dhcpcd.conf

# Add at the end:
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8
```

#### Hostname Configuration

```bash
# Set custom hostname
sudo hostnamectl set-hostname homelab-pi

# Update hosts file
sudo nano /etc/hosts
# Add: 127.0.1.1 homelab-pi
```

### Firewall Configuration

#### Raspberry Pi (UFW)

```bash
# Install and configure UFW
sudo apt install ufw

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow ssh

# Allow n8n (local only)
sudo ufw allow from 192.168.0.0/16 to any port 5678

# Allow Ollama (local only)
sudo ufw allow from 192.168.0.0/16 to any port 11434

# Enable firewall
sudo ufw enable
sudo ufw status
```

#### macOS Firewall

```bash
# Enable macOS firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Allow Docker Desktop
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Docker.app/Contents/MacOS/Docker\ Desktop
```

### Remote Access Setup

#### SSH Key Authentication

```bash
# Generate SSH key on your main machine
ssh-keygen -t ed25519 -C "homelab-access"

# Copy public key to Pi
ssh-copy-id pi@192.168.1.100

# Test passwordless login
ssh pi@192.168.1.100
```

#### SSH Hardening

```bash
# Edit SSH config on Pi
sudo nano /etc/ssh/sshd_config

# Recommended settings:
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
Port 22
Protocol 2
```

## Storage Configuration

### External Storage (Pi)

#### USB SSD Setup

```bash
# Check connected drives
lsblk

# Format drive (replace sdX with your drive)
sudo fdisk /dev/sdX
# Create partition, format as ext4

sudo mkfs.ext4 /dev/sdX1

# Create mount point
sudo mkdir -p /mnt/ssd

# Add to fstab for automatic mounting
echo '/dev/sdX1 /mnt/ssd ext4 defaults,noatime 0 2' | sudo tee -a /etc/fstab

# Mount drive
sudo mount -a
```

#### Docker Volume Location

```bash
# Move Docker volumes to external storage
sudo systemctl stop docker
sudo mkdir -p /mnt/ssd/homelab/volumes
sudo chown -R $USER:$USER /mnt/ssd/homelab

# Update docker-compose.yml volumes section:
volumes:
  postgres_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/ssd/homelab/volumes/postgres
```

### Backup Storage

#### Local Backup Drive

```bash
# Format backup drive
sudo mkdir -p /mnt/backup
echo '/dev/sdY1 /mnt/backup ext4 defaults,noatime 0 2' | sudo tee -a /etc/fstab

# Configure backup location in .env
BACKUP_LOCATION=/mnt/backup/homelab
```

#### Network Attached Storage

```bash
# Mount NAS for backups (example with SMB)
sudo apt install cifs-utils
sudo mkdir -p /mnt/nas

# Add to fstab
echo '//192.168.1.10/backup /mnt/nas cifs username=user,password=pass,uid=1000,gid=1000 0 0' | sudo tee -a /etc/fstab

# Mount
sudo mount -a
```

## Power Management

### Raspberry Pi Power Optimization

#### Power Supply Requirements

- Use official 27W USB-C power supply
- Ensure stable power (consider UPS for critical applications)
- Monitor under-voltage warnings

#### Power Monitoring

```bash
# Check power status
vcgencmd get_throttled

# Monitor power events in dmesg
dmesg | grep -i voltage
```

### UPS Configuration (Optional)

#### APC UPS with NUT

```bash
# Install Network UPS Tools
sudo apt install nut nut-client nut-server

# Configure for APC UPS
sudo nano /etc/nut/ups.conf
```

```ini
[apc]
    driver = usbhid-ups
    port = auto
    desc = "APC UPS"
```

## Security Hardening

### System Security

#### Automatic Updates

```bash
# Install unattended-upgrades
sudo apt install unattended-upgrades

# Configure automatic security updates
sudo dpkg-reconfigure -plow unattended-upgrades
```

#### Fail2Ban

```bash
# Install fail2ban for SSH protection
sudo apt install fail2ban

# Configure
sudo nano /etc/fail2ban/jail.local
```

```ini
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
```

### Container Security

#### Docker Security

```bash
# Run Docker in rootless mode (optional)
dockerd-rootless-setuptool.sh install

# Use non-root users in containers
# Check docker-compose.yml for user specifications
```

#### Regular Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update Docker images
docker compose pull
docker compose up -d --force-recreate

# Clean up unused resources (be careful with 16GB models)
docker system prune -af --volumes=false  # Keep volumes with large models
```

### Pi 5 16GB Specific Optimizations

#### Model Storage Optimization

```bash
# Create dedicated partition for AI models
sudo fdisk /dev/sda  # Create 100GB+ partition for models
sudo mkfs.ext4 /dev/sda1
sudo mkdir -p /mnt/models
echo '/dev/sda1 /mnt/models ext4 defaults,noatime 0 2' | sudo tee -a /etc/fstab
sudo mount -a

# Symlink Ollama models to fast storage
sudo systemctl stop docker
sudo mkdir -p /mnt/models/ollama
sudo ln -sf /mnt/models/ollama /var/lib/docker/volumes/homelab_ollama_data/_data
sudo systemctl start docker
```

#### Memory Management for Large Models

```bash
# Create optimized swap configuration
sudo dphys-swapfile swapoff
echo 'CONF_SWAPSIZE=8192' | sudo tee /etc/dphys-swapfile
echo 'CONF_SWAPFACTOR=2' | sudo tee -a /etc/dphys-swapfile
echo 'CONF_MAXSWAP=8192' | sudo tee -a /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon

# Optimize kernel parameters for large allocations
echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.dirty_ratio=15' | sudo tee -a /etc/sysctl.conf
echo 'vm.dirty_background_ratio=5' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

#### Performance Monitoring for AI Workloads

```bash
# Install AI-specific monitoring tools
sudo apt install nvtop htop iotop nethogs

# Create monitoring script for large models
cat > /home/pi/monitor-ai.sh << 'EOF'
#!/bin/bash
echo "=== AI Workload Monitor ==="
echo "Memory Usage:"
free -h | grep -E "(Mem|Swap)"
echo
echo "Ollama Models:"
curl -s http://localhost:11434/api/tags | jq '.models[].name' 2>/dev/null || echo "Ollama not available"
echo
echo "Docker Stats:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
echo
echo "Temperature:"
vcgencmd measure_temp
EOF

chmod +x /home/pi/monitor-ai.sh

# Add to crontab for regular monitoring
echo "*/5 * * * * /home/pi/monitor-ai.sh >> /var/log/ai-monitor.log" | sudo crontab -
```

## Troubleshooting Hardware Issues

### Common Pi Issues

#### SD Card Corruption

```bash
# Check filesystem
sudo fsck /dev/mmcblk0p2

# Monitor SD card health
sudo smartctl -a /dev/mmcblk0
```

#### Overheating

```bash
# Check temperature
vcgencmd measure_temp

# Reduce CPU frequency if needed
echo 'arm_freq=1000' | sudo tee -a /boot/firmware/config.txt
```

#### Memory Issues

```bash
# Check memory usage
free -h
cat /proc/meminfo

# Monitor OOM events
dmesg | grep -i "killed process"
```

### Performance Monitoring

#### System Monitoring Script

```bash
#!/bin/bash
# Save as monitor.sh

echo "=== System Status ==="
echo "Temperature: $(vcgencmd measure_temp)"
echo "Memory: $(free -h | grep Mem)"
echo "Disk: $(df -h / | tail -1)"
echo "Load: $(uptime | cut -d',' -f3-5)"
echo

echo "=== Docker Status ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

#### Automated Monitoring

```bash
# Add to crontab for regular monitoring
*/15 * * * * /home/pi/monitor.sh >> /var/log/homelab-monitor.log
```
