# API Integration Guide

## Overview

This guide covers setting up API integrations for the homelab automation stack. The stack includes two main workflows:

1. **Telegram → Notion**: Messages sent to Telegram bot are processed by AI and converted to Notion tasks
2. **Gmail → Telegram**: Daily Gmail scan analyzes emails with AI and sends summaries to Telegram

## Telegram Bot Setup (Primary Integration)

**Note**: Telegram serves dual purposes - receiving task creation commands AND receiving daily Gmail summaries.

### 1. Create Bot with BotFather

### 1. Create Bot with BotFather

1. Start a chat with [@BotFather](https://t.me/BotFather)
2. Send `/newbot` command
3. Follow the prompts to name your bot
4. Save the bot token provided

### 2. Get Chat ID

```bash
# Method 1: Send a message to your bot, then call:
curl https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates

# Method 2: Use @userinfobot to get your user ID
```

### 3. Set Webhook in n8n

1. Import the Telegram workflow
2. Configure the webhook URL in n8n
3. Test with a message to your bot

## Notion API Setup

### 1. Create Integration

1. Go to [Notion Developers](https://developers.notion.com/)
2. Click "New integration"
3. Name it "Homelab Automation"
4. Save the internal integration token

### 2. Create Task Database

1. Create a new page in Notion
2. Add a database with this structure:

```json
{
  "Title": { "type": "title" },
  "Description": { "type": "rich_text" },
  "Status": {
    "type": "select",
    "options": ["To Do", "In Progress", "Done"]
  },
  "Priority": {
    "type": "select",
    "options": ["High", "Medium", "Low"]
  },
  "Source": {
    "type": "select",
    "options": ["Telegram", "Gmail", "Manual"]
  },
  "Created": { "type": "date" },
  "Due Date": { "type": "date" }
}
```

### 3. Share Database with Integration

1. Click "Share" on your database
2. Invite your integration
3. Copy the database ID from the URL

## Gmail API Setup (For AI Email Analysis)

**Purpose**: Gmail integration scans your inbox daily and sends AI-generated summaries to Telegram.

**What it does**:

- Scans for unread emails in the last 24 hours
- Identifies important/actionable emails using keyword filtering
- Processes each email through local AI for intelligent summarization
- Sends formatted summaries to Telegram with priority indicators
- Provides daily statistics (total emails, important count)

### 1. Google Cloud Console Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Gmail API
4. Go to "Credentials" → "Create Credentials" → "OAuth 2.0"

### 2. OAuth Configuration

1. Set application type to "Desktop application"
2. Add authorized redirect URIs:

   - `http://localhost`
   - `urn:ietf:wg:oauth:2.0:oob`

3. Download credentials JSON file

### 3. Get Refresh Token

Use this Python script to get refresh token:

```python
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']

def get_refresh_token():
    flow = InstalledAppFlow.from_client_secrets_file(
        'credentials.json', SCOPES)
    creds = flow.run_local_server(port=0)

    print(f"Refresh Token: {creds.refresh_token}")
    print(f"Client ID: {creds.client_id}")
    print(f"Client Secret: {creds.client_secret}")

if __name__ == '__main__':
    get_refresh_token()
```

## OpenAI API Setup

### 1. Get API Key

1. Go to [OpenAI Platform](https://platform.openai.com/)
2. Navigate to API Keys
3. Create new secret key
4. Set usage limits and billing

### 2. Configure in Environment

```bash
OPENAI_API_KEY=sk-your-key-here
OPENAI_MODEL=gpt-4o-mini
```

## Tailscale Setup (Optional)

### 1. Account Setup

1. Create account at [Tailscale](https://tailscale.com/)
2. Generate auth key in admin panel
3. Set key type to "Reusable" and "Ephemeral"

### 2. Configuration

```bash
# Add to .env
TAILSCALE_AUTH_KEY=tskey-auth-your-key
TAILSCALE_HOSTNAME=homelab

# Start with profile
docker compose --profile tailscale up -d
```

### 3. Access Services

Once connected to Tailscale network:

- n8n: `https://homelab.your-tailnet.ts.net`
- Direct IP access also works

## Security Best Practices

### API Key Management

1. **Rotate keys quarterly**
2. **Use environment variables only**
3. **Never commit secrets to git**
4. **Monitor API usage and billing**

### Access Control

```bash
# Limit n8n access by IP (in docker-compose.yml)
ports:
  - "127.0.0.1:5678:5678"

# Use strong passwords
N8N_PASSWORD=$(openssl rand -base64 32)
```

### Network Security

```bash
# Firewall rules (ufw on Ubuntu/Raspberry Pi OS)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 5678/tcp  # Only if needed externally
sudo ufw enable
```

## Testing Integrations

### Test Telegram Bot (Both Directions)

```bash
# Test sending TO Telegram (for Gmail summaries)
curl -X POST \
  https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage \
  -H 'Content-Type: application/json' \
  -d '{
    "chat_id": "YOUR_CHAT_ID",
    "text": "🔴 **Test Email Summary**\n\n**From:** test@example.com\n**Subject:** Test Email\n\n**Summary:** This is a test email summary from your homelab stack.",
    "parse_mode": "Markdown"
  }'

# Test receiving FROM Telegram (for task creation)
# Send a message like "todo: Review project documentation" to your bot
```

### Test Notion API

```bash
# List databases
curl -X GET \
  https://api.notion.com/v1/databases \
  -H "Authorization: Bearer ${NOTION_API_TOKEN}" \
  -H "Notion-Version: 2022-06-28"
```

### Test Gmail API

```python
import requests

def test_gmail_api():
    # Exchange refresh token for access token
    token_url = "https://oauth2.googleapis.com/token"
    data = {
        'client_id': 'YOUR_CLIENT_ID',
        'client_secret': 'YOUR_CLIENT_SECRET',
        'refresh_token': 'YOUR_REFRESH_TOKEN',
        'grant_type': 'refresh_token'
    }

    response = requests.post(token_url, data=data)
    access_token = response.json()['access_token']

    # Test API call
    headers = {'Authorization': f'Bearer {access_token}'}
    gmail_response = requests.get(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages',
        headers=headers,
        params={'q': 'is:unread', 'maxResults': 1}
    )

    print("Gmail API Response:", gmail_response.json())

test_gmail_api()
```

### Test Gmail → Telegram Workflow

```bash
# Test the complete Gmail analysis workflow
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:7b",
    "prompt": "Analyze this email and create a concise summary. Focus on key information, urgency, and any required actions. Keep it under 200 words.\n\nFrom: boss@company.com\nSubject: Urgent: Project deadline moved to Friday\nContent: Hi team, due to client requirements, we need to move the project deadline from next Monday to this Friday. Please prioritize and let me know if you need help.\n\nProvide a clear, actionable summary:",
    "stream": false
  }'

# Check workflow execution in n8n
# 1. Go to http://localhost:5678
# 2. Navigate to "Gmail to Telegram" workflow
# 3. Click "Test workflow" to run manually
# 4. Check Telegram for summary message
```

### Test Ollama API Performance (16GB Pi 5)

```bash
# Test model availability
curl http://localhost:11434/api/tags

# Test multiple models simultaneously (16GB capability)
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:14b",
    "prompt": "Analyze this complex email and provide detailed insights",
    "stream": false
  }' &

curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.1:8b",
    "prompt": "Process this simple task request",
    "stream": false
  }' &

wait  # Wait for both to complete
```

## Troubleshooting API Issues

### Common Problems

#### Gmail → Telegram Workflow Issues

```bash
# Check if Gmail API is working
curl -H "Authorization: Bearer $(get_access_token)" \
  https://gmail.googleapis.com/gmail/v1/users/me/messages?q=is:unread

# Verify Telegram bot can send messages
curl -X POST \
  https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage \
  -d "chat_id=${TELEGRAM_CHAT_ID}&text=Test from API"

# Check Ollama model status for email analysis
curl http://localhost:11434/api/tags | grep qwen2.5

# Debug workflow in n8n
# 1. Open n8n at localhost:5678
# 2. Go to "Gmail to Telegram" workflow
# 3. Check execution history for errors
# 4. Verify all nodes are properly connected
```

#### Telegram Webhook Issues

```bash
# Check webhook status
curl https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getWebhookInfo

# Delete webhook if needed
curl https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/deleteWebhook
```

#### Notion API Errors

- Check database permissions
- Verify property names match exactly
- Ensure integration has access to database

#### Gmail OAuth Issues

- Check redirect URIs in Google Console
- Verify scopes match requirements
- Refresh tokens expire if unused for 6 months

#### Ollama Connection Problems

```bash
# Check if model is loaded
docker exec homelab-ollama ollama ps

# Restart Ollama service
docker restart homelab-ollama

# Check memory usage
docker stats homelab-ollama
```

### Debug Mode

Enable debug logging in n8n:

```bash
# Add to .env
N8N_LOG_LEVEL=debug

# Restart n8n
docker restart homelab-n8n

# View detailed logs
docker logs -f homelab-n8n
```
