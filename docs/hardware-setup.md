# Hardware Setup Guide

## 🖥️ Raspberry Pi 5 Setup

### Hardware Requirements

**Minimum (4GB RAM):**
- Raspberry Pi 5 4GB + 64GB SD card
- Official power supply + cooling
- Use small models: `llama3.2:1b,qwen2.5:1.5b`

**Recommended (8GB RAM):**
- Raspberry Pi 5 8GB + 128GB SD card  
- Active cooler + Ethernet connection
- Use medium models: `llama3.1:8b,qwen2.5:7b`

**Optimal (16GB RAM):**
- Raspberry Pi 5 16GB + 256GB NVMe SSD
- M.2 HAT or USB 3.0 SSD adapter
- Use large models: `qwen2.5:14b,codellama:13b`

### OS Installation

1. Download [Raspberry Pi Imager](https://www.raspberrypi.org/software/)
2. Flash **Raspberry Pi OS Lite (64-bit)**
3. Enable SSH in advanced options
4. Boot and SSH: `ssh pi@<ip-address>`

### Initial Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo systemctl enable docker

# Reboot
sudo reboot
```

### Performance Tuning

```bash
# Add to /boot/firmware/config.txt
gpu_mem=16              # Minimal GPU memory  
arm_64bit=1             # Enable 64-bit mode
dtparam=pcie=on         # Enable PCIe for NVMe
```

## 🍎 macOS Setup

### Requirements
- Apple Silicon Mac (M1/M2/M3)
- macOS 12+ with Docker Desktop
- 16GB+ RAM recommended

### Installation

```bash
# Install Docker Desktop
brew install --cask docker

# Or download from docker.com
```

## 🔧 Resource Optimization

### Memory Configuration

Edit `.env` for your hardware:

```bash
# 4GB Pi - Conservative
OLLAMA_MAX_LOADED_MODELS=1
OLLAMA_NUM_PARALLEL=1

# 8GB Pi - Balanced  
OLLAMA_MAX_LOADED_MODELS=2
OLLAMA_NUM_PARALLEL=1

# 16GB Pi - Aggressive
OLLAMA_MAX_LOADED_MODELS=3
OLLAMA_NUM_PARALLEL=2
```

### Storage Setup (Pi 5)

**For NVMe SSD:**
```bash
# Install M.2 HAT, then move Docker to SSD
sudo systemctl stop docker
sudo mv /var/lib/docker /mnt/ssd/docker
sudo ln -s /mnt/ssd/docker /var/lib/docker
sudo systemctl start docker
```

**Add Swap (if needed):**
```bash
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile  # Set CONF_SWAPSIZE=4096
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

## ✅ Verification

```bash
# Check Docker
docker --version
docker compose --version

# Test resource limits
docker run --rm alpine:latest free -h
```