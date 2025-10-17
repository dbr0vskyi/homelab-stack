#!/bin/bash

# Docker and system prerequisites checker

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    check_docker
    check_docker_daemon
    check_architecture
    check_required_tools
    
    log_success "Prerequisites check passed"
}

check_docker() {
    if ! command_exists docker; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
}

check_docker_daemon() {
    log_info "Checking Docker daemon status..."
    
    if ! docker info &> /dev/null; then
        log_warning "Docker daemon is not running. Attempting to start Docker..."
        start_docker_daemon
    fi
}

start_docker_daemon() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        start_docker_macos
    else
        log_error "Docker daemon is not running. Please start Docker service:"
        echo "  sudo systemctl start docker"
        exit 1
    fi
}

start_docker_macos() {
    log_info "Starting Docker Desktop on macOS..."
    open -a Docker
    log_info "Waiting for Docker to start (this may take 30-60 seconds)..."
    
    # Wait for Docker to start (up to 2 minutes)
    for i in {1..24}; do
        if docker info &> /dev/null; then
            log_success "Docker is now running"
            return
        fi
        echo -n "."
        sleep 5
    done
    
    # Final check
    if ! docker info &> /dev/null; then
        log_error "Docker failed to start. Please start Docker Desktop manually and try again."
        echo "  1. Open Docker Desktop application"
        echo "  2. Wait for it to fully start"
        echo "  3. Run this script again"
        exit 1
    fi
}

check_architecture() {
    local arch=$(uname -m)
    if [[ "$arch" != "arm64" && "$arch" != "aarch64" && "$arch" != "x86_64" ]]; then
        log_warning "Architecture $arch may not be fully supported. Proceeding anyway..."
    fi
}

check_required_tools() {
    log_info "Checking required tools..."
    
    # Check for jq (required for Tailscale integration)
    if ! command_exists jq; then
        log_warning "jq is not installed. Installing automatically..."
        install_jq
    else
        log_success "jq is already installed"
    fi
}

install_jq() {
    local install_cmd=""
    local update_cmd=""
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command_exists brew; then
            install_cmd="brew install jq"
        else
            log_error "Homebrew not found. Please install jq manually:"
            echo "  Visit: https://jqlang.github.io/jq/download/"
            return 1
        fi
    elif [[ -f /etc/debian_version ]]; then
        update_cmd="sudo apt update"
        install_cmd="sudo apt install -y jq"
    elif [[ -f /etc/redhat-release ]]; then
        if command_exists dnf; then
            install_cmd="sudo dnf install -y jq"
        elif command_exists yum; then
            install_cmd="sudo yum install -y jq"
        else
            log_error "Neither dnf nor yum found. Please install jq manually."
            return 1
        fi
    elif command_exists apk; then
        install_cmd="sudo apk add jq"
    else
        log_error "Unable to detect package manager. Please install jq manually:"
        echo "  Visit: https://jqlang.github.io/jq/download/"
        return 1
    fi
    
    log_info "Installing jq..."
    if [[ -n "$update_cmd" ]]; then
        log_info "Updating package lists..."
        if ! eval "$update_cmd"; then
            log_error "Failed to update package lists"
            return 1
        fi
    fi
    
    log_info "Running: $install_cmd"
    if eval "$install_cmd"; then
        log_success "jq installed successfully"
        
        # Verify installation
        if command_exists jq; then
            log_success "jq is now available and ready to use"
        else
            log_error "jq installation completed but command not found. You may need to restart your shell."
            return 1
        fi
    else
        log_error "Failed to install jq. Please install manually:"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  brew install jq"
        elif [[ -f /etc/debian_version ]]; then
            echo "  sudo apt update && sudo apt install -y jq"
        elif [[ -f /etc/redhat-release ]]; then
            echo "  sudo dnf install -y jq  # or: sudo yum install -y jq"
        elif command_exists apk; then
            echo "  sudo apk add jq"
        else
            echo "  Visit: https://jqlang.github.io/jq/download/"
        fi
        return 1
    fi
}