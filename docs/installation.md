# Installation Guide

Complete guide for installing and deploying GitHub Self-Hosted Runner.

## Prerequisites

### System Requirements

- **Operating System**: Linux (Ubuntu 22.04 LTS recommended)
- **Docker**: Version 20.10 or later
- **CPU**: Minimum 2 cores (4+ recommended for production)
- **Memory**: Minimum 4GB RAM (8GB+ recommended for production)
- **Disk Space**: Minimum 20GB free space
- **Network**: Outbound HTTPS access to GitHub (api.github.com, github.com)

### Access Requirements

- GitHub repository admin access
- Ability to create GitHub Apps (organization or personal account)
- SSH/terminal access to deployment server

## Installation Steps

### 1. Install Docker

If Docker is not already installed:

```bash
# Update package index
sudo apt-get update

# Install dependencies
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up stable repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Verify installation
docker --version
```

### 2. Clone Repository

```bash
git clone https://github.com/pv-udpv/github-selfhosted-runner.git
cd github-selfhosted-runner
```

### 3. Create GitHub App

See detailed guide: [GitHub App Setup](github-app-setup.md)

Quick steps:

1. Go to [GitHub Apps](https://github.com/settings/apps/new)
2. Fill in:
   - **App name**: `github-runner-yourorg`
   - **Homepage URL**: `https://github.com/yourorg`
   - **Webhook**: Uncheck "Active"
3. Set permissions:
   - Repository > Administration: Read & write (OR)
   - Repository > Actions: Read & write
4. Click "Create GitHub App"
5. Note the **App ID**
6. Generate and download **private key**
7. Install app on your repository
8. Note the **Installation ID** from URL

### 4. Configure Runner

#### Option A: Interactive Setup (Recommended)

```bash
./scripts/setup.sh
```

Follow the prompts to:
- Enter GitHub App ID
- Enter Installation ID
- Specify private key location
- Configure repository URL
- Set runner name
- Define resource limits

#### Option B: Manual Configuration

```bash
# Copy template
cp config/runner.env.template config/runner.env

# Edit configuration
nano config/runner.env
```

Minimal configuration:

```bash
# GitHub App Authentication
GITHUB_APP_ID=123456
GITHUB_APP_INSTALLATION_ID=789012
GITHUB_APP_PRIVATE_KEY_PATH=/etc/github-runner/app-key.pem

# Repository
REPO_URL=https://github.com/your-org/your-repo
RUNNER_NAME=docker-runner-prod
LABELS=self-hosted,linux,x64,docker

# Resources
CPU_LIMIT=2.0
MEMORY_LIMIT=4g
```

### 5. Install Private Key

```bash
# Create directory
sudo mkdir -p /etc/github-runner

# Copy private key (adjust path)
sudo cp ~/Downloads/your-app-key.pem /etc/github-runner/app-key.pem

# Set permissions (IMPORTANT!)
sudo chmod 600 /etc/github-runner/app-key.pem
```

### 6. Deploy Runner

```bash
./scripts/deploy.sh --config config/runner.env
```

Expected output:
```
Deploying runner: docker-runner-prod
  Repository: https://github.com/your-org/your-repo
  CPU: 2.0 cores
  Memory: 4g

Building Docker image...
[build output...]

✓ Runner deployed successfully

Check status:
  docker logs -f docker-runner-prod

Verify on GitHub:
  https://github.com/your-org/your-repo/settings/actions/runners
```

### 7. Verify Deployment

#### Check Container Status

```bash
# View running containers
docker ps --filter "name=docker-runner-prod"

# View logs
docker logs -f docker-runner-prod
```

Successful logs should show:
```
[RUNNER] Configuration:
[RUNNER]   Repository: https://github.com/your-org/your-repo
[RUNNER]   Runner Name: docker-runner-prod
[RUNNER]   Labels: self-hosted,linux,x64,docker
[RUNNER] Using GitHub App authentication
[RUNNER] Configuring runner...
[RUNNER] Runner configured successfully
[RUNNER] Starting runner...
[RUNNER] Runner is now listening for jobs
```

#### Check GitHub UI

1. Go to repository settings: `https://github.com/your-org/your-repo/settings/actions/runners`
2. Verify runner appears with "Idle" status (green)
3. Check labels match configuration

#### Run Test Workflow

Create `.github/workflows/test-runner.yml` in your repository:

```yaml
name: Test Runner
on: [workflow_dispatch]
jobs:
  test:
    runs-on: [self-hosted, linux, docker]
    steps:
      - name: Test runner
        run: |
          echo "Runner is working!"
          echo "Hostname: $(hostname)"
          docker --version
```

Trigger manually from Actions tab.

## Post-Installation

### Health Check

```bash
./scripts/health-check.sh --name docker-runner-prod
```

### Monitor Resources

```bash
# Real-time stats
docker stats docker-runner-prod

# Detailed info
./scripts/health-check.sh --name docker-runner-prod --verbose
```

### Enable Auto-Start on Boot

Container is already configured with `--restart unless-stopped`, so it will automatically start on system reboot.

To verify:
```bash
docker inspect docker-runner-prod | jq '.[0].HostConfig.RestartPolicy'
```

Should show:
```json
{
  "Name": "unless-stopped",
  "MaximumRetryCount": 0
}
```

## Multiple Runners

### Same Repository (Parallel Jobs)

```bash
# Deploy 3 runners
for i in {1..3}; do
  ./scripts/deploy.sh \
    --config config/runner.env \
    --name runner-$i \
    --cpus 1.0 \
    --memory 2g
done
```

### Multiple Repositories

```bash
# Create configs
cp config/runner.env config/repo-frontend.env
cp config/runner.env config/repo-backend.env

# Edit each config with different REPO_URL and RUNNER_NAME

# Deploy
./scripts/deploy.sh --config config/repo-frontend.env
./scripts/deploy.sh --config config/repo-backend.env
```

## Uninstall

### Remove Single Runner

```bash
# Keep workspace data
./scripts/undeploy.sh --name docker-runner-prod

# Remove everything including data
./scripts/undeploy.sh --name docker-runner-prod --remove-volumes
```

### Complete Cleanup

```bash
# Remove all runners
docker stop $(docker ps -q --filter "ancestor=github-runner")
docker rm $(docker ps -aq --filter "ancestor=github-runner")

# Remove images
docker rmi github-runner:latest

# Remove volumes
docker volume prune -f

# Remove private key (if no longer needed)
sudo rm /etc/github-runner/app-key.pem
```

## Troubleshooting

See [Troubleshooting Guide](troubleshooting.md) for common issues and solutions.

## Next Steps

- [Configuration Reference](configuration.md) - Detailed config options
- [GitHub App Setup](github-app-setup.md) - GitHub App configuration
- [Architecture](architecture.md) - System design and components
