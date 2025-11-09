# Workflow Documentation

Comprehensive documentation for all n8n workflows in the homelab automation stack.

## Quick Start

### Prerequisites

1. Complete n8n setup wizard via web UI first (required for database initialization)
2. Configure credentials in n8n UI after importing workflows

### Management Commands

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

## Available Workflows

### Production Workflows

#### 📧 [Gmail to Telegram](gmail-to-telegram.md)

Daily email digest with AI-powered summaries delivered to Telegram.

- **File**: `workflows/Gmail to Telegram.json`
- **Trigger**: Schedule (Daily at 8am, configurable)
- **Features**: Email sanitization, LLM summarization, structured output
- **Status**: ✅ Production (v1.1)

**Quick Links**:
- [Full Documentation](gmail-to-telegram.md)
- [Email Sanitization](../email-sanitization.md)
- [Improvements Roadmap](../email-sanitization-improvements.md)

---

#### 📱 [Telegram to Notion](telegram-to-notion.md)

Convert Telegram messages to structured Notion tasks using AI.

- **File**: `workflows/telegram-to-notion.json`
- **Trigger**: Telegram bot messages (todo:, meeting:, task:)
- **Features**: Natural language parsing, automatic categorization, date extraction
- **Status**: ✅ Production (v1.0)

**Quick Links**:
- [Full Documentation](telegram-to-notion.md)

---

### Development/Testing Workflows

#### 🔧 [Ollama Echo](ollama-echo.md)

Test and benchmark local LLM performance with detailed metrics.

- **File**: `workflows/ollama-echo.json`
- **Trigger**: Telegram bot messages
- **Features**: Model selection, performance metrics, benchmarking
- **Status**: 🧪 Development/Testing

**Quick Links**:
- [Full Documentation](ollama-echo.md)
- [Model Analysis](../model-context-window-analysis.md)

---

## Common Operations

### Import All Workflows

```bash
# Import all workflow JSON files from workflows/ directory
./scripts/manage.sh import-workflows
```

**Expected output**:
```
Importing workflow: Gmail to Telegram
Importing workflow: telegram-to-notion
Importing workflow: Ollama Echo
✅ Successfully imported 3 workflows
```

### Export Modified Workflows

After making changes in the n8n UI:

```bash
# Export all active workflows to workflows/ directory
./scripts/manage.sh export-workflows
```

### Monitor Executions

```bash
# Show latest execution across all workflows
./scripts/manage.sh exec-latest

# Show last 20 executions
./scripts/manage.sh exec-history 20

# Show workflow-specific executions
./scripts/manage.sh exec-workflow gmail-to-telegram

# Show only failed executions
./scripts/manage.sh exec-failed 10

# Show execution statistics
./scripts/manage.sh exec-stats
```

### Investigate Issues

```bash
# Quick diagnostic triage
/diagnose-workflow <execution-id>

# Full forensic investigation with report
/investigate <execution-id>

# Extract execution data
./scripts/manage.sh exec-details <execution-id>

# Parse specific node outputs
./scripts/manage.sh exec-parse <execution-id> --node "Node Name"

# Analyze LLM responses
./scripts/manage.sh exec-llm <execution-id>
```

## Credentials Setup

All workflows require credentials to be configured in the n8n UI after import.

### Required Credentials by Workflow

| Workflow | Credentials Needed |
|----------|-------------------|
| Gmail to Telegram | Gmail OAuth2, Telegram Bot, Ollama (local) |
| Telegram to Notion | Telegram Bot, Notion API, Ollama (local) |
| Ollama Echo | Telegram Bot, Ollama (local) |

### Gmail OAuth2 Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create project and enable Gmail API
3. Create OAuth2 credentials (Desktop app)
4. Configure in n8n with Client ID, Client Secret
5. Authorize and get Refresh Token

**See**: `docs/api-setup.md` for detailed instructions

### Telegram Bot Setup

1. Talk to [@BotFather](https://t.me/BotFather) on Telegram
2. Send `/newbot` command
3. Choose name and username
4. Copy the bot token
5. Add token to n8n credentials
6. Get your Chat ID:
   - Send message to bot
   - Visit: `https://api.telegram.org/bot<TOKEN>/getUpdates`
   - Find `chat.id` in response

### Notion API Setup

1. Go to [Notion Integrations](https://www.notion.so/my-integrations)
2. Create new integration
3. Copy the API token
4. Create a database in Notion
5. Share database with your integration
6. Copy database ID from URL
7. Configure in n8n

### Ollama (Local LLM)

No credentials needed if using the local Ollama instance in the Docker stack.

**External Ollama**: Configure URL in workflow nodes (default: `http://ollama:11434`)

## Troubleshooting

### General Issues

| Issue | Solution |
|-------|----------|
| Workflows not visible | Complete n8n setup wizard first, then hard refresh UI |
| "Database not initialized" | Access web UI and complete setup |
| Import warnings about project ID | Normal for fresh installs - auto-assigns to default project |
| Missing credentials | Configure in n8n UI after import (not included in exports) |

### Workflow-Specific Issues

See individual workflow documentation:
- [Gmail to Telegram Troubleshooting](gmail-to-telegram.md#troubleshooting)
- [Telegram to Notion Troubleshooting](telegram-to-notion.md#troubleshooting)
- [Ollama Echo Troubleshooting](ollama-echo.md#troubleshooting)

### Running Diagnostics

```bash
# Full system diagnostic
./scripts/manage.sh diagnose

# Workflow-specific diagnostic
./scripts/manage.sh test-workflows

# Check service health
./scripts/manage.sh health

# View logs
./scripts/manage.sh logs n8n
./scripts/manage.sh logs ollama
./scripts/manage.sh logs postgres
```

## Backup & Restore

### Create Backup

```bash
# Full backup (includes workflows, database, configurations)
./scripts/backup.sh
```

**Backup includes**:
- PostgreSQL databases (n8n data, execution history)
- n8n workflow files
- Ollama models list
- Configuration files (.env, SSL certs)

### Restore from Backup

```bash
# Restore everything
./scripts/restore.sh <backup-file>

# After restore, verify workflows
./scripts/manage.sh test-workflows
```

## Development Guidelines

### Creating New Workflows

1. **Design in n8n UI**: Build and test workflow
2. **Export**: Run `./scripts/manage.sh export-workflows`
3. **Document**: Create `docs/workflows/your-workflow.md` using existing templates
4. **Update Index**: Add entry to this README.md
5. **Test Import**: Test on clean system with `./scripts/manage.sh import-workflows`
6. **Commit**: Add workflow JSON and documentation to git

### Modifying Existing Workflows

1. **Make changes in n8n UI**
2. **Test thoroughly** with manual executions
3. **Export**: `./scripts/manage.sh export-workflows`
4. **Update docs**: Reflect changes in workflow documentation
5. **Version bump**: Update version in workflow doc header
6. **Commit**: Git commit with clear description

### Documentation Template

Use existing workflow docs as templates:
- **Overview**: Purpose, trigger, status
- **Flow Diagram**: ASCII flow chart
- **Key Features**: Main capabilities
- **Configuration**: Required credentials, customization
- **Usage Examples**: Concrete examples
- **Troubleshooting**: Common issues and solutions
- **Monitoring**: How to check executions
- **Performance Metrics**: Expected performance
- **Related Documentation**: Links to related docs
- **Maintenance**: Export, backup, update procedures

## Performance Monitoring

### Execution Metrics

Track these metrics for each workflow:

- **Success Rate**: % of successful executions
- **Processing Time**: Average duration
- **Token Usage**: For LLM-based workflows
- **Memory Usage**: Peak memory during execution
- **Error Rate**: Types and frequency of errors

### Analysis Tools

```bash
# Execution statistics
./scripts/manage.sh exec-stats

# Workflow-specific stats
./scripts/manage.sh exec-workflow <workflow-name>

# Failed execution analysis
./scripts/manage.sh exec-failed 20

# LLM response analysis
./scripts/manage.sh exec-llm <execution-id>
```

### Investigation Reports

For complex issues, use the investigation system:

```bash
# Quick diagnostic
/diagnose-workflow <execution-id>

# Full investigation with documented report
/investigate <execution-id>
```

Reports are saved to `docs/investigations/` with:
- Performance analysis
- Data quality assessment
- Root cause identification
- Prioritized recommendations
- Code examples for fixes

**See**: `docs/investigation-system.md` for complete documentation

## Related Documentation

### Core Documentation

- **Setup Guide**: `docs/setup-guide.md`
- **API Setup**: `docs/api-setup.md`
- **Monitoring**: `docs/monitoring.md`

### Workflow-Specific

- **Email Sanitization**: `docs/email-sanitization.md`
- **Sanitization Improvements**: `docs/email-sanitization-improvements.md`
- **Model Analysis**: `docs/model-context-window-analysis.md`

### Investigation Reports

- **LLM Parsing Failures**: `docs/investigations/2025-10-29-workflow-191-llm-parsing-failures.md`
- **Performance Baselines**: `docs/investigations/2025-10-30-workflow-193-qwen-performance-baseline.md`
- **All Reports**: `docs/investigations/`

### System Documentation

- **Investigation System**: `docs/investigation-system.md`
- **Investigation Tooling**: `docs/investigation-tooling-improvements.md`
- **Roadmap**: `docs/roadmap.md`

## Contributing

### Adding New Workflows

1. Build and test in n8n UI
2. Document following the template structure
3. Export workflow JSON
4. Update this README with new entry
5. Create pull request or commit directly

### Improving Documentation

1. Identify gaps or outdated information
2. Update relevant workflow documentation
3. Test documented procedures
4. Commit with clear description

---

**Last Updated**: 2025-11-09
**Workflows Count**: 3 (2 production, 1 development)
**Documentation Version**: 2.0 (restructured)
