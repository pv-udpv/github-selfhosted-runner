# GitHub Self-Hosted Runner

Universal, production-ready self-hosted GitHub Actions runner with GitHub App authentication.

## Features

- 🔐 **GitHub App Authentication** - No manual token management
- 🐳 **Docker-based** - Easy deployment, isolated environment
- 🔄 **Auto-restart** - Survives crashes and reboots
- 📊 **Resource Limits** - CPU, memory, disk quotas
- 🧹 **Auto-cleanup** - Workspace and Docker image management
- 🛡️ **Security-first** - Read-only secrets, minimal permissions
- 📦 **Reusable** - Deploy to any repository with config file
- 🎛️ **Flexible** - Single runner or fleet management

## Quick Start

### 1. Prerequisites

- Docker installed
- GitHub repository admin access
- Linux server (recommended: Ubuntu 22.04)

### 2. Create GitHub App

```bash
./scripts/setup.sh
```

Follow interactive prompts to create GitHub App and get credentials.

### 3. Configure

```bash
cp config/runner.env.template config/runner.env
# Edit config/runner.env with your settings
```

### 4. Deploy

```bash
./scripts/deploy.sh --config config/runner.env
```

### 5. Verify

Check GitHub repository settings → Actions → Runners

## Configuration Examples

### Single Repository

```bash
# config/runner.env
GITHUB_APP_ID=123456
GITHUB_APP_INSTALLATION_ID=789012
GITHUB_APP_PRIVATE_KEY_PATH=/etc/github-runner/app-key.pem

REPO_URL=https://github.com/your-org/your-repo
RUNNER_NAME=docker-runner-prod
LABELS=self-hosted,linux,x64,docker

CPU_LIMIT=2.0
MEMORY_LIMIT=4g
```

### Multiple Runners (Same Repository)

```bash
# Deploy 3 runners for parallel jobs
./scripts/deploy.sh --config config/runner.env --name runner-1 --cpus 1 --memory 2g
./scripts/deploy.sh --config config/runner.env --name runner-2 --cpus 1 --memory 2g
./scripts/deploy.sh --config config/runner.env --name runner-3 --cpus 1 --memory 2g
```

### Multiple Repositories

```bash
# Deploy runner per repository
./scripts/deploy.sh --config config/repo-a.env
./scripts/deploy.sh --config config/repo-b.env
./scripts/deploy.sh --config config/repo-c.env
```

## Documentation

- [Installation Guide](docs/installation.md)
- [GitHub App Setup](docs/github-app-setup.md)
- [Configuration Reference](docs/configuration.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Architecture](docs/architecture.md)

## Advanced Usage

### Custom Docker Image

```bash
# Build with custom tools
docker build \
  --build-arg RUNNER_VERSION=2.329.0 \
  --build-arg INSTALL_CUSTOM_TOOLS=true \
  -t my-custom-runner:latest \
  -f docker/Dockerfile .
```

### Resource Monitoring

```bash
./scripts/health-check.sh --name runner-1
```

### Update Runner Version

```bash
./scripts/update.sh --version 2.330.0
```

## Security

- Private keys stored with `chmod 600`
- Read-only mounts for secrets
- Non-root user inside container
- Automatic cleanup on shutdown
- Audit logging enabled

## License

MIT
