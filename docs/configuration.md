# Configuration Reference

Complete reference for all configuration options in GitHub Self-Hosted Runner.

## Configuration File Format

Configuration is stored in `.env` files with simple `KEY=value` format.

**Location**: `config/runner.env`

**Template**: `config/runner.env.template`

## GitHub Authentication

### GitHub App (Recommended)

#### `GITHUB_APP_ID`

- **Type**: Integer
- **Required**: Yes (if using GitHub App)
- **Description**: GitHub App ID from app settings
- **Example**: `123456`
- **How to get**: See [GitHub App Setup](github-app-setup.md)

#### `GITHUB_APP_INSTALLATION_ID`

- **Type**: Integer
- **Required**: Yes (if using GitHub App)
- **Description**: Installation ID when app is installed on repository
- **Example**: `789012`
- **How to get**: From installation URL

#### `GITHUB_APP_PRIVATE_KEY_PATH`

- **Type**: String (file path)
- **Required**: Yes (if using GitHub App)
- **Description**: Path to private key file inside container
- **Default**: `/etc/github-runner/app-key.pem`
- **Example**: `/etc/github-runner/app-key.pem`
- **Security**: Must be mounted read-only (`:ro`)
- **Permissions**: Must be `600` on host

### Personal Access Token (Fallback)

#### `GITHUB_PAT`

- **Type**: String (token)
- **Required**: Yes (if not using GitHub App)
- **Description**: Personal Access Token with `repo` scope
- **Example**: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
- **Security**: Less secure than GitHub App, avoid in production
- **Scope**: Requires `repo` scope or `admin:org` for organization runners

## Runner Configuration

### `REPO_URL`

- **Type**: String (URL)
- **Required**: Yes
- **Description**: Full URL of GitHub repository
- **Format**: `https://github.com/OWNER/REPO`
- **Example**: `https://github.com/acme-corp/my-project`
- **Notes**: Must be exact, including `https://`

### `RUNNER_NAME`

- **Type**: String
- **Required**: No
- **Default**: `docker-runner-<hostname>`
- **Description**: Name that appears in GitHub UI
- **Example**: `docker-runner-prod-01`
- **Constraints**: Alphanumeric, hyphens, underscores
- **Uniqueness**: Must be unique within repository

### `LABELS`

- **Type**: String (comma-separated)
- **Required**: No
- **Default**: `self-hosted,linux,x64,docker`
- **Description**: Runner labels for workflow targeting
- **Example**: `self-hosted,linux,x64,docker,production`
- **Usage in workflow**:
  ```yaml
  runs-on: [self-hosted, production]
  ```
- **Best practices**:
  - Always include: `self-hosted,linux,x64`
  - Add custom labels for environment: `dev`, `staging`, `prod`
  - Add capability labels: `docker`, `gpu`, `large-disk`

### `RUNNER_GROUP`

- **Type**: String
- **Required**: No (Enterprise only)
- **Description**: Runner group for organization runners
- **Example**: `production`
- **Notes**: Only applicable to GitHub Enterprise

### `RUNNER_WORKDIR`

- **Type**: String (path)
- **Required**: No
- **Default**: `/home/runner/actions-runner/_work`
- **Description**: Working directory for job execution
- **Notes**: Rarely needs to be changed

## Resource Limits

### `CPU_LIMIT`

- **Type**: Float
- **Required**: No
- **Default**: `2.0`
- **Description**: Maximum CPU cores available to container
- **Unit**: Number of cores
- **Example**: `4.0` (4 cores)
- **Range**: `0.1` to number of host cores
- **Recommendations**:
  - Development: `1.0` - `2.0`
  - Production: `2.0` - `4.0`
  - Large workloads: `4.0+`

### `CPU_RESERVATION`

- **Type**: Float
- **Required**: No
- **Default**: `0.5`
- **Description**: Guaranteed CPU cores
- **Example**: `1.0`
- **Notes**: Should be less than `CPU_LIMIT`

### `MEMORY_LIMIT`

- **Type**: String (size)
- **Required**: No
- **Default**: `4g`
- **Description**: Maximum memory available to container
- **Format**: `<number><unit>` where unit is `b`, `k`, `m`, `g`
- **Example**: `8g` (8 gigabytes)
- **Recommendations**:
  - Development: `2g` - `4g`
  - Production: `4g` - `8g`
  - Large workloads: `8g+`

### `MEMORY_RESERVATION`

- **Type**: String (size)
- **Required**: No
- **Default**: `1g`
- **Description**: Guaranteed memory
- **Example**: `2g`
- **Notes**: Should be less than `MEMORY_LIMIT`

### `DISK_LIMIT`

- **Type**: String (size)
- **Required**: No
- **Default**: `20g`
- **Description**: Maximum disk space for workspace
- **Example**: `50g`
- **Notes**: Enforced through cleanup, not hard limit

## Docker Configuration

### `ENABLE_DOCKER`

- **Type**: Boolean
- **Required**: No
- **Default**: `true`
- **Description**: Enable Docker-in-Docker support
- **Values**: `true`, `false`
- **Notes**: Required for workflows that use Docker

### `RUNNER_VERSION`

- **Type**: String (version)
- **Required**: No
- **Default**: `2.329.0`
- **Description**: GitHub Actions Runner version
- **Format**: `X.Y.Z`
- **Example**: `2.330.0`
- **Notes**: Check [releases](https://github.com/actions/runner/releases) for latest version

## Maintenance

### `CLEANUP_WORKSPACE_DAYS`

- **Type**: Integer
- **Required**: No
- **Default**: `7`
- **Description**: Remove workspace directories older than N days
- **Unit**: Days
- **Example**: `14`
- **Range**: `1` - `365`

### `CLEANUP_DOCKER_HOURS`

- **Type**: Integer
- **Required**: No
- **Default**: `24`
- **Description**: Remove Docker images older than N hours
- **Unit**: Hours
- **Example**: `48`
- **Range**: `1` - `8760`

### `LOG_MAX_FILES`

- **Type**: Integer
- **Required**: No
- **Default**: `3`
- **Description**: Maximum number of log files to keep
- **Example**: `5`

### `LOG_MAX_SIZE`

- **Type**: String (size)
- **Required**: No
- **Default**: `10m`
- **Description**: Maximum size per log file
- **Format**: `<number><unit>` where unit is `k`, `m`, `g`
- **Example**: `20m`

## Network Configuration

### `NETWORK_MODE`

- **Type**: String
- **Required**: No
- **Default**: `bridge`
- **Description**: Docker network mode
- **Values**:
  - `bridge`: Default Docker bridge network
  - `host`: Use host network (less isolation)
  - `custom`: Use custom network (specify with `NETWORK_NAME`)
- **Example**: `custom`

### `NETWORK_NAME`

- **Type**: String
- **Required**: No (required if `NETWORK_MODE=custom`)
- **Description**: Custom Docker network name
- **Example**: `runner-network`
- **Notes**: Network must be created before deployment

## Advanced Options

### `DISABLE_AUTO_UPDATE`

- **Type**: Boolean
- **Required**: No
- **Default**: `true`
- **Description**: Disable automatic runner updates
- **Values**: `true`, `false`
- **Recommendation**: Keep `true` for controlled updates

### `DEBUG`

- **Type**: Boolean
- **Required**: No
- **Default**: `false`
- **Description**: Enable verbose logging
- **Values**: `true`, `false`
- **Notes**: Use for troubleshooting

### `CUSTOM_ENV_VARS`

- **Type**: String (comma-separated key=value)
- **Required**: No
- **Description**: Custom environment variables for workflows
- **Format**: `KEY1=value1,KEY2=value2`
- **Example**: `NPM_TOKEN=xxx,DOCKER_REGISTRY=registry.example.com`
- **Notes**: Available to all job steps

## Configuration Examples

### Minimal Configuration

```bash
GITHUB_APP_ID=123456
GITHUB_APP_INSTALLATION_ID=789012
GITHUB_APP_PRIVATE_KEY_PATH=/etc/github-runner/app-key.pem
REPO_URL=https://github.com/acme/project
```

### Development Environment

```bash
GITHUB_APP_ID=123456
GITHUB_APP_INSTALLATION_ID=789012
GITHUB_APP_PRIVATE_KEY_PATH=/etc/github-runner/app-key.pem

REPO_URL=https://github.com/acme/project
RUNNER_NAME=dev-runner-01
LABELS=self-hosted,linux,x64,docker,dev

CPU_LIMIT=1.0
MEMORY_LIMIT=2g
CLEANUP_WORKSPACE_DAYS=3
```

### Production Environment

```bash
GITHUB_APP_ID=123456
GITHUB_APP_INSTALLATION_ID=789012
GITHUB_APP_PRIVATE_KEY_PATH=/etc/github-runner/app-key.pem

REPO_URL=https://github.com/acme/project
RUNNER_NAME=prod-runner-01
LABELS=self-hosted,linux,x64,docker,production
RUNNER_GROUP=production

CPU_LIMIT=4.0
CPU_RESERVATION=2.0
MEMORY_LIMIT=8g
MEMORY_RESERVATION=4g
DISK_LIMIT=50g

CLEANUP_WORKSPACE_DAYS=14
CLEANUP_DOCKER_HOURS=48
LOG_MAX_FILES=5
LOG_MAX_SIZE=20m

NETWORK_MODE=custom
NETWORK_NAME=prod-runner-net
DISABLE_AUTO_UPDATE=true
```

### High-Performance Build Server

```bash
GITHUB_APP_ID=123456
GITHUB_APP_INSTALLATION_ID=789012
GITHUB_APP_PRIVATE_KEY_PATH=/etc/github-runner/app-key.pem

REPO_URL=https://github.com/acme/large-project
RUNNER_NAME=build-runner-01
LABELS=self-hosted,linux,x64,docker,large-disk,high-cpu

CPU_LIMIT=8.0
CPU_RESERVATION=4.0
MEMORY_LIMIT=16g
MEMORY_RESERVATION=8g
DISK_LIMIT=100g

ENABLE_DOCKER=true
CLEANUP_WORKSPACE_DAYS=7
CLEANUP_DOCKER_HOURS=12
```

## Validation

To validate your configuration:

```bash
# Check syntax
bash -n config/runner.env

# Test deployment (dry-run)
./scripts/deploy.sh --config config/runner.env --help
```

## Best Practices

1. **Security**
   - Never commit `.env` files to git
   - Use GitHub App instead of PAT
   - Set strict file permissions on private keys
   - Rotate credentials periodically

2. **Resource Management**
   - Set limits based on workload
   - Monitor resource usage
   - Adjust limits over time
   - Use reservations for critical runners

3. **Maintenance**
   - Enable cleanup to prevent disk exhaustion
   - Review logs periodically
   - Update runner version regularly
   - Test configuration changes in dev first

4. **Organization**
   - Use descriptive runner names
   - Label runners by purpose/environment
   - Document custom configurations
   - Keep configuration in version control (without secrets)

## Next Steps

- [Installation Guide](installation.md) - Deploy your runner
- [Troubleshooting](troubleshooting.md) - Common issues
- [Architecture](architecture.md) - System design
