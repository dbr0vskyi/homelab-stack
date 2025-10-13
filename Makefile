# Homelab Stack Makefile
# Provides convenient commands for managing the stack

.PHONY: help setup start stop restart status logs backup restore clean update models health

# Default target
help:
	@echo "🏠 Homelab Stack Management"
	@echo "=========================="
	@echo ""
	@echo "Available commands:"
	@echo "  make setup     - Initial setup of the stack"
	@echo "  make start     - Start all services"
	@echo "  make stop      - Stop all services"  
	@echo "  make restart   - Restart all services"
	@echo "  make status    - Show service status"
	@echo "  make logs      - Show logs from all services"
	@echo "  make backup    - Create a backup"
	@echo "  make restore   - Restore from backup"
	@echo "  make update    - Update all container images"
	@echo "  make models    - List available Ollama models"
	@echo "  make health    - Check service health"
	@echo "  make clean     - Clean up unused Docker resources"
	@echo ""
	@echo "Configuration:"
	@echo "  make config    - Edit environment configuration"
	@echo "  make env       - Show current environment"
	@echo ""
	@echo "Development:"
	@echo "  make dev       - Start in development mode with live logs"
	@echo "  make shell     - Open shell in n8n container"
	@echo ""

# Setup and initialization
setup:
	@echo "🚀 Setting up homelab stack..."
	./scripts/setup.sh

# Service management
start:
	@echo "▶️  Starting services..."
	docker compose up -d

stop:
	@echo "⏹️  Stopping services..."
	docker compose down

restart:
	@echo "🔄 Restarting services..."
	docker compose restart

# Monitoring and status
status:
	@./scripts/manage.sh status

logs:
	@docker compose logs -f --tail=50

health:
	@./scripts/manage.sh health

# Data management
backup:
	@echo "💾 Creating backup..."
	./scripts/backup.sh

restore:
	@echo "📥 Restoring from backup..."
	@echo "Usage: make restore BACKUP=backup_file.tar.gz"
	@if [ -z "$(BACKUP)" ]; then \
		echo "Please specify backup file: make restore BACKUP=filename.tar.gz"; \
		ls -la backups/homelab_backup_*.tar.gz 2>/dev/null || echo "No backups found"; \
	else \
		./scripts/restore.sh $(BACKUP); \
	fi

# Updates and maintenance
update:
	@echo "🔄 Updating container images..."
	./scripts/manage.sh update

clean:
	@echo "🧹 Cleaning up unused Docker resources..."
	./scripts/manage.sh clean

# Ollama model management
models:
	@./scripts/manage.sh models

pull-model:
	@echo "📥 Downloading Ollama model..."
	@if [ -z "$(MODEL)" ]; then \
		echo "Usage: make pull-model MODEL=llama3.1:8b"; \
	else \
		./scripts/manage.sh pull $(MODEL); \
	fi

# Configuration management
config:
	@echo "⚙️  Opening configuration file..."
	@if command -v code >/dev/null 2>&1; then \
		code .env; \
	elif command -v nano >/dev/null 2>&1; then \
		nano .env; \
	else \
		echo "Please edit .env file with your preferred editor"; \
	fi

env:
	@echo "🔧 Current environment configuration:"
	@echo "====================================="
	@grep -v "^#" .env 2>/dev/null | grep -v "^$$" | while read line; do \
		key=$$(echo $$line | cut -d'=' -f1); \
		if echo $$key | grep -qE "(PASSWORD|TOKEN|KEY|SECRET)"; then \
			echo "$$key=***HIDDEN***"; \
		else \
			echo "$$line"; \
		fi; \
	done || echo "No .env file found. Run 'make setup' first."

# Development helpers
dev:
	@echo "🔧 Starting in development mode..."
	docker compose up --build

shell:
	@echo "🐚 Opening shell in n8n container..."
	docker exec -it homelab-n8n /bin/sh

shell-postgres:
	@echo "🐚 Opening PostgreSQL shell..."
	docker exec -it homelab-postgres psql -U n8n -d n8n

shell-ollama:
	@echo "🐚 Opening Ollama shell..."
	docker exec -it homelab-ollama /bin/bash

# Service-specific logs
logs-n8n:
	@docker compose logs -f n8n

logs-postgres:
	@docker compose logs -f postgres

logs-ollama:
	@docker compose logs -f ollama

# Optional services
tailscale-start:
	@echo "🔐 Starting Tailscale..."
	docker compose --profile tailscale up -d

tailscale-stop:
	@echo "🔐 Stopping Tailscale..."
	docker compose --profile tailscale down

redis-start:
	@echo "🗄️  Starting Redis..."
	docker compose --profile redis up -d

redis-stop:
	@echo "🗄️  Stopping Redis..."
	docker compose --profile redis down

watchtower-start:
	@echo "👀 Starting Watchtower..."
	docker compose --profile watchtower up -d

watchtower-stop:
	@echo "👀 Stopping Watchtower..."
	docker compose --profile watchtower down

# Security and troubleshooting
reset:
	@echo "⚠️  This will destroy all data!"
	@read -p "Are you sure? Type 'RESET' to confirm: " confirm; \
	if [ "$$confirm" = "RESET" ]; then \
		./scripts/manage.sh reset; \
	else \
		echo "Reset cancelled"; \
	fi

check-docker:
	@echo "🔍 Checking Docker installation..."
	@docker --version || echo "❌ Docker not found"
	@docker compose version || echo "❌ Docker Compose not found"
	@docker info >/dev/null 2>&1 && echo "✅ Docker daemon running" || echo "❌ Docker daemon not running"

test:
	@echo "🧪 Running basic tests..."
	@echo "Testing Docker connectivity..."
	@docker run --rm hello-world >/dev/null 2>&1 && echo "✅ Docker working" || echo "❌ Docker test failed"
	@echo "Testing service connectivity..."
	@curl -s http://localhost:5678/healthz >/dev/null && echo "✅ n8n responding" || echo "ℹ️  n8n not responding (may be starting)"
	@curl -s http://localhost:11434/api/tags >/dev/null && echo "✅ Ollama responding" || echo "ℹ️  Ollama not responding (may be starting)"

# Installation and system prep
install-docker-mac:
	@echo "🍎 Installing Docker on macOS..."
	@if command -v brew >/dev/null 2>&1; then \
		brew install --cask docker; \
	else \
		echo "Please install Homebrew first or download Docker Desktop manually"; \
	fi

install-docker-pi:
	@echo "🥧 Installing Docker on Raspberry Pi..."
	curl -fsSL https://get.docker.com -o get-docker.sh
	sudo sh get-docker.sh
	sudo usermod -aG docker $$USER
	@echo "Please log out and back in for Docker access"

# Documentation
docs:
	@echo "📚 Opening documentation..."
	@if command -v code >/dev/null 2>&1; then \
		code README.md; \
	else \
		echo "Documentation available in:"; \
		echo "  - README.md (main documentation)"; \
		echo "  - docs/api-setup.md (API configuration)"; \
		echo "  - docs/hardware-setup.md (hardware guide)"; \
	fi

# Quick access URLs
open:
	@echo "🌐 Opening web interfaces..."
	@if command -v open >/dev/null 2>&1; then \
		open http://localhost:5678; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open http://localhost:5678; \
	else \
		echo "n8n: http://localhost:5678"; \
		echo "Ollama API: http://localhost:11434"; \
	fi