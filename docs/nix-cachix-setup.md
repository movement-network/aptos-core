# Binary Cache Setup Guide

This document explains how to configure Nix to use the Movement Labs binary cache, which speeds up builds by downloading pre-built artifacts.

## Quick Setup (Recommended)

### Step 1: Add Yourself as a Trusted User

The flake includes cache configuration, but Nix needs to trust your user to use it.

**For Determinate Nix (macOS/Linux):**

```bash
# Add yourself as a trusted user
sudo sh -c 'echo "trusted-users = root $(whoami)" >> /etc/nix/nix.custom.conf'

# Restart the Nix daemon
# macOS:
sudo launchctl stop org.nixos.nix-daemon
sudo launchctl start org.nixos.nix-daemon

# Linux:
sudo systemctl restart nix-daemon
```

**For standard Nix installations:**

```bash
# Edit the main config file
sudo nano /etc/nix/nix.conf

# Add this line (replace YOUR_USERNAME):
trusted-users = root YOUR_USERNAME

# Restart the daemon (same commands as above)
```

### Step 2: Verify Setup

```bash
# Should show your username
nix show-config | grep trusted-users

# Test a build - should not show "untrusted substituter" warnings
nix flake check --no-build
```

## How It Works

The `flake.nix` includes this configuration:

```nix
nixConfig = {
  extra-substituters = [
    "https://movementlabsxyz.cachix.org"
  ];
  extra-trusted-public-keys = [
    "movementlabsxyz.cachix.org-1:ap2x2pbuuPk8hJr3B7jkXiP32UvJWpcmQ38RVB4P0cU="
  ];
};
```

When you're a trusted user, Nix automatically uses these substituters to check for pre-built binaries before compiling from source.

## Alternative: Per-Command Flag

If you don't want to modify system config, use `--accept-flake-config`:

```bash
nix build .#aptos-node --accept-flake-config -L
```

This trusts the flake's cache settings for that command only.

## Cache Status

**Current Status**: The `movementlabsxyz` Cachix cache is being set up. Until CI/CD populates it with builds, you'll need to build from source (15-60+ minutes for first build).

Once the cache is populated:
- Subsequent builds will download pre-built binaries in seconds
- The flake's dependency caching (via crane) means even cache misses are faster

## Verifying Cache Hits

When building with `-L` flag, cache hits show:

```
copying path '/nix/store/xxx-aptos-node-0.1.0' from 'https://movementlabsxyz.cachix.org'...
```

Cache misses show compilation output instead.

## Troubleshooting

### "Untrusted substituter" Warning

```
warning: ignoring untrusted substituter 'https://movementlabsxyz.cachix.org'
```

**Fix**: Add yourself to `trusted-users` (see Step 1 above).

### "Not a trusted user" Warning

```
warning: you are not a trusted user
```

**Fix**: Same as above - add yourself to `trusted-users` and restart the daemon.

### Cache Misses (Building from Source)

If builds compile from source even after cache setup:

1. The commit you're building may not be cached yet
2. Check network connectivity: `curl -I https://movementlabsxyz.cachix.org`
3. Verify substituters are configured: `nix show-config | grep substituters`

## For CI/CD: Pushing to Cache

To populate the cache from CI:

```bash
# Install Cachix
nix profile install nixpkgs#cachix

# Authenticate (requires CACHIX_AUTH_TOKEN secret)
cachix authtoken $CACHIX_AUTH_TOKEN

# Build and push
nix build .#aptos-node -L
cachix push movementlabsxyz ./result
```

Note: Pushing requires organization membership and an auth token.
