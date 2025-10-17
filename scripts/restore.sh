#!/bin/bash

# Homelab Stack Restore Script - Refactored Version
# Restores data from backup using modular libraries

set -e

# Get script directory and source library modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source required library modules
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/backup.sh"

# Check if backup file is provided
if [[ -z "$1" ]]; then
    echo "Usage: $0 <backup_file.tar.gz>"
    echo "Available backups:"
    list_available_backups
    exit 1
fi

BACKUP_FILE="$1"

# Restore from backup using library function
restore_full_backup "$BACKUP_FILE"