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

log_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Additional logging functions for different contexts
log_test() { echo -e "${BLUE}[TEST]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Monitoring-specific logging
log_monitoring() { echo -e "${BLUE}[MONITORING]${NC} $*"; }
log_deploy() { echo -e "${BLUE}[DEPLOY]${NC} $*"; }

# Error handling with exit
die() { log_error "$*"; exit 1; }

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

# Common script initialization
init_script() {
    set -euo pipefail
    
    # Set common directories if not already set
    if [[ -z "${SCRIPT_DIR:-}" ]]; then
        readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    fi
    if [[ -z "${PROJECT_DIR:-}" ]]; then
        readonly PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
    fi
    
    # Change to project directory
    cd "$PROJECT_DIR"
}

# Platform detection
detect_platform() {
    local platform_info=""
    
    if [[ "$(uname)" == "Darwin" ]]; then
        platform_info="macOS $(sw_vers -productVersion) ($(uname -m))"
        log_debug "Detected: $platform_info"
        echo "macos"
        return
    fi
    
    if [[ -f /proc/device-tree/model ]]; then
        platform_info=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "Linux")
        if [[ "$platform_info" == *"Raspberry Pi"* ]]; then
            log_debug "Detected: $platform_info"
            echo "raspberry-pi"
            return
        fi
    fi
    
    platform_info="Linux $(uname -r)"
    log_debug "Detected: $platform_info"
    echo "linux"
}

# Check if running on Raspberry Pi
is_raspberry_pi() {
    [[ "$(detect_platform)" == "raspberry-pi" ]]
}

# Check resource constraints
check_system_resources() {
    local min_ram_mb=${1:-1024}
    local min_disk_mb=${2:-2048}
    
    # Memory check (cross-platform)
    local total_mem
    if [[ "$(uname)" == "Darwin" ]]; then
        total_mem=$(( $(sysctl -n hw.memsize) / 1024 / 1024 ))
    else
        total_mem=$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)
    fi
    
    if (( total_mem < min_ram_mb )); then
        log_warn "Limited RAM (${total_mem}MB) - may need resource optimization"
        return 1
    fi
    
    # Disk space check  
    local available_space
    available_space=$(df "${PROJECT_DIR:-$(pwd)}" | awk 'NR==2 {print int($4/1024)}')
    
    if (( available_space < min_disk_mb )); then
        log_warn "Limited disk space (${available_space}MB available)"
        return 1
    fi
    
    log_debug "Resources OK: ${total_mem}MB RAM, ${available_space}MB disk"
    return 0
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