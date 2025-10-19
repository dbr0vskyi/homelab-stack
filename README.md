# 🏠 Homelab Automation Stack

Self-hosted automation platform for Raspberry Pi 5/macOS. Automate workflows with n8n, Telegram, Notion, Gmail, and local LLMs.

## ✨ Features

- 📱 **Telegram → Notion**: Convert messages to tasks with AI processing
- 📧 **Gmail Summaries**: Daily email digests via Telegram
- 🤖 **Local LLMs**: Privacy-first AI processing with Ollama
- 🔄 **Containerized**: Fully dockerized with automated backups
- 🌐 **Secure Access**: Optional Tailscale integration

## 🛠️ Stack

- **n8n** - Workflow automation platform
- **PostgreSQL** - Reliable database backend
- **Ollama** - Local LLM inference
- **Tailscale** - Zero-trust network access (optional)

## 🚀 Quick Start

```bash
# 1. Clone repository
git clone <your-repo> homelab-stack && cd homelab-stack

# 2. Setup everything
./scripts/setup.sh

# 3. Configure APIs
cp .env.example .env
nano .env  # Add your tokens
```

**Required**: `TELEGRAM_BOT_TOKEN` from [@BotFather](https://t.me/BotFather)  
**Optional**: Notion and Gmail API tokens

**Access**: n8n at `https://localhost:8443`, Ollama at `http://localhost:11434`

## 📋 Management

```bash
./scripts/manage.sh status    # Check services
./scripts/manage.sh logs      # View logs  
./scripts/backup.sh          # Create backup
./scripts/setup.sh funnel    # Enable external webhooks
```

Run any script without arguments to see all options.

## 🔧 Hardware Recommendations

| Device | RAM | Models | Performance |
|--------|-----|--------|-------------|
| **Pi 5 4GB** | 4GB | `llama3.2:1b` | Basic automation |
| **Pi 5 8GB** | 8GB | `llama3.1:8b` | Good performance |
| **Pi 5 16GB** | 16GB | `qwen2.5:14b` | High performance |
| **Apple Silicon** | 8GB+ | Any models | Excellent |

## 📚 Documentation

- [🚀 **Setup Guide**](docs/setup-guide.md) - Complete installation walkthrough
- [🌐 **Tailscale Setup**](docs/tailscale-setup.md) - SSL certificates and external access  
- [🔗 **API Configuration**](docs/api-setup.md) - Telegram, Notion, Gmail setup
- [⚡ **Workflow Management**](docs/workflows.md) - Import/export and examples
- [🖥️ **Hardware Optimization**](docs/hardware-setup.md) - Platform-specific tuning

## 🚨 Troubleshooting

```bash
./scripts/manage.sh diagnose    # Full system check
./scripts/manage.sh restart     # Restart services
docker compose logs -f n8n      # View n8n logs
```

**Common Issues**: Port conflicts, SSL certificates, webhook setup → See setup guide

## 📄 License

MIT License - For personal use. Review security before internet exposure.