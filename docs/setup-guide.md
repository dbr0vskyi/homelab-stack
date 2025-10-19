# Setup Guide

Complete installation and configuration guide for the homelab automation stack.

## 📋 Prerequisites

- **Hardware**: Raspberry Pi 4/5 (4GB+ RAM) or equivalent Linux system
- **OS**: Ubuntu/Debian-based system with Docker support
- **Network**: Internet connection for downloads

## 🔧 Installation Steps

### 1. System Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Logout and login again to apply group changes
```

### 2. Project Setup

````bash
# Clone repository
git clone <repository-url>
cd homelab-stack

# Run automated setup
./scripts/setup.sh

# Or step-by-step setup
./scripts/setup.sh prereq    # Check prerequisites
./scripts/setup.sh env       # Setup environment
./scripts/setup.sh ssl       # Setup SSL certificates
./scripts/setup.sh services  # Start services
./scripts/setup.sh models    # Download AI models
```### 3. API Configuration

Edit `.env` file with your API tokens:

```bash
# Telegram Bot (required)
TELEGRAM_BOT_TOKEN=your-bot-token

# Notion API (optional)
NOTION_API_TOKEN=your-notion-token
NOTION_DATABASE_ID=your-database-id

# Gmail API (optional)
GMAIL_CLIENT_ID=your-gmail-client-id
GMAIL_CLIENT_SECRET=your-gmail-secret
````

### 4. Access Services

- **n8n**: `https://localhost:8443` (or your Tailscale domain)
- **Ollama**: `http://localhost:11434`

## 🌐 Tailscale Integration (Optional)

### SSL Certificates

```bash
# Install Tailscale first
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Enable MagicDNS in Tailscale admin console
# Then run SSL setup
./scripts/setup.sh ssl
```

### External Access (Funnel)

```bash
# Enable public webhook access
./scripts/setup.sh funnel

# Your services will be available at:
# https://your-machine.tailnet.ts.net/
```

## 🤖 API Setup

### Telegram Bot

1. Message [@BotFather](https://t.me/BotFather)
2. Send `/newbot` → Name your bot → Save token
3. Add to `.env`: `TELEGRAM_BOT_TOKEN=your-token`

### Notion API

1. Go to [Notion Developers](https://developers.notion.com/)
2. Create integration → Save token
3. Create database with properties:
   - **Title** (Title)
   - **Description** (Text)
   - **Status** (Select: To Do, In Progress, Done)
   - **Priority** (Select: High, Medium, Low)
   - **Source** (Select: Telegram, Gmail, Manual)
4. Share database with integration
5. Add to `.env`: `NOTION_API_TOKEN=token` and `NOTION_DATABASE_ID=id`

## 📱 Workflow Setup

### Import Workflows

```bash
# Import pre-built workflows
./scripts/manage.sh import-workflows
```

### Create Webhook Workflows

1. Open n8n web interface
2. Create new workflow
3. Add **Webhook** trigger node:
   - **Path**: `telegram` (for Telegram webhooks)
   - **Method**: `POST`
   - **Authentication**: `None`
4. Add processing nodes (AI, Notion, etc.)
5. **Save and Activate** workflow

### Configure Telegram Webhook

```bash
# Set webhook URL (replace BOT_TOKEN and domain)
curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://your-domain/webhook/telegram"}'
```

## 🔧 Management Commands

```bash
# Check status and logs
./scripts/manage.sh status
./scripts/manage.sh logs

# Backup and restore
./scripts/backup.sh
./scripts/restore.sh <backup-file>

# External access (Tailscale required)
./scripts/setup.sh funnel
```

Run any script without arguments to see all available options.

## 🛠️ Troubleshooting

### Common Issues

| Problem                      | Solution                                        |
| ---------------------------- | ----------------------------------------------- |
| **Can't access n8n**         | Check if services running: `docker ps`          |
| **SSL certificate warnings** | Use `./scripts/setup.sh ssl` for trusted certs  |
| **Telegram webhook 404**     | Create and activate webhook workflow in n8n     |
| **Out of memory**            | Reduce Ollama model size or increase RAM        |
| **Funnel not working**       | Check Tailscale connection and tailnet settings |

### Diagnostics

```bash
# Full system check
./scripts/manage.sh diagnose

# View logs
docker compose logs -f n8n

# Check Tailscale
tailscale status
```

## 🎯 Next Steps

1. **Test Workflows**: Send a message to your Telegram bot
2. **Monitor Performance**: Check system resources and logs
3. **Set Up Backups**: Schedule regular backups
4. **Security Review**: Enable authentication and monitor access

For advanced topics, see specialized documentation files.
