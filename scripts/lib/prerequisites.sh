#!/bin/bash

# Docker and system prerequisites checker

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    check_docker
    check_docker_daemon
    check_architecture
    
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