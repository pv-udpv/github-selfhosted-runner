#!/bin/bash
set -euo pipefail

# Health check for GitHub Self-Hosted Runners

RUNNER_NAME=""
VERBOSE=false
JSON_OUTPUT=false

usage() {
    cat <<EOF
Usage: $0 --name <runner-name> [OPTIONS]

Options:
  --name NAME         Runner name (container name) (required)
  --verbose           Show detailed information
  --json              Output in JSON format
  --help              Show this help

Examples:
  # Basic health check
  $0 --name runner-1

  # Detailed health check
  $0 --name runner-1 --verbose

  # JSON output for monitoring systems
  $0 --name runner-1 --json

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
        --verbose)
            VERBOSE=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
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

# Collect health data
STATUS="unknown"
UPTIME="0"
CPU_USAGE="0"
MEMORY_USAGE="0"
MEMORY_LIMIT="0"
PROCESS_RUNNING=false
HEALTH_STATUS="unknown"
ERROR_COUNT=0
WARNING_COUNT=0

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${RUNNER_NAME}$"; then
    if [ "$JSON_OUTPUT" = true ]; then
        echo '{"status":"not_found","error":"Container not found"}'
    else
        echo "ERROR: Container '$RUNNER_NAME' not found"
    fi
    exit 1
fi

# Container status
STATUS=$(docker inspect --format='{{.State.Status}}' "$RUNNER_NAME" 2>/dev/null || echo "unknown")

if [ "$STATUS" != "running" ]; then
    if [ "$JSON_OUTPUT" = true ]; then
        echo "{\"status\":\"$STATUS\",\"healthy\":false,\"error\":\"Container not running\"}"
    else
        echo "✗ Container is not running (status: $STATUS)"
    fi
    exit 1
fi

# Get container stats
READ_STATS=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}" "$RUNNER_NAME" 2>/dev/null)
CPU_USAGE=$(echo "$READ_STATS" | cut -d'|' -f1 | tr -d '%')
MEMORY_INFO=$(echo "$READ_STATS" | cut -d'|' -f2)
MEMORY_USAGE=$(echo "$MEMORY_INFO" | awk '{print $1}')
MEMORY_LIMIT=$(echo "$MEMORY_INFO" | awk '{print $3}')

# Check if runner process is running
if docker exec "$RUNNER_NAME" pgrep -f "Runner.Listener" >/dev/null 2>&1; then
    PROCESS_RUNNING=true
else
    PROCESS_RUNNING=false
    ((ERROR_COUNT++))
fi

# Get health check status
HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$RUNNER_NAME" 2>/dev/null || echo "none")

# Check for recent errors in logs
RECENT_ERRORS=$(docker logs --since 5m "$RUNNER_NAME" 2>&1 | grep -i error | wc -l)
if [ "$RECENT_ERRORS" -gt 0 ]; then
    ((WARNING_COUNT++))
fi

# Get uptime
STARTED=$(docker inspect --format='{{.State.StartedAt}}' "$RUNNER_NAME")
STARTED_EPOCH=$(date -d "$STARTED" +%s 2>/dev/null || echo "0")
CURRENT_EPOCH=$(date +%s)
UPTIME_SECONDS=$((CURRENT_EPOCH - STARTED_EPOCH))
UPTIME=$(printf '%dd %dh %dm' $((UPTIME_SECONDS/86400)) $((UPTIME_SECONDS%86400/3600)) $((UPTIME_SECONDS%3600/60)))

# Determine overall health
HEALTHY=true
if [ "$PROCESS_RUNNING" = false ] || [ "$ERROR_COUNT" -gt 0 ]; then
    HEALTHY=false
fi

# Output results
if [ "$JSON_OUTPUT" = true ]; then
    cat <<EOF
{
  "runner": "$RUNNER_NAME",
  "status": "$STATUS",
  "healthy": $HEALTHY,
  "process_running": $PROCESS_RUNNING,
  "health_status": "$HEALTH_STATUS",
  "uptime": "$UPTIME",
  "uptime_seconds": $UPTIME_SECONDS,
  "cpu_usage_percent": $CPU_USAGE,
  "memory_usage": "$MEMORY_USAGE",
  "memory_limit": "$MEMORY_LIMIT",
  "error_count": $ERROR_COUNT,
  "warning_count": $WARNING_COUNT,
  "recent_errors": $RECENT_ERRORS
}
EOF
else
    echo "Health Check: $RUNNER_NAME"
    echo "==========================================="
    echo ""
    
    if [ "$HEALTHY" = true ]; then
        echo "Status: ✓ HEALTHY"
    else
        echo "Status: ✗ UNHEALTHY"
    fi
    
    echo ""
    echo "Container Status:    $STATUS"
    echo "Process Running:     $([ "$PROCESS_RUNNING" = true ] && echo '✓ Yes' || echo '✗ No')"
    echo "Health Check:        $HEALTH_STATUS"
    echo "Uptime:              $UPTIME"
    echo "CPU Usage:           ${CPU_USAGE}%"
    echo "Memory:              $MEMORY_USAGE / $MEMORY_LIMIT"
    echo "Recent Errors (5m):  $RECENT_ERRORS"
    
    if [ "$VERBOSE" = true ]; then
        echo ""
        echo "Detailed Information:"
        echo "-------------------------------------------"
        
        # Repository
        REPO_URL=$(docker inspect "$RUNNER_NAME" | jq -r '.[0].Config.Env[] | select(startswith("REPO_URL="))' | cut -d= -f2-)
        echo "Repository:          $REPO_URL"
        
        # Labels
        LABELS=$(docker inspect "$RUNNER_NAME" | jq -r '.[0].Config.Env[] | select(startswith("LABELS="))' | cut -d= -f2-)
        echo "Labels:              $LABELS"
        
        # Resource limits
        CPU_LIMIT=$(docker inspect "$RUNNER_NAME" | jq -r '.[0].HostConfig.NanoCpus / 1000000000')
        MEMORY_LIMIT_BYTES=$(docker inspect "$RUNNER_NAME" | jq -r '.[0].HostConfig.Memory')
        MEMORY_LIMIT_GB=$(awk "BEGIN {printf \"%.1f\", $MEMORY_LIMIT_BYTES/1024/1024/1024}")
        echo "CPU Limit:           ${CPU_LIMIT} cores"
        echo "Memory Limit:        ${MEMORY_LIMIT_GB}GB"
        
        # Disk usage
        DISK_USAGE=$(docker exec "$RUNNER_NAME" df -h /home/runner/actions-runner/_work | tail -1 | awk '{print $5}')
        echo "Workspace Usage:     $DISK_USAGE"
        
        # Recent logs
        echo ""
        echo "Recent Logs (last 10 lines):"
        echo "-------------------------------------------"
        docker logs --tail 10 "$RUNNER_NAME" 2>&1 | sed 's/^/  /'
    fi
    
    echo ""
fi

# Exit with appropriate code
if [ "$HEALTHY" = true ]; then
    exit 0
else
    exit 1
fi
