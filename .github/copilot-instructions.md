# GitHub Copilot Instructions for github-selfhosted-runner

## Project Overview

This is a **universal self-hosted GitHub Actions runner** with GitHub App authentication support. The project enables secure, production-ready deployment of self-hosted runners for any GitHub repository.

## Core Principles

### 1. Security First
- **Always** use GitHub App authentication over Personal Access Tokens
- Private keys must be mounted read-only (`:ro`)
- Never commit secrets, tokens, or `.env` files
- Use `chmod 600` for all private key files
- Run containers as non-root users
- Validate all external inputs

### 2. Production-Ready Defaults
- Enable auto-restart (`--restart unless-stopped`)
- Set resource limits (CPU, memory)
- Implement health checks
- Enable log rotation
- Auto-cleanup old workspaces and Docker resources

### 3. Simplicity & Reusability
- Configuration via `.env` files only
- Single command deployment
- Clear, documented scripts
- Works for any repository without code changes

## Code Style Guidelines

### Shell Scripts
```bash
#!/bin/bash
set -euo pipefail  # ALWAYS include this

# Use descriptive variable names in UPPERCASE
CONFIG_FILE=""
RUNNER_NAME=""

# Always validate inputs
if [ -z "${REQUIRED_VAR:-}" ]; then
    echo "ERROR: REQUIRED_VAR is not set" >&2
    exit 1
fi

# Use logging functions
log() { echo "[SCRIPT] $*"; }
error() { echo "[SCRIPT] ERROR: $*" >&2; }

# Check file existence before operations
if [ ! -f "$FILE_PATH" ]; then
    error "File not found: $FILE_PATH"
    exit 1
fi
```

### Dockerfile
```dockerfile
# Always specify versions explicitly
FROM ubuntu:22.04

ARG RUNNER_VERSION=2.329.0
ARG DEBIAN_FRONTEND=noninteractive

# Group related RUN commands
RUN apt-get update && apt-get install -y \
    package1 \
    package2 \
    && rm -rf /var/lib/apt/lists/*

# Use non-root user
USER runner
WORKDIR /home/runner

# Include health checks
HEALTHCHECK --interval=30s --timeout=10s \
    CMD pgrep -f "Runner.Listener" || exit 1
```

### Environment Variables
```bash
# Naming convention: COMPONENT_PROPERTY
GITHUB_APP_ID=
GITHUB_APP_INSTALLATION_ID=
RUNNER_NAME=
CPU_LIMIT=

# Always provide defaults
RUNNER_NAME=${RUNNER_NAME:-docker-runner-$(hostname)}
LABELS=${LABELS:-self-hosted,linux,x64,docker}
```

## Architecture Patterns

### Authentication Flow
1. **GitHub App** (preferred)
   - Generate JWT from App ID + Private Key
   - Exchange JWT for Installation Access Token
   - Use Access Token to get Runner Registration Token

2. **PAT Fallback** (legacy)
   - Use PAT directly to get Runner Registration Token

### Resource Management
```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 4g
    reservations:
      cpus: '0.5'
      memory: 1g
```

### Cleanup Strategy
- **Workspace**: Remove directories older than N days
- **Docker**: Prune containers, images, volumes, networks
- **Logs**: Rotate based on size and count

## Common Tasks

### Adding a New Configuration Option
1. Add to `config/runner.env.template` with comment
2. Update `README.md` documentation
3. Implement in `docker/entrypoint.sh`
4. Add example to `config/examples/`
5. Update `docs/configuration.md`

### Adding a New Script
1. Create in `scripts/` directory
2. Start with shebang and `set -euo pipefail`
3. Add usage function with examples
4. Implement argument parsing
5. Add to README.md
6. Make executable: `chmod +x scripts/new-script.sh`

### Adding Documentation
1. Create in `docs/` directory
2. Use clear headers (##, ###)
3. Include code examples
4. Add troubleshooting section
5. Link from README.md

## Testing Guidelines

### Manual Testing Checklist
- [ ] Fresh deployment works
- [ ] Runner appears in GitHub UI
- [ ] Runner can execute simple workflow
- [ ] Runner can execute Docker-based workflow
- [ ] Cleanup runs successfully
- [ ] Health check passes
- [ ] Logs are readable and informative

### Integration Tests
```yaml
# Test workflow in target repository
name: Test Runner
on: [workflow_dispatch]
jobs:
  test:
    runs-on: [self-hosted, docker]
    steps:
      - run: echo "Runner is working"
      - run: docker --version
```

## Error Handling

### Exit Codes
- `0`: Success
- `1`: General error
- `2`: Invalid arguments
- `3`: Missing dependencies
- `4`: Authentication failure
- `5`: Network error

### Error Messages
```bash
# BAD
echo "Error"

# GOOD
error "Failed to obtain registration token"
error "Possible causes:"
error "  - Invalid GitHub App credentials"
error "  - Network connectivity issues"
error "  - Insufficient permissions"
```

## Security Checklist

When writing code, ensure:
- [ ] No hardcoded secrets or tokens
- [ ] Private keys are never logged
- [ ] File permissions are restrictive (600 for keys)
- [ ] Input validation is performed
- [ ] Error messages don't leak sensitive info
- [ ] Docker socket access is intentional
- [ ] Network exposure is minimal
- [ ] Secrets are mounted read-only

## Documentation Standards

### README.md
- Quick Start section comes first
- Code examples are complete and runnable
- Links to detailed docs in `docs/`
- Configuration examples for common use cases

### Inline Comments
```bash
# GOOD: Explain WHY, not WHAT
# Use JWT for time-limited authentication instead of long-lived PAT
generate_jwt "${APP_ID}" "${KEY_PATH}"

# BAD: Obvious comment
# Generate JWT token
generate_jwt "${APP_ID}" "${KEY_PATH}"
```

### docs/ Files
- One topic per file
- Step-by-step instructions
- Screenshots for UI steps
- Troubleshooting section at end

## Performance Considerations

- Use Docker layer caching (order commands by change frequency)
- Minimize image size (multi-stage builds, cleanup in same RUN)
- Set appropriate resource limits
- Implement cleanup for long-running runners
- Use volume mounts for persistent data

## Copilot Shortcuts

When I say:
- **"Add cleanup script"** → Create script in `scripts/` with workspace and Docker cleanup
- **"Add docs for X"** → Create markdown file in `docs/` with comprehensive guide
- **"Add example config"** → Create `.env` file in `config/examples/`
- **"Add workflow"** → Create GitHub Actions workflow in `.github/workflows/`
- **"Add security check"** → Implement validation, permissions, or audit logging

## Project-Specific Context

### Key Files
- `docker/entrypoint.sh`: Runner startup logic, auth handling
- `scripts/deploy.sh`: Main deployment script
- `config/runner.env.template`: Configuration reference
- `docker/Dockerfile`: Runner image definition

### Critical Paths
- Private keys: `/etc/github-runner/*.pem`
- Runner workspace: `/home/runner/actions-runner/_work`
- Config files: `./config/*.env`

### External Dependencies
- GitHub Actions Runner binary
- Docker CLI (for DinD)
- OpenSSL (for JWT generation)
- jq (for JSON parsing)

## Remember

1. **Security over convenience** - Never sacrifice security for ease of use
2. **Documentation is code** - Update docs with every feature
3. **Test with real workflows** - Ensure runners work with actual GitHub Actions
4. **Think reusable** - Code should work for ANY repository
5. **Fail fast, fail clearly** - Better to exit with clear error than continue in bad state
