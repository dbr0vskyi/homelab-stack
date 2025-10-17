# N8N Workflows Setup and Troubleshooting Guide

## Overview

This homelab-stack includes n8n for workflow automation. The project provides automated import/export functionality for workflows to maintain them as code alongside your infrastructure.

## Workflow Structure

Workflows are stored as JSON files in the `/workflows` directory:

- Each workflow file represents one n8n workflow
- Files are automatically imported when needed
- Files are exported from n8n for backup and version control

## Understanding N8N Projects

**Important:** N8N organizes workflows by **projects**. Each workflow belongs to exactly one project:

- **Personal Project**: Default project created for each user
- **Custom Projects**: Additional projects can be created for organization
- **Project-Specific Storage**: Workflows in different projects are isolated

This is why `export:workflow --all` might return "No workflows found" - it's looking in a different project than where your workflows exist.

## Commands Reference

### List N8N Projects

```bash
./scripts/manage.sh list-projects
```

This shows all projects with their IDs and names. You need the project ID to work with specific workflows.

**Output example:**

```json
[
  {
    "id": "PTDcIHwvy2eBoTf7",
    "name": "Unnamed Project",
    "type": "personal",
    ...
  }
]
```

### Test Workflow Sync

```bash
./scripts/manage.sh test-workflows
```

This comprehensive diagnostic shows:

- n8n CLI availability
- Database connectivity
- All projects and their workflow counts
- Local workflow files

**Use this first if exports/imports aren't working.**

### Export Workflows from N8N

```bash
./scripts/manage.sh export-workflows
```

This command:

1. Connects to n8n
2. Finds all projects
3. Exports workflows from each project
4. Saves them as JSON files in `/workflows` directory
5. Cleans up unnecessary metadata

**Troubleshooting:**

- If you see "No workflows found", run `test-workflows` to diagnose
- Check that workflows exist in n8n UI
- Verify project IDs are accessible

### Import Workflows to N8N

```bash
./scripts/manage.sh import-workflows
```

This command:

1. Reads all JSON files from `/workflows` directory
2. Validates them
3. Detects project ID from:
   - `.env` file (`N8N_PROJECT_ID`)
   - Workflow file metadata
   - N8N database (first available project)
4. Imports them into the detected project

**Requirements:**

- At least one workflow file in `/workflows`
- N8N container running
- Database initialized

## Common Issues and Solutions

### Issue: "No workflows found with specified filters"

**Cause:** The export command is looking in the wrong project.

**Solution:**

1. Run `./scripts/manage.sh list-projects` to see all projects
2. Verify your workflows exist in n8n UI
3. Check if workflows are in a different project
4. Run `./scripts/manage.sh test-workflows` for detailed diagnostics

### Issue: Workflows Imported Successfully But Don't Appear in UI

**Cause:** Workflows may have been imported to a different project than the one you're viewing.

**Solution:**

1. Check all projects in n8n (top-left project selector)
2. Switch between projects to find your workflows
3. Set `N8N_PROJECT_ID` in `.env` to ensure imports go to the right project

### Issue: Export Returns Empty Result

**Cause:** Could be any of:

- Workflows don't exist yet in n8n
- Database hasn't initialized properly
- Workflows are in a project with access issues
- CLI permission problems

**Solution:**

1. First run: `./scripts/manage.sh test-workflows`
2. Check n8n logs: `./scripts/manage.sh logs n8n`
3. Verify database health: `./scripts/manage.sh health`
4. Check that n8n UI shows your workflows

### Issue: Import Fails with Database Errors

**Cause:**

- N8N database not ready
- PostgreSQL not initialized
- Connectivity issues

**Solution:**

1. Check services: `./scripts/manage.sh status`
2. View logs: `./scripts/manage.sh logs n8n`
3. Verify health: `./scripts/manage.sh health`
4. Restart if needed: `./scripts/manage.sh restart`

## Environment Configuration

Add to your `.env` file:

```bash
# Optional: Specify project ID for imports
N8N_PROJECT_ID=your_project_id_here

# Standard n8n config
N8N_USER=admin
N8N_PASSWORD=your_secure_password
N8N_HOST=your-host.example.com
N8N_ENCRYPTION_KEY=your_encryption_key
```

To get your project ID:

```bash
./scripts/manage.sh list-projects
```

## Workflow File Locations

```
homelab-stack/
├── workflows/                 # Workflow files
│   ├── gmail-to-telegram.json
│   └── telegram-to-notion.json
├── config/
│   └── postgres/
│       └── init.sql          # Database initialization
└── scripts/
    ├── manage.sh             # Main management script
    └── lib/
        └── workflows.sh      # Workflow automation functions
```

## Manual N8N CLI Commands

If you need to run n8n commands directly:

```bash
# Export all workflows from a specific project
docker exec -u node homelab-n8n n8n export:workflow --all --project=PROJECT_ID --output=/tmp/exports

# List all projects
docker exec -u node homelab-n8n n8n list:project --output=json

# List workflows in a project
docker exec -u node homelab-n8n n8n list:workflow --project=PROJECT_ID
```

## Best Practices

1. **Regular Exports**: Export workflows regularly to keep them backed up in version control

   ```bash
   ./scripts/manage.sh export-workflows
   git add workflows/
   git commit -m "Update workflows export"
   ```

2. **Set Project ID**: Configure `N8N_PROJECT_ID` in `.env` for consistent imports

   ```bash
   ./scripts/manage.sh list-projects
   # Copy your desired project ID
   echo "N8N_PROJECT_ID=your_id" >> .env
   ```

3. **Test After Changes**: Verify workflow sync is working

   ```bash
   ./scripts/manage.sh test-workflows
   ```

4. **Monitor During Startup**: Watch logs during initial setup
   ```bash
   ./scripts/manage.sh logs n8n
   ```

## Workflow Schema Reference

Exported workflow files follow this structure:

```json
{
  "name": "workflow-name",
  "active": false,
  "nodes": [...],
  "connections": {...},
  "settings": {...},
  "shared": [
    {
      "role": "workflow:owner",
      "projectId": "PROJECT_ID"
    }
  ]
}
```

Key fields:

- **name**: Workflow name in n8n
- **active**: Whether workflow runs automatically
- **nodes**: Workflow nodes/steps
- **connections**: Links between nodes
- **shared**: Project ownership info

## Additional Resources

- [n8n Documentation](https://docs.n8n.io/)
- [n8n CLI Reference](https://docs.n8n.io/reference/cli/)
- [N8N Projects Feature](https://docs.n8n.io/hosting/features/projects/)
