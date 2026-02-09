# Nix Build Guide for Aptos Core

Comprehensive guide for building, testing, and deploying aptos-core using Nix.

## Table of Contents

- [Setup](#setup)
- [Building Locally](#building-locally)
- [Docker Images](#docker-images)
- [Cachix (Binary Cache)](#cachix-binary-cache)
- [Testing Locally](#testing-locally)
- [Testing on amd64 Linux (K8s)](#testing-on-amd64-linux-k8s)
- [CI/CD](#cicd)
- [Troubleshooting](#troubleshooting)

---

## Setup

### Install Nix

Use the [Determinate Systems installer](https://determinate.systems/nix/) (works on both macOS and Linux):

```bash
just install-nix
# or manually:
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Restart your shell after installation.

### Install 1Password CLI (for Cachix push access)

The `op` CLI fetches the Cachix auth token from the `cachix` vault.

```bash
just install-op
# or manually on macOS:
brew install --cask 1password-cli
```

Sign in after installing:

```bash
op signin
```

### Setup Cachix

**Option 1: Token file (preferred for local dev)**

1. Go to https://app.cachix.org/cache/movement-m1 -> Settings -> Auth Tokens
2. Generate a new token (or get one from a teammate)
3. Save it:

```bash
echo 'YOUR_TOKEN' > .cachix-token   # gitignored, never committed
just setup-cachix
```

**Option 2: 1Password (Move Industries account)**

```bash
op signin --account moveindustries.1password.com
just setup-cachix   # falls back to op://team-move-dev/CACHIX_AUTH_TOKEN/credential
```

`just setup-cachix` reads from `.cachix-token` first, then 1Password as fallback.

To pull from the cache (no auth needed):

```bash
cachix use movement-m1
```

---

## Building Locally

The flake provides 5 individual packages and an aggregate:

| Package | Description |
|---------|-------------|
| `aptos-node` | Main Aptos node binary |
| `movement` | Movement CLI (renamed from `aptos`) |
| `l1-migration` | L1 migration tool |
| `aptos-faucet-service` | Faucet service for test networks |
| `aptos-transaction-emitter` | Transaction testing/load generation tool |
| `all-binaries` | All 5 binaries via symlinkJoin |

### Build all binaries

```bash
nix build .#all-binaries -L
ls result/bin/
# aptos-node  movement  l1-migration  aptos-faucet-service  aptos-transaction-emitter
```

### Build individual binaries

```bash
nix build .#aptos-node
nix build .#movement
nix build .#l1-migration
nix build .#aptos-faucet-service
nix build .#aptos-transaction-emitter
```

### Development shell (cargo builds)

For faster iteration during development, use the Nix dev shell which provides all system dependencies:

```bash
nix develop
# or via just:
just dev

# Then build with cargo:
cargo build -p aptos-node
just build aptos-node release
```

### List all build targets

```bash
just list-binaries
```

---

## Docker Images

Build a Linux amd64 container using Docker buildx. This works on macOS/Apple Silicon by building inside Docker's Linux VM using Nix.

```bash
# Build with git short SHA as tag
just container-buildx aptos-node

# Build with a specific tag
just container-buildx aptos-node v1.0

# Test the image locally (note: may not run on ARM macOS due to amd64 binary)
docker run --rm ghcr.io/movementlabsxyz/aptos-node:<tag> --version
```

The `Dockerfile.nix` (at `docker/aptos-node/Dockerfile.nix`) uses a multi-stage build:
1. **Stage 1**: Installs Nix in a Linux container and builds all binaries
2. **Stage 2**: Copies just the binaries into a minimal Debian runtime image

---

## Cachix (Binary Cache)

Pre-built binaries are shared via [Cachix](https://app.cachix.org/cache/movement-m1).

- **Cache name**: `movement-m1`
- **Public key**: `movement-m1.cachix.org-1:S/LYIoBq5MoEE8L4WY3ITVzrJYJo+Tmbx/lP3EORmgY=`
- **Auth token**: `.cachix-token` file (gitignored) or 1Password `op://team-move-dev/CACHIX_AUTH_TOKEN/credential` (Move Industries account)

### Push builds to cache

```bash
just setup-cachix       # One-time setup (reads .cachix-token or 1Password)
just cache-push-all     # Build and push all 5 binaries
just cache-push aptos-node  # Push a single binary
```

### Pull from cache (no auth needed)

```bash
cachix use movement-m1
# Then builds will automatically use cached artifacts
nix build .#aptos-node  # Fast if already in cache
```

### Check setup status

```bash
just cache-status
```

### Cross-platform caching

arm64 macOS and amd64 Linux produce separate derivations. Both are cached independently. If you build on macOS, your cache entries won't help Linux builds (and vice versa). CI builds on amd64 Linux, populating the cache for that platform.

---

## Testing Locally

### Test all nix builds (arm64 macOS)

Builds all 5 binaries and verifies `--version` works:

```bash
just test-nix-build
# or directly:
bash scripts/test-nix-build.sh
```

### Test cachix push

Builds all binaries, pushes to cachix, and verifies narinfo exists:

```bash
just test-cachix
# or directly:
bash scripts/test-cachix.sh
```

---

## Testing on amd64 Linux (K8s)

Docker images built on macOS target `linux/amd64`. To validate they actually work on real amd64 Linux hardware (not just Rosetta/QEMU), we use a K8s devNet cluster.

**No nix building happens on K8s** - the job just pulls the Docker image from GHCR and runs `--version` checks on the binaries.

### Full workflow

```bash
# 1. Build the Docker image locally
just container-buildx aptos-node

# 2. Push to GHCR
docker push ghcr.io/movementlabsxyz/aptos-node:<tag>

# 3. Setup K8s namespace
just k8s-setup

# 4. Submit validation job
just k8s-test-docker <tag>

# 5. Monitor
just k8s-test-logs
just k8s-test-status
```

### All-in-one

```bash
just k8s-test-e2e
# or with a specific tag:
just k8s-test-e2e v1.0
```

### Available K8s commands

| Command | Description |
|---------|-------------|
| `just k8s-setup` | Create `nix-build-test` namespace |
| `just k8s-test-docker <tag>` | Submit validation job |
| `just k8s-test-logs` | Stream job logs |
| `just k8s-test-status` | Check job/pod status |
| `just k8s-test-cleanup` | Delete all test jobs |
| `just k8s-test-e2e` | Build, push, validate end-to-end |

### Environment variables

The K8s scripts respect these environment variables:

- `K8S_CONTEXT` - kubectl context (default: `devNet`)
- `K8S_NAMESPACE` - namespace (default: `nix-build-test`)

---

## CI/CD

CI is defined in `.github/workflows/build-versions.yaml`. On every push:

1. **setup** - Computes git SHA, branch, tag, build date
2. **cachix-push** - Builds all 5 binaries with Nix and pushes to Cachix (amd64 Linux)
3. **binaries-aptos-node** - Builds `aptos-node`, `movement`, `l1-migration` via Nix
4. **container-aptos-node** - Builds and pushes Docker image to GHCR
5. **binaries-aptos-faucet-service** - Builds `aptos-faucet-service` via Nix
6. **container-aptos-faucet-service** - Builds and pushes Docker image to GHCR
7. **binaries-aptos-tools** - Builds `aptos-transaction-emitter` via Nix

### Required secrets

- `CACHIX_AUTH_TOKEN` - Cachix push token
- `INFRA_GH_USER` / `INFRA_GH_PAT` - GHCR authentication

---

## Troubleshooting

### jemalloc prefix mismatch on macOS

**Symptom**: Linker errors like `Undefined symbols: __rjem_malloc`

**Cause**: System jemalloc from nixpkgs lacks the `_rjem_` prefix that `jemalloc-sys` expects.

**Fix**: Do NOT set `JEMALLOC_OVERRIDE`. Let `jemalloc-sys` build from source with the correct prefix. The `flake.nix` build packages intentionally omit `JEMALLOC_OVERRIDE`. The dev shell sets it for faster cargo builds (where the prefix issue doesn't apply the same way).

### crane vs buildRustPackage

**Why crane?** The `fetchCargoVendor` / `buildRustPackage` approach from nixpkgs can't handle two git crates with the same name and version from different repos (e.g., `aptos-moving-average-0.1.0` exists in both `aptos-indexer-processors` and `aptos-indexer-processor-sdk`). Crane vendors by `repo+revision`, avoiding collisions.

### Docker images built on macOS don't run locally

**Symptom**: `docker run` of the amd64 image fails on ARM macOS with errors about missing nix store paths or ld-linux.

**Cause**: Rosetta/QEMU can't resolve nix store ld-linux paths in the builder stage.

**Fix**: The final runtime image is a standard Debian image with statically-placed binaries - it should work. If the *builder* stage fails, ensure you're using `docker buildx build --platform linux/amd64` (not plain `docker build`). To validate the image works on real amd64, use the K8s test workflow:

```bash
just k8s-test-e2e
```

### Slow builds

- **First build**: Expected to be slow - compiling the entire workspace from scratch
- **Subsequent builds**: Much faster thanks to crane's two-phase caching (dependencies cached separately from source)
- **With cachix**: `cachix use movement-m1` to pull pre-built artifacts
- **CI**: The `cachix-push` job populates the cache on every push

### Nix command not found after install

Restart your shell or source the nix profile:

```bash
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```
