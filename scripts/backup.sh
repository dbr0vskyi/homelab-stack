#!/bin/bash

# Homelab Stack Backup Script
# Creates backups of all persistent data

set -e

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="homelab_backup_$TIMESTAMP"
COMPOSE_PROJECT="homelab"

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

# Create backup directory
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

log_info "Starting backup: $BACKUP_NAME"

# Backup PostgreSQL database
log_info "Backing up PostgreSQL database..."
docker exec homelab-postgres pg_dump -U n8n n8n > "$BACKUP_DIR/$BACKUP_NAME/postgres_backup.sql"
log_success "PostgreSQL backup complete"

# Backup n8n data
log_info "Backing up n8n data..."
docker run --rm -v homelab_n8n_data:/data -v "$(pwd)/$BACKUP_DIR/$BACKUP_NAME":/backup alpine tar czf /backup/n8n_data.tar.gz -C /data .
log_success "n8n data backup complete"

# Backup Ollama models and data
log_info "Backing up Ollama data..."
docker run --rm -v homelab_ollama_data:/data -v "$(pwd)/$BACKUP_DIR/$BACKUP_NAME":/backup alpine tar czf /backup/ollama_data.tar.gz -C /data .
log_success "Ollama data backup complete"

# Backup configuration files
log_info "Backing up configuration files..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME/config_backup.tar.gz" config/ workflows/ .env docker-compose.yml 2>/dev/null || true
log_success "Configuration backup complete"

# Create backup metadata
cat > "$BACKUP_DIR/$BACKUP_NAME/backup_info.txt" << EOF
Homelab Stack Backup
====================
Backup Date: $(date)
Backup Name: $BACKUP_NAME
Hostname: $(hostname)
Docker Version: $(docker --version)
Services Status:
$(docker compose ps)

Backup Contents:
- postgres_backup.sql: PostgreSQL database dump
- n8n_data.tar.gz: n8n workflows and data
- ollama_data.tar.gz: Ollama models and data
- config_backup.tar.gz: Configuration files and workflows

Restore Instructions:
1. Stop all services: docker compose down
2. Restore volumes using restore.sh script
3. Start services: docker compose up -d
EOF

# Create compressed archive
log_info "Creating compressed backup archive..."
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME/"
rm -rf "$BACKUP_NAME"
cd - > /dev/null

# Cleanup old backups (keep last 7 by default)
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}
log_info "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "homelab_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

BACKUP_SIZE=$(du -h "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" | cut -f1)
log_success "Backup complete: ${BACKUP_NAME}.tar.gz ($BACKUP_SIZE)"

# Optional: Upload to cloud storage
if [[ -n "${BACKUP_UPLOAD_CMD:-}" ]]; then
    log_info "Uploading backup to cloud storage..."
    eval "$BACKUP_UPLOAD_CMD '$BACKUP_DIR/${BACKUP_NAME}.tar.gz'" || log_error "Backup upload failed"
fi