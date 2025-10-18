#!/bin/bash

# Advanced workflow import testing script
# This script tests the exact import process with detailed logging

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

N8N_CONTAINER="homelab-n8n"
WORKFLOWS_DIR="$(dirname "${SCRIPT_DIR}")/workflows"

log_info "=== ADVANCED WORKFLOW IMPORT TEST ==="
log_info "This script simulates the exact import process with detailed logging"
log_info ""

# Check if n8n is running
if ! docker ps --format "table {{.Names}}" | grep -q "^${N8N_CONTAINER}$"; then
    log_error "n8n container is not running"
    exit 1
fi

# 1. Pre-import state
log_info "=== PRE-IMPORT STATE ==="
log_info "Current workflows in n8n:"
pre_import_workflows=$(docker exec "$N8N_CONTAINER" n8n list:workflow --onlyId 2>&1)
pre_import_count=$(echo "$pre_import_workflows" | grep -v '^$' | wc -l | xargs)
log_info "Pre-import workflow count: $pre_import_count"

if [[ $pre_import_count -gt 0 ]]; then
    echo "$pre_import_workflows" | head -5 | while IFS= read -r line; do
        [[ -n "$line" ]] && log_info "  $line"
    done
    if [[ $pre_import_count -gt 5 ]]; then
        log_info "  ... and $((pre_import_count - 5)) more"
    fi
fi
log_info ""

# 2. Workflow file preparation
log_info "=== WORKFLOW FILE PREPARATION ==="
workflow_files=("${WORKFLOWS_DIR}"/*.json)
if [[ ! -f "${workflow_files[0]}" ]]; then
    log_error "No workflow files found in ${WORKFLOWS_DIR}"
    exit 1
fi

log_info "Preparing workflow files for import..."
docker exec "$N8N_CONTAINER" mkdir -p /tmp/test-import

files_prepared=0
for workflow_file in "${workflow_files[@]}"; do
    [[ ! -f "$workflow_file" ]] && continue
    
    filename=$(basename "$workflow_file")
    log_info "Processing: $filename"
    
    # Validate JSON
    if ! jq empty "$workflow_file" 2>/dev/null; then
        log_error "  ✗ Invalid JSON, skipping"
        continue
    fi
    
    # Check required fields
    has_nodes=$(jq 'has("nodes")' "$workflow_file" 2>/dev/null)
    if [[ "$has_nodes" != "true" ]]; then
        log_error "  ✗ Missing nodes field, skipping"
        continue
    fi
    
    # Get workflow metadata
    workflow_name=$(jq -r '.name // "unnamed"' "$workflow_file" 2>/dev/null)
    node_count=$(jq '.nodes | length' "$workflow_file" 2>/dev/null)
    project_id=$(jq -r '.shared[]?.project.id // empty' "$workflow_file" 2>/dev/null | head -1)
    
    log_info "  Name: $workflow_name"
    log_info "  Nodes: $node_count"
    log_info "  Project ID: ${project_id:-"none"}"
    
    # Prepare cleaned workflow data (same process as the real import)
    temp_file="/tmp/${filename}"
    jq --arg name "$workflow_name" '
        {
            name: (.name // $name),
            nodes: .nodes,
            connections: .connections,
            active: (.active // false),
            settings: (.settings // {}),
            staticData: (.staticData // null),
            tags: (.tags // []),
            pinData: (.pinData // {})
        }
    ' "$workflow_file" > "$temp_file"
    
    if [[ $? -eq 0 ]]; then
        log_success "  ✓ Prepared workflow data"
        
        # Copy to container
        if docker cp "$temp_file" "$N8N_CONTAINER:/tmp/test-import/"; then
            log_success "  ✓ Copied to container"
            ((files_prepared++))
        else
            log_error "  ✗ Failed to copy to container"
        fi
        rm -f "$temp_file"
    else
        log_error "  ✗ Failed to prepare workflow data"
    fi
    log_info ""
done

if [[ $files_prepared -eq 0 ]]; then
    log_error "No files prepared for import"
    docker exec "$N8N_CONTAINER" rm -rf /tmp/test-import
    exit 1
fi

log_info "Successfully prepared $files_prepared workflow file(s)"
log_info ""

# 3. Test import command variants
log_info "=== TESTING IMPORT COMMANDS ==="

# Get project ID from workflow file
project_id=""
for workflow_file in "${WORKFLOWS_DIR}"/*.json; do
    [[ ! -f "$workflow_file" ]] && continue
    file_project_id=$(jq -r '.shared[]?.project.id // empty' "$workflow_file" 2>/dev/null | head -1)
    if [[ -n "$file_project_id" && "$file_project_id" != "null" ]]; then
        project_id="$file_project_id"
        break
    fi
done

# Test 1: Basic import command
log_info "Test 1: Basic import without project ID"
test1_output=$(docker exec "$N8N_CONTAINER" n8n import:workflow --separate --input=/tmp/test-import 2>&1)
test1_exit=$?
log_info "Exit code: $test1_exit"
if [[ $test1_exit -eq 0 ]]; then
    log_success "✓ Basic import succeeded"
else
    log_error "✗ Basic import failed"
fi
log_info "Output:"
echo "$test1_output" | while IFS= read -r line; do
    log_info "  $line"
done
log_info ""

# Check post-import state after test 1
log_info "Workflows after test 1:"
post_test1_workflows=$(docker exec "$N8N_CONTAINER" n8n list:workflow --onlyId 2>&1)
post_test1_count=$(echo "$post_test1_workflows" | grep -v '^$' | wc -l | xargs)
log_info "Count: $post_test1_count (was $pre_import_count)"
log_info ""

# Test 2: Import with project ID (if available)
if [[ -n "$project_id" && "$project_id" != "null" ]]; then
    log_info "Test 2: Import with project ID: $project_id"
    
    # Prepare fresh files (in case they were consumed)
    docker exec "$N8N_CONTAINER" rm -rf /tmp/test-import2
    docker exec "$N8N_CONTAINER" mkdir -p /tmp/test-import2
    
    for workflow_file in "${workflow_files[@]}"; do
        [[ ! -f "$workflow_file" ]] && continue
        filename=$(basename "$workflow_file")
        workflow_name="${filename%.json}"
        
        if jq empty "$workflow_file" 2>/dev/null && [[ "$(jq 'has("nodes")' "$workflow_file")" == "true" ]]; then
            temp_file="/tmp/${filename}"
            jq --arg name "$workflow_name" '
                {
                    name: (.name // $name),
                    nodes: .nodes,
                    connections: .connections,
                    active: (.active // false),
                    settings: (.settings // {}),
                    staticData: (.staticData // null),
                    tags: (.tags // []),
                    pinData: (.pinData // {})
                }
            ' "$workflow_file" > "$temp_file"
            docker cp "$temp_file" "$N8N_CONTAINER:/tmp/test-import2/"
            rm -f "$temp_file"
        fi
    done
    
    test2_output=$(docker exec "$N8N_CONTAINER" n8n import:workflow --separate --input=/tmp/test-import2 --projectId="$project_id" 2>&1)
    test2_exit=$?
    log_info "Exit code: $test2_exit"
    if [[ $test2_exit -eq 0 ]]; then
        log_success "✓ Project-specific import succeeded"
    else
        log_error "✗ Project-specific import failed"
        # Check if it's a "project not found" error
        if echo "$test2_output" | grep -q "Could not find any entity of type \"Project\""; then
            log_warning "  → Project ID not found (normal for fresh n8n installations)"
        fi
    fi
    log_info "Output:"
    echo "$test2_output" | while IFS= read -r line; do
        log_info "  $line"
    done
    
    docker exec "$N8N_CONTAINER" rm -rf /tmp/test-import2
else
    log_info "Test 2: Skipped (no project ID found in workflows)"
fi
log_info ""

# 4. Final state verification
log_info "=== FINAL VERIFICATION ==="
final_workflows=$(docker exec "$N8N_CONTAINER" n8n list:workflow 2>&1)
final_exit=$?

if [[ $final_exit -eq 0 ]]; then
    final_count=$(echo "$final_workflows" | wc -l | xargs)
    log_info "Final workflow count: $final_count"
    log_info "Imported workflows: $((final_count - pre_import_count))"
    
    if [[ $final_count -gt $pre_import_count ]]; then
        log_success "✓ New workflows were added"
        log_info "New workflows:"
        echo "$final_workflows" | tail -n +$((pre_import_count + 1)) | while IFS= read -r line; do
            [[ -n "$line" ]] && log_info "  $line"
        done
    else
        log_warning "⚠  No new workflows added (possibly duplicates or import failed)"
    fi
else
    log_error "✗ Failed to list final workflows: $final_workflows"
fi
log_info ""

# 5. Check for common issues
log_info "=== ISSUE DIAGNOSIS ==="

# Check for workflow duplicates by name
log_info "Checking for duplicate workflow names..."
if [[ $final_exit -eq 0 ]]; then
    workflow_names=$(echo "$final_workflows" | cut -d'|' -f2 | sort)
    duplicate_names=$(echo "$workflow_names" | uniq -d)
    if [[ -n "$duplicate_names" ]]; then
        log_warning "⚠  Found duplicate workflow names:"
        echo "$duplicate_names" | while IFS= read -r name; do
            [[ -n "$name" ]] && log_warning "    $name"
        done
        log_info "This may indicate successful imports creating multiple versions"
    else
        log_info "No duplicate names found"
    fi
fi

# Check container resources
log_info "Container resource usage:"
docker exec "$N8N_CONTAINER" sh -c 'free -h && df -h /home/node/.n8n' | while IFS= read -r line; do
    log_info "  $line"
done

# Check recent n8n logs for any errors during import
log_info "Checking recent logs for import-related messages..."
recent_logs=$(docker logs --since="5m" "$N8N_CONTAINER" 2>&1 | grep -i -E "(import|workflow|error|warn)" | tail -10)
if [[ -n "$recent_logs" ]]; then
    log_info "Recent relevant log entries:"
    echo "$recent_logs" | while IFS= read -r line; do
        log_info "  $line"
    done
else
    log_info "No recent import-related log entries found"
fi

# Clean up
log_info ""
log_info "=== CLEANUP ==="
docker exec "$N8N_CONTAINER" rm -rf /tmp/test-import /tmp/test-import2
log_info "Temporary files cleaned up"

log_info ""
log_success "=== ADVANCED IMPORT TEST COMPLETE ==="
log_info ""
log_info "SUMMARY:"
log_info "- Pre-import workflows: $pre_import_count"
log_info "- Files prepared: $files_prepared"
log_info "- Basic import result: $([ $test1_exit -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')"
if [[ -n "$project_id" ]]; then
    log_info "- Project import result: $([ $test2_exit -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')"
fi
log_info "- Final workflows: $final_count"
log_info "- Net change: $((final_count - pre_import_count))"
log_info ""
log_info "If workflows are not visible in the UI despite successful import:"
log_info "1. Check if they need to be activated in the n8n interface"
log_info "2. Verify project assignments and permissions"
log_info "3. Clear browser cache and refresh the interface"
log_info "4. Check n8n logs for UI-specific errors"