#!/bin/bash

# Universal n8n Environment Diagnostic Tool
# Comprehensive diagnostic script for troubleshooting n8n workflow and system issues

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Configuration
N8N_CONTAINER="homelab-n8n"
POSTGRES_CONTAINER="homelab-postgres"
WORKFLOWS_DIR="$(dirname "${SCRIPT_DIR}")/workflows"

# Color codes for enhanced output
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'

# Helper function to print section headers
print_section() {
    local title="$1"
    echo ""
    echo -e "${BOLD}${BLUE}=== $title ===${NC}"
    echo ""
}

# Helper function to print subsection headers
print_subsection() {
    local title="$1"
    echo -e "${UNDERLINE}${title}:${NC}"
}

# System information collection
collect_system_info() {
    print_section "SYSTEM ENVIRONMENT"
    
    log_info "Timestamp: $(date)"
    log_info "Hostname: $(hostname)"
    log_info "OS: $(uname -a)"
    log_info "Architecture: $(uname -m)"
    
    # Docker information
    print_subsection "Docker Environment"
    if command -v docker >/dev/null 2>&1; then
        log_success "✓ Docker is available"
        local docker_version=$(docker version --format 'Client: {{.Client.Version}} ({{.Client.Os}}/{{.Client.Arch}}){{"\n"}}Server: {{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})' 2>/dev/null)
        if [[ -n "$docker_version" ]]; then
            echo "$docker_version" | while IFS= read -r line; do
                log_info "$line"
            done
        else
            log_warning "Docker version information unavailable"
        fi
    else
        log_error "✗ Docker not found"
        return 1
    fi
    
    # Available disk space
    print_subsection "Disk Space"
    df -h . | tail -n +2 | while IFS= read -r line; do
        log_info "$line"
    done
    
    # Memory information
    print_subsection "Memory"
    if command -v free >/dev/null 2>&1; then
        free -h | while IFS= read -r line; do
            log_info "$line"
        done
    else
        # macOS alternative
        if command -v vm_stat >/dev/null 2>&1; then
            log_info "Memory info (macOS):"
            vm_stat | head -5 | while IFS= read -r line; do
                log_info "  $line"
            done
        fi
    fi
}

# Container status and health
collect_container_info() {
    print_section "DOCKER CONTAINERS"
    
    # List all containers
    print_subsection "Container Status"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}" | while IFS= read -r line; do
        if [[ "$line" == *"$N8N_CONTAINER"* ]]; then
            log_success "  $line"
        elif [[ "$line" == *"$POSTGRES_CONTAINER"* ]]; then
            log_success "  $line"
        elif [[ "$line" == "NAMES"* ]]; then
            log_info "$line"
        else
            log_info "  $line"
        fi
    done
    
    # n8n container details
    if docker ps --format "{{.Names}}" | grep -q "^${N8N_CONTAINER}$"; then
        print_subsection "n8n Container Details"
        log_success "✓ n8n container is running"
        
        # Container metadata
        log_info "Image: $(docker inspect $N8N_CONTAINER --format '{{.Config.Image}}')"
        log_info "Started: $(docker inspect $N8N_CONTAINER --format '{{.State.StartedAt}}')"
        
        # Health check
        local health_status=$(docker inspect $N8N_CONTAINER --format '{{.State.Health.Status}}' 2>/dev/null || echo "no-health-check")
        if [[ "$health_status" == "healthy" ]]; then
            log_success "Health: $health_status"
        else
            log_warning "Health: $health_status"
        fi
        
        # n8n version and architecture
        local n8n_version=$(docker exec $N8N_CONTAINER n8n --version 2>/dev/null)
        local container_arch=$(docker exec $N8N_CONTAINER uname -m 2>/dev/null)
        log_info "n8n version: ${n8n_version:-"unknown"}"
        log_info "Container architecture: ${container_arch:-"unknown"}"
        
        # Container resource usage
        print_subsection "Container Resources"
        docker exec $N8N_CONTAINER sh -c 'echo "Uptime: $(uptime)" && echo "Memory:" && free -h 2>/dev/null | head -2' 2>/dev/null | while IFS= read -r line; do
            log_info "$line"
        done
        
        # Volume mounts
        print_subsection "Volume Mounts"
        docker inspect $N8N_CONTAINER --format '{{range .Mounts}}{{.Source}} -> {{.Destination}} ({{.Type}}){{"\n"}}{{end}}' | while IFS= read -r line; do
            log_info "$line"
        done
    else
        log_error "✗ n8n container is not running"
    fi
    
    # PostgreSQL container details
    if docker ps --format "{{.Names}}" | grep -q "^${POSTGRES_CONTAINER}$"; then
        print_subsection "PostgreSQL Container Details"
        log_success "✓ PostgreSQL container is running"
        
        # Test database connectivity
        if docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "SELECT version();" >/dev/null 2>&1; then
            log_success "✓ Database connection working"
            local pg_version=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "SELECT version();" -t 2>/dev/null | head -1 | xargs)
            log_info "PostgreSQL: $pg_version"
        else
            log_error "✗ Database connection failed"
        fi
    else
        log_error "✗ PostgreSQL container is not running"
    fi
}

# n8n CLI and functionality testing
collect_n8n_cli_info() {
    print_section "N8N CLI FUNCTIONALITY"
    
    if ! docker ps --format "{{.Names}}" | grep -q "^${N8N_CONTAINER}$"; then
        log_error "Cannot test n8n CLI - container not running"
        return 1
    fi
    
    # Basic CLI accessibility
    print_subsection "CLI Access"
    if docker exec $N8N_CONTAINER n8n --help >/dev/null 2>&1; then
        log_success "✓ n8n CLI accessible"
    else
        log_error "✗ n8n CLI not accessible"
        return 1
    fi
    
    # Workflow listing
    print_subsection "Workflow Management"
    local workflow_list=$(docker exec $N8N_CONTAINER n8n list:workflow 2>&1)
    local workflow_exit=$?
    
    if [[ $workflow_exit -eq 0 ]]; then
        log_success "✓ Workflow listing works"
        local workflow_count=$(echo "$workflow_list" | wc -l | xargs)
        log_info "Total workflows: $workflow_count"
        
        if [[ $workflow_count -gt 0 && $workflow_count -lt 10 ]]; then
            log_info "Current workflows:"
            echo "$workflow_list" | while IFS= read -r line; do
                [[ -n "$line" ]] && log_info "  $line"
            done
        elif [[ $workflow_count -ge 10 ]]; then
            log_info "Sample workflows (first 5):"
            echo "$workflow_list" | head -5 | while IFS= read -r line; do
                [[ -n "$line" ]] && log_info "  $line"
            done
            log_info "  ... and $((workflow_count - 5)) more"
        fi
    else
        log_error "✗ Workflow listing failed"
        log_error "Error: $workflow_list"
    fi
    
    # Import command availability
    print_subsection "Import/Export Commands"
    local import_help=$(docker exec $N8N_CONTAINER n8n import:workflow --help 2>&1)
    if [[ $? -eq 0 ]]; then
        log_success "✓ Import command available"
        if echo "$import_help" | grep -q -- "--separate"; then
            log_success "✓ --separate flag supported"
        else
            log_warning "⚠  --separate flag not found"
        fi
    else
        log_error "✗ Import command not available"
    fi
    
    # Environment variables
    print_subsection "n8n Environment"
    docker exec $N8N_CONTAINER env | grep -E "^(N8N_|DB_|GENERIC_TIMEZONE)" | sort | while IFS= read -r line; do
        if echo "$line" | grep -q -E "(PASSWORD|KEY|SECRET)"; then
            local key=$(echo "$line" | cut -d= -f1)
            log_info "$key=***MASKED***"
        else
            log_info "$line"
        fi
    done
}

# Database analysis
collect_database_info() {
    print_section "DATABASE ANALYSIS"
    
    if ! docker ps --format "{{.Names}}" | grep -q "^${POSTGRES_CONTAINER}$"; then
        log_error "Cannot analyze database - PostgreSQL container not running"
        return 1
    fi
    
    # Database schema
    print_subsection "Database Schema"
    local table_count=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
    " -t 2>/dev/null | xargs)
    
    log_info "Total tables: ${table_count:-"unknown"}"
    
    # Key tables analysis
    print_subsection "Key Tables"
    docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
        SELECT 
            table_name,
            (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as columns,
            CASE 
                WHEN table_name = 'workflow_entity' THEN 
                    (SELECT COUNT(*) FROM workflow_entity)::text
                WHEN table_name = 'user' THEN 
                    (SELECT COUNT(*) FROM \"user\")::text
                WHEN table_name = 'project' THEN 
                    (SELECT COUNT(*) FROM project)::text
                ELSE '-'
            END as row_count
        FROM information_schema.tables t 
        WHERE table_schema = 'public' 
        AND table_name IN ('workflow_entity', 'user', 'project', 'execution_entity', 'credentials_entity')
        ORDER BY table_name;
    " -t 2>/dev/null | while IFS= read -r line; do
        [[ -n "$line" && "$line" != *"("*"row"* ]] && log_info "$line"
    done
    
    # Workflow details
    local workflow_count=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "SELECT COUNT(*) FROM workflow_entity;" -t 2>/dev/null | xargs)
    if [[ -n "$workflow_count" && $workflow_count -gt 0 ]]; then
        print_subsection "Workflow Details"
        log_info "Total workflows in database: $workflow_count"
        
        # Active vs inactive workflows
        local active_count=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "SELECT COUNT(*) FROM workflow_entity WHERE active = true;" -t 2>/dev/null | xargs)
        log_info "Active workflows: ${active_count:-"unknown"}"
        
        # Recent workflows
        if [[ $workflow_count -lt 10 ]]; then
            log_info "All workflows:"
            docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
                SELECT id, name, active, \"createdAt\"::date 
                FROM workflow_entity 
                ORDER BY \"createdAt\" DESC;
            " -t 2>/dev/null | while IFS= read -r line; do
                [[ -n "$line" && "$line" != *"("*"row"* ]] && log_info "  $line"
            done
        fi
    fi
    
    # Project information
    local project_count=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "SELECT COUNT(*) FROM project;" -t 2>/dev/null | xargs)
    if [[ -n "$project_count" && $project_count -gt 0 ]]; then
        print_subsection "Projects"
        log_info "Total projects: $project_count"
        docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
            SELECT id, name, type, \"createdAt\"::date 
            FROM project 
            ORDER BY \"createdAt\" DESC;
        " -t 2>/dev/null | while IFS= read -r line; do
            [[ -n "$line" && "$line" != *"("*"row"* ]] && log_info "  $line"
        done
    fi
}

# Workflow files analysis
collect_workflow_files_info() {
    print_section "WORKFLOW FILES ANALYSIS"
    
    if [[ -d "$WORKFLOWS_DIR" ]]; then
        log_success "✓ Workflows directory exists: $WORKFLOWS_DIR"
        
        local workflow_files=("${WORKFLOWS_DIR}"/*.json)
        if [[ -f "${workflow_files[0]}" ]]; then
            print_subsection "Available Workflow Files"
            local total_size=0
            
            for wf in "${workflow_files[@]}"; do
                if [[ -f "$wf" ]]; then
                    local filename=$(basename "$wf")
                    local filesize=$(stat -f%z "$wf" 2>/dev/null || stat -c%s "$wf" 2>/dev/null || echo "0")
                    total_size=$((total_size + filesize))
                    
                    # JSON validation
                    if jq empty "$wf" 2>/dev/null; then
                        log_success "✓ $filename (${filesize} bytes)"
                        
                        # Extract key information
                        local workflow_name=$(jq -r '.name // "unnamed"' "$wf" 2>/dev/null)
                        local node_count=$(jq '.nodes | length' "$wf" 2>/dev/null)
                        local has_nodes=$(jq 'has("nodes")' "$wf" 2>/dev/null)
                        
                        log_info "    Name: $workflow_name"
                        log_info "    Nodes: $node_count"
                        
                        if [[ "$has_nodes" == "true" ]]; then
                            log_success "    ✓ Valid workflow structure"
                        else
                            log_error "    ✗ Missing nodes field"
                        fi
                    else
                        log_error "✗ $filename (${filesize} bytes) - Invalid JSON"
                    fi
                fi
            done
            
            log_info ""
            log_info "Total workflow files: $(ls -1 "${WORKFLOWS_DIR}"/*.json 2>/dev/null | wc -l | xargs)"
            log_info "Total size: $total_size bytes"
        else
            log_warning "No workflow files found in directory"
        fi
    else
        log_error "✗ Workflows directory not found: $WORKFLOWS_DIR"
    fi
}

# Recent logs analysis
collect_logs_info() {
    print_section "CONTAINER LOGS ANALYSIS"
    
    if docker ps --format "{{.Names}}" | grep -q "^${N8N_CONTAINER}$"; then
        print_subsection "Recent n8n Logs"
        log_info "Last 10 log entries:"
        docker logs --tail 10 "$N8N_CONTAINER" 2>&1 | while IFS= read -r line; do
            if echo "$line" | grep -q -i "error"; then
                log_error "  $line"
            elif echo "$line" | grep -q -i "warn"; then
                log_warning "  $line"
            else
                log_info "  $line"
            fi
        done
        
        # Check for specific issues
        print_subsection "Log Issue Analysis"
        local error_count=$(docker logs --since="1h" "$N8N_CONTAINER" 2>&1 | grep -c -i "error" || true)
        local warning_count=$(docker logs --since="1h" "$N8N_CONTAINER" 2>&1 | grep -c -i "warn" || true)

        # Ensure counts are valid numbers (default to 0 if empty)
        error_count=${error_count:-0}
        warning_count=${warning_count:-0}

        log_info "Errors in last hour: $error_count"
        log_info "Warnings in last hour: $warning_count"

        if [[ $error_count -gt 0 ]]; then
            log_warning "Recent errors found:"
            docker logs --since="1h" "$N8N_CONTAINER" 2>&1 | grep -i "error" | tail -3 | while IFS= read -r line; do
                log_error "  $line"
            done
        fi
    else
        log_error "Cannot analyze logs - n8n container not running"
    fi
}

# Performance and connectivity tests
run_connectivity_tests() {
    print_section "CONNECTIVITY & PERFORMANCE TESTS"
    
    if ! docker ps --format "{{.Names}}" | grep -q "^${N8N_CONTAINER}$"; then
        log_error "Cannot run connectivity tests - n8n container not running"
        return 1
    fi
    
    print_subsection "File Operations Test"
    # Test file operations
    if docker exec "$N8N_CONTAINER" mkdir -p /tmp/diagnostic-test 2>/dev/null; then
        log_success "✓ Can create directories in container"
        
        # Test file copying
        echo "test" > /tmp/diagnostic-test-file
        if docker cp /tmp/diagnostic-test-file "$N8N_CONTAINER:/tmp/diagnostic-test/" 2>/dev/null; then
            log_success "✓ Can copy files to container"
            
            if docker exec "$N8N_CONTAINER" cat /tmp/diagnostic-test/diagnostic-test-file >/dev/null 2>&1; then
                log_success "✓ Can read files in container"
            else
                log_error "✗ Cannot read files in container"
            fi
        else
            log_error "✗ Cannot copy files to container"
        fi
        
        # Cleanup
        docker exec "$N8N_CONTAINER" rm -rf /tmp/diagnostic-test 2>/dev/null
        rm -f /tmp/diagnostic-test-file
    else
        log_error "✗ Cannot create directories in container"
    fi
    
    print_subsection "JSON Processing Test"
    # Test jq availability
    if docker exec "$N8N_CONTAINER" which jq >/dev/null 2>&1; then
        log_success "✓ jq is available in container"
        
        # Test JSON processing
        if echo '{"test": "value"}' | docker exec -i "$N8N_CONTAINER" jq . >/dev/null 2>&1; then
            log_success "✓ JSON processing works"
        else
            log_error "✗ JSON processing failed"
        fi
    else
        log_error "✗ jq not available in container"
    fi
}

# Generate summary and recommendations
generate_summary() {
    print_section "DIAGNOSTIC SUMMARY & RECOMMENDATIONS"
    
    # System status summary
    print_subsection "System Status"
    
    # Container status
    local n8n_running=$(docker ps --format "{{.Names}}" | grep -q "^${N8N_CONTAINER}$" && echo "yes" || echo "no")
    local postgres_running=$(docker ps --format "{{.Names}}" | grep -q "^${POSTGRES_CONTAINER}$" && echo "yes" || echo "no")
    
    if [[ "$n8n_running" == "yes" ]]; then
        log_success "✓ n8n container: Running"
    else
        log_error "✗ n8n container: Not running"
    fi
    
    if [[ "$postgres_running" == "yes" ]]; then
        log_success "✓ PostgreSQL container: Running"
    else
        log_error "✗ PostgreSQL container: Not running"
    fi
    
    # Database connectivity
    if [[ "$postgres_running" == "yes" ]] && docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "SELECT 1;" >/dev/null 2>&1; then
        log_success "✓ Database: Connected"
    else
        log_error "✗ Database: Connection failed"
    fi
    
    # Workflow count
    if [[ "$n8n_running" == "yes" ]]; then
        local cli_workflow_count=$(docker exec $N8N_CONTAINER n8n list:workflow 2>/dev/null | wc -l | xargs || echo "0")
        log_info "Workflows accessible via CLI: $cli_workflow_count"
        
        if [[ "$postgres_running" == "yes" ]]; then
            local db_workflow_count=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "SELECT COUNT(*) FROM workflow_entity;" -t 2>/dev/null | xargs || echo "0")
            log_info "Workflows in database: $db_workflow_count"
            
            if [[ "$cli_workflow_count" != "$db_workflow_count" ]]; then
                log_warning "⚠  CLI and database workflow counts differ"
            fi
        fi
    fi
    
    # Recommendations
    print_subsection "Recommendations"
    
    if [[ "$n8n_running" != "yes" ]]; then
        log_info "• Start n8n container: docker-compose up -d n8n"
    fi
    
    if [[ "$postgres_running" != "yes" ]]; then
        log_info "• Start PostgreSQL container: docker-compose up -d postgres"
    fi
    
    # Workflow file recommendations
    local workflow_files=("${WORKFLOWS_DIR}"/*.json)
    if [[ -f "${workflow_files[0]}" ]] && [[ "$n8n_running" == "yes" ]]; then
        local file_count=$(ls -1 "${WORKFLOWS_DIR}"/*.json 2>/dev/null | wc -l | xargs)
        local cli_count=$(docker exec $N8N_CONTAINER n8n list:workflow 2>/dev/null | wc -l | xargs || echo "0")
        
        if [[ $file_count -gt $cli_count ]]; then
            log_info "• Import workflow files: ./scripts/manage.sh import-workflows"
        fi
    fi
    
    log_info ""
    log_info "For specific issues, check the relevant sections above."
    log_info "Save this output for troubleshooting or sharing with support."
}

# Main execution
main() {
    local mode="${1:-full}"
    
    case "$mode" in
        "system"|"sys")
            collect_system_info
            ;;
        "containers"|"docker")
            collect_container_info
            ;;
        "n8n"|"cli")
            collect_n8n_cli_info
            ;;
        "database"|"db")
            collect_database_info
            ;;
        "workflows"|"wf")
            collect_workflow_files_info
            ;;
        "logs")
            collect_logs_info
            ;;
        "tests"|"test")
            run_connectivity_tests
            ;;
        "summary")
            generate_summary
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [mode]"
            echo ""
            echo "Modes:"
            echo "  full        Complete diagnostic (default)"
            echo "  system      System information only"
            echo "  containers  Docker containers analysis"
            echo "  n8n         n8n CLI and functionality"
            echo "  database    Database analysis"
            echo "  workflows   Workflow files analysis"
            echo "  logs        Container logs analysis"
            echo "  tests       Connectivity tests"
            echo "  summary     Summary and recommendations"
            echo ""
            echo "Examples:"
            echo "  $0              # Full diagnostic"
            echo "  $0 system       # System info only"
            echo "  $0 database     # Database analysis only"
            exit 0
            ;;
        "full"|*)
            log_info "${BOLD}Universal n8n Environment Diagnostic${NC}"
            log_info "Generated at: $(date)"
            log_info "Host: $(hostname)"
            
            collect_system_info
            collect_container_info
            collect_n8n_cli_info
            collect_database_info
            collect_workflow_files_info
            collect_logs_info
            run_connectivity_tests
            generate_summary
            ;;
    esac
    
    echo ""
    log_success "Diagnostic complete. $(date)"
}

# Run the diagnostic
main "$@"