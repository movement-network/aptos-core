# Binary Cache Setup Guide

This document explains how to configure Nix binary caching so team members can share builds and avoid redundant compilation during PR reviews.

## Overview

With Cachix configured:
1. Developer A builds `aptos-node` and pushes to cache (~30 min)
2. Developer B reviewing the PR pulls the pre-built binary (~30 sec)
3. CI/CD can also populate the cache for main branch builds

## One-Time Admin Setup

**Someone with org admin access needs to do this once:**

### 1. Create the Cachix Cache

1. Go to https://app.cachix.org
2. Sign in with GitHub (use Movement Labs org account)
3. Create a new cache named `movementlabs`
4. Set it as **public** (allows anyone to pull without auth)
5. Note the signing key shown after creation

### 2. Generate Auth Tokens

Create tokens for team members and CI:

1. Go to cache settings → Auth Tokens
2. Create tokens with **Write** permission
3. Distribute tokens securely to team members (1Password recommended)

### 3. Verify the Public Key

The flake uses this public key - verify it matches your cache:

```
movementlabs.cachix.org-1:qqCkWyzFSZCH2TcyHPRXVOOlYR3Sv+4GKMXSZtyN8s=
```

If different, update `nixConfig` in `flake.nix` and `nix/flake.nix`.

## Developer Setup

### Step 1: Add Yourself as Trusted User

On macOS, using group-based trust (`@admin` or `@staff`) is more reliable than individual usernames:

```bash
# For Determinate Nix on macOS (recommended)
# Using groups ensures all admin/staff users are trusted
sudo tee /etc/nix/nix.custom.conf << 'EOF'
trusted-users = root @admin @staff
trusted-substituters = https://cache.flakehub.com https://movementlabs.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= movementlabs.cachix.org-1:qqCkWyzFSZCH2TcyHPRXVOOlYR3Sv+4GKMXSZtyN8s=
accept-flake-config = true
EOF

# For standard Nix on Linux
sudo sh -c 'echo "trusted-users = root @wheel" >> /etc/nix/nix.conf'

# Restart Nix daemon
# macOS:
sudo launchctl stop org.nixos.nix-daemon && sudo launchctl start org.nixos.nix-daemon

# Linux:
sudo systemctl restart nix-daemon
```

**Note**: Using individual usernames (e.g., `trusted-users = root myusername`) may not work reliably on macOS with Determinate Systems' Nix. Using groups (`@admin`, `@staff`, `@wheel`) is the recommended approach.

### Step 2: Install and Configure Cachix CLI

```bash
# Option A: Use via nix shell (no permanent install needed)
nix shell nixpkgs#cachix -c cachix --version

# Option B: Add to your Nix profile (may fail on some systems)
nix profile install nixpkgs#cachix
```

> **Note**: If `nix profile install` fails with "public key is not valid", use option A with `nix shell nixpkgs#cachix -c <command>` instead.

```bash
# Authenticate with your token (get from team lead or 1Password)
cachix authtoken YOUR_AUTH_TOKEN

# Verify authentication
cachix authtoken --check
```

### Step 3: Verify Setup

```bash
# Should not show "untrusted substituter" warnings
nix flake check --no-build
```

## Workflow: Building and Sharing

### Push Your Builds to Cache

After building locally, push to cache so others can pull:

```bash
# Build a package
nix build .#aptos-node -L

# Push the result to cache
cachix push movementlabs ./result

# Or build and push in one command
nix build .#aptos-node -L | cachix push movementlabs
```

### Push All Binaries

```bash
# Build all binaries
nix build .#all-binaries -L

# Push the entire result (includes all 5 binaries)
cachix push movementlabs ./result
```

### Pull from Cache (Automatic)

Once someone has pushed a build, others automatically get it:

```bash
# This will download from cache if available, otherwise build
nix build .#aptos-node -L
```

You'll see cache hits in the output:
```
copying path '/nix/store/xxx-aptos-node-0.1.0' from 'https://movementlabs.cachix.org'...
```

## PR Review Workflow

### For PR Authors

After pushing your PR branch:

```bash
# Build and push so reviewers don't have to build
nix build .#all-binaries -L
cachix push movementlabs ./result

# Add a comment to the PR
echo "Binaries pushed to Cachix - reviewers can pull with: nix build .#all-binaries"
```

### For PR Reviewers

```bash
# Checkout the PR branch
gh pr checkout 123

# Build - will pull from cache if author pushed
nix build .#aptos-node -L

# Test the binary
./result/bin/aptos-node --version
```

## CI/CD Integration

Add to your GitHub Actions workflow:

```yaml
- name: Install Nix
  uses: DeterminateSystems/nix-installer-action@main

- name: Setup Cachix
  uses: cachix/cachix-action@v14
  with:
    name: movementlabs
    authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'

- name: Build and push
  run: |
    nix build .#all-binaries -L
    cachix push movementlabs ./result
```

Store `CACHIX_AUTH_TOKEN` in GitHub repository secrets.

## Troubleshooting

### "Binary cache movementlabs doesn't exist"

The cache hasn't been created yet. See "One-Time Admin Setup" above.

### "Untrusted substituter" Warning

Add yourself to `trusted-users` - see Step 1 in Developer Setup.

### "Permission denied" When Pushing

Your auth token doesn't have write access. Get a new token from an admin.

### Cache Misses (Always Building from Source)

1. The specific derivation hasn't been pushed yet
2. The flake inputs changed (different nixpkgs = different hashes)
3. Check if cache is configured: `nix show-config | grep movementlabs`

### Slow Uploads

Large binaries take time to upload. The `aptos-node` binary is ~200MB+.

```bash
# Check upload progress with verbose output
cachix push movementlabs ./result -v
```

## How It Works

### Nix Store Paths

Each build produces a unique path like:
```
/nix/store/abc123...-aptos-node-0.1.0
```

The hash (`abc123...`) is determined by all inputs - source code, dependencies, build flags. Same inputs = same hash = cache hit.

### Flake Configuration

The `flake.nix` includes:

```nix
nixConfig = {
  extra-substituters = [
    "https://movementlabs.cachix.org"
  ];
  extra-trusted-public-keys = [
    "movementlabs.cachix.org-1:qqCkWyzFSZCH2TcyHPRXVOOlYR3Sv+4GKMXSZtyN8s="
  ];
};
```

This tells Nix to check Cachix before building. Trusted users automatically use these settings.

### Dependency Caching (Crane)

The flake uses crane's `buildDepsOnly` to cache dependencies separately:

```nix
cargoArtifacts = craneLib.buildDepsOnly commonArgs;
```

Benefits:
- Dependencies cached independently of source changes
- Source-only changes rebuild faster even on cache miss
- Multiple binaries share the same dependency cache

## Security Notes

- The public key cryptographically verifies all downloaded artifacts
- Only authenticated users with write tokens can push
- The cache is read-only for unauthenticated users
- Never commit auth tokens to git - use environment variables or secrets managers
