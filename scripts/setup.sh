#!/bin/bash

# Homelab Stack Setup Script
# Initializes and configures the automation stack

set -e

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

# Helper functions
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
    
    # Check Docker Daemon
    log_info "Checking Docker daemon status..."
    if ! docker info &> /dev/null; then
        log_warning "Docker daemon is not running. Attempting to start Docker..."
        
        # Try to start Docker based on OS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            log_info "Starting Docker Desktop on macOS..."
            open -a Docker
            log_info "Waiting for Docker to start (this may take 30-60 seconds)..."
            
            # Wait for Docker to start (up to 2 minutes)
            for i in {1..24}; do
                if docker info &> /dev/null; then
                    log_success "Docker is now running"
                    break
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
        else
            log_error "Docker daemon is not running. Please start Docker service:"
            echo "  sudo systemctl start docker"
            exit 1
        fi
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" != "arm64" && "$ARCH" != "aarch64" && "$ARCH" != "x86_64" ]]; then
        log_warning "Architecture $ARCH may not be fully supported. Proceeding anyway..."
    fi
    
    log_success "Prerequisites check passed"
}

# Setup environment file
setup_environment() {
    log_info "Setting up environment configuration..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        if [[ -f ".env.example" ]]; then
            cp .env.example "$ENV_FILE"
            log_success "Environment file created from template"
        else
            log_error "No .env.example template found"
            exit 1
        fi
    else
        log_warning "Environment file already exists, skipping creation"
        return
    fi
    
    # Generate secure passwords and keys
    log_info "Generating secure passwords and encryption keys..."
    
    # Generate random passwords
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    N8N_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    N8N_ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    
    # Update .env file with generated values
    if command -v sed &> /dev/null; then
        sed -i.bak "s/your_secure_postgres_password_here/$POSTGRES_PASSWORD/g" "$ENV_FILE"
        sed -i.bak "s/your_secure_n8n_password_here/$N8N_PASSWORD/g" "$ENV_FILE"
        sed -i.bak "s/your_32_character_encryption_key_here/$N8N_ENCRYPTION_KEY/g" "$ENV_FILE"
        rm -f "$ENV_FILE.bak"
        log_success "Generated secure passwords and keys"
    else
        log_warning "Could not automatically generate passwords. Please update .env manually."
    fi
    
    log_info "Please edit $ENV_FILE and add your API tokens:"
    echo "  - TELEGRAM_BOT_TOKEN"
    echo "  - NOTION_API_TOKEN"
    echo "  - GMAIL credentials (optional)"
    echo "  - OPENAI_API_KEY (optional)"
    echo "  - TAILSCALE_AUTH_KEY (optional)"
}

# Initialize Docker volumes
init_volumes() {
    log_info "Initializing Docker volumes..."
    
    # Verify Docker is still running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon stopped working. Please check Docker Desktop."
        exit 1
    fi
    
    # Create named volumes with better error handling
    log_info "Creating postgres volume..."
    if ! docker volume create homelab_postgres_data 2>/dev/null; then
        log_info "Postgres volume already exists or created"
    fi
    
    log_info "Creating n8n volume..."
    if ! docker volume create homelab_n8n_data 2>/dev/null; then
        log_info "n8n volume already exists or created"
    fi
    
    log_info "Creating ollama volume..."
    if ! docker volume create homelab_ollama_data 2>/dev/null; then
        log_info "Ollama volume already exists or created"
    fi
    
    log_success "Docker volumes initialized"
}

# Start core services
# Start services
start_services() {
    log_info "Starting Docker services..."
    
    # Verify Docker is still running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon stopped working. Please check Docker Desktop."
        exit 1
    fi
    
    # Start core services first
    log_info "Starting PostgreSQL..."
    if ! docker compose up -d postgres; then
        log_error "Failed to start PostgreSQL"
        exit 1
    fi
    
    log_info "Waiting for PostgreSQL to be ready..."
    sleep 10
    
    # Start n8n
    log_info "Starting n8n..."
    if ! docker compose up -d n8n; then
        log_error "Failed to start n8n"
        exit 1
    fi
    
    # Start Ollama
    log_info "Starting Ollama..."
    if ! docker compose up -d ollama; then
        log_error "Failed to start Ollama"
        exit 1
    fi
    
    # Check if optional services should be started
    if [[ "${ENABLE_TAILSCALE:-false}" == "true" ]]; then
        log_info "Starting Tailscale..."
        docker compose up -d tailscale
    fi
    
    if [[ "${ENABLE_REDIS:-false}" == "true" ]]; then
        log_info "Starting Redis..."
        docker compose up -d redis
    fi
    
    if [[ "${ENABLE_WATCHTOWER:-false}" == "true" ]]; then
        log_info "Starting Watchtower..."
        docker compose up -d watchtower
    fi
    
    log_success "Services started successfully"
}

# Download Ollama models
setup_ollama_models() {
    log_info "Setting up Ollama models..."
    
    # Wait for Ollama to be ready
    log_info "Waiting for Ollama to be ready..."
    sleep 30
    
    # Read models from config
    if [[ -f "config/ollama/models.txt" ]]; then
        while IFS= read -r model; do
            # Skip comments and empty lines
            [[ "$model" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${model// }" ]] && continue
            
            log_info "Downloading model: $model"
            docker exec homelab-ollama ollama pull "$model" || log_warning "Failed to download $model"
        done < config/ollama/models.txt
    else
        # Default models for Pi 5 16GB
        log_info "Downloading optimized models for Pi 5 16GB..."
        docker exec homelab-ollama ollama pull llama3.1:8b || log_warning "Failed to download llama3.1:8b"
        docker exec homelab-ollama ollama pull qwen2.5:7b || log_warning "Failed to download qwen2.5:7b"
        docker exec homelab-ollama ollama pull qwen2.5:14b || log_warning "Failed to download qwen2.5:14b"
    fi
    
    log_success "Ollama models setup complete"
}

# Display service information
show_info() {
    log_success "Homelab Stack setup complete!"
    echo
    log_info "Service URLs:"
    echo "  📊 n8n Workflows: http://localhost:5678"
    echo "  🤖 Ollama API: http://localhost:11434"
    echo
    log_info "Default Credentials:"
    echo "  👤 n8n Username: admin"
    echo "  🔑 n8n Password: (check .env file)"
    echo
    log_info "Next Steps:"
    echo "  1. Configure your API tokens in the .env file"
    echo "  2. Access n8n and import workflow templates"
    echo "  3. Set up your Telegram bot and Notion integration"
    echo "  4. Test the automation workflows"
    echo
    log_info "Management Commands:"
    echo "  📈 View logs: docker compose logs -f"
    echo "  🔄 Restart: docker compose restart"
    echo "  🛑 Stop: docker compose down"
    echo "  🗄️ Backup: ./scripts/backup.sh"
}

# Main setup flow
main() {
    echo "🏠 Homelab Stack Setup"
    echo "======================"
    echo
    
    check_prerequisites
    setup_environment
    init_volumes
    start_services
    setup_ollama_models
    show_info
    
    log_success "Setup completed successfully! 🎉"
}

# Handle arguments
case "${1:-}" in
    "models")
        setup_ollama_models
        ;;
    "info")
        show_info
        ;;
    *)
        main
        ;;
esac