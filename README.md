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
./scripts/manage.sh status       # Check services
./scripts/manage.sh logs         # View logs
./scripts/manage.sh exec-latest  # Show workflow executions
./scripts/backup.sh             # Create backup
./scripts/setup.sh funnel       # Enable external webhooks
```

Run any script without arguments to see all options.

## 🔧 Hardware Recommendations

**This project uses a Raspberry Pi 5 with 16GB RAM** - ideal for running larger models like qwen2.5:14b.

| Device            | RAM  | Models        | Performance      |
| ----------------- | ---- | ------------- | ---------------- |
| **Pi 5 4GB**      | 4GB  | `llama3.2:1b` | Basic automation |
| **Pi 5 8GB**      | 8GB  | `llama3.1:8b` | Good performance |
| **Pi 5 16GB** ⭐   | 16GB | `qwen2.5:14b` to `qwen2.5:32b` | High performance (current setup) |
| **Apple Silicon** | 8GB+ | Any models    | Excellent        |

## 📚 Documentation

- [🚀 **Setup Guide**](docs/setup-guide.md) - Complete installation walkthrough
- [🌐 **Tailscale Setup**](docs/tailscale-setup.md) - SSL certificates and external access
- [🔗 **API Configuration**](docs/api-setup.md) - Telegram, Notion, Gmail setup
- [⚡ **Workflow Management**](docs/workflows.md) - Import/export and examples
- [🖥️ **Hardware Optimization**](docs/hardware-setup.md) - Platform-specific tuning

## � Long-Running LLM Calls

This stack includes a timeout patch to enable AI Agent nodes with long-running LLM calls (>5 minutes). The default Node.js and undici timeouts are too restrictive for complex AI processing.

**Solution Applied**: [n8n-timeout-patch](https://github.com/Piggeldi2013/n8n-timeout-patch) by [@Piggeldi2013](https://github.com/Piggeldi2013)

**How it works**:

- Patches Node.js HTTP server timeouts (inbound requests)
- Configures undici global dispatcher (outbound API calls to LLMs)
- Preloaded via `NODE_OPTIONS=--require /patch/patch-http-timeouts.js`

**Timeout Configuration**:

- **Workflow execution**: 6 hours (`N8N_WORKFLOW_TIMEOUT=21600`)
- **LLM headers response**: 30 minutes (`FETCH_HEADERS_TIMEOUT=1800000`)
- **LLM body streaming**: 3.33 hours (`FETCH_BODY_TIMEOUT=12000000`)

**Files**:

- `config/n8n/patch-http-timeouts.js` - Timeout patch script
- Environment variables in `docker-compose.yml` - Timeout configuration

**Verification**: Check logs for `[patch] undici dispatcher set` and `[patch] http server timeouts` messages.

## �🚨 Troubleshooting

```bash
./scripts/manage.sh diagnose    # Full system check
./scripts/manage.sh restart     # Restart services
docker compose logs -f n8n      # View n8n logs
```

**Common Issues**: Port conflicts, SSL certificates, webhook setup → See setup guide

## 📄 License

MIT License - For personal use. Review security before internet exposure.
