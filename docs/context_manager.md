# Context/State Manager Integration Cookbook

## Purpose
Provides typical usage recipes, structural guides, and variable matrix for integrating context_manager API in GitHub Actions and runner workflows.

### Table of Contents
1. Context Layers and Matrix
2. Bash API Functions
3. Usage Patterns in Workflow YAML
4. State Checkpoint & Rollback
5. Best Practices
6. Security Considerations

---

## 1. Context Layers
| Layer      | Example Var         | Provider        | Namespace         | Visibility      | Persistence      | Description                      |
|------------|---------------------|-----------------|--------------------|-----------------|------------------|----------------------------------|
| App        | GITHUB_APP_ID       | User/App        | GITHUB_APP_*       | Secret/Public   | Permanent        | Authentication                   |
| Account    | github.actor        | GitHub/user     | GITHUB_USER_*      | Public          | Permanent        | CI initiator, audit              |
| Repo       | github.repository   | GitHub/api      | GITHUB_REPO_*      | Public          | Permanent        | Scope workflow, runners          |
| Commit     | github.sha          | VCS             | COMMIT_*           | Public          | Per run          | Versioning, trace                |
| Workflow   | github.run_id       | Actions Runtime | WORKFLOW_*         | Internal        | Workflow run     | Orchestration ID                 |
| Job        | job.status          | Actions Runtime | JOB_*              | Internal        | Run              | Pause/rollback, status           |
| Runner     | runner.name         | Actions Runtime | RUNNER_*           | Internal        | Session          | Capacity, dynamic                |
| Workspace  | github.workspace    | Actions Runtime | WORKSPACE_*        | Internal        | Run              | Workflow/job files               |

---

## 2. Bash API Summary
- `context_manager_get <layer> <var>` - Retrieve a context variable
- `context_manager_set <layer> <var> <value>` - Set a context variable
- `context_manager_export <layer> [nomask]` - Export all variables for a layer
- `context_manager_checkpoint <layer>` - Create a checkpoint of layer state
- `context_manager_rollback <layer>` - Restore state from checkpoint

---

## 3. Usage in Workflow YAML

### CLI Mode (Recommended)
```yaml
steps:
  - name: Snapshot context
    run: scripts/context_manager.sh export runner
    
  - name: Check busy status
    run: |
      if [[ $(scripts/context_manager.sh get runner busy) == "true" ]]; then 
        echo "Runner is busy"
        exit 1
      fi
      
  - name: Set status
    run: scripts/context_manager.sh set runner busy true
    
  - name: Persist checkpoint
    run: scripts/context_manager.sh checkpoint runner
    
  - name: Rollback on failure
    if: failure()
    run: scripts/context_manager.sh rollback runner
```

### Source Mode (For Multiple Operations)
```yaml
steps:
  - name: Complex context operations
    run: |
      source scripts/context_manager.sh
      
      # Multiple operations without re-sourcing
      context_manager_checkpoint runner
      context_manager_set runner status "processing"
      context_manager_set runner job_id "${{ github.run_id }}"
      context_manager_export runner
```

---

## 4. Checkpoint/Stateful Ops Pattern

### Basic Pattern
```yaml
- name: Create checkpoint before mutation
  run: scripts/context_manager.sh checkpoint runner

- name: Perform stateful operation
  id: operation
  run: |
    # Your stateful operation here
    scripts/context_manager.sh set runner busy true
    # ... more operations

- name: Rollback on error
  if: failure() && steps.operation.outcome == 'failure'
  run: scripts/context_manager.sh rollback runner
```

### Complete Workflow Example
```yaml
name: Runner Lifecycle with Context Management

on:
  workflow_dispatch:
    inputs:
      runner_name:
        description: 'Runner name'
        required: true

jobs:
  manage-runner:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Initialize runner context
        run: |
          scripts/context_manager.sh set runner name "${{ inputs.runner_name }}"
          scripts/context_manager.sh set runner status "initializing"
          scripts/context_manager.sh checkpoint runner
      
      - name: Configure runner
        id: configure
        run: |
          scripts/context_manager.sh set runner status "configuring"
          # Configuration steps...
          scripts/context_manager.sh checkpoint runner
      
      - name: Start runner
        id: start
        run: |
          scripts/context_manager.sh set runner status "running"
          # Start runner...
      
      - name: Rollback on failure
        if: failure()
        run: |
          echo "Operation failed, rolling back..."
          scripts/context_manager.sh rollback runner
          scripts/context_manager.sh export runner
```

---

## 5. Best Practices

### Namespacing
- Always use layer-specific prefixes for environment variables
- Follow documented namespace patterns (see table above)
- Avoid using generic `GITHUB_*` prefix for custom variables

### Logging and Audit
- Export context at the beginning and end of workflows
- Use masked exports for sensitive layers (app, account)
- Log checkpoint creation for audit trails
- Keep checkpoint files for post-mortem analysis

### Checkpoint Strategy
- Create checkpoints before any stateful mutation
- Use descriptive checkpoint locations (`CHECKPOINT_DIR`)
- Implement checkpoint cleanup for old files
- Test rollback procedures regularly

### Security
- Never use `nomask` option in production workflows
- Validate checkpoint files before rollback
- Use secure permissions (600) for checkpoint files
- Rotate sensitive credentials regularly
- Review checkpoint files for leaked secrets

### Error Handling
- Always check return codes from context_manager functions
- Implement proper rollback on failures
- Log errors to stderr for visibility
- Use `set -euo pipefail` in scripts for fail-fast behavior

---

## 6. Security Considerations

### Secret Masking
By default, the `export` command masks sensitive values:
```bash
# Masked by default
scripts/context_manager.sh export app
# Output: GITHUB_APP_TOKEN=***MASKED***

# Unmask only for debugging (use with caution)
scripts/context_manager.sh export app nomask
```

### Sensitive Patterns
The following patterns trigger automatic masking:
- `KEY` (e.g., PRIVATE_KEY, API_KEY)
- `SECRET` (e.g., CLIENT_SECRET)
- `TOKEN` (e.g., ACCESS_TOKEN)
- `PRIVATE` (e.g., PRIVATE_KEY_PATH)
- `PASSWORD` (e.g., DB_PASSWORD)
- `CREDENTIAL` (e.g., CREDENTIALS_JSON)

### Checkpoint File Security
Checkpoint files are automatically secured:
- Permissions: `600` (owner read/write only)
- Location: `.checkpoints/` directory (not tracked in git)
- Validation: Content checked before sourcing
- Ownership: Verified to match current user

### GitHub Actions Integration
When running in GitHub Actions (`GITHUB_ACTIONS=true`):
- Sensitive values automatically masked with `::add-mask::`
- Checkpoint directory defaults to workspace subdirectory
- Logs are sanitized to prevent credential exposure

---

## Migration Guide (Breaking Changes)

If you're upgrading from the original implementation, note these namespace changes:

| Old Namespace | New Namespace | Affected Layer |
|---------------|---------------|----------------|
| `GITHUB_*` (generic) | `GITHUB_USER_*` | Account |
| `GITHUB_*` (generic) | `COMMIT_*` | Commit |
| `GITHUB_*` (generic) | `WORKFLOW_*` | Workflow |
| `GITHUB_WORKSPACE` | `WORKSPACE_*` | Workspace |

### Migration Steps
1. Search your codebase for direct references to old namespaces
2. Update environment variable references
3. Update checkpoint files (recreate with new script)
4. Test rollback procedures with new namespaces

---

For implementation details and source code, see [`scripts/context_manager.sh`](../scripts/context_manager.sh).
