# GitHub App Setup Guide

Detailed guide for creating and configuring a GitHub App for runner authentication.

## Why GitHub App?

### Advantages over Personal Access Tokens (PAT)

- **Security**: Time-limited tokens (1 hour), automatic rotation
- **Granular Permissions**: Scope to specific repositories
- **Audit Trail**: App-based actions are clearly attributed
- **No User Dependency**: Not tied to a specific user account
- **Rate Limits**: Higher API rate limits
- **Best Practice**: Recommended by GitHub for automation

## Creating a GitHub App

### Step 1: Navigate to GitHub Apps

**For Personal Account:**
1. Go to [https://github.com/settings/apps/new](https://github.com/settings/apps/new)

**For Organization:**
1. Go to your organization: `https://github.com/organizations/YOUR-ORG/settings/apps/new`
2. Replace `YOUR-ORG` with your organization name

### Step 2: Fill in Basic Information

**GitHub App name** (required)
- Format: `github-runner-<your-org-name>`
- Example: `github-runner-acme-corp`
- Must be globally unique across GitHub

**Description** (optional)
- Example: "Self-hosted GitHub Actions runner for ACME Corp repositories"

**Homepage URL** (required)
- Your organization homepage or repository
- Example: `https://github.com/acme-corp`

### Step 3: Webhook Configuration

**Webhook**
- ☑ **Uncheck** "Active"
- Webhooks are not needed for runners

### Step 4: Repository Permissions

Select **Repository permissions**:

**Option A: Administration Permission (Recommended)**
- Actions: `No access`
- Administration: `Read and write`

This gives full control over runners.

**Option B: Actions Permission (Minimal)**
- Actions: `Read and write`
- Administration: `No access`

This is sufficient for registering runners.

**Do NOT grant**:
- Contents, Issues, Pull Requests, or other permissions
- Keep permissions minimal for security

### Step 5: Where can this GitHub App be installed?

**Installation options:**
- 🔘 **Only on this account** (Recommended for private use)
- ◯ Any account (If you want to share the app)

Choose "Only on this account" for internal runners.

### Step 6: Create the App

Click **Create GitHub App**

You'll be redirected to the app settings page.

## App Configuration

### Retrieve App ID

1. On the app settings page, note the **App ID**
2. Located near the top: "App ID: 123456"
3. Save this value - you'll need it in `GITHUB_APP_ID`

### Generate Private Key

1. Scroll down to **Private keys** section
2. Click **Generate a private key**
3. A `.pem` file will download automatically
4. **IMPORTANT**: Store this file securely - it cannot be re-downloaded
5. Rename for clarity: `github-runner-<org>.pem`

**Security Best Practices for Private Key:**
- Never commit to git
- Store in secure location (e.g., `/etc/github-runner/`)
- Set permissions to `600` (owner read/write only)
- Consider using a secrets manager in production
- Rotate periodically (generate new key, update configs)

## Install the App

### Step 1: Navigate to Installation

1. From app settings, click **Install App** in left sidebar
2. Or go to: `https://github.com/settings/apps/YOUR-APP-NAME/installations`

### Step 2: Choose Account

Click **Install** next to:
- Your personal account, or
- Your organization

### Step 3: Repository Access

**Select repositories:**

**Option A: All repositories**
- 🔘 All repositories
- Easiest for managing multiple repos
- Less secure (broad access)

**Option B: Only select repositories** (Recommended)
- ◯ Only select repositories
- Choose specific repositories from dropdown
- More secure (minimal access)
- Must update when adding new repos

Choose repositories where you want to deploy runners.

### Step 4: Confirm Installation

Click **Install**

You'll be redirected to: `https://github.com/settings/installations/INSTALLATION_ID`

### Retrieve Installation ID

**From URL:**
The URL will be: `https://github.com/settings/installations/12345678`

The number `12345678` is your **Installation ID**.

**From API:**
```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/app/installations
```

Save this value - you'll need it in `GITHUB_APP_INSTALLATION_ID`.

## Configuration Summary

You now have three critical values:

```bash
GITHUB_APP_ID=123456                                    # From app settings page
GITHUB_APP_INSTALLATION_ID=789012                       # From installation URL
GITHUB_APP_PRIVATE_KEY_PATH=/etc/github-runner/app-key.pem  # Where you saved the .pem file
```

Add these to your `config/runner.env` file.

## Installing Private Key on Server

```bash
# Create directory
sudo mkdir -p /etc/github-runner

# Copy private key to server
# Option 1: Direct copy (if on same machine)
sudo cp ~/Downloads/github-runner-acme.pem /etc/github-runner/app-key.pem

# Option 2: Transfer from another machine
scp ~/Downloads/github-runner-acme.pem user@server:/tmp/
ssh user@server
sudo mv /tmp/github-runner-acme.pem /etc/github-runner/app-key.pem

# Set correct permissions (CRITICAL!)
sudo chmod 600 /etc/github-runner/app-key.pem
sudo chown root:root /etc/github-runner/app-key.pem

# Verify permissions
ls -la /etc/github-runner/app-key.pem
# Should show: -rw------- 1 root root ... app-key.pem
```

## Verification

### Test JWT Generation

```bash
# Test manually (requires openssl and jq)
./docker/scripts/generate-jwt.sh \
  "$GITHUB_APP_ID" \
  "/etc/github-runner/app-key.pem"
```

Should output a long JWT token string.

### Test Installation Access

```bash
# Get JWT token
JWT=$(./docker/scripts/generate-jwt.sh "$GITHUB_APP_ID" "/etc/github-runner/app-key.pem")

# Get installation access token
curl -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/$GITHUB_APP_INSTALLATION_ID/access_tokens"
```

Should return JSON with `token` field.

## Troubleshooting

### "Failed to generate JWT token"

**Cause**: Private key file not found or wrong permissions

**Solution**:
```bash
# Check file exists
ls -la /etc/github-runner/app-key.pem

# Fix permissions if needed
sudo chmod 600 /etc/github-runner/app-key.pem
```

### "Failed to get installation access token"

**Cause 1**: Invalid App ID
- Verify App ID from app settings page

**Cause 2**: Invalid Installation ID
- Reinstall app and get new installation ID from URL

**Cause 3**: App not installed on repository
- Go to app installations and add the repository

**Cause 4**: Insufficient permissions
- Edit app permissions (Administration or Actions)
- Organization may need to approve permission changes

### "Bad credentials" when registering runner

**Cause**: Installation access token is invalid

**Solution**:
1. Verify all three values (App ID, Installation ID, key path)
2. Check private key file integrity
3. Regenerate private key if necessary

## Security Best Practices

1. **Principle of Least Privilege**
   - Grant only required permissions (Administration OR Actions)
   - Install on specific repositories, not "All repositories"

2. **Key Rotation**
   - Rotate private keys every 90 days
   - Keep old key for 7 days during transition

3. **Access Control**
   - Limit who can access the server where keys are stored
   - Use SSH key authentication for server access
   - Consider using secrets managers (Vault, AWS Secrets Manager)

4. **Monitoring**
   - Monitor app activity in GitHub audit log
   - Alert on unexpected API usage
   - Review runner registrations regularly

5. **Incident Response**
   - If key is compromised, immediately:
     - Revoke the private key in app settings
     - Generate new private key
     - Update all runner deployments
     - Audit recent runner activity

## App Management

### Add Repository to Existing Installation

1. Go to app installation: `https://github.com/settings/installations/INSTALLATION_ID`
2. Click **Configure**
3. Under "Repository access", select additional repositories
4. Click **Save**

### Update Permissions

1. Go to app settings: `https://github.com/settings/apps/YOUR-APP-NAME`
2. Click **Permissions & events**
3. Update permissions
4. Click **Save changes**
5. **Note**: Organization owners may need to approve changes

### Revoke Access

1. Go to app installation: `https://github.com/settings/installations/INSTALLATION_ID`
2. Click **Configure**
3. Click **Uninstall** at bottom
4. Existing runners will stop working

## Next Steps

- [Installation Guide](installation.md) - Deploy your runner
- [Configuration Reference](configuration.md) - Advanced configuration options
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
