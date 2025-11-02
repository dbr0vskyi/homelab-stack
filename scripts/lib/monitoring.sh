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
        docker-compose --profile monitoring up -d --force-recreate || die "Failed to start monitoring services"
    else
        docker-compose --profile monitoring up -d || die "Failed to start monitoring services"
    fi
    
    log_success "Monitoring stack started"
}

# Stop monitoring stack  
stop_monitoring_stack() {
    log_monitoring "Stopping monitoring stack..."
    
    docker-compose --profile monitoring stop || log_warn "Some services may have failed to stop"
    
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