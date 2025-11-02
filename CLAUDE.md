# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a self-hosted homelab automation stack designed for Raspberry Pi 5 and macOS. It provides workflow automation using n8n, PostgreSQL, Ollama (local LLMs), and optional Tailscale for secure remote access. The stack enables AI-powered automation workflows like Telegram→Notion task conversion and Gmail summaries.

## Architecture

### Docker Stack

- **n8n**: Workflow automation platform (port 8443) with PostgreSQL backend
- **PostgreSQL**: Database backend for n8n workflows and execution history
- **Ollama**: Local LLM inference server (port 11434) for privacy-first AI processing
- **Tailscale**: Optional secure remote access via profiles
- **Redis**: Optional caching/rate limiting via profiles
- **Watchtower**: Optional automatic container updates via profiles

All services are networked via a bridge network (`homelab_network`) and use external named volumes for persistence.

### Critical Timeout Configuration

The stack includes a **custom timeout patch** (`config/n8n/patch-http-timeouts.js`) to enable long-running LLM calls. This is essential for AI Agent nodes and complex workflows.

**What it patches:**

- Node.js HTTP server (browser → n8n requests)
- Axios library (used by LangChain components)
- Global fetch (extends timeout for Ollama URLs)
- Undici dispatcher (n8n → LLM API calls)

**Key timeout values (in docker-compose.yml):**

- Workflow execution: 12 hours (`N8N_WORKFLOW_TIMEOUT=43200`)
- Inbound request: disabled (`N8N_HTTP_REQUEST_TIMEOUT=0`)
- Outbound connect: 10 min (`FETCH_CONNECT_TIMEOUT=600000`)
- Outbound headers: 3 hours (`FETCH_HEADERS_TIMEOUT=10800000`)
- Outbound body/stream: 12 hours (`FETCH_BODY_TIMEOUT=43200000`)

The patch is preloaded via `NODE_OPTIONS=--require /patch/patch-http-timeouts.js`. When modifying timeout behavior, edit environment variables in docker-compose.yml.

### Modular Script Architecture

The setup and management scripts use a modular library system located in `scripts/lib/`:

**Core libraries:**

- `common.sh`: Logging, color output, error handling, utilities
- `docker.sh`: Docker compose wrappers, container management, health checks
- `prerequisites.sh`: System requirements validation
- `environment.sh`: .env file generation and configuration
- `ssl.sh`: Self-signed certificate generation
- `services.sh`: Docker volume initialization and service startup
- `ollama.sh`: Model downloads and management
- `workflows.sh`: n8n workflow import/export via CLI
- `executions.sh`: Query workflow execution history from PostgreSQL
- `parse-execution-data.py`: Python parser for n8n execution data (handles compressed JSON format)
- `tailscale.sh`: Funnel setup for external webhooks
- `backup.sh`: Full system backup/restore operations
- `display.sh`: Setup completion information display

**Main scripts:**

- `setup.sh`: Initial setup and configuration (always recreates containers)
- `manage.sh`: Day-to-day operations (start/stop/logs/status)
- `backup.sh`: Backup orchestration
- `restore.sh`: Restore orchestration
- `diagnose-universal.sh`: Universal diagnostic tool

When modifying functionality, identify which library module contains the relevant functions and update it there. All scripts source their required libraries from `scripts/lib/`.

## Common Commands

### Initial Setup

```bash
./scripts/setup.sh              # Full setup (recreates containers)
./scripts/setup.sh prereq       # Check prerequisites only
./scripts/setup.sh env          # Setup .env only
./scripts/setup.sh ssl          # Generate SSL certificates only
./scripts/setup.sh funnel       # Enable external webhooks via Tailscale
```

### Service Management

```bash
./scripts/manage.sh status      # Show service status and health
./scripts/manage.sh logs n8n    # View n8n logs
./scripts/manage.sh restart     # Restart all services
./scripts/manage.sh stop        # Stop all services
./scripts/manage.sh start       # Start all services
./scripts/manage.sh update      # Update container images
./scripts/manage.sh health      # Check service health
./scripts/manage.sh diagnose    # Run full diagnostic
```

### Ollama Model Management

```bash
./scripts/manage.sh models                      # List installed models
./scripts/manage.sh pull llama3.1:8b           # Download specific model
./scripts/manage.sh restore-models backup.txt  # Restore models from backup
```

### Workflow Management

```bash
./scripts/manage.sh import-workflows   # Import workflow JSON files to n8n
./scripts/manage.sh export-workflows   # Export n8n workflows to files
./scripts/manage.sh test-workflows     # Test workflow sync and credentials
```

Workflows are stored in `workflows/*.json` and can be imported/exported using the n8n CLI. The workflow management functions require n8n to be running.

### Execution Logs

```bash
./scripts/manage.sh exec-latest                     # Show latest execution
./scripts/manage.sh exec-history 20                 # Show last N executions
./scripts/manage.sh exec-details 191                # Show execution details by ID
./scripts/manage.sh exec-stats                      # Show execution statistics
./scripts/manage.sh exec-workflow gmail-to-telegram # Show workflow-specific executions
./scripts/manage.sh exec-failed 10                  # Show failed executions
```

Query workflow execution history directly from PostgreSQL. Useful for monitoring performance, debugging failures, and analyzing workflow runs without manual database access.

### Execution Data Analysis

```bash
# Extract raw execution data
./scripts/manage.sh exec-data 191                   # Output to stdout
./scripts/manage.sh exec-data 191 exec-191.json     # Save to file

# Parse execution data and extract node outputs
./scripts/manage.sh exec-parse 191                  # Parse all nodes
./scripts/manage.sh exec-parse 191 --node "Format for Telegram"  # Specific node
./scripts/manage.sh exec-parse 191 --llm-only       # Extract only LLM responses
./scripts/manage.sh exec-parse 191 --llm-only --validate-json   # With JSON validation
./scripts/manage.sh exec-parse 191 --output results.json        # Save to file

# Analyze LLM responses with automatic JSON validation
./scripts/manage.sh exec-llm 191                    # Full analysis with statistics
```

Advanced execution data analysis for investigating workflow failures, debugging LLM parsing issues, and extracting detailed node outputs. The parser handles n8n's compressed JSON reference format automatically.

**Use cases:**

- Investigate LLM parsing failures (e.g., workflow 191 investigation)
- Extract specific node outputs for analysis
- Validate JSON responses from AI nodes
- Debug complex workflow execution issues
- Generate reports on execution quality

### Workflow Investigation System

The project includes specialized Claude Code slash commands for comprehensive workflow analysis:

**Available commands:**

```bash
/investigate <execution_id>        # Full forensic investigation with detailed report
/diagnose-workflow [execution_id]  # Quick diagnostic triage (no report)
```

**Investigation features:**

- **Comprehensive analysis**: Performance, data quality, model verification, root cause identification
- **Automated reporting**: Generates markdown reports saved to `docs/investigations/`
- **Actionable recommendations**: Prioritized fixes with code examples and impact estimates
- **Model verification**: Automatically detects model mismatches and UI changes
- **Interactive questioning**: Asks clarifying questions when needed

**When to use:**

Use `/investigate` for:

- Workflow failures or unexpected behavior
- Performance degradation (execution took unusually long)
- Data quality issues (parsing failures, empty outputs)
- Need documented analysis for future reference
- Before/after optimization to establish baselines

Use `/diagnose-workflow` for:

- Quick health check of latest execution
- Fast triage without full report
- Determining if detailed investigation is needed

**Investigation reports include:**

- Executive summary with key findings
- Detailed performance and data quality analysis
- Model performance assessment
- Root cause identification
- Prioritized recommendations (immediate/short-term/long-term)
- Specific code examples and implementation steps
- Testing recommendations and expected impact

**Example workflow:**

```bash
# Check latest execution quickly
/diagnose-workflow

# If issues found, run full investigation
/investigate 194

# Review generated report
cat docs/investigations/2025-10-30-workflow-194-*.md

# Implement recommended fixes
# Test with new execution
# Monitor improvement
```

See `docs/investigation-system.md` for complete documentation and examples.

**Existing investigation reports:**

- `docs/investigations/2025-10-29-workflow-191-llm-parsing-failures.md` - LLM JSON parsing issues

### Backup & Restore

```bash
./scripts/backup.sh                    # Create full backup
./scripts/restore.sh <backup-file>     # Restore from backup
```

Backups include PostgreSQL databases, n8n data, Ollama models list, and configuration files.

### Docker Compose

```bash
docker compose up -d                         # Start services
docker compose down                          # Stop services
docker compose logs -f n8n                   # Follow n8n logs
docker compose --profile tailscale up -d     # Start with Tailscale
docker compose --profile redis up -d         # Start with Redis
```

Use profiles to enable optional services: `tailscale`, `redis`, `watchtower`.

## Development Workflow

### Modifying Docker Configuration

1. Edit `docker-compose.yml`
2. Update `.env.example` if adding new environment variables
3. Run `./scripts/setup.sh` to recreate containers (setup always forces recreation)
4. Verify changes with `./scripts/manage.sh status` and `./scripts/manage.sh health`

### Modifying Scripts

1. Identify the correct library module in `scripts/lib/`
2. Edit the function in the library file
3. Test by running the relevant script command
4. Use `./scripts/manage.sh diagnose` to verify system health

### Adding New Workflows

1. Create workflow in n8n UI (https://localhost:8443)
2. Run `./scripts/manage.sh export-workflows` to export to `workflows/*.json`
3. Commit the JSON files to version control
4. Import on other systems with `./scripts/manage.sh import-workflows`

### Testing LLM Integration

1. Ensure Ollama is running: `./scripts/manage.sh status`
2. List available models: `./scripts/manage.sh models`
3. Download model if needed: `./scripts/manage.sh pull llama3.1:8b`
4. Test via n8n workflow or direct API: `curl http://localhost:11434/api/generate -d '{"model":"llama3.1:8b","prompt":"test"}'`

## Important File Locations

- `.env` - Environment variables (generated from `.env.example`)
- `docker-compose.yml` - Service definitions and timeout configuration
- `config/n8n/patch-http-timeouts.js` - Timeout patch for long-running LLM calls
- `config/postgres/init.sql` - PostgreSQL initialization
- `config/ssl/` - Self-signed SSL certificates
- `workflows/*.json` - n8n workflow definitions
- `scripts/lib/*.sh` - Modular script libraries
- Volumes: External Docker volumes (`homelab_postgres_data`, `homelab_n8n_data`, `homelab_ollama_data`)

## Environment Variables

Required variables (in `.env`):

- `POSTGRES_PASSWORD` - PostgreSQL database password
- `N8N_PASSWORD` - n8n basic auth password
- `N8N_ENCRYPTION_KEY` - 32-character encryption key for n8n
- `TELEGRAM_BOT_TOKEN` - Telegram bot token (from @BotFather)

Optional variables:

- `NOTION_API_TOKEN` - Notion integration token
- `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET`, `GMAIL_REFRESH_TOKEN` - Gmail OAuth2
- `TAILSCALE_AUTH_KEY` - Tailscale authentication key
- `OPENAI_API_KEY` - OpenAI API fallback

See `.env.example` for complete list.

## Troubleshooting

### n8n Not Starting

- Check PostgreSQL health: `docker compose logs postgres`
- Verify encryption key is exactly 32 characters
- Check volume permissions: `./scripts/manage.sh diagnose`

### Ollama Out of Memory

- Reduce model size or use quantized models
- Adjust memory limits in docker-compose.yml (currently 14GB limit, 4GB reservation)
- Check available RAM: `./scripts/manage.sh diagnose system`

### Long-Running LLM Timeouts

- Verify patch loaded: check n8n logs for `[patch]` messages (HTTP server, axios, global fetch, undici)
- Increase timeout values in docker-compose.yml environment variables
- For Ollama-specific issues, check `FETCH_BODY_TIMEOUT` and `OLLAMA_REQUEST_TIMEOUT`

### Workflow Import/Export Failures

- Ensure n8n is running: `./scripts/manage.sh status`
- Test credentials: `./scripts/manage.sh test-workflows`
- Check n8n API is accessible: `curl -u admin:password http://localhost:8443/api/v1/workflows`

### External Webhook Access

- Ensure Tailscale is installed and connected
- Run `./scripts/setup.sh funnel` to enable external access
- Check funnel status: `./scripts/setup.sh funnel-status`

## Platform-Specific Notes

### Raspberry Pi 5

- **This project uses a Raspberry Pi 5 with 16GB RAM**
- Recommended models: `llama3.2:1b` (4GB), `llama3.1:8b` (8GB), `qwen2.5:14b` (16GB), `qwen2.5:32b` (20GB)
- With 16GB RAM, you can run larger models like qwen2.5:14b comfortably
- Memory limits are critical - adjust docker-compose.yml based on available RAM
- Use `OLLAMA_NUM_PARALLEL=1` and `OLLAMA_MAX_LOADED_MODELS=1` to prevent OOM

### macOS (Apple Silicon)

- Excellent performance with any models
- Ollama uses Metal acceleration automatically
- SSL certificates work with system keychain

## Security Considerations

- n8n uses basic auth by default (consider OAuth for production)
- PostgreSQL credentials are in `.env` (never commit this file)
- Self-signed SSL certificates are for local development only
- Tailscale funnel exposes webhooks publicly - use webhook validation
- Review security before exposing to the internet
