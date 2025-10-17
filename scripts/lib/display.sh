#!/bin/bash

# Display setup information and status

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

show_info() {
    log_success "Homelab Stack setup complete!"
    echo
    
    show_service_urls
    show_credentials
    show_ssl_info
    show_next_steps
    show_management_commands
    
    log_success "Setup completed successfully! 🎉"
}

show_service_urls() {
    log_info "Service URLs:"
    
    local n8n_host=$(get_env_value "N8N_HOST")
    if [[ "$n8n_host" != "localhost" && -n "$n8n_host" ]]; then
        echo "  📊 n8n Workflows: https://$n8n_host (HTTPS enabled)"
    else
        echo "  📊 n8n Workflows: https://localhost (HTTPS enabled)"
    fi
    echo "  🤖 Ollama API: http://localhost:11434"
    echo
}

show_credentials() {
    log_info "Default Credentials:"
    echo "  👤 n8n Username: admin"
    echo "  🔑 n8n Password: (check .env file)"
    echo
}

show_ssl_info() {
    log_info "SSL Certificate Info:"
    
    if [[ -f "config/ssl/cert.pem" ]]; then
        local cert_expiry=$(openssl x509 -enddate -noout -in config/ssl/cert.pem 2>/dev/null | cut -d= -f2 || echo 'Unknown')
        local cert_hostname=$(openssl x509 -subject -noout -in config/ssl/cert.pem 2>/dev/null | sed 's/.*CN=\([^,]*\).*/\1/' || echo 'localhost')
        
        echo "  🔒 Certificate valid until: $cert_expiry"
        echo "  🌐 Certificate hostname: $cert_hostname"
    fi
    echo
}

show_next_steps() {
    log_info "Next Steps:"
    echo "  1. Configure your API tokens in the .env file"
    echo "  2. Access n8n and import workflow templates"
    echo "  3. Set up your Telegram bot and Notion integration"
    echo "  4. Test the automation workflows"
    echo
}

show_production_info() {
    log_info "For Production HTTPS:"
    echo "  📜 Replace self-signed certs with real ones in config/ssl/"
    echo "  🔧 Update N8N_HOST in .env with your domain name"
    echo "  🔄 Restart services: docker compose restart n8n"
    echo
}

show_management_commands() {
    log_info "Management Commands:"
    echo "  📈 View logs: docker compose logs -f"
    echo "  🔄 Restart: docker compose restart"
    echo "  🛑 Stop: docker compose down"
    echo "  🗄️ Backup: ./scripts/backup.sh"
}