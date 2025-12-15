# Nix Build Setup Guide

This document explains how to set up your development environment for building Aptos Core using Nix and the reproducible build system.

## Overview

The Aptos Core build system supports two approaches:

1. **Cargo builds** (via `nix develop`): Fast iteration during development
2. **Nix builds** (via `nix build`): Reproducible builds with Cachix caching

The Nix build approach is recommended for production builds as it:

- Produces bit-for-bit reproducible builds
- Leverages Cachix for binary caching (avoiding recompilation)
- Ensures consistent builds across different machines
- Can be easily integrated into CI/CD pipelines

## Prerequisites

### 1. Install Nix

We recommend using the Determinate Systems installer, which sets up Nix with flakes enabled by default:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

After installation, restart your shell or run:

```bash
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

Verify Nix is installed:

```bash
nix --version
```

### 2. Enable Flakes (if not using Determinate Systems installer)

If you used a different Nix installer, you may need to enable flakes manually.

Add to `~/.config/nix/nix.conf`:

```ini
experimental-features = nix-command flakes
```

Or use the command-line flag: `nix --extra-experimental-features "nix-command flakes" ...`

### 3. Install Just (optional but recommended)

Just is a command runner that simplifies build commands:

```bash
# With Nix
nix profile install nixpkgs#just

# Or with Homebrew (macOS)
brew install just

# Or with Cargo
cargo install just
```

## Quick Start

### Building with Nix (Recommended for Production)

```bash
# Clone the repository
git clone https://github.com/movementlabsxyz/aptos-core.git
cd aptos-core

# Build a single binary (reproducible, cached)
just build-nix aptos-node

# Build all binaries
just build-all-nix

# The binary will be available at ./result/bin/<binary-name>
./result/bin/aptos-node --version
```

### Development Workflow

```bash
# Enter the development shell (with all build tools)
just dev

# Build with cargo for fast iteration
cargo build -p aptos-node

# Run tests
cargo test
```

## Available Build Targets

### Binary Packages

| Target | Description | Command |
|--------|-------------|---------|
| `aptos-node` | Main Aptos validator/fullnode binary | `just build-nix aptos-node` |
| `movement` | Movement CLI tool (renamed from aptos) | `just build-nix movement` |
| `l1-migration` | L1 migration utility | `just build-nix l1-migration` |
| `aptos-faucet-service` | Faucet service for test networks | `just build-nix aptos-faucet-service` |
| `aptos-transaction-emitter` | Transaction testing/benchmarking tool | `just build-nix aptos-transaction-emitter` |
| `all-binaries` | All five binaries combined | `just build-all-nix` |

### Container Images

| Target | Description | Command |
|--------|-------------|---------|
| `container-aptos-node` | Node container (includes aptos-node, movement, l1-migration) | `just container-nix aptos-node` |
| `container-aptos-faucet-service` | Faucet service container | `just container-nix aptos-faucet-service` |

Note: Container builds are only available on Linux systems.

## Direct Nix Commands

If you prefer using Nix commands directly instead of Just:

```bash
# Build a specific binary
nix build .#aptos-node -L

# Build all binaries
nix build .#all-binaries -L

# Build a container image (Linux only)
nix build .#container-aptos-node -L

# Enter development shell
nix develop

# Run a binary directly
nix run .#aptos-node -- --version

# Show all available packages
nix flake show
```

## Platform Support

The build system supports:

- **aarch64-darwin** (Apple Silicon Macs)
- **x86_64-linux** (Linux x86_64)

Platform-specific notes:

- **macOS**: Container builds are not available (containers require Linux)
- **Linux**: Full feature support including container builds

## Cachix Integration

For faster builds via binary caching, see [Cachix Setup Guide](./nix-cachix-setup.md).

## Troubleshooting

### Nix daemon not running

If you see "error: cannot connect to daemon":

```bash
# macOS
sudo launchctl start org.nixos.nix-daemon

# Linux
sudo systemctl start nix-daemon
```

### Permission denied errors

Ensure your user is in a trusted group. On macOS with Determinate Systems' Nix, configure trusted users in `/etc/nix/nix.custom.conf`:

```bash
# macOS with Determinate Nix (recommended)
sudo tee /etc/nix/nix.custom.conf << 'EOF'
trusted-users = root @admin @staff
trusted-substituters = https://cache.flakehub.com https://movementlabs.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= movementlabs.cachix.org-1:qqCkWyzFSZCH2TcyHPRXVOOlYR3Sv+4GKMXSZtyN8s=
accept-flake-config = true
EOF

# Linux with standard Nix
sudo sh -c 'echo "trusted-users = root @wheel" >> /etc/nix/nix.conf'
```

**Important**: On macOS, using groups (`@admin`, `@staff`) is more reliable than individual usernames.

Then restart the Nix daemon:

```bash
# macOS
sudo launchctl stop org.nixos.nix-daemon && sudo launchctl start org.nixos.nix-daemon

# Linux
sudo systemctl restart nix-daemon
```

### Darwin framework linking errors (macOS)

If you see framework-related errors on macOS, ensure Xcode command line tools are installed:

```bash
xcode-select --install
```

### Disk space issues

Nix stores build artifacts in `/nix/store`. To clean up old generations:

```bash
# Remove old generations (keeps last 7 days)
nix-collect-garbage --delete-older-than 7d

# Remove all unreachable paths
nix-collect-garbage -d
```

### Build taking too long

Without Cachix configured, builds must compile everything from source. Set up Cachix (see [Cachix Setup Guide](./nix-cachix-setup.md)) to pull pre-built binaries.

## Understanding the Build System

### File Structure

- `nix/flake.nix` - Main Nix flake defining packages and development shells
- `flake.lock` - Locked input versions for reproducibility
- `Justfile` - Command runner recipes for common tasks
- `rust-toolchain.toml` - Rust version specification (1.86.0)

### How Crane Works

The build system uses [Crane](https://github.com/ipetkov/crane) for Rust builds:

1. **Dependency caching**: `craneLib.buildDepsOnly` builds all dependencies once
2. **Incremental builds**: Only recompiles changed source code
3. **Binary caching**: Built artifacts can be cached in Cachix
4. **Platform handling**: Automatically handles Darwin/Linux differences

### Build Artifacts

- **Development builds**: Stored in `target/` (not reproducible)
- **Nix builds**: Stored in `/nix/store/` and symlinked to `result/`

## Next Steps

1. Set up [Cachix](./nix-cachix-setup.md) for faster builds
2. Run `just help` to see all available commands
3. Run `just list-binaries` for detailed build target information
