# Telegram to Notion Workflow

Convert Telegram messages to structured Notion tasks using AI.

## Overview

**Workflow File**: `workflows/telegram-to-notion.json`
**Trigger**: Telegram bot messages
**Status**: Active

## Purpose

Capture quick task ideas from Telegram and automatically convert them to structured tasks in Notion using local LLM processing. Supports meeting notes, todos, and general tasks with automatic categorization and parsing.

## Flow Diagram

```
Telegram Trigger
  → Filter Message (Check format)
  → Extract Message Type
  → Process with LLM (Ollama)
  → Parse JSON Response
  → Create Notion Page
  → Send Confirmation (Telegram)
```

## Key Features

### Message Format Support

The workflow recognizes several message patterns:

**Todo Items**:
```
todo: Buy groceries tomorrow
todo: Call John about the project deadline
```

**Meeting Notes**:
```
meeting: Discuss Q4 roadmap with team on Friday 3pm
meeting: Client presentation prep next week
```

**General Tasks**:
```
task: Review pull requests
task: Update documentation
```

### AI Processing

- **Model**: Local Ollama LLM (configurable)
- **Function**: Extracts structured data from natural language
- **Output**: JSON with title, description, due date, priority, tags

### Notion Integration

Creates pages in your Notion database with:
- **Title**: Extracted from message
- **Description**: Full context
- **Due Date**: Parsed from message (if mentioned)
- **Priority**: Auto-assigned based on keywords
- **Tags**: Auto-categorized
- **Source**: Marked as "Telegram"

## Configuration

### Required Credentials

Configure these in the n8n UI after importing:

1. **Telegram Bot**
   - Bot Token (from @BotFather)
   - Instructions: Talk to @BotFather on Telegram
     - Send `/newbot`
     - Choose name and username
     - Copy the token

2. **Notion Integration**
   - API Token (from Notion integrations)
   - Database ID (from your Notion workspace)
   - Instructions:
     - Go to https://www.notion.so/my-integrations
     - Create new integration
     - Copy the API token
     - Share your database with the integration

3. **Ollama** (no credentials needed if using local instance)

### Notion Database Setup

Your Notion database should have these properties:

| Property | Type | Required | Notes |
|----------|------|----------|-------|
| Name | Title | Yes | Task title |
| Description | Text | No | Full details |
| Due Date | Date | No | Parsed from message |
| Priority | Select | No | High/Medium/Low |
| Tags | Multi-select | No | Auto-categorized |
| Source | Select | No | Set to "Telegram" |
| Status | Select | No | Default: "Not Started" |

### Model Selection

Edit the LLM node to change the model:

```json
{
  "model": "llama3.1:8b",  // Default
  "prompt": "Extract task information...",
  "options": {
    "temperature": 0.7
  }
}
```

## Usage Examples

### Simple Todo

**Input**:
```
todo: Fix the login bug
```

**Output** (Notion):
- Title: "Fix the login bug"
- Priority: Medium
- Tags: ["development", "bug"]
- Source: Telegram

### Meeting with Date

**Input**:
```
meeting: Quarterly review with Sarah on Friday at 2pm
```

**Output** (Notion):
- Title: "Quarterly review with Sarah"
- Due Date: Next Friday 2:00 PM
- Priority: High
- Tags: ["meeting"]
- Source: Telegram

### Task with Context

**Input**:
```
task: Update the API documentation to include the new authentication endpoints and rate limiting info
```

**Output** (Notion):
- Title: "Update API documentation"
- Description: "Include new authentication endpoints and rate limiting info"
- Priority: Medium
- Tags: ["documentation", "API"]
- Source: Telegram

## Troubleshooting

### Issue: Bot not responding

**Check**:
1. Telegram credentials are valid
2. Bot token is correct in n8n credentials
3. Workflow is active in n8n
4. Check webhook is registered: `docker compose logs n8n | grep telegram`

### Issue: Tasks not appearing in Notion

**Check**:
1. Notion credentials are valid
2. Database ID is correct
3. Notion integration has access to the database
4. Check n8n execution logs for errors

### Issue: LLM not parsing correctly

**Solutions**:
1. Try a different model: `qwen2.5:7b` or `llama3.2:3b`
2. Check Ollama is running: `docker compose ps ollama`
3. Verify model is downloaded: `./scripts/manage.sh models`
4. Review LLM response in execution logs

### Issue: Date parsing errors

**Cause**: Ambiguous date formats

**Solution**: Be specific in your messages:
- ✅ "tomorrow at 3pm"
- ✅ "Friday 2pm"
- ✅ "next Monday"
- ❌ "soon"
- ❌ "later"

## Monitoring

### Check Recent Executions

```bash
# Latest execution
./scripts/manage.sh exec-latest

# Workflow-specific history
./scripts/manage.sh exec-workflow telegram-to-notion

# Show failures
./scripts/manage.sh exec-failed
```

### Test Manually

1. Send a test message to your Telegram bot:
   ```
   todo: This is a test task
   ```

2. Check n8n execution in UI or CLI:
   ```bash
   ./scripts/manage.sh exec-latest
   ```

3. Verify task appears in Notion

## Performance Metrics

**Expected Performance**:

| Metric | Target | Notes |
|--------|--------|-------|
| Processing time | 5-15 seconds | Depends on model size |
| Success rate | 95%+ | Occasional parsing failures with complex input |
| Memory usage | 4-8GB | Depends on model |

## Customization

### Add Custom Message Types

Edit the "Filter Message" node to recognize new patterns:

```javascript
// Example: Add "reminder:" prefix
const patterns = [
  /^todo:/i,
  /^meeting:/i,
  /^task:/i,
  /^reminder:/i  // NEW
];
```

### Modify LLM Prompt

Edit the prompt in the LLM node to change behavior:

```
You are a task extraction assistant. Convert natural language messages to structured task data.

Extract:
- Title (brief)
- Description (detailed)
- Due date (if mentioned)
- Priority (High/Medium/Low based on urgency keywords)
- Tags (relevant categories)

Return JSON only.
```

### Change Notion Properties

Edit the "Create Notion Page" node to map different fields.

## Related Documentation

- **Workflow Management**: `docs/workflows/README.md`
- **Investigation System**: `docs/investigation-system.md`
- **Ollama Setup**: `docs/api-setup.md`

## Maintenance

### Export Workflow

```bash
./scripts/manage.sh export-workflows
```

### Backup

```bash
./scripts/backup.sh
```

---

**Last Updated**: 2025-11-09
**Version**: 1.0
**Status**: Production
