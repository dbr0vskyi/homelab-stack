# 📁 Project Structure

## Directory Overview

```
homelab-stack/
├── 📋 README.md                    # Main documentation and setup guide
├── 📋 CHANGELOG.md                 # Version history and changes
├── 📋 LICENSE                      # MIT license file
├── 📋 Makefile                     # Convenient management commands
├── 🚀 quick-start.sh              # Interactive setup script
├── 📋 .env.example                 # Environment template
├── 📋 .gitignore                   # Git ignore patterns
├── 🐳 docker-compose.yml           # Main service definitions
│
├── 📂 config/                      # Service configurations
│   ├── 📂 postgres/
│   │   └── init.sql               # PostgreSQL initialization
│   ├── 📂 redis/
│   │   └── redis.conf             # Redis configuration
│   ├── 📂 tailscale/
│   │   └── tailscale.json         # Tailscale serve configuration
│   └── 📂 ollama/
│       └── models.txt             # List of models to download
│
├── 📂 scripts/                     # Management and utility scripts
│   ├── 🛠️ setup.sh                # Initial setup and configuration
│   ├── 🛠️ manage.sh               # Service management operations
│   ├── 💾 backup.sh               # Automated backup creation
│   └── 📥 restore.sh              # Backup restoration
│
├── 📂 workflows/                   # n8n workflow templates
│   ├── telegram-to-notion.json    # Telegram → LLM → Notion automation
│   └── gmail-to-telegram.json     # Gmail → LLM → Telegram automation
│
├── 📂 docs/                        # Detailed documentation
│   ├── api-setup.md              # API configuration guide
│   └── hardware-setup.md         # Hardware and OS setup guide
│
└── 📂 backups/                     # Backup storage directory
    └── (backup files created here)
```

## Core Files Description

### 🐳 Docker Configuration

- **`docker-compose.yml`** - Defines all services (n8n, PostgreSQL, Ollama, etc.)
- **`.env.example`** - Template with all required environment variables
- **`config/`** - Service-specific configuration files

### 🛠️ Management Scripts

- **`scripts/setup.sh`** - Automated setup with password generation
- **`scripts/manage.sh`** - Daily operations (start, stop, backup, etc.)
- **`scripts/backup.sh`** - Creates compressed backups of all data
- **`scripts/restore.sh`** - Restores from backup files
- **`quick-start.sh`** - Interactive guided setup experience

### 🤖 Automation Workflows

- **`workflows/telegram-to-notion.json`** - Processes Telegram messages with LLM and creates Notion tasks
- **`workflows/gmail-to-telegram.json`** - Scans Gmail and sends AI summaries to Telegram

### 📚 Documentation

- **`README.md`** - Comprehensive setup and usage guide
- **`docs/api-setup.md`** - Step-by-step API configuration
- **`docs/hardware-setup.md`** - Pi 5 and macOS hardware setup
- **`CHANGELOG.md`** - Version history and updates

## Key Features

### 🏗️ Architecture

- **Containerized Services**: Everything runs in Docker containers
- **ARM64 Compatible**: Optimized for Raspberry Pi 5 and Apple Silicon
- **Persistent Storage**: Named volumes for data persistence
- **Internal Networking**: Secure communication between services
- **Health Monitoring**: Built-in health checks for all services

### 🔧 Configuration Management

- **Environment Variables**: All secrets in `.env` file
- **Service Profiles**: Optional services (Tailscale, Redis, Watchtower)
- **Resource Optimization**: Different configs for Pi vs Mac
- **Security Hardening**: No exposed ports except n8n interface

### 🛡️ Security Features

- **Local-First**: No external dependencies by default
- **Encrypted Storage**: PostgreSQL and n8n data encryption
- **Access Control**: Basic auth for n8n, API token validation
- **Network Isolation**: Services communicate via internal network
- **Optional Remote Access**: Secure Tailscale integration

### 📊 Monitoring & Maintenance

- **Health Checks**: Automatic service health monitoring
- **Log Management**: Centralized logging with rotation
- **Backup System**: Automated daily backups with retention
- **Update Management**: Optional Watchtower for auto-updates
- **Resource Monitoring**: Built-in Docker stats and metrics

## Getting Started

### Quick Start (5 minutes)

```bash
# Clone and run interactive setup
curl -fsSL https://raw.githubusercontent.com/your-repo/homelab-stack/main/quick-start.sh | bash
```

### Manual Setup

```bash
# Clone repository
git clone https://github.com/your-repo/homelab-stack
cd homelab-stack

# Run setup
./scripts/setup.sh

# Start services
docker compose up -d

# Check status
make status
```

### Using Makefile Commands

```bash
# Common operations
make help          # Show all available commands
make start         # Start all services
make status        # Show service status
make logs          # View logs
make backup        # Create backup
make update        # Update containers

# Configuration
make config        # Edit .env file
make env           # Show current config (hides secrets)

# Model management
make models        # List Ollama models
make pull-model MODEL=llama3.1:8b  # Download specific model
```

## Service URLs

Once running, access these services:

- **n8n Automation**: `http://localhost:5678`
- **Ollama API**: `http://localhost:11434`
- **PostgreSQL**: `localhost:5432` (internal only)

## Workflow Templates

### Telegram → Notion Automation

1. Receives messages from Telegram bot
2. Processes text with local LLM (Ollama)
3. Extracts task information (title, priority, due date)
4. Creates structured Notion database entry
5. Sends confirmation back to Telegram

### Gmail → Telegram Daily Scan

1. Scheduled daily execution (8 AM)
2. Scans Gmail for unread important emails
3. Processes each email with LLM for intelligent summarization
4. Sends formatted summaries directly to Telegram
5. Provides daily summary with email count and priorities

## Customization

### Adding New Integrations

1. **Add credentials to `.env`**
2. **Create n8n workflow** using the web interface
3. **Export workflow** to `workflows/` directory
4. **Document setup** in `docs/api-setup.md`

### Resource Optimization

- **Pi 4GB**: Use lightweight models (1B parameters)
- **Pi 8GB**: Balanced models (7B parameters)
- **Pi 16GB**: High-performance models (up to 14B parameters, multiple models)
- **Mac Mini/Studio**: Full models (13B+ parameters)
- **External Storage**: Move Docker volumes to SSD for better performance

### Security Hardening

- **Firewall Rules**: Limit port access to local network
- **SSH Keys**: Disable password authentication
- **API Keys**: Rotate quarterly, monitor usage
- **Updates**: Enable Watchtower or manual monthly updates

## Troubleshooting

### Common Issues

1. **Services won't start**: Check Docker daemon, logs, disk space
2. **Model download fails**: Check internet, disk space, Ollama logs
3. **API errors**: Verify tokens, check service logs, test endpoints
4. **Performance issues**: Monitor resources, use smaller models

### Getting Help

1. **Check logs**: `make logs` or `docker compose logs -f`
2. **Verify config**: `make env` to check environment
3. **Health status**: `make health` for service health
4. **Documentation**: Review `docs/` folder for detailed guides

## Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-integration`
3. Test on both Pi and macOS
4. Update documentation
5. Submit pull request

## License

MIT License - see `LICENSE` file for details.

---

**Ready to get started?** Run the quick-start script or follow the README setup guide!
