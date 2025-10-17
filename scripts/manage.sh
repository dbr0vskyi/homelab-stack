#!/bin/bash

# Homelab Stack Management Script - Refactored Version
# Provides common management operations using modular libraries

set -e

# Get script directory and source library modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source all required library modules
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/docker.sh"
source "${LIB_DIR}/backup.sh"
source "${LIB_DIR}/ollama.sh"
source "${LIB_DIR}/workflows.sh"

# Show help
show_help() {
    cat << EOF
🏠 Homelab Stack Management

Usage: $0 <command> [options]

Commands:
  status               Show service status and health
  logs [service]       Show logs (all services or specific service)
  restart              Restart all services
  stop                 Stop all services
  start                Start all services  
  update               Update all container images
  backup               Create a backup
  restore <file>       Restore from backup
  clean                Clean up unused Docker resources
  health               Check service health status
  models               List Ollama models
  pull <model>         Download specific Ollama model
  restore-models <file> Restore Ollama models from backup list
  reset                Reset all data (destructive!)
  
  Workflow Management:
  import-workflows           Import workflow files to n8n
  export-workflows          Export n8n workflows to files

Examples:
  $0 status                           # Show service status
  $0 logs n8n                        # Show n8n logs
  $0 update                          # Update all services
  $0 pull llama3.1:8b                # Download specific model
  $0 restore-models backup_models.txt # Restore models from backup
  $0 import-workflows                # Import workflow files to n8n
  $0 export-workflows                # Export n8n workflows to files
EOF
}

# Show service status
show_status() {
    get_service_status
    echo
    get_docker_resource_usage
    echo
    list_homelab_volumes
}

# Show logs
show_logs() {
    local service="${1:-}"
    compose_logs "$service" "${2:-50}"
}

# Restart services
restart_services() {
    compose_restart
}

# Stop services
stop_services() {
    compose_down
}

# Start services
start_services() {
    compose_up
}

# Update services
update_services() {
    update_docker_images
    
    log_info "Recreating containers with new images..."
    docker compose up -d --force-recreate
    
    log_success "Update complete"
}

# Check health
check_health() {
    get_service_health
}

# List Ollama models
list_models() {
    list_ollama_models
}

# Pull Ollama model
pull_model() {
    local model="$1"
    
    if [[ -z "$model" ]]; then
        log_error "Model name required"
        exit 1
    fi
    
    download_ollama_model "$model"
}

# Restore Ollama models from backup list
restore_models_from_file() {
    local models_file="$1"
    
    if [[ -z "$models_file" ]]; then
        log_error "Models file path required"
        exit 1
    fi
    
    restore_models_from_backup "$models_file"
}

# Clean up Docker resources
clean_docker() {
    cleanup_docker_resources
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
    remove_volume "homelab_postgres_data"
    remove_volume "homelab_n8n_data"
    remove_volume "homelab_ollama_data"
    
    log_info "Removing environment file..."
    rm -f .env
    
    log_success "Stack reset complete. Run setup.sh to reinitialize."
}

# Create backup
create_backup() {
    create_full_backup
}

# Restore from backup
restore_backup() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        log_error "Backup file required"
        list_available_backups
        exit 1
    fi
    
    restore_full_backup "$backup_file"
}

# Workflow management functions
import_workflows_command() {
    import_workflows
}

export_workflows_command() {
    export_workflows
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
    "restore-models")
        restore_models_from_file "$2"
        ;;
    "reset")
        reset_stack
        ;;
    "import-workflows")
        import_workflows_command
        ;;
    "export-workflows")
        export_workflows_command
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