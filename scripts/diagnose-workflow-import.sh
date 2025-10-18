#!/bin/bash

# Comprehensive diagnostic script for n8n workflow import issues
# Run this on both Mac (working) and Raspberry Pi (not working) to compare

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

N8N_CONTAINER="homelab-n8n"
WORKFLOWS_DIR="$(dirname "${SCRIPT_DIR}")/workflows"

log_info "=== N8N WORKFLOW IMPORT DIAGNOSTICS ==="
log_info "Timestamp: $(date)"
log_info "Host: $(hostname)"
log_info "OS: $(uname -a)"
log_info ""

# 1. System Architecture and Docker Info
log_info "=== SYSTEM INFORMATION ==="
log_info "Architecture: $(uname -m)"
log_info "Docker client: $(docker version --format '{{.Client.Version}} ({{.Client.Os}}/{{.Client.Arch}})')"
log_info "Docker server: $(docker version --format '{{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})')"
log_info ""

# 2. Container Status
log_info "=== CONTAINER STATUS ==="
if docker ps --format "table {{.Names}}" | grep -q "^${N8N_CONTAINER}$"; then
    log_success "✓ n8n container is running"
    
    # Container details
    log_info "Container image: $(docker inspect $N8N_CONTAINER --format '{{.Config.Image}}')"
    log_info "Container started: $(docker inspect $N8N_CONTAINER --format '{{.State.StartedAt}}')"
    log_info "Container uptime: $(docker exec $N8N_CONTAINER uptime)"
    log_info "Container architecture: $(docker exec $N8N_CONTAINER uname -m)"
    log_info "n8n version: $(docker exec $N8N_CONTAINER n8n --version)"
    
    # Health check
    health_status=$(docker inspect $N8N_CONTAINER --format '{{.State.Health.Status}}' 2>/dev/null || echo "no-health-check")
    log_info "Health status: $health_status"
else
    log_error "✗ n8n container is not running"
    log_info "Available containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    exit 1
fi
log_info ""

# 3. Database Connectivity
log_info "=== DATABASE CONNECTIVITY ==="
if docker exec $N8N_CONTAINER sh -c 'echo "SELECT 1;" | timeout 5 psql -h postgres -U $DB_POSTGRESDB_USER -d $DB_POSTGRESDB_DATABASE -t' >/dev/null 2>&1; then
    log_success "✓ Database connection working"
    
    # Get database info
    db_info=$(docker exec $N8N_CONTAINER sh -c 'echo "SELECT current_database(), current_user, version();" | psql -h postgres -U $DB_POSTGRESDB_USER -d $DB_POSTGRESDB_DATABASE -t' 2>/dev/null | head -1)
    log_info "Database info: $db_info"
    
    # Check for n8n tables
    table_count=$(docker exec $N8N_CONTAINER sh -c 'echo "SELECT COUNT(*) FROM information_schema.tables WHERE table_name LIKE '\''%workflow%'\'';" | psql -h postgres -U $DB_POSTGRESDB_USER -d $DB_POSTGRESDB_DATABASE -t' 2>/dev/null | xargs)
    log_info "Workflow tables count: $table_count"
    
else
    log_error "✗ Database connection failed"
    log_info "Checking postgres container..."
    if docker ps --format "table {{.Names}}" | grep -q "homelab-postgres"; then
        log_info "Postgres container is running"
    else
        log_error "Postgres container is not running"
    fi
fi
log_info ""

# 4. n8n CLI Functionality
log_info "=== N8N CLI FUNCTIONALITY ==="

# Test basic CLI
if docker exec $N8N_CONTAINER n8n --help >/dev/null 2>&1; then
    log_success "✓ n8n CLI accessible"
else
    log_error "✗ n8n CLI not accessible"
fi

# Test workflow listing
log_info "Testing workflow listing..."
workflow_list_output=$(docker exec $N8N_CONTAINER n8n list:workflow 2>&1)
workflow_list_exit=$?

if [[ $workflow_list_exit -eq 0 ]]; then
    log_success "✓ Workflow listing works"
    workflow_count=$(echo "$workflow_list_output" | wc -l | xargs)
    log_info "Current workflows count: $workflow_count"
    
    # Show first few workflows
    if [[ $workflow_count -gt 0 ]]; then
        log_info "Sample workflows:"
        echo "$workflow_list_output" | head -5 | while IFS= read -r line; do
            [[ -n "$line" ]] && log_info "  $line"
        done
    fi
else
    log_error "✗ Workflow listing failed"
    log_error "Error: $workflow_list_output"
fi

# Test workflow listing with onlyId flag
id_list_output=$(docker exec $N8N_CONTAINER n8n list:workflow --onlyId 2>&1)
id_list_exit=$?
if [[ $id_list_exit -eq 0 ]]; then
    id_count=$(echo "$id_list_output" | grep -v '^$' | wc -l | xargs)
    log_info "Workflow IDs count: $id_count"
else
    log_error "✗ Workflow ID listing failed: $id_list_output"
fi
log_info ""

# 5. Workflow Files Analysis
log_info "=== WORKFLOW FILES ANALYSIS ==="
if [[ -d "$WORKFLOWS_DIR" ]]; then
    log_success "✓ Workflows directory exists: $WORKFLOWS_DIR"
    
    workflow_files=("${WORKFLOWS_DIR}"/*.json)
    if [[ -f "${workflow_files[0]}" ]]; then
        log_info "Found workflow files:"
        for wf in "${workflow_files[@]}"; do
            if [[ -f "$wf" ]]; then
                filename=$(basename "$wf")
                filesize=$(stat -f%z "$wf" 2>/dev/null || stat -c%s "$wf" 2>/dev/null || echo "unknown")
                log_info "  - $filename (${filesize} bytes)"
                
                # JSON validation
                if jq empty "$wf" 2>/dev/null; then
                    log_success "    ✓ Valid JSON"
                    
                    # Check required fields
                    has_nodes=$(jq 'has("nodes")' "$wf" 2>/dev/null)
                    has_name=$(jq 'has("name")' "$wf" 2>/dev/null)
                    workflow_name=$(jq -r '.name // "unnamed"' "$wf" 2>/dev/null)
                    node_count=$(jq '.nodes | length' "$wf" 2>/dev/null)
                    project_id=$(jq -r '.shared[]?.project.id // "none"' "$wf" 2>/dev/null | head -1)
                    
                    log_info "    Name: $workflow_name"
                    log_info "    Nodes: $node_count"
                    log_info "    Project ID: $project_id"
                    
                    if [[ "$has_nodes" == "true" ]]; then
                        log_success "    ✓ Has nodes field"
                    else
                        log_error "    ✗ Missing nodes field"
                    fi
                else
                    log_error "    ✗ Invalid JSON"
                fi
            fi
        done
    else
        log_warning "No workflow files found in directory"
    fi
else
    log_error "✗ Workflows directory not found: $WORKFLOWS_DIR"
fi
log_info ""

# 6. Container Environment Variables
log_info "=== CONTAINER ENVIRONMENT ==="
log_info "Key n8n environment variables:"
docker exec $N8N_CONTAINER env | grep -E "^(N8N_|DB_|GENERIC_TIMEZONE)" | sort | while IFS= read -r line; do
    # Mask sensitive values
    if echo "$line" | grep -q -E "(PASSWORD|KEY|SECRET)"; then
        key=$(echo "$line" | cut -d= -f1)
        log_info "  $key=***MASKED***"
    else
        log_info "  $line"
    fi
done
log_info ""

# 7. File Permissions and Volume Mounts
log_info "=== FILE PERMISSIONS AND MOUNTS ==="
log_info "Container volume mounts:"
docker inspect $N8N_CONTAINER --format '{{range .Mounts}}{{.Source}} -> {{.Destination}} ({{.Type}}){{"\n"}}{{end}}' | while IFS= read -r line; do
    log_info "  $line"
done

log_info "n8n user in container:"
docker exec $N8N_CONTAINER id
log_info "n8n home directory permissions:"
docker exec $N8N_CONTAINER ls -la /home/node/.n8n | head -5
log_info ""

# 8. Test Import Preparation
log_info "=== IMPORT PREPARATION TEST ==="
log_info "Testing temporary directory creation..."
if docker exec $N8N_CONTAINER mkdir -p /tmp/test-workflows 2>/dev/null; then
    log_success "✓ Can create temp directories"
    docker exec $N8N_CONTAINER rm -rf /tmp/test-workflows
else
    log_error "✗ Cannot create temp directories"
fi

# Test file copying
if [[ -f "${workflow_files[0]}" ]]; then
    test_file="${workflow_files[0]}"
    log_info "Testing file copy to container..."
    if docker cp "$test_file" "$N8N_CONTAINER:/tmp/test-workflow.json" 2>/dev/null; then
        log_success "✓ Can copy files to container"
        
        # Check if file is readable in container
        if docker exec $N8N_CONTAINER cat /tmp/test-workflow.json >/dev/null 2>&1; then
            log_success "✓ Can read copied files in container"
        else
            log_error "✗ Cannot read copied files in container"
        fi
        
        # Check if jq works in container
        if docker exec $N8N_CONTAINER jq empty /tmp/test-workflow.json 2>/dev/null; then
            log_success "✓ jq works in container"
        else
            log_error "✗ jq not working in container"
        fi
        
        docker exec $N8N_CONTAINER rm -f /tmp/test-workflow.json
    else
        log_error "✗ Cannot copy files to container"
    fi
fi
log_info ""

# 9. Import Command Test (Dry Run Style)
log_info "=== IMPORT COMMAND ANALYSIS ==="
log_info "Testing import command help..."
import_help=$(docker exec $N8N_CONTAINER n8n import:workflow --help 2>&1)
if [[ $? -eq 0 ]]; then
    log_success "✓ Import command available"
    # Check for specific flags
    if echo "$import_help" | grep -q -- "--separate"; then
        log_success "✓ --separate flag available"
    else
        log_warning "⚠  --separate flag not found"
    fi
    if echo "$import_help" | grep -q -- "--projectId"; then
        log_success "✓ --projectId flag available"
    else
        log_warning "⚠  --projectId flag not found"
    fi
else
    log_error "✗ Import command not available: $import_help"
fi
log_info ""

# 10. Recent Container Logs
log_info "=== RECENT CONTAINER LOGS ==="
log_info "Last 20 lines from n8n container logs:"
docker logs --tail 20 $N8N_CONTAINER 2>&1 | while IFS= read -r line; do
    log_info "  $line"
done
log_info ""

log_info "=== DIAGNOSTIC COMPLETE ==="
log_info "Save this output and compare between working (Mac) and non-working (Raspberry Pi) systems"
log_info "Look for differences in:"
log_info "  - n8n version"
log_info "  - Architecture (should both be arm64/aarch64)"
log_info "  - Database connectivity"
log_info "  - File permissions"
log_info "  - CLI command availability"
log_info "  - Container logs for errors"