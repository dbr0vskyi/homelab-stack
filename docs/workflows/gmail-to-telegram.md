# Gmail to Telegram Workflow

Daily email digest with AI-powered summaries delivered to Telegram.

## Overview

**Workflow File**: `workflows/Gmail to Telegram.json`
**Trigger**: Schedule (Daily at 8am, configurable)
**Status**: Active

## Purpose

Automatically processes unread Gmail messages, generates concise AI summaries, and delivers them as a daily digest to Telegram. This helps you stay on top of important emails without constantly checking your inbox.

## Flow Diagram

```
Schedule Trigger (8am daily)
  → Get Unread Emails (Gmail)
  → Any Emails? (Check)
  → Map Email Fields
  → Clean Email Input (Sanitization)
  → Loop Over Emails
    → Summarize Email with LLM (Ollama)
    → Extract JSON Response
    → Format for Telegram
  → Send Daily Summary (Telegram)
  → Mark Emails as Read (Gmail)
```

## Key Features

### Email Sanitization (v1.1)

The workflow includes comprehensive email sanitization to improve LLM processing:

- **HTML Cleaning**: Removes tags, entities, tracking pixels, base64 images
- **Language Detection**: Identifies Polish, German, French emails and forces English output
- **Promotional Detection**: Identifies marketing/newsletter emails and simplifies them
- **URL Extraction**: Replaces long URLs with placeholders to save tokens
- **Smart Truncation**: Limits to 10,000 chars at sentence boundaries
- **Token Reduction**: 70-80% reduction in token count

**See**: `docs/email-sanitization.md` for complete implementation details

### LLM Configuration

- **Model**: `qwen2.5:7b` (recommended) or `llama3.1:8b`
- **Context Window**: 8,192 tokens (optimized for email processing)
- **Timeout**: 12 hours workflow timeout, extended HTTP timeouts for long-running inference
- **Structured Output**: JSON schema validation for consistent results

### Output Format

Each email is summarized with:
- **Subject**: Original email subject
- **From**: Sender name and email
- **Importance**: Boolean flag for priority emails
- **Summary**: Concise 2-3 sentence overview
- **Category**: Auto-categorized (work, personal, finance, promotion, etc.)
- **Actions**: Extracted actionable items with URLs

## Configuration

### Required Credentials

Configure these in the n8n UI after importing:

1. **Gmail OAuth2**
   - Client ID
   - Client Secret
   - Refresh Token

2. **Telegram Bot**
   - Bot Token (from @BotFather)
   - Chat ID

3. **Ollama** (no credentials needed if using local instance)

### Schedule Customization

Edit the "Schedule Trigger" node to change the execution time:

```javascript
// Default: Daily at 8am
// Cron: 0 8 * * *
```

### Model Selection

Edit the "Summarize Email with LLM" node to change the model:

```json
{
  "model": "qwen2.5:7b",  // Change this
  "options": {
    "num_ctx": 8192
  }
}
```

## Troubleshooting

### Issue: No emails being processed

**Check**:
1. Gmail credentials are valid and authorized
2. Unread emails exist in inbox
3. Check n8n execution logs: `./scripts/manage.sh logs n8n`

### Issue: LLM timeouts

**Solutions**:
1. Verify Ollama is running: `docker compose ps ollama`
2. Check Ollama has sufficient memory (12GB+ recommended)
3. Try a smaller model: `llama3.2:3b`
4. Check timeout patch is loaded in n8n logs

### Issue: Parsing failures (non-JSON responses)

**Causes**:
- Oversized emails overwhelming context window
- Promotional emails confusing the LLM
- Non-English emails triggering wrong language output

**Solutions**:
1. Verify "Clean Email Input" node is connected and active
2. Check sanitization statistics in execution logs
3. Review email-sanitization.md for tuning options

### Issue: Garbled characters in summaries

**Cause**: HTML entity encoding issues

**Solution**:
- Verify Phase 1 improvements are applied (v1.1)
- Check `cleanHTML()` function has comprehensive entity list
- See `docs/email-sanitization-improvements.md`

## Monitoring

### Check Execution History

```bash
# Latest execution
./scripts/manage.sh exec-latest

# Last 10 executions
./scripts/manage.sh exec-history 10

# Workflow-specific history
./scripts/manage.sh exec-workflow gmail-to-telegram

# Show failures
./scripts/manage.sh exec-failed 5
```

### Analyze Execution Details

```bash
# Get execution details
./scripts/manage.sh exec-details <execution-id>

# Extract LLM responses
./scripts/manage.sh exec-llm <execution-id>

# Parse node outputs
./scripts/manage.sh exec-parse <execution-id> --node "Clean Email Input"
```

### Run Investigation

For comprehensive analysis of issues:

```bash
# Quick diagnostic
/diagnose-workflow <execution-id>

# Full investigation with report
/investigate <execution-id>
```

## Performance Metrics

**Expected Performance** (with v1.1 sanitization):

| Metric | Target | Notes |
|--------|--------|-------|
| Processing time | 4-6 min/email | Depends on email size and model |
| Token count | ~1,000-1,500 | After sanitization (70-80% reduction) |
| Schema compliance | 100% | All responses should be valid JSON |
| Memory usage | ~12GB | Per LLM call with 8K context |
| Parsing failures | 0% | Down from 25% pre-sanitization |

## Related Documentation

- **Email Sanitization**: `docs/email-sanitization.md`
- **Improvements Roadmap**: `docs/email-sanitization-improvements.md`
- **Investigation Reports**: `docs/investigations/2025-10-29-workflow-191-llm-parsing-failures.md`
- **Model Analysis**: `docs/model-context-window-analysis.md`
- **Investigation System**: `docs/investigation-system.md`

## Maintenance

### Export Workflow

```bash
./scripts/manage.sh export-workflows
```

### Backup

```bash
./scripts/backup.sh
```

### Update Sanitization

When modifying the "Clean Email Input" node:
1. Test with sample emails first
2. Export workflow after changes
3. Monitor first production run closely
4. Compare execution metrics with baseline

---

**Last Updated**: 2025-11-09
**Version**: 1.1 (includes Phase 1 sanitization improvements)
**Status**: Production
