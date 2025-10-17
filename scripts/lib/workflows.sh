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
    
    # Load project ID from environment if available
    local env_file="$(dirname "$(dirname "${SCRIPT_DIR}")")/.env"
    if [[ -f "$env_file" ]]; then
        N8N_PROJECT_ID=$(grep "^N8N_PROJECT_ID=" "$env_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)
    fi
    
    # Check if there are any workflow files to import
    local workflow_files=("${WORKFLOWS_DIR}"/*.json)
    if [[ ! -f "${workflow_files[0]}" ]]; then
        log_info "No workflow files found in ${WORKFLOWS_DIR}"
        return 0
    fi
    
    # Create temporary directory in container for workflow files
    docker exec "$N8N_CONTAINER" mkdir -p /tmp/workflows
    
    # Copy all workflow files to container, adding name field if missing
    local files_copied=0
    for workflow_file in "${WORKFLOWS_DIR}"/*.json; do
        [[ ! -f "$workflow_file" ]] && continue
        
        local filename=$(basename "$workflow_file")
        local workflow_name="${filename%.json}"
        
        # Validate JSON
        if ! jq empty "$workflow_file" 2>/dev/null; then
            log_warning "Skipping invalid JSON file: $filename"
            continue
        fi
        
        # Prepare workflow data with required fields
        local temp_file="/tmp/${filename}"
        jq --arg name "$workflow_name" '
            . + {
                name: ($name),
                active: true,
                id: (.id // null)
            } | 
            del(.createdAt, .updatedAt, .versionId)
        ' "$workflow_file" > "$temp_file"
        
        if docker cp "$temp_file" "$N8N_CONTAINER:/tmp/workflows/"; then
            ((files_copied++))
            rm -f "$temp_file"
        else
            log_error "Failed to copy workflow file to container: $filename"
            rm -f "$temp_file"
        fi
    done
    
    if [[ $files_copied -eq 0 ]]; then
        log_error "No valid workflow files could be copied to container"
        docker exec "$N8N_CONTAINER" rm -rf /tmp/workflows
        return 1
    fi
    
    log_info "Importing $files_copied workflow files..."
    
    # Import all workflows using n8n CLI with --separate flag
    local import_command="import:workflow --separate --input=/tmp/workflows"
    
    local import_output
    import_output=$(run_n8n_cli $import_command 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Successfully imported workflows"
        log_info "Import output: $import_output"
        log_info "Please refresh your n8n web interface to see the imported workflows"
    else
        log_error "Failed to import workflows"
        log_error "Error output: $import_output"
    fi
    
    # Clean up temporary directory
    docker exec "$N8N_CONTAINER" rm -rf /tmp/workflows
    
    return $exit_code
}

# Function to export workflows from n8n to files
export_workflows() {
    log_info "Exporting workflows from n8n using CLI..."
    
    if ! is_n8n_running; then
        log_error "n8n container is not running"
        return 1
    fi
    
    # Create workflows directory if it doesn't exist
    mkdir -p "$WORKFLOWS_DIR"
    
    # Create temporary directory in container
    docker exec "$N8N_CONTAINER" mkdir -p /tmp/exports
    
    # Export all workflows using n8n CLI
    log_info "Exporting all workflows..."
    local export_output
    export_output=$(run_n8n_cli export:workflow --all --separate --output="/tmp/exports" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Failed to export workflows"
        log_error "Error output: $export_output"
        docker exec "$N8N_CONTAINER" rm -rf /tmp/exports
        return $exit_code
    fi
    
    log_info "Export completed: $export_output"
    
    # List exported files in container
    local exported_files
    exported_files=$(docker exec "$N8N_CONTAINER" find /tmp/exports -name "*.json" -type f 2>/dev/null)
    
    if [[ -z "$exported_files" ]]; then
        log_info "No workflow files found after export"
        docker exec "$N8N_CONTAINER" rm -rf /tmp/exports
        return 0
    fi
    
    local exported=0
    
    # Copy exported files from container to host
    while IFS= read -r exported_file; do
        [[ -z "$exported_file" ]] && continue
        
        # Get filename and workflow name from exported file
        local container_filename=$(basename "$exported_file")
        
        # Try to get a better filename based on workflow name
        local workflow_data
        workflow_data=$(docker exec "$N8N_CONTAINER" cat "$exported_file" 2>/dev/null)
        
        if [[ -n "$workflow_data" ]]; then
            local workflow_name
            workflow_name=$(echo "$workflow_data" | jq -r '.name // empty' 2>/dev/null)
            
            if [[ -n "$workflow_name" && "$workflow_name" != "null" ]]; then
                # Sanitize filename
                workflow_name=$(echo "$workflow_name" | sed 's/[^a-zA-Z0-9._-]/_/g')
                local output_file="${WORKFLOWS_DIR}/${workflow_name}.json"
            else
                local output_file="${WORKFLOWS_DIR}/${container_filename}"
            fi
            
            # Copy from container to host
            if docker cp "$N8N_CONTAINER:$exported_file" "$output_file"; then
                log_success "Exported: $(basename "$output_file")"
                ((exported++))
            else
                log_error "Failed to copy exported workflow: $exported_file"
            fi
        fi
        
    done <<< "$exported_files"
    
    # Clean up temporary directory
    docker exec "$N8N_CONTAINER" rm -rf /tmp/exports
    
    log_info "Exported $exported workflows to ${WORKFLOWS_DIR}"
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

# List n8n projects (returns JSON list)
list_n8n_projects() {
    if ! is_n8n_running; then
        log_error "n8n container is not running"
        return 1
    fi

    run_n8n_cli list:project --output=json 2>/dev/null || return 1
}

# Resolve project name to project ID (prints ID)
resolve_project_id() {
    local project_name="$1"
    if [[ -z "$project_name" ]]; then
        log_error "Project name required"
        return 1
    fi

    local projects_json
    projects_json=$(list_n8n_projects) || return 1

    echo "$projects_json" | jq -r ".[] | select(.name == \"${project_name}\") | .id" 2>/dev/null
}

# Function to test workflow sync
test_workflow_sync() {
    log_info "Testing workflow sync using n8n CLI..."
    
    if ! is_n8n_running; then
        log_error "n8n container is not running"
        return 1
    fi
    
    # Test if n8n CLI is available in container
    if docker exec "$N8N_CONTAINER" which n8n >/dev/null 2>&1; then
        log_success "✓ n8n CLI is available in container"
    else
        log_error "✗ n8n CLI not found in container"
        return 1
    fi
    
    # Test listing workflows
    log_info "Testing workflow listing..."
    local workflow_list
    workflow_list=$(run_n8n_cli list:workflow 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "✓ Successfully connected to n8n database"
        local workflow_count
        workflow_count=$(echo "$workflow_list" | wc -l)
        log_info "Found $workflow_count workflows in n8n"
    else
        log_error "✗ Failed to connect to n8n database"
        log_error "Error: $workflow_list"
        return 1
    fi
    
    # Check workflows directory
    if [[ -d "$WORKFLOWS_DIR" ]]; then
        local file_count
        file_count=$(find "$WORKFLOWS_DIR" -name "*.json" -type f | wc -l)
        log_info "Found $file_count workflow files in $WORKFLOWS_DIR"
    else
        log_info "Workflows directory does not exist: $WORKFLOWS_DIR"
    fi
    
    log_success "✓ Workflow sync test completed successfully"
    return 0
}

