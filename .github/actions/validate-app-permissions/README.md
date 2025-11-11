# Validate GitHub App Permissions

Verifies that a GitHub App has the required permissions for runner management operations.

## Usage

```yaml
- name: Validate App Permissions
  uses: ./.github/actions/validate-app-permissions
  with:
    app_id: ${{ secrets.GITHUB_APP_ID }}
    private_key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
    repository: 'owner/repo'
    required_permissions: 'actions:write,administration:write,metadata:read'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|--------|
| `app_id` | GitHub App ID | Yes | - |
| `private_key` | GitHub App private key (PEM format) | Yes | - |
| `repository` | Target repository (owner/repo) | Yes | - |
| `required_permissions` | Comma-separated list of required permissions | No | `actions:write,administration:write,metadata:read` |

## Outputs

| Output | Description |
|--------|-------------|
| `valid` | Whether app has all required permissions (true/false) |
| `missing_permissions` | List of missing permissions (if any) |
| `installation_id` | GitHub App installation ID |

## Required Permissions

The GitHub App must have these permissions installed on the repository:

- **actions**: write (to manage runners)
- **administration**: write (to register/unregister runners)
- **metadata**: read (to access repository information)

## Examples

### Basic Usage

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Validate Permissions
        id: validate
        uses: ./.github/actions/validate-app-permissions
        with:
          app_id: ${{ secrets.APP_ID }}
          private_key: ${{ secrets.PRIVATE_KEY }}
          repository: ${{ github.repository }}
      
      - name: Check result
        if: steps.validate.outputs.valid == 'true'
        run: echo "✅ Permissions validated"
```

### Custom Permissions

```yaml
- name: Validate Custom Permissions
  uses: ./.github/actions/validate-app-permissions
  with:
    app_id: ${{ secrets.APP_ID }}
    private_key: ${{ secrets.PRIVATE_KEY }}
    repository: 'owner/repo'
    required_permissions: 'actions:write,contents:read,issues:write'
```

## Error Handling

- Returns exit code 1 if validation fails
- Sets `valid=false` output
- Lists missing permissions in `missing_permissions` output
- Provides detailed error messages via GitHub Actions annotations

## Idempotency

This action is idempotent - it only reads permissions and can be run multiple times safely.
