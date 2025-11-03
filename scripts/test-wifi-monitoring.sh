#!/bin/bash

# WiFi Monitoring Test Suite
# Comprehensive testing for WiFi connectivity monitoring and recovery

set -euo pipefail

# Get script directory and source library modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source required library modules
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/wifi.sh"

# Test configuration
readonly TEST_MODE="${1:-full}"
readonly SCRIPT_NAME="test-wifi-monitoring"

# Test counters
test_count=0
pass_count=0
fail_count=0

# Test logging functions
log_test() { 
    ((test_count++))
    echo -e "${BLUE}[TEST $test_count]${NC} $*" 
}

pass() { 
    ((pass_count++))
    echo -e "${GREEN}[PASS]${NC} $*" 
}

fail() { 
    ((fail_count++))
    echo -e "${RED}[FAIL]${NC} $*" 
}

# Test 1: Prerequisites and Dependencies
test_prerequisites() {
    log_test "Testing prerequisites and dependencies..."
    
    # Check if running on appropriate platform
    local platform
    platform=$(detect_platform)
    
    if [[ "$platform" == "raspberry-pi" ]]; then
        pass "Running on Raspberry Pi - optimal platform"
    elif [[ "$platform" == "linux" ]]; then
        log_warn "Running on Linux (not Pi) - some features may be limited"
    else
        fail "Running on unsupported platform: $platform"
        return 1
    fi
    
    # Check WiFi tools availability
    if is_wifi_available; then
        pass "WiFi management tools available"
    else
        fail "No WiFi management tools found (nmcli or wpa_cli required)"
        return 1
    fi
    
    # Check NetworkManager specifically
    if is_networkmanager_available; then
        pass "NetworkManager is available and running"
    else
        log_warn "NetworkManager not available - limited functionality"
    fi
    
    # Check required directories
    local project_dir="${PROJECT_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
    
    if [[ -d "$project_dir" ]]; then
        pass "Project directory found: $project_dir"
    else
        fail "Project directory not found: $project_dir"
        return 1
    fi
    
    # Check script permissions
    local scripts=("wifi-monitor.sh" "wifi-recovery.sh")
    for script in "${scripts[@]}"; do
        local script_path="${SCRIPT_DIR}/$script"
        if [[ -f "$script_path" && -x "$script_path" ]]; then
            pass "Script executable: $script"
        else
            fail "Script missing or not executable: $script_path"
        fi
    done
}

# Test 2: WiFi Interface Detection
test_wifi_interface() {
    log_test "Testing WiFi interface detection..."
    
    local interface
    interface=$(get_wifi_interface)
    
    if [[ -n "$interface" ]]; then
        pass "WiFi interface detected: $interface"
        
        # Test interface status
        if is_wifi_interface_up "$interface"; then
            pass "WiFi interface is UP: $interface"
        else
            log_warn "WiFi interface is DOWN: $interface"
        fi
        
        # Show interface details
        if command -v ip >/dev/null; then
            log_info "Interface details:"
            ip addr show "$interface" | grep -E "(inet|ether)" | sed 's/^/  /'
        fi
    else
        fail "No WiFi interface found"
        log_info "Available network interfaces:"
        ip link show | grep -E "^[0-9]+:" | sed 's/^/  /'
        return 1
    fi
}

# Test 3: WiFi Connection Status
test_wifi_status() {
    log_test "Testing WiFi connection status detection..."
    
    local status
    status=$(get_wifi_status)
    
    if [[ -n "$status" ]]; then
        pass "WiFi status detected: $status"
        
        case "$status" in
            CONNECTED:*)
                pass "WiFi is connected"
                ;;
            LOCAL_ONLY:*)
                log_warn "WiFi connected but local only"
                ;;
            CONNECTING)
                log_warn "WiFi is connecting"
                ;;
            DISCONNECTED)
                log_warn "WiFi is disconnected"
                ;;
            NO_INTERFACE)
                fail "No WiFi interface available"
                ;;
            *)
                log_warn "Unknown WiFi status: $status"
                ;;
        esac
    else
        fail "Could not determine WiFi status"
        return 1
    fi
}

# Test 4: Connectivity Testing
test_connectivity() {
    log_test "Testing connectivity functions..."
    
    # Test local connectivity
    log_info "Testing local connectivity (gateway)..."
    if test_local_connectivity; then
        pass "Local connectivity test passed"
    else
        log_warn "Local connectivity test failed"
    fi
    
    # Test internet connectivity
    log_info "Testing internet connectivity..."
    if test_connectivity; then
        pass "Internet connectivity test passed"
    else
        log_warn "Internet connectivity test failed"
    fi
    
    # Show network configuration
    log_info "Network configuration:"
    local gateway
    gateway=$(ip route | awk '/default/ {print $3}' | head -1)
    echo "  Gateway: ${gateway:-Not found}"
    
    local dns
    dns=$(grep nameserver /etc/resolv.conf 2>/dev/null | head -1 | awk '{print $2}')
    echo "  DNS: ${dns:-Not configured}"
}

# Test 5: WiFi Network Scanning
test_network_scanning() {
    log_test "Testing WiFi network scanning..."
    
    local interface
    interface=$(get_wifi_interface)
    
    if [[ -z "$interface" ]]; then
        fail "No WiFi interface for scanning"
        return 1
    fi
    
    log_info "Scanning for WiFi networks on $interface..."
    local networks
    networks=$(scan_wifi_networks "$interface" 2>/dev/null)
    
    if [[ -n "$networks" ]]; then
        local network_count
        network_count=$(echo "$networks" | wc -l)
        pass "Network scan completed: $network_count networks found"
        
        # Show top 5 networks
        log_info "Top networks found:"
        echo "$networks" | head -5 | while IFS=: read -r ssid signal security; do
            if [[ -n "$ssid" && "$ssid" != "--" ]]; then
                echo "  $ssid (Signal: $signal, Security: $security)"
            fi
        done
    else
        log_warn "No WiFi networks found - may indicate hardware or location issues"
    fi
}

# Test 6: Configuration Management
test_configuration_management() {
    log_test "Testing WiFi configuration management..."
    
    # Test saved connections listing
    if is_networkmanager_available; then
        log_info "Testing saved connection listing..."
        local connections
        connections=$(list_saved_connections)
        
        if [[ -n "$connections" ]]; then
            local conn_count
            conn_count=$(echo "$connections" | wc -l)
            pass "Found $conn_count saved WiFi connections"
        else
            log_warn "No saved WiFi connections found"
        fi
        
        # Test configuration backup
        log_info "Testing configuration backup..."
        local backup_dir="${WIFI_CONFIG_DIR}/test-backup"
        mkdir -p "$backup_dir"
        local backup_file="$backup_dir/test-backup-$(date +%s).json"
        
        if backup_wifi_configs "$backup_file"; then
            pass "Configuration backup created successfully"
            # Clean up test backup
            rm -f "$backup_file"
        else
            fail "Configuration backup failed"
        fi
    else
        log_warn "NetworkManager not available - skipping configuration tests"
    fi
}

# Test 7: Recovery Functions (Non-destructive)
test_recovery_functions() {
    log_test "Testing WiFi recovery functions (safe tests only)..."
    
    # Test interface detection for recovery
    local interface
    interface=$(get_wifi_interface)
    
    if [[ -n "$interface" ]]; then
        pass "Interface available for recovery testing: $interface"
    else
        fail "No interface available for recovery testing"
        return 1
    fi
    
    # Test recovery function availability
    if declare -f wifi_recovery_soft >/dev/null; then
        pass "Soft recovery function available"
    else
        fail "Soft recovery function not found"
    fi
    
    if declare -f wifi_recovery_hard >/dev/null; then
        pass "Hard recovery function available"
    else
        fail "Hard recovery function not found"
    fi
    
    if declare -f wifi_recovery_full >/dev/null; then
        pass "Full recovery function available"
    else
        fail "Full recovery function not found"
    fi
    
    log_warn "Actual recovery testing skipped to avoid disruption"
    log_info "Use manual testing for recovery validation"
}

# Test 8: Monitoring Setup
test_monitoring_setup() {
    log_test "Testing WiFi monitoring setup..."
    
    # Test initialization
    log_info "Testing monitoring initialization..."
    if init_wifi_monitoring; then
        pass "WiFi monitoring initialization successful"
    else
        fail "WiFi monitoring initialization failed"
        return 1
    fi
    
    # Test directory creation
    if [[ -d "$WIFI_CONFIG_DIR" ]]; then
        pass "WiFi config directory exists: $WIFI_CONFIG_DIR"
    else
        fail "WiFi config directory missing: $WIFI_CONFIG_DIR"
    fi
    
    # Test log directory (requires sudo)
    log_info "Testing log directory access..."
    if sudo mkdir -p "$WIFI_LOG_DIR" 2>/dev/null; then
        pass "Can create log directory: $WIFI_LOG_DIR"
    else
        log_warn "Cannot create log directory - may need manual setup"
    fi
    
    # Test webhook URL configuration
    if [[ -n "${N8N_WEBHOOK_URL:-}" ]]; then
        pass "N8N webhook URL configured for alerts"
    else
        log_warn "N8N webhook URL not configured - alerts disabled"
    fi
}

# Test 9: Script Integration
test_script_integration() {
    log_test "Testing script integration and commands..."
    
    local scripts=(
        "wifi-monitor.sh"
        "wifi-recovery.sh"
    )
    
    for script in "${scripts[@]}"; do
        local script_path="${SCRIPT_DIR}/$script"
        
        if [[ -f "$script_path" ]]; then
            # Test help command
            log_info "Testing $script help command..."
            if "$script_path" help >/dev/null 2>&1; then
                pass "$script help command works"
            else
                log_warn "$script help command failed"
            fi
        else
            fail "Script not found: $script_path"
        fi
    done
    
    # Test manage.sh integration
    local manage_script="${SCRIPT_DIR}/manage.sh"
    if [[ -f "$manage_script" ]]; then
        log_info "Testing manage.sh WiFi commands..."
        if grep -q "wifi-status" "$manage_script"; then
            pass "WiFi commands integrated in manage.sh"
        else
            fail "WiFi commands not found in manage.sh"
        fi
    else
        log_warn "manage.sh script not found"
    fi
}

# Test 10: System Service (if available)
test_system_service() {
    log_test "Testing systemd service configuration..."
    
    local service_file="/etc/systemd/system/wifi-monitor.service"
    local config_service_file="${PROJECT_DIR}/config/systemd/wifi-monitor.service"
    
    if [[ -f "$config_service_file" ]]; then
        pass "Service file template exists: $config_service_file"
        
        # Check if installed
        if [[ -f "$service_file" ]]; then
            pass "Service installed: $service_file"
            
            # Check service status
            if systemctl is-enabled wifi-monitor >/dev/null 2>&1; then
                pass "Service is enabled"
            else
                log_warn "Service is not enabled"
            fi
            
            if systemctl is-active wifi-monitor >/dev/null 2>&1; then
                pass "Service is active"
            else
                log_warn "Service is not active"
            fi
        else
            log_warn "Service not installed - run manual installation"
            log_info "To install: sudo cp $config_service_file $service_file"
        fi
    else
        fail "Service file template missing: $config_service_file"
    fi
}

# Comprehensive diagnostics
run_comprehensive_diagnostics() {
    log_test "Running comprehensive WiFi diagnostics..."
    
    wifi_diagnostics
    pass "Comprehensive diagnostics completed"
}

# Main test execution
main() {
    log_info "Starting WiFi monitoring test suite..."
    log_info "Test mode: $TEST_MODE"
    echo ""
    
    # Initialize test environment
    init_script
    
    case "$TEST_MODE" in
        "quick")
            test_prerequisites
            test_wifi_interface
            test_wifi_status
            test_connectivity
            ;;
        "connectivity")
            test_prerequisites
            test_wifi_interface
            test_wifi_status
            test_connectivity
            test_network_scanning
            ;;
        "config")
            test_prerequisites
            test_configuration_management
            test_monitoring_setup
            ;;
        "integration")
            test_prerequisites
            test_script_integration
            test_system_service
            ;;
        "diagnostics")
            run_comprehensive_diagnostics
            ;;
        "full")
            test_prerequisites
            test_wifi_interface
            test_wifi_status
            test_connectivity
            test_network_scanning
            test_configuration_management
            test_recovery_functions
            test_monitoring_setup
            test_script_integration
            test_system_service
            ;;
        *)
            log_error "Unknown test mode: $TEST_MODE"
            echo "Available modes: quick, connectivity, config, integration, diagnostics, full"
            exit 1
            ;;
    esac
    
    # Test summary
    echo ""
    echo "=================================================="
    echo "  WiFi Monitoring Test Results"
    echo "=================================================="
    echo "Mode: $TEST_MODE"
    echo "Total tests: $test_count"
    echo "Passed: $pass_count"
    echo "Failed: $fail_count"
    echo ""
    
    if (( fail_count == 0 )); then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo ""
        echo "WiFi monitoring system is ready for use."
        echo ""
        echo "Next steps:"
        echo "1. Start monitoring: ./scripts/wifi-monitor.sh start"
        echo "2. Check status: ./scripts/manage.sh wifi-monitor-status"
        echo "3. View logs: ./scripts/wifi-monitor.sh logs-follow"
        echo "4. Install service: sudo cp config/systemd/wifi-monitor.service /etc/systemd/system/"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        echo ""
        echo "Issues detected - please resolve before deployment:"
        echo "- Check network hardware and drivers"
        echo "- Verify NetworkManager installation"
        echo "- Ensure proper permissions for scripts"
        echo "- Review system logs for errors"
        return 1
    fi
}

# Show help
show_help() {
    cat << EOF
🧪 WiFi Monitoring Test Suite

Usage: $0 [mode]

Test Modes:
  quick          Basic connectivity and interface tests (default)
  connectivity   Extended connectivity and network scanning tests
  config         Configuration management and backup tests
  integration    Script and service integration tests  
  diagnostics    Comprehensive system diagnostics
  full           Complete test suite (all tests)

Examples:
  $0                    # Quick test
  $0 full              # Complete test suite
  $0 connectivity      # Test connectivity only
  $0 diagnostics       # Full system diagnostics

The test suite validates:
- WiFi hardware and driver availability
- NetworkManager configuration
- Connectivity testing functions
- Network scanning capabilities  
- Configuration backup/restore
- Script integration and permissions
- Systemd service setup
- Monitoring initialization

Note: Tests are non-destructive and safe to run on production systems.
Some tests require sudo privileges for system access.

EOF
}

# Handle command line arguments
case "${1:-quick}" in
    "help"|"-h"|"--help")
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac