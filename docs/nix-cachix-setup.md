# Cachix Setup Guide

This document explains how to set up Cachix for binary caching, which significantly speeds up Nix builds by pulling pre-built artifacts instead of compiling from source.

## What is Cachix?

[Cachix](https://cachix.org) is a binary cache service for Nix. When properly configured:

1. **CI builds** push compiled binaries to Cachix
2. **Local builds** pull pre-built binaries from Cachix
3. **Build times** are reduced from hours to minutes

Movement Labs maintains a Cachix cache at `movementlabsxyz` for aptos-core and related repositories.

## Quick Setup

### One-Time Setup

```bash
# 1. Install Cachix CLI
nix profile install nixpkgs#cachix

# 2. Configure the Movement Labs cache
cachix use movementlabsxyz
```

That's it! Your Nix installation will now automatically check Cachix for cached binaries.

### Verify Setup

After setup, Cachix substituters should be in your Nix configuration:

```bash
# Check current substituters
nix show-config | grep substituters
```

You should see `https://movementlabsxyz.cachix.org` in the list.

## How Cachix Works

### Build Flow

```
Developer runs: nix build .#aptos-node
         |
         v
    +----------+
    |   Nix    |  1. Check local store (/nix/store/)
    +----------+
         |
         v (not found locally)
    +----------+
    |  Cachix  |  2. Check Cachix cache
    +----------+
         |
         v (found in cache)
    Download pre-built binary
         |
         v (not found in cache)
    Build from source
```

### Cache Hits vs Misses

- **Cache Hit**: Binary found in Cachix, downloaded in seconds
- **Cache Miss**: Must compile from source, takes 15-60+ minutes

The flake is configured to automatically check Cachix before building.

## Manual Configuration (Alternative)

If `cachix use` doesn't work or you prefer manual configuration:

### Option 1: System-wide Configuration

Add to `/etc/nix/nix.conf`:

```ini
substituters = https://cache.nixos.org https://movementlabsxyz.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= movementlabsxyz.cachix.org-1:ap2x2pbuuPk8hJr3B7jkXiP32UvJWpcmQ38RVB4P0cU=
```

Then restart the Nix daemon:

```bash
# macOS
sudo launchctl stop org.nixos.nix-daemon
sudo launchctl start org.nixos.nix-daemon

# Linux
sudo systemctl restart nix-daemon
```

### Option 2: User-level Configuration

Add to `~/.config/nix/nix.conf`:

```ini
extra-substituters = https://movementlabsxyz.cachix.org
extra-trusted-public-keys = movementlabsxyz.cachix.org-1:ap2x2pbuuPk8hJr3B7jkXiP32UvJWpcmQ38RVB4P0cU=
```

### Option 3: Per-command Configuration

Use `--accept-flake-config` flag to accept the Cachix configuration from the flake:

```bash
nix build .#aptos-node --accept-flake-config
```

The flake.nix includes Cachix configuration, but Nix may not trust it by default.

## Trusting the Cachix Cache

If you see warnings about "ignoring untrusted substituter", you need to trust the cache:

### Option A: Accept Flake Config

```bash
nix build .#aptos-node --accept-flake-config -L
```

### Option B: Add to Trusted Settings

Edit `/etc/nix/nix.conf` and ensure your user is trusted:

```ini
trusted-users = root @wheel @admin your-username
```

Then restart the Nix daemon.

## Verifying Cache Usage

### Check for Cache Hits During Build

When running a build with `-L` flag, you'll see output like:

```
copying path '/nix/store/xxx-aptos-node-0.1.0' from 'https://movementlabsxyz.cachix.org'...
```

This indicates a cache hit!

### Manual Cache Check

```bash
# Check if a specific derivation is cached
nix path-info --store https://movementlabsxyz.cachix.org /nix/store/xxx-aptos-node-0.1.0
```

## Cache Freshness

The Cachix cache is populated when:

1. **CI/CD runs**: Automated builds push artifacts to Cachix
2. **New releases**: Tagged releases are built and cached
3. **Main branch updates**: Commits to main are built and cached

If you're building a very recent commit that hasn't been cached yet, you may experience a cache miss and need to build from source.

## Troubleshooting

### "Untrusted substituter" Warning

This means Nix doesn't trust the Cachix URL. Solutions:

1. Use `--accept-flake-config` flag
2. Add your user to `trusted-users` in `/etc/nix/nix.conf`
3. Manually add Cachix to `trusted-substituters`

### No Cache Hits

If builds always compile from source:

1. Verify Cachix is configured: `nix show-config | grep cachix`
2. Ensure you're building the same commit that was cached
3. Check network connectivity to `cachix.org`

### Slow Downloads from Cachix

If downloads are slow:

1. Check your network connection
2. Try a different network (VPN might slow it down)
3. Cachix servers are primarily in Europe

### Cache Authentication Errors

For public caches like `movementlabsxyz`, no authentication is needed for pulling. If you see auth errors:

1. Check your Cachix CLI version: `cachix --version`
2. Reinstall Cachix: `nix profile remove cachix && nix profile install nixpkgs#cachix`

## Advanced: Pushing to Cachix (CI/CD)

For CI/CD pipelines that need to push to Cachix:

```bash
# Authenticate (requires CACHIX_AUTH_TOKEN)
cachix authtoken $CACHIX_AUTH_TOKEN

# Push build results
nix build .#aptos-node
cachix push movementlabsxyz ./result
```

Note: Pushing requires write access to the cache (organization membership).

## Cache Configuration in flake.nix

The flake already includes Cachix configuration:

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

This means the cache will be used automatically if you trust flake configs.

## Security Considerations

- The Cachix public key ensures downloaded binaries are authentic
- Never add untrusted public keys to your Nix configuration
- Movement Labs signs all artifacts pushed to the cache
- The cache is read-only for non-authenticated users

## Resources

- [Cachix Documentation](https://docs.cachix.org/)
- [Cachix Organization Dashboard](https://app.cachix.org/organization/movementlabsxyz)
- [Nix Binary Cache Guide](https://nixos.wiki/wiki/Binary_Cache)
