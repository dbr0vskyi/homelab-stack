#!/bin/bash

# WiFi Recovery and Management Script
# Manual WiFi troubleshooting, configuration, and network management

set -euo pipefail

# Get script directory and source library modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source required library modules
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/wifi.sh"

# Interactive WiFi network connection
interactive_wifi_connect() {
    log_info "WiFi Network Connection Wizard"
    echo ""
    
    # Check prerequisites
    if ! is_wifi_available; then
        log_error "No WiFi management tools available"
        log_info "Please install NetworkManager: sudo apt install network-manager"
        return 1
    fi
    
    local interface
    interface=$(get_wifi_interface)
    
    if [[ -z "$interface" ]]; then
        log_error "No WiFi interface found"
        log_info "Available network interfaces:"
        ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | tr -d ' '
        return 1
    fi
    
    log_success "WiFi interface found: $interface"
    echo ""
    
    # Scan for networks
    log_info "Scanning for available networks..."
    local networks
    networks=$(scan_wifi_networks "$interface")
    
    if [[ -z "$networks" ]]; then
        log_error "No WiFi networks found"
        log_info "Try moving closer to a WiFi router or check if WiFi is enabled"
        return 1
    fi
    
    # Display available networks
    echo "Available WiFi networks:"
    echo "----------------------------------------"
    local i=1
    local network_list=()
    
    while IFS=: read -r ssid signal security; do
        if [[ -n "$ssid" && "$ssid" != "--" ]]; then
            printf "%2d. %-25s Signal: %-3s Security: %s\n" "$i" "$ssid" "$signal" "$security"
            network_list+=("$ssid")
            ((i++))
        fi
    done <<< "$networks"
    
    echo "----------------------------------------"
    echo ""
    
    # Get user selection
    local selection
    while true; do
        read -p "Select network (1-$((i-1))) or 'q' to quit: " selection
        
        if [[ "$selection" == "q" ]]; then
            log_info "Connection cancelled"
            return 0
        fi
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection < i )); then
            break
        else
            echo "Invalid selection. Please enter a number between 1 and $((i-1))."
        fi
    done
    
    local selected_ssid="${network_list[$((selection-1))]}"
    log_info "Selected network: $selected_ssid"
    
    # Get password if needed
    local password=""
    if [[ "$networks" == *"$selected_ssid"*"WPA"* ]] || [[ "$networks" == *"$selected_ssid"*"WEP"* ]]; then
        echo ""
        read -s -p "Enter password for '$selected_ssid': " password
        echo ""
        
        if [[ -z "$password" ]]; then
            log_error "Password is required for secured networks"
            return 1
        fi
    fi
    
    # Attempt connection
    echo ""
    log_info "Connecting to '$selected_ssid'..."
    
    if connect_wifi "$selected_ssid" "$password" "$interface"; then
        log_success "Successfully connected to '$selected_ssid'"
        
        # Verify connectivity
        sleep 5
        if test_connectivity; then
            log_success "Internet connectivity confirmed"
        else
            log_warning "Connected but no internet access - check network settings"
        fi
        
        return 0
    else
        log_error "Failed to connect to '$selected_ssid'"
        log_info "Please check the password and try again"
        return 1
    fi
}

# List saved WiFi connections
list_connections() {
    log_info "Saved WiFi connections:"
    echo ""
    
    if ! is_networkmanager_available; then
        log_error "NetworkManager not available"
        return 1
    fi
    
    local connections
    connections=$(list_saved_connections)
    
    if [[ -z "$connections" ]]; then
        echo "No saved WiFi connections found"
        return 0
    fi
    
    local i=1
    while IFS= read -r connection; do
        if [[ -n "$connection" ]]; then
            # Get connection details
            local status="Inactive"
            if nmcli connection show --active | grep -q "^$connection "; then
                status="Active"
            fi
            
            printf "%2d. %-30s Status: %s\n" "$i" "$connection" "$status"
            ((i++))
        fi
    done <<< "$connections"
}

# Forget WiFi network
forget_network() {
    local connection_name="$1"
    
    if [[ -z "$connection_name" ]]; then
        log_error "Connection name is required"
        log_info "Usage: $0 forget <connection-name>"
        return 1
    fi
    
    log_info "Removing WiFi connection: $connection_name"
    
    if delete_wifi_connection "$connection_name"; then
        log_success "Connection '$connection_name' removed successfully"
    else
        log_error "Failed to remove connection '$connection_name'"
        return 1
    fi
}

# Interactive forget network
interactive_forget() {
    log_info "Remove Saved WiFi Connection"
    echo ""
    
    if ! is_networkmanager_available; then
        log_error "NetworkManager not available"
        return 1
    fi
    
    local connections
    connections=$(list_saved_connections)
    
    if [[ -z "$connections" ]]; then
        log_info "No saved WiFi connections to remove"
        return 0
    fi
    
    # Display connections
    echo "Saved WiFi connections:"
    echo "----------------------------------------"
    local i=1
    local connection_list=()
    
    while IFS= read -r connection; do
        if [[ -n "$connection" ]]; then
            printf "%2d. %s\n" "$i" "$connection"
            connection_list+=("$connection")
            ((i++))
        fi
    done <<< "$connections"
    
    echo "----------------------------------------"
    echo ""
    
    # Get user selection
    local selection
    while true; do
        read -p "Select connection to remove (1-$((i-1))) or 'q' to quit: " selection
        
        if [[ "$selection" == "q" ]]; then
            log_info "Operation cancelled"
            return 0
        fi
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection < i )); then
            break
        else
            echo "Invalid selection. Please enter a number between 1 and $((i-1))."
        fi
    done
    
    local selected_connection="${connection_list[$((selection-1))]}"
    
    # Confirm deletion
    echo ""
    read -p "Are you sure you want to remove '$selected_connection'? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        forget_network "$selected_connection"
    else
        log_info "Operation cancelled"
    fi
}

# WiFi configuration backup
backup_config() {
    local backup_file="${1:-}"
    
    if [[ -z "$backup_file" ]]; then
        backup_file="${WIFI_CONFIG_DIR}/wifi-backup-$(date +%Y%m%d-%H%M%S).json"
    fi
    
    log_info "Creating WiFi configuration backup..."
    
    if backup_wifi_configs "$backup_file"; then
        log_success "WiFi configurations backed up to: $backup_file"
    else
        log_error "Failed to create backup"
        return 1
    fi
}

# Show current WiFi information
show_wifi_info() {
    log_info "Current WiFi Information"
    echo ""
    
    # Interface information
    local interface
    interface=$(get_wifi_interface)
    
    if [[ -n "$interface" ]]; then
        echo "WiFi Interface: $interface"
        echo "Interface Status: $(is_wifi_interface_up "$interface" && echo "UP" || echo "DOWN")"
    else
        echo "WiFi Interface: Not found"
        echo ""
        return 1
    fi
    
    # Connection status
    local wifi_status
    wifi_status=$(get_wifi_status)
    echo "Connection Status: $wifi_status"
    
    # IP address information
    local ip_addr
    ip_addr=$(ip addr show "$interface" | grep -oP 'inet \K[\d.]+' | head -1)
    echo "IP Address: ${ip_addr:-Not assigned}"
    
    # Gateway information
    local gateway
    gateway=$(ip route | awk '/default/ {print $3}' | head -1)
    echo "Gateway: ${gateway:-Not found}"
    
    # DNS information
    echo "DNS Servers:"
    if [[ -f /etc/resolv.conf ]]; then
        grep nameserver /etc/resolv.conf | awk '{print "  " $2}'
    else
        echo "  Not available"
    fi
    
    echo ""
    
    # Signal strength (if available)
    if command -v iwconfig >/dev/null 2>&1; then
        local signal_info
        signal_info=$(iwconfig "$interface" 2>/dev/null | grep -oP 'Signal level=\K[^\s]+' || echo "Not available")
        echo "Signal Strength: $signal_info"
    fi
    
    # Speed information
    if is_networkmanager_available; then
        local speed_info
        speed_info=$(nmcli device show "$interface" | grep -E "GENERAL.SPEED" | awk '{print $2}' || echo "Not available")
        echo "Connection Speed: ${speed_info} Mbps"
    fi
    
    echo ""
    
    # Connectivity tests
    echo "Connectivity Tests:"
    echo -n "  Local (Gateway): "
    if test_local_connectivity; then
        echo "✓ PASS"
    else
        echo "✗ FAIL"
    fi
    
    echo -n "  Internet: "
    if test_connectivity; then
        echo "✓ PASS"
    else
        echo "✗ FAIL"
    fi
}

# Quick WiFi recovery
quick_recovery() {
    log_info "Performing quick WiFi recovery..."
    
    if wifi_recovery_soft; then
        log_success "Quick recovery completed successfully"
        return 0
    else
        log_warning "Quick recovery failed, trying full recovery..."
        
        if wifi_recovery_full; then
            log_success "Full recovery completed successfully"
            return 0
        else
            log_error "All recovery attempts failed"
            return 1
        fi
    fi
}

# WiFi network scan
scan_networks() {
    local interface="${1:-$(get_wifi_interface)}"
    
    if [[ -z "$interface" ]]; then
        log_error "No WiFi interface found"
        return 1
    fi
    
    log_info "Scanning WiFi networks on $interface..."
    echo ""
    
    local networks
    networks=$(scan_wifi_networks "$interface")
    
    if [[ -z "$networks" ]]; then
        log_warning "No networks found"
        return 0
    fi
    
    echo "Available WiFi Networks:"
    echo "=========================================="
    printf "%-25s %-8s %s\n" "SSID" "Signal" "Security"
    echo "------------------------------------------"
    
    while IFS=: read -r ssid signal security; do
        if [[ -n "$ssid" && "$ssid" != "--" ]]; then
            printf "%-25s %-8s %s\n" "$ssid" "$signal" "$security"
        fi
    done <<< "$networks"
    
    echo "=========================================="
}

# Emergency access point mode (placeholder for future implementation)
emergency_hotspot() {
    log_warning "Emergency hotspot mode not yet implemented"
    log_info "This feature will create a WiFi access point for emergency access"
    log_info "For now, use ethernet connection or manual WiFi configuration"
}

# Show help
show_help() {
    cat << EOF
🔧 WiFi Recovery and Management Tool

Usage: $0 <command> [options]

Connection Management:
  connect              Interactive WiFi connection wizard
  disconnect           Disconnect from current WiFi network
  reconnect            Reconnect to current WiFi network
  info                 Show current WiFi connection information
  scan                 Scan for available WiFi networks
  
Network Management:
  list                 List saved WiFi connections
  forget <name>        Remove saved WiFi connection
  forget-interactive   Interactively remove saved connections
  
Recovery Operations:
  recovery             Perform quick WiFi recovery
  recovery-soft        Soft recovery (restart interface)
  recovery-hard        Hard recovery (restart NetworkManager)
  recovery-full        Full recovery sequence
  
Configuration:
  backup [file]        Backup WiFi configurations
  restore <file>       Restore WiFi configurations (placeholder)
  diagnostics          Run comprehensive WiFi diagnostics
  
Emergency:
  hotspot              Enable emergency access point (placeholder)

Examples:
  $0 connect           # Connect to WiFi network interactively
  $0 info              # Show current WiFi status
  $0 scan              # Scan for networks
  $0 recovery          # Fix connectivity issues
  $0 backup            # Backup current config
  $0 diagnostics       # Run full diagnostics

Note: Most operations require sudo privileges for network management.

EOF
}

# Main execution
main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        "connect")
            interactive_wifi_connect
            ;;
        "disconnect")
            disconnect_wifi
            ;;
        "reconnect")
            local interface
            interface=$(get_wifi_interface)
            if [[ -n "$interface" ]]; then
                disconnect_wifi "$interface"
                sleep 2
                restart_wifi_interface "$interface"
            else
                log_error "No WiFi interface found"
                exit 1
            fi
            ;;
        "info")
            show_wifi_info
            ;;
        "scan")
            scan_networks "$@"
            ;;
        "list")
            list_connections
            ;;
        "forget")
            forget_network "$1"
            ;;
        "forget-interactive")
            interactive_forget
            ;;
        "recovery")
            quick_recovery
            ;;
        "recovery-soft")
            wifi_recovery_soft
            ;;
        "recovery-hard")
            wifi_recovery_hard
            ;;
        "recovery-full")
            wifi_recovery_full
            ;;
        "backup")
            backup_config "$1"
            ;;
        "restore")
            restore_wifi_configs "$1"
            ;;
        "diagnostics")
            wifi_diagnostics
            ;;
        "hotspot")
            emergency_hotspot
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Initialize script environment
init_script

# Run main function with all arguments
main "$@"