#!/bin/bash
set -euo pipefail

# Undeploy (remove) GitHub Self-Hosted Runner

RUNNER_NAME=""
REMOVE_VOLUMES=false

usage() {
    cat <<EOF
Usage: $0 --name <runner-name> [OPTIONS]

Options:
  --name NAME         Runner name (container name) (required)
  --remove-volumes    Also remove associated volumes
  --help              Show this help

Examples:
  # Remove runner but keep workspace
  $0 --name runner-1

  # Remove runner and all data
  $0 --name runner-1 --remove-volumes

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            RUNNER_NAME="$2"
            shift 2
            ;;
        --remove-volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

if [ -z "$RUNNER_NAME" ]; then
    echo "ERROR: --name is required"
    usage
fi

echo "Undeploying runner: $RUNNER_NAME"
echo ""

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${RUNNER_NAME}$"; then
    echo "ERROR: Container '$RUNNER_NAME' not found"
    echo ""
    echo "Available runners:"
    docker ps -a --filter "label=github-runner" --format "  - {{.Names}}"
    exit 1
fi

# Stop container
echo "Stopping container..."
docker stop "$RUNNER_NAME" 2>/dev/null || true

# Remove container
echo "Removing container..."
docker rm "$RUNNER_NAME" 2>/dev/null || true

# Remove volumes if requested
if [ "$REMOVE_VOLUMES" = true ]; then
    echo "Removing volumes..."
    docker volume rm "${RUNNER_NAME}-work" 2>/dev/null || true
    echo "  ✓ Workspace volume removed"
else
    echo "Workspace volume preserved: ${RUNNER_NAME}-work"
    echo "  (Remove manually with: docker volume rm ${RUNNER_NAME}-work)"
fi

echo ""
echo "✓ Runner undeployed successfully"
echo ""
echo "Note: The runner may still appear in GitHub UI for a few minutes."
echo "It will be automatically removed when GitHub detects it's offline."
echo ""
