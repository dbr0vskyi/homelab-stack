#!/bin/bash

# Environment configuration and .env file management

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

setup_environment() {
    log_info "Setting up environment configuration..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        create_env_file
        generate_secure_credentials
    else
        log_warning "Environment file already exists, skipping creation"
        return
    fi
    
    show_env_setup_instructions
}

create_env_file() {
    if [[ -f ".env.example" ]]; then
        cp .env.example "$ENV_FILE"
        log_success "Environment file created from template"
    else
        log_error "No .env.example template found"
        exit 1
    fi
}

generate_secure_credentials() {
    log_info "Generating secure passwords and encryption keys..."
    
    local postgres_password=$(generate_password 25)
    local n8n_password=$(generate_password 25)
    local n8n_encryption_key=$(generate_encryption_key 32)
    
    if command_exists sed; then
        update_env_value "POSTGRES_PASSWORD" "$postgres_password"
        update_env_value "N8N_PASSWORD" "$n8n_password"
        update_env_value "N8N_ENCRYPTION_KEY" "$n8n_encryption_key"
        log_success "Generated secure passwords and keys"
    else
        log_warning "Could not automatically generate passwords. Please update .env manually."
    fi
}

show_env_setup_instructions() {
    log_info "Please edit $ENV_FILE and add your API tokens:"
    echo "  - TELEGRAM_BOT_TOKEN"
    echo "  - NOTION_API_TOKEN"
    echo "  - GMAIL credentials (optional)"
    echo "  - OPENAI_API_KEY (optional)"
    echo "  - TAILSCALE_AUTH_KEY (optional)"
}