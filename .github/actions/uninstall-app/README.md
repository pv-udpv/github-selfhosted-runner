# Uninstall GitHub App

Removes GitHub App installation from a repository and optionally cleans up associated runners.

## ⚠️ Warning

This is a **STATEFUL** operation that:
- Permanently removes the GitHub App installation
- Optionally deletes all associated runners
- Cannot be automatically reversed

Use with caution, especially in production environments.

## Usage

```yaml
- name: Uninstall GitHub App
  uses: ./.github/actions/uninstall-app
  with:
    app_id: ${{ secrets.GITHUB_APP_ID }}
    private_key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
    repository: 'owner/repo'
    cleanup_runners: 'true'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|--------|
| `app_id` | GitHub App ID | Yes | - |
| `private_key` | GitHub App private key (PEM format) | Yes | - |
| `repository` | Target repository (owner/repo) | Yes | - |
| `installation_id` | Installation ID (auto-detected if not provided) | No | '' |
| `cleanup_runners` | Also remove all associated runners | No | `true` |
| `force` | Force uninstall even if runners are active | No | `false` |

## Outputs

| Output | Description |
|--------|-------------|
| `success` | Whether uninstall was successful (true/false) |
| `removed_runners` | Number of runners removed |
| `installation_id` | Installation ID that was removed |

## State Management

### Stateful Operations

This action performs the following **irreversible** state changes:

1. **Removes GitHub App installation**
   - Revokes all app permissions
   - Removes app from repository settings
   - Deletes installation access tokens

2. **Deletes runners** (if `cleanup_runners: true`):
   - Unregisters runners from GitHub
   - Removes runner tokens
   - Cleans up runner metadata

### Safety Checks

- **Busy runner protection**: Refuses to remove busy runners unless `force: true`
- **Auto-detection**: Automatically finds installation ID if not provided
- **Graceful handling**: Returns success if app is already uninstalled

## Examples

### Basic Uninstall

```yaml
- name: Uninstall App
  uses: ./.github/actions/uninstall-app
  with:
    app_id: ${{ secrets.APP_ID }}
    private_key: ${{ secrets.PRIVATE_KEY }}
    repository: ${{ github.repository }}
```

### Keep Runners

```yaml
- name: Uninstall App But Keep Runners
  uses: ./.github/actions/uninstall-app
  with:
    app_id: ${{ secrets.APP_ID }}
    private_key: ${{ secrets.PRIVATE_KEY }}
    repository: 'owner/repo'
    cleanup_runners: 'false'
```

### Force Uninstall

```yaml
- name: Force Uninstall (Even with Active Runners)
  uses: ./.github/actions/uninstall-app
  with:
    app_id: ${{ secrets.APP_ID }}
    private_key: ${{ secrets.PRIVATE_KEY }}
    repository: 'owner/repo'
    force: 'true'
```

### With Pre-checks

```yaml
jobs:
  safe-uninstall:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # Check runner status first
      - name: List Runners
        id: runners
        uses: ./.github/actions/list-runners
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          repository: ${{ github.repository }}
      
      # Abort if any runners are busy
      - name: Check for Busy Runners
        run: |
          if [[ ${{ steps.runners.outputs.busy_count }} -gt 0 ]]; then
            echo "::error::Cannot uninstall: ${{ steps.runners.outputs.busy_count }} runners are busy"
            exit 1
          fi
      
      # Proceed with uninstall
      - name: Uninstall App
        uses: ./.github/actions/uninstall-app
        with:
          app_id: ${{ secrets.APP_ID }}
          private_key: ${{ secrets.PRIVATE_KEY }}
          repository: ${{ github.repository }}
```

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "App is not installed" | App already removed | No action needed (idempotent) |
| "Runners are busy" | Active jobs running | Wait or use `force: true` |
| "Failed to get access token" | Invalid credentials | Check `app_id` and `private_key` |
| "Failed to uninstall app" | Permission issue | Verify app has admin permissions |

## Idempotency

This action is **partially idempotent**:
- ✅ Safe to run if app is already uninstalled (returns success)
- ⚠️ Removes runners on each run if `cleanup_runners: true`
- ❌ Cannot reverse the uninstallation

## Related Actions

- `validate-app-permissions` - Check permissions before uninstall
- `list-runners` - List runners before cleanup
- `check-runner-status` - Verify runner status before removal

## Security Considerations

1. **Credentials**: Store `app_id` and `private_key` in GitHub Secrets
2. **Permissions**: Requires GitHub App with admin permissions
3. **Audit**: Operation is logged in GitHub audit log
4. **Reversibility**: Manual reinstallation required to restore
