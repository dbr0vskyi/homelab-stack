# Homelab Stack - Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial release of homelab automation stack
- Optimization for Raspberry Pi 5 16GB RAM configuration
- Docker Compose configuration for ARM64 and Apple Silicon
- n8n workflow automation platform
- PostgreSQL database with persistence
- Ollama local LLM integration
- Telegram Bot API integration
- Notion API integration
- Gmail API integration (optional)
- OpenAI API fallback support
- Tailscale secure remote access (optional)
- Redis caching layer (optional)
- Watchtower automatic updates (optional)

### Infrastructure

- Automated setup script with security key generation
- Comprehensive backup and restore system
- Management script for common operations
- Health monitoring and logging
- Docker volume management
- Network security configuration

### Documentation

- Complete setup and configuration guide
- API integration documentation
- Hardware setup guide for Pi 5 and macOS
- Troubleshooting and optimization guides
- Sample workflow templates

### Workflows

- Telegram → LLM → Notion task creation
- Daily Gmail → LLM → Telegram summary delivery
- Automated email processing and intelligent summarization
- Telegram notification system with priority handling

## [1.0.0] - 2024-01-01

### Added

- Initial stable release
- Production-ready configuration
- Comprehensive documentation
- Sample workflows and templates
