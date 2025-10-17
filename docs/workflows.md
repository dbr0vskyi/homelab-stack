# Workflow Guide

Two automated workflows for productivity:

## 📱 Telegram → Notion Tasks

**Purpose**: Convert Telegram messages to structured Notion tasks using AI

**Flow**: Telegram → Ollama AI → Notion → Confirmation

### Setup
1. Import `workflows/telegram-to-notion.json` in n8n
2. Configure:
   - Telegram Bot credentials  
   - Notion API token + database ID
   - Verify Ollama connection
3. Test: Send "todo: Review budget by Friday" to bot

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
1. Import `workflows/gmail-to-telegram.json` in n8n
2. Configure:
   - Gmail OAuth credentials
   - Telegram Bot for summaries
   - Schedule (default: daily 8am)
3. Test: Run workflow manually

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

### Filtering Rules
Edit workflows to customize:
- Email importance detection
- Task extraction patterns
- Summary formats
- Notification preferences

## 📊 Monitoring
- Check n8n execution history
- Monitor via `./scripts/manage.sh logs n8n`
- Test workflows manually before scheduling