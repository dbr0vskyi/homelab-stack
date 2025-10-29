#!/bin/bash

# Execution log management for n8n workflows
# Provides functions to query PostgreSQL database for workflow execution history

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
POSTGRES_CONTAINER="homelab-postgres"
POSTGRES_USER="n8n"
POSTGRES_DB="n8n"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Helper Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check if PostgreSQL container is running
is_postgres_running() {
    docker ps --format "table {{.Names}}" | grep -q "^${POSTGRES_CONTAINER}$"
}

# Execute PostgreSQL query
execute_postgres_query() {
    local query="$1"

    if ! is_postgres_running; then
        log_error "PostgreSQL container is not running"
        return 1
    fi

    docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$query" 2>&1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Execution Query Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Get the latest workflow execution
get_latest_execution() {
    log_info "Fetching latest workflow execution from PostgreSQL..."
    echo ""

    if ! is_postgres_running; then
        log_error "PostgreSQL container is not running"
        return 1
    fi

    local query="
SELECT
    e.id as execution_id,
    e.\"workflowId\" as workflow_id,
    w.name as workflow_name,
    e.mode,
    e.\"startedAt\" as started_at,
    e.\"stoppedAt\" as stopped_at,
    ROUND(EXTRACT(EPOCH FROM (e.\"stoppedAt\" - e.\"startedAt\"))/60, 2) as duration_mins,
    e.status,
    e.finished,
    w.active as workflow_active
FROM execution_entity e
LEFT JOIN workflow_entity w ON e.\"workflowId\" = w.id
WHERE e.\"deletedAt\" IS NULL
ORDER BY e.\"startedAt\" DESC
LIMIT 1;
"

    local result
    result=$(execute_postgres_query "$query")
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
        echo ""
        log_success "✓ Latest execution retrieved successfully"
    else
        log_error "✗ Failed to retrieve latest execution"
        log_error "$result"
        return 1
    fi

    return 0
}

# Get recent execution history
get_execution_history() {
    local limit="${1:-10}"

    log_info "Fetching last $limit workflow executions from PostgreSQL..."
    echo ""

    if ! is_postgres_running; then
        log_error "PostgreSQL container is not running"
        return 1
    fi

    local query="
SELECT
    e.id,
    w.name as workflow_name,
    e.\"startedAt\" as started,
    e.status,
    ROUND(EXTRACT(EPOCH FROM (e.\"stoppedAt\" - e.\"startedAt\"))/60, 1) as duration_mins
FROM execution_entity e
LEFT JOIN workflow_entity w ON e.\"workflowId\" = w.id
WHERE e.\"deletedAt\" IS NULL
ORDER BY e.\"startedAt\" DESC
LIMIT $limit;
"

    local result
    result=$(execute_postgres_query "$query")
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
        echo ""
        log_success "✓ Execution history retrieved successfully"
    else
        log_error "✗ Failed to retrieve execution history"
        log_error "$result"
        return 1
    fi

    return 0
}

# Get detailed execution information by ID
get_execution_details() {
    local execution_id="$1"

    if [[ -z "$execution_id" ]]; then
        log_error "Execution ID required"
        log_info "Usage: get_execution_details <execution_id>"
        return 1
    fi

    log_info "Fetching detailed information for execution ID: $execution_id"
    echo ""

    if ! is_postgres_running; then
        log_error "PostgreSQL container is not running"
        return 1
    fi

    # Get execution details
    local query="
SELECT
    e.id as execution_id,
    e.\"workflowId\" as workflow_id,
    w.name as workflow_name,
    e.mode,
    e.\"startedAt\" as started_at,
    e.\"stoppedAt\" as stopped_at,
    EXTRACT(EPOCH FROM (e.\"stoppedAt\" - e.\"startedAt\")) as duration_seconds,
    ROUND(EXTRACT(EPOCH FROM (e.\"stoppedAt\" - e.\"startedAt\"))/60, 2) as duration_mins,
    e.status,
    e.finished,
    e.\"retryOf\" as retry_of,
    e.\"retrySuccessId\" as retry_success_id,
    e.\"waitTill\" as wait_till,
    w.active as workflow_active,
    w.\"updatedAt\" as workflow_updated_at,
    e.\"createdAt\" as created_at
FROM execution_entity e
LEFT JOIN workflow_entity w ON e.\"workflowId\" = w.id
WHERE e.id = $execution_id;
"

    local result
    result=$(execute_postgres_query "$query")
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "$result"

        # Check if execution has metadata
        echo ""
        log_info "Checking for execution metadata..."
        local metadata_query="
SELECT
    key,
    value
FROM execution_metadata
WHERE \"executionId\" = $execution_id;
"
        local metadata_result
        metadata_result=$(execute_postgres_query "$metadata_query")

        if [[ -n "$metadata_result" ]] && [[ "$metadata_result" != *"(0 rows)"* ]]; then
            echo ""
            log_info "Execution metadata:"
            echo "$metadata_result"
        else
            log_debug "No metadata found for this execution"
        fi

        echo ""
        log_success "✓ Execution details retrieved successfully"
    else
        log_error "✗ Failed to retrieve execution details"
        log_error "$result"
        return 1
    fi

    return 0
}

# Get execution statistics summary
get_execution_stats() {
    log_info "Fetching execution statistics from PostgreSQL..."
    echo ""

    if ! is_postgres_running; then
        log_error "PostgreSQL container is not running"
        return 1
    fi

    local query="
SELECT
    COUNT(*) as total_executions,
    COUNT(CASE WHEN status = 'success' THEN 1 END) as successful,
    COUNT(CASE WHEN status = 'error' THEN 1 END) as failed,
    COUNT(CASE WHEN status = 'canceled' THEN 1 END) as canceled,
    COUNT(CASE WHEN status = 'waiting' THEN 1 END) as waiting,
    COUNT(DISTINCT \"workflowId\") as unique_workflows,
    ROUND(AVG(EXTRACT(EPOCH FROM (\"stoppedAt\" - \"startedAt\"))/60), 2) as avg_duration_mins,
    MAX(\"startedAt\") as latest_execution
FROM execution_entity
WHERE \"deletedAt\" IS NULL;
"

    local result
    result=$(execute_postgres_query "$query")
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
        echo ""
        log_success "✓ Execution statistics retrieved successfully"
    else
        log_error "✗ Failed to retrieve execution statistics"
        log_error "$result"
        return 1
    fi

    return 0
}

# Get executions by workflow name
get_executions_by_workflow() {
    local workflow_name="$1"
    local limit="${2:-10}"

    if [[ -z "$workflow_name" ]]; then
        log_error "Workflow name required"
        log_info "Usage: get_executions_by_workflow <workflow_name> [limit]"
        return 1
    fi

    log_info "Fetching last $limit executions for workflow: $workflow_name"
    echo ""

    if ! is_postgres_running; then
        log_error "PostgreSQL container is not running"
        return 1
    fi

    local query="
SELECT
    e.id,
    e.\"startedAt\" as started,
    e.\"stoppedAt\" as stopped,
    ROUND(EXTRACT(EPOCH FROM (e.\"stoppedAt\" - e.\"startedAt\"))/60, 1) as duration_mins,
    e.status,
    e.mode
FROM execution_entity e
LEFT JOIN workflow_entity w ON e.\"workflowId\" = w.id
WHERE e.\"deletedAt\" IS NULL
  AND w.name = '$workflow_name'
ORDER BY e.\"startedAt\" DESC
LIMIT $limit;
"

    local result
    result=$(execute_postgres_query "$query")
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
        echo ""
        log_success "✓ Workflow executions retrieved successfully"
    else
        log_error "✗ Failed to retrieve workflow executions"
        log_error "$result"
        return 1
    fi

    return 0
}

# Get failed executions
get_failed_executions() {
    local limit="${1:-10}"

    log_info "Fetching last $limit failed executions..."
    echo ""

    if ! is_postgres_running; then
        log_error "PostgreSQL container is not running"
        return 1
    fi

    local query="
SELECT
    e.id,
    w.name as workflow_name,
    e.\"startedAt\" as started,
    e.\"stoppedAt\" as stopped,
    ROUND(EXTRACT(EPOCH FROM (e.\"stoppedAt\" - e.\"startedAt\"))/60, 1) as duration_mins,
    e.status,
    e.mode
FROM execution_entity e
LEFT JOIN workflow_entity w ON e.\"workflowId\" = w.id
WHERE e.\"deletedAt\" IS NULL
  AND e.status IN ('error', 'canceled')
ORDER BY e.\"startedAt\" DESC
LIMIT $limit;
"

    local result
    result=$(execute_postgres_query "$query")
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
        echo ""
        log_success "✓ Failed executions retrieved successfully"
    else
        log_error "✗ Failed to retrieve failed executions"
        log_error "$result"
        return 1
    fi

    return 0
}
