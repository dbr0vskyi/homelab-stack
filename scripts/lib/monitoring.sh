#!/bin/bash
# Monitoring functions library - Consolidated monitoring operations

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Monitoring configuration
declare -a MONITORING_SERVICES=(
    "prometheus:9090:/metrics"
    "grafana:3000:/api/health"
    "thermal-exporter:9200:/metrics"
    "node-exporter:9100:/metrics"
)

# PostgreSQL configuration (matches executions.sh)
POSTGRES_CONTAINER="homelab-postgres"
POSTGRES_USER="n8n"
POSTGRES_DB="n8n"

# Build thermal exporter image
build_thermal_exporter() {
    log_monitoring "Building thermal exporter image..."
    
    if docker build -t homelab-thermal-exporter -f config/thermal-exporter/Dockerfile .; then
        log_success "Thermal exporter image built"
    else
        die "Failed to build thermal exporter image"
    fi
}

# Create monitoring volumes
create_monitoring_volumes() {
    log_monitoring "Creating monitoring volumes..."
    
    local volumes=(
        "homelab_prometheus_data"
        "homelab_grafana_data"
    )
    
    for volume in "${volumes[@]}"; do
        if ! docker volume inspect "$volume" >/dev/null 2>&1; then
            docker volume create "$volume"
            log_success "Created volume: $volume"
        else
            log_debug "Volume $volume already exists"
        fi
    done
}

# Start monitoring stack
start_monitoring_stack() {
    local force_recreate="${1:-false}"
    
    log_monitoring "Starting monitoring stack..."
    
    # Ensure prerequisites
    create_monitoring_volumes
    build_thermal_exporter
    
    # Start services
    if [[ "$force_recreate" == "true" ]]; then
        docker compose --profile monitoring up -d --force-recreate || die "Failed to start monitoring services"
    else
        docker compose --profile monitoring up -d || die "Failed to start monitoring services"
    fi
    
    log_success "Monitoring stack started"
}

# Stop monitoring stack  
stop_monitoring_stack() {
    log_monitoring "Stopping monitoring stack..."

    docker compose --profile monitoring stop || log_warn "Some services may have failed to stop"

    log_success "Monitoring stack stopped"
}

# Check monitoring service health
check_monitoring_health() {
    log_monitoring "Checking monitoring service health..."
    
    local all_healthy=true
    
    for service_info in "${MONITORING_SERVICES[@]}"; do
        IFS=':' read -r service port path <<< "$service_info"
        local container_name="homelab-$service"
        
        # Check if container is running
        if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
            log_pass "$service container running"
            
            # Check endpoint health
            if curl -sf "http://localhost:${port}${path}" >/dev/null 2>&1; then
                log_pass "$service endpoint responding"
            else
                log_fail "$service endpoint not responding"
                all_healthy=false
            fi
        else
            log_fail "$service container not running"
            all_healthy=false
        fi
    done
    
    if [[ "$all_healthy" == "true" ]]; then
        log_success "All monitoring services healthy"
        return 0
    else
        log_error "Some monitoring services are unhealthy"
        return 1
    fi
}

# Show monitoring status
show_monitoring_status() {
    log_info "Monitoring Stack Status:"
    echo
    
    for service_info in "${MONITORING_SERVICES[@]}"; do
        IFS=':' read -r service port path <<< "$service_info"
        local container_name="homelab-$service"
        
        if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
            log_success "$container_name: Running"
        else
            log_error "$container_name: Not running"
        fi
    done
    
    echo
    log_info "Checking monitoring endpoints:"
    check_monitoring_health >/dev/null 2>&1
}

# Test monitoring endpoints
test_monitoring_endpoints() {
    log_test "Testing monitoring endpoints..."
    
    # Test platform detection
    local platform
    platform=$(detect_platform)
    log_test "Platform detected: $platform"
    
    if [[ "$platform" == "raspberry-pi" ]]; then
        if command_exists vcgencmd; then
            local temp
            temp=$(vcgencmd measure_temp 2>/dev/null || echo "temp=N/A")
            log_pass "vcgencmd available: $temp"
        else
            log_fail "vcgencmd not available on Pi"
        fi
    else
        log_warn "Not running on Pi - thermal metrics will be limited"
    fi
    
    # Test service endpoints
    check_monitoring_health
}

# Deploy complete monitoring stack
deploy_monitoring_stack() {
    log_deploy "Deploying monitoring stack..."
    
    # Platform and resource checks
    local platform
    platform=$(detect_platform)
    log_info "Target platform: $platform"
    
    check_system_resources 512 1024 || log_warn "System resources may be constrained"
    
    # Deploy stack
    start_monitoring_stack true
    
    # Wait for services to initialize
    log_info "Waiting for services to initialize..."
    sleep 30
    
    # Health check
    if check_monitoring_health; then
        show_monitoring_access_info
    else
        log_warn "Some services may not be fully ready yet"
    fi
    
    log_success "Monitoring deployment complete!"
}

# Show access information
show_monitoring_access_info() {
    local host_ip
    if command_exists hostname && hostname -I >/dev/null 2>&1; then
        host_ip=$(hostname -I | awk '{print $1}')
    else
        host_ip="localhost"
    fi
    
    cat << EOF

🎉 Monitoring Stack Ready!

Access URLs:
============
🔍 Prometheus: http://${host_ip}:9090
📊 Grafana:    http://${host_ip}:3000 (admin/admin)
🌡️ Thermal:    http://${host_ip}:9200/metrics
💻 Node:       http://${host_ip}:9100/metrics

Management:
===========
Start:  ./scripts/manage.sh monitoring-start
Stop:   ./scripts/manage.sh monitoring-stop
Status: ./scripts/manage.sh monitoring-status

EOF
}

# Monitoring integration for setup
setup_monitoring_stack() {
    local force_recreate="${1:-false}"

    log_info "Setting up monitoring stack..."

    # Build and start monitoring services
    if [[ "$force_recreate" == "true" ]]; then
        start_monitoring_stack true
    else
        start_monitoring_stack false
    fi

    log_success "Monitoring stack setup complete"
}

# Query Prometheus for execution metrics
query_execution_metrics() {
    local execution_id="$1"
    local start_time="$2"
    local end_time="$3"

    if [[ -z "$execution_id" ]] || [[ -z "$start_time" ]] || [[ -z "$end_time" ]]; then
        log_error "Usage: query_execution_metrics <execution_id> <start_time_iso> <end_time_iso>"
        return 1
    fi

    log_info "Querying monitoring data for execution #${execution_id}..."

    # Convert ISO timestamps to Unix
    local start_unix end_unix
    start_unix=$(date -d "$start_time" +%s 2>/dev/null)
    end_unix=$(date -d "$end_time" +%s 2>/dev/null)

    if [[ -z "$start_unix" ]] || [[ -z "$end_unix" ]]; then
        log_error "Invalid timestamp format. Use ISO 8601 format (e.g., 2025-11-02T19:35:23+01:00)"
        return 1
    fi

    local duration_min=$(( (end_unix - start_unix) / 60 ))

    echo "======================================================================"
    echo "MONITORING DATA FOR EXECUTION #${execution_id}"
    echo "======================================================================"
    echo "Time Range: ${start_time} to ${end_time}"
    echo "Duration: ${duration_min} minutes"
    echo ""

    # Temperature query
    local temp_data
    temp_data=$(curl -s "http://localhost:9090/api/v1/query_range?query=rpi_cpu_temperature_celsius&start=${start_unix}&end=${end_unix}&step=60")

    if echo "$temp_data" | grep -q '"status":"success"'; then
        echo "🌡️  CPU TEMPERATURE"
        echo "----------------------------------------------------------------------"
        echo "$temp_data" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data['status'] == 'success' and data['data']['result']:
    values = data['data']['result'][0]['values']
    temps = [float(v[1]) for v in values]
    if temps:
        print(f'  Samples:    {len(values)} readings')
        print(f'  Start:      {temps[0]:.1f}°C')
        print(f'  End:        {temps[-1]:.1f}°C')
        print(f'  Minimum:    {min(temps):.1f}°C')
        print(f'  Maximum:    {max(temps):.1f}°C')
        print(f'  Average:    {sum(temps)/len(temps):.1f}°C')
        print(f'  Change:     {temps[-1]-temps[0]:+.1f}°C')
else:
    print('  No data available')
" 2>/dev/null || echo "  Error parsing temperature data"
    else
        echo "  No temperature data available"
    fi

    echo ""

    # Throttling query
    local throttle_data
    throttle_data=$(curl -s "http://localhost:9090/api/v1/query_range?query=rpi_throttling_status&start=${start_unix}&end=${end_unix}&step=60")

    echo "🚦 THROTTLING STATUS"
    echo "----------------------------------------------------------------------"
    if echo "$throttle_data" | grep -q '"status":"success"'; then
        echo "$throttle_data" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data['status'] == 'success' and data['data']['result']:
    values = data['data']['result'][0]['values']
    throttles = [int(float(v[1])) for v in values]
    if any(throttles):
        print(f'  ⚠️  THROTTLING DETECTED')
        print(f'  Max value: {max(throttles)}')
    else:
        print(f'  ✅ NO THROTTLING')
        print(f'  All {len(values)} readings: 0')
else:
    print('  No data available')
" 2>/dev/null || echo "  Error parsing throttling data"
    else
        echo "  No throttling data available"
    fi

    echo ""

    # Memory query
    local mem_data
    mem_data=$(curl -s "http://localhost:9090/api/v1/query_range?query=node_memory_MemAvailable_bytes&start=${start_unix}&end=${end_unix}&step=60")

    echo "💾 MEMORY USAGE"
    echo "----------------------------------------------------------------------"
    if echo "$mem_data" | grep -q '"status":"success"'; then
        echo "$mem_data" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data['status'] == 'success' and data['data']['result']:
    values = data['data']['result'][0]['values']
    mem_gb = [float(v[1]) / (1024**3) for v in values]
    if mem_gb:
        total_ram = 16.0  # Raspberry Pi 5 16GB
        used_start = total_ram - mem_gb[0]
        used_end = total_ram - mem_gb[-1]
        used_peak = total_ram - min(mem_gb)
        print(f'  Total RAM:  {total_ram:.1f} GB')
        print(f'  Start Avail: {mem_gb[0]:.2f} GB (used: {used_start:.2f} GB, {used_start/total_ram*100:.1f}%)')
        print(f'  End Avail:   {mem_gb[-1]:.2f} GB (used: {used_end:.2f} GB, {used_end/total_ram*100:.1f}%)')
        print(f'  Peak Used:   {used_peak:.2f} GB ({used_peak/total_ram*100:.1f}%)')
        print(f'  Consumed:    {used_end - used_start:+.2f} GB')
else:
    print('  No data available')
" 2>/dev/null || echo "  Error parsing memory data"
    else
        echo "  No memory data available"
    fi

    echo ""

    # CPU usage query
    local cpu_data
    cpu_data=$(curl -g -s "http://localhost:9090/api/v1/query_range?query=100%20-%20(avg%20by(instance)%20(rate(node_cpu_seconds_total{mode=\"idle\"}[5m]))%20*%20100)&start=${start_unix}&end=${end_unix}&step=60")
    local curl_exit=$?

    echo "⚙️  CPU UTILIZATION"
    echo "----------------------------------------------------------------------"
    if [[ $curl_exit -ne 0 ]]; then
        echo "  ⚠️  Failed to query CPU data (curl error code: $curl_exit)"
    elif echo "$cpu_data" | grep -q '"status":"success"'; then
        echo "$cpu_data" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data['status'] == 'success' and data['data']['result']:
    values = data['data']['result'][0]['values']
    cpu_usage = [float(v[1]) for v in values]
    if cpu_usage:
        print(f'  Start:      {cpu_usage[0]:.1f}%')
        print(f'  End:        {cpu_usage[-1]:.1f}%')
        print(f'  Peak:       {max(cpu_usage):.1f}%')
        print(f'  Average:    {sum(cpu_usage)/len(cpu_usage):.1f}%')
else:
    print('  No data available')
" 2>/dev/null || echo "  ⚠️  Error parsing CPU data"
    else
        echo "  ⚠️  No CPU data available (Prometheus returned non-success status)"
    fi

    echo ""
    echo "======================================================================"
}

# Get execution timestamps and query metrics
get_execution_monitoring_data() {
    local execution_id="$1"

    if [[ -z "$execution_id" ]]; then
        log_error "Usage: get_execution_monitoring_data <execution_id>"
        return 1
    fi

    log_info "Fetching execution timestamps for #${execution_id}..."

    # Get execution details from PostgreSQL
    local exec_data
    exec_data=$(docker compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -t -c \
        "SELECT \"startedAt\", \"stoppedAt\" FROM execution_entity WHERE id = ${execution_id};" 2>/dev/null)

    if [[ -z "$exec_data" ]]; then
        log_error "Execution #${execution_id} not found in database"
        return 1
    fi

    # Parse timestamps (format: YYYY-MM-DD HH:MM:SS.ms+TZ | YYYY-MM-DD HH:MM:SS.ms+TZ)
    local start_time end_time start_part end_part
    IFS='|' read -r start_part end_part <<< "$exec_data"
    start_time=$(echo "$start_part" | awk '{print $1"T"$2}' | sed 's/\..*//')
    end_time=$(echo "$end_part" | awk '{print $1"T"$2}' | sed 's/\..*//')

    if [[ -z "$start_time" ]] || [[ -z "$end_time" ]]; then
        log_error "Failed to parse execution timestamps"
        return 1
    fi

    # Query metrics
    query_execution_metrics "$execution_id" "$start_time" "$end_time"
}