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
    
    # Create monitoring volumes if monitoring is enabled
    if [[ "${ENABLE_MONITORING:-false}" == "true" ]]; then
        create_volume "homelab_prometheus_data" "prometheus"
        create_volume "homelab_grafana_data" "grafana"
    fi
    
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
    local force_recreate="${1:-false}"
    
    if [[ "$force_recreate" == "true" ]]; then
        log_info "Starting Docker services (recreating containers)..."
    else
        log_info "Starting Docker services..."
    fi
    
    verify_docker_running
    start_core_services "$force_recreate"
    start_optional_services "$force_recreate"
    
    log_success "Services started successfully"
}

verify_docker_running() {
    if ! docker info &> /dev/null; then
        log_error "Docker daemon stopped working. Please check Docker Desktop."
        exit 1
    fi
}

start_core_services() {
    local force_recreate="${1:-false}"
    
    start_service "postgres" "PostgreSQL" "$force_recreate"
    
    log_info "Waiting for PostgreSQL to be ready..."
    sleep 10
    
    start_service "n8n" "n8n" "$force_recreate"
    start_service "ollama" "Ollama" "$force_recreate"
}

start_optional_services() {
    local force_recreate="${1:-false}"
    
    if [[ "${ENABLE_TAILSCALE:-false}" == "true" ]]; then
        start_service "tailscale" "Tailscale" "$force_recreate"
    fi
    
    if [[ "${ENABLE_REDIS:-false}" == "true" ]]; then
        start_service "redis" "Redis" "$force_recreate"
    fi
    
    if [[ "${ENABLE_WATCHTOWER:-false}" == "true" ]]; then
        start_service "watchtower" "Watchtower" "$force_recreate"
    fi
    
    # Start monitoring services if enabled
    if [[ "${ENABLE_MONITORING:-false}" == "true" ]]; then
        setup_monitoring_stack "$force_recreate"
    fi
}

start_service() {
    local service_name="$1"
    local display_name="$2"
    local force_recreate="${3:-false}"
    
    log_info "Starting ${display_name}..."
    
    if [[ "$force_recreate" == "true" ]]; then
        # Force recreate containers (used by setup script)
        if ! docker compose up -d --force-recreate "$service_name"; then
            log_error "Failed to start ${display_name}"
            exit 1
        fi
    else
        # Normal start (used by manage script)
        if ! docker compose up -d "$service_name"; then
            log_error "Failed to start ${display_name}"
            exit 1
        fi
    fi
}

# Load monitoring functions
source "$(dirname "${BASH_SOURCE[0]}")/monitoring.sh"

setup_monitoring_stack() {
    local force_recreate="${1:-false}"
    
    # Use the centralized monitoring library function
    if [[ "$force_recreate" == "true" ]]; then
        start_monitoring_stack true
    else
        start_monitoring_stack false
    fi
}