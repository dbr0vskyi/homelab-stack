# Workflow Management

## Prerequisites

1. Complete n8n setup wizard via web UI first (required for database initialization)
2. Configure credentials in n8n UI after importing workflows

## Quick Commands

```bash
# Import workflows (cross-environment compatible)
./scripts/manage.sh import-workflows

# Export workflows for backup
./scripts/manage.sh export-workflows

# Run diagnostics
./scripts/manage.sh test-workflows

# Monitor execution history
./scripts/manage.sh exec-latest    # Latest execution
./scripts/manage.sh exec-history   # Recent executions
./scripts/manage.sh exec-failed    # Show failures
```

## Workflows

### 📱 Telegram → Notion Tasks

Convert messages to structured tasks using AI

- **Trigger**: Telegram bot messages starting with "todo:", "meeting:", etc.
- **Flow**: Telegram → Ollama AI → Notion → Confirmation

### 📧 Gmail → Telegram Summaries

Daily email digest with AI summaries

- **Schedule**: Daily at 8am (configurable)
- **Flow**: Gmail → AI Analysis → Telegram Summary

## Troubleshooting

| Issue                            | Solution                                                    |
| -------------------------------- | ----------------------------------------------------------- |
| Workflows not visible            | Complete n8n setup wizard first, then hard refresh UI       |
| "Database not initialized"       | Access web UI and complete setup                            |
| Import warnings about project ID | Normal for fresh installs - auto-assigns to default project |
| Missing credentials              | Configure in n8n UI after import (not included in exports)  |

Run diagnostics for detailed troubleshooting: `./scripts/manage.sh diagnose`
