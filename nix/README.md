# Aptos Core Nix Build System

This directory contains the Nix flake for building Aptos Core. The build system uses [crane](https://github.com/ipetkov/crane) with [rust-overlay](https://github.com/oxalica/rust-overlay) for reproducible Rust builds.

## Architecture

```
nix/
├── flake.nix         # Nix flake - package definitions, dev shell
├── flake.lock        # Locked dependencies
└── README.md         # This file
```

The root `flake.nix` is a symlink to `nix/flake.nix`. All source paths in the flake use `./..` to reference the repo root.

### Why crane?

Standard nixpkgs `buildRustPackage` / `fetchCargoVendor` can't handle two git crates with the same name and version from different repos (e.g., `aptos-moving-average-0.1.0` from both `aptos-indexer-processors` and `aptos-indexer-processor-sdk`). Crane vendors by repo+revision, avoiding collisions.

### Build phases

Crane splits the build into two phases for better caching:

1. **`buildDepsOnly`** - Builds all workspace dependencies (cached separately)
2. **`buildPackage`** - Builds the specific crate (fast rebuild on source changes)

## Packages

| Package | Binary | Description |
|---------|--------|-------------|
| `aptos-node` | `aptos-node` | Main Aptos node |
| `movement` | `movement` | Movement CLI |
| `l1-migration` | `l1-migration` | L1 migration tool |
| `aptos-faucet-service` | `aptos-faucet-service` | Faucet service |
| `aptos-transaction-emitter` | `aptos-transaction-emitter` | Transaction load tool |
| `all-binaries` | (all above) | symlinkJoin of all 5 |

## Usage

```bash
# Build all binaries
nix build .#all-binaries -L

# Build individual binary
nix build .#aptos-node

# Enter dev shell
nix develop

# Run aptos-node
nix run .#aptos-node
```

## Inputs

| Input | Source | Purpose |
|-------|--------|---------|
| `nixpkgs` | `nixos-unstable` | System packages (openssl, rocksdb, etc.) |
| `flake-utils` | `numtide/flake-utils` | `eachDefaultSystem` helper |
| `rust-overlay` | `oxalica/rust-overlay` | Rust toolchain from `rust-toolchain.toml` |
| `crane` | `ipetkov/crane` | Rust build framework |

## Environment Variables

The flake configures these for the build:

- `LIBCLANG_PATH` - libclang for bindgen
- `BINDGEN_EXTRA_CLANG_ARGS` - Include paths for bindgen
- `ROCKSDB_LIB_DIR` - System RocksDB library
- `LD_LIBRARY_PATH` - Runtime library search path

**Note**: `JEMALLOC_OVERRIDE` is intentionally NOT set for package builds. The dev shell sets it for faster cargo builds, but package builds let `jemalloc-sys` compile from source with the correct `_rjem_` prefix.

## Updating Dependencies

```bash
nix flake update
```

## See Also

- [Nix Build Guide](../docs/nix-build-guide.md) - Comprehensive guide with testing, Docker, Cachix, and K8s validation
- [README.md](../README.md) - Quick start
