# Gmail to Telegram Workflow

Daily email digest with AI-powered summaries delivered to Telegram.

## Overview

**Workflow File**: `workflows/Gmail to Telegram.json`
**Trigger**: Schedule (Daily at 2am, configurable)
**Status**: Active

## Purpose

Automatically processes unread Gmail messages, generates concise AI summaries, and delivers them as a daily digest to Telegram. This helps you stay on top of important emails without constantly checking your inbox.

## Flow Diagram

```
Schedule Trigger (2am daily)
  → Get Unread Emails (Gmail)
  → Any Emails? (Check)
  → Map Email Fields
  → Clean Email Input (Sanitization)
  → Loop Over Emails
    → Summarize Email with LLM (Ollama)
    → Parse Structured Text Response
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

**Status**: Fully implemented and battle-tested (100% success rate in recent investigations)

**See**: `docs/email-sanitization.md` for complete implementation details

### LLM Configuration

- **Model**: `llama3.2:3b` (currently configured in workflow)
- **Recommended Models**: `qwen2.5:1.5b` (best choice), `llama3.2:3b` (good balance)
- **Context Window**: 8,192 tokens (optimized for email processing)
- **Timeout**: 12 hours workflow timeout, extended HTTP timeouts for long-running inference
- **Output Format**: Structured text format (avoids JSON parsing errors)

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
// Default: Daily at 2am
// Cron: 0 2 * * *
```

### Model Selection

Edit the "Set model" node to change the model:

```json
{
  "model": "llama3.2:3b" // Default in workflow (1.27 min/email)
  // Recommended alternative:
  // "qwen2.5:1.5b"      // ~0.35 min/email (21x faster)
}
```

**Model Comparison** (based on Investigation 286):

| Model        | Performance    | Memory | Quality   | Recommendation                        |
| ------------ | -------------- | ------ | --------- | ------------------------------------- |
| qwen2.5:1.5b | 0.35 min/email | ~8GB   | Excellent | ⭐ **Best Choice** - Fast & efficient |
| llama3.2:3b  | 1.27 min/email | ~10GB  | Excellent | **Configured in workflow**            |
| qwen2.5:7b   | 7.44 min/email | ~12GB  | Excellent | Oversized for this task               |

**Key Insights:**

- Email summarization is a simple NLP task that doesn't require large models
- Smaller models (1.5-3B params) produce equivalent quality output 5-21x faster
- Context window is adequate across all models (8K tokens configured)
- Current workflow uses `llama3.2:3b` (good balance); `qwen2.5:1.5b` is recommended for best performance

**How to Change:**

1. Open workflow in n8n
2. Find "Set model" node (in the email processing loop)
3. Change the value from `llama3.2:3b` to `qwen2.5:1.5b` for faster execution
4. Save and test with a manual execution

## Troubleshooting

### Issue: No emails being processed

**Check**:

1. Gmail credentials are valid and authorized
2. Unread emails exist in inbox
3. Check n8n execution logs: `./scripts/manage.sh logs n8n`

### Issue: LLM timeouts

**Solutions**:

1. Verify Ollama is running: `docker compose ps ollama`
2. Check Ollama has sufficient memory (8-12GB recommended for qwen2.5:1.5b/3b)
3. Switch to a smaller, faster model: `qwen2.5:1.5b` (21x faster than 7b)
4. Check timeout patch is loaded in n8n logs

**Note**: With proper email sanitization and smaller models, timeouts should be extremely rare.

### Issue: Parsing failures (non-JSON responses)

**Historical Context** (Oct 2025, Investigation 191):

- 25% parsing failures with llama3.2:3b before sanitization
- Promotional emails and non-English content confused the LLM

**Current Status** (Nov 2025):

- ✅ **RESOLVED** with comprehensive email sanitization
- 100% success rate with proper sanitization and text format output
- Workflow now uses structured text format instead of JSON to avoid parsing issues

**If issues occur**:

1. Verify "Clean Email Input" node is connected and active
2. Check sanitization statistics in execution logs
3. Review email-sanitization.md for tuning options

### Issue: Telegram markdown parsing failure

**Cause**: Malformed markdown in email subjects or sender names (Investigation 283)

**Symptoms**:

- Error: `Can't parse entities: Can't find end of the entity starting at byte offset X`
- Workflow succeeds but final summary message fails to send

**Solution**:

1. Check "Format for Telegram" node for unescaped markdown characters
2. Email subjects containing `*`, `_`, `[`, `]` need proper escaping
3. Ensure the node escapes user-generated content before markdown formatting

**Workaround**:

- Individual per-email notifications succeed (properly escaped)
- Only the final aggregated summary message may fail
- Check Telegram for partial results in per-email notifications

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

**Expected Performance** (based on recent investigations):

| Model             | Time/Email | Token Count  | Schema Compliance | Memory Usage | Notes                           |
| ----------------- | ---------- | ------------ | ----------------- | ------------ | ------------------------------- |
| qwen2.5:1.5b      | ~0.35 min  | ~1,000-1,500 | 100%              | ~8GB         | **Recommended** - 21x faster    |
| llama3.2:3b       | ~1.27 min  | ~1,000-1,500 | 100%              | ~10GB        | Good balance                    |
| qwen2.5:7b        | ~7.44 min  | ~1,000-1,500 | 100%              | ~12GB        | Currently configured, oversized |
| llama3.2:3b (old) | ~4-6 min   | ~2,500-4,000 | 75%               | ~12GB        | Before sanitization (Oct 2025)  |

**Historical Context:**

- **Investigation 191 (Oct 29, 2025)**: 25% parsing failures with llama3.2:3b due to lack of email sanitization
- **Investigation 286 (Nov 10, 2025)**: 100% success rate with qwen2.5:7b after sanitization improvements
- **Token reduction**: 70-80% reduction achieved through comprehensive sanitization

**Known Issues (Under Improvement):**

- ⚠️ **High importance rate**: Current workflow and prompt classify ~75% of emails as "important", which reduces filtering effectiveness
- ⚠️ **Category misclassification**: Some emails are categorized incorrectly (e.g., promotional emails marked as personal)
- 🔄 **Status**: These issues are present in the workflow and will be gradually adjusted and tested to improve classification accuracy in future updates

## Related Documentation

- **Email Sanitization**: `docs/email-sanitization.md`
- **Improvements Roadmap**: `docs/email-sanitization-improvements.md`
- **Investigation Reports**:
  - `docs/investigations/2025-10-29-workflow-191-llm-parsing-failures.md` (Historical: Pre-sanitization issues)
  - `docs/investigations/2025-11-02-workflow-200-performance-and-schema-compliance.md` (Performance analysis)
  - `docs/investigations/2025-11-08-workflow-278-performance-degradation.md` (Anomalous slowdown)
  - `docs/investigations/2025-11-09-workflow-283-telegram-markdown-parsing-failure.md` (Telegram formatting issue)
  - `docs/investigations/2025-11-10-workflow-286-performance-baseline.md` (Current baseline with qwen2.5:7b)
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

**Last Updated**: 2025-11-10
**Version**: 1.2 (Updated with findings from investigations 191, 200, 278, 283, 286)
**Status**: Production
