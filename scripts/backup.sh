#!/bin/bash

# Homelab Stack Backup Script - Refactored Version
# Creates backups of all persistent data using modular libraries

set -e

# Get script directory and source library modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source required library modules
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/backup.sh"

# Configuration
BACKUP_NAME="homelab_backup_$(date +"%Y%m%d_%H%M%S")"

log_info "Starting backup: $BACKUP_NAME"

# Create full backup using library function
create_full_backup "$BACKUP_NAME"
# Cleanup old backups
cleanup_old_backups

# Optional: Upload to cloud storage
if [[ -n "${BACKUP_UPLOAD_CMD:-}" ]]; then
    upload_backup_to_cloud "./backups/${BACKUP_NAME}.tar.gz"
fi