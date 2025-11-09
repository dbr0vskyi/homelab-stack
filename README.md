# Homelab Automation Stack

Self-hosted automation platform for Raspberry Pi 5 and macOS. Build AI-powered workflows with n8n, local LLMs (Ollama), and integrate with popular services like Telegram, Notion, and Gmail.

## Features

- **Local AI Processing**: Privacy-first LLM inference with Ollama (no cloud dependencies)
- **Workflow Automation**: Visual workflow builder with n8n for complex automations
- **Fully Containerized**: Docker-based stack with persistent volumes and automated backups
- **Secure Remote Access**: Optional Tailscale integration for external webhooks
- **Monitoring Built-in**: Prometheus and Grafana for system and thermal tracking
- **Production-Ready**: Comprehensive timeout handling for long-running LLM operations

## Stack Components

- **n8n** - Workflow automation platform
- **PostgreSQL** - Database backend for n8n workflows and execution history
- **Ollama** - Local LLM inference server
- **Prometheus + Grafana** - Monitoring and thermal tracking
- **Tailscale** - Zero-trust network access (optional)
- **Redis** - Caching and rate limiting (optional)
- **Watchtower** - Automatic container updates (optional)

## 🚀 Quick Start

```bash
# Clone repository
git clone <your-repo> homelab-stack && cd homelab-stack

# Run setup script (checks prerequisites, generates config, starts services)
./scripts/setup.sh

# Configure API credentials
cp .env.example .env
nano .env  # Add your tokens
```

**Access Points**:
- n8n UI: `https://localhost:8443`
- Ollama API: `http://localhost:11434`
- Grafana: `http://localhost:3000` (if monitoring enabled)

**See**: [Setup Guide](docs/setup-guide.md) for detailed installation instructions and [API Setup](docs/api-setup.md) for credential configuration.

## Management

Common operations via management scripts:

```bash
./scripts/manage.sh status       # Check service health
./scripts/manage.sh logs n8n     # View logs
./scripts/manage.sh restart      # Restart services
./scripts/backup.sh              # Create full backup
```

**Workflow Management**:
```bash
./scripts/manage.sh import-workflows   # Import workflow JSON files
./scripts/manage.sh export-workflows   # Export workflows to files
./scripts/manage.sh exec-latest        # View execution history
```

Run any script without arguments to see all available options.

**See**: [Workflow Documentation](docs/workflows/) for detailed workflow management and [Monitoring Guide](docs/monitoring.md) for observability setup.

## Hardware Requirements

**Current Setup**: Raspberry Pi 5 with 16GB RAM (recommended for production use)

**Minimum**:
- Raspberry Pi 5 (4GB RAM) or Apple Silicon Mac
- 32GB storage (SD card or SSD)
- Network connectivity

**Recommended**:
- Raspberry Pi 5 with 8GB+ RAM or Apple Silicon Mac
- 64GB+ SSD storage for better performance
- Active cooling for sustained LLM workloads

Model performance scales with available RAM - see [Hardware Setup Guide](docs/hardware-setup.md) for detailed recommendations and optimization.

## Documentation

**Getting Started**:
- [Setup Guide](docs/setup-guide.md) - Complete installation walkthrough
- [API Configuration](docs/api-setup.md) - Telegram, Notion, Gmail credential setup
- [Hardware Setup](docs/hardware-setup.md) - Platform-specific optimization

**Workflows**:
- [Workflow Documentation](docs/workflows/) - Individual workflow guides and management
- [Email Sanitization](docs/email-sanitization.md) - Email processing implementation
- [Investigation System](docs/investigation-system.md) - Workflow debugging tools

**Operations**:
- [Monitoring Setup](docs/monitoring.md) - Prometheus, Grafana, and thermal tracking
- [Tailscale Setup](docs/tailscale-setup.md) - External webhook access
- [Roadmap](docs/roadmap.md) - Planned features and improvements

## Architecture Notes

### LLM Integration

Workflows use **HTTP Request nodes** to communicate directly with Ollama (`http://ollama:11434/api/generate`) instead of n8n's AI Agent node. This provides:

- Flexible timeout control for long-running inference (minutes to hours on Raspberry Pi)
- Direct API access with full control over Ollama parameters
- Predictable behavior without abstraction layer limitations

### Timeout Configuration

The stack includes custom timeout patches to support extended LLM operations:
- Workflow execution: 12 hours
- HTTP request timeouts: configurable per request
- Fetch API timeouts: extended for streaming responses

**Implementation details**: See [CLAUDE.md](CLAUDE.md) for architecture documentation and timeout configuration.

## Troubleshooting

```bash
./scripts/manage.sh diagnose    # Full system diagnostic
./scripts/manage.sh restart     # Restart all services
./scripts/manage.sh logs n8n    # View service logs
```

**Common Issues**:
- Port conflicts or SSL certificate errors → [Setup Guide](docs/setup-guide.md)
- Workflow execution failures → [Workflow Documentation](docs/workflows/)
- LLM timeout or performance issues → [Hardware Setup](docs/hardware-setup.md)

Use the investigation system for detailed workflow debugging: `/diagnose-workflow <execution-id>` or `/investigate <execution-id>`

## License

MIT License - For personal use. Review security settings before exposing to the internet.
