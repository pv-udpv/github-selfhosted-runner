# List Runners

Lists all self-hosted GitHub Actions runners for a repository with optional filtering and multiple output formats.

## Usage

```yaml
- name: List All Runners
  id: runners
  uses: ./.github/actions/list-runners
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    repository: 'owner/repo'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|--------|
| `github_token` | GitHub token (PAT or App installation token) | Yes | - |
| `repository` | Target repository (owner/repo) | Yes | - |
| `status_filter` | Filter by status (online/offline/all) | No | `all` |
| `label_filter` | Filter by label (comma-separated) | No | '' |
| `output_format` | Output format (table/json/csv) | No | `table` |

## Outputs

| Output | Description |
|--------|-------------|
| `runners_json` | All runners as JSON array |
| `total_count` | Total number of runners |
| `online_count` | Number of online runners |
| `offline_count` | Number of offline runners |
| `busy_count` | Number of busy runners |

## Examples

### List Online Runners

```yaml
- name: List Online Runners
  uses: ./.github/actions/list-runners
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    repository: ${{ github.repository }}
    status_filter: 'online'
    output_format: 'table'
```

### Filter by Labels

```yaml
- name: List Production Runners
  uses: ./.github/actions/list-runners
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    repository: 'owner/repo'
    label_filter: 'production,linux'
```

### JSON Output

```yaml
- name: Get Runners JSON
  id: runners
  uses: ./.github/actions/list-runners
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    repository: ${{ github.repository }}
    output_format: 'json'

- name: Process Runners
  run: |
    echo '${{ steps.runners.outputs.runners_json }}' | jq '.[] | .name'
```

### Check Runner Count

```yaml
- name: List Runners
  id: list
  uses: ./.github/actions/list-runners
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    repository: ${{ github.repository }}

- name: Verify Capacity
  run: |
    ONLINE=${{ steps.list.outputs.online_count }}
    if [[ $ONLINE -lt 2 ]]; then
      echo "::error::Insufficient runners online: $ONLINE"
      exit 1
    fi
```

## Output Formats

### Table (Default)

| ID | Name | Status | Busy | Labels |
|-----|------|--------|------|--------|
| 123 | runner-01 | online | false | linux, x64 |

### JSON

```json
[
  {
    "id": 123,
    "name": "runner-01",
    "status": "online",
    "busy": false,
    "labels": [{"name": "linux"}, {"name": "x64"}]
  }
]
```

### CSV

```csv
ID,Name,Status,Busy,Labels
123,runner-01,online,false,"linux;x64"
```

## Idempotency

This action is idempotent - it only reads runner information and can be run multiple times safely.
