# Complete Installation Guide

Detailed step-by-step guide for installing and deploying GitHub Self-Hosted Runner from scratch.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation Process](#installation-process)
  - [Phase 1: Environment Setup](#phase-1-environment-setup)
  - [Phase 2: GitHub App Configuration](#phase-2-github-app-configuration)
  - [Phase 3: Runner Configuration](#phase-3-runner-configuration)
  - [Phase 4: Deployment](#phase-4-deployment)
  - [Phase 5: Verification](#phase-5-verification)
- [Post-Installation](#post-installation)
- [Advanced Scenarios](#advanced-scenarios)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

---

## Overview

### What You'll Install

This guide will help you deploy a containerized GitHub Actions self-hosted runner with:
- **Docker-based isolation** for security and portability
- **GitHub App authentication** for secure, time-limited access
- **Resource limits** (CPU, memory) for controlled usage
- **Auto-restart** capability for high availability
- **Health monitoring** and logging

### Installation Time

- **Quick setup**: 15-20 minutes (experienced users)
- **Full setup**: 30-45 minutes (first-time users)
- **Multiple runners**: +5 minutes per additional runner

### Architecture Overview

```
┌─────────────────────────────────────────┐
│         Your Linux Server               │
│  ┌───────────────────────────────────┐  │
│  │     Docker Container              │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  GitHub Actions Runner      │  │  │
│  │  │  + Docker CLI (DinD)        │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
              ↕ HTTPS
┌─────────────────────────────────────────┐
│         GitHub.com                      │
│  • Receives job requests                │
│  • Authenticates via GitHub App         │
│  • Sends jobs to runner                 │
└─────────────────────────────────────────┘
```

---

## Prerequisites

### System Requirements

#### Minimum Configuration (Development)
- **OS**: Linux (Ubuntu 22.04 LTS, Debian 11, or CentOS 8+)
- **CPU**: 2 cores
- **RAM**: 4GB
- **Disk**: 20GB free space
- **Network**: Outbound HTTPS (443) to `*.github.com`, `*.githubusercontent.com`

#### Recommended Configuration (Production)
- **OS**: Ubuntu 22.04 LTS (latest patches)
- **CPU**: 4+ cores
- **RAM**: 8GB+
- **Disk**: 50GB+ free space (SSD recommended)
- **Network**: Stable connection, firewall configured

#### Software Requirements

| Software | Minimum Version | Recommended |
|----------|----------------|-------------|
| Docker   | 20.10          | 24.0+       |
| Git      | 2.0            | 2.30+       |
| Bash     | 4.0            | 5.0+        |
| curl     | 7.0            | Latest      |
| jq       | 1.5            | Latest      |

### Access Requirements

#### GitHub Access
- ✅ Repository **admin** access (to register runners)
- ✅ Ability to create GitHub Apps (personal or organization account)
- ✅ Permission to install apps on repositories

#### Server Access
- ✅ SSH or direct terminal access
- ✅ `sudo` privileges (for Docker and system setup)
- ✅ Ability to open firewall ports (if applicable)

### Pre-Installation Checklist

Before starting, verify:

```bash
# Check OS version
lsb_release -a

# Check available disk space
df -h /

# Check CPU cores
nproc

# Check RAM
free -h

# Check network connectivity to GitHub
curl -I https://api.github.com
curl -I https://github.com

# Check if Docker is installed
docker --version || echo "Docker not installed"

# Check if Git is installed
git --version || echo "Git not installed"
```

---

## Installation Process

### Phase 1: Environment Setup

#### Step 1.1: Update System Packages

```bash
# Update package lists
sudo apt-get update

# Upgrade existing packages (optional but recommended)
sudo apt-get upgrade -y

# Install prerequisites
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    jq \
    git
```

#### Step 1.2: Install Docker

**If Docker is already installed**, verify version:
```bash
docker --version
# Should show: Docker version 20.10+ or higher
```

**If Docker is not installed:**

```bash
# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Verify installation
docker --version
sudo docker run hello-world
```

#### Step 1.3: Configure Docker Permissions (Optional)

**Warning**: Adding users to `docker` group grants root-equivalent permissions.

```bash
# Add current user to docker group
sudo usermod -aG docker $USER

# Apply group changes (logout/login or run)
newgrp docker

# Verify non-root access
docker ps
```

#### Step 1.4: Clone Repository

```bash
# Navigate to desired installation directory
cd /opt  # or ~/projects, or any preferred location

# Clone repository
git clone https://github.com/pv-udpv/github-selfhosted-runner.git

# Navigate to repository
cd github-selfhosted-runner

# Verify repository structure
ls -la
# Should show: config/, docker/, scripts/, docs/, etc.
```

---

### Phase 2: GitHub App Configuration

#### Step 2.1: Create GitHub App

**Navigate to GitHub App creation page:**

- **For Personal Account**: [https://github.com/settings/apps/new](https://github.com/settings/apps/new)
- **For Organization**: `https://github.com/organizations/YOUR-ORG/settings/apps/new`

#### Step 2.2: Fill in App Details

| Field | Value | Notes |
|-------|-------|-------|
| **GitHub App name** | `github-runner-yourorg` | Must be globally unique |
| **Description** | `Self-hosted runner for CI/CD` | Optional |
| **Homepage URL** | `https://github.com/yourorg` | Your org/profile URL |
| **Callback URL** | Leave empty | Not needed |
| **Webhook Active** | ❌ **Uncheck** | Runners don't need webhooks |

#### Step 2.3: Set Permissions

Under **Repository permissions**, set:

**Option A: Administration Permission (Recommended)**
- `Administration`: **Read and write**
- All others: **No access**

**Option B: Actions Permission (Minimal)**
- `Actions`: **Read and write**
- All others: **No access**

> ⚠️ **Important**: Do NOT grant unnecessary permissions like Contents, Issues, Pull Requests

#### Step 2.4: Installation Options

Under **Where can this GitHub App be installed?**:
- Select: **Only on this account** (for private use)
- Or: **Any account** (if sharing the app)

#### Step 2.5: Create App

Click **Create GitHub App** button.

#### Step 2.6: Retrieve App ID

After creation, you'll see:
```
App ID: 123456  ← Copy this number
```

Save this as `GITHUB_APP_ID=123456`

#### Step 2.7: Generate Private Key

1. Scroll down to **Private keys** section
2. Click **Generate a private key**
3. A `.pem` file will download (e.g., `my-app.2025-11-11.private-key.pem`)
4. **IMPORTANT**: Store securely, cannot be re-downloaded

#### Step 2.8: Install App on Repository

1. Click **Install App** in left sidebar
2. Click **Install** next to your account/organization
3. Choose repository access:
   - **All repositories** (easier but less secure)
   - **Only select repositories** ✅ (recommended)
4. Select target repository
5. Click **Install**

#### Step 2.9: Retrieve Installation ID

After installation, you'll be redirected to:
```
https://github.com/settings/installations/12345678
                                       ^^^^^^^^
```

The number `12345678` is your **Installation ID**.

Save this as `GITHUB_APP_INSTALLATION_ID=12345678`

#### Step 2.10: Transfer Private Key to Server

**If GitHub App was created on a different machine:**

```bash
# From your local machine (where .pem was downloaded)
scp ~/Downloads/my-app.*.pem user@your-server:/tmp/github-app-key.pem

# On server
ssh user@your-server
sudo mkdir -p /etc/github-runner
sudo mv /tmp/github-app-key.pem /etc/github-runner/app-key.pem
sudo chmod 600 /etc/github-runner/app-key.pem
sudo chown root:root /etc/github-runner/app-key.pem
```

**If GitHub App was created on the server:**

```bash
# Copy from Downloads to secure location
sudo mkdir -p /etc/github-runner
sudo cp ~/Downloads/my-app.*.pem /etc/github-runner/app-key.pem
sudo chmod 600 /etc/github-runner/app-key.pem
sudo chown root:root /etc/github-runner/app-key.pem
```

**Verify private key:**

```bash
# Check file exists and has correct permissions
ls -la /etc/github-runner/app-key.pem
# Should show: -rw------- 1 root root ... app-key.pem

# Verify it's a valid PEM file
head -n 1 /etc/github-runner/app-key.pem
# Should show: -----BEGIN RSA PRIVATE KEY-----
```

---

### Phase 3: Runner Configuration

#### Step 3.1: Create Configuration File

**Option A: Use Template (Manual)**

```bash
cd /opt/github-selfhosted-runner  # or your installation directory

# Copy template
cp config/runner.env.template config/runner.env

# Edit with your favorite editor
nano config/runner.env
# or
vim config/runner.env
```

**Option B: Interactive Setup (Recommended for First-Time Users)**

> Note: `scripts/setup.sh` is referenced in README but may not exist yet. Use manual method if script is missing.

#### Step 3.2: Configure Essential Settings

Edit `config/runner.env` with your values:

```bash
# ============================================================================
# GitHub App Authentication
# ============================================================================
GITHUB_APP_ID=123456                                    # From Step 2.6
GITHUB_APP_INSTALLATION_ID=789012                       # From Step 2.9
GITHUB_APP_PRIVATE_KEY_PATH=/etc/github-runner/app-key.pem  # From Step 2.10

# ============================================================================
# Repository Configuration
# ============================================================================
REPO_URL=https://github.com/your-org/your-repo         # Target repository
RUNNER_NAME=docker-runner-prod-01                      # Unique name
LABELS=self-hosted,linux,x64,docker                    # Runner labels

# ============================================================================
# Resource Limits
# ============================================================================
CPU_LIMIT=2.0              # CPU cores (e.g., 2.0 = 2 cores)
CPU_RESERVATION=0.5        # Guaranteed CPU
MEMORY_LIMIT=4g            # RAM limit (e.g., 4g = 4GB)
MEMORY_RESERVATION=1g      # Guaranteed RAM

# ============================================================================
# Docker Configuration
# ============================================================================
ENABLE_DOCKER=true         # Enable Docker-in-Docker
RUNNER_VERSION=2.329.0     # GitHub Actions Runner version

# ============================================================================
# Maintenance
# ============================================================================
CLEANUP_WORKSPACE_DAYS=7   # Clean workspace after N days
CLEANUP_DOCKER_HOURS=24    # Clean Docker images after N hours
```

#### Step 3.3: Validate Configuration

```bash
# Check for required variables
grep -E "^(GITHUB_APP_ID|REPO_URL|RUNNER_NAME)=" config/runner.env

# Verify no syntax errors
source config/runner.env && echo "Configuration is valid"
```

#### Step 3.4: Security Checklist

- [ ] Private key file has 600 permissions
- [ ] Private key is owned by root
- [ ] Configuration file does NOT contain actual secrets (only paths)
- [ ] REPO_URL is correct and accessible
- [ ] App ID and Installation ID are integers

---

### Phase 4: Deployment

#### Step 4.1: Build Docker Image

```bash
cd /opt/github-selfhosted-runner

# Build runner image
docker build \
    --build-arg RUNNER_VERSION=2.329.0 \
    -t github-runner:latest \
    -f docker/Dockerfile \
    docker/
```

**Expected output:**
```
[+] Building 123.4s (15/15) FINISHED
 => [internal] load build definition
 => [internal] load .dockerignore
...
 => exporting to image
 => => naming to docker.io/library/github-runner:latest
```

**Verify image:**
```bash
docker images | grep github-runner
# Should show: github-runner  latest  <image-id>  <size>
```

#### Step 4.2: Deploy Runner

```bash
# Make deploy script executable (if needed)
chmod +x scripts/deploy.sh

# Deploy runner
./scripts/deploy.sh --config config/runner.env
```

**Expected output:**
```
Deploying runner: docker-runner-prod-01
  Repository: https://github.com/your-org/your-repo
  CPU: 2.0 cores
  Memory: 4g

Building Docker image...
[build output...]

Starting container...

✓ Runner deployed successfully

Check status:
  docker logs -f docker-runner-prod-01

Verify on GitHub:
  https://github.com/your-org/your-repo/settings/actions/runners
```

#### Step 4.3: Monitor Startup

```bash
# Follow logs in real-time
docker logs -f docker-runner-prod-01
```

**Successful startup logs:**
```
[RUNNER] Configuration:
[RUNNER]   Repository: https://github.com/your-org/your-repo
[RUNNER]   Runner Name: docker-runner-prod-01
[RUNNER]   Labels: self-hosted,linux,x64,docker
[RUNNER] Using GitHub App authentication
[RUNNER] Configuring runner...
[RUNNER] Runner configured successfully
[RUNNER] Starting runner...
[RUNNER] Runner is now listening for jobs
```

**Press Ctrl+C to exit logs (runner continues running)**

---

### Phase 5: Verification

#### Step 5.1: Check Container Status

```bash
# List running containers
docker ps --filter "name=docker-runner-prod-01"

# Check container health
docker inspect docker-runner-prod-01 --format='{{.State.Health.Status}}'
# Should show: healthy
```

#### Step 5.2: Verify in GitHub UI

1. Navigate to: `https://github.com/YOUR-ORG/YOUR-REPO/settings/actions/runners`
2. Look for runner name: `docker-runner-prod-01`
3. Status should be: **🟢 Idle** (green)
4. Labels should match: `self-hosted, linux, x64, docker`

#### Step 5.3: Run Test Workflow

**Create test workflow in your repository:**

1. In your repository, create `.github/workflows/test-runner.yml`:

```yaml
name: Test Self-Hosted Runner

on:
  workflow_dispatch:  # Manual trigger

jobs:
  test:
    runs-on: [self-hosted, linux, docker]
    steps:
      - name: Check runner
        run: |
          echo "✓ Runner is working!"
          echo "Hostname: $(hostname)"
          echo "User: $(whoami)"
          echo "CPU cores: $(nproc)"
          echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
      
      - name: Test Docker
        run: |
          docker --version
          docker run hello-world
      
      - name: Test Git
        run: |
          git --version
```

2. Commit and push
3. Go to Actions tab
4. Select "Test Self-Hosted Runner"
5. Click "Run workflow"
6. Wait for completion (should be green ✓)

#### Step 5.4: Health Check

If `health-check.sh` script exists:

```bash
./scripts/health-check.sh --name docker-runner-prod-01
```

**Expected output:**
```
Health Check: docker-runner-prod-01
===========================================

Status: ✓ HEALTHY

Container Status:    running
Process Running:     ✓ Yes
Health Check:        healthy
Uptime:              5m 23s
CPU Usage:           2.5%
Memory:              1.2GB / 4GB
Recent Errors (5m):  0
```

---

## Post-Installation

### Enable Monitoring

**Set up basic monitoring:**

```bash
# Check resource usage
watch -n 5 docker stats docker-runner-prod-01

# Monitor logs continuously
docker logs -f docker-runner-prod-01

# Check for errors
docker logs docker-runner-prod-01 2>&1 | grep -i error
```

### Configure Log Rotation

Log rotation is already configured in Docker deployment. Verify:

```bash
docker inspect docker-runner-prod-01 --format='{{.HostConfig.LogConfig}}'
# Should show max-size and max-file settings
```

### Set Up Alerts (Optional)

**Example: Email alert on runner failure**

```bash
# Create monitoring script
cat > /usr/local/bin/check-runner.sh << 'EOF'
#!/bin/bash
if ! docker ps | grep -q docker-runner-prod-01; then
    echo "Runner is down!" | mail -s "Runner Alert" admin@example.com
fi
EOF

chmod +x /usr/local/bin/check-runner.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/check-runner.sh") | crontab -
```

### Backup Configuration

```bash
# Backup config files (without secrets)
tar -czf runner-config-backup-$(date +%Y%m%d).tar.gz \
    config/*.env.template \
    config/examples/

# Store in safe location
mv runner-config-backup-*.tar.gz /backup/
```

---

## Advanced Scenarios

### Multiple Runners for Same Repository

**Use case**: Parallel job execution

```bash
# Deploy 3 runners with lighter resources
for i in {1..3}; do
    ./scripts/deploy.sh \
        --config config/runner.env \
        --name runner-parallel-$i \
        --cpus 1.0 \
        --memory 2g
done

# Verify all runners
docker ps --filter "name=runner-parallel"
```

### Multiple Repositories

**Use case**: Different runners for different projects

```bash
# Create separate configs
cp config/runner.env config/frontend-runner.env
cp config/runner.env config/backend-runner.env

# Edit each config:
# - Different REPO_URL
# - Different RUNNER_NAME
# - Different LABELS (e.g., frontend, backend)

# Deploy each
./scripts/deploy.sh --config config/frontend-runner.env
./scripts/deploy.sh --config config/backend-runner.env
```

### High-Availability Setup

**Use case**: Production workloads requiring redundancy

```bash
# Deploy multiple runners with auto-restart
for i in {1..5}; do
    ./scripts/deploy.sh \
        --config config/runner-prod.env \
        --name runner-ha-$i \
        --cpus 2.0 \
        --memory 4g
done

# Verify restart policy
docker inspect runner-ha-1 --format='{{.HostConfig.RestartPolicy}}'
# Should show: {unless-stopped 0}
```

### Custom Docker Image

**Use case**: Runners with additional tools

```bash
# Create custom Dockerfile
cat > docker/Dockerfile.custom << 'EOF'
FROM github-runner:latest

# Install additional tools
USER root
RUN apt-get update && apt-get install -y \
    nodejs \
    npm \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

USER runner
EOF

# Build custom image
docker build -f docker/Dockerfile.custom -t github-runner:custom .

# Deploy with custom image
# (modify deploy.sh to use github-runner:custom)
```

---

## Troubleshooting

### Runner Not Appearing in GitHub UI

**Symptoms**: Container running, but runner not visible in GitHub

**Diagnosis**:
```bash
# Check logs for errors
docker logs docker-runner-prod-01 | grep -i error

# Verify GitHub App credentials
docker exec docker-runner-prod-01 env | grep GITHUB_APP
```

**Common causes**:
1. Invalid App ID or Installation ID
2. Private key file not accessible
3. Insufficient permissions on GitHub App
4. Network connectivity issues

**Solution**: See [Troubleshooting Guide](troubleshooting.md#runner-not-appearing)

### Container Exits Immediately

**Symptoms**: Container starts then stops

**Diagnosis**:
```bash
# Check exit code
docker inspect docker-runner-prod-01 --format='{{.State.ExitCode}}'

# View last logs
docker logs docker-runner-prod-01
```

**Common causes**:
1. Configuration error
2. Missing private key
3. Invalid REPO_URL

**Solution**: Verify configuration and redeploy

### High Memory Usage

**Symptoms**: Container using excessive memory

**Diagnosis**:
```bash
# Monitor resource usage
docker stats docker-runner-prod-01
```

**Solution**: Increase MEMORY_LIMIT or optimize workflow

### Jobs Not Executing

**Symptoms**: Runner shows "Idle" but jobs don't start

**Check workflow labels**:
```yaml
# Workflow must use correct labels
runs-on: [self-hosted, linux, docker]  # Must match runner labels
```

---

## FAQ

### Q: Can I use Personal Access Token instead of GitHub App?

**A**: Yes, but not recommended. GitHub Apps provide better security with time-limited tokens.

### Q: How do I update the runner version?

**A**: Use the update script (if available) or redeploy with new RUNNER_VERSION:
```bash
# Edit config
sed -i 's/RUNNER_VERSION=.*/RUNNER_VERSION=2.330.0/' config/runner.env

# Redeploy
./scripts/deploy.sh --config config/runner.env
```

### Q: Can I run multiple runners on the same server?

**A**: Yes! Each runner runs in its own container. Just use different names and adjust resource limits.

### Q: What happens if the server reboots?

**A**: Runners auto-start because of `--restart unless-stopped` policy.

### Q: How do I remove a runner?

**A**: Use undeploy script:
```bash
./scripts/undeploy.sh --name docker-runner-prod-01
```

### Q: Can I use this with GitHub Enterprise Server?

**A**: Yes, modify REPO_URL to point to your enterprise instance.

### Q: How secure is this setup?

**A**: Very secure when properly configured:
- Private keys with 600 permissions
- Non-root user in container
- Read-only secret mounts
- Time-limited GitHub App tokens
- Resource limits prevent DoS

---

## Next Steps

After successful installation:

1. **Configure workflows** to use your self-hosted runner
2. **Set up monitoring** for production environments
3. **Review security settings** in [Security Best Practices](../docs/security.md)
4. **Optimize resources** based on actual usage
5. **Plan maintenance windows** for updates

### Related Documentation

- [Configuration Reference](configuration.md) - All configuration options
- [GitHub App Setup](github-app-setup.md) - Detailed GitHub App guide
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
- [Architecture](architecture.md) - System design and components

---

**Installation Complete! 🎉**

Your self-hosted runner is now ready to execute GitHub Actions workflows.
