#!/bin/bash

# Simple workflow import/export for n8n using CLI

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
N8N_CONTAINER="homelab-n8n"
WORKFLOWS_DIR="$(dirname "${SCRIPT_DIR}")/../workflows"

# Function to check if n8n is running
is_n8n_running() {
    docker ps --format "table {{.Names}}" | grep -q "^${N8N_CONTAINER}$"
}

# Function to run n8n CLI command in container
run_n8n_cli() {
    local command="$1"
    shift
    local args="$@"
    
    if ! is_n8n_running; then
        log_error "n8n container is not running"
        return 1
    fi
    
    log_debug "Running n8n CLI: $command $args"
    
    # Run n8n CLI command in the container
    docker exec "$N8N_CONTAINER" n8n "$command" $args
}

# Function to import workflows from files to n8n
import_workflows() {
    log_info "Importing workflows to n8n using CLI..."
    
    if ! is_n8n_running; then
        log_error "n8n container is not running"
        return 1
    fi
    
    # Check if there are any workflow files to import
    local workflow_files=("${WORKFLOWS_DIR}"/*.json)
    if [[ ! -f "${workflow_files[0]}" ]]; then
        log_info "No workflow files found in ${WORKFLOWS_DIR}"
        return 0
    fi
    
    log_info "Found workflow files in ${WORKFLOWS_DIR}:"
    for wf in "${workflow_files[@]}"; do
        [[ -f "$wf" ]] && log_info "  - $(basename "$wf")"
    done
    
    # Get project ID from environment or workflow file
    local project_id=""
    local env_file="$(dirname "$(dirname "${SCRIPT_DIR}")")/.env"
    
    # Try to get from workflow files first (more reliable)
    log_debug "Checking workflow files for project ID..."
    for workflow_file in "${WORKFLOWS_DIR}"/*.json; do
        [[ ! -f "$workflow_file" ]] && continue
        
        if jq empty "$workflow_file" 2>/dev/null; then
            local file_project_id=$(jq -r '.shared[]?.project.id // empty' "$workflow_file" 2>/dev/null | head -1)
            if [[ -n "$file_project_id" && "$file_project_id" != "null" ]]; then
                project_id="$file_project_id"
                log_info "Found project ID in workflow file: $project_id"
                break
            fi
        fi
    done
    
    # Fall back to environment variable if needed
    if [[ -z "$project_id" || "$project_id" == "null" ]]; then
        if [[ -f "$env_file" ]]; then
            project_id=$(grep "^N8N_PROJECT_ID=" "$env_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)
            if [[ -n "$project_id" && "$project_id" != "null" ]]; then
                log_info "Using project ID from .env: $project_id"
            fi
        fi
    fi
    
    if [[ -z "$project_id" || "$project_id" == "null" ]]; then
        log_warning "Could not determine project ID for import"
        log_info "Proceeding with import without explicit project (will use default)"
    fi
    
    # Create temporary directory in container for workflow files
    log_debug "Creating temporary directory in container..."
    docker exec "$N8N_CONTAINER" mkdir -p /tmp/workflows
    
    # Copy all workflow files to container, cleaning up metadata
    local files_copied=0
    local files_failed=0
    for workflow_file in "${WORKFLOWS_DIR}"/*.json; do
        [[ ! -f "$workflow_file" ]] && continue
        
        local filename=$(basename "$workflow_file")
        local workflow_name="${filename%.json}"
        
        # Validate JSON
        if ! jq empty "$workflow_file" 2>/dev/null; then
            log_warning "⚠️  Skipping invalid JSON file: $filename"
            ((files_failed++))
            continue
        fi
        
        # Check if workflow has required fields
        local has_nodes=$(jq 'has("nodes")' "$workflow_file" 2>/dev/null)
        if [[ "$has_nodes" != "true" ]]; then
            log_warning "⚠️  Skipping file missing 'nodes' field: $filename"
            ((files_failed++))
            continue
        fi
        
        # Prepare workflow data - clean up metadata that could cause conflicts
        local temp_file="/tmp/${filename}"
        log_debug "Preparing workflow file: $filename"
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
        
        if [[ $? -ne 0 ]]; then
            log_warning "⚠️  Failed to prepare workflow: $filename"
            ((files_failed++))
            rm -f "$temp_file"
            continue
        fi
        
        if docker cp "$temp_file" "$N8N_CONTAINER:/tmp/workflows/"; then
            log_debug "✓ Copied to container: $filename"
            ((files_copied++))
            rm -f "$temp_file"
        else
            log_error "✗ Failed to copy workflow file to container: $filename"
            ((files_failed++))
            rm -f "$temp_file"
        fi
    done
    
    if [[ $files_copied -eq 0 ]]; then
        log_error "No valid workflow files could be copied to container"
        if [[ $files_failed -gt 0 ]]; then
            log_error "$files_failed file(s) failed validation or processing"
        fi
        docker exec "$N8N_CONTAINER" rm -rf /tmp/workflows
        return 1
    fi
    
    log_info "Ready to import: $files_copied workflow file(s)"
    if [[ $files_failed -gt 0 ]]; then
        log_warning "Skipped: $files_failed invalid file(s)"
    fi
    
    # Import all workflows using n8n CLI
    log_info "Executing import command..."
    
    # Build the import command
    local import_cmd="n8n import:workflow --separate --input=/tmp/workflows"
    
    # Add project ID if available
    if [[ -n "$project_id" && "$project_id" != "null" ]]; then
        import_cmd="$import_cmd --projectId=$project_id"
        log_debug "Using project ID: $project_id"
    fi
    
    log_debug "Command: $import_cmd"
    
    # Execute import directly in container
    local import_output
    import_output=$(docker exec "$N8N_CONTAINER" $import_cmd 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "✓ Successfully imported workflows to n8n"
        
        # Parse and display import details if available
        if [[ -n "$import_output" ]]; then
            log_info "Import details:"
            echo "$import_output" | while IFS= read -r line; do
                [[ -n "$line" ]] && log_info "  $line"
            done
        fi
        
        # List workflows to verify import
        log_info "Verifying imported workflows..."
        local workflow_list
        workflow_list=$(docker exec "$N8N_CONTAINER" n8n list:workflow 2>&1)
        if [[ $? -eq 0 && -n "$workflow_list" ]]; then
            log_success "Current workflows in n8n:"
            echo "$workflow_list" | while IFS= read -r line; do
                [[ -n "$line" ]] && log_info "  $line"
            done
        fi
        
        log_info ""
        log_success "✓ Import complete! Please refresh your n8n web interface."
        log_info "Note: If workflows don't appear, they may need activation in the UI."
    else
        log_error "✗ Failed to import workflows"
        log_error "Exit code: $exit_code"
        log_error "Error output:"
        echo "$import_output" | while IFS= read -r line; do
            [[ -n "$line" ]] && log_error "  $line"
        done
        log_info ""
        log_info "Troubleshooting tips:"
        log_info "1. Check if workflows have valid JSON structure"
        log_info "2. Ensure n8n database is accessible"
        log_info "3. Verify project ID is correct (if specified)"
        log_info "4. Check container logs: docker logs homelab-n8n"
    fi
    
    # Clean up temporary directory
    log_debug "Cleaning up temporary files..."
    docker exec "$N8N_CONTAINER" rm -rf /tmp/workflows
    
    return $exit_code
}

# Export workflows from n8n to files
export_workflows() {
    log_info "Exporting workflows from n8n using CLI..."
    
    if ! is_n8n_running; then
        log_error "n8n container is not running"
        return 1
    fi
    
    # Create workflows directory if it doesn't exist
    mkdir -p "$WORKFLOWS_DIR"
    
    # Create temporary directory in container
    log_debug "Creating temporary export directory in container..."
    docker exec "$N8N_CONTAINER" mkdir -p /tmp/exports
    
    # First, check if there are any workflows in n8n
    log_info "Checking for workflows in n8n..."
    local workflow_count
    workflow_count=$(docker exec "$N8N_CONTAINER" n8n list:workflow --onlyId 2>/dev/null | wc -l | xargs)
    
    if [[ -z "$workflow_count" || "$workflow_count" == "0" ]]; then
        log_warning "No workflows found in n8n database"
        log_info "Possible reasons:"
        log_info "  - No workflows have been created yet"
        log_info "  - Database is empty or not properly initialized"
        log_info "  - n8n service just started and hasn't loaded workflows yet"
        docker exec "$N8N_CONTAINER" rm -rf /tmp/exports
        return 0
    fi
    
    log_info "Found $workflow_count workflow(s) in n8n database"
    
    # Export all workflows using backup format (all, pretty, separate)
    log_info "Executing export command..."
    local export_output
    export_output=$(docker exec "$N8N_CONTAINER" n8n export:workflow --backup --output=/tmp/exports 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "✗ Export command failed with exit code: $exit_code"
        log_error "Error output:"
        echo "$export_output" | while IFS= read -r line; do
            [[ -n "$line" ]] && log_error "  $line"
        done
        docker exec "$N8N_CONTAINER" rm -rf /tmp/exports
        return 1
    fi
    
    log_debug "Export command output:"
    echo "$export_output" | while IFS= read -r line; do
        [[ -n "$line" ]] && log_debug "  $line"
    done
    
    # List exported files in container
    log_debug "Checking for exported files..."
    local exported_files
    exported_files=$(docker exec "$N8N_CONTAINER" find /tmp/exports -name "*.json" -type f 2>/dev/null)
    
    if [[ -z "$exported_files" ]]; then
        log_warning "No workflow files found after export"
        log_warning "Export command succeeded but produced no files"
        log_info "This may indicate:"
        log_info "  - Workflows exist but couldn't be exported"
        log_info "  - Permission issues in the container"
        log_info "  - Database connection issues"
        docker exec "$N8N_CONTAINER" rm -rf /tmp/exports
        return 0
    fi
    
    local exported=0
    local failed=0
    
    # Copy exported files from container to host
    log_info "Copying exported workflows to host..."
    while IFS= read -r exported_file; do
        [[ -z "$exported_file" ]] && continue
        
        # Get filename and workflow name from exported file
        local container_filename=$(basename "$exported_file")
        
        # Try to get a better filename based on workflow name
        local workflow_data
        workflow_data=$(docker exec "$N8N_CONTAINER" cat "$exported_file" 2>/dev/null)
        
        if [[ -z "$workflow_data" ]]; then
            log_warning "⚠️  Could not read workflow data from: $exported_file"
            ((failed++))
            continue
        fi
        
        # Validate JSON
        if ! echo "$workflow_data" | jq empty 2>/dev/null; then
            log_warning "⚠️  Invalid JSON in exported file: $container_filename"
            ((failed++))
            continue
        fi
        
        local workflow_name
        workflow_name=$(echo "$workflow_data" | jq -r '.name // empty' 2>/dev/null)
        
        if [[ -n "$workflow_name" && "$workflow_name" != "null" ]]; then
            # Sanitize filename - replace non-alphanumeric with underscore
            workflow_name=$(echo "$workflow_name" | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g')
            local output_file="${WORKFLOWS_DIR}/${workflow_name}.json"
        else
            local output_file="${WORKFLOWS_DIR}/${container_filename}"
        fi
        
        # Copy from container to host
        if docker cp "$N8N_CONTAINER:$exported_file" "$output_file"; then
            log_success "✓ Exported: $(basename "$output_file")"
            ((exported++))
            
            # Verify the exported file is valid
            if ! jq empty "$output_file" 2>/dev/null; then
                log_warning "⚠️  Exported file has invalid JSON: $(basename "$output_file")"
                log_info "  File will be kept but may need manual review"
            fi
        else
            log_error "✗ Failed to copy exported workflow: $exported_file"
            ((failed++))
        fi
        
    done <<< "$exported_files"
    
    # Clean up temporary directory
    log_debug "Cleaning up temporary files..."
    docker exec "$N8N_CONTAINER" rm -rf /tmp/exports
    
    # Summary
    log_info ""
    if [[ $exported -gt 0 ]]; then
        log_success "✓ Successfully exported $exported workflow(s) to ${WORKFLOWS_DIR}"
        if [[ $failed -gt 0 ]]; then
            log_warning "⚠️  $failed workflow(s) failed to export"
        fi
    else
        log_error "✗ No workflows were exported successfully"
        if [[ $failed -gt 0 ]]; then
            log_error "  $failed workflow(s) failed during export"
        fi
        return 1
    fi
    
    return 0
}

# Function to export workflows during setup (waits for n8n to be ready)
export_initial_workflows() {
    log_info "Setting up workflow synchronization..."
    
    # Create workflows directory
    mkdir -p "$WORKFLOWS_DIR"
    
    # Wait for n8n to be ready
    log_info "Waiting for n8n to be ready..."
    local max_wait=60
    local wait_time=0
    
    while ! is_n8n_running; do
        if [[ $wait_time -ge $max_wait ]]; then
            log_warning "n8n not ready after ${max_wait}s, skipping workflow export"
            log_info "You can export workflows later with: ./scripts/manage.sh export-workflows"
            return 0
        fi
        sleep 2
        ((wait_time += 2))
    done
    
    # Give n8n a few more seconds to fully initialize
    sleep 5
    
    # Export workflows if any exist
    if export_workflows >/dev/null 2>&1; then
        log_success "Exported existing workflows to files"
    else
        log_info "No existing workflows to export"
    fi
    
    log_info "Workflow sync ready. Use: ./scripts/manage.sh import-workflows | export-workflows"
}


# Function to test workflow sync
test_workflow_sync() {
    log_info "Testing workflow sync using n8n CLI..."
    echo ""
    
    if ! is_n8n_running; then
        log_error "n8n container is not running"
        return 1
    fi
    
    # Test 1: Check if n8n CLI is available in container
    log_info "Test 1: Checking n8n CLI availability..."
    if docker exec "$N8N_CONTAINER" which n8n >/dev/null 2>&1; then
        log_success "✓ n8n CLI is available in container"
    else
        log_error "✗ n8n CLI not found in container"
        return 1
    fi
    echo ""
    
    # Test 2: Check database connection by listing workflows
    log_info "Test 2: Testing database connection..."
    local workflow_list
    workflow_list=$(docker exec "$N8N_CONTAINER" n8n list:workflow 2>&1)
    local list_exit=$?
    
    if [[ $list_exit -eq 0 ]]; then
        log_success "✓ Successfully connected to n8n database"
        
        # Count workflows
        local workflow_count
        workflow_count=$(docker exec "$N8N_CONTAINER" n8n list:workflow --onlyId 2>/dev/null | wc -l | xargs)
        log_info "Found $workflow_count workflow(s) in n8n database"
        
        if [[ $workflow_count -gt 0 ]]; then
            log_info ""
            log_info "Workflow list:"
            echo "$workflow_list" | while IFS= read -r line; do
                [[ -n "$line" ]] && log_info "  $line"
            done
        fi
    else
        log_error "✗ Failed to connect to n8n database"
        log_error "Error output:"
        echo "$workflow_list" | while IFS= read -r line; do
            [[ -n "$line" ]] && log_error "  $line"
        done
        return 1
    fi
    echo ""
    
    # Test 3: Check workflows directory
    log_info "Test 3: Checking local workflows directory..."
    if [[ -d "$WORKFLOWS_DIR" ]]; then
        local file_count
        file_count=$(find "$WORKFLOWS_DIR" -name "*.json" -type f 2>/dev/null | wc -l | xargs)
        log_info "Workflows directory: $WORKFLOWS_DIR"
        log_info "Found $file_count workflow file(s)"
        
        if [[ $file_count -gt 0 ]]; then
            log_info ""
            log_info "Workflow files:"
            find "$WORKFLOWS_DIR" -name "*.json" -type f | while read -r file; do
                local filename=$(basename "$file")
                # Validate JSON
                if jq empty "$file" 2>/dev/null; then
                    local wf_name=$(jq -r '.name // "unnamed"' "$file" 2>/dev/null)
                    local node_count=$(jq '.nodes | length' "$file" 2>/dev/null)
                    log_success "  ✓ $filename"
                    log_info "      Name: $wf_name | Nodes: $node_count"
                else
                    log_error "  ✗ $filename (invalid JSON)"
                fi
            done
        else
            log_info "No workflow files found in directory"
        fi
    else
        log_warning "Workflows directory does not exist: $WORKFLOWS_DIR"
        log_info "Creating directory..."
        mkdir -p "$WORKFLOWS_DIR"
        log_success "✓ Created workflows directory"
    fi
    echo ""
    
    # Test 4: Test export functionality
    log_info "Test 4: Testing export functionality..."
    local test_export_dir="/tmp/n8n_test_export_$$"
    docker exec "$N8N_CONTAINER" mkdir -p "$test_export_dir" 2>/dev/null
    
    local export_test
    export_test=$(docker exec "$N8N_CONTAINER" n8n export:workflow --all --output="$test_export_dir/test.json" 2>&1)
    local export_exit=$?
    
    if [[ $export_exit -eq 0 ]]; then
        log_success "✓ Export command executed successfully"
    else
        log_warning "⚠️  Export command failed or no workflows to export"
        log_debug "Output: $export_test"
    fi
    
    # Clean up test export
    docker exec "$N8N_CONTAINER" rm -rf "$test_export_dir" 2>/dev/null
    echo ""
    
    # Test 5: Test import capability (dry run)
    log_info "Test 5: Testing import capability..."
    if [[ -f "${WORKFLOWS_DIR}"/*.json ]] 2>/dev/null; then
        log_success "✓ Import functionality available (workflow files found)"
        log_info "Run './scripts/manage.sh import-workflows' to import"
    else
        log_info "No workflow files to import"
        log_info "Run './scripts/manage.sh export-workflows' first to export existing workflows"
    fi
    echo ""
    
    # Summary
    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "✓ Workflow sync diagnostic completed successfully"
    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "Next steps:"
    log_info "  - Import workflows: ./scripts/manage.sh import-workflows"
    log_info "  - Export workflows: ./scripts/manage.sh export-workflows"
    echo ""
    
    return 0
}

