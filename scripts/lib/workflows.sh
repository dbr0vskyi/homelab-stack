#!/bin/bash

# Simple workflow import/export for n8n

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

# Function to get n8n API credentials from environment
get_n8n_credentials() {
    # Try multiple possible locations for .env file
    local env_files=(
        "$(dirname "$(dirname "${SCRIPT_DIR}")")/.env"  # Two levels up (homelab-stack/.env)
        "$(dirname "${SCRIPT_DIR}")/.env"               # One level up
        "${PWD}/.env"                                   # Current directory
        "./.env"                                        # Relative current
    )
    
    local env_file=""
    for file in "${env_files[@]}"; do
        if [[ -f "$file" ]]; then
            env_file="$file"
            break
        fi
    done
    
    if [[ -n "$env_file" ]]; then
        log_info "Using .env file: $env_file"
        N8N_USER=$(grep "^N8N_USER=" "$env_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)
        N8N_PASSWORD=$(grep "^N8N_PASSWORD=" "$env_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)
        N8N_HOST=$(grep "^N8N_HOST=" "$env_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)
    else
        log_error "No .env file found. Checked: ${env_files[*]}"
        N8N_USER="${N8N_USER:-admin}"
        N8N_PASSWORD="${N8N_PASSWORD}"
        N8N_HOST="${N8N_HOST:-localhost}"
    fi
    
    # Set defaults
    N8N_USER="${N8N_USER:-admin}"
    N8N_HOST="${N8N_HOST:-localhost}"
    
    if [[ -z "$N8N_PASSWORD" ]]; then
        log_error "N8N_PASSWORD not found in environment or .env file"
        log_info "Please ensure N8N_PASSWORD is set in your .env file"
        return 1
    fi
}

# Function to make authenticated API call to n8n (using session cookies)
make_n8n_api_call() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    
    # Get credentials
    if ! get_n8n_credentials; then
        return 1
    fi
    
    # Ensure we have a valid session cookie
    if ! test -f /tmp/n8n_session.txt || ! session_is_valid; then
        if ! create_n8n_session; then
            log_error "Failed to create n8n session"
            return 1
        fi
    fi
    
    if [[ -n "$data" ]]; then
        curl -s -k \
            -b /tmp/n8n_session.txt \
            -H "Content-Type: application/json" \
            -X "$method" \
            -d "$data" \
            "https://${N8N_HOST}$endpoint" 2>/dev/null
    else
        curl -s -k \
            -b /tmp/n8n_session.txt \
            -X "$method" \
            "https://${N8N_HOST}$endpoint" 2>/dev/null
    fi
}

# Function to create n8n session
create_n8n_session() {
    # Clear any existing session
    rm -f /tmp/n8n_session.txt
    
    # First, get the login page to establish session
    curl -s -k -c /tmp/n8n_session.txt \
        "https://${N8N_HOST}/" >/dev/null 2>&1
    
    # Try Basic Auth first (for the web interface)
    local auth_response
    auth_response=$(curl -s -k \
        -b /tmp/n8n_session.txt \
        -c /tmp/n8n_session.txt \
        -u "${N8N_USER}:${N8N_PASSWORD}" \
        "https://${N8N_HOST}/rest/login" 2>/dev/null)
    
    # Check if login was successful
    if echo "$auth_response" | jq -e '.data.id' >/dev/null 2>&1; then
        return 0
    fi
    
    # If Basic Auth failed, try form-based login
    auth_response=$(curl -s -k \
        -b /tmp/n8n_session.txt \
        -c /tmp/n8n_session.txt \
        -H "Content-Type: application/json" \
        -X POST \
        -d "{\"emailOrLdapLoginId\":\"${N8N_USER}\",\"password\":\"${N8N_PASSWORD}\"}" \
        "https://${N8N_HOST}/rest/login" 2>/dev/null)
    
    if echo "$auth_response" | jq -e '.data.id' >/dev/null 2>&1; then
        return 0
    fi
    
    log_error "Failed to create n8n session"
    log_error "Response: $auth_response"
    return 1
}

# Function to check if session is valid
session_is_valid() {
    local test_response
    test_response=$(curl -s -k \
        -b /tmp/n8n_session.txt \
        "https://${N8N_HOST}/rest/workflows" 2>/dev/null)
    
    echo "$test_response" | jq -e '.data' >/dev/null 2>&1
}

# Function to test Basic Auth with n8n API
get_n8n_auth_cookie() {
    get_n8n_credentials || return 1
    
    # Try to create a session
    if create_n8n_session; then
        return 0
    else
        # Try localhost if the configured host failed
        if [[ "$N8N_HOST" != "localhost" ]]; then
            log_info "Trying localhost as fallback..."
            N8N_HOST="localhost"
            if create_n8n_session; then
                return 0
            fi
        fi
        
        log_error "Failed to authenticate with n8n API"
        return 1
    fi
}

# Function to import workflows from files to n8n
import_workflows() {
    log_info "Importing workflows to n8n..."
    
    if ! is_n8n_running; then
        log_error "n8n container is not running"
        return 1
    fi
    
    # Test authentication first
    if ! get_n8n_credentials; then
        return 1
    fi
    
    local imported=0
    local errors=0
    
    # Process each workflow file
    for workflow_file in "${WORKFLOWS_DIR}"/*.json; do
        [[ ! -f "$workflow_file" ]] && continue
        
        local filename=$(basename "$workflow_file")
        local workflow_name="${filename%.json}"
        
        log_info "Processing workflow: $workflow_name"
        
        # Validate JSON
        if ! jq empty "$workflow_file" 2>/dev/null; then
            log_warning "Skipping invalid JSON file: $filename"
            ((errors++))
            continue
        fi
        
        # Read workflow data
        local workflow_data
        workflow_data=$(jq -c . "$workflow_file")
        
        # Clean the workflow data for import (remove fields that shouldn't be in import)
        local clean_workflow_data
        clean_workflow_data=$(echo "$workflow_data" | jq 'del(.id, .createdAt, .updatedAt, .versionId, .meta)')
        
        # Ensure the workflow has a name
        local workflow_json_name
        workflow_json_name=$(echo "$clean_workflow_data" | jq -r '.name // empty')
        if [[ -z "$workflow_json_name" ]]; then
            clean_workflow_data=$(echo "$clean_workflow_data" | jq --arg name "$workflow_name" '. + {name: $name}')
        fi
        
        # Check if workflow already exists
        log_info "Checking for existing workflow..."
        local existing_workflows
        existing_workflows=$(make_n8n_api_call "GET" "/rest/workflows")
        
        if [[ -z "$existing_workflows" ]] || echo "$existing_workflows" | jq -e '.status == "error"' >/dev/null 2>&1; then
            log_error "Failed to fetch existing workflows from n8n API"
            log_error "Response: $existing_workflows"
            ((errors++))
            continue
        fi
        
        local workflow_id
        workflow_id=$(echo "$existing_workflows" | jq -r ".data[]? | select(.name == \"$workflow_name\") | .id" 2>/dev/null)
        
        if [[ -n "$workflow_id" && "$workflow_id" != "null" ]]; then
            # Update existing workflow
            log_info "Updating existing workflow (ID: $workflow_id)..."
            local response
            response=$(make_n8n_api_call "PUT" "/rest/workflows/${workflow_id}" "$clean_workflow_data")
            
            if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
                log_success "Updated workflow: $workflow_name"
                ((imported++))
            else
                log_error "Failed to update workflow: $workflow_name"
                log_error "Response: $response"
                ((errors++))
            fi
        else
            # Create new workflow
            log_info "Creating new workflow..."
            local response
            response=$(make_n8n_api_call "POST" "/rest/workflows" "$clean_workflow_data")
            
            if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
                log_success "Imported workflow: $workflow_name"
                ((imported++))
            else
                log_error "Failed to import workflow: $workflow_name"
                log_error "Response: $response"
                ((errors++))
            fi
        fi
    done
    
    rm -f /tmp/n8n_session.txt
    log_info "Import completed: $imported workflows imported, $errors errors"
    
    if [[ $imported -gt 0 ]]; then
        log_info "Please refresh your n8n web interface to see the imported workflows"
    fi
    
    return $errors
}

# Function to export workflows from n8n to files
export_workflows() {
    log_info "Exporting workflows from n8n..."
    
    if ! is_n8n_running; then
        log_error "n8n container is not running"
        return 1
    fi
    
    # Test authentication first
    if ! get_n8n_credentials; then
        return 1
    fi
    
    # Create workflows directory if it doesn't exist
    mkdir -p "$WORKFLOWS_DIR"
    
    # Get all workflows from n8n
    local workflows
    workflows=$(make_n8n_api_call "GET" "/rest/workflows")
    
    if [[ -z "$workflows" ]] || echo "$workflows" | jq -e '.status == "error"' >/dev/null 2>&1; then
        log_error "Failed to fetch workflows from n8n API"
        log_error "Response: $workflows"
        rm -f /tmp/n8n_cookie.txt
        return 1
    fi
    
    local exported=0
    
    # Process each workflow
    while IFS= read -r workflow_id; do
        [[ -z "$workflow_id" || "$workflow_id" == "null" ]] && continue
        
        # Get workflow details
        local workflow_data
        workflow_data=$(make_n8n_api_call "GET" "/rest/workflows/${workflow_id}")
        
        if echo "$workflow_data" | jq -e '.name' >/dev/null 2>&1; then
            # Extract workflow name and sanitize for filename
            local workflow_name
            workflow_name=$(echo "$workflow_data" | jq -r '.name' | sed 's/[^a-zA-Z0-9._-]/_/g')
            
            local output_file="${WORKFLOWS_DIR}/${workflow_name}.json"
            
            # Save workflow
            if echo "$workflow_data" | jq '.' > "$output_file" 2>/dev/null; then
                log_success "Exported: $workflow_name"
                ((exported++))
            fi
        fi
        
    done < <(echo "$workflows" | jq -r '.data[].id' 2>/dev/null)
    
    rm -f /tmp/n8n_session.txt
    log_info "Exported $exported workflows"
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
    
    while ! is_n8n_running || ! get_n8n_credentials >/dev/null 2>&1; do
        if [[ $wait_time -ge $max_wait ]]; then
            log_warning "n8n not ready after ${max_wait}s, skipping workflow export"
            log_info "You can export workflows later with: ./scripts/manage.sh export-workflows"
            return 0
        fi
        sleep 2
        ((wait_time += 2))
    done
    
    # Export workflows if any exist
    if export_workflows >/dev/null 2>&1; then
        log_success "Exported existing workflows to files"
    else
        log_info "No existing workflows to export"
    fi
    
    log_info "Workflow sync ready. Use: ./scripts/manage.sh import-workflows | export-workflows"
}

# Function to test workflow sync credentials
test_workflow_credentials() {
    log_info "Testing workflow sync credentials..."
    
    # Debug path information
    log_info "Debug info:"
    log_info "  SCRIPT_DIR: $SCRIPT_DIR"
    log_info "  PWD: $PWD"
    log_info "  Looking for .env in:"
    local env_files=(
        "$(dirname "$(dirname "${SCRIPT_DIR}")")/.env"
        "$(dirname "${SCRIPT_DIR}")/.env"
        "${PWD}/.env"
        "./.env"
    )
    for file in "${env_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_info "    ✓ Found: $file"
        else
            log_info "    ✗ Missing: $file"
        fi
    done
    
    if ! is_n8n_running; then
        log_error "n8n container is not running"
        return 1
    fi
    
    if get_n8n_credentials; then
        log_success "✓ Credentials loaded successfully"
        log_info "  User: $N8N_USER"
        log_info "  Host: $N8N_HOST"
        log_info "  Password: ${N8N_PASSWORD:0:3}***${N8N_PASSWORD: -3}" # Show first 3 and last 3 chars
        
        if get_n8n_auth_cookie; then
            log_success "✓ Authentication successful"
            rm -f /tmp/n8n_session.txt
            return 0
        else
            log_error "✗ Authentication failed"
            return 1
        fi
    else
        log_error "✗ Failed to load credentials"
        return 1
    fi
}

