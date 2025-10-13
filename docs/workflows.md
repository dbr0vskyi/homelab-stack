# Workflow Configuration Guide

## Overview

The homelab stack includes two main automated workflows designed to streamline personal productivity:

1. **Telegram → Notion**: Interactive task creation via Telegram messages
2. **Gmail → Telegram**: Automated email analysis and intelligent summaries

## Workflow 1: Telegram → Notion Task Creation

### Description

Converts messages sent to your Telegram bot into structured tasks in a Notion database using local AI analysis.

### Process Flow

```
Telegram Message → AI Analysis (Ollama) → Structured Data → Notion Task → Confirmation
```

### Configuration Steps

#### 1. Import Workflow

1. Access n8n at `http://localhost:5678`
2. Click "Import from file"
3. Select `workflows/telegram-to-notion.json`
4. Click "Import"

#### 2. Configure Credentials

- **Telegram Bot API**: Add your bot token and configure webhook
- **Notion API**: Add integration token and database ID
- **Ollama**: Verify connection to `http://ollama:11434`

#### 3. Test the Workflow

Send a message to your Telegram bot:

```
"todo: Review the quarterly budget report by Friday"
```

Expected result:

- AI extracts: title, priority, due date
- Creates Notion task with structured data
- Sends confirmation back to Telegram

### Message Formats

The AI can understand various formats:

- `"todo: Task description"`
- `"remind me to call John tomorrow"`
- `"high priority: Fix the server issue"`
- `"add task: Schedule team meeting for next week"`

## Workflow 2: Gmail → Telegram Intelligence

### Description

Automatically scans Gmail daily for important emails, analyzes them with AI, and sends intelligent summaries to Telegram.

### Process Flow

```
Gmail Scan → Email Filtering → AI Analysis → Formatted Summary → Telegram Delivery
```

### Key Features

#### Smart Email Filtering

Identifies actionable emails using keywords:

- `action required`, `please review`, `urgent`, `deadline`
- `follow up`, `response needed`, `approval`, `feedback`
- `meeting`, `schedule`, `reminder`, `invoice`, `payment`
- `security`, `alert`, `verification`, `confirm`

#### AI-Powered Analysis

- Uses Qwen2.5:7B model for email summarization
- Extracts key information and action items
- Determines urgency and priority level
- Keeps summaries concise (under 200 words)

#### Rich Telegram Formatting

- **Priority indicators**: 🔴 for urgent, 📧 for regular
- **Structured layout**: From, Subject, Summary, Gmail link
- **Daily statistics**: Total emails processed, important count

### Configuration Steps

#### 1. Import Workflow

1. Access n8n at `http://localhost:5678`
2. Import `workflows/gmail-to-telegram.json`
3. Verify schedule is set to daily at 8 AM (`0 8 * * *`)

#### 2. Configure Gmail OAuth2

- Set up Google Cloud Console project
- Enable Gmail API
- Create OAuth2 credentials
- Add credentials to n8n

#### 3. Configure Telegram Delivery

- Use same Telegram bot as workflow 1
- Verify chat ID is correct
- Test message formatting

### Sample Output

```
🔴 **Email Summary**

**From:** Sarah Johnson
**Subject:** Urgent: Client presentation moved to tomorrow
**Received:** Oct 13, 2025, 9:15 AM

**Summary:**
Client has requested to move the quarterly review presentation from Friday to tomorrow (Thursday) at 2 PM. Need to prepare slides for the new timeline and confirm availability of all team members. Action required: Reply by EOD today.

[Open in Gmail](https://mail.google.com/mail/u/0/#inbox/abc123)
```

## Advanced Configuration

### Model Selection for Different Hardware

#### Pi 5 4GB RAM

```bash
# Lightweight models in workflows
- Use: llama3.2:1b for basic analysis
- Avoid: Models larger than 3B parameters
```

#### Pi 5 8GB RAM

```bash
# Balanced performance
- Use: llama3.1:8b, qwen2.5:7b
- Good for: Most email analysis tasks
```

#### Pi 5 16GB RAM (Recommended)

```bash
# High-performance models
- Use: qwen2.5:14b for email analysis
- Use: llama3.1:8b for task creation
- Use: codellama:13b for technical emails
- Benefit: Multiple models loaded simultaneously
```

### Workflow Customization

#### Email Filtering Customization

Edit the "Process Emails" node in Gmail workflow:

```javascript
// Add custom keywords for your domain
const customKeywords = [
  "budget approval",
  "contract review",
  "meeting request",
  "invoice due",
  "project update",
  "client feedback",
];

const allKeywords = [...importantKeywords, ...customKeywords];
```

#### Telegram Message Formatting

Customize the "Format for Telegram" node:

```javascript
// Add custom emoji and formatting
const priorityEmoji = emailData.isImportant ? '🚨' : '📧';
const urgencyLevel = determineUrgency(summary); // Add custom function

const message = `${priorityEmoji} **${urgencyLevel} Email**\\n\\n` +
  `**From:** ${fromName}\\n` +
  // ... rest of formatting
```

#### Schedule Adjustment

Modify the schedule trigger for different times:

- `0 7 * * *` - 7 AM daily
- `0 9,17 * * *` - 9 AM and 5 PM daily
- `0 8 * * 1-5` - 8 AM weekdays only

### Performance Optimization

#### For Pi 5 16GB RAM

```bash
# Environment variables for optimal performance
OLLAMA_MAX_LOADED_MODELS=3
OLLAMA_NUM_PARALLEL=2
OLLAMA_KEEP_ALIVE=24h

# Docker resource limits
deploy:
  resources:
    limits:
      memory: 12G
    reservations:
      memory: 4G
```

#### Memory Management

- **Load balancing**: Distribute different models across workflows
- **Model rotation**: Unload unused models automatically
- **Caching**: Keep frequently used models in memory

## Monitoring and Maintenance

### Workflow Health Checks

```bash
# Check workflow execution history in n8n
# Navigate to: Executions → View execution logs

# Monitor Ollama model performance
docker logs homelab-ollama --tail=50

# Check Telegram API rate limits
curl https://api.telegram.org/bot${BOT_TOKEN}/getMe
```

### Common Issues and Solutions

#### Gmail Workflow Not Running

1. **Check Gmail API quota**: Ensure daily limits not exceeded
2. **Verify OAuth2 tokens**: Refresh tokens if expired
3. **Check email filters**: Ensure query syntax is correct
4. **Monitor execution logs**: Look for API errors in n8n

#### Telegram Messages Not Sending

1. **Verify bot token**: Test with direct API call
2. **Check chat ID**: Ensure correct recipient
3. **Rate limiting**: Telegram allows 30 messages/second max
4. **Message size**: Keep under 4096 characters

#### Ollama Performance Issues

1. **Model size**: Use appropriate model for available RAM
2. **Concurrent requests**: Limit parallel processing
3. **Temperature monitoring**: Check Pi 5 CPU temperature
4. **Memory pressure**: Monitor for OOM kills

### Backup and Recovery

#### Workflow Backup

```bash
# Export workflows from n8n
# Go to Settings → Import/Export → Export workflows

# Store workflow JSON files in version control
git add workflows/
git commit -m "Update workflow configurations"
```

#### Credential Backup

```bash
# Backup n8n credentials (encrypted)
docker exec homelab-n8n cp -r /home/node/.n8n/credentials.json /backup/

# Restore credentials
docker exec homelab-n8n cp /backup/credentials.json /home/node/.n8n/
```

## Integration Extensions

### Adding New Email Providers

- **Outlook**: Use Microsoft Graph API
- **Yahoo**: Use Yahoo Mail API
- **IMAP**: Generic IMAP integration for any provider

### Adding New Messaging Platforms

- **Discord**: Use Discord webhook integration
- **Slack**: Use Slack bot API
- **SMS**: Use Twilio or similar service

### Custom LLM Integration

- **OpenAI**: Fallback for complex analysis
- **Anthropic Claude**: Alternative AI provider
- **Local models**: Additional Ollama models for specialized tasks

## Security Considerations

### API Token Management

- Rotate tokens quarterly
- Use environment variables only
- Monitor API usage for anomalies
- Implement rate limiting

### Data Privacy

- Email content processed locally via Ollama
- No data sent to external AI services by default
- Telegram messages encrypted in transit
- Notion data stored securely

### Network Security

- All integrations use HTTPS/TLS
- Local network isolation for containers
- Optional VPN access via Tailscale
- Regular security updates

This workflow system provides a powerful foundation for personal automation while maintaining privacy and security through local AI processing.
