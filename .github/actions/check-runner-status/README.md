# Check Runner Status

Checks if a self-hosted GitHub Actions runner is online, offline, or busy.

## Usage

```yaml
- name: Check Runner Status
  id: status
  uses: ./.github/actions/check-runner-status
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    repository: 'owner/repo'
    runner_name: 'my-runner'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|--------|
| `github_token` | GitHub token (PAT or App installation token) | Yes | - |
| `repository` | Target repository (owner/repo) | Yes | - |
| `runner_name` | Runner name to check | No | '' |
| `runner_id` | Runner ID to check (takes precedence) | No | '' |

## Outputs

| Output | Description |
|--------|-------------|
| `status` | Runner status (online/offline/busy/not_found) |
| `runner_id` | Runner ID |
| `runner_name` | Runner name |
| `busy` | Whether runner is executing a job (true/false) |
| `labels` | Runner labels (JSON array) |

## Examples

### Check by Name

```yaml
- name: Check Runner by Name
  id: check
  uses: ./.github/actions/check-runner-status
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    repository: ${{ github.repository }}
    runner_name: 'production-runner-01'

- name: Handle offline runner
  if: steps.check.outputs.status != 'online'
  run: echo "Runner is not online: ${{ steps.check.outputs.status }}"
```

### Check by ID

```yaml
- name: Check Runner by ID
  uses: ./.github/actions/check-runner-status
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    repository: 'owner/repo'
    runner_id: '12345'
```

### Wait for Runner

```yaml
- name: Wait for Runner Online
  shell: bash
  run: |
    for i in {1..30}; do
      STATUS=$(gh api repos/${{ github.repository }}/actions/runners \
        | jq -r '.runners[] | select(.name=="my-runner") | .status')
      
      if [[ "$STATUS" == "online" ]]; then
        echo "✅ Runner is online"
        exit 0
      fi
      
      echo "Waiting for runner... ($i/30)"
      sleep 10
    done
    
    echo "::error::Runner did not come online"
    exit 1
```

## Idempotency

This action is idempotent - it only reads runner status and can be run multiple times safely.
