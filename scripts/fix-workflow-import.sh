#!/bin/bash

# Quick Fix Script for n8n Workflow Import Issues
# Run this on Raspberry Pi after diagnostics

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

N8N_CONTAINER="homelab-n8n"

log_info "=== N8N WORKFLOW IMPORT QUICK FIXES ==="
log_info ""

# Fix 1: Create missing project
log_info "Fix 1: Creating default project if missing..."
project_check=$(docker exec "$N8N_CONTAINER" n8n project:list 2>&1)
if [[ $? -ne 0 ]] || echo "$project_check" | grep -q "No projects found"; then
    log_info "Creating default project..."
    docker exec "$N8N_CONTAINER" n8n project:create --name "Default Project" --type personal
    if [[ $? -eq 0 ]]; then
        log_success "✓ Default project created"
    else
        log_error "✗ Failed to create default project"
    fi
else
    log_info "Projects already exist:"
    echo "$project_check" | while IFS= read -r line; do
        log_info "  $line"
    done
fi
log_info ""

# Fix 2: Import without project ID (use default project)
log_info "Fix 2: Importing workflows without project ID..."
./import-workflows-no-project.sh
log_info ""

# Fix 3: Force re-import with clean workflow data
log_info "Fix 3: Clean import with simplified workflow data..."
./import-workflows-clean.sh
log_info ""

# Fix 4: Manual workflow activation
log_info "Fix 4: Activating all imported workflows..."
workflow_ids=$(docker exec "$N8N_CONTAINER" n8n list:workflow --onlyId 2>/dev/null)
if [[ -n "$workflow_ids" ]]; then
    echo "$workflow_ids" | while IFS= read -r wf_id; do
        [[ -n "$wf_id" ]] && docker exec "$N8N_CONTAINER" n8n update:workflow "$wf_id" --active=true
    done
    log_success "✓ Workflow activation attempted"
else
    log_warning "No workflows found to activate"
fi
log_info ""

log_info "=== VERIFICATION ==="
final_count=$(docker exec "$N8N_CONTAINER" n8n list:workflow --onlyId 2>/dev/null | wc -l | xargs)
log_info "Total workflows after fixes: $final_count"
log_info ""
log_info "If workflows still don't appear in UI:"
log_info "1. Check browser console for JavaScript errors"
log_info "2. Clear browser cache and cookies for n8n"
log_info "3. Restart n8n container: docker restart homelab-n8n"
log_info "4. Check user permissions and project assignments"