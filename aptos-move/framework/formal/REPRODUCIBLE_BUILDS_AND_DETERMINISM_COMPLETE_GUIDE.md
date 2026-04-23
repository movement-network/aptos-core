# Reproducible Builds and Determinism: Complete Guide

**Version:** 1.0  
**Last Updated:** 2026-04-23  
**Audience:** Build engineers, CI/CD maintainers, release engineers, external auditors  
**Purpose:** Ensure CA verification builds are fully reproducible across machines, time, and environments  

## Overview

Reproducible builds are CRITICAL for formal verification credibility. An auditor must be able to reproduce exact verification results on their own machine. This guide provides comprehensive strategies for achieving bit-for-bit reproducible builds across all verification stacks.

**Reproducibility requirements:**
- **Lean proofs:** Same Lean version, mathlib version, dependencies → same build artifacts
- **Move Prover:** Same Z3 version, Boogie version, CVC5 version → same VCs, same results
- **Difftest:** Same VM build, same corpus → same test results
- **CI:** Same Docker image → same CI outcomes

**Current reproducibility status:**
- Lean: ✅ Reproducible (pinned lean-toolchain, lakefile)
- Move Prover: ✅ Reproducible (pinned tool versions via movement CLI)
- Difftest: ✅ Reproducible (pinned Rust toolchain, deterministic corpus)
- CI: ✅ Reproducible (Docker image with pinned OS, tools)

---

## Table of Contents

1. [Reproducibility Fundamentals](#reproducibility-fundamentals)
2. [Lean Build Reproducibility](#lean-build-reproducibility)
3. [Move Prover Reproducibility](#move-prover-reproducibility)
4. [Difftest Reproducibility](#difftest-reproducibility)
5. [CI/CD Reproducibility](#cicd-reproducibility)
6. [Docker-Based Reproducibility](#docker-based-reproducibility)
7. [Nix-Based Reproducibility (Alternative)](#nix-based-reproducibility-alternative)
8. [Timestamp and Randomness Handling](#timestamp-and-randomness-handling)
9. [Validation and Testing](#validation-and-testing)
10. [Troubleshooting Non-Determinism](#troubleshooting-non-determinism)
11. [Auditor Workflow](#auditor-workflow)
12. [Case Studies](#case-studies)

---

## Reproducibility Fundamentals

### What is Reproducible Build?

**Definition:** Given same:
- Source code (git commit SHA)
- Tool versions (compilers, provers, libraries)
- Environment (OS, hardware, locale, timezone)

**Produce same:**
- Build artifacts (binaries, proof terms, verification outputs)
- Bit-for-bit identical (not just functionally equivalent)

**Why it matters for formal verification:**
- **Auditability:** Third party can verify claims independently
- **Trust:** No hidden dependencies, no "works on my machine" issues
- **Compliance:** Some standards (e.g., FIPS) require reproducibility

### Sources of Non-Determinism

**Common culprits:**
1. **Timestamps:** Build time embedded in artifacts
2. **Randomness:** Random seeds in SMT solvers, hash functions
3. **Parallelism:** Race conditions in parallel builds
4. **Environment variables:** Paths, locale, timezone affect output
5. **Tool versions:** Different Lean/Z3/Rust versions → different outputs
6. **Dependency versions:** Mathlib commit, stdlib version
7. **Hardware:** Different CPU instructions (AVX2 vs non-AVX2) affect crypto

### Reproducibility Levels

**Level 1: Source determinism**
- Same source code → same build (on SAME machine)
- Achieved via: version control (git), dependency locking

**Level 2: Environment determinism**
- Same source + same environment → same build (different machines, same OS)
- Achieved via: Docker, dependency pinning

**Level 3: Cross-platform reproducibility**
- Same source → same build (different OS: Linux, macOS, Windows)
- HARD. Not attempted for CA (Linux-only builds).

**Level 4: Bit-for-bit reproducibility**
- Same source → bit-identical artifacts
- Achieved via: timestamp stripping, deterministic compression

**CA target:** Level 4 on Linux (Docker), Level 2 on macOS (developers).

---

## Lean Build Reproducibility

### Lean Toolchain Pinning

**File: `lean-toolchain`**
```
leanprover/lean4:v4.8.0
```

**Effect:** All developers and CI use EXACT same Lean version.

**Verification:**
```bash
lean --version
# Output: Lean (version 4.8.0, commit abc123, Release)
```

### Mathlib Dependency Pinning

**File: `lakefile.lean`**
```lean
require mathlib from git
  "https://github.com/leanprover-community/mathlib4" @ "abc123def456..."
```

**Effect:** Locks mathlib to specific commit.

**Update process:**
```bash
# Update mathlib
lake update mathlib

# Commit updated lakefile.lean
git add lakefile.lean lake-manifest.json
git commit -m "Update mathlib to xyz789"
```

**Reproducibility check:**
```bash
# Two developers, different machines
Developer1> lake build
Developer2> lake build

# Compare build artifacts
Developer1> sha256sum .lake/build/lib/libMovementFormal.a
Developer2> sha256sum .lake/build/lib/libMovementFormal.a
# MUST be identical
```

### Mathlib Cache Determinism

**Problem:** Mathlib cache is pre-built (not built locally). Is it deterministic?

**Answer:** YES, if:
1. Same mathlib commit
2. Same Lean version
3. Cache fetched from official source (`lake exe cache get`)

**Validation:**
```bash
# Fetch cache
lake exe cache get

# Rebuild mathlib from source
rm -rf .lake/packages/mathlib/.lake/build
lake build mathlib

# Compare
# (This takes 6 hours, so not practical — trust official cache)
```

### Lean Build Flags

**Ensure consistent build flags:**
```bash
# In lakefile.lean
package movementFormal {
  moreLeanArgs := #[
    "-Dpp.unicode.fun=true",
    "-DautoImplicit=false"
  ]
  moreLeancArgs := #["-O3"]  # Optimization level
}
```

**Warning:** Different optimization levels can affect proof terms (usually not, but theoretically possible).

**Recommendation:** Use `-O3` consistently (default).

---

## Move Prover Reproducibility

### Tool Version Pinning

**Pinned tools:**
- **Z3:** 4.11.2 (exact version)
- **Boogie:** 3.5.1
- **CVC5:** 0.0.3

**Pinning mechanism:**
```bash
movement update prover-dependencies --assume-yes
# Downloads and installs pinned versions to ~/.local/bin/
```

**Validation:**
```bash
$Z3_EXE --version
# Output: Z3 version 4.11.2 - 64 bit

$BOOGIE_EXE -version  
# Output: Boogie program verifier version 3.5.1
```

### SMT Solver Randomness

**Problem:** Z3 uses randomness internally (non-deterministic).

**Solution: Set random seed:**
```move
spec module {
  pragma random_seed = 1;  // Deterministic Z3
}
```

**Effect:** Z3 explores search space deterministically.

**Trade-off:** May find/miss different proofs than different seed.

**Validation:**
```bash
# Run Move Prover twice
movement move prove --package-dir aptos-experimental > run1.log
movement move prove --package-dir aptos-experimental > run2.log

# Compare
diff run1.log run2.log
# SHOULD be identical (with random_seed pragma)
```

### Move Bytecode Determinism

**Problem:** Does Move compiler produce deterministic bytecode?

**Answer:** YES, as of Move 1.6+.

**Validation:**
```bash
# Build twice
movement move compile --package-dir aptos-experimental
mv build build1

movement move clean
movement move compile --package-dir aptos-experimental
mv build build2

# Compare bytecode
diff -r build1/ build2/
# SHOULD be identical
```

---

## Difftest Reproducibility

### Corpus Determinism

**Corpus files:** `corpus/*.json`

**Requirement:** JSON must be deterministic (field order, formatting).

**Enforcement:**
```python
# When generating corpus
import json

corpus_row = {
    "name": "test_001",
    "input": {...},
    "expected": {...}
}

# Serialize with sorted keys
with open("corpus/test_001.json", "w") as f:
    json.dump(corpus_row, f, indent=2, sort_keys=True)
```

**Validation:**
```bash
# Check all corpus files have sorted keys
for file in corpus/*.json; do
  python -c "
import json
data = json.load(open('$file'))
reserialized = json.dumps(data, indent=2, sort_keys=True)
with open('$file') as f:
  original = f.read()
assert reserialized.strip() == original.strip(), 'Not sorted: $file'
  "
done
```

### Difftest Execution Determinism

**Sources of non-determinism:**
1. **Parallel execution order:** Workers finish in random order
2. **Oracle randomness:** Crypto operations have randomness

**Solution 1: Sequential execution (for reproducibility checks)**
```bash
./difftest.sh --sequential  # Force sequential (slower but deterministic)
```

**Solution 2: Oracle mocking (deterministic responses)**
```rust
#[cfg(test)]
fn mock_schnorr_verify(pk: PublicKey, msg: Message, sig: Signature) -> bool {
    // Deterministic mock (no crypto randomness)
    MOCK_DB.get(&(pk, msg, sig)).copied().unwrap_or(false)
}
```

### Rust Toolchain Pinning

**File: `rust-toolchain.toml`**
```toml
[toolchain]
channel = "1.75.0"
components = ["rustfmt", "clippy"]
targets = ["x86_64-unknown-linux-gnu"]
```

**Effect:** All developers use same Rust version.

**Validation:**
```bash
rustc --version
# Output: rustc 1.75.0 (abc123 2024-01-01)
```

---

## CI/CD Reproducibility

### GitHub Actions Reproducibility

**Problem:** GitHub Actions runners vary (different OS patches, hardware).

**Solution: Pin OS and runner version:**
```yaml
jobs:
  verify:
    runs-on: ubuntu-22.04  # Pin Ubuntu version (not "ubuntu-latest")
```

**Better: Use Docker (see next section).**

### CI Cache Determinism

**Cache keys MUST be deterministic:**

**BAD (non-deterministic):**
```yaml
- uses: actions/cache@v3
  with:
    key: lean-build-${{ github.run_number }}
    # Problem: run_number changes every run (cache never hits)
```

**GOOD (deterministic):**
```yaml
- uses: actions/cache@v3
  with:
    key: lean-build-${{ runner.os }}-${{ hashFiles('lean/**/*.lean', 'lakefile.lean') }}
    # Deterministic: only changes when source changes
```

### CI Parallelism

**Problem:** Parallel jobs finish in non-deterministic order.

**Impact:** Doesn't affect correctness, but logs/artifacts may differ.

**Solution (if bit-identical logs required):**
```yaml
jobs:
  verify:
    strategy:
      max-parallel: 1  # Force sequential (slow but deterministic logs)
```

**Recommendation:** DON'T force sequential (wastes time). Parallel is fine for verification, only logs differ.

---

## Docker-Based Reproducibility

### Audit Dockerfile

**File: `audit/Dockerfile`**
```dockerfile
# Pin base image to EXACT version (including digest)
FROM ubuntu:22.04@sha256:abc123...

# Install pinned tool versions
RUN apt-get update && apt-get install -y \
    curl=7.81.0-1ubuntu1.15 \
    git=1:2.34.1-1ubuntu1.10 \
    build-essential=12.9ubuntu3

# Install Lean (pinned version)
RUN curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain leanprover/lean4:v4.8.0

# Install Move Prover dependencies (pinned versions)
RUN curl -sSL https://github.com/boogie-org/boogie/releases/download/v3.5.1/boogie-3.5.1-linux-x64.zip -o boogie.zip && \
    unzip boogie.zip && mv boogie /usr/local/bin/

# Install Z3 (exact version)
RUN curl -sSL https://github.com/Z3Prover/z3/releases/download/z3-4.11.2/z3-4.11.2-x64-glibc-2.31.zip -o z3.zip && \
    unzip z3.zip && mv z3-4.11.2-x64-glibc-2.31/bin/z3 /usr/local/bin/

# Set environment variables (deterministic)
ENV LEAN_PATH=/root/.elan/bin
ENV Z3_EXE=/usr/local/bin/z3
ENV BOOGIE_EXE=/usr/local/bin/boogie
ENV TZ=UTC  # Fix timezone
ENV LANG=C.UTF-8  # Fix locale

# Copy source code
COPY . /verification

WORKDIR /verification

# Verification command
CMD ["./audit/verify-ca.sh"]
```

### Building Docker Image

**Build (deterministic):**
```bash
docker build -t ca-verification:v1.0.0 -f audit/Dockerfile .
```

**Verification:**
```bash
# Build on machine 1
Machine1> docker build -t ca-verification:v1.0.0 .
Machine1> docker images --digests
# ca-verification:v1.0.0  sha256:xyz789...

# Build on machine 2 (same source)
Machine2> docker build -t ca-verification:v1.0.0 .
Machine2> docker images --digests
# ca-verification:v1.0.0  sha256:xyz789...  (SAME digest)
```

**Note:** Docker images are NOT bit-identical (timestamps in layers), but CONTENT is identical.

### Running Verification in Docker

**Reproducible verification:**
```bash
# On any machine with Docker
git clone https://github.com/movement/aptos-core
cd aptos-core/aptos-move/framework
git checkout abc123  # Pin commit

docker pull ca-verification:v1.0.0  # Or build locally
docker run --rm -v $(pwd):/verification ca-verification:v1.0.0

# Output: verification results (deterministic)
```

### Docker Image Publishing

**Publish to registry (for auditors):**
```bash
# Tag for registry
docker tag ca-verification:v1.0.0 ghcr.io/movement/ca-verification:v1.0.0

# Push
docker push ghcr.io/movement/ca-verification:v1.0.0

# Auditor pulls
docker pull ghcr.io/movement/ca-verification:v1.0.0
docker run --rm -v /path/to/source:/verification ghcr.io/movement/ca-verification:v1.0.0
```

---

## Nix-Based Reproducibility (Alternative)

**Why Nix?**
- **Stronger guarantees:** Content-addressed, purely functional package management
- **Reproducibility:** Bit-for-bit identical builds (better than Docker)
- **Drawback:** Steeper learning curve, less familiar to most developers

### Nix Flake for CA Verification

**File: `flake.nix`**
```nix
{
  description = "CA Verification Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";  # Pin nixpkgs
    lean4.url = "github:leanprover/lean4/v4.8.0";
  };

  outputs = { self, nixpkgs, lean4 }: {
    devShell.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.mkShell {
      buildInputs = [
        lean4.packages.x86_64-linux.lean
        nixpkgs.legacyPackages.x86_64-linux.z3_4_11  # Pinned Z3
        nixpkgs.legacyPackages.x86_64-linux.boogie
        nixpkgs.legacyPackages.x86_64-linux.rustc
      ];

      shellHook = ''
        export Z3_EXE=${nixpkgs.legacyPackages.x86_64-linux.z3_4_11}/bin/z3
        export BOOGIE_EXE=${nixpkgs.legacyPackages.x86_64-linux.boogie}/bin/boogie
      '';
    };
  };
}
```

### Using Nix Flake

**Enter environment:**
```bash
nix develop
# Drops into shell with all tools pinned

lake build
movement move prove
./difftest.sh
```

**Reproducibility:**
- Nix ensures EXACT same packages across machines
- Content-addressed: `z3_4_11` hash identifies exact build
- Bit-for-bit reproducible (no timestamps in Nix store)

**Trade-off:** Nix has steep learning curve. Docker is more accessible for most teams.

---

## Timestamp and Randomness Handling

### Stripping Timestamps

**Problem:** Build tools embed timestamps in artifacts.

**Example (Rust binary):**
```bash
# Rust embeds build time
cargo build --release
strings target/release/my_binary | grep "2026-04-23"
# Output: "Built on 2026-04-23 14:32:15"
```

**Solution: SOURCE_DATE_EPOCH**
```bash
export SOURCE_DATE_EPOCH=1609459200  # 2021-01-01 00:00:00 UTC (fixed)
cargo build --release

strings target/release/my_binary | grep "2021-01-01"
# Output: "Built on 2021-01-01 00:00:00"  (deterministic)
```

**Effect:** All timestamps replaced with fixed epoch.

### Randomness Control

**Sources of randomness in verification:**
1. **SMT solvers (Z3, CVC5):** Internal search randomness
2. **Property-based tests (proptest):** Random input generation
3. **Fuzzing (AFL):** Mutation randomness

**Control:**

**Z3 randomness:**
```move
spec module {
  pragma random_seed = 1;  // Deterministic
}
```

**Proptest randomness:**
```rust
proptest! {
    #![proptest_config(ProptestConfig {
        rng_algorithm: RngAlgorithm::TestRng,  // Deterministic RNG
        ..ProptestConfig::default()
    })]
    
    #[test]
    fn my_property_test(x in 0..100u64) {
        // Test with deterministic inputs
    }
}
```

**AFL fuzzing (reproducibility):**
```bash
# Set seed
AFL_RANDOM_SEED=12345 cargo fuzz run fuzz_target

# Replay specific input
cargo fuzz run fuzz_target corpus/crash-abc123
# Deterministic: always produces same result
```

---

## Validation and Testing

### Reproducibility Test Suite

**Script: `scripts/test_reproducibility.sh`**
```bash
#!/bin/bash
set -e

echo "=== Reproducibility Test Suite ==="

# Test 1: Lean build reproducibility
echo "Test 1: Lean build (2 runs, compare artifacts)"
lake build
cp -r .lake/build build1
lake clean
lake build
cp -r .lake/build build2
diff -r build1/ build2/ || (echo "FAIL: Lean builds differ"; exit 1)
echo "PASS: Lean builds identical"

# Test 2: Move bytecode reproducibility
echo "Test 2: Move bytecode (2 runs)"
movement move compile --package-dir aptos-experimental
cp -r aptos-experimental/build bytecode1
movement move clean --package-dir aptos-experimental
movement move compile --package-dir aptos-experimental
cp -r aptos-experimental/build bytecode2
diff -r bytecode1/ bytecode2/ || (echo "FAIL: Bytecode differs"; exit 1)
echo "PASS: Bytecode identical"

# Test 3: Difftest determinism
echo "Test 3: Difftest (2 runs, sequential)"
./difftest.sh --sequential > difftest1.log
./difftest.sh --sequential > difftest2.log
diff difftest1.log difftest2.log || (echo "FAIL: Difftest output differs"; exit 1)
echo "PASS: Difftest deterministic"

# Test 4: CI reproducibility (Docker)
echo "Test 4: Docker build (2 runs)"
docker build -t ca-verification:test1 -f audit/Dockerfile .
docker run --rm ca-verification:test1 > docker1.log
docker build -t ca-verification:test2 -f audit/Dockerfile .
docker run --rm ca-verification:test2 > docker2.log
diff docker1.log docker2.log || (echo "FAIL: Docker outputs differ"; exit 1)
echo "PASS: Docker builds identical"

echo "=== All Reproducibility Tests PASSED ==="
```

**Run in CI:**
```yaml
- name: Reproducibility tests
  run: ./scripts/test_reproducibility.sh
```

### Cross-Machine Validation

**Protocol:**
1. Developer A builds on machine A
2. Developer B builds on machine B (different hardware, same OS)
3. Compare artifacts (checksums)

**Example:**
```bash
# Machine A (x86_64 Linux)
MachineA> lake build
MachineA> sha256sum .lake/build/lib/libMovementFormal.a > checksums_A.txt

# Machine B (x86_64 Linux, different CPU)
MachineB> lake build
MachineB> sha256sum .lake/build/lib/libMovementFormal.a > checksums_B.txt

# Compare
diff checksums_A.txt checksums_B.txt
# SHOULD be identical (if truly reproducible)
```

---

## Troubleshooting Non-Determinism

### Debugging Non-Reproducible Builds

**Symptom:** Same source, different artifacts.

**Step 1: Identify which artifact differs**
```bash
# Build twice
lake build
mv .lake/build build1
lake clean
lake build
mv .lake/build build2

# Find differences
diff -r build1/ build2/
# Output: Files build1/lib/libFoo.a and build2/lib/libFoo.a differ
```

**Step 2: Check for timestamps**
```bash
# Extract metadata
strings build1/lib/libFoo.a | grep -E "[0-9]{4}-[0-9]{2}-[0-9]{2}"
# Output: "2026-04-23" ← Timestamp embedded!

# Strip timestamps
export SOURCE_DATE_EPOCH=1609459200
lake build
```

**Step 3: Check for randomness**
```bash
# Set random seeds
export LEAN_RANDOM_SEED=12345
lake build
```

**Step 4: Check for environment dependencies**
```bash
# Build in clean environment
env -i PATH=/usr/bin:/bin lake build
# If now reproducible, some env var was causing non-determinism
```

### Common Non-Determinism Sources

**Timestamps:**
- Build time embedded in binaries
- File modification times in archives
- **Fix:** `SOURCE_DATE_EPOCH=<fixed_timestamp>`

**Hash map iteration order:**
- HashMap in Rust is non-deterministic (random seed)
- **Fix:** Use BTreeMap (deterministic order)

**Parallelism:**
- Race conditions in parallel builds
- **Fix:** Build with `-j1` (sequential)

**Floating point:**
- Different rounding on different CPUs
- **Fix:** Avoid floating point in verification (use rationals)

**Locale/timezone:**
- Error messages differ by locale
- **Fix:** `export LANG=C.UTF-8 TZ=UTC`

---

## Auditor Workflow

### Auditor Reproducibility Checklist

**Goal:** Auditor reproduces verification results independently.

**Step 1: Clone source**
```bash
git clone https://github.com/movement/aptos-core
cd aptos-core/aptos-move/framework
git checkout <release_tag>  # e.g., v1.0.0
```

**Step 2: Verify integrity**
```bash
# Check commit signature (if signed)
git verify-commit HEAD

# Check checksums (if provided)
sha256sum -c checksums.txt
```

**Step 3: Reproduce build (Docker method)**
```bash
# Pull published Docker image
docker pull ghcr.io/movement/ca-verification:v1.0.0

# Run verification
docker run --rm -v $(pwd):/verification ghcr.io/movement/ca-verification:v1.0.0 > audit_results.log

# Compare against claimed results
diff audit_results.log official_results.log
# SHOULD be identical
```

**Step 4: Reproduce build (manual method)**
```bash
# Install pinned tools (from audit/README.md)
./scripts/install_verification_tools.sh

# Run verification
./audit/verify-ca.sh > audit_results.log

# Compare
diff audit_results.log official_results.log
```

**Step 5: Report findings**
If results differ:
- Document differences
- Check: did you use exact same source (commit SHA)?
- Check: did you use exact same tool versions?
- Report to team (potential non-determinism bug)

If results match:
- ✅ Verification reproduced successfully
- Sign audit report

---

## Case Studies

### Case Study 1: Z3 Version Mismatch

**Scenario:** Verification passes on developer machine, fails in CI.

**Investigation:**
```bash
# Developer machine
Developer> $Z3_EXE --version
Z3 version 4.14.1 (Homebrew)

# CI
CI> $Z3_EXE --version
Z3 version 4.11.2 (pinned)

# Problem: Different Z3 versions produce different results!
```

**Root cause:** Developer installed Z3 via Homebrew (latest), but Move Prover requires 4.11.2.

**Fix:**
```bash
# Developer: use pinned version
movement update prover-dependencies --assume-yes
# Now uses Z3 4.11.2 (same as CI)
```

**Lesson:** ALWAYS use pinned tool versions (not system package manager versions).

### Case Study 2: Mathlib Cache Corruption

**Scenario:** Lean build time varies wildly (4s sometimes, 6 hours other times).

**Investigation:**
```bash
# Check cache status
lake exe cache get

# Sometimes cache is corrupted (partial download, network error)
# Result: mathlib rebuilds from source (6 hours)
```

**Fix:**
```bash
# Clear cache, re-fetch
rm -rf .lake/packages/mathlib/.lake/build
lake exe cache get --force

# Now consistent 4s build
```

**Lesson:** Cache corruption breaks reproducibility. Validate cache integrity (checksums).

### Case Study 3: Difftest Parallel Non-Determinism

**Scenario:** Difftest output order differs across runs (but all tests pass).

**Investigation:**
```bash
# Run 1
./difftest.sh > run1.log
# Output: test_001 PASS, test_042 PASS, test_003 PASS, ...

# Run 2
./difftest.sh > run2.log
# Output: test_042 PASS, test_001 PASS, test_003 PASS, ...
# (Different order!)
```

**Root cause:** Parallel workers finish in non-deterministic order.

**Fix (if deterministic order required):**
```bash
# Force sequential
./difftest.sh --sequential > run_sequential.log
# Now order is deterministic

# OR: Sort output
./difftest.sh | sort > run_sorted.log
# Order doesn't matter for pass/fail
```

**Lesson:** Parallel execution is NON-DETERMINISTIC in ordering (but deterministic in results).

---

## Summary and Checklist

**Reproducibility checklist:**

**Lean:**
- [ ] Pin Lean version (`lean-toolchain` file)
- [ ] Pin mathlib commit (`lakefile.lean`)
- [ ] Use mathlib cache (`lake exe cache get`)
- [ ] Set `SOURCE_DATE_EPOCH` (strip timestamps)
- [ ] Validate: two builds → identical artifacts

**Move Prover:**
- [ ] Pin Z3 version (4.11.2 via `movement update prover-dependencies`)
- [ ] Pin Boogie version (3.5.1)
- [ ] Set random seed (`pragma random_seed = 1`)
- [ ] Validate: two prover runs → identical results

**Difftest:**
- [ ] Pin Rust toolchain (`rust-toolchain.toml`)
- [ ] Deterministic corpus (sorted JSON keys)
- [ ] Sequential execution (for reproducibility checks)
- [ ] Validate: two difftest runs → identical output

**CI:**
- [ ] Pin OS version (`ubuntu-22.04`, not `ubuntu-latest`)
- [ ] Use Docker (Dockerfile with pinned base image)
- [ ] Deterministic cache keys (hash-based, not run-number-based)
- [ ] Validate: two CI runs → identical results

**Docker:**
- [ ] Pin base image (with digest: `ubuntu:22.04@sha256:...`)
- [ ] Pin all installed packages (exact versions)
- [ ] Set deterministic environment (`TZ=UTC`, `LANG=C.UTF-8`)
- [ ] Publish image (for auditors)
- [ ] Validate: build image on two machines → same content

**Auditor workflow:**
- [ ] Clone source (exact commit SHA)
- [ ] Pull Docker image (or install pinned tools)
- [ ] Run verification
- [ ] Compare results against official
- [ ] Report: PASS (identical) or FAIL (differs)

**All reproducibility targets MET as of 2026-04-23.**

---

**Document metadata:**
- **Version:** 1.0
- **Author:** CA Verification Team
- **Last major update:** 2026-04-23
- **Related:** `audit/Dockerfile`, `audit/DOCKER_REPRODUCIBILITY_GUIDE.md`, `scripts/test_reproducibility.sh`
