#!/bin/bash

# Quick Start Script for Homelab Stack
# This script provides a guided setup experience

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/your-username/homelab-stack"
STACK_DIR="homelab-stack"

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

print_header() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                  🏠 Homelab Stack Setup                     ║
║                                                              ║
║  Personal automation platform for Raspberry Pi 5 & macOS   ║
║  ────────────────────────────────────────────────────────   ║
║  Features:                                                   ║
║  • Telegram Bot → Notion automation                         ║
║  • Gmail scanning → Task creation                           ║
║  • Local LLM processing (Ollama)                            ║
║  • Secure, containerized, local-first                       ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# System detection
detect_system() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        SYSTEM="macOS"
        if [[ $(uname -m) == "arm64" ]]; then
            ARCH="Apple Silicon"
        else
            ARCH="Intel"
        fi
    elif [[ -f /proc/device-tree/model ]] && grep -q "Raspberry Pi" /proc/device-tree/model; then
        SYSTEM="Raspberry Pi"
        ARCH=$(uname -m)
    else
        SYSTEM="Linux"
        ARCH=$(uname -m)
    fi
    
    log_info "Detected: $SYSTEM ($ARCH)"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed!"
        echo
        echo "Installation instructions:"
        if [[ "$SYSTEM" == "macOS" ]]; then
            echo "  1. Install Docker Desktop: https://docker.com/products/docker-desktop"
            echo "  2. Or via Homebrew: brew install --cask docker"
        else
            echo "  1. Run: curl -fsSL https://get.docker.com -o get-docker.sh"
            echo "  2. Run: sudo sh get-docker.sh"
            echo "  3. Run: sudo usermod -aG docker $USER"
            echo "  4. Log out and back in"
        fi
        exit 1
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available!"
        echo "Please update to Docker with Compose V2 support"
        exit 1
    fi
    
    # Check Git
    if ! command -v git &> /dev/null; then
        log_warning "Git not found. Install git to clone repository."
    fi
    
    log_success "Prerequisites check passed"
}

# Clone or setup repository
setup_repository() {
    if [[ -d "$STACK_DIR" ]]; then
        log_info "Directory $STACK_DIR already exists"
        cd "$STACK_DIR"
        return
    fi
    
    if command -v git &> /dev/null; then
        log_info "Cloning repository..."
        git clone "$REPO_URL" "$STACK_DIR"
        cd "$STACK_DIR"
    else
        log_error "Cannot clone repository without git"
        echo "Please either:"
        echo "  1. Install git and run this script again"
        echo "  2. Download and extract the repository manually"
        exit 1
    fi
}

# Interactive environment setup
setup_environment_interactive() {
    log_info "Setting up environment configuration..."
    
    if [[ -f ".env" ]]; then
        log_warning "Environment file already exists"
        read -p "Overwrite existing .env file? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    # Copy template
    cp .env.example .env
    
    # Generate secure passwords
    log_info "Generating secure passwords..."
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    N8N_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    N8N_ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    
    # Update passwords in .env
    sed -i.bak "s/your_secure_postgres_password_here/$POSTGRES_PASSWORD/g" .env
    sed -i.bak "s/your_secure_n8n_password_here/$N8N_PASSWORD/g" .env
    sed -i.bak "s/your_32_character_encryption_key_here/$N8N_ENCRYPTION_KEY/g" .env
    rm -f .env.bak
    
    echo
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}                API Configuration Setup${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    # Telegram Bot setup
    echo -e "${YELLOW}📱 Telegram Bot Setup${NC}"
    echo "1. Message @BotFather on Telegram"
    echo "2. Create new bot with /newbot"
    echo "3. Copy the bot token"
    echo
    read -p "Enter Telegram Bot Token (or press Enter to skip): " telegram_token
    if [[ -n "$telegram_token" ]]; then
        sed -i.bak "s/your_telegram_bot_token_here/$telegram_token/g" .env
        rm -f .env.bak
        
        read -p "Enter your Telegram Chat ID (or press Enter to skip): " chat_id
        if [[ -n "$chat_id" ]]; then
            sed -i.bak "s/your_telegram_chat_id_here/$chat_id/g" .env
            rm -f .env.bak
        fi
    fi
    
    echo
    # Notion setup
    echo -e "${YELLOW}📝 Notion Integration Setup${NC}"
    echo "1. Go to https://developers.notion.com/"
    echo "2. Create new integration"
    echo "3. Copy the integration token"
    echo "4. Create a database and share it with your integration"
    echo
    read -p "Enter Notion API Token (or press Enter to skip): " notion_token
    if [[ -n "$notion_token" ]]; then
        sed -i.bak "s/your_notion_integration_token_here/$notion_token/g" .env
        rm -f .env.bak
        
        read -p "Enter Notion Database ID (or press Enter to skip): " database_id
        if [[ -n "$database_id" ]]; then
            sed -i.bak "s/your_notion_database_id_here/$database_id/g" .env
            rm -f .env.bak
        fi
    fi
    
    echo
    # OpenAI setup
    echo -e "${YELLOW}🤖 OpenAI API Setup (Optional)${NC}"
    echo "For fallback when local LLM is unavailable"
    echo
    read -p "Enter OpenAI API Key (or press Enter to skip): " openai_key
    if [[ -n "$openai_key" ]]; then
        sed -i.bak "s/your_openai_api_key_here/$openai_key/g" .env
        rm -f .env.bak
    fi
    
    log_success "Environment configuration complete"
    echo
    log_info "You can edit .env later to add more API keys (Gmail, Tailscale, etc.)"
}

# Start services
start_services() {
    echo
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}                Starting Services${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
    
    log_info "Starting homelab stack services..."
    
    # Create Docker volumes
    docker volume create homelab_postgres_data || true
    docker volume create homelab_n8n_data || true
    docker volume create homelab_ollama_data || true
    
    # Start core services
    log_info "Starting database..."
    docker compose up -d postgres
    sleep 5
    
    log_info "Starting n8n..."
    docker compose up -d n8n
    
    log_info "Starting Ollama..."
    docker compose up -d ollama
    
    # Wait for services to be ready
    log_info "Waiting for services to start..."
    sleep 10
    
    # Check service health
    if docker compose ps | grep -q "Up"; then
        log_success "Services started successfully!"
    else
        log_error "Some services failed to start. Check logs with: docker compose logs"
        return 1
    fi
}

# Download initial models
setup_models() {
    echo
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}              Downloading LLM Models${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════${NC}"
    
    log_info "This will download AI models for local processing"
    echo "Available models:"
    echo "  • llama3.2:1b   - Fast, lightweight (1GB)"
    echo "  • llama3.1:8b   - Balanced performance (4.7GB)"  
    echo "  • qwen2.5:7b    - Good for coding tasks (4.4GB)"
    echo
    
    if [[ "$SYSTEM" == "Raspberry Pi" ]]; then
        # Check available RAM to determine model recommendations
        TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
        if [[ $TOTAL_RAM -gt 14000000 ]]; then
            log_info "Raspberry Pi with 16GB RAM detected - using optimized models"
            DEFAULT_MODELS="llama3.1:8b qwen2.5:7b qwen2.5:14b"
        else
            log_warning "Raspberry Pi with limited RAM detected - using smaller models"
            DEFAULT_MODELS="llama3.2:1b qwen2.5:1.5b"
        fi
    else
        DEFAULT_MODELS="llama3.1:8b qwen2.5:14b"
    fi
    
    read -p "Download default models ($DEFAULT_MODELS)? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Skipping model download. You can download models later with:"
        echo "  docker exec homelab-ollama ollama pull <model-name>"
        return
    fi
    
    for model in $DEFAULT_MODELS; do
        log_info "Downloading $model..."
        docker exec homelab-ollama ollama pull "$model" || log_warning "Failed to download $model"
    done
    
    log_success "Model setup complete!"
}

# Show completion info
show_completion() {
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    🎉 Setup Complete!                       ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    echo -e "${CYAN}📊 Service URLs:${NC}"
    echo "  • n8n Interface: http://localhost:5678"
    echo "  • Ollama API: http://localhost:11434"
    echo
    
    echo -e "${CYAN}🔑 Default Credentials:${NC}"
    echo "  • Username: admin"
    echo "  • Password: (check .env file for N8N_PASSWORD)"
    echo
    
    echo -e "${CYAN}📋 Next Steps:${NC}"
    echo "  1. Open http://localhost:5678 in your browser"
    echo "  2. Login with the credentials above"
    echo "  3. Import workflows from the workflows/ folder"
    echo "  4. Configure your automations"
    echo
    
    echo -e "${CYAN}🛠️ Management Commands:${NC}"
    echo "  • View status: ./scripts/manage.sh status"
    echo "  • View logs: ./scripts/manage.sh logs"
    echo "  • Create backup: ./scripts/manage.sh backup"
    echo "  • Stop services: docker compose down"
    echo "  • Restart services: docker compose restart"
    echo
    
    echo -e "${YELLOW}⚠️  Important Notes:${NC}"
    echo "  • Keep your .env file secure (contains passwords)"
    echo "  • Set up regular backups for important data"
    echo "  • Update API tokens as needed in the .env file"
    echo "  • Check documentation in docs/ for advanced setup"
    echo
}

# Main setup flow
main() {
    print_header
    detect_system
    check_prerequisites
    
    read -p "Continue with installation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    setup_repository
    setup_environment_interactive
    
    read -p "Start services now? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        start_services
        
        read -p "Download AI models now? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            setup_models
        fi
    fi
    
    show_completion
}

# Error handling
trap 'log_error "Setup failed at line $LINENO. Check the error above."' ERR

# Run main setup
main "$@"