#!/bin/bash
set -euo pipefail

# Update GitHub Actions Runner to a new version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

RUNNER_VERSION=""
RUNNER_NAME=""
CONFIG_FILE=""
ZERO_DOWNTIME=false

usage() {
    cat <<EOF
Usage: $0 --version <version> [OPTIONS]

Options:
  --version VER       Runner version (e.g., 2.330.0) (required)
  --name NAME         Update specific runner only
  --config FILE       Configuration file to use for redeployment
  --zero-downtime     Update with zero downtime (requires multiple runners)
  --help              Show this help

Examples:
  # Update all runners to version 2.330.0
  $0 --version 2.330.0

  # Update specific runner
  $0 --version 2.330.0 --name runner-1 --config config/runner.env

  # Zero-downtime update (updates runners one by one)
  $0 --version 2.330.0 --zero-downtime

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            RUNNER_VERSION="$2"
            shift 2
            ;;
        --name)
            RUNNER_NAME="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --zero-downtime)
            ZERO_DOWNTIME=true
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

if [ -z "$RUNNER_VERSION" ]; then
    echo "ERROR: --version is required"
    usage
fi

echo "Updating to GitHub Actions Runner version: $RUNNER_VERSION"
echo ""

# Build new image
echo "Building new runner image..."
cd "$PROJECT_ROOT"
docker build \
    --build-arg RUNNER_VERSION="$RUNNER_VERSION" \
    -t github-runner:"$RUNNER_VERSION" \
    -t github-runner:latest \
    -f docker/Dockerfile \
    docker/

echo "✓ Image built successfully"
echo ""

# Get list of runners to update
if [ -n "$RUNNER_NAME" ]; then
    RUNNERS=("$RUNNER_NAME")
else
    mapfile -t RUNNERS < <(docker ps --filter "ancestor=github-runner" --format "{{.Names}}")
fi

if [ ${#RUNNERS[@]} -eq 0 ]; then
    echo "No runners found to update"
    exit 0
fi

echo "Runners to update:"
for runner in "${RUNNERS[@]}"; do
    echo "  - $runner"
done
echo ""

# Update runners
for runner in "${RUNNERS[@]}"; do
    echo "Updating $runner..."

    # Get current configuration for logging/debugging
    # shellcheck disable=SC2034
    REPO_URL=$(docker inspect "$runner" | jq -r '.[0].Config.Env[] | select(startswith("REPO_URL="))' | cut -d= -f2-)
    # shellcheck disable=SC2034
    LABELS=$(docker inspect "$runner" | jq -r '.[0].Config.Env[] | select(startswith("LABELS="))' | cut -d= -f2-)
    # shellcheck disable=SC2034
    CPU_LIMIT=$(docker inspect "$runner" | jq -r '.[0].HostConfig.NanoCpus / 1000000000')
    # shellcheck disable=SC2034
    MEMORY_LIMIT=$(docker inspect "$runner" | jq -r '.[0].HostConfig.Memory')
    
    # Log current config for debugging
    echo "  Current config: REPO_URL=${REPO_URL}, LABELS=${LABELS}"
    echo "  Resources: CPU=${CPU_LIMIT}, Memory=${MEMORY_LIMIT}"

    # Stop and remove old container
    docker stop "$runner"
    docker rm "$runner"

    # Deploy new version
    if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
        # Update version in config
        sed -i "s/RUNNER_VERSION=.*/RUNNER_VERSION=$RUNNER_VERSION/" "$CONFIG_FILE"
        "$SCRIPT_DIR/deploy.sh" --config "$CONFIG_FILE" --name "$runner"
    else
        echo "WARNING: No config file provided, using basic deployment"
        echo "Runner may need manual reconfiguration"
    fi

    echo "✓ $runner updated"

    # Wait before updating next runner (zero-downtime mode)
    if [ "$ZERO_DOWNTIME" = true ] && [ "$runner" != "${RUNNERS[-1]}" ]; then
        echo "Waiting 30 seconds before updating next runner..."
        sleep 30
    fi

    echo ""
done

echo "✓ Update complete"
echo ""
echo "Verify runners:"
echo "  docker ps --filter 'ancestor=github-runner:$RUNNER_VERSION'"
echo ""
