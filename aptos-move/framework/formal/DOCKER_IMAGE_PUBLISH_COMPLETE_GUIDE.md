# Docker Image — Complete Build & Publish Guide

**Phase 7 Outstanding Item:** Docker image publish (~30 min)  
**Status:** ✅ Dockerfile complete, 🟡 publish pending  
**This guide:** Complete end-to-end instructions to build, test, and publish the image

---

## Quick Start (5 Minutes)

```bash
# From repository root
cd aptos-move/framework/formal

# Build the image (takes ~15 min first time, ~2 min cached)
docker build -t ca-formal-verification:latest -f audit/Dockerfile ../..

# Test the image
docker run --rm ca-formal-verification:latest lake --version

# Run verification suite
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  ca-formal-verification:latest \
  ./audit/verify-ca.sh --op normalization --stack lean

# Expected: ✅ Normalization verification completes in ≤3 min
```

---

## Part 1: Building the Image

### 1.1 Prerequisites

- Docker Desktop or Docker Engine installed
- ~10 GB free disk space (image + build cache)
- Internet connection (downloads ~2 GB of dependencies)

### 1.2 Build Command

```bash
#!/usr/bin/env bash
# build-docker-image.sh

set -euo pipefail

# Configuration
IMAGE_NAME="ca-formal-verification"
IMAGE_TAG="latest"  # Or use: $(git rev-parse --short HEAD)
DOCKERFILE="audit/Dockerfile"
BUILD_CONTEXT="../.."  # Repository root from formal/

# Build with progress output
docker build \
  --platform linux/amd64 \
  -t "${IMAGE_NAME}:${IMAGE_TAG}" \
  -f "$DOCKERFILE" \
  "$BUILD_CONTEXT"

# Tag with date for versioning
DATE_TAG=$(date +%Y%m%d)
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${IMAGE_NAME}:${DATE_TAG}"

echo "✅ Built: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "✅ Tagged: ${IMAGE_NAME}:${DATE_TAG}"
```

Save as `scripts/build-docker-image.sh`, make executable:

```bash
chmod +x scripts/build-docker-image.sh
./scripts/build-docker-image.sh
```

### 1.3 Build Output

Expected timeline:
- **Step 1-5** (base image + system deps): ~2 minutes
- **Step 6-8** (Rust + Lean + Lake): ~5 minutes
- **Step 9** (Mathlib cache): ~8 minutes (downloads ~1.5 GB)
- **Step 10-15** (Move toolchain + verification tools): ~3 minutes

**Total first build:** ~15-20 minutes  
**Subsequent builds (cached):** ~2-5 minutes

Final image size: ~2.8 GB

---

## Part 2: Testing the Image

### 2.1 Smoke Tests

```bash
# Test 1: Lean toolchain
docker run --rm ca-formal-verification:latest lean --version
# Expected: Lean (version 4.24.0...)

# Test 2: Lake build system
docker run --rm ca-formal-verification:latest lake --version
# Expected: Lake version 5.0.0-src+797c613...

# Test 3: Rust toolchain
docker run --rm ca-formal-verification:latest rustc --version
# Expected: rustc 1.86.0...

# Test 4: Move Prover tools
docker run --rm ca-formal-verification:latest bash -c '$Z3_EXE --version'
# Expected: Z3 version 4.11.2...
```

### 2.2 Verification Suite Test

```bash
# Mount workspace and run full verification
docker run --rm \
  -v "$(pwd):/workspace" \
  -w /workspace \
  ca-formal-verification:latest \
  ./audit/verify-ca.sh

# Expected output:
# ✅ Normalization: Lean (✓ 14 PCs), Move Prover (✓ compile), Difftest (✓ 12 rows)
# ✅ Withdrawal: Lean (✓ 15 PCs), ...
# ...
# Total time: ≤15 minutes
```

### 2.3 Per-Operation Tests

```bash
# Test Normalization only (fastest)
docker run --rm -v $(pwd):/workspace -w /workspace \
  ca-formal-verification:latest \
  ./audit/verify-ca.sh --op normalization

# Test all stacks for one operation
docker run --rm -v $(pwd):/workspace -w /workspace \
  ca-formal-verification:latest \
  ./audit/verify-ca.sh --op withdrawal --stack lean

docker run --rm -v $(pwd):/workspace -w /workspace \
  ca-formal-verification:latest \
  ./audit/verify-ca.sh --op withdrawal --stack move-prover
```

---

## Part 3: Publishing to Container Registry

### 3.1 GitHub Container Registry (Recommended)

```bash
#!/usr/bin/env bash
# publish-docker-image-ghcr.sh

set -euo pipefail

# Configuration
GHCR_REGISTRY="ghcr.io"
GHCR_NAMESPACE="movementlabs"  # Or your org
IMAGE_NAME="ca-formal-verification"
VERSION_TAG=$(git describe --tags --always --dirty)
DATE_TAG=$(date +%Y%m%d)

# Login to GitHub Container Registry
echo "$GITHUB_TOKEN" | docker login "$GHCR_REGISTRY" -u "$GITHUB_ACTOR" --password-stdin

# Tag for GHCR
docker tag "${IMAGE_NAME}:latest" \
  "${GHCR_REGISTRY}/${GHCR_NAMESPACE}/${IMAGE_NAME}:${VERSION_TAG}"

docker tag "${IMAGE_NAME}:latest" \
  "${GHCR_REGISTRY}/${GHCR_NAMESPACE}/${IMAGE_NAME}:${DATE_TAG}"

docker tag "${IMAGE_NAME}:latest" \
  "${GHCR_REGISTRY}/${GHCR_NAMESPACE}/${IMAGE_NAME}:latest"

# Push all tags
docker push "${GHCR_REGISTRY}/${GHCR_NAMESPACE}/${IMAGE_NAME}:${VERSION_TAG}"
docker push "${GHCR_REGISTRY}/${GHCR_NAMESPACE}/${IMAGE_NAME}:${DATE_TAG}"
docker push "${GHCR_REGISTRY}/${GHCR_NAMESPACE}/${IMAGE_NAME}:latest"

echo "✅ Published to ${GHCR_REGISTRY}/${GHCR_NAMESPACE}/${IMAGE_NAME}"
echo "   - :${VERSION_TAG}"
echo "   - :${DATE_TAG}"
echo "   - :latest"
```

**Setup GitHub secrets:**
- `GITHUB_TOKEN`: Personal access token with `write:packages` scope
- `GITHUB_ACTOR`: Your GitHub username

**Run in CI:**
```yaml
# .github/workflows/docker-publish.yaml
name: Publish Docker Image

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          file: aptos-move/framework/formal/audit/Dockerfile
          push: true
          tags: |
            ghcr.io/movementlabs/ca-formal-verification:latest
            ghcr.io/movementlabs/ca-formal-verification:${{ github.ref_name }}
            ghcr.io/movementlabs/ca-formal-verification:$(date +%Y%m%d)
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### 3.2 Docker Hub (Alternative)

```bash
# Login to Docker Hub
docker login

# Tag for Docker Hub
docker tag ca-formal-verification:latest \
  movementlabs/ca-formal-verification:latest

docker tag ca-formal-verification:latest \
  movementlabs/ca-formal-verification:$(git describe --tags --always)

# Push
docker push movementlabs/ca-formal-verification:latest
docker push movementlabs/ca-formal-verification:$(git describe --tags --always)
```

---

## Part 4: Using the Published Image

### 4.1 Pull and Run

```bash
# Pull latest
docker pull ghcr.io/movementlabs/ca-formal-verification:latest

# Run verification
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/movementlabs/ca-formal-verification:latest \
  ./audit/verify-ca.sh
```

### 4.2 CI Integration

```yaml
# .github/workflows/ca-verification.yaml
name: CA Verification

on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/movementlabs/ca-formal-verification:latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Run verification suite
        run: |
          cd aptos-move/framework/formal
          ./audit/verify-ca.sh
```

### 4.3 Local Development

```bash
# Create alias for convenience
alias verify-ca='docker run --rm -v $(pwd):/workspace -w /workspace ghcr.io/movementlabs/ca-formal-verification:latest ./audit/verify-ca.sh'

# Use it
cd aptos-move/framework/formal
verify-ca --op normalization --stack lean
```

---

## Part 5: Maintenance

### 5.1 Updating Dependencies

When Lean or other tools need updates:

1. Edit `audit/Dockerfile` ENV vars:
   ```dockerfile
   ENV LEAN_VERSION=v4.25.0  # Update version
   ```

2. Update `audit/toolchain.lock`:
   ```
   lean: v4.25.0
   lake: 5.1.0
   ...
   ```

3. Rebuild and test:
   ```bash
   ./scripts/build-docker-image.sh
   docker run --rm ca-formal-verification:latest ./audit/verify-ca.sh
   ```

4. If tests pass, publish new version:
   ```bash
   ./scripts/publish-docker-image-ghcr.sh
   ```

### 5.2 Debugging Build Failures

**Issue: Mathlib cache download fails**
```bash
# Check cache URL is accessible
curl -I https://lakefile.lean-lang.org/mathlib4/mathlib4-nightly-2024-12-01.tar.gz

# If 404, update to latest mathlib cache date in Dockerfile
```

**Issue: Out of disk space**
```bash
# Clean up Docker build cache
docker system prune -af

# Remove old images
docker rmi $(docker images -f "dangling=true" -q)
```

**Issue: Build timeout in CI**
```yaml
# Increase timeout in workflow
jobs:
  build:
    timeout-minutes: 60  # Default is 360
```

---

## Part 6: Size Optimization (Optional)

Current image: ~2.8 GB. Can optimize to ~1.5 GB:

### 6.1 Multi-Stage Build

```dockerfile
# Stage 1: Build environment
FROM ubuntu:22.04 AS builder
# ... install all build tools ...
# ... download and cache mathlib ...

# Stage 2: Runtime environment (smaller)
FROM ubuntu:22.04

# Copy only runtime binaries from builder
COPY --from=builder /root/.elan /root/.elan
COPY --from=builder /root/.cargo/bin/rustc /usr/local/bin/
COPY --from=builder /root/.cache/lake /root/.cache/lake

# Skip build tools (saves ~500 MB)
```

### 6.2 Layer Optimization

```dockerfile
# Combine RUN commands to reduce layers
RUN apt-get update && apt-get install -y \
    curl git wget && \
    curl -sSf https://sh.rustup.rs | sh -s -- -y && \
    rm -rf /var/lib/apt/lists/* /tmp/*
```

---

## Part 7: Verification

### 7.1 Image Integrity

```bash
# Generate image digest
docker inspect ghcr.io/movementlabs/ca-formal-verification:latest \
  --format='{{.RepoDigests}}'

# Expected: ghcr.io/movementlabs/ca-formal-verification@sha256:abc123...

# Verify digest in production
docker pull ghcr.io/movementlabs/ca-formal-verification@sha256:abc123...
```

### 7.2 Reproducibility Test

```bash
# Build on two different machines
machine1$ docker build -t test1 -f audit/Dockerfile .
machine2$ docker build -t test2 -f audit/Dockerfile .

# Compare image IDs (should be identical for reproducible builds)
machine1$ docker images test1 --format "{{.ID}}"
machine2$ docker images test2 --format "{{.ID}}"

# Note: Timestamps in layers may differ, but functional content is identical
```

---

## Part 8: Documentation Update

After publishing, update these docs:

### 8.1 README.md

Add Docker section:
````markdown
## Running Verification (Docker)

```bash
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/movementlabs/ca-formal-verification:latest \
  ./audit/verify-ca.sh
```
````

### 8.2 CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md

Update Phase 7 row:
```markdown
| 7 | Reproducibility and audit package | ✅ COMPLETE | Docker image published to ghcr.io/movementlabs/ca-formal-verification:latest ...
```

### 8.3 audit/DOCKER_REPRODUCIBILITY_GUIDE.md

Add pull instructions:
```markdown
## Quick Start

```bash
docker pull ghcr.io/movementlabs/ca-formal-verification:latest
docker run --rm -v $(pwd):/workspace ghcr.io/.../ca-formal-verification:latest ./audit/verify-ca.sh
```
```

---

## Completion Checklist

- [ ] Build image locally: `./scripts/build-docker-image.sh`
- [ ] Run smoke tests (all pass)
- [ ] Run verification suite (all operations ✓)
- [ ] Create GitHub secrets (GITHUB_TOKEN)
- [ ] Add `.github/workflows/docker-publish.yaml`
- [ ] Push to main branch
- [ ] Create git tag: `git tag v1.0.0 && git push --tags`
- [ ] Workflow runs and publishes image
- [ ] Pull published image and test
- [ ] Update documentation (README, plan, guides)
- [ ] Update Phase 7 status to ✅ COMPLETE

**Total estimated time:** 30-45 minutes (as estimated in plan)

**Completion:** Moves Phase 7 from "90% complete" to "100% complete" ✅

---

**END OF GUIDE**
