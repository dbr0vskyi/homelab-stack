# Homelab Stack - Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Docker Compose**: Removed deprecated `version: '3.8'` specification for Docker Compose v2 compatibility
- **Setup Script**: Enhanced Docker daemon detection and automatic startup on macOS
- **Setup Script**: Improved error handling with detailed failure messages and recovery instructions
- **Setup Script**: Added automatic Docker Desktop startup for macOS users
- **Setup Script**: Enhanced volume creation with better error handling and status messages
- **Setup Script**: Improved service startup sequence with proper error checking and conditional optional services

### Fixed

- **Setup Script**: Docker daemon availability check now properly detects and starts Docker Desktop on macOS
- **Setup Script**: Better handling of Docker volume creation with existing volume detection
- **Setup Script**: More robust service startup with individual error handling for each service
- **Setup Script**: Fixed compatibility with modern Docker installations by replacing deprecated `docker-compose` commands with `docker compose`

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
