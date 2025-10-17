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
    
    # Get project ID from environment or workflow file
    local project_id=""
    local env_file="$(dirname "$(dirname "${SCRIPT_DIR}")")/.env"
    
    # Try to get from environment variable first
    if [[ -f "$env_file" ]]; then
        project_id=$(grep "^N8N_PROJECT_ID=" "$env_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)
    fi
    
    # If no project ID in env, try to get from workflow files
    if [[ -z "$project_id" ]]; then
        log_info "No N8N_PROJECT_ID in .env, checking workflow files for project ID..."
        for workflow_file in "${WORKFLOWS_DIR}"/*.json; do
            [[ ! -f "$workflow_file" ]] && continue
            
            if jq empty "$workflow_file" 2>/dev/null; then
                project_id=$(jq -r '.shared[]?.project.id // empty' "$workflow_file" 2>/dev/null | head -1)
                [[ -n "$project_id" ]] && break
            fi
        done
    fi
    
    # If still no project ID, try to get the first available project from n8n
    if [[ -z "$project_id" ]]; then
        log_info "No project ID found, attempting to get default project from n8n..."
        project_id=$(run_n8n_cli list:project --output=json 2>/dev/null | jq -r 'first(.[] | .id)' 2>/dev/null)
    fi
    
    if [[ -z "$project_id" ]]; then
        log_warning "Could not determine project ID for import"
        log_info "Proceeding with import without explicit project (will use default)"
    else
        log_info "Using project ID: $project_id"
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
            del(.createdAt, .updatedAt, .versionId, .shared, .projectId)
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
    
    # Import all workflows using n8n CLI
    local import_command="import:workflow --separate --input=/tmp/workflows"
    
    # Add project ID if available
    if [[ -n "$project_id" ]]; then
        import_command="$import_command --project=$project_id"
    fi
    
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
    docker exec "$N8N_CONTAINER" mkdir -p /tmp/exports
    
    # Get all projects and export from each one
    log_info "Fetching all n8n projects..."
    local projects_json
    projects_json=$(run_n8n_cli list:project --output=json 2>/dev/null)
    
    if [[ -z "$projects_json" ]]; then
        log_warning "Could not retrieve projects list"
        # Fall back to exporting without project specification
        log_info "Attempting export without project filter..."
        local export_output
        export_output=$(run_n8n_cli export:workflow --all --separate --output="/tmp/exports" 2>&1)
        local exit_code=$?
    else
        # For each project, export workflows
        local project_count=0
        while IFS= read -r project_id; do
            [[ -z "$project_id" ]] && continue
            ((project_count++))
            
            log_info "Exporting workflows from project: $project_id"
            run_n8n_cli export:workflow --all --separate --project="$project_id" --output="/tmp/exports" 2>&1
        done < <(echo "$projects_json" | jq -r '.[] | .id' 2>/dev/null)
        
        if [[ $project_count -eq 0 ]]; then
            log_warning "No projects found, attempting export without project filter..."
        fi
    fi
    
    log_info "Export completed: $export_output"
    
    # List exported files in container
    local exported_files
    exported_files=$(docker exec "$N8N_CONTAINER" find /tmp/exports -name "*.json" -type f 2>/dev/null)
    
    if [[ -z "$exported_files" ]]; then
        log_warning "No workflow files found after export. Possible reasons:"
        log_warning "  - No workflows exist in n8n"
        log_warning "  - Workflows are not in a project the CLI can access"
        log_warning "  - Database might be empty or not properly initialized"
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
    
    # Test database connection by listing projects
    log_info "Testing database connection..."
    local projects_list
    projects_list=$(run_n8n_cli list:project --output=json 2>&1)
    local projects_exit=$?
    
    if [[ $projects_exit -eq 0 ]]; then
        log_success "✓ Successfully connected to n8n database"
        local project_count
        project_count=$(echo "$projects_list" | jq 'length' 2>/dev/null || echo "0")
        log_info "Found $project_count projects in n8n"
        
        # List each project and its workflows
        while IFS= read -r project_info; do
            [[ -z "$project_info" ]] && continue
            
            local project_id=$(echo "$project_info" | jq -r '.id' 2>/dev/null)
            local project_name=$(echo "$project_info" | jq -r '.name' 2>/dev/null)
            
            log_info "Project: $project_name (ID: $project_id)"
            
            # List workflows in this project
            local workflow_count
            workflow_count=$(run_n8n_cli list:workflow --project="$project_id" 2>&1 | wc -l)
            log_info "  └─ Workflows in this project: $workflow_count"
        done < <(echo "$projects_list" | jq -c '.[]' 2>/dev/null)
    else
        log_error "✗ Failed to connect to n8n database"
        log_error "Error: $projects_list"
        return 1
    fi
    
    # Test listing workflows without project filter
    log_info "Testing workflow listing (without project filter)..."
    local all_workflows
    all_workflows=$(run_n8n_cli list:workflow 2>&1)
    local workflows_count
    workflows_count=$(echo "$all_workflows" | wc -l)
    log_info "Total workflows accessible: $workflows_count"
    
    # Check workflows directory
    if [[ -d "$WORKFLOWS_DIR" ]]; then
        local file_count
        file_count=$(find "$WORKFLOWS_DIR" -name "*.json" -type f | wc -l)
        log_info "Found $file_count workflow files in $WORKFLOWS_DIR"
        
        if [[ $file_count -gt 0 ]]; then
            log_info "Workflow files:"
            find "$WORKFLOWS_DIR" -name "*.json" -type f -exec echo "  - {}" \;
        fi
    else
        log_info "Workflows directory does not exist: $WORKFLOWS_DIR"
    fi
    
    log_success "✓ Workflow sync test completed successfully"
    return 0
}

