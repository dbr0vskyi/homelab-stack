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

## 🚀 Quick Start

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

## 📋 Management

```bash
# Status and logs
./scripts/manage.sh status
./scripts/manage.sh logs [service]

# Service control
./scripts/manage.sh start|stop|restart

# Backups
./scripts/manage.sh backup
./scripts/manage.sh restore <backup.tar.gz>

# Models
./scripts/manage.sh models
./scripts/manage.sh pull <model>

# Updates
./scripts/manage.sh update
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
# Services won't start
./scripts/manage.sh logs
./scripts/manage.sh restart

# Ollama model issues
docker exec homelab-ollama ollama pull llama3.1:8b
./scripts/manage.sh models

# n8n workflow errors
./scripts/manage.sh logs n8n
# Check API tokens in .env

# Database issues
docker exec homelab-postgres pg_isready -U n8n

# SSL/HTTPS issues
./scripts/setup.sh ssl
docker compose restart n8n
```

### Performance

```bash
# Monitor resources
docker stats

# Use smaller models for low memory
# Add swap space on Pi: sudo dphys-swapfile setup
```

## � Documentation

- [SSL Setup Guide](docs/ssl-troubleshooting.md)
- [Tailscale Setup](docs/tailscale-ssl-setup.md)
- [Hardware Guide](docs/hardware-setup.md)
- [API Setup](docs/api-setup.md)

## 📄 License

MIT License - Personal use. Ensure security before internet exposure.
