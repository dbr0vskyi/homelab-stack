#!/bin/bash

# Docker services and volume management

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

init_volumes() {
    log_info "Initializing Docker volumes..."
    
    # Verify Docker is still running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon stopped working. Please check Docker Desktop."
        exit 1
    fi
    
    create_volume "homelab_postgres_data" "postgres"
    create_volume "homelab_n8n_data" "n8n" 
    create_volume "homelab_ollama_data" "ollama"
    
    log_success "Docker volumes initialized"
}

create_volume() {
    local volume_name="$1"
    local service_name="$2"
    
    log_info "Creating ${service_name} volume..."
    if ! docker volume create "$volume_name" 2>/dev/null; then
        log_info "${service_name^} volume already exists or created"
    fi
}

start_services() {
    log_info "Starting Docker services..."
    
    verify_docker_running
    start_core_services
    start_optional_services
    
    log_success "Services started successfully"
}

verify_docker_running() {
    if ! docker info &> /dev/null; then
        log_error "Docker daemon stopped working. Please check Docker Desktop."
        exit 1
    fi
}

start_core_services() {
    start_service "postgres" "PostgreSQL"
    
    log_info "Waiting for PostgreSQL to be ready..."
    sleep 10
    
    start_service "n8n" "n8n"
    start_service "ollama" "Ollama"
}

start_optional_services() {
    if [[ "${ENABLE_TAILSCALE:-false}" == "true" ]]; then
        start_service "tailscale" "Tailscale"
    fi
    
    if [[ "${ENABLE_REDIS:-false}" == "true" ]]; then
        start_service "redis" "Redis"
    fi
    
    if [[ "${ENABLE_WATCHTOWER:-false}" == "true" ]]; then
        start_service "watchtower" "Watchtower"
    fi
}

start_service() {
    local service_name="$1"
    local display_name="$2"
    
    log_info "Starting ${display_name}..."
    if ! docker compose up -d "$service_name"; then
        log_error "Failed to start ${display_name}"
        exit 1
    fi
}