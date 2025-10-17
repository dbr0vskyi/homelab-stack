#!/bin/bash

# Tailscale Operations Library
# Common Tailscale operations for homelab stack

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Tailscale utility functions
is_tailscale_installed() {
    command -v tailscale &>/dev/null
}

is_tailscale_connected() {
    tailscale status --json &>/dev/null
}

get_tailscale_status_json() {
    if is_tailscale_connected; then
        tailscale status --json 2>/dev/null
    else
        return 1
    fi
}

get_tailscale_self_info() {
    local tailscale_json
    tailscale_json=$(get_tailscale_status_json) || return 1
    
    local hostname machine_name dns_name tailnet_suffix ip_address
    
    hostname=$(echo "$tailscale_json" | jq -r '.Self.HostName')
    machine_name=$(echo "$tailscale_json" | jq -r '.Self.HostName')
    dns_name=$(echo "$tailscale_json" | jq -r '.Self.DNSName')
    tailnet_suffix=$(echo "$tailscale_json" | jq -r '.MagicDNSSuffix')
    ip_address=$(echo "$tailscale_json" | jq -r '.Self.TailscaleIPs[0]')
    
    # Export as global variables for easy access
    TAILSCALE_HOSTNAME="$hostname"
    TAILSCALE_MACHINE_NAME="$machine_name"
    TAILSCALE_DNS_NAME="$dns_name"
    TAILSCALE_TAILNET_SUFFIX="$tailnet_suffix"
    TAILSCALE_IP="$ip_address"
    
    return 0
}

is_magicdns_enabled() {
    get_tailscale_self_info || return 1
    
    if [[ -n "$TAILSCALE_TAILNET_SUFFIX" && "$TAILSCALE_TAILNET_SUFFIX" != "null" && "$TAILSCALE_TAILNET_SUFFIX" != "" ]]; then
        return 0
    else
        return 1
    fi
}

# Domain detection with fallbacks
detect_tailscale_domain() {
    log_info "Checking for Tailscale availability..." >&2
    
    if ! is_tailscale_installed; then
        log_info "Tailscale not found in PATH" >&2
        return 1
    fi
    
    if ! is_tailscale_connected; then
        log_info "Tailscale is installed but not logged in" >&2
        log_info "Run 'tailscale up' to connect" >&2
        return 1
    fi
    
    if ! command_exists jq; then
        log_warning "jq not available, cannot parse Tailscale config" >&2
        return 1
    fi
    
    if ! get_tailscale_self_info; then
        log_error "Failed to get Tailscale self info" >&2
        return 1
    fi
    
    if is_magicdns_enabled; then
        echo "$TAILSCALE_DNS_NAME"
        log_info "MagicDNS is enabled with suffix: $TAILSCALE_TAILNET_SUFFIX" >&2
        return 0
    else
        log_warning "Tailscale is running but MagicDNS is not enabled" >&2
        log_info "Enable MagicDNS at: https://login.tailscale.com/admin/dns" >&2
        return 1
    fi
}

# Certificate operations
can_generate_tailscale_cert() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        log_error "Domain is required for certificate check"
        return 1
    fi
    
    if ! is_tailscale_installed; then
        return 1
    fi
    
    if ! is_tailscale_connected; then
        return 1
    fi
    
    # Test certificate generation without actually creating files
    local temp_dir=$(mktemp -d)
    local result=0
    
    if tailscale cert --cert-file "$temp_dir/test-cert.pem" --key-file "$temp_dir/test-key.pem" "$domain" &>/dev/null; then
        result=0
    else
        result=1
    fi
    
    rm -rf "$temp_dir"
    return $result
}

generate_tailscale_certificate() {
    local hostname="$1"
    local cert_path="${2:-config/ssl/cert.pem}"
    local key_path="${3:-config/ssl/key.pem}"
    
    if [[ -z "$hostname" ]]; then
        log_error "Hostname is required"
        return 1
    fi
    
    log_info "Attempting to get Tailscale certificate for: $hostname"
    
    # Ensure SSL directory exists
    mkdir -p "$(dirname "$cert_path")"
    mkdir -p "$(dirname "$key_path")"
    
    if tailscale cert --cert-file "$cert_path" --key-file "$key_path" "$hostname" 2>/dev/null; then
        log_success "Generated Tailscale certificate for $hostname"
        return 0
    else
        log_warning "Failed to get Tailscale certificate. Possible reasons:"
        log_warning "  - Certificate permissions in Tailscale admin"
        log_warning "  - Domain not properly configured"
        log_warning "  - MagicDNS propagation delay"
        return 1
    fi
}

# DNS operations
test_tailscale_dns_resolution() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        get_tailscale_self_info || return 1
        domain="$TAILSCALE_DNS_NAME"
    fi
    
    log_info "Testing DNS resolution for $domain..."
    
    if nslookup "$domain" &>/dev/null || dig "$domain" &>/dev/null || host "$domain" &>/dev/null; then
        log_success "DNS resolution works for $domain"
        return 0
    else
        log_error "DNS resolution failed for $domain"
        log_info "Possible causes:"
        log_info "  - MagicDNS propagation delay (try again in a few minutes)"
        log_info "  - Local DNS cache (try: sudo dscacheutil -flushcache on macOS)"
        log_info "  - Network connectivity issues"
        return 1
    fi
}

# Tailscale setup validation
validate_tailscale_setup() {
    local domain="${1:-}"
    
    log_info "Validating Tailscale setup..."
    
    # Check installation
    if ! is_tailscale_installed; then
        log_error "Tailscale is not installed or not in PATH"
        log_info "Install from: https://tailscale.com/download"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            log_info "macOS: brew install tailscale"
        else
            log_info "Linux: curl -fsSL https://tailscale.com/install.sh | sh"
        fi
        return 1
    fi
    
    log_success "Tailscale is installed"
    
    # Check connection
    if ! is_tailscale_connected; then
        log_error "Tailscale is not logged in or running"
        log_info "Run: tailscale up"
        log_info "Steps to connect:"
        log_info "  1. Run: tailscale up"
        log_info "  2. Follow the authentication URL"
        log_info "  3. Run this script again"
        return 1
    fi
    
    log_success "Tailscale is connected"
    
    # Get self info
    if ! get_tailscale_self_info; then
        log_error "Failed to get Tailscale information"
        return 1
    fi
    
    # Check MagicDNS
    if ! is_magicdns_enabled; then
        log_error "MagicDNS is not enabled"
        log_info "Enable it at: https://login.tailscale.com/admin/dns"
        log_info "Without MagicDNS, you can only use IP addresses for HTTPS:"
        log_info "N8N_HOST=$TAILSCALE_IP"
        log_warning "IP-based certificates will show browser warnings"
        log_info "Recommendation: Enable MagicDNS for trusted certificates"
        return 1
    fi
    
    log_success "MagicDNS is enabled"
    
    # Use provided domain or detected domain
    local test_domain="$domain"
    if [[ -z "$test_domain" ]]; then
        test_domain="$TAILSCALE_DNS_NAME"
    fi
    
    # Test DNS resolution
    if ! test_tailscale_dns_resolution "$test_domain"; then
        return 1
    fi
    
    # Test certificate generation
    if ! can_generate_tailscale_cert "$test_domain"; then
        log_error "Tailscale certificate generation failed"
        log_info "Possible causes:"
        log_info "  - Certificate permissions in Tailscale admin console"
        log_info "  - Account limitations (free vs paid)"
        log_info "  - Network connectivity issues"
        return 1
    fi
    
    log_success "Tailscale certificate generation works"
    
    return 0
}

# Display Tailscale configuration info
show_tailscale_info() {
    if ! get_tailscale_self_info; then
        log_error "Cannot retrieve Tailscale information"
        return 1
    fi
    
    echo
    echo "📋 Your Tailscale Configuration:"
    echo "   🖥️  Machine Name: $TAILSCALE_MACHINE_NAME"
    echo "   🌐 Tailnet Suffix: $TAILSCALE_TAILNET_SUFFIX"
    echo "   📡 Your DNS Name: $TAILSCALE_DNS_NAME"
    echo "   🔢 Your Tailscale IP: $TAILSCALE_IP"
    echo
    
    if is_magicdns_enabled; then
        echo "🎯 Recommended configuration:"
        echo "   N8N_HOST=$TAILSCALE_DNS_NAME"
        echo
        echo "🌐 Access URL:"
        echo "   https://$TAILSCALE_DNS_NAME"
    else
        echo "⚠️  MagicDNS is not enabled"
        echo "   Enable at: https://login.tailscale.com/admin/dns"
    fi
    
    echo
    echo "📚 Additional Resources:"
    echo "   • Tailscale Admin: https://login.tailscale.com/admin"
    echo "   • MagicDNS Setup: https://tailscale.com/kb/1081/magicdns/"
    echo "   • Certificate Setup: https://tailscale.com/kb/1153/enabling-https/"
}

# Interactive setup helper
interactive_tailscale_setup() {
    echo "🔍 Tailscale Domain Discovery Helper"
    echo "===================================="
    echo
    
    # Ensure jq is available
    if ! command_exists jq; then
        log_warning "jq is not installed. Installing via package manager..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command_exists brew; then
                brew install jq
            else
                log_error "Homebrew not found. Please install jq manually: brew install jq"
                return 1
            fi
        else
            log_error "jq is required for JSON parsing. Install it with your package manager"
            log_info "Ubuntu/Debian: sudo apt install jq"
            log_info "CentOS/RHEL: sudo yum install jq"
            return 1
        fi
    fi
    
    # Validate setup
    if validate_tailscale_setup; then
        show_tailscale_info
        
        echo "🚀 Ready to use Tailscale certificates!"
        echo
        echo "✨ Automatic Setup (Recommended):"
        echo "   ./scripts/setup.sh ssl"
        echo "   ↳ This will automatically detect and use your Tailscale domain"
        echo
        echo "🔧 Manual Setup:"
        echo "   1. Update .env: N8N_HOST=$TAILSCALE_DNS_NAME"
        echo "   2. Generate cert: ./scripts/setup.sh ssl"
        echo "   3. Restart: docker compose restart n8n"
        echo
        
        # Ask if user wants to run setup automatically
        echo "❓ Would you like to run the SSL setup automatically now? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo
            log_info "Running SSL setup..."
            if [[ -f "scripts/setup.sh" ]]; then
                scripts/setup.sh ssl
            elif [[ -f "./setup.sh" ]]; then
                ./setup.sh ssl
            else
                log_warning "Setup script not found. Please run manually:"
                log_info "./scripts/setup.sh ssl"
            fi
        fi
    else
        log_error "Tailscale setup validation failed"
        return 1
    fi
}

# Utility function to check if domain is a Tailscale domain
is_tailscale_domain() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        return 1
    fi
    
    # Check if domain ends with .ts.net (Tailscale domains)
    if [[ "$domain" == *".ts.net"* ]]; then
        return 0
    fi
    
    # Check against known Tailscale domain if available
    if get_tailscale_self_info && [[ "$domain" == "$TAILSCALE_DNS_NAME" ]]; then
        return 0
    fi
    
    return 1
}