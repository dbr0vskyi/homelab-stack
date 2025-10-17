# API Setup Guide

Quick setup for Telegram, Notion, and Gmail integrations.

## 🤖 Telegram Bot

1. Message [@BotFather](https://t.me/BotFather)
2. Send `/newbot` → Name your bot → Save token
3. Add `TELEGRAM_BOT_TOKEN=your-token` to `.env`
4. Get your chat ID:
   ```bash
   curl https://api.telegram.org/bot<TOKEN>/getUpdates
   ```

## 📝 Notion API

1. Go to [Notion Developers](https://developers.notion.com/)
2. Create integration → Save token
3. Create database with these properties:
   - **Title** (Title)
   - **Description** (Text)
   - **Status** (Select: To Do, In Progress, Done)
   - **Priority** (Select: High, Medium, Low)
   - **Source** (Select: Telegram, Gmail, Manual)
4. Share database with your integration
5. Add to `.env`:
   ```bash
   NOTION_API_TOKEN=your-token
   NOTION_DATABASE_ID=your-database-id
   ```

## 📧 Gmail API (Optional)

1. [Google Cloud Console](https://console.cloud.google.com)
2. Enable Gmail API
3. Create OAuth2 credentials
4. Add to `.env`:
   ```bash
   GMAIL_CLIENT_ID=your-client-id
   GMAIL_CLIENT_SECRET=your-secret
   GMAIL_REFRESH_TOKEN=your-refresh-token
   ```

## 🔗 Import Workflows

1. Access n8n at http://localhost:5678
2. Import `workflows/telegram-to-notion.json`
3. Import `workflows/gmail-to-telegram.json`
4. Configure API credentials in each workflow
5. Activate workflows

## ✅ Test

- Send message to Telegram bot → Check Notion
- Run Gmail workflow manually → Check Telegram
