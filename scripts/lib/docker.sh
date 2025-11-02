#!/bin/bash

# Docker Operations Library
# Common Docker operations for homelab stack management

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Docker configuration
COMPOSE_PROJECT="homelab"

# Docker volume operations
create_volume() {
    local volume_name="$1"
    
    if [[ -z "$volume_name" ]]; then
        log_error "Volume name is required"
        return 1
    fi
    
    if docker volume inspect "$volume_name" &>/dev/null; then
        log_info "Volume $volume_name already exists"
    else
        log_info "Creating volume: $volume_name"
        docker volume create "$volume_name"
    fi
}

remove_volume() {
    local volume_name="$1"
    
    if [[ -z "$volume_name" ]]; then
        log_error "Volume name is required"
        return 1
    fi
    
    if docker volume inspect "$volume_name" &>/dev/null; then
        log_info "Removing volume: $volume_name"
        docker volume rm "$volume_name" 2>/dev/null || true
    else
        log_info "Volume $volume_name does not exist"
    fi
}

list_homelab_volumes() {
    log_info "Homelab Docker volumes:"
    docker volume ls | grep "${COMPOSE_PROJECT}" || log_info "No homelab volumes found"
}

# Docker Compose operations
compose_up() {
    local service="${1:-}"
    
    if [[ -n "$service" ]]; then
        log_info "Starting service: $service"
        docker compose up -d "$service"
    else
        log_info "Starting all services"
        docker compose up -d
    fi
}

compose_down() {
    local service="${1:-}"
    
    if [[ -n "$service" ]]; then
        log_info "Stopping service: $service"
        docker compose stop "$service"
    else
        log_info "Stopping all services"
        docker compose down
    fi
}

compose_restart() {
    local service="${1:-}"
    
    if [[ -n "$service" ]]; then
        log_info "Restarting service: $service"
        docker compose restart "$service"
    else
        log_info "Restarting all services"
        docker compose restart
    fi
}

compose_logs() {
    local service="${1:-}"
    local tail_lines="${2:-100}"
    
    if [[ -n "$service" ]]; then
        log_info "Showing logs for $service (last $tail_lines lines):"
        docker compose logs -f --tail="$tail_lines" "$service"
    else
        log_info "Showing logs for all services (last $tail_lines lines):"
        docker compose logs -f --tail="$tail_lines"
    fi
}

# Service health operations
wait_for_service_healthy() {
    local service="$1"
    local timeout="${2:-60}"
    local counter=0
    
    log_info "Waiting for $service to be healthy..."
    
    while [[ $counter -lt $timeout ]]; do
        if docker compose ps --format json | jq -r '.[] | select(.Service == "'"$service"'") | .Health' | grep -q "healthy"; then
            log_success "$service is healthy"
            return 0
        fi
        
        sleep 2
        counter=$((counter + 2))
        
        if [[ $((counter % 10)) -eq 0 ]]; then
            log_info "Still waiting for $service... (${counter}s/${timeout}s)"
        fi
    done
    
    log_error "$service failed to become healthy within ${timeout}s"
    return 1
}

wait_for_service_running() {
    local service="$1"
    local timeout="${2:-30}"
    local counter=0
    
    log_info "Waiting for $service to be running..."
    
    while [[ $counter -lt $timeout ]]; do
        if docker compose ps --format json | jq -r '.[] | select(.Service == "'"$service"'") | .State' | grep -q "running"; then
            log_success "$service is running"
            return 0
        fi
        
        sleep 2
        counter=$((counter + 2))
    done
    
    log_error "$service failed to start within ${timeout}s"
    return 1
}

# Service status operations
get_service_status() {
    log_info "Service Status:"
    docker compose ps --format table
}

get_docker_resource_usage() {
    log_info "Docker Resource Usage:"
    docker system df
}

get_service_health() {
    local service="${1:-}"
    
    if [[ -n "$service" ]]; then
        log_info "Health status for $service:"
        docker compose ps --format json | jq -r '.[] | select(.Service == "'"$service"'") | {Service, State, Health, Status}'
    else
        log_info "Health status for all services:"
        docker compose ps --format json | jq -r '.[] | {Service, State, Health, Status}'
    fi
}

# Docker maintenance operations
cleanup_docker_resources() {
    log_info "Cleaning up unused Docker resources..."
    
    # Remove unused containers
    log_info "Removing stopped containers..."
    docker container prune -f
    
    # Remove unused images
    log_info "Removing unused images..."
    docker image prune -f
    
    # Remove unused networks
    log_info "Removing unused networks..."
    docker network prune -f
    
    # Remove unused volumes (excluding homelab volumes)
    log_info "Removing unused volumes (excluding homelab volumes)..."
    docker volume prune -f --filter "label!=com.docker.compose.project=${COMPOSE_PROJECT}"
    
    log_success "Docker cleanup complete"
}

update_docker_images() {
    log_info "Updating Docker images..."
    docker compose pull
    log_success "Docker images updated"
}

# Container execution helpers
exec_in_container() {
    local container="$1"
    local command="${2:-/bin/sh}"
    
    if [[ -z "$container" ]]; then
        log_error "Container name is required"
        return 1
    fi
    
    if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        log_error "Container $container is not running"
        return 1
    fi
    
    log_info "Executing in container $container: $command"
    docker exec -it "$container" "$command"
}

# Backup/restore volume helpers
backup_volume_to_tar() {
    local volume_name="$1"
    local backup_path="$2"
    
    if [[ -z "$volume_name" || -z "$backup_path" ]]; then
        log_error "Volume name and backup path are required"
        return 1
    fi
    
    log_info "Backing up volume $volume_name to $backup_path"
    docker run --rm \
        -v "${volume_name}:/data:ro" \
        -v "$(dirname "$backup_path"):/backup" \
        alpine \
        tar czf "/backup/$(basename "$backup_path")" -C /data .
}

restore_volume_from_tar() {
    local volume_name="$1"
    local backup_path="$2"
    
    if [[ -z "$volume_name" || -z "$backup_path" ]]; then
        log_error "Volume name and backup path are required"
        return 1
    fi
    
    if [[ ! -f "$backup_path" ]]; then
        log_error "Backup file not found: $backup_path"
        return 1
    fi
    
    log_info "Restoring volume $volume_name from $backup_path"
    
    # Remove existing volume
    remove_volume "$volume_name"
    
    # Create new volume
    create_volume "$volume_name"
    
    # Restore data
    docker run --rm \
        -v "${volume_name}:/data" \
        -v "$(dirname "$backup_path"):/backup" \
        alpine \
        tar xzf "/backup/$(basename "$backup_path")" -C /data
}

# Load monitoring functions
source "$(dirname "${BASH_SOURCE[0]}")/monitoring.sh"

# Monitoring-specific Docker operations
docker_compose_monitoring() {
    local action="$1"
    shift
    
    cd "$PROJECT_DIR"
    docker-compose --profile monitoring "$action" "$@"
}

show_monitoring_status() {
    # Use centralized monitoring status function
    show_monitoring_status
}