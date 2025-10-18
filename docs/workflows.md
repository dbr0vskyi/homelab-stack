# Workflow Guide

Two automated workflows for productivity:

## 🔄 Workflow Management

### ⚠️ **IMPORTANT: First-Time Setup**

**Before importing workflows, you MUST complete n8n initialization:**

1. Access n8n web interface: `https://your-domain/` (or `https://localhost/` locally)
2. Complete the setup wizard
3. Create your admin account
4. Wait for n8n to fully initialize

**Why this is required:**

- n8n CLI requires the database to be initialized
- Database is created during first-time setup wizard
- Without initialization, imports will fail

**Check if n8n is ready:**

```bash
./scripts/manage.sh test-workflows
```

If you see "Found 0 workflow(s)" and initialization errors, complete the setup wizard first.

---

### Import Workflows to n8n

Import workflow files from the `workflows/` directory into n8n:

```bash
./scripts/manage.sh import-workflows
```

**What it does:**

- Validates all JSON workflow files
- Cleans up metadata that could cause conflicts
- Imports workflows using n8n CLI
- Automatically detects and uses the correct project ID
- **Falls back to default project if project ID not found** (fresh installs)
- Skips invalid files with detailed warnings
- Verifies successful import

**Output Example:**

```
[INFO] Importing workflows to n8n using CLI...
[INFO] Found workflow files in workflows/:
[INFO]   - gmail-to-telegram.json
[INFO]   - telegram-to-notion.json
[SUCCESS] ✓ Successfully imported workflows to n8n
[INFO] Verifying imported workflows...
[SUCCESS] Current workflows in n8n:
[INFO]   apv2HH0a1EfNcMRd|gmail-to-telegram
[INFO]   sz6q4bQXIXzMymmb|telegram-to-notion
```

**For fresh n8n installations:**

```
[WARNING] ⚠️  Project ID 'PTDcIHwvy2eBoTf7' not found in this n8n instance
[INFO] This is normal for fresh n8n installations
[INFO] Retrying import without project ID (will use default project)...
[SUCCESS] ✓ Successfully imported workflows to n8n
```

### Export Workflows from n8n

Export workflows from n8n to the `workflows/` directory:

```bash
./scripts/manage.sh export-workflows
```

**What it does:**

- Exports all workflows from n8n database
- Saves each workflow as a separate JSON file
- Uses workflow name for filename (sanitized)
- Validates exported JSON format
- Overwrites existing files

**Use Cases:**

- Backup workflows before changes
- Version control your workflows
- Share workflows with team members
- Migrate workflows to another instance

### Test Workflow Sync

Run comprehensive diagnostics on workflow management:

```bash
./scripts/manage.sh test-workflows
```

**Tests performed:**

1. ✓ n8n CLI availability in container
2. ✓ Database connection and workflow listing
3. ✓ Local workflows directory validation
4. ✓ Export functionality test
5. ✓ Import capability check

### Troubleshooting

If workflows don't appear in n8n UI after import:

1. **Complete n8n initialization first** - Access web UI and complete setup wizard
2. **Refresh the web interface** - Hard refresh (Cmd+Shift+R / Ctrl+Shift+R)
3. **Check workflow status** - Workflows may be inactive by default
4. **Verify project** - Ensure you're viewing the correct project in n8n
5. **Check logs** - Run `docker logs homelab-n8n --tail 50`
6. **Re-import** - Try exporting and re-importing

Common issues:

| Issue                          | Cause                    | Solution                                           |
| ------------------------------ | ------------------------ | -------------------------------------------------- |
| "n8n database not initialized" | First run, no setup      | Complete n8n setup wizard in web UI first          |
| "Found 0 workflows"            | Fresh installation       | Normal - import workflows after setup              |
| "Project not found"            | Different n8n instance   | Script auto-falls-back to default project          |
| "Invalid JSON"                 | Malformed workflow file  | Validate JSON with `jq empty workflow.json`        |
| "Duplicate workflows"          | Multiple imports         | Normal - n8n creates new versions                  |
| "Workflows not visible in UI"  | Browser cache            | Hard refresh browser (Cmd+Shift+R)                 |
| Import cuts off/hangs          | Container resource issue | Check `docker stats` and increase memory if needed |

**Verbose Logging:**

For detailed debugging, check the script output. The scripts provide:

- ✓ File-by-file validation status
- ⚠️ Warnings for skipped files
- ✗ Error messages with specific issues
- 📋 Complete import/export summaries

## �📱 Telegram → Notion Tasks

**Purpose**: Convert Telegram messages to structured Notion tasks using AI

**Flow**: Telegram → Ollama AI → Notion → Confirmation

### Setup

1. Import workflow: `./scripts/manage.sh import-workflows`
2. Open n8n web interface (https://your-domain/)
3. Find "telegram-to-notion" workflow
4. Configure credentials:
   - Telegram Bot API token
   - Notion API token + database ID
   - Verify Ollama connection (automatic if running)
5. **Activate the workflow** in n8n UI
6. Test: Send "todo: Review budget by Friday" to bot

### Usage Examples

```
"todo: Review quarterly budget by Friday"
"meeting: Team standup tomorrow 9am"
"urgent: Fix server issue ASAP"
"note: Research new automation tools"
```

## 📧 Gmail → Telegram Summaries

**Purpose**: Daily Gmail scan with AI-powered email summaries

**Flow**: Gmail Scan → AI Analysis → Telegram Summary

### Setup

1. Import workflow: `./scripts/manage.sh import-workflows`
2. Open n8n web interface
3. Find "gmail-to-telegram" workflow
4. Configure credentials:
   - Gmail OAuth2 credentials
   - Telegram Bot for notifications
   - Set `TELEGRAM_CHAT_ID` in environment
5. Adjust schedule (default: daily 8am)
6. **Activate the workflow** in n8n UI
7. Test: Run workflow manually (Execute button)

### Features

- Scans last 24h of unread emails
- Filters important/actionable emails
- AI summarizes with priority levels
- Sends formatted digest to Telegram

## 🔧 Customization

### AI Model Selection

- **Fast**: `llama3.2:1b` (basic summaries)
- **Balanced**: `llama3.1:8b` (good quality)
- **Quality**: `qwen2.5:14b` (detailed analysis)

Edit the Ollama HTTP Request node in workflows to change models.

### Filtering Rules

Edit workflows in n8n to customize:

- Email importance detection keywords
- Task extraction patterns
- Summary formats and lengths
- Notification preferences

## 📊 Monitoring

- Check n8n execution history in the UI
- Monitor logs: `./scripts/manage.sh logs n8n`
- Test workflows manually before scheduling
- Export workflows regularly for backup: `./scripts/manage.sh export-workflows`

## 🔐 Credentials Management

**Important**: Workflows reference credentials by ID. When importing workflows:

1. Credentials are NOT included in exports (security)
2. You must configure credentials in n8n UI after import
3. Workflow nodes will show ⚠️ until credentials are set
4. See `docs/workflows-setup.md` for detailed credential setup
