#!/bin/bash

# Common utilities and logging functions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="homelab"
ENV_FILE=".env"
COMPOSE_FILE="docker-compose.yml"

# SSL Configuration (global variables)
SSL_HOSTNAME=""
USE_TAILSCALE_CERT=false
TAILSCALE_DOMAIN=""

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Utility functions
generate_password() {
    local length=${1:-25}
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-${length}
}

generate_encryption_key() {
    local length=${1:-32}
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-${length}
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if file exists and is readable
file_readable() {
    [[ -f "$1" && -r "$1" ]]
}

# Get value from .env file, handling comments and quotes
get_env_value() {
    local key="$1"
    local env_file="${2:-$ENV_FILE}"
    
    if [[ -f "$env_file" ]]; then
        grep "^${key}=" "$env_file" 2>/dev/null | \
        cut -d'=' -f2 | \
        cut -d'#' -f1 | \
        tr -d '"' | \
        tr -d "'" | \
        xargs
    fi
}

# Update value in .env file
update_env_value() {
    local key="$1"
    local value="$2"
    local env_file="${3:-$ENV_FILE}"
    
    if [[ -f "$env_file" ]] && command_exists sed; then
        sed -i.bak "s/^${key}=.*/${key}=${value}/" "$env_file"
        rm -f "${env_file}.bak"
        return 0
    fi
    return 1
}