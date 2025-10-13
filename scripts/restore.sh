#!/bin/bash

# Homelab Stack Restore Script
# Restores data from backup

set -e

# Configuration
BACKUP_DIR="./backups"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if backup file is provided
if [[ -z "$1" ]]; then
    echo "Usage: $0 <backup_file.tar.gz>"
    echo "Available backups:"
    ls -la "$BACKUP_DIR"/homelab_backup_*.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [[ ! -f "$BACKUP_FILE" ]]; then
    # Try to find it in backup directory
    if [[ -f "$BACKUP_DIR/$BACKUP_FILE" ]]; then
        BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
    else
        log_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
fi

log_info "Restoring from backup: $(basename "$BACKUP_FILE")"

# Confirm with user
read -p "This will overwrite existing data. Are you sure? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Restore cancelled"
    exit 0
fi

# Stop services
log_info "Stopping services..."
docker compose down

# Extract backup
TEMP_DIR=$(mktemp -d)
log_info "Extracting backup to $TEMP_DIR"
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

BACKUP_NAME=$(basename "$BACKUP_FILE" .tar.gz)
EXTRACT_DIR="$TEMP_DIR/$BACKUP_NAME"

# Restore PostgreSQL
if [[ -f "$EXTRACT_DIR/postgres_backup.sql" ]]; then
    log_info "Restoring PostgreSQL database..."
    
    # Start only PostgreSQL
    docker compose up -d postgres
    sleep 10
    
    # Drop and recreate database
    docker exec homelab-postgres psql -U n8n -c "DROP DATABASE IF EXISTS n8n;"
    docker exec homelab-postgres psql -U n8n -c "CREATE DATABASE n8n;"
    
    # Restore data
    docker exec -i homelab-postgres psql -U n8n n8n < "$EXTRACT_DIR/postgres_backup.sql"
    log_success "PostgreSQL restore complete"
    
    docker compose down
fi

# Restore n8n data
if [[ -f "$EXTRACT_DIR/n8n_data.tar.gz" ]]; then
    log_info "Restoring n8n data..."
    docker volume rm homelab_n8n_data 2>/dev/null || true
    docker volume create homelab_n8n_data
    docker run --rm -v homelab_n8n_data:/data -v "$EXTRACT_DIR":/backup alpine tar xzf /backup/n8n_data.tar.gz -C /data
    log_success "n8n data restore complete"
fi

# Restore Ollama data
if [[ -f "$EXTRACT_DIR/ollama_data.tar.gz" ]]; then
    log_info "Restoring Ollama data..."
    docker volume rm homelab_ollama_data 2>/dev/null || true
    docker volume create homelab_ollama_data
    docker run --rm -v homelab_ollama_data:/data -v "$EXTRACT_DIR":/backup alpine tar xzf /backup/ollama_data.tar.gz -C /data
    log_success "Ollama data restore complete"
fi

# Restore configuration (optional)
if [[ -f "$EXTRACT_DIR/config_backup.tar.gz" ]]; then
    read -p "Restore configuration files? This will overwrite current config. (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restoring configuration files..."
        tar -xzf "$EXTRACT_DIR/config_backup.tar.gz" -C . --exclude='.env'
        log_success "Configuration restore complete"
        log_warning "Please review your .env file for any needed updates"
    fi
fi

# Cleanup
rm -rf "$TEMP_DIR"

# Start services
log_info "Starting services..."
docker compose up -d

log_success "Restore complete!"
log_info "Services should be starting up. Check status with: docker compose ps"