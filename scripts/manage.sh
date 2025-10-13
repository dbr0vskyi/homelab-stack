#!/bin/bash

# Homelab Stack Management Script
# Provides common management operations

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Show help
show_help() {
    cat << EOF
🏠 Homelab Stack Management

Usage: $0 <command> [options]

Commands:
  status          Show service status and health
  logs [service]  Show logs (all services or specific service)
  restart         Restart all services
  stop            Stop all services
  start           Start all services  
  update          Update all container images
  backup          Create a backup
  restore <file>  Restore from backup
  clean           Clean up unused Docker resources
  health          Check service health status
  models          List Ollama models
  pull <model>    Download specific Ollama model
  reset           Reset all data (destructive!)

Examples:
  $0 status              # Show service status
  $0 logs n8n           # Show n8n logs
  $0 update             # Update all services
  $0 pull llama3.1:8b   # Download specific model
EOF
}

# Show service status
show_status() {
    log_info "Service Status:"
    docker compose ps
    echo
    
    log_info "Docker Resource Usage:"
    docker system df
    echo
    
    log_info "Volume Information:"
    docker volume ls | grep homelab
}

# Show logs
show_logs() {
    local service="${1:-}"
    
    if [[ -n "$service" ]]; then
        log_info "Showing logs for $service:"
        docker compose logs -f --tail=100 "$service"
    else
        log_info "Showing logs for all services:"
        docker compose logs -f --tail=50
    fi
}

# Restart services
restart_services() {
    log_info "Restarting services..."
    docker compose restart
    log_success "Services restarted"
}

# Stop services
stop_services() {
    log_info "Stopping services..."
    docker compose down
    log_success "Services stopped"
}

# Start services
start_services() {
    log_info "Starting services..."
    docker compose up -d
    log_success "Services started"
}

# Update services
update_services() {
    log_info "Updating container images..."
    docker compose pull
    
    log_info "Recreating containers with new images..."
    docker compose up -d --force-recreate
    
    log_success "Update complete"
}

# Check health
check_health() {
    log_info "Service Health Status:"
    
    # Check each service
    services=("postgres" "n8n" "ollama")
    
    for service in "${services[@]}"; do
        if docker compose ps -q "$service" > /dev/null 2>&1; then
            status=$(docker compose ps --format "{{.State}}" "$service")
            health=$(docker inspect --format='{{.State.Health.Status}}' "homelab-$service" 2>/dev/null || echo "unknown")
            
            if [[ "$status" == "running" ]]; then
                if [[ "$health" == "healthy" ]]; then
                    echo -e "  ✅ $service: running (healthy)"
                elif [[ "$health" == "unhealthy" ]]; then
                    echo -e "  ❌ $service: running (unhealthy)"
                else
                    echo -e "  🟡 $service: running (health unknown)"
                fi
            else
                echo -e "  ❌ $service: $status"
            fi
        else
            echo -e "  ❌ $service: not found"
        fi
    done
}

# List Ollama models
list_models() {
    log_info "Available Ollama models:"
    docker exec homelab-ollama ollama list 2>/dev/null || log_error "Ollama is not running"
}

# Pull Ollama model
pull_model() {
    local model="$1"
    
    if [[ -z "$model" ]]; then
        log_error "Model name required"
        exit 1
    fi
    
    log_info "Downloading model: $model"
    docker exec homelab-ollama ollama pull "$model"
    log_success "Model downloaded: $model"
}

# Clean up Docker resources
clean_docker() {
    log_info "Cleaning up unused Docker resources..."
    
    # Remove unused containers, networks, images, and build cache
    docker system prune -f
    
    # Remove unused volumes (be careful!)
    read -p "Remove unused volumes? This could delete data. (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume prune -f
    fi
    
    log_success "Cleanup complete"
}

# Reset all data (destructive)
reset_stack() {
    log_warning "This will destroy ALL data and reset the stack!"
    read -p "Are you absolutely sure? Type 'RESET' to confirm: " -r
    
    if [[ "$REPLY" != "RESET" ]]; then
        log_info "Reset cancelled"
        exit 0
    fi
    
    log_info "Stopping and removing all containers..."
    docker compose down -v --remove-orphans
    
    log_info "Removing Docker volumes..."
    docker volume rm homelab_postgres_data homelab_n8n_data homelab_ollama_data 2>/dev/null || true
    
    log_info "Removing environment file..."
    rm -f .env
    
    log_success "Stack reset complete. Run setup.sh to reinitialize."
}

# Create backup
create_backup() {
    ./scripts/backup.sh
}

# Restore from backup
restore_backup() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        log_error "Backup file required"
        exit 1
    fi
    
    ./scripts/restore.sh "$backup_file"
}

# Main command handler
case "${1:-}" in
    "status")
        show_status
        ;;
    "logs")
        show_logs "$2"
        ;;
    "restart")
        restart_services
        ;;
    "stop")
        stop_services
        ;;
    "start")
        start_services
        ;;
    "update")
        update_services
        ;;
    "backup")
        create_backup
        ;;
    "restore")
        restore_backup "$2"
        ;;
    "clean")
        clean_docker
        ;;
    "health")
        check_health
        ;;
    "models")
        list_models
        ;;
    "pull")
        pull_model "$2"
        ;;
    "reset")
        reset_stack
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        log_error "Unknown command: ${1:-}"
        echo
        show_help
        exit 1
        ;;
esac