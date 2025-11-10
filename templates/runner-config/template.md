# Runner Configuration: {{RUNNER_NAME}}

## Overview
This runner is configured for repository **{{REPO_URL}}**.

## Authentication
- **GitHub App ID**: {{GITHUB_APP_ID}}
- **Installation ID**: {{GITHUB_APP_INSTALLATION_ID}}
- **Private Key**: {{GITHUB_APP_PRIVATE_KEY_PATH}}

## Runner Settings
- **Name**: {{RUNNER_NAME}}
- **Labels**: {{LABELS}}
- **Work Directory**: {{RUNNER_WORKDIR}}

## Resource Limits
- **CPU**: {{CPU_LIMIT}} cores (reserved: {{CPU_RESERVATION}})
- **Memory**: {{MEMORY_LIMIT}} (reserved: {{MEMORY_RESERVATION}})
- **Disk**: {{DISK_LIMIT}}

## Docker Configuration
- **Docker Enabled**: {{ENABLE_DOCKER}}
- **Runner Version**: {{RUNNER_VERSION}}

## Maintenance
- **Workspace Cleanup**: Every {{CLEANUP_WORKSPACE_DAYS}} days
- **Docker Cleanup**: Every {{CLEANUP_DOCKER_HOURS}} hours

## Deployment Command

```bash
./scripts/deploy.sh --config config/{{RUNNER_NAME}}.env
```

## Verify

```bash
docker logs -f {{RUNNER_NAME}}
./scripts/health-check.sh --name {{RUNNER_NAME}}
```

---
**Generated on**: {{GENERATED_DATE}}
**Template Version**: {{TEMPLATE_VERSION}}
