# Context/State Manager for Self-Hosted Runner App

This module implements standardized context and state management for all GitHub Actions and runner lifecycle operations, enabling audit, rollback, and traceability.

## Context Layers:
- App
- Account/User
- Repository
- Commit
- Workflow Run
- Job
- Runner
- Workspace

## Usage (Bash Helper):

```bash
context_manager_get() {
  # Arguments: layer, variable
  # Example: context_manager_get runner busy
  local layer="$1"
  local var="$2"
  case "$layer" in
    app) echo "${GITHUB_APP_${var^^}}";;
    account) echo "${GITHUB_${var^^}}";;
    repo) echo "${GITHUB_REPO_${var^^}}";;
    commit) echo "${GITHUB_${var^^}}";;
    workflow) echo "${GITHUB_${var^^}}";;
    job) echo "${JOB_${var^^}}";;
    runner) echo "${RUNNER_${var^^}}";;
    workspace) echo "${GITHUB_WORKSPACE}";;
    *) echo "";;
  esac
}

context_manager_set() {
  # Example: context_manager_set runner busy false
  local layer="$1"; local var="$2"; local value="$3"
  export "${layer^^}_${var^^}=$value"
}

context_manager_export() {
  # Export env for layer
  local layer="$1"
  env | grep "^${layer^^}_"
}

context_manager_checkpoint() {
  # Simple checkpoint
  local layer="$1"; local file="checkpoint_$layer.env"
  context_manager_export "$layer" > "$file"
}

context_manager_rollback() {
  local layer="$1"; local file="checkpoint_$layer.env"
  if [[ -f "$file" ]]; then
    set -a
    source "$file"
    set +a
  fi
}
```

## Integration Example

Add as step in workflow jobs:
```yaml
steps:
  - name: Export runner context
    run: context_manager_export runner
  - name: Check busy
    run: |
      if [[ $(context_manager_get runner busy) == true ]]; then exit 1; fi
  - name: Persist checkpoint
    run: context_manager_checkpoint runner
  - name: Rollback on fail
    if: failure()
    run: context_manager_rollback runner
```

## Best Practices
- Always create checkpoint before stateful mutation
- Export context at the beginning and end of workflow
- Rollback to checkpoint on failure
- Use namespacing in env for all CI/CD vars

---

For full context variable matrix and state diagram see docs/context_manager.md.
