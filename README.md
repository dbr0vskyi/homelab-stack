# 🏠 Homelab Automation Stack

Self-hosted automation platform for Raspberry Pi 5/macOS. Automate workflows with n8n, Telegram, Notion, Gmail, and local LLMs.

## ✨ What it does

- 📱 Telegram → Notion tasks with AI processing
- 📧 Gmail summaries → Telegram notifications
- 🤖 Local LLM processing (privacy-first)
- 🔄 Fully containerized with backups

## 🛠️ Stack

- **n8n** - Workflow automation
- **PostgreSQL** - Database
- **Ollama** - Local LLMs
- **Tailscale** - Secure access (optional)

## � Prerequisites

- **Docker** & **Docker Compose**
- **jq** (for Tailscale integration - optional)

### Install jq

```bash
# macOS
brew install jq

# Debian/Ubuntu/Raspberry Pi OS
sudo apt update && sudo apt install -y jq

# Red Hat/Fedora
sudo dnf install jq
```

## �🚀 Quick Start

```bash
# 1. Clone and setup
git clone <your-repo> homelab-stack && cd homelab-stack
./scripts/setup.sh

# 2. Configure environment
cp .env.example .env
nano .env  # Add your API tokens

# 3. Start services
docker compose up -d
```

### Required API Keys

- `TELEGRAM_BOT_TOKEN` - [@BotFather](https://t.me/BotFather)
- `NOTION_API_TOKEN` - [Notion Developers](https://developers.notion.com)
- `NOTION_DATABASE_ID` - Your Notion database

### Access

- **n8n**: http://localhost:5678
- **Ollama**: http://localhost:11434

## 🛠️ Available Scripts

The homelab stack includes several management scripts for easy operation:

| Script                | Purpose                          | Examples                             |
| --------------------- | -------------------------------- | ------------------------------------ |
| `setup.sh`            | Initial setup and configuration  | `./scripts/setup.sh`                 |
| `manage.sh`           | Daily operations and maintenance | `./scripts/manage.sh status`         |
| `backup.sh`           | Create system backups            | `./scripts/backup.sh`                |
| `restore.sh`          | Restore from backups             | `./scripts/restore.sh backup.tar.gz` |
| `tailscale-helper.sh` | Tailscale configuration helper   | `./scripts/tailscale-helper.sh`      |

Run any script without arguments to see available options.

## 📋 Management

### Daily Operations

```bash
# Check service status and health
./scripts/manage.sh status
./scripts/manage.sh health

# View logs
./scripts/manage.sh logs           # All services
./scripts/manage.sh logs n8n       # Specific service

# Service control
./scripts/manage.sh start          # Start services
./scripts/manage.sh stop           # Stop services
./scripts/manage.sh restart        # Restart services
```

### Backup & Restore

```bash
# Create backup
./scripts/backup.sh

# Restore from backup
./scripts/restore.sh <backup.tar.gz>
```

### AI Model Management

```bash
# List available models
./scripts/manage.sh models

# Download specific model
./scripts/manage.sh pull llama3.1:8b

# Restore models from backup
./scripts/manage.sh restore-models models.txt
```

### Workflow Management

```bash
# Import workflow files to n8n (cross-environment compatible)
./scripts/manage.sh import-workflows

# Export n8n workflows to files (for version control)
./scripts/manage.sh export-workflows
```

### Diagnostics

```bash
# Full system diagnostic
./scripts/manage.sh diagnose

# Specific diagnostics
./scripts/manage.sh diagnose system      # System info
./scripts/manage.sh diagnose database   # Database analysis
./scripts/manage.sh diagnose n8n        # n8n functionality
./scripts/manage.sh diagnose summary    # Quick overview

# Direct diagnostic access
./scripts/diagnose-universal.sh help    # All diagnostic modes
```

### Maintenance

```bash
# Update all container images
./scripts/manage.sh update

# Clean unused Docker resources
./scripts/manage.sh clean

# Reset all data (destructive!)
./scripts/manage.sh reset
```

## 🔧 Configuration

### Hardware Optimization

**Pi 5 4GB**: Use `llama3.2:1b,qwen2.5:1.5b` models  
**Pi 5 8GB**: Use `llama3.1:8b,qwen2.5:7b` models  
**Pi 5 16GB**: Use `qwen2.5:14b,codellama:13b` models  
**Apple Silicon**: Any models work

### Environment Variables

```bash
TIMEZONE=Europe/Warsaw
N8N_PORT=5678
OLLAMA_MODELS=llama3.1:8b,qwen2.5:7b
OLLAMA_MAX_LOADED_MODELS=3
```

### Optional Services

```bash
docker compose --profile tailscale up -d    # Secure access
docker compose --profile redis up -d        # Caching
docker compose --profile watchtower up -d   # Auto-updates
```

## 🚨 Troubleshooting

### Common Issues

```bash
# Quick system check
./scripts/manage.sh diagnose summary

# Services won't start
./scripts/manage.sh diagnose system
./scripts/manage.sh restart

# n8n workflow import/export issues
./scripts/manage.sh diagnose n8n
./scripts/manage.sh import-workflows

# Database connectivity
./scripts/manage.sh diagnose database

# Full diagnostic report
./scripts/manage.sh diagnose > diagnostic.log
```

### Performance

```bash
# Monitor resources
docker stats

# Use smaller models for low memory
# Add swap space on Pi: sudo dphys-swapfile setup
```

## 📋 Documentation

- [🗺️ Roadmap & TODOs](docs/roadmap.md) - Planned improvements and features
- [SSL Setup Guide](docs/ssl-troubleshooting.md)
- [Tailscale Setup](docs/tailscale-ssl-setup.md)
- [Hardware Guide](docs/hardware-setup.md)
- [API Setup](docs/api-setup.md)
- [Workflows](docs/workflows.md)

## 📄 License

MIT License - Personal use. Ensure security before internet exposure.
