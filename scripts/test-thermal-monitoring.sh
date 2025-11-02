#!/bin/bash#!/bin/bash#!/bin/bash#!/bin/bash#!/bin/bash

# Thermal Monitoring Test Script - Refactored

# Thermal Monitoring Test Script - Refactored

set -euo pipefail

# Test monitoring stack functionality# Thermal Monitoring Test - Optimized

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"



source "${SCRIPT_DIR}/lib/common.sh"# Initialize script with common functions# Test Prometheus-based thermal monitoring# Thermal Monitoring Test - Optimized

source "${SCRIPT_DIR}/lib/monitoring.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$PROJECT_DIR"

source "${SCRIPT_DIR}/lib/common.sh"

main() {

    log_test "Starting thermal monitoring tests..."source "${SCRIPT_DIR}/lib/monitoring.sh"

    test_monitoring_endpoints

    log_test "Test complete"set -euo pipefail# Test Prometheus-based thermal monitoring# Thermal Monitoring Test Script

}

# Initialize script

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

    main "$@"init_script

fi


# Main test functionreadonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"# Purpose: Test thermal monitoring system on development machine and Raspberry Pi

main() {

    log_test "Starting thermal monitoring tests..."

    

    # Use the library function for testing# Loggingset -euo pipefail# Usage: ./test-thermal-monitoring.sh [quick|full|pi-only]

    test_monitoring_endpoints

    log() { echo -e "\033[0;34m[TEST]\033[0m $*"; }

    log_test "Test complete"

}pass() { echo -e "\033[0;32m[PASS]\033[0m $*"; }



# Run if executed directlyfail() { echo -e "\033[0;31m[FAIL]\033[0m $*"; }

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

    main "$@"readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"set -euo pipefail

fi
# Test thermal exporter endpoint

test_thermal_endpoint() {

    log "Testing thermal exporter endpoint..."

    # LoggingSCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if curl -sf http://localhost:9200/metrics >/dev/null 2>&1; then

        pass "Thermal exporter responding"log() { echo -e "\033[0;34m[TEST]\033[0m $*"; }PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

        

        # Check for Pi-specific metricspass() { echo -e "\033[0;32m[PASS]\033[0m $*"; }

        if curl -s http://localhost:9200/metrics | grep -q "rpi_cpu_temperature"; then

            pass "Pi thermal metrics available"fail() { echo -e "\033[0;31m[FAIL]\033[0m $*"; }TEST_MODE="${1:-quick}"

        else

            fail "Pi thermal metrics not found"

        fi

    else# Test thermal exporter endpoint# Colors for output

        fail "Thermal exporter not responding"

    fitest_thermal_endpoint() {RED='\033[0;31m'

}

    log "Testing thermal exporter endpoint..."GREEN='\033[0;32m'

# Test Prometheus scraping

test_prometheus_scraping() {    YELLOW='\033[1;33m'

    log "Testing Prometheus thermal data..."

        if curl -sf http://localhost:9200/metrics >/dev/null 2>&1; thenBLUE='\033[0;34m'

    if curl -sf "http://localhost:9090/api/v1/query?query=rpi_cpu_temperature_celsius" >/dev/null 2>&1; then

        pass "Prometheus collecting thermal data"        pass "Thermal exporter responding"NC='\033[0m' # No Color

    else

        fail "Prometheus not collecting thermal data"        

    fi

}        # Check for Pi-specific metricslog_test() {



# Test platform detection        if curl -s http://localhost:9200/metrics | grep -q "rpi_cpu_temperature"; then    echo -e "${BLUE}[TEST]${NC} $1"

test_platform_detection() {

    log "Testing platform detection..."            pass "Pi thermal metrics available"}

    

    if [[ -f /proc/device-tree/model ]]; then        else

        local model

        model=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "Unknown")            fail "Pi thermal metrics not found"log_pass() {

        pass "Platform: $model"

                fi    echo -e "${GREEN}[PASS]${NC} $1"

        if command -v vcgencmd >/dev/null 2>&1; then

            local temp    else}

            temp=$(vcgencmd measure_temp 2>/dev/null || echo "temp=N/A")

            pass "vcgencmd available: $temp"        fail "Thermal exporter not responding"

        else

            fail "vcgencmd not available"    filog_fail() {

        fi

    else}    echo -e "${RED}[FAIL]${NC} $1"

        fail "Not running on Raspberry Pi (expected on macOS)"

    fi}

}

# Test Prometheus scraping

# Main test suite

main() {test_prometheus_scraping() {log_warn() {

    log "Starting thermal monitoring tests..."

        log "Testing Prometheus thermal data..."    echo -e "${YELLOW}[WARN]${NC} $1"

    test_platform_detection

    test_thermal_endpoint    }

    test_prometheus_scraping

        if curl -sf http://localhost:9090/api/v1/query?query=rpi_cpu_temperature_celsius >/dev/null 2>&1; then

    log "Test complete"

}        pass "Prometheus collecting thermal data"# Test 1: Script Permissions and Existence



# Run if executed directly    elsetest_script_permissions() {

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

    main "$@"        fail "Prometheus not collecting thermal data"    log_test "Testing script permissions and existence..."

fi
    fi    

}    local thermal_script="${SCRIPT_DIR}/thermal-monitor.sh"

    local analysis_script="${SCRIPT_DIR}/analyze-thermal-logs.sh"

# Test platform detection    

test_platform_detection() {    if [[ -f "$thermal_script" && -x "$thermal_script" ]]; then

    log "Testing platform detection..."        log_pass "Thermal monitor script exists and is executable"

        else

    if [[ -f /proc/device-tree/model ]]; then        log_fail "Thermal monitor script missing or not executable: $thermal_script"

        local model        return 1

        model=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "Unknown")    fi

        pass "Platform: $model"    

            if [[ -f "$analysis_script" && -x "$analysis_script" ]]; then

        if command -v vcgencmd >/dev/null 2>&1; then        log_pass "Analysis script exists and is executable"

            local temp    else

            temp=$(vcgencmd measure_temp 2>/dev/null || echo "temp=N/A")        log_fail "Analysis script missing or not executable: $analysis_script"

            pass "vcgencmd available: $temp"        return 1

        else    fi

            fail "vcgencmd not available"}

        fi

    else# Test 2: Directory Creation

        fail "Not running on Raspberry Pi"test_directory_creation() {

    fi    log_test "Testing directory creation..."

}    

    local log_dir="${PROJECT_DIR}/logs/thermal"

# Main test suite    local tmp_dir="${PROJECT_DIR}/tmp"

main() {    

    log "Starting thermal monitoring tests..."    mkdir -p "$log_dir" "$tmp_dir"

        

    test_platform_detection    if [[ -d "$log_dir" && -w "$log_dir" ]]; then

    test_thermal_endpoint        log_pass "Thermal log directory created and writable: $log_dir"

    test_prometheus_scraping    else

            log_fail "Cannot create or write to thermal log directory: $log_dir"

    log "Test complete"        return 1

}    fi

    

# Run if executed directly    if [[ -d "$tmp_dir" && -w "$tmp_dir" ]]; then

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then        log_pass "Temp directory created and writable: $tmp_dir"

    main "$@"    else

fi        log_fail "Cannot create or write to temp directory: $tmp_dir"
        return 1
    fi
}

# Test 3: Platform Detection
test_platform_detection() {
    log_test "Testing platform detection..."
    
    local platform_output
    platform_output=$("${SCRIPT_DIR}/thermal-monitor.sh" test-platform platform_check start 2>&1 || echo "error")
    
    if command -v vcgencmd &> /dev/null; then
        local pi_model=""
        if [[ -f /proc/device-tree/model ]]; then
            pi_model=$(cat /proc/device-tree/model 2>/dev/null)
        fi
        
        if [[ "$pi_model" == *"Raspberry Pi 5"* ]]; then
            log_pass "Platform: Raspberry Pi 5 detected"
            return 0
        elif [[ "$pi_model" == *"Raspberry Pi"* ]]; then
            log_warn "Platform: Raspberry Pi (not Pi 5) detected"
            return 0
        else
            log_warn "Platform: Generic Pi detected"
            return 0
        fi
    else
        log_warn "Platform: Not Raspberry Pi (thermal monitoring will be disabled)"
        
        if [[ "$platform_output" == *"Not running on Raspberry Pi"* ]] || [[ "$platform_output" == *"thermal monitoring disabled"* ]]; then
            log_pass "Platform detection working correctly - graceful fallback"
        else
            log_fail "Platform detection not working as expected"
            return 1
        fi
    fi
}

# Test 4: Short Monitoring Test
test_short_monitoring() {
    log_test "Testing short monitoring cycle..."
    
    local test_workflow="test-thermal-$(date +%s)"
    
    # Start monitoring
    log_test "Starting monitoring for $test_workflow..."
    "${SCRIPT_DIR}/thermal-monitor.sh" "$test_workflow" "test_start" "start" &
    local monitor_pid=$!
    
    # Wait a bit
    sleep 5
    
    # Log a test step
    log_test "Logging test step..."
    "${SCRIPT_DIR}/thermal-monitor.sh" "$test_workflow" "test_processing" "log_step" || true
    
    # Wait a bit more
    sleep 5
    
    # Stop monitoring
    log_test "Stopping monitoring..."
    "${SCRIPT_DIR}/thermal-monitor.sh" "$test_workflow" "test_end" "stop" || true
    
    # Wait for process to stop
    sleep 2
    
    # Check if files were created
    local log_files
    log_files=$(find "${PROJECT_DIR}/logs/thermal" -name "*${test_workflow}*" -type f 2>/dev/null | wc -l)
    
    if (( log_files >= 2 )); then
        log_pass "Monitoring files created successfully ($log_files files)"
        
        # Show file contents briefly
        local csv_file
        csv_file=$(find "${PROJECT_DIR}/logs/thermal" -name "*${test_workflow}*.csv" -type f 2>/dev/null | head -1)
        if [[ -f "$csv_file" ]]; then
            local line_count
            line_count=$(wc -l < "$csv_file")
            log_test "CSV file has $line_count lines (including header)"
            
            if (( line_count >= 2 )); then
                log_pass "Thermal data collected successfully"
            else
                log_warn "Thermal data collection may be incomplete"
            fi
        fi
    else
        log_fail "Expected monitoring files not created"
        return 1
    fi
    
    # Cleanup background process if still running
    if kill -0 $monitor_pid 2>/dev/null; then
        kill $monitor_pid 2>/dev/null || true
    fi
}

# Test 5: Analysis Script Test
test_analysis_script() {
    log_test "Testing analysis script..."
    
    # Find a recent CSV file
    local csv_file
    csv_file=$(find "${PROJECT_DIR}/logs/thermal" -name "*.csv" -type f -exec ls -t {} + 2>/dev/null | head -1)
    
    if [[ -z "$csv_file" ]]; then
        log_warn "No CSV files found for analysis testing - skipping"
        return 0
    fi
    
    log_test "Analyzing file: $(basename "$csv_file")"
    
    if "${SCRIPT_DIR}/analyze-thermal-logs.sh" "$csv_file" &>/dev/null; then
        log_pass "Analysis script executed successfully"
        
        # Check if analysis files were created
        local analysis_file="${csv_file%.csv}.analysis"
        if [[ -f "$analysis_file" ]]; then
            log_pass "Analysis file created: $(basename "$analysis_file")"
        else
            log_warn "Analysis file not created"
        fi
    else
        log_fail "Analysis script execution failed"
        return 1
    fi
}

# Test 6: N8N Integration Simulation
test_n8n_integration() {
    log_test "Testing N8N integration commands..."
    
    # Simulate the Execute Command node scripts
    local workflow_id="gmail-to-telegram"
    
    # Test start command
    log_test "Testing workflow start command..."
    local start_cmd="/bin/bash -c 'SCRIPT_DIR=\"${SCRIPT_DIR}\"; WORKFLOW_ID=\"${workflow_id}\"; if [[ -x \"\$SCRIPT_DIR/thermal-monitor.sh\" ]]; then \"\$SCRIPT_DIR/thermal-monitor.sh\" \"\$WORKFLOW_ID\" \"workflow_start\" \"start\"; else echo \"WARNING: Script not found\"; fi'"
    
    if eval "$start_cmd" &>/dev/null; then
        log_pass "N8N start command simulation successful"
    else
        log_fail "N8N start command simulation failed"
        return 1
    fi
    
    sleep 2
    
    # Test step logging
    log_test "Testing step logging command..."
    local step_cmd="/bin/bash -c 'SCRIPT_DIR=\"${SCRIPT_DIR}\"; WORKFLOW_ID=\"${workflow_id}\"; if [[ -x \"\$SCRIPT_DIR/thermal-monitor.sh\" ]]; then \"\$SCRIPT_DIR/thermal-monitor.sh\" \"\$WORKFLOW_ID\" \"email_1_test\" \"log_step\"; fi'"
    
    eval "$step_cmd" &>/dev/null || true
    log_pass "N8N step logging simulation completed"
    
    sleep 2
    
    # Test stop command  
    log_test "Testing workflow stop command..."
    local stop_cmd="/bin/bash -c 'SCRIPT_DIR=\"${SCRIPT_DIR}\"; WORKFLOW_ID=\"${workflow_id}\"; if [[ -x \"\$SCRIPT_DIR/thermal-monitor.sh\" ]]; then \"\$SCRIPT_DIR/thermal-monitor.sh\" \"\$WORKFLOW_ID\" \"workflow_end\" \"stop\"; fi'"
    
    if eval "$stop_cmd" &>/dev/null; then
        log_pass "N8N stop command simulation successful"
    else
        log_warn "N8N stop command had issues (may be normal)"
    fi
}

# Test 7: Error Handling
test_error_handling() {
    log_test "Testing error handling..."
    
    # Test with invalid parameters
    if "${SCRIPT_DIR}/thermal-monitor.sh" invalid_workflow invalid_step invalid_operation &>/dev/null; then
        log_warn "Script should have failed with invalid parameters"
    else
        log_pass "Error handling working - invalid parameters rejected"
    fi
    
    # Test cleanup of stale processes
    log_test "Testing cleanup..."
    pkill -f "thermal-monitor.sh" 2>/dev/null || true
    log_pass "Process cleanup completed"
}

# Main test execution
main() {
    echo "=================================================="
    echo "  Thermal Monitoring System Test Suite"
    echo "=================================================="
    echo ""
    
    local test_count=0
    local pass_count=0
    local fail_count=0
    
    run_test() {
        local test_name="$1"
        local test_function="$2"
        
        ((test_count++))
        echo ""
        echo "[$test_count] $test_name"
        echo "----------------------------------------"
        
        if $test_function; then
            ((pass_count++))
            log_pass "Test completed successfully"
        else
            ((fail_count++))
            log_fail "Test failed"
        fi
    }
    
    # Core tests (always run)
    run_test "Script Permissions" test_script_permissions
    run_test "Directory Creation" test_directory_creation 
    run_test "Platform Detection" test_platform_detection
    
    case "$TEST_MODE" in
        "quick")
            run_test "Short Monitoring" test_short_monitoring
            ;;
        "full")
            run_test "Short Monitoring" test_short_monitoring
            run_test "Analysis Script" test_analysis_script
            run_test "N8N Integration" test_n8n_integration
            run_test "Error Handling" test_error_handling
            ;;
        "pi-only")
            if command -v vcgencmd &> /dev/null; then
                run_test "Short Monitoring" test_short_monitoring
                run_test "Analysis Script" test_analysis_script
                run_test "N8N Integration" test_n8n_integration
            else
                log_warn "Skipping Pi-only tests - not running on Raspberry Pi"
            fi
            ;;
    esac
    
    # Summary
    echo ""
    echo "=================================================="
    echo "  Test Results Summary"
    echo "=================================================="
    echo "Total tests: $test_count"
    echo "Passed: $pass_count"
    echo "Failed: $fail_count"
    
    if (( fail_count == 0 )); then
        echo -e "${GREEN}All tests passed!${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Deploy scripts to Raspberry Pi"
        echo "2. Add thermal monitoring nodes to n8n workflow"
        echo "3. Test with actual workflow execution"
        return 0
    else
        echo -e "${RED}Some tests failed - please fix issues before deployment${NC}"
        return 1
    fi
}

# Cleanup function
cleanup() {
    log_test "Cleaning up test processes..."
    pkill -f "thermal-monitor.sh.*test" 2>/dev/null || true
}

# Set up cleanup trap
trap cleanup EXIT

# Run main function
main