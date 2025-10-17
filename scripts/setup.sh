#!/bin/bash

# Homelab Stack Setup Script - Refactored Version
# Initializes and configures the automation stack

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source all library modules
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/prerequisites.sh"
source "${LIB_DIR}/environment.sh"
source "${LIB_DIR}/ssl.sh"
source "${LIB_DIR}/services.sh"
source "${LIB_DIR}/ollama.sh"
source "${LIB_DIR}/display.sh"

# Main setup workflow
# Forces container recreation to ensure clean state after configuration changes
main() {
    echo "🏠 Homelab Stack Setup"
    echo "======================"
    echo
    
    check_prerequisites
    setup_environment
    setup_ssl_certificates
    init_volumes
    start_services true  # Force recreate containers in setup
    setup_ollama_models
    show_info
}

# Handle command line arguments
case "${1:-}" in
    "prereq")
        check_prerequisites
        exit 0
        ;;
    "env")
        setup_environment
        exit 0
        ;;
    "ssl")
        setup_ssl_certificates
        exit 0
        ;;
    "volumes")
        init_volumes
        exit 0
        ;;
    "services")
        start_services true  # Force recreate when called directly
        exit 0
        ;;
    "models")
        setup_ollama_models
        exit 0
        ;;
    "info")
        show_info
        exit 0
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Setup script always recreates containers for clean state."
        echo "For regular start/stop/restart operations, use manage.sh instead."
        echo ""
        echo "Commands:"
        echo "  prereq   - Check prerequisites only"
        echo "  env      - Setup environment configuration only"
        echo "  ssl      - Setup SSL certificates only"
        echo "  volumes  - Initialize Docker volumes only"
        echo "  services - Start Docker services only (recreates containers)"
        echo "  models   - Download Ollama models only"
        echo "  info     - Show setup information"
        echo "  help     - Show this help message"
        echo ""
        echo "Run without arguments for full setup."
        exit 0
        ;;
    *)
        main
        ;;
esac