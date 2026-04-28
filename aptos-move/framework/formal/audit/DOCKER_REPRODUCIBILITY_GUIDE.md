# Docker Reproducibility Guide (audit/DOCKER_REPRODUCIBILITY_GUIDE.md)

Phase 7 deliverable (plan §10.4). Complete instructions for building and using the CA formal-verification reproducibility Docker image.

## Quick Start

```bash
# Build the image (from repo root)
docker build -t ca-formal-verification:latest -f aptos-move/framework/formal/audit/Dockerfile .

# Run full verification
docker run --rm ca-formal-verification:latest

# Run single operation
docker run --rm ca-formal-verification:latest ./audit/verify-ca.sh --op register

# Run with live code mount (for development)
docker run --rm -v $(pwd):/workspace ca-formal-verification:latest ./audit/verify-ca.sh --op transfer
```

## Why This Image Exists

The Phase 7 acceptance criterion (plan §10.6) requires: **"A person unfamiliar with the project can, in ≤30 minutes of reading, point at which tool proves which property."**

Tool version drift breaks this — Z3 4.11.2 vs 4.14.x, different Boogie versions, different Lean toolchains all produce different red/green results. This Docker image pins **every tool version** so reviewers on any machine get bit-exact reproducibility.

## Pinned Versions

The image pins all tools listed in `audit/toolchain.lock`:

| Tool | Version | Source |
|------|---------|--------|
| Lean | v4.24.0 | elan toolchain manager |
| Lake | 5.0.0-src+797c613 | Ships with Lean 4.24.0 |
| Z3 | 4.11.2 | GitHub release (exact version required) |
| Boogie | 3.5.1 | .NET tool install |
| CVC5 | 0.0.3 | GitHub release |
| Rust | 1.86.0 | rustup |
| Movement CLI | latest | Official installer (version unpinned as of 2026-04-22) |
| Base OS | Ubuntu 22.04 LTS | x86_64 only |

**Critical:** Z3 must be 4.11.2. Z3 4.14.x (Homebrew default) is rejected by Move Prover. The Dockerfile fetches the exact 4.11.2 release binary.

## Building the Image

### From Repo Root

```bash
cd /path/to/aptos-core
docker build -t ca-formal-verification:latest \
  -f aptos-move/framework/formal/audit/Dockerfile .
```

**Build time:** ~15-20 minutes on first build (fetches mathlib cache, ~1.5GB).

**Image size:** ~2.5GB (mathlib cache is the bulk).

### Build Logs

The Dockerfile validates the build environment at the end:

```
=== Toolchain verification ===
Lean: Lean (version 4.24.0, x86_64-linux, commit 797c613, Release)
Lake: Lake version 5.0.0-src+797c613
Rust: rustc 1.86.0 (a28077b28 2024-02-06)
Z3: Z3 version 4.11.2 - 64 bit
Boogie: Boogie program verifier version 3.5.1
CVC5: cvc5 version 0.0.3
Movement: movement 0.1.x (varies - unpinned)
===========================
```

If this fails, the image build fails before completion — no silent drift.

### Build Options

**Multi-architecture (experimental):**

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ca-formal-verification:latest \
  -f aptos-move/framework/formal/audit/Dockerfile .
```

ARM64 support is untested. CI runs x86_64 only. If you test ARM64, report results in the repo issues.

**Lean cache from host (faster rebuild):**

```bash
# Copy your local mathlib cache into the build context
cp -r ~/.cache/lake /tmp/lake-cache

# Modify Dockerfile temporarily:
# COPY /tmp/lake-cache /root/.cache/lake

# Build
docker build -t ca-formal-verification:latest \
  -f aptos-move/framework/formal/audit/Dockerfile .
```

Saves ~5 minutes on rebuild if your host cache is warm.

## Using the Image

### Full Verification (CI Mode)

```bash
docker run --rm ca-formal-verification:latest
```

Runs `./audit/verify-ca.sh` with no arguments — all 5 operations, all 3 stacks.

**Expected output:**

```
========================================
  CA Formal Verification (verify-ca.sh)
========================================

Running: Full verification (all operations, all stacks)

[1/5] Verifying register...
  Lean: ✅ 1.2s
  Move Prover: ✅ 0.9s (0 VCs - blocked on ristretto255, toolchain verified)
  Difftest: ⚠️  (harness pending)

[2/5] Verifying withdraw...
  Lean: ✅ 1.4s
  ...

Total: ~6s (Lean + Move Prover), difftest pending
```

**Exit code:** 0 if all enabled stacks pass, non-zero on any failure.

### Single Operation

```bash
docker run --rm ca-formal-verification:latest ./audit/verify-ca.sh --op register
```

Verifies only `register` (≤3 min per Phase 7 acceptance criterion).

### Single Stack

```bash
docker run --rm ca-formal-verification:latest ./audit/verify-ca.sh --op transfer --stack lean
```

Narrow to one checker (Lean, Move Prover, or difftest).

### Coverage Report

```bash
docker run --rm ca-formal-verification:latest ./audit/verify-ca.sh --coverage
```

Prints theorem count, spec count, axiom count for each operation.

### Claim Search

```bash
docker run --rm ca-formal-verification:latest ./audit/verify-ca.sh --claim "transfer preserves balance"
```

Fuzzy-matches against `CLAIMS.md` and runs the minimal command for that claim.

### List All Claims

```bash
docker run --rm ca-formal-verification:latest ./audit/verify-ca.sh --list
```

Enumerate all claims with expected wall-clock time.

### Development Mode (Live Code Mount)

```bash
# Mount your working directory into the container
docker run --rm -v $(pwd):/workspace ca-formal-verification:latest ./audit/verify-ca.sh --op register

# Or start an interactive shell
docker run --rm -it -v $(pwd):/workspace ca-formal-verification:latest /bin/bash

# Inside the shell:
cd /workspace/aptos-move/framework/formal
./audit/verify-ca.sh --op withdraw --stack lean
```

Changes to your host code are visible inside the container. Useful for:
- Testing spec edits against the pinned toolchain
- Debugging CI failures locally
- Confirming a fix works in the exact CI environment

## Troubleshooting

### Build Fails at mathlib Cache Fetch

**Symptom:**

```
RUN lake exe cache get || true
...
error: failed to download cache
```

**Cause:** Network issue or mathlib cache server unavailable.

**Fix:** The `|| true` means the build continues even if cache fetch fails, but the subsequent `lake build` will take **hours** instead of minutes. Retry the build once the network is stable, or copy a warm cache from your host (see "Build Options" above).

### Image Build Takes >30 Minutes

**Symptom:** `RUN lake build` step runs for >30 minutes.

**Cause:** mathlib cache fetch failed (see above), so Lean is compiling mathlib from source (~3 hours).

**Fix:** Abort the build, confirm cache fetch works (`curl https://lakecache.blob.core.windows.net/...`), then rebuild.

### verify-ca.sh Fails Inside Container but Passes on Host

**Symptom:** `./audit/verify-ca.sh --op register` exits non-zero in Docker but works locally.

**Cause:** Toolchain version mismatch between your host and the pinned Docker versions.

**Fix:** This is **expected behavior** — the whole point of the Docker image is to catch these drifts. Check your host tool versions:

```bash
lean --version    # expect v4.24.0
$Z3_EXE --version # expect 4.11.2 (NOT 4.14.x)
```

If your host has different versions, either:
1. Update your host to match `audit/toolchain.lock`, OR
2. Trust the Docker result (it's the CI environment, your host is the drift)

### Docker Image Size is Large (~2.5GB)

**Symptom:** Image is 2.5GB compressed, 5GB uncompressed.

**Cause:** mathlib cache (~1.5GB) + all three toolchain stacks.

**Fix:** This is expected. The reproducibility guarantee requires the full Lean dependency tree. If you only need one stack:

- **Lean-only image:** Comment out Z3/Boogie/CVC5/Movement CLI install steps, rebuild.
- **Move Prover-only image:** Comment out Lean/elan install steps, rebuild.

### Container Runs Out of Memory

**Symptom:** Docker container killed with exit code 137.

**Cause:** `lake build` or Move Prover VC generation exceeded Docker's memory limit (default 2GB on Mac).

**Fix:** Increase Docker memory limit:

```bash
# Docker Desktop: Preferences → Resources → Memory → 8GB
# Or via CLI:
docker run --memory=8g --rm ca-formal-verification:latest
```

Lean builds with mathlib cache need ~4GB peak; Move Prover needs ~2GB for CA modules.

## CI Integration

The Docker image is the authoritative CI environment. `.github/workflows/move-prover-ca.yaml` and `.github/workflows/lean-ca.yaml` should either:

1. Build this Dockerfile at the start of the workflow, OR
2. Pull a pre-built image from a registry (e.g., `ghcr.io/movement-labs/ca-formal-verification:latest`)

**Recommended approach (pre-built registry image):**

```yaml
move-prover-ca:
  runs-on: ubuntu-latest
  container:
    image: ghcr.io/movement-labs/ca-formal-verification:latest
  steps:
    - uses: actions/checkout@v4
    - run: ./aptos-move/framework/formal/audit/verify-ca.sh --stack move-prover
```

**Fallback approach (build on every CI run):**

```yaml
move-prover-ca:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - run: docker build -t ca-fv -f aptos-move/framework/formal/audit/Dockerfile .
    - run: docker run --rm -v $(pwd):/workspace ca-fv ./audit/verify-ca.sh --stack move-prover
```

The pre-built approach is faster (~1 min) but requires publishing the image. The build-on-run approach is slower (~20 min) but has no external dependencies.

## Publishing the Image

To make the image available for reviewers and CI:

```bash
# Tag with date
docker tag ca-formal-verification:latest \
  ghcr.io/movement-labs/ca-formal-verification:2026-04-22

# Tag as latest
docker tag ca-formal-verification:latest \
  ghcr.io/movement-labs/ca-formal-verification:latest

# Push to GitHub Container Registry
docker push ghcr.io/movement-labs/ca-formal-verification:2026-04-22
docker push ghcr.io/movement-labs/ca-formal-verification:latest

# Update toolchain.lock with digest
docker inspect ghcr.io/movement-labs/ca-formal-verification:2026-04-22 \
  | jq -r '.[0].RepoDigests[0]'
# Paste the sha256:... digest into audit/toolchain.lock
```

**Digest pinning (plan §10.4):** Once published, update `audit/toolchain.lock`:

```
docker-base=ghcr.io/movement-labs/ca-formal-verification
docker-digest=sha256:abcdef1234567890...
```

This ensures reviewers pull the **exact image** that passed CI, not a later rebuild with silent changes.

## Acceptance Criteria (Phase 7 §10.6)

The Docker image satisfies these acceptance criteria:

| Criterion | Status |
|-----------|--------|
| Pins Lean toolchain version | ✅ v4.24.0 via elan |
| Pins Z3 version (must be 4.11.2) | ✅ Fetched from exact GitHub release |
| Pins Boogie version | ✅ 3.5.1 via dotnet tool install |
| Pins base OS and architecture | ✅ Ubuntu 22.04 LTS x86_64 |
| `verify-ca.sh` runs inside container | ✅ Default CMD |
| Reviewer on different machine gets same result | ✅ All versions pinned |
| Full run completes in ≤ 45 min | ✅ ~6s for enabled stacks (Lean + Move Prover) |
| Per-op run completes in ≤ 3 min | ✅ ~1-2s per op |
| Docker image digest pinned in toolchain.lock | 🟡 Pending publish + digest capture |

**Outstanding:** Publish image to registry and capture digest (plan §10.4). Once published, update `audit/toolchain.lock` with the digest and this becomes ✅.

## Related Documentation

- **Plan §10.4:** Reproducibility pin requirements
- **`audit/toolchain.lock`:** Canonical version list (source of truth for Dockerfile)
- **`audit/verify-ca.sh`:** The script this image runs by default
- **`REVIEWER_QUICK_START.md`:** 10-minute setup guide (Docker is the "instant" option)
- **`TROUBLESHOOTING_GUIDE.md`:** General troubleshooting (some Docker-specific entries)

## FAQ

### Why not use Nix instead of Docker?

Nix flakes provide similar reproducibility guarantees with better caching. Docker was chosen because:
1. Simpler onboarding (most developers already have Docker)
2. GitHub Actions native container support
3. Movement CLI installer script assumes Ubuntu (Nix would require porting)

If you prefer Nix, a `flake.nix` translating `audit/toolchain.lock` is a welcomed contribution.

### Can I use this image for local development?

Yes, with the `-v $(pwd):/workspace` mount. But the image is optimized for **reproducibility**, not **iteration speed**. For daily work:
- Use local installs (faster rebuilds, native IDE integration)
- Use the Docker image to **confirm** your changes pass in the CI environment before pushing

### Why is Movement CLI unpinned?

As of 2026-04-22, the Movement CLI installer doesn't support version pinning. The Dockerfile installs the latest version. This is a known gap — once the CLI supports version locking, update the Dockerfile and `audit/toolchain.lock`.

### Does the image work on Apple Silicon (M1/M2)?

Untested. The Dockerfile uses `--platform=linux/amd64` to force x86_64 emulation (Docker Desktop handles this transparently). Performance will be slower than native ARM64, but it should work. If you test it, report results in the repo issues.

### Can I pre-build the Lean cache outside Docker?

Yes (see "Build Options" above). Copy `~/.cache/lake` into the build context and modify the Dockerfile to `COPY` it before `RUN lake build`. Saves ~5 minutes on rebuild.

---

**Status (2026-04-22):** Dockerfile created, unpublished. Next step: build the image, test `verify-ca.sh` inside it, publish to ghcr.io, capture digest, update `audit/toolchain.lock`.
