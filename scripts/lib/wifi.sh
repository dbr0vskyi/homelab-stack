#!/bin/bash

# WiFi Management Library
# Handles WiFi connectivity monitoring, recovery, and configuration

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# WiFi configuration
readonly WIFI_CONFIG_DIR="${PROJECT_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}/config/wifi"
readonly WIFI_LOG_DIR="/var/log/homelab"
readonly WIFI_LOG_FILE="${WIFI_LOG_DIR}/wifi-monitor.log"
readonly CONNECTIVITY_TIMEOUT=10
readonly RECOVERY_ATTEMPTS=3
readonly MONITOR_INTERVAL=30

# WiFi utility functions
is_wifi_available() {
    command -v nmcli &>/dev/null || command -v wpa_cli &>/dev/null
}

is_networkmanager_available() {
    command -v nmcli &>/dev/null && systemctl is-active --quiet NetworkManager 2>/dev/null
}

is_wpa_supplicant_available() {
    command -v wpa_cli &>/dev/null && systemctl is-active --quiet wpa_supplicant 2>/dev/null
}

# Get WiFi interface name
get_wifi_interface() {
    if is_networkmanager_available; then
        nmcli -t -f DEVICE,TYPE device | grep wifi | head -1 | cut -d: -f1
    else
        # Fallback to common interface names
        for iface in wlan0 wlp2s0 wlp3s0; do
            if [[ -d "/sys/class/net/$iface" ]]; then
                echo "$iface"
                return 0
            fi
        done
    fi
    return 1
}

# Check if WiFi interface is up
is_wifi_interface_up() {
    local interface="${1:-$(get_wifi_interface)}"
    [[ -n "$interface" ]] && ip link show "$interface" | grep -q "state UP"
}

# Get current WiFi connection status
get_wifi_status() {
    local interface="${1:-$(get_wifi_interface)}"
    
    if [[ -z "$interface" ]]; then
        echo "NO_INTERFACE"
        return 1
    fi
    
    if is_networkmanager_available; then
        local status=$(nmcli -t -f STATE general status)
        local connection=$(nmcli -t -f NAME connection show --active | grep -v "^$" | head -1)

        case "$status" in
            "connected (global)"|"connected")
                # Both old format "connected (global)" and new format "connected" indicate full connectivity
                echo "CONNECTED:$connection"
                return 0
                ;;
            "connected (local only)")
                echo "LOCAL_ONLY:$connection"
                return 1
                ;;
            "connecting")
                echo "CONNECTING"
                return 1
                ;;
            *)
                echo "DISCONNECTED"
                return 1
                ;;
        esac
    else
        # Fallback using interface status
        if is_wifi_interface_up "$interface"; then
            local ssid=$(iwgetid -r "$interface" 2>/dev/null || echo "unknown")
            echo "CONNECTED:$ssid"
            return 0
        else
            echo "DISCONNECTED"
            return 1
        fi
    fi
}

# Test internet connectivity with multiple targets
test_connectivity() {
    local targets=(
        "1.1.1.1"          # Cloudflare DNS
        "8.8.8.8"          # Google DNS
        "208.67.222.222"   # OpenDNS
    )
    
    log_debug "Testing internet connectivity..."
    
    for target in "${targets[@]}"; do
        if ping -c 2 -W "$CONNECTIVITY_TIMEOUT" "$target" &>/dev/null; then
            log_debug "Connectivity test passed: $target"
            return 0
        fi
    done
    
    log_debug "All connectivity tests failed"
    return 1
}

# Test local network connectivity (router)
test_local_connectivity() {
    local gateway
    gateway=$(ip route | awk '/default/ {print $3}' | head -1)
    
    if [[ -n "$gateway" ]]; then
        log_debug "Testing local connectivity to gateway: $gateway"
        ping -c 2 -W "$CONNECTIVITY_TIMEOUT" "$gateway" &>/dev/null
    else
        log_debug "No default gateway found"
        return 1
    fi
}

# Get available WiFi networks
scan_wifi_networks() {
    local interface="${1:-$(get_wifi_interface)}"
    
    if [[ -z "$interface" ]]; then
        log_error "No WiFi interface found"
        return 1
    fi
    
    log_info "Scanning for WiFi networks on $interface..."
    
    if is_networkmanager_available; then
        # Trigger scan and wait
        nmcli device wifi rescan ifname "$interface" 2>/dev/null || true
        sleep 2
        nmcli -t -f SSID,SIGNAL,SECURITY device wifi list ifname "$interface" | \
            sort -t: -k2 -nr | head -20
    else
        # Fallback using iwlist
        iwlist "$interface" scan 2>/dev/null | \
            awk '/ESSID:/ {essid=$0} /Quality=/ {quality=$0} /Encryption/ {enc=$0} essid && quality {print essid ":" quality ":" enc; essid=""; quality=""; enc=""}'
    fi
}

# Connect to WiFi network
connect_wifi() {
    local ssid="$1"
    local password="$2"
    local interface="${3:-$(get_wifi_interface)}"
    
    if [[ -z "$ssid" ]]; then
        log_error "SSID is required"
        return 1
    fi
    
    if [[ -z "$interface" ]]; then
        log_error "No WiFi interface found"
        return 1
    fi
    
    log_info "Connecting to WiFi network: $ssid"
    
    if is_networkmanager_available; then
        if [[ -n "$password" ]]; then
            nmcli device wifi connect "$ssid" password "$password" ifname "$interface"
        else
            nmcli device wifi connect "$ssid" ifname "$interface"
        fi
    else
        log_error "NetworkManager not available, manual wpa_supplicant configuration required"
        return 1
    fi
}

# Disconnect from current WiFi
disconnect_wifi() {
    local interface="${1:-$(get_wifi_interface)}"
    
    if [[ -z "$interface" ]]; then
        log_error "No WiFi interface found"
        return 1
    fi
    
    log_info "Disconnecting WiFi interface: $interface"
    
    if is_networkmanager_available; then
        nmcli device disconnect "$interface"
    else
        ip link set "$interface" down
    fi
}

# Restart WiFi interface
restart_wifi_interface() {
    local interface="${1:-$(get_wifi_interface)}"
    
    if [[ -z "$interface" ]]; then
        log_error "No WiFi interface found"
        return 1
    fi
    
    log_info "Restarting WiFi interface: $interface"
    
    # Method 1: NetworkManager
    if is_networkmanager_available; then
        nmcli device set "$interface" managed no
        sleep 2
        nmcli device set "$interface" managed yes
        sleep 5
        return 0
    fi
    
    # Method 2: Direct interface control
    ip link set "$interface" down
    sleep 2
    ip link set "$interface" up
    sleep 5
}

# Restart NetworkManager service
restart_networkmanager() {
    log_info "Restarting NetworkManager service..."
    
    if systemctl is-active --quiet NetworkManager; then
        sudo systemctl restart NetworkManager
        sleep 10
        return $?
    else
        log_error "NetworkManager service not available"
        return 1
    fi
}

# Get saved WiFi connections
list_saved_connections() {
    if is_networkmanager_available; then
        nmcli -t -f NAME,TYPE connection show | grep wifi | cut -d: -f1
    else
        log_warning "NetworkManager not available, cannot list saved connections"
        return 1
    fi
}

# Delete WiFi connection profile
delete_wifi_connection() {
    local connection_name="$1"
    
    if [[ -z "$connection_name" ]]; then
        log_error "Connection name is required"
        return 1
    fi
    
    if is_networkmanager_available; then
        log_info "Deleting WiFi connection: $connection_name"
        nmcli connection delete "$connection_name"
    else
        log_error "NetworkManager not available"
        return 1
    fi
}

# Backup WiFi configurations
backup_wifi_configs() {
    local backup_file="${1:-${WIFI_CONFIG_DIR}/wifi-backup-$(date +%Y%m%d-%H%M%S).json}"
    
    mkdir -p "$(dirname "$backup_file")"
    
    log_info "Backing up WiFi configurations to: $backup_file"
    
    if is_networkmanager_available; then
        # Export all WiFi connections as JSON
        local connections=()
        while IFS= read -r connection; do
            if [[ -n "$connection" ]]; then
                connections+=("$connection")
            fi
        done < <(nmcli -t -f NAME connection show | grep -E "(wifi|wireless)")
        
        {
            echo "{"
            echo "  \"timestamp\": \"$(date -Iseconds)\","
            echo "  \"hostname\": \"$(hostname)\","
            echo "  \"connections\": ["
            
            local first=true
            for conn in "${connections[@]}"; do
                if [[ "$first" != true ]]; then
                    echo ","
                fi
                first=false
                
                echo -n "    {\"name\": \"$conn\", \"config\": \""
                nmcli connection show "$conn" | base64 -w 0
                echo -n "\"}"
            done
            
            echo ""
            echo "  ]"
            echo "}"
        } > "$backup_file"
        
        log_success "WiFi configurations backed up: ${#connections[@]} connections"
    else
        log_error "NetworkManager not available for backup"
        return 1
    fi
}

# Restore WiFi configurations
restore_wifi_configs() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    if ! is_networkmanager_available; then
        log_error "NetworkManager not available for restore"
        return 1
    fi
    
    log_info "Restoring WiFi configurations from: $backup_file"
    log_warning "This is a placeholder - manual restoration required"
    log_info "Use: nmcli connection import type wifi file <connection-file>"
    
    # TODO: Implement full restoration logic
    return 1
}

# WiFi recovery procedures
wifi_recovery_soft() {
    log_info "Attempting soft WiFi recovery..."
    
    local interface
    interface=$(get_wifi_interface)
    
    if [[ -z "$interface" ]]; then
        log_error "No WiFi interface found"
        return 1
    fi
    
    # Step 1: Restart interface
    log_info "Step 1: Restarting WiFi interface"
    restart_wifi_interface "$interface"
    sleep 10
    
    # Step 2: Test connectivity
    if test_connectivity; then
        log_success "Soft recovery successful"
        return 0
    fi
    
    # Step 3: Try reconnecting to current network
    local current_connection
    current_connection=$(nmcli -t -f NAME connection show --active | grep -v "^$" | head -1)
    
    if [[ -n "$current_connection" ]]; then
        log_info "Step 3: Reconnecting to: $current_connection"
        nmcli connection down "$current_connection"
        sleep 2
        nmcli connection up "$current_connection"
        sleep 10
        
        if test_connectivity; then
            log_success "Reconnection successful"
            return 0
        fi
    fi
    
    log_warning "Soft recovery failed"
    return 1
}

wifi_recovery_hard() {
    log_info "Attempting hard WiFi recovery..."
    
    # Step 1: Restart NetworkManager
    log_info "Step 1: Restarting NetworkManager"
    if restart_networkmanager; then
        sleep 15
        
        if test_connectivity; then
            log_success "Hard recovery successful"
            return 0
        fi
    fi
    
    # Step 2: Manual interface reset
    log_info "Step 2: Manual interface reset"
    local interface
    interface=$(get_wifi_interface)
    
    if [[ -n "$interface" ]]; then
        sudo modprobe -r iwlwifi 2>/dev/null || true
        sleep 2
        sudo modprobe iwlwifi 2>/dev/null || true
        sleep 5
        
        restart_wifi_interface "$interface"
        sleep 10
        
        if test_connectivity; then
            log_success "Interface reset successful"
            return 0
        fi
    fi
    
    log_error "Hard recovery failed - manual intervention required"
    return 1
}

# Full WiFi recovery sequence
wifi_recovery_full() {
    local attempt=1
    
    log_info "Starting full WiFi recovery sequence..."
    
    while (( attempt <= RECOVERY_ATTEMPTS )); do
        log_info "Recovery attempt $attempt of $RECOVERY_ATTEMPTS"
        
        # Try soft recovery first
        if wifi_recovery_soft; then
            log_success "Recovery successful on attempt $attempt"
            return 0
        fi
        
        # If soft fails and it's not the last attempt, try hard recovery
        if (( attempt < RECOVERY_ATTEMPTS )); then
            log_info "Soft recovery failed, trying hard recovery..."
            if wifi_recovery_hard; then
                log_success "Recovery successful on attempt $attempt"
                return 0
            fi
        fi
        
        ((attempt++))
        if (( attempt <= RECOVERY_ATTEMPTS )); then
            log_info "Waiting before next attempt..."
            sleep 30
        fi
    done
    
    log_error "All recovery attempts failed"
    return 1
}

# Monitor WiFi connectivity
monitor_wifi_connectivity() {
    local check_interval="${1:-$MONITOR_INTERVAL}"
    local failure_count=0
    local max_failures=3
    
    log_info "Starting WiFi connectivity monitoring (interval: ${check_interval}s)"
    
    # Ensure log directory exists
    sudo mkdir -p "$WIFI_LOG_DIR"
    
    while true; do
        local wifi_status
        wifi_status=$(get_wifi_status)
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        if test_connectivity; then
            if (( failure_count > 0 )); then
                log_success "Connectivity restored"
                echo "$timestamp [INFO] Connectivity restored after $failure_count failures" | sudo tee -a "$WIFI_LOG_FILE" >/dev/null
                failure_count=0
            fi
            
            log_debug "Connectivity check passed: $wifi_status"
            echo "$timestamp [DEBUG] Connectivity OK: $wifi_status" | sudo tee -a "$WIFI_LOG_FILE" >/dev/null
        else
            ((failure_count++))
            log_warning "Connectivity check failed ($failure_count/$max_failures): $wifi_status"
            echo "$timestamp [WARN] Connectivity failed ($failure_count/$max_failures): $wifi_status" | sudo tee -a "$WIFI_LOG_FILE" >/dev/null
            
            if (( failure_count >= max_failures )); then
                log_error "Multiple connectivity failures detected, starting recovery"
                echo "$timestamp [ERROR] Starting recovery after $failure_count failures" | sudo tee -a "$WIFI_LOG_FILE" >/dev/null
                
                if wifi_recovery_full; then
                    failure_count=0
                    echo "$timestamp [SUCCESS] Recovery completed successfully" | sudo tee -a "$WIFI_LOG_FILE" >/dev/null
                else
                    echo "$timestamp [ERROR] Recovery failed - manual intervention required" | sudo tee -a "$WIFI_LOG_FILE" >/dev/null
                    # Send alert if n8n webhook is available
                    send_wifi_alert "WiFi recovery failed on $(hostname)" "Manual intervention required"
                fi
            fi
        fi
        
        sleep "$check_interval"
    done
}

# Send WiFi alert via n8n webhook
send_wifi_alert() {
    local title="$1"
    local message="$2"
    local webhook_url="${N8N_WEBHOOK_URL:-}"
    
    if [[ -z "$webhook_url" ]]; then
        log_debug "No N8N webhook URL configured for alerts"
        return 0
    fi
    
    log_info "Sending WiFi alert: $title"
    
    local payload=$(cat <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "alert_type": "wifi_connectivity",
  "title": "$title",
  "message": "$message",
  "wifi_status": "$(get_wifi_status)"
}
EOF
)
    
    curl -s -X POST "$webhook_url" \
        -H "Content-Type: application/json" \
        -d "$payload" &>/dev/null || log_debug "Failed to send webhook alert"
}

# Initialize WiFi monitoring setup
init_wifi_monitoring() {
    log_info "Initializing WiFi monitoring setup..."
    
    # Check prerequisites
    if ! is_wifi_available; then
        log_error "No WiFi management tools available (nmcli or wpa_cli)"
        return 1
    fi
    
    # Create directories
    mkdir -p "$WIFI_CONFIG_DIR"
    sudo mkdir -p "$WIFI_LOG_DIR"
    
    # Create initial backup
    if is_networkmanager_available; then
        log_info "Creating initial WiFi configuration backup..."
        backup_wifi_configs "${WIFI_CONFIG_DIR}/initial-backup.json"
    fi
    
    log_success "WiFi monitoring initialized"
}

# WiFi diagnostics
wifi_diagnostics() {
    log_info "Running WiFi diagnostics..."
    
    echo "=== WiFi System Information ==="
    echo "Hostname: $(hostname)"
    echo "Date: $(date)"
    echo "Kernel: $(uname -r)"
    echo ""
    
    echo "=== WiFi Tools Available ==="
    echo "NetworkManager: $(is_networkmanager_available && echo "YES" || echo "NO")"
    echo "wpa_supplicant: $(is_wpa_supplicant_available && echo "YES" || echo "NO")"
    echo "nmcli command: $(command -v nmcli || echo "NOT FOUND")"
    echo "iwconfig command: $(command -v iwconfig || echo "NOT FOUND")"
    echo ""
    
    echo "=== WiFi Interface Information ==="
    local interface
    interface=$(get_wifi_interface)
    if [[ -n "$interface" ]]; then
        echo "WiFi interface: $interface"
        echo "Interface status: $(is_wifi_interface_up "$interface" && echo "UP" || echo "DOWN")"
        echo "Interface details:"
        ip addr show "$interface" 2>/dev/null || echo "Failed to get interface details"
    else
        echo "No WiFi interface found"
    fi
    echo ""
    
    echo "=== Connection Status ==="
    local status
    status=$(get_wifi_status)
    echo "WiFi status: $status"
    
    if is_networkmanager_available; then
        echo ""
        echo "NetworkManager general status:"
        nmcli general status
        
        echo ""
        echo "Active connections:"
        nmcli connection show --active
        
        echo ""
        echo "Available connections:"
        nmcli connection show
    fi
    echo ""
    
    echo "=== Connectivity Tests ==="
    echo -n "Local connectivity (gateway): "
    test_local_connectivity && echo "PASS" || echo "FAIL"
    
    echo -n "Internet connectivity: "
    test_connectivity && echo "PASS" || echo "FAIL"
    echo ""
    
    echo "=== Network Configuration ==="
    echo "Default route:"
    ip route | grep default || echo "No default route"
    
    echo ""
    echo "DNS configuration:"
    cat /etc/resolv.conf 2>/dev/null || echo "Cannot read DNS config"
    echo ""
}