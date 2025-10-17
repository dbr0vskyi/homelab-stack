#!/bin/bash

# SSL certificate management with Tailscale integration

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/tailscale.sh"

setup_ssl_certificates() {
    log_info "Setting up SSL certificates for n8n HTTPS..."
    
    # Create SSL directory
    mkdir -p config/ssl
    
    # Detect hostname and certificate type (sets global variables)
    detect_certificate_config
    
    # Check existing certificates
    if certificates_valid "$SSL_HOSTNAME"; then
        log_success "Existing SSL certificates are valid and match hostname"
        return
    fi
    
    # Generate certificates
    if [[ "$USE_TAILSCALE_CERT" == true ]]; then
        generate_tailscale_certificate_ssl "$SSL_HOSTNAME" || generate_self_signed_certificate "$SSL_HOSTNAME"
    else
        generate_self_signed_certificate "$SSL_HOSTNAME"
    fi
}

detect_certificate_config() {
    log_info "Detecting certificate configuration..."
    
    # Try to detect Tailscale domain
    local tailscale_domain
    tailscale_domain=$(detect_tailscale_domain)
    
    if [[ $? -eq 0 && -n "$tailscale_domain" ]]; then
        SSL_HOSTNAME="$tailscale_domain"
        USE_TAILSCALE_CERT=true
        log_success "Found Tailscale domain: $SSL_HOSTNAME"
        return 0
    fi
    
    # Fallback to .env hostname
    if [[ -f "$ENV_FILE" ]]; then
        local env_hostname
        env_hostname=$(grep "^N8N_HOST=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '"')
        if [[ -n "$env_hostname" && "$env_hostname" != "localhost" ]]; then
            SSL_HOSTNAME="$env_hostname"
            
            # Check if it's a Tailscale domain
            if is_tailscale_domain "$env_hostname"; then
                USE_TAILSCALE_CERT=true
                log_info "Using Tailscale hostname from .env: $SSL_HOSTNAME"
            else
                USE_TAILSCALE_CERT=false
                log_info "Using hostname from .env: $SSL_HOSTNAME"
            fi
            return 0
        fi
    fi
    
    # Default hostname
    SSL_HOSTNAME="localhost"
    USE_TAILSCALE_CERT=false
    log_info "Using default hostname: $SSL_HOSTNAME"
    return 0
}



certificates_valid() {
    local hostname="$1"
    
    if [[ ! -f "config/ssl/cert.pem" || ! -f "config/ssl/key.pem" ]]; then
        return 1
    fi
    
    log_info "SSL certificates already exist, checking validity..."
    
    # Check expiry (more than 30 days)
    if ! openssl x509 -checkend 2592000 -noout -in config/ssl/cert.pem 2>/dev/null; then
        log_warning "SSL certificates are expired or expiring soon, regenerating..."
        return 1
    fi
    
    # Check hostname match
    local cert_cn=$(openssl x509 -subject -noout -in config/ssl/cert.pem 2>/dev/null | sed 's/.*CN=\([^,]*\).*/\1/')
    if [[ "$cert_cn" != "$hostname" ]]; then
        log_warning "Certificate hostname mismatch (cert: $cert_cn, needed: $hostname), regenerating..."
        return 1
    fi
    
    return 0
}

generate_tailscale_certificate_ssl() {
    local hostname="$1"
    
    # Use the library function from tailscale.sh
    if generate_tailscale_certificate "$hostname" "config/ssl/cert.pem" "config/ssl/key.pem"; then
        set_certificate_permissions
        log_success "Tailscale SSL certificate obtained successfully"
        log_info "Certificate valid for: $hostname"
        log_info "Certificate expires: $(openssl x509 -enddate -noout -in config/ssl/cert.pem | cut -d= -f2)"
        
        # Update .env file with Tailscale domain if different
        update_env_with_tailscale_domain "$hostname"
        return 0
    else
        log_warning "Falling back to self-signed certificate..."
        return 1
    fi
}

generate_self_signed_certificate() {
    local hostname="$1"
    
    log_info "Generating self-signed SSL certificate for hostname: $hostname"
    
    if openssl req -x509 -newkey rsa:4096 -keyout config/ssl/key.pem -out config/ssl/cert.pem \
        -days 365 -nodes -subj "/CN=$hostname" \
        -addext "subjectAltName=DNS:$hostname,DNS:localhost,IP:127.0.0.1" 2>/dev/null; then
        
        set_certificate_permissions
        log_success "Self-signed SSL certificate generated successfully"
        log_info "Certificate valid for: $hostname, localhost, 127.0.0.1"
        log_info "Certificate expires: $(openssl x509 -enddate -noout -in config/ssl/cert.pem | cut -d= -f2)"
        return 0
    else
        log_error "Failed to generate SSL certificates"
        log_warning "Falling back to HTTP mode. Edit docker-compose.yml to disable HTTPS if needed."
        return 1
    fi
}

set_certificate_permissions() {
    chmod 644 config/ssl/cert.pem
    chmod 600 config/ssl/key.pem
}

update_env_with_tailscale_domain() {
    local tailscale_domain="$1"
    
    if [[ -f "$ENV_FILE" && -n "$tailscale_domain" ]]; then
        local current_n8n_host=$(get_env_value "N8N_HOST")
        if [[ "$current_n8n_host" != "$tailscale_domain" ]]; then
            log_info "Updating N8N_HOST in .env to match Tailscale domain"
            if update_env_value "N8N_HOST" "$tailscale_domain"; then
                log_success "Updated N8N_HOST to: $tailscale_domain"
            else
                log_warning "Could not automatically update N8N_HOST. Please set:"
                log_warning "  N8N_HOST=$tailscale_domain"
            fi
        fi
    fi
}