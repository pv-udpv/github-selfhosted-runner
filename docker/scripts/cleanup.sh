#!/bin/bash
# Cleanup script for GitHub runner workspace and Docker resources
set -euo pipefail

WORKSPACE_DIR="${1:-/home/runner/actions-runner/_work}"
CLEANUP_DAYS="${2:-7}"

echo "[CLEANUP] Starting cleanup process"
echo "[CLEANUP] Workspace: ${WORKSPACE_DIR}"
echo "[CLEANUP] Remove files older than: ${CLEANUP_DAYS} days"

# Cleanup old workspace directories
if [ -d "${WORKSPACE_DIR}" ]; then
    echo "[CLEANUP] Removing old workspace directories..."
    find "${WORKSPACE_DIR}" -mindepth 1 -maxdepth 1 -type d -mtime +${CLEANUP_DAYS} -exec rm -rf {} + || true
    echo "[CLEANUP] Workspace cleanup complete"
fi

# Cleanup Docker resources (if Docker is available)
if command -v docker &> /dev/null; then
    echo "[CLEANUP] Cleaning Docker resources..."
    
    # Remove stopped containers
    docker container prune -f || true
    
    # Remove unused images
    docker image prune -a -f --filter "until=24h" || true
    
    # Remove unused volumes
    docker volume prune -f || true
    
    # Remove unused networks
    docker network prune -f || true
    
    echo "[CLEANUP] Docker cleanup complete"
fi

echo "[CLEANUP] Cleanup process finished"
