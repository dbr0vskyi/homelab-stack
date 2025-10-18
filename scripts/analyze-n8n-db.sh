#!/bin/bash

# n8n Database Analysis Script
# Directly examines the database to understand workflow import issues

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

N8N_CONTAINER="homelab-n8n"
POSTGRES_CONTAINER="homelab-postgres"

log_info "=== N8N DATABASE ANALYSIS ==="
log_info ""

# Check if containers are running
if ! docker ps --format "table {{.Names}}" | grep -q "^${N8N_CONTAINER}$"; then
    log_error "n8n container is not running"
    exit 1
fi

if ! docker ps --format "table {{.Names}}" | grep -q "^${POSTGRES_CONTAINER}$"; then
    log_error "postgres container is not running"
    exit 1
fi

# Database connection test
log_info "=== DATABASE CONNECTION ==="
db_test=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "SELECT version();" 2>&1)
if [[ $? -eq 0 ]]; then
    log_success "✓ Database connection working"
    log_info "PostgreSQL version: $(echo "$db_test" | grep PostgreSQL | head -1 | xargs)"
else
    log_error "✗ Database connection failed: $db_test"
    exit 1
fi
log_info ""

# Database schema analysis
log_info "=== DATABASE SCHEMA ==="
log_info "n8n-related tables:"
docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
    SELECT 
        table_name,
        (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count
    FROM information_schema.tables t 
    WHERE table_schema = 'public' 
    ORDER BY table_name;
" -t | while IFS= read -r line; do
    [[ -n "$line" && "$line" != *"("*"row"* ]] && log_info "  $line"
done
log_info ""

# Workflow table analysis
log_info "=== WORKFLOW TABLE ANALYSIS ==="
workflow_count=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "SELECT COUNT(*) FROM workflow_entity;" -t 2>/dev/null | xargs)
if [[ -n "$workflow_count" ]]; then
    log_info "Total workflows in database: $workflow_count"
    
    if [[ $workflow_count -gt 0 ]]; then
        log_info "Workflow details:"
        # Check if projectId column exists (newer n8n versions)
        has_project_col=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
            SELECT COUNT(*) 
            FROM information_schema.columns 
            WHERE table_name = 'workflow_entity' AND column_name = 'projectId';
        " -t 2>/dev/null | xargs)
        
        if [[ "$has_project_col" == "1" ]]; then
            docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
                SELECT 
                    id,
                    name,
                    active,
                    \"createdAt\",
                    \"updatedAt\",
                    CASE WHEN \"projectId\" IS NOT NULL THEN \"projectId\" ELSE 'default' END as project
                FROM workflow_entity 
                ORDER BY \"createdAt\" DESC 
                LIMIT 10;
            " -x | while IFS= read -r line; do
                [[ -n "$line" ]] && log_info "  $line"
            done
        else
            # Fallback for older n8n versions without projectId
            docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
                SELECT 
                    id,
                    name,
                    active,
                    \"createdAt\",
                    \"updatedAt\"
                FROM workflow_entity 
                ORDER BY \"createdAt\" DESC 
                LIMIT 10;
            " -x | while IFS= read -r line; do
                [[ -n "$line" ]] && log_info "  $line"
            done
        fi
        
        # Check for active workflows
        active_count=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "SELECT COUNT(*) FROM workflow_entity WHERE active = true;" -t 2>/dev/null | xargs)
        log_info "Active workflows: $active_count"
        
        # Check project distribution
        log_info "Workflows by project:"
        if [[ "$has_project_col" == "1" ]]; then
            docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
                SELECT 
                    COALESCE(\"projectId\", 'default') as project_id,
                    COUNT(*) as workflow_count
                FROM workflow_entity 
                GROUP BY \"projectId\"
                ORDER BY workflow_count DESC;
            " -t | while IFS= read -r line; do
                [[ -n "$line" && "$line" != *"("*"row"* ]] && log_info "  $line"
            done
        else
            log_info "  All workflows in default project (no projectId column)"
        fi
    fi
else
    log_warning "Could not retrieve workflow count (table may not exist)"
fi
log_info ""

# Project analysis
log_info "=== PROJECT ANALYSIS ==="
project_count=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "SELECT COUNT(*) FROM project;" -t 2>/dev/null | xargs)
if [[ -n "$project_count" ]]; then
    log_info "Total projects in database: $project_count"
    
    if [[ $project_count -gt 0 ]]; then
        log_info "Project details:"
        docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
            SELECT 
                id,
                name,
                type,
                \"createdAt\",
                \"updatedAt\"
            FROM project 
            ORDER BY \"createdAt\" DESC;
        " -x | while IFS= read -r line; do
            [[ -n "$line" ]] && log_info "  $line"
        done
    fi
else
    log_warning "Could not retrieve project count (table may not exist)"
fi
log_info ""

# User analysis
log_info "=== USER ANALYSIS ==="
user_count=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "SELECT COUNT(*) FROM \"user\";" -t 2>/dev/null | xargs)
if [[ -n "$user_count" ]]; then
    log_info "Total users in database: $user_count"
    
    if [[ $user_count -gt 0 ]]; then
        log_info "User details:"
        # Check if globalRole column exists (schema evolution)
        has_global_role=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
            SELECT COUNT(*) 
            FROM information_schema.columns 
            WHERE table_name = 'user' AND column_name = 'globalRole';
        " -t 2>/dev/null | xargs)
        
        if [[ "$has_global_role" == "1" ]]; then
            docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
                SELECT 
                    id,
                    email,
                    \"firstName\",
                    \"lastName\",
                    \"globalRole\",
                    \"createdAt\"
                FROM \"user\" 
                ORDER BY \"createdAt\" DESC;
            " -x | while IFS= read -r line; do
                [[ -n "$line" ]] && log_info "  $line"
            done
        else
            docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
                SELECT 
                    id,
                    email,
                    \"firstName\",
                    \"lastName\",
                    \"createdAt\"
                FROM \"user\" 
                ORDER BY \"createdAt\" DESC;
            " -x | while IFS= read -r line; do
                [[ -n "$line" ]] && log_info "  $line"
            done
        fi
    fi
else
    log_warning "Could not retrieve user count (table may not exist)"
fi
log_info ""

# Execution analysis
log_info "=== EXECUTION ANALYSIS ==="
execution_count=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "SELECT COUNT(*) FROM execution_entity;" -t 2>/dev/null | xargs)
if [[ -n "$execution_count" ]]; then
    log_info "Total executions in database: $execution_count"
    
    if [[ $execution_count -gt 0 ]]; then
        log_info "Recent executions:"
        docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
            SELECT 
                id,
                \"workflowId\",
                mode,
                \"startedAt\",
                \"stoppedAt\",
                finished
            FROM execution_entity 
            ORDER BY \"startedAt\" DESC 
            LIMIT 5;
        " -t | while IFS= read -r line; do
            [[ -n "$line" && "$line" != *"("*"row"* ]] && log_info "  $line"
        done
    fi
else
    log_info "No execution table found (normal for fresh installation)"
fi
log_info ""

# Settings analysis
log_info "=== SETTINGS ANALYSIS ==="
settings_count=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "SELECT COUNT(*) FROM settings;" -t 2>/dev/null | xargs)
if [[ -n "$settings_count" && $settings_count -gt 0 ]]; then
    log_info "n8n settings:"
    docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
        SELECT 
            key,
            CASE 
                WHEN key LIKE '%password%' OR key LIKE '%secret%' OR key LIKE '%key%' 
                THEN '***MASKED***'
                ELSE value 
            END as value,
            \"loadOnStartup\"
        FROM settings 
        ORDER BY key;
    " -t | while IFS= read -r line; do
        [[ -n "$line" && "$line" != *"("*"row"* ]] && log_info "  $line"
    done
else
    log_info "No settings found"
fi
log_info ""

# Database integrity check
log_info "=== DATABASE INTEGRITY ==="
log_info "Checking for orphaned workflows..."

# Check if projectId column exists before checking for orphaned workflows
has_project_col=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
    SELECT COUNT(*) 
    FROM information_schema.columns 
    WHERE table_name = 'workflow_entity' AND column_name = 'projectId';
" -t 2>/dev/null | xargs)

if [[ "$has_project_col" == "1" ]]; then
    orphaned=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
        SELECT COUNT(*) 
        FROM workflow_entity w 
        WHERE w.\"projectId\" IS NOT NULL 
        AND NOT EXISTS (SELECT 1 FROM project p WHERE p.id = w.\"projectId\");
    " -t 2>/dev/null | xargs)
else
    orphaned="0 (no projectId column)"
fi

if [[ -n "$orphaned" ]]; then
    log_info "Orphaned workflows (referencing non-existent projects): $orphaned"
    if [[ "$has_project_col" == "1" && $orphaned -gt 0 ]]; then
        log_warning "⚠  Found workflows with invalid project references"
    fi
else
    log_info "Could not check for orphaned workflows"
fi

# Check for workflow name conflicts
log_info "Checking for workflow name conflicts..."
conflicts=$(docker exec "$POSTGRES_CONTAINER" psql -U n8n -d n8n -c "
    SELECT name, COUNT(*) as count 
    FROM workflow_entity 
    GROUP BY name 
    HAVING COUNT(*) > 1 
    ORDER BY count DESC;
" -t 2>/dev/null)

if [[ -n "$conflicts" ]]; then
    conflict_count=$(echo "$conflicts" | grep -v "^$" | wc -l | xargs)
    if [[ $conflict_count -gt 0 ]]; then
        log_warning "⚠  Found $conflict_count workflow names with duplicates:"
        echo "$conflicts" | while IFS= read -r line; do
            [[ -n "$line" && "$line" != *"("*"row"* ]] && log_warning "    $line"
        done
    else
        log_info "No workflow name conflicts found"
    fi
else
    log_info "Could not check for name conflicts"
fi
log_info ""

log_success "=== DATABASE ANALYSIS COMPLETE ==="
log_info ""
log_info "KEY FINDINGS:"
log_info "- Workflows in DB: ${workflow_count:-"unknown"}"
log_info "- Projects in DB: ${project_count:-"unknown"}"
log_info "- Users in DB: ${user_count:-"unknown"}"
log_info "- Active workflows: ${active_count:-"unknown"}"
log_info "- Orphaned workflows: ${orphaned:-"unknown"}"
log_info ""
log_info "If workflows are imported but not visible:"
log_info "1. Check if they're assigned to the correct project"
log_info "2. Verify user permissions for the project"
log_info "3. Check if workflows are set to active=false"
log_info "4. Look for project ID mismatches"