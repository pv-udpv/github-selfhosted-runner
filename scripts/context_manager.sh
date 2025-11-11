#!/bin/bash
set -euo pipefail

#
# Context/State Manager for Self-Hosted Runner App
#
# This module implements standardized context and state management for all
# GitHub Actions and runner lifecycle operations, enabling audit, rollback,
# and traceability.
#
# Context Layers:
#   - App: GitHub App authentication (GITHUB_APP_*)
#   - Account: CI user/actor (GITHUB_USER_*)
#   - Repository: Repo scope (GITHUB_REPO_*)
#   - Commit: VCS commit info (COMMIT_*)
#   - Workflow: Workflow run (WORKFLOW_*)
#   - Job: Job execution (JOB_*)
#   - Runner: Runner instance (RUNNER_*)
#   - Workspace: Workspace files (WORKSPACE_*)
#
# Usage:
#   CLI mode:    scripts/context_manager.sh get runner name
#   Source mode: source scripts/context_manager.sh && context_manager_get runner name
#

# Configuration
CHECKPOINT_DIR="${CHECKPOINT_DIR:-${GITHUB_WORKSPACE:-.}/.checkpoints}"
SENSITIVE_PATTERNS="KEY|SECRET|TOKEN|PRIVATE|PASSWORD|CREDENTIAL"

# Valid layer names
VALID_LAYERS=("app" "account" "repo" "commit" "workflow" "job" "runner" "workspace")

#
# context_manager_get - Retrieve a context variable
#
# Arguments:
#   $1 - layer: Context layer name
#   $2 - var: Variable name
#
# Returns:
#   Variable value or empty string
#
# Example:
#   value=$(context_manager_get runner name)
#
context_manager_get() {
  local layer="${1:-}"
  local var="${2:-}"
  
  # Validate required parameters
  if [[ -z "${layer:-}" ]]; then
    echo "Error: layer parameter is required" >&2
    echo "Usage: context_manager_get <layer> <var>" >&2
    return 1
  fi
  
  if [[ -z "${var:-}" ]]; then
    echo "Error: var parameter is required" >&2
    echo "Usage: context_manager_get <layer> <var>" >&2
    return 1
  fi
  
  # Validate layer is in allowed list
  if [[ ! " ${VALID_LAYERS[*]} " =~ " ${layer} " ]]; then
    echo "Error: invalid layer '${layer}'. Valid: ${VALID_LAYERS[*]}" >&2
    return 1
  fi
  
  # Sanitize variable name (alphanumeric + underscore only)
  if [[ ! "$var" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "Error: invalid variable name '${var}'. Use alphanumeric and underscore only" >&2
    return 1
  fi
  
  # Build variable name based on layer namespace
  local varname
  case "$layer" in
    app)      varname="GITHUB_APP_${var^^}";;
    account)  varname="GITHUB_USER_${var^^}";;
    repo)     varname="GITHUB_REPO_${var^^}";;
    commit)   varname="COMMIT_${var^^}";;
    workflow) varname="WORKFLOW_${var^^}";;
    job)      varname="JOB_${var^^}";;
    runner)   varname="RUNNER_${var^^}";;
    workspace)
      # Special case: if no var specified, return workspace path
      if [[ "$var" == "path" ]] || [[ "$var" == "PATH" ]]; then
        echo "${GITHUB_WORKSPACE:-}"
        return
      fi
      varname="WORKSPACE_${var^^}"
      ;;
    *)
      echo ""
      return 1
      ;;
  esac
  
  # Use indirect expansion to get value
  echo "${!varname:-}"
}

#
# context_manager_set - Set a context variable
#
# Arguments:
#   $1 - layer: Context layer name
#   $2 - var: Variable name
#   $3 - value: Variable value
#
# Example:
#   context_manager_set runner busy true
#
context_manager_set() {
  local layer="${1:-}"
  local var="${2:-}"
  local value="${3:-}"
  
  # Validate required parameters
  if [[ -z "${layer:-}" ]]; then
    echo "Error: layer parameter is required" >&2
    echo "Usage: context_manager_set <layer> <var> <value>" >&2
    return 1
  fi
  
  if [[ -z "${var:-}" ]]; then
    echo "Error: var parameter is required" >&2
    echo "Usage: context_manager_set <layer> <var> <value>" >&2
    return 1
  fi
  
  # Validate layer
  if [[ ! " ${VALID_LAYERS[*]} " =~ " ${layer} " ]]; then
    echo "Error: invalid layer '${layer}'. Valid: ${VALID_LAYERS[*]}" >&2
    return 1
  fi
  
  # Sanitize variable name
  if [[ ! "$var" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "Error: invalid variable name '${var}'. Use alphanumeric and underscore only" >&2
    return 1
  fi
  
  # Build and export variable
  local varname
  case "$layer" in
    app)      varname="GITHUB_APP_${var^^}";;
    account)  varname="GITHUB_USER_${var^^}";;
    repo)     varname="GITHUB_REPO_${var^^}";;
    commit)   varname="COMMIT_${var^^}";;
    workflow) varname="WORKFLOW_${var^^}";;
    job)      varname="JOB_${var^^}";;
    runner)   varname="RUNNER_${var^^}";;
    workspace) varname="WORKSPACE_${var^^}";;
    *) return 1;;
  esac
  
  # Export variable
  export "${varname}=${value}"
  
  # Mask in GitHub Actions if sensitive
  if [[ -n "${GITHUB_ACTIONS:-}" ]] && [[ "$varname" =~ $SENSITIVE_PATTERNS ]]; then
    echo "::add-mask::${value}"
  fi
}

#
# context_manager_export - Export all variables for a layer
#
# Arguments:
#   $1 - layer: Context layer name
#   $2 - mask: Optional, set to "nomask" to disable masking (use with caution)
#
# Example:
#   context_manager_export runner
#   context_manager_export app nomask  # For debugging only
#
context_manager_export() {
  local layer="${1:-}"
  local mask="${2:-mask}"
  
  # Validate layer
  if [[ -z "${layer:-}" ]]; then
    echo "Error: layer parameter is required" >&2
    echo "Usage: context_manager_export <layer> [nomask]" >&2
    return 1
  fi
  
  if [[ ! " ${VALID_LAYERS[*]} " =~ " ${layer} " ]]; then
    echo "Error: invalid layer '${layer}'. Valid: ${VALID_LAYERS[*]}" >&2
    return 1
  fi
  
  # Determine namespace prefix
  local prefix
  case "$layer" in
    app)      prefix="GITHUB_APP_";;
    account)  prefix="GITHUB_USER_";;
    repo)     prefix="GITHUB_REPO_";;
    commit)   prefix="COMMIT_";;
    workflow) prefix="WORKFLOW_";;
    job)      prefix="JOB_";;
    runner)   prefix="RUNNER_";;
    workspace) prefix="WORKSPACE_";;
    *) return 1;;
  esac
  
  # Warn if exporting potentially sensitive layer
  if [[ "${layer^^}" =~ ^(APP|ACCOUNT|REPO|RUNNER)$ ]] && [[ "$mask" != "nomask" ]]; then
    echo "[context_manager] Exporting layer '${layer}' - sensitive values will be masked" >&2
  fi
  
  # Export variables, masking sensitive ones
  if [[ "$mask" == "nomask" ]]; then
    # No masking (use with extreme caution)
    env | grep "^${prefix}" || true
  else
    # Mask sensitive values
    env | grep "^${prefix}" || true | \
      awk -v pat="$SENSITIVE_PATTERNS" '
        BEGIN { IGNORECASE=1 }
        $0 ~ pat { 
          split($0, a, "="); 
          print a[1]"=***MASKED***"; 
          next 
        }
        { print }
      '
  fi
}

#
# context_manager_checkpoint - Create a checkpoint of layer state
#
# Arguments:
#   $1 - layer: Context layer name
#
# Example:
#   context_manager_checkpoint runner
#
context_manager_checkpoint() {
  local layer="${1:-}"
  
  # Validate layer
  if [[ -z "${layer:-}" ]]; then
    echo "Error: layer parameter is required" >&2
    echo "Usage: context_manager_checkpoint <layer>" >&2
    return 1
  fi
  
  if [[ ! " ${VALID_LAYERS[*]} " =~ " ${layer} " ]]; then
    echo "Error: invalid layer '${layer}'. Valid: ${VALID_LAYERS[*]}" >&2
    return 1
  fi
  
  # Create checkpoint directory
  mkdir -p "$CHECKPOINT_DIR" || {
    echo "Error: Cannot create checkpoint directory: $CHECKPOINT_DIR" >&2
    return 1
  }
  
  local file="${CHECKPOINT_DIR}/checkpoint_${layer}.env"
  
  # Export to temp file first
  local temp_file
  temp_file=$(mktemp) || {
    echo "Error: Cannot create temp file" >&2
    return 1
  }
  
  # Write with error checking (export without masking for checkpoints)
  if ! context_manager_export "$layer" nomask > "$temp_file"; then
    rm -f "$temp_file"
    echo "Error: Failed to export context" >&2
    return 1
  fi
  
  # Set secure permissions (600)
  chmod 600 "$temp_file" || {
    rm -f "$temp_file"
    echo "Error: Cannot set file permissions" >&2
    return 1
  }
  
  # Move to final location atomically
  if ! mv "$temp_file" "$file"; then
    rm -f "$temp_file"
    echo "Error: Failed to create checkpoint" >&2
    return 1
  fi
  
  echo "[context_manager] Checkpoint created: $file" >&2
}

#
# context_manager_rollback - Restore state from checkpoint
#
# Arguments:
#   $1 - layer: Context layer name
#
# Example:
#   context_manager_rollback runner
#
context_manager_rollback() {
  local layer="${1:-}"
  
  # Validate layer
  if [[ -z "${layer:-}" ]]; then
    echo "Error: layer parameter is required" >&2
    echo "Usage: context_manager_rollback <layer>" >&2
    return 1
  fi
  
  if [[ ! " ${VALID_LAYERS[*]} " =~ " ${layer} " ]]; then
    echo "Error: invalid layer '${layer}'. Valid: ${VALID_LAYERS[*]}" >&2
    return 1
  fi
  
  local file="${CHECKPOINT_DIR}/checkpoint_${layer}.env"
  
  # Validate file exists and is readable
  if [[ ! -f "$file" ]]; then
    echo "Error: Checkpoint file not found: $file" >&2
    return 1
  fi
  
  if [[ ! -r "$file" ]]; then
    echo "Error: Cannot read checkpoint file: $file" >&2
    return 1
  fi
  
  # Check file permissions (should be 600)
  local perms
  if [[ "$(uname)" == "Darwin" ]]; then
    perms=$(stat -f '%A' "$file" 2>/dev/null || echo "unknown")
  else
    perms=$(stat -c '%a' "$file" 2>/dev/null || echo "unknown")
  fi
  
  if [[ "$perms" != "600" ]] && [[ "$perms" != "unknown" ]]; then
    echo "[context_manager] Warning: Checkpoint file has insecure permissions: $perms" >&2
  fi
  
  # Validate file ownership (if USER is set)
  if [[ -n "${USER:-}" ]]; then
    local owner
    if [[ "$(uname)" == "Darwin" ]]; then
      owner=$(stat -f '%Su' "$file" 2>/dev/null || echo "unknown")
    else
      owner=$(stat -c '%U' "$file" 2>/dev/null || echo "unknown")
    fi
    
    if [[ "$owner" != "$USER" ]] && [[ "$owner" != "unknown" ]]; then
      echo "Error: Checkpoint file owned by different user: $owner" >&2
      return 1
    fi
  fi
  
  # Validate content (only ENV_VAR=value lines, no blank lines)
  if ! grep -q '=' "$file"; then
    echo "Error: Checkpoint file appears to be empty or invalid" >&2
    return 1
  fi
  
  # Check for suspicious patterns (shell metacharacters)
  if grep -qE '(;|\||`|\$\(|<\(|>\(|\{|\})' "$file"; then
    echo "Error: Checkpoint file contains suspicious shell metacharacters" >&2
    return 1
  fi
  
  # Validate each line matches ENV_VAR=value pattern
  while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue
    
    # Check format
    if [[ ! "$line" =~ ^[A-Z_][A-Z0-9_]*=.*$ ]]; then
      echo "Error: Invalid line in checkpoint file: $line" >&2
      return 1
    fi
  done < "$file"
  
  # Source safely
  set -a
  # shellcheck disable=SC1090
  if ! source "$file"; then
    set +a
    echo "Error: Failed to source checkpoint file" >&2
    return 1
  fi
  set +a
  
  echo "[context_manager] Rollback successful from: $file" >&2
}

#
# CLI Dispatcher - allows script to be called directly
#
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Script is being executed, not sourced
  if [[ $# -lt 1 ]]; then
    cat >&2 << 'EOF'
Usage: context_manager.sh <command> [args...]

Commands:
  get <layer> <var>          Get a context variable
  set <layer> <var> <value>  Set a context variable
  export <layer> [nomask]    Export all variables for a layer
  checkpoint <layer>         Create a checkpoint of layer state
  rollback <layer>           Restore state from checkpoint

Layers:
  app, account, repo, commit, workflow, job, runner, workspace

Examples:
  context_manager.sh get runner name
  context_manager.sh set runner busy true
  context_manager.sh export runner
  context_manager.sh checkpoint runner
  context_manager.sh rollback runner
EOF
    exit 1
  fi
  
  command="$1"
  shift
  
  case "$command" in
    get)
      context_manager_get "$@"
      ;;
    set)
      context_manager_set "$@"
      ;;
    export)
      context_manager_export "$@"
      ;;
    checkpoint)
      context_manager_checkpoint "$@"
      ;;
    rollback)
      context_manager_rollback "$@"
      ;;
    help|--help|-h)
      "$0" # Show usage
      ;;
    *)
      echo "Error: Unknown command '$command'" >&2
      echo "Run '$0 help' for usage" >&2
      exit 1
      ;;
  esac
fi
