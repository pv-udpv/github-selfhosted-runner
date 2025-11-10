#!/bin/bash
set -euo pipefail

# =============================================================================
# GitHub Self-Hosted Runner Entrypoint
# Supports GitHub App authentication and classic PAT
# =============================================================================

LOG_PREFIX="[RUNNER]"
log() { echo "${LOG_PREFIX} $*"; }
error() { echo "${LOG_PREFIX} ERROR: $*" >&2; }

# =============================================================================
# Configuration Validation
# =============================================================================

if [ -z "${REPO_URL:-}" ]; then
    error "REPO_URL environment variable is required"
    exit 1
fi

RUNNER_NAME=${RUNNER_NAME:-docker-runner-$(hostname)}
LABELS=${LABELS:-self-hosted,linux,x64,docker}
RUNNER_WORKDIR="${RUNNER_WORKDIR:-/home/runner/actions-runner/_work}"

log "Configuration:"
log "  Repository: ${REPO_URL}"
log "  Runner Name: ${RUNNER_NAME}"
log "  Labels: ${LABELS}"
log "  Work Directory: ${RUNNER_WORKDIR}"

# =============================================================================
# GitHub App JWT Token Generation
# =============================================================================

generate_jwt() {
    local app_id="$1"
    local private_key_path="$2"
    
    if [ ! -f "${private_key_path}" ]; then
        error "Private key file not found: ${private_key_path}"
        return 1
    fi
    
    local now=$(date +%s)
    local iat=$((now - 60))
    local exp=$((now + 600))
    
    local header='{"alg":"RS256","typ":"JWT"}'
    local payload="{\"iat\":${iat},\"exp\":${exp},\"iss\":\"${app_id}\"}"
    
    local b64_header=$(echo -n "${header}" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
    local b64_payload=$(echo -n "${payload}" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
    
    local signature=$(echo -n "${b64_header}.${b64_payload}" | \
        openssl dgst -sha256 -sign "${private_key_path}" | \
        openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
    
    echo "${b64_header}.${b64_payload}.${signature}"
}

# =============================================================================
# Get Registration Token
# =============================================================================

get_registration_token() {
    local token=""
    
    # Method 1: GitHub App
    if [ -n "${GITHUB_APP_ID:-}" ] && [ -n "${GITHUB_APP_INSTALLATION_ID:-}" ] && [ -n "${GITHUB_APP_PRIVATE_KEY_PATH:-}" ]; then
        log "Using GitHub App authentication"
        
        local jwt
        jwt=$(generate_jwt "${GITHUB_APP_ID}" "${GITHUB_APP_PRIVATE_KEY_PATH}")
        
        if [ -z "${jwt}" ]; then
            error "Failed to generate JWT token"
            return 1
        fi
        
        local installation_token
        installation_token=$(curl -sS -X POST \
            -H "Authorization: Bearer ${jwt}" \
            -H "Accept: application/vnd.github+json" \
            "https://api.github.com/app/installations/${GITHUB_APP_INSTALLATION_ID}/access_tokens" | \
            jq -r '.token')
        
        if [ -z "${installation_token}" ] || [ "${installation_token}" = "null" ]; then
            error "Failed to get installation access token"
            return 1
        fi
        
        token="${installation_token}"
        
    # Method 2: Personal Access Token
    elif [ -n "${GITHUB_PAT:-}" ]; then
        log "Using Personal Access Token authentication"
        token="${GITHUB_PAT}"
        
    else
        error "No authentication method configured"
        error "Set either:"
        error "  - GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID, GITHUB_APP_PRIVATE_KEY_PATH"
        error "  - GITHUB_PAT"
        return 1
    fi
    
    # Extract owner and repo from URL
    local repo_path=$(echo "${REPO_URL}" | sed 's|https://github.com/||')
    
    # Get registration token
    local reg_token
    reg_token=$(curl -sS -X POST \
        -H "Authorization: token ${token}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${repo_path}/actions/runners/registration-token" | \
        jq -r '.token')
    
    if [ -z "${reg_token}" ] || [ "${reg_token}" = "null" ]; then
        error "Failed to get runner registration token"
        return 1
    fi
    
    echo "${reg_token}"
}

# =============================================================================
# Cleanup on Exit
# =============================================================================

cleanup() {
    log "Received shutdown signal, removing runner..."
    
    if [ -f "/home/runner/.runner" ]; then
        ./config.sh remove --token "$(get_registration_token)" || true
    fi
    
    log "Cleanup complete"
    exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

# =============================================================================
# Configure Runner
# =============================================================================

log "Configuring runner..."

REG_TOKEN=$(get_registration_token)

if [ -z "${REG_TOKEN}" ]; then
    error "Failed to obtain registration token"
    exit 1
fi

log "Registering runner with GitHub..."

./config.sh \
    --url "${REPO_URL}" \
    --token "${REG_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "${LABELS}" \
    --work "${RUNNER_WORKDIR}" \
    --unattended \
    --replace

log "Runner configured successfully"

# =============================================================================
# Start Runner
# =============================================================================

log "Starting runner..."
log "Runner is now listening for jobs"

./run.sh & wait $!
