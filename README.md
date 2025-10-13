# 🏠 Homelab Automation Stack

A self-hosted automation platform that runs on Raspberry Pi 5 or macOS (Apple Silicon) using Docker Compose. Automate personal workflows through n8n, integrating with Telegram, Notion, Gmail, and local/remote LLMs.

## 🎯 Overview

This stack enables you to:

- 📱 Receive messages from Telegram and convert them to Notion tasks
- 📧 Scan Gmail daily and send AI-summarized emails to Telegram
- 🤖 Process content using local LLMs (Ollama) or OpenAI API
- 🔄 Run entirely containerized with persistent data
- 🔒 Maintain privacy with local-first operation

## 🏗️ Architecture

### Core Services

- **n8n** - Workflow automation orchestrator
- **PostgreSQL** - Persistent database for n8n
- **Ollama** - Local LLM API (Llama, Qwen, Mistral)
- **Tailscale** - Secure remote access (optional)
- **Redis** - Caching and rate limiting (optional)
- **Watchtower** - Automatic container updates (optional)

### Integrations

- **Telegram Bot API** - Input channel for messages and email summaries
- **Notion API** - Task storage and management
- **Gmail API** - Email scanning and processing
- **OpenAI API** - Fallback for higher quality LLM responses

## 🚀 Quick Start

### Prerequisites

- **Hardware**: Raspberry Pi 5 (16GB RAM recommended) or macOS with Apple Silicon
- **Software**: Docker & Docker Compose
- **Network**: Internet connection for initial setup

### 1. Clone and Setup

```bash
# Clone the repository
git clone <your-repo-url> homelab-stack
cd homelab-stack

# Run the setup script
./scripts/setup.sh
```

### 2. Configure Environment

Edit the `.env` file with your credentials:

```bash
# Copy and edit environment variables
cp .env.example .env
nano .env
```

Required credentials:

- `TELEGRAM_BOT_TOKEN` - Create bot via [@BotFather](https://t.me/BotFather)
- `NOTION_API_TOKEN` - Create integration at [Notion Developers](https://developers.notion.com)
- `NOTION_DATABASE_ID` - Database ID from your Notion workspace

Optional credentials:

- `GMAIL_*` - OAuth credentials for Gmail integration
- `OPENAI_API_KEY` - For fallback LLM processing
- `TAILSCALE_AUTH_KEY` - For secure remote access

### 3. Start Services

```bash
# Start all services
docker compose up -d

# Check status
./scripts/manage.sh status
```

### 4. Access n8n

1. Open http://localhost:5678
2. Login with credentials from `.env` file
3. Import workflow templates from `workflows/` folder

## 📋 Service Configuration

### n8n Workflows

Access n8n at `http://localhost:5678` and import these workflows:

1. **Telegram → Notion**: `workflows/telegram-to-notion.json`

   - Receives Telegram messages
   - Processes with local LLM
   - Creates structured Notion tasks

2. **Gmail → Telegram**: `workflows/gmail-to-telegram.json`
   - Daily scan of Gmail inbox
   - Analyzes emails with local LLM
   - Sends intelligent summaries to Telegram

### Notion Database Schema

Create a Notion database with these properties:

| Property    | Type   | Options                  |
| ----------- | ------ | ------------------------ |
| Title       | Title  | -                        |
| Description | Text   | -                        |
| Status      | Select | To Do, In Progress, Done |
| Priority    | Select | High, Medium, Low        |
| Source      | Select | Telegram, Gmail, Manual  |
| Created     | Date   | -                        |
| Due Date    | Date   | -                        |

### Telegram Bot Setup

1. Message [@BotFather](https://t.me/BotFather)
2. Create new bot: `/newbot`
3. Get token and add to `.env`
4. Set webhook in n8n workflow

### Gmail API Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Enable Gmail API
3. Create OAuth2 credentials
4. Add credentials to `.env`

## 🛠️ Management

### Daily Operations

```bash
# View service status
./scripts/manage.sh status

# View logs
./scripts/manage.sh logs
./scripts/manage.sh logs n8n

# Restart services
./scripts/manage.sh restart
```

### Backup & Restore

```bash
# Create backup
./scripts/manage.sh backup

# Restore from backup
./scripts/manage.sh restore backup_file.tar.gz

# List available backups
ls -la backups/
```

### Ollama Model Management

```bash
# List installed models
./scripts/manage.sh models

# Download specific model
./scripts/manage.sh pull llama3.1:8b

# Download all configured models
./scripts/setup.sh models
```

### Updates

```bash
# Update all container images
./scripts/manage.sh update

# Auto-updates (via Watchtower)
docker compose --profile watchtower up -d
```

## 🔧 Configuration

### Environment Variables

Key configuration options in `.env`:

```bash
# System
TIMEZONE=Europe/Warsaw
N8N_PORT=5678
OLLAMA_PORT=11434

# Security
N8N_ENCRYPTION_KEY=your-32-char-key
POSTGRES_PASSWORD=secure-password

# Models
OLLAMA_MODELS=llama3.1:8b,qwen2.5:7b

# Backup
BACKUP_RETENTION_DAYS=30
BACKUP_SCHEDULE=0 2 * * *
```

### Docker Compose Profiles

Enable optional services:

```bash
# Enable Tailscale
docker compose --profile tailscale up -d

# Enable Redis caching
docker compose --profile redis up -d

# Enable auto-updates
docker compose --profile watchtower up -d
```

### Resource Optimization

#### Raspberry Pi 5 (4GB RAM)

```bash
# Use smaller models
OLLAMA_MODELS=llama3.2:1b,qwen2.5:1.5b

# Limit PostgreSQL memory
# Add to docker-compose.yml postgres service:
command: postgres -c shared_buffers=128MB -c effective_cache_size=256MB
```

#### Raspberry Pi 5 (8GB RAM)

```bash
# Balanced models
OLLAMA_MODELS=llama3.1:8b,qwen2.5:7b,mistral:7b
```

#### Raspberry Pi 5 (16GB RAM) - Optimized Configuration

```bash
# High-performance models - can run multiple simultaneously
OLLAMA_MODELS=llama3.1:8b,qwen2.5:14b,codellama:13b,deepseek-coder:6.7b

# Ollama optimization for 16GB
OLLAMA_MAX_LOADED_MODELS=3
OLLAMA_NUM_PARALLEL=2

# PostgreSQL can use more memory
command: postgres -c shared_buffers=512MB -c effective_cache_size=4GB
```

#### Apple Silicon Mac

```bash
# Full models
OLLAMA_MODELS=llama3.1:8b,qwen2.5:14b,codellama:13b
```

## 🔐 Security

### Network Security

- All services run on internal Docker network
- Only n8n port exposed locally (5678)
- Optional Tailscale for secure remote access

### Data Protection

- PostgreSQL with encrypted connections
- n8n data encryption with `N8N_ENCRYPTION_KEY`
- No secrets in Docker images or logs

### Access Control

- n8n basic authentication
- Telegram bot token validation
- API key rotation recommended quarterly

## 🚨 Troubleshooting

### Common Issues

#### Services won't start

```bash
# Check Docker daemon
sudo systemctl status docker

# Check logs
./scripts/manage.sh logs

# Reset and restart
./scripts/manage.sh stop
./scripts/manage.sh start
```

#### Ollama model download fails

```bash
# Check available space
df -h

# Manually pull model
docker exec homelab-ollama ollama pull llama3.1:8b

# Check Ollama logs
docker logs homelab-ollama
```

#### n8n workflow errors

```bash
# Check n8n logs
./scripts/manage.sh logs n8n

# Verify environment variables
docker exec homelab-n8n env | grep -E "(TELEGRAM|NOTION|GMAIL)"

# Test API connections in n8n interface
```

#### Database connection issues

```bash
# Check PostgreSQL health
docker exec homelab-postgres pg_isready -U n8n

# Reset database (destructive!)
./scripts/manage.sh stop
docker volume rm homelab_postgres_data
./scripts/manage.sh start
```

### Performance Optimization

#### High memory usage

```bash
# Monitor resource usage
docker stats

# Use smaller Ollama models
# Reduce n8n execution history retention
# Add swap space on Pi
```

#### Slow LLM responses

```bash
# Check model size vs available RAM
./scripts/manage.sh models

# Switch to smaller/faster models
docker exec homelab-ollama ollama pull llama3.2:1b

# Use OpenAI API as fallback
```

## 📊 Monitoring

### Health Checks

```bash
# Overall health
./scripts/manage.sh health

# Service status
docker compose ps

# Resource usage
docker stats
```

### Logs

```bash
# All services
docker compose logs -f --tail=50

# Specific service
docker compose logs -f n8n

# Export logs
docker compose logs > homelab-logs.txt
```

## 🔄 Backup Strategy

### Automated Backups

- Daily backups via cron: `0 2 * * *`
- Retention: 30 days by default
- Includes: database, n8n data, Ollama models, configs

### Manual Backup

```bash
# Create immediate backup
./scripts/backup.sh

# Backup to external storage
BACKUP_UPLOAD_CMD="rclone copy" ./scripts/backup.sh
```

### Disaster Recovery

```bash
# Full restore from backup
./scripts/restore.sh backup_file.tar.gz

# Reset and reinstall
./scripts/manage.sh reset
./scripts/setup.sh
```

## 🚀 Extensions

### Adding New Integrations

1. **Discord Bot**

   ```bash
   # Add Discord credentials to .env
   DISCORD_BOT_TOKEN=your-token

   # Create n8n workflow with Discord trigger
   ```

2. **Home Assistant**

   ```bash
   # Add Home Assistant integration
   HOME_ASSISTANT_URL=http://homeassistant:8123
   HOME_ASSISTANT_TOKEN=your-token
   ```

3. **Additional LLM Providers**

   ```bash
   # Anthropic Claude
   ANTHROPIC_API_KEY=your-key

   # Google Gemini
   GOOGLE_AI_API_KEY=your-key
   ```

### Custom Workflows

Create new workflows in n8n for:

- Weather notifications
- Calendar management
- File organization
- IoT device control
- Social media monitoring

## 📚 Additional Resources

### Documentation

- [n8n Documentation](https://docs.n8n.io/)
- [Ollama Models](https://ollama.com/library)
- [Notion API](https://developers.notion.com/)
- [Telegram Bot API](https://core.telegram.org/bots/api)

### Community

- [n8n Community](https://community.n8n.io/)
- [Self-Hosted Alternatives](https://github.com/awesome-selfhosted/awesome-selfhosted)
- [Raspberry Pi Forums](https://www.raspberrypi.org/forums/)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-integration`
3. Test thoroughly on Pi 5 and macOS
4. Submit pull request with documentation

## 📄 License

MIT License - see LICENSE file for details.

## ⚠️ Disclaimer

This stack is designed for personal use. Ensure proper security measures before exposing to the internet. Regular backups and updates are recommended.
