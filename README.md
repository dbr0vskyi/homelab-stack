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
- **Prometheus + Grafana** - Monitoring and thermal tracking
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
./scripts/manage.sh status          # Check services
./scripts/manage.sh logs            # View logs
./scripts/manage.sh exec-latest     # Show workflow executions
./scripts/backup.sh                 # Create backup

# Monitoring commands (included by default)
./scripts/manage.sh monitoring-*    # Monitoring management commands

# External access
./scripts/setup.sh funnel          # Enable external webhooks
```

Run any script without arguments to see all options.

## 🔧 Hardware Recommendations

**This project uses a Raspberry Pi 5 with 16GB RAM** - ideal for running larger models like qwen2.5:14b.

| Device            | RAM  | Models                         | Performance                      |
| ----------------- | ---- | ------------------------------ | -------------------------------- |
| **Pi 5 4GB**      | 4GB  | `llama3.2:1b`                  | Basic automation                 |
| **Pi 5 8GB**      | 8GB  | `llama3.1:8b`                  | Good performance                 |
| **Pi 5 16GB** ⭐  | 16GB | `qwen2.5:14b` to `qwen2.5:32b` | High performance (current setup) |
| **Apple Silicon** | 8GB+ | Any models                     | Excellent                        |

## 📚 Documentation

- [🚀 **Setup Guide**](docs/setup-guide.md) - Complete installation walkthrough
- [🌐 **Tailscale Setup**](docs/tailscale-setup.md) - SSL certificates and external access
- [🔗 **API Configuration**](docs/api-setup.md) - Telegram, Notion, Gmail setup
- [⚡ **Workflow Management**](docs/workflows.md) - Import/export and examples
- [🖥️ **Hardware Optimization**](docs/hardware-setup.md) - Platform-specific tuning
- [📊 **Monitoring Setup**](docs/monitoring.md) - Thermal monitoring and performance tracking

## ⏱ Long-Running LLM Calls

**Current Approach**: All workflows use the **HTTP Request node** to communicate directly with self-hosted Ollama at `http://ollama:11434/api/generate`.

**Why HTTP Request instead of AI Agent?**

On Raspberry Pi, LLM inference can take several minutes for complex prompts. The HTTP Request node provides:

- **Flexible timeout control**: Set explicit timeouts per request (e.g., `"timeout": 3600000` for 1 hour)
- **Direct API access**: Full control over Ollama parameters (temperature, top_p, repeat_penalty, num_threads)
- **Predictable behavior**: No abstraction layers that might interfere with long-running calls

**AI Agent Node Status**: Support for AI Agent is not currently a top priority, but will be considered for future iterations. Several approaches were attempted with only partial success due to timeout configuration limitations in AI Agent's architecture when working with self-hosted LLMs.

**Timeout Patch**: The stack includes [n8n-timeout-patch](https://github.com/Piggeldi2013/n8n-timeout-patch) to extend global timeout limits, ensuring workflows don't terminate during long LLM operations:

- **Workflow execution**: 12 hours (`N8N_WORKFLOW_TIMEOUT=43200`)
- **LLM response headers**: 3 hours (`FETCH_HEADERS_TIMEOUT=10800000`)
- **LLM body streaming**: 12 hours (`FETCH_BODY_TIMEOUT=43200000`)

**Example**: See `workflows/gmail-to-telegram.json` node "Summarise Email with LLM" for HTTP Request configuration with Ollama.

## �🚨 Troubleshooting

```bash
./scripts/manage.sh diagnose    # Full system check
./scripts/manage.sh restart     # Restart services
docker compose logs -f n8n      # View n8n logs
```

**Common Issues**: Port conflicts, SSL certificates, webhook setup → See setup guide

## 📄 License

MIT License - For personal use. Review security before internet exposure.
