#!/bin/bash

# WiFi Connectivity Monitor - Main Daemon Script
# Continuously monitors WiFi connectivity and performs automatic recovery

set -euo pipefail

# Get script directory and source library modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Source required library modules
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/wifi.sh"

# Script configuration
readonly SCRIPT_NAME="wifi-monitor"
readonly PID_FILE="/var/run/${SCRIPT_NAME}.pid"
readonly DAEMON_LOG="/var/log/homelab/${SCRIPT_NAME}-daemon.log"

# Default settings (can be overridden by environment or config file)
DAEMON_MONITOR_INTERVAL="${WIFI_MONITOR_INTERVAL:-30}"
DAEMON_FAILURE_THRESHOLD="${WIFI_FAILURE_THRESHOLD:-3}"
DAEMON_RECOVERY_COOLDOWN="${WIFI_RECOVERY_COOLDOWN:-300}"
DEBUG_MODE="${WIFI_DEBUG:-false}"

# Global variables
DAEMON_RUNNING=false
LAST_RECOVERY_TIME=0
CONSECUTIVE_FAILURES=0

# Signal handlers
cleanup_and_exit() {
    log_info "Received termination signal, cleaning up..."
    DAEMON_RUNNING=false
    
    # Remove PID file
    if [[ -f "$PID_FILE" ]]; then
        sudo rm -f "$PID_FILE"
    fi
    
    log_info "WiFi monitor daemon stopped"
    exit 0
}

# Setup signal handlers
trap cleanup_and_exit SIGTERM SIGINT SIGQUIT

# Logging functions for daemon
daemon_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$timestamp [$level] $message" | sudo tee -a "$DAEMON_LOG" >/dev/null
    
    # Also log to console if not in daemon mode
    if [[ "${DAEMON_MODE:-false}" != "true" ]]; then
        case "$level" in
            "INFO") log_info "$message" ;;
            "SUCCESS") log_success "$message" ;;
            "WARNING") log_warning "$message" ;;
            "ERROR") log_error "$message" ;;
            "DEBUG") [[ "$DEBUG_MODE" == "true" ]] && log_debug "$message" ;;
        esac
    fi
}

# Check if daemon is already running
is_daemon_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            # Stale PID file
            sudo rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# Start daemon
start_daemon() {
    if is_daemon_running; then
        log_error "WiFi monitor daemon is already running"
        return 1
    fi
    
    # Initialize setup
    if ! init_wifi_monitoring; then
        log_error "Failed to initialize WiFi monitoring"
        return 1
    fi
    
    log_info "Starting WiFi monitor daemon..."
    
    # Create PID file
    echo $$ | sudo tee "$PID_FILE" >/dev/null
    
    # Initialize daemon log
    sudo mkdir -p "$(dirname "$DAEMON_LOG")"
    daemon_log "INFO" "WiFi monitor daemon starting (PID: $$)"
    daemon_log "INFO" "Configuration: interval=${DAEMON_MONITOR_INTERVAL}s, threshold=${DAEMON_FAILURE_THRESHOLD}, cooldown=${DAEMON_RECOVERY_COOLDOWN}s"
    
    # Perform initial connectivity check
    daemon_log "INFO" "Performing initial connectivity check..."
    local wifi_status
    wifi_status=$(get_wifi_status)
    daemon_log "INFO" "Initial WiFi status: $wifi_status"
    
    if test_connectivity; then
        daemon_log "SUCCESS" "Initial connectivity check passed"
    else
        daemon_log "WARNING" "Initial connectivity check failed"
    fi
    
    # Main monitoring loop
    DAEMON_RUNNING=true
    CONSECUTIVE_FAILURES=0
    
    while $DAEMON_RUNNING; do
        monitor_cycle
        sleep "$DAEMON_MONITOR_INTERVAL"
    done
}

# Single monitoring cycle
monitor_cycle() {
    local current_time=$(date +%s)
    local wifi_status
    wifi_status=$(get_wifi_status)
    
    daemon_log "DEBUG" "Monitoring cycle: $wifi_status"
    
    # Test connectivity
    if test_connectivity; then
        # Connectivity is good
        if (( CONSECUTIVE_FAILURES > 0 )); then
            daemon_log "SUCCESS" "Connectivity restored after $CONSECUTIVE_FAILURES failures"
            send_wifi_alert "WiFi Connectivity Restored" "Connection recovered on $(hostname) after $CONSECUTIVE_FAILURES failures"
            CONSECUTIVE_FAILURES=0
        fi
        
        daemon_log "DEBUG" "Connectivity check passed: $wifi_status"
        return 0
    fi
    
    # Connectivity failed
    ((CONSECUTIVE_FAILURES++))
    daemon_log "WARNING" "Connectivity failure $CONSECUTIVE_FAILURES/$DAEMON_FAILURE_THRESHOLD: $wifi_status"
    
    # Check if we should trigger recovery
    if (( CONSECUTIVE_FAILURES >= DAEMON_FAILURE_THRESHOLD )); then
        # Check recovery cooldown
        local time_since_recovery=$((current_time - LAST_RECOVERY_TIME))
        
        if (( time_since_recovery < DAEMON_RECOVERY_COOLDOWN )); then
            daemon_log "INFO" "Recovery cooling down (${time_since_recovery}s/${DAEMON_RECOVERY_COOLDOWN}s)"
            return 1
        fi
        
        # Trigger recovery
        daemon_log "ERROR" "Connectivity failure threshold reached, starting recovery"
        send_wifi_alert "WiFi Connectivity Lost" "Starting recovery on $(hostname) after $CONSECUTIVE_FAILURES failures"
        
        LAST_RECOVERY_TIME=$current_time
        
        if perform_recovery; then
            daemon_log "SUCCESS" "Recovery completed successfully"
            CONSECUTIVE_FAILURES=0
        else
            daemon_log "ERROR" "Recovery failed - will retry after cooldown"
            send_wifi_alert "WiFi Recovery Failed" "Manual intervention may be required on $(hostname)"
        fi
    fi
}

# Perform WiFi recovery with enhanced logging
perform_recovery() {
    daemon_log "INFO" "Starting WiFi recovery procedure..."
    
    # Pre-recovery diagnostics
    daemon_log "DEBUG" "Pre-recovery WiFi status: $(get_wifi_status)"
    daemon_log "DEBUG" "Pre-recovery interface status: $(get_wifi_interface)"
    
    # Attempt recovery
    if wifi_recovery_full; then
        daemon_log "SUCCESS" "WiFi recovery completed successfully"
        
        # Post-recovery verification
        sleep 10
        if test_connectivity; then
            daemon_log "SUCCESS" "Post-recovery connectivity verified"
            return 0
        else
            daemon_log "WARNING" "Recovery completed but connectivity still failing"
            return 1
        fi
    else
        daemon_log "ERROR" "WiFi recovery failed"
        return 1
    fi
}

# Stop daemon
stop_daemon() {
    if ! is_daemon_running; then
        log_warning "WiFi monitor daemon is not running"
        return 0
    fi
    
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null)
    
    if [[ -n "$pid" ]]; then
        log_info "Stopping WiFi monitor daemon (PID: $pid)..."
        
        # Send TERM signal
        sudo kill -TERM "$pid" 2>/dev/null || true
        
        # Wait for graceful shutdown
        local timeout=10
        while (( timeout > 0 )) && kill -0 "$pid" 2>/dev/null; do
            sleep 1
            ((timeout--))
        done
        
        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            log_warning "Daemon didn't stop gracefully, forcing shutdown..."
            sudo kill -KILL "$pid" 2>/dev/null || true
        fi
        
        # Clean up PID file
        sudo rm -f "$PID_FILE"
        log_success "WiFi monitor daemon stopped"
    else
        log_error "Invalid PID file"
        return 1
    fi
}

# Restart daemon
restart_daemon() {
    log_info "Restarting WiFi monitor daemon..."
    stop_daemon
    sleep 2
    start_daemon
}

# Show daemon status
show_status() {
    echo "=== WiFi Monitor Daemon Status ==="
    
    if is_daemon_running; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        echo "Status: RUNNING (PID: $pid)"
        
        # Show process info
        if command -v ps >/dev/null; then
            echo "Process info:"
            ps -p "$pid" -o pid,ppid,etime,cmd 2>/dev/null || echo "  Cannot get process info"
        fi
    else
        echo "Status: STOPPED"
    fi
    
    echo ""
    echo "Configuration:"
    echo "  Monitor interval: ${DAEMON_MONITOR_INTERVAL}s"
    echo "  Failure threshold: $DAEMON_FAILURE_THRESHOLD"
    echo "  Recovery cooldown: ${DAEMON_RECOVERY_COOLDOWN}s"
    echo "  Debug mode: $DEBUG_MODE"
    echo ""
    
    echo "Log files:"
    echo "  Daemon log: $DAEMON_LOG"
    echo "  WiFi log: $WIFI_LOG_FILE"
    echo ""
    
    # Show recent log entries
    if [[ -f "$DAEMON_LOG" ]]; then
        echo "Recent daemon activity (last 10 lines):"
        sudo tail -10 "$DAEMON_LOG" 2>/dev/null || echo "  Cannot read daemon log"
    else
        echo "No daemon log found"
    fi
}

# Show logs
show_logs() {
    local lines="${1:-50}"
    local follow="${2:-false}"
    
    if [[ ! -f "$DAEMON_LOG" ]]; then
        log_error "Daemon log not found: $DAEMON_LOG"
        return 1
    fi
    
    if [[ "$follow" == "true" ]]; then
        log_info "Following daemon logs (Ctrl+C to exit)..."
        sudo tail -f "$DAEMON_LOG"
    else
        log_info "Showing last $lines daemon log entries..."
        sudo tail -n "$lines" "$DAEMON_LOG"
    fi
}

# Test WiFi monitoring (non-daemon mode)
test_monitoring() {
    local cycles="${1:-5}"
    
    log_info "Testing WiFi monitoring for $cycles cycles..."
    
    # Initialize monitoring
    if ! init_wifi_monitoring; then
        log_error "Failed to initialize WiFi monitoring"
        return 1
    fi
    
    # Run test cycles
    for ((i=1; i<=cycles; i++)); do
        log_info "Test cycle $i/$cycles"
        
        local wifi_status
        wifi_status=$(get_wifi_status)
        log_info "WiFi status: $wifi_status"
        
        if test_connectivity; then
            log_success "Connectivity test passed"
        else
            log_warning "Connectivity test failed"
        fi
        
        if (( i < cycles )); then
            log_info "Waiting ${DAEMON_MONITOR_INTERVAL}s before next cycle..."
            sleep "$DAEMON_MONITOR_INTERVAL"
        fi
    done
    
    log_success "WiFi monitoring test completed"
}

# Manual recovery trigger
trigger_recovery() {
    log_info "Manually triggering WiFi recovery..."
    
    if perform_recovery; then
        log_success "Manual recovery completed successfully"
        return 0
    else
        log_error "Manual recovery failed"
        return 1
    fi
}

# Show help
show_help() {
    cat << EOF
🔌 WiFi Connectivity Monitor

Usage: $0 <command> [options]

Commands:
  start                Start the WiFi monitor daemon
  stop                 Stop the WiFi monitor daemon  
  restart              Restart the WiFi monitor daemon
  status               Show daemon status and configuration
  logs [lines]         Show recent daemon logs (default: 50 lines)
  logs-follow          Follow daemon logs in real-time
  
  test [cycles]        Test monitoring for N cycles (default: 5)
  recovery             Manually trigger WiFi recovery
  diagnostics          Run comprehensive WiFi diagnostics
  
Configuration:
  Set environment variables to customize behavior:
    WIFI_MONITOR_INTERVAL=30     # Check interval in seconds
    WIFI_FAILURE_THRESHOLD=3     # Failures before recovery
    WIFI_RECOVERY_COOLDOWN=300   # Seconds between recoveries
    WIFI_DEBUG=true              # Enable debug logging

Examples:
  $0 start                      # Start monitoring daemon
  $0 status                     # Check if running
  $0 logs-follow               # Watch logs in real-time
  $0 test 3                    # Test for 3 cycles
  WIFI_DEBUG=true $0 test      # Test with debug output

Log Files:
  Daemon: $DAEMON_LOG
  WiFi:   $WIFI_LOG_FILE

EOF
}

# Main execution
main() {
    local command="${1:-help}"
    
    case "$command" in
        "start")
            start_daemon
            ;;
        "stop")
            stop_daemon
            ;;
        "restart")
            restart_daemon
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "${2:-50}"
            ;;
        "logs-follow")
            show_logs "50" "true"
            ;;
        "test")
            test_monitoring "${2:-5}"
            ;;
        "recovery")
            trigger_recovery
            ;;
        "diagnostics")
            wifi_diagnostics
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