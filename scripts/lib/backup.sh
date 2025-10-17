#!/bin/bash

# Backup Operations Library
# Common backup and restore operations for homelab stack

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/docker.sh"

# Backup configuration
DEFAULT_BACKUP_DIR="./backups"
DEFAULT_RETENTION_DAYS=7

# Backup metadata operations
create_backup_metadata() {
    local backup_dir="$1"
    local backup_name="$2"
    
    if [[ -z "$backup_dir" || -z "$backup_name" ]]; then
        log_error "Backup directory and name are required"
        return 1
    fi
    
    log_info "Creating backup metadata..."
    
    cat > "$backup_dir/$backup_name/backup_info.txt" << EOF
Homelab Stack Backup
====================
Backup Date: $(date)
Backup Name: $backup_name
Hostname: $(hostname)
Docker Version: $(docker --version)
Services Status:
$(docker compose ps)

Backup Contents:
- postgres_backup.sql: PostgreSQL database dump
- n8n_data.tar.gz: n8n workflows and data
- ollama_models.txt: List of installed Ollama models (for re-download)
- config_backup.tar.gz: Configuration files and workflows

Note: Ollama model data is NOT backed up due to large size.
Models can be re-downloaded using the included models list.

Restore Instructions:
1. Stop all services: docker compose down
2. Restore volumes using restore.sh script
3. Start services: docker compose up -d
4. Re-download Ollama models: ./scripts/setup.sh models
EOF
}

# Database backup operations
backup_postgres_database() {
    local backup_dir="$1"
    local container_name="${2:-homelab-postgres}"
    local database_name="${3:-n8n}"
    local username="${4:-n8n}"
    
    if [[ -z "$backup_dir" ]]; then
        log_error "Backup directory is required"
        return 1
    fi
    
    log_info "Backing up PostgreSQL database..."
    
    if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        log_error "PostgreSQL container $container_name is not running"
        return 1
    fi
    
    docker exec "$container_name" pg_dump -U "$username" "$database_name" > "$backup_dir/postgres_backup.sql"
    
    if [[ $? -eq 0 ]]; then
        log_success "PostgreSQL backup complete"
    else
        log_error "PostgreSQL backup failed"
        return 1
    fi
}

restore_postgres_database() {
    local backup_file="$1"
    local container_name="${2:-homelab-postgres}"
    local database_name="${3:-n8n}"
    local username="${4:-n8n}"
    
    if [[ -z "$backup_file" || ! -f "$backup_file" ]]; then
        log_error "Valid backup file is required"
        return 1
    fi
    
    log_info "Restoring PostgreSQL database..."
    
    # Start only PostgreSQL if not running
    if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        compose_up "postgres"
        wait_for_service_healthy "postgres" 30
    fi
    
    # Drop and recreate database
    docker exec "$container_name" psql -U "$username" -c "DROP DATABASE IF EXISTS $database_name;"
    docker exec "$container_name" psql -U "$username" -c "CREATE DATABASE $database_name;"
    
    # Restore data
    docker exec -i "$container_name" psql -U "$username" "$database_name" < "$backup_file"
    
    if [[ $? -eq 0 ]]; then
        log_success "PostgreSQL restore complete"
    else
        log_error "PostgreSQL restore failed"
        return 1
    fi
}

# Volume backup operations
backup_homelab_volumes() {
    local backup_dir="$1"
    
    if [[ -z "$backup_dir" ]]; then
        log_error "Backup directory is required"
        return 1
    fi
    
    # Backup n8n data
    log_info "Backing up n8n data..."
    backup_volume_to_tar "homelab_n8n_data" "$backup_dir/n8n_data.tar.gz"
    
    if [[ $? -eq 0 ]]; then
        log_success "n8n data backup complete"
    else
        log_error "n8n data backup failed"
        return 1
    fi
    
    # Backup Ollama model list (not the data - too large)
    log_info "Backing up Ollama models list..."
    backup_ollama_models_list "$backup_dir"
}

restore_homelab_volumes() {
    local backup_dir="$1"
    
    if [[ -z "$backup_dir" ]]; then
        log_error "Backup directory is required"
        return 1
    fi
    
    # Restore n8n data
    if [[ -f "$backup_dir/n8n_data.tar.gz" ]]; then
        log_info "Restoring n8n data..."
        restore_volume_from_tar "homelab_n8n_data" "$backup_dir/n8n_data.tar.gz"
        
        if [[ $? -eq 0 ]]; then
            log_success "n8n data restore complete"
        else
            log_error "n8n data restore failed"
            return 1
        fi
    else
        log_warning "n8n backup file not found, skipping"
    fi
    
    # Skip Ollama data restoration (models will be re-downloaded)
    if [[ -f "$backup_dir/ollama_models.txt" ]]; then
        log_info "Ollama models list found - models can be restored using: ./scripts/setup.sh models"
        log_info "Available models to restore:"
        while IFS= read -r model; do
            log_info "  - $model"
        done < "$backup_dir/ollama_models.txt"
    else
        log_warning "No Ollama models list found in backup"
    fi
}

# Ollama model list backup operations
backup_ollama_models_list() {
    local backup_dir="$1"
    
    if [[ -z "$backup_dir" ]]; then
        log_error "Backup directory is required"
        return 1
    fi
    
    # Check if Ollama container is running
    if ! docker ps --format "{{.Names}}" | grep -q "^homelab-ollama$"; then
        log_warning "Ollama container not running, cannot backup models list"
        echo "# Ollama was not running during backup" > "$backup_dir/ollama_models.txt"
        return 0
    fi
    
    # Get list of installed models
    if docker exec homelab-ollama ollama list --format json 2>/dev/null | jq -r '.[].name' > "$backup_dir/ollama_models.txt" 2>/dev/null; then
        local model_count=$(wc -l < "$backup_dir/ollama_models.txt")
        log_success "Ollama models list backup complete ($model_count models)"
        log_info "Models can be restored after setup using: ./scripts/setup.sh models"
    else
        # Fallback to plain text format if JSON parsing fails
        if docker exec homelab-ollama ollama list 2>/dev/null | awk 'NR>1 {print $1}' > "$backup_dir/ollama_models.txt"; then
            local model_count=$(wc -l < "$backup_dir/ollama_models.txt")
            log_success "Ollama models list backup complete ($model_count models)"
        else
            log_warning "Could not backup Ollama models list"
            echo "# Could not retrieve models list during backup" > "$backup_dir/ollama_models.txt"
        fi
    fi
}

# Configuration backup operations
backup_configuration_files() {
    local backup_dir="$1"
    local config_items="${2:-config/ workflows/ .env docker-compose.yml}"
    
    if [[ -z "$backup_dir" ]]; then
        log_error "Backup directory is required"
        return 1
    fi
    
    log_info "Backing up configuration files..."
    
    # Create config backup with error handling
    if tar -czf "$backup_dir/config_backup.tar.gz" $config_items 2>/dev/null; then
        log_success "Configuration backup complete"
    else
        log_warning "Some configuration files may be missing, backup created with available files"
    fi
}

restore_configuration_files() {
    local backup_file="$1"
    local confirm="${2:-prompt}"
    
    if [[ -z "$backup_file" || ! -f "$backup_file" ]]; then
        log_error "Valid backup file is required"
        return 1
    fi
    
    if [[ "$confirm" == "prompt" ]]; then
        read -p "Restore configuration files? This will overwrite current config. (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Configuration restore skipped"
            return 0
        fi
    fi
    
    log_info "Restoring configuration files..."
    
    # Restore config excluding .env to prevent overwriting sensitive data
    if tar -xzf "$backup_file" -C . --exclude='.env' 2>/dev/null; then
        log_success "Configuration restore complete"
        log_warning "Please review your .env file for any needed updates"
    else
        log_error "Configuration restore failed"
        return 1
    fi
}

# Full backup operations
create_full_backup() {
    local backup_name="${1:-homelab_backup_$(date +"%Y%m%d_%H%M%S")}"
    local backup_dir="${2:-$DEFAULT_BACKUP_DIR}"
    
    log_info "Starting backup: $backup_name"
    
    # Create backup directory
    mkdir -p "$backup_dir/$backup_name"
    
    # Backup database
    backup_postgres_database "$backup_dir/$backup_name" || return 1
    
    # Backup volumes
    backup_homelab_volumes "$backup_dir/$backup_name" || return 1
    
    # Backup configuration
    backup_configuration_files "$backup_dir/$backup_name" || return 1
    
    # Create metadata
    create_backup_metadata "$backup_dir" "$backup_name" || return 1
    
    # Create compressed archive
    log_info "Creating compressed backup archive..."
    cd "$backup_dir"
    tar -czf "${backup_name}.tar.gz" "$backup_name/"
    rm -rf "$backup_name"
    cd - > /dev/null
    
    local backup_size=$(du -h "$backup_dir/${backup_name}.tar.gz" | cut -f1)
    log_success "Backup complete: ${backup_name}.tar.gz ($backup_size)"
    
    return 0
}

restore_full_backup() {
    local backup_file="$1"
    local confirm="${2:-prompt}"
    
    if [[ -z "$backup_file" ]]; then
        log_error "Backup file is required"
        return 1
    fi
    
    # Try to find backup file if not absolute path
    if [[ ! -f "$backup_file" ]]; then
        if [[ -f "$DEFAULT_BACKUP_DIR/$backup_file" ]]; then
            backup_file="$DEFAULT_BACKUP_DIR/$backup_file"
        else
            log_error "Backup file not found: $backup_file"
            return 1
        fi
    fi
    
    log_info "Restoring from backup: $(basename "$backup_file")"
    
    if [[ "$confirm" == "prompt" ]]; then
        read -p "This will overwrite existing data. Are you sure? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Restore cancelled"
            return 0
        fi
    fi
    
    # Stop services
    compose_down
    
    # Extract backup
    local temp_dir=$(mktemp -d)
    log_info "Extracting backup to $temp_dir"
    tar -xzf "$backup_file" -C "$temp_dir"
    
    local backup_name=$(basename "$backup_file" .tar.gz)
    local extract_dir="$temp_dir/$backup_name"
    
    # Restore database
    if [[ -f "$extract_dir/postgres_backup.sql" ]]; then
        restore_postgres_database "$extract_dir/postgres_backup.sql" || return 1
        compose_down  # Stop postgres after restore
    fi
    
    # Restore volumes
    restore_homelab_volumes "$extract_dir" || return 1
    
    # Restore configuration
    if [[ -f "$extract_dir/config_backup.tar.gz" ]]; then
        restore_configuration_files "$extract_dir/config_backup.tar.gz" "$confirm"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Start services
    compose_up
    
    log_success "Restore complete!"
    log_info "Services should be starting up. Check status with: docker compose ps"
    
    # Provide instructions for Ollama models
    if [[ -f "$extract_dir/ollama_models.txt" ]]; then
        echo
        log_info "📦 Ollama Models Restoration:"
        log_info "Your backup includes a list of Ollama models that can be restored."
        log_info "To restore all models automatically, run:"
        log_info "  ./scripts/manage.sh restore-models '$extract_dir/ollama_models.txt'"
        log_info "Or restore models manually using the setup script:"
        log_info "  ./scripts/setup.sh models"
    fi
    
    return 0
}

# Backup maintenance operations
cleanup_old_backups() {
    local backup_dir="${1:-$DEFAULT_BACKUP_DIR}"
    local retention_days="${2:-$DEFAULT_RETENTION_DAYS}"
    
    log_info "Cleaning up backups older than $retention_days days..."
    
    if [[ ! -d "$backup_dir" ]]; then
        log_info "Backup directory does not exist: $backup_dir"
        return 0
    fi
    
    # Find and remove old backups
    local deleted_count=0
    while IFS= read -r -d '' backup_file; do
        log_info "Removing old backup: $(basename "$backup_file")"
        rm -f "$backup_file"
        ((deleted_count++))
    done < <(find "$backup_dir" -name "homelab_backup_*.tar.gz" -mtime +"$retention_days" -print0 2>/dev/null)
    
    if [[ $deleted_count -gt 0 ]]; then
        log_success "Removed $deleted_count old backup(s)"
    else
        log_info "No old backups to clean up"
    fi
}

list_available_backups() {
    local backup_dir="${1:-$DEFAULT_BACKUP_DIR}"
    
    log_info "Available backups in $backup_dir:"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_info "Backup directory does not exist: $backup_dir"
        return 0
    fi
    
    local backup_found=false
    while IFS= read -r backup_file; do
        if [[ -n "$backup_file" ]]; then
            local size=$(du -h "$backup_file" | cut -f1)
            local date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$backup_file" 2>/dev/null || date -r "$backup_file" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
            printf "  %-40s %8s  %s\n" "$(basename "$backup_file")" "$size" "$date"
            backup_found=true
        fi
    done < <(find "$backup_dir" -name "homelab_backup_*.tar.gz" -type f 2>/dev/null | sort)
    
    if [[ "$backup_found" == false ]]; then
        log_info "No backups found"
    fi
}

# Cloud backup operations (extensible)
upload_backup_to_cloud() {
    local backup_file="$1"
    local upload_command="${BACKUP_UPLOAD_CMD:-}"
    
    if [[ -z "$backup_file" || ! -f "$backup_file" ]]; then
        log_error "Valid backup file is required"
        return 1
    fi
    
    if [[ -z "$upload_command" ]]; then
        log_info "No cloud upload command configured (BACKUP_UPLOAD_CMD not set)"
        return 0
    fi
    
    log_info "Uploading backup to cloud storage..."
    
    if eval "$upload_command '$backup_file'"; then
        log_success "Backup uploaded successfully"
    else
        log_error "Backup upload failed"
        return 1
    fi
}