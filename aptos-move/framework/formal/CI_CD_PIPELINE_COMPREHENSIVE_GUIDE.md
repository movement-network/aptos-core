# CI/CD Pipeline Comprehensive Guide

**Audience:** DevOps engineers, verification engineers maintaining CI infrastructure  
**Prerequisites:** Basic GitHub Actions knowledge, understanding of the verification plan  
**Related:** `VERIFICATION_METRICS_DASHBOARD_GUIDE.md`, `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §10.5-10.6

## Purpose

This guide provides complete documentation of the CA verification CI/CD infrastructure, including:
- All GitHub Actions workflows and their interactions
- Performance budgets and monitoring
- Debugging failed CI runs
- Adding new checks to the pipeline
- Docker reproducibility infrastructure
- Maintenance procedures

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Workflow Inventory](#workflow-inventory)
3. [Performance Budgets](#performance-budgets)
4. [Debugging Failed Runs](#debugging-failed-runs)
5. [Adding New Checks](#adding-new-checks)
6. [Docker Reproducibility](#docker-reproducibility)
7. [Maintenance Procedures](#maintenance-procedures)
8. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### Three-Layer CI Strategy

The CA verification CI follows a **fast-fail → comprehensive** pattern:

```
Layer 1: Quick Check (2 min)
    ↓ (fail fast if broken)
Layer 2: Parallel Verification (6 jobs, ~13 min total wall-clock)
    ├─ Lean Verification (all 5 operations)
    ├─ Move Prover Compilation (all modules)
    ├─ Trust Boundaries Reconciliation
    ├─ Documentation Lint
    ├─ Performance Benchmarks
    └─ Axiom Drift Guard
    ↓
Layer 3: Nightly/Release Checks (difftest corpus, full matrix)
```

**Why this structure:**
- Quick check (Layer 1) catches 80% of breakage in 2 minutes
- Parallel jobs (Layer 2) maximize throughput (13 min vs 45+ min sequential)
- Expensive checks (Layer 3) run off-PR to keep feedback loop fast

### Workflow File Locations

All workflows live in `.github/workflows/`:

```
.github/workflows/
├── ca-verification-suite.yaml        # Main suite (Layers 1+2)
├── axiom-diff-ca.yaml                # Axiom baseline guard
├── lean-ca.yaml                      # Lean-only verification (used by suite)
├── move-prover-ca.yaml               # Move Prover compilation
└── difftest-nightly.yaml             # Full difftest corpus (nightly)
```

### Concurrency Control

All workflows use `concurrency.group` to auto-cancel stale runs:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

This prevents pile-ups when pushing multiple commits to a PR.

---

## Workflow Inventory

### 1. `ca-verification-suite.yaml` — Main Verification Suite

**Triggers:**
- Push to `main`, `movement`, `lean-fv` branches (paths: `formal/**`, `confidential_asset/**`)
- Pull requests touching same paths
- Manual via `workflow_dispatch`

**Jobs (6 parallel):**

#### Job 1: `quick-check` (2 min, fails fast)
```yaml
runs-on: ubuntu-latest
timeout-minutes: 5
steps:
  - Install Lean v4.24.0 via elan
  - Fetch mathlib cache (lake exe cache get)
  - Run scripts/run_verification_suite.sh --quick
```

**What it checks:**
- Lean tree compiles (no syntax errors)
- Basic imports resolve
- No obvious `sorry` in critical files
- Move source parses

**Failure modes:**
- Lean syntax errors → check recent `.lean` edits
- Missing mathlib cache → usually transient, retry
- Import cycle → check recent `import` additions

#### Job 2: `lean-verification` (5-7 min with cache)
```yaml
needs: quick-check
timeout-minutes: 15
steps:
  - Install Lean v4.24.0
  - Fetch mathlib cache
  - lake build (full tree)
  - Check for sorry (grep -r "sorry" ... | wc -l)
  - Verify all operations (./audit/verify-ca.sh --stack lean)
```

**What it checks:**
- Full Lean tree builds successfully
- Zero `sorry` placeholders in `ConfidentialAsset/` proofs
- All 5 operations (Registration, Withdrawal, Transfer, Normalization, Rotation) verify

**Performance budget:** ≤10 min cold, ≤3 min per operation  
**Current typical:** ~6 min with warm cache

**Failure modes:**
- Build timeout → performance regression, see [Performance Optimization](#performance-budgets)
- Sorry found → incomplete proof landed, revert or complete
- Single operation fails → check that operation's EvalEquiv file

#### Job 3: `move-prover-compilation` (1-2 min)
```yaml
needs: quick-check
timeout-minutes: 10
env:
  BOOGIE_EXE: /usr/local/bin/boogie
  Z3_EXE: /usr/local/bin/z3
  CVC5_EXE: /usr/local/bin/cvc5
steps:
  - Install Movement CLI
  - movement update prover-dependencies --assume-yes
  - movement move prove --package-dir aptos-experimental --filter confidential_*
```

**What it checks:**
- All CA MSL specs compile to Boogie without errors
- Z3 4.11.2 / Boogie 3.5.1 / CVC5 0.0.3 installed correctly
- No `pragma verify = false` regressions

**Performance budget:** ≤2 min per module, ≤10 min total  
**Current typical:** ~1-2 min (0 VCs until ristretto255 patches land)

**Failure modes:**
- Boogie compilation error → MSL syntax error or ristretto255 regression
- Z3 version mismatch → check `movement update prover-dependencies` output
- Timeout → spec too complex, needs `pragma timeout = 120` or refactor

#### Job 4: `trust-boundaries-reconciliation` (30 sec)
```yaml
needs: quick-check
timeout-minutes: 5
steps:
  - ./scripts/reconcile_trust_boundaries.sh
```

**What it checks:**
- `TRUST_BOUNDARIES.md` axiom count matches `#print axioms` output
- All `pragma opaque` declarations documented
- No undocumented axioms snuck in

**Performance budget:** <1 min  
**Current typical:** ~30 seconds

**Failure modes:**
- Mismatch → new axiom added without updating `TRUST_BOUNDARIES.md`
- Script error → recent refactor broke axiom extraction

#### Job 5: `documentation-lint` (1 min)
```yaml
needs: quick-check
timeout-minutes: 5
steps:
  - Check all .md files have valid internal links
  - Check CLAIMS.md entries match theorem names
  - Validate COMPREHENSIVE_GUIDES_INDEX.md links
```

**What it checks:**
- No broken internal links in documentation
- `CLAIMS.md` file:line references are accurate
- Cross-references between guides resolve

**Performance budget:** <2 min  
**Current typical:** ~1 min

**Failure modes:**
- Broken link → file moved/renamed, update references
- Missing claim → new theorem lacks `CLAIMS.md` entry

#### Job 6: `performance-benchmarks` (2-3 min)
```yaml
needs: quick-check
timeout-minutes: 10
steps:
  - ./scripts/benchmark_verification.sh --format json > benchmark.json
  - Upload benchmark.json as artifact
  - Compare against baseline (alert if >20% regression)
```

**What it checks:**
- Per-operation Lean build time (baseline: Registration 3.0s, others 0.5-0.7s)
- Full tree build time (baseline: 1.6s for 1886 jobs)
- Move Prover compilation time per module

**Performance budget:** See [Performance Budgets](#performance-budgets)  
**Current typical:** ~2 min to benchmark all operations

**Failure modes:**
- Regression >20% → investigate recent changes, see Performance Guide
- Benchmark script error → check `scripts/benchmark_verification.sh`

### 2. `axiom-diff-ca.yaml` — Axiom Drift Guard

**Triggers:**
- Push to `main`, `movement`, `lean-fv` branches
- Pull requests (runs on every commit)

**What it does:**
```yaml
steps:
  - lake build MovementFormal.Experimental.ConfidentialAsset
  - Extract #print axioms output for all top-level theorems
  - Diff against audit/axiom-baseline.txt
  - Fail if ANY new axioms detected
```

**Why it exists:** Prevents silent trust-base expansion. Every axiom must be reviewed and documented.

**Performance budget:** <2 min  
**Failure modes:**
- New axiom detected → intended? Update baseline + document in `TRUST_BOUNDARIES.md`. Unintended? Revert.

### 3. `lean-ca.yaml` — Standalone Lean Verification

**Triggers:**
- Called by `ca-verification-suite.yaml`
- Manual dispatch for quick Lean-only checks

**Identical to** `lean-verification` job in main suite, but runnable standalone.

### 4. `move-prover-ca.yaml` — Standalone Move Prover

**Triggers:**
- Called by `ca-verification-suite.yaml`
- Manual dispatch for quick MSL-only checks

**Identical to** `move-prover-compilation` job in main suite.

### 5. `difftest-nightly.yaml` — Full Corpus (Nightly)

**Triggers:**
- Scheduled: `cron: '0 6 * * *'` (6am UTC daily)
- Manual dispatch

**What it does:**
```yaml
steps:
  - Build Lean tree
  - Build difftest harness (Rust)
  - Run all 97+ corpus rows
  - Generate coverage report
  - Upload failures as artifacts
```

**Why nightly, not PR:** Difftest corpus takes ~15-20 min to run full matrix (Lean executor + VM executor for 97 scenarios). Too slow for PR feedback loop.

**Performance budget:** ≤30 min  
**Current typical:** ~20 min

**Failure modes:**
- Scenario mismatch → VM behavior changed, or Lean model wrong
- Coverage drop → new operation added without corpus rows
- Timeout → corpus too large, needs parallelization

---

## Performance Budgets

### Per-Job Budgets (Layer 2, parallel)

| Job | Budget | Current | Alert Threshold | Crit Threshold |
|-----|--------|---------|-----------------|----------------|
| quick-check | 5 min | 2 min | 3 min | 5 min |
| lean-verification | 15 min | 6 min | 10 min | 15 min |
| move-prover-compilation | 10 min | 2 min | 5 min | 10 min |
| trust-boundaries | 5 min | 30s | 2 min | 5 min |
| documentation-lint | 5 min | 1 min | 3 min | 5 min |
| performance-benchmarks | 10 min | 2 min | 5 min | 10 min |

**Total wall-clock (parallel):** ~13 min typical, 15 min budget

### Per-Operation Budgets (Lean)

| Operation | Budget | Current | File |
|-----------|--------|---------|------|
| Registration (rebuild) | 3 min | 3.0s | `Registration/EvalEquivRebuild.lean` |
| Withdrawal | 3 min | 0.5s | `Withdrawal/EvalEquiv.lean` |
| Transfer | 3 min | 0.7s | `Transfer/EvalEquiv.lean` |
| Normalization | 3 min | 0.5s | `Normalization/EvalEquiv.lean` |
| Rotation | 3 min | 0.5s | `Rotation/EvalEquiv.lean` |

**Full tree:** ≤10 min cold, currently ~1.6s (1886 jobs with warm cache)

### Alert Levels

**Green:** Within budget  
**Yellow:** >50% of budget (e.g., Lean verification >7.5 min) → investigate, not blocked  
**Red:** Exceeds budget → blocks merge, must fix

### How Budgets Are Monitored

1. **`performance-benchmarks` job** runs `scripts/benchmark_verification.sh` every PR
2. Outputs JSON with per-operation timings
3. Compared against baseline in `audit/performance-baseline.json`
4. PR comment posted with comparison table if >10% change detected

Example PR comment:
```
⚠️ Performance regression detected:

| Operation | Baseline | Current | Change |
|-----------|----------|---------|--------|
| Registration | 3.0s | 4.2s | +40% ⚠️ |
| Transfer | 0.7s | 0.7s | 0% ✅ |

Investigate recent changes to Registration/EvalEquivRebuild.lean
```

---

## Debugging Failed Runs

### Quick Check Failures

**Symptom:** `quick-check` job fails, all other jobs skipped

**Common causes:**
1. **Lean syntax error**
   ```
   error: expected ')', found ':'
   ```
   **Fix:** Check recent `.lean` file edits, fix syntax

2. **Missing mathlib cache**
   ```
   Cache fetch failed, will build from source (slow)
   ```
   **Fix:** Usually transient, retry workflow. If persistent, check mathlib compatibility.

3. **Import cycle**
   ```
   error: import cycle detected
   ```
   **Fix:** Check recent `import` statements, break cycle

**Debugging steps:**
1. Click "Quick Sanity Check" job in GitHub Actions
2. Expand failing step
3. Read error message (usually points to exact file:line)
4. Fix locally, test with `lake build`, push fix

### Lean Verification Failures

**Symptom:** `lean-verification` job fails, other jobs may pass

**Common causes:**

1. **Build timeout (>15 min)**
   ```
   Error: The operation was canceled.
   ```
   **Diagnosis:** Performance regression
   **Fix:** See [LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md](LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md)
   - Check recent changes for `simp` → `simp only`
   - Check for missing `@[irreducible]`
   - Check for expensive elaboration in theorem statements

2. **Sorry detected**
   ```
   ❌ Found 3 sorry placeholders
   ```
   **Diagnosis:** Incomplete proof landed
   **Fix:** Either complete the proof or revert the commit
   - `grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/`
   - Replace `sorry` with actual proof

3. **Verification failure (theorem doesn't hold)**
   ```
   type mismatch
     eval ... = ...
   has type
     ExecResult
   but is expected to have type
     Bool
   ```
   **Diagnosis:** Proof broken by recent change
   **Fix:** 
   - Identify which theorem failed (check build log)
   - Test locally: `cd lean && lake build MovementFormal.Experimental.ConfidentialAsset.<Operation>.EvalEquiv`
   - Fix theorem or revert breaking change

**Debugging steps:**
1. Click "Lean Verification (All 5 Operations)" job
2. Expand "Build Lean tree" step
3. Search log for `error:` (Lean errors) or `❌` (sorry check)
4. Download build log artifact if needed (Actions → Summary → Artifacts)
5. Reproduce locally:
   ```bash
   cd aptos-move/framework/formal/lean
   lake exe cache get
   lake build
   ```

### Move Prover Failures

**Symptom:** `move-prover-compilation` job fails

**Common causes:**

1. **Boogie compilation error**
   ```
   error: undeclared identifier: spec_scalar_from_u64_internal
   ```
   **Diagnosis:** MSL spec syntax error or ristretto255 regression
   **Fix:** Check recent `.spec.move` edits
   - Test locally: `movement move prove --package-dir aptos-experimental --filter confidential_asset`

2. **Z3 version mismatch**
   ```
   expected at most version 4.11.2 but found 4.14.x
   ```
   **Diagnosis:** Wrong Z3 version installed
   **Fix:** CI should install correct version via `movement update prover-dependencies`
   - If broken, check workflow's setup steps

3. **Verification condition timeout**
   ```
   timeout for VC at line 42
   ```
   **Diagnosis:** Spec too complex for Z3
   **Fix:** Add `pragma timeout = 120` or refactor spec

**Debugging steps:**
1. Click "Move Prover Compilation" job
2. Expand "Run Move Prover" step
3. Search log for `error:` or `timeout`
4. Reproduce locally:
   ```bash
   movement update prover-dependencies --assume-yes
   cd aptos-move/framework/aptos-experimental
   movement move prove --filter confidential_asset
   ```

### Axiom Drift Failures

**Symptom:** `axiom-diff-ca` workflow fails

**Common causes:**

1. **New axiom detected**
   ```
   + axiom foo : ∀ x, P x
   Diff: 1 new axiom
   ```
   **Diagnosis:** New axiom introduced
   **Fix (if intended):**
   - Update `audit/axiom-baseline.txt`: `./audit/verify-ca.sh --coverage > audit/axiom-baseline.txt`
   - Document in `TRUST_BOUNDARIES.md` §3 "Residual axioms in Lean"
   - Add justification (crypto assumption? temporary?)
   
   **Fix (if unintended):**
   - Find where axiom was introduced: `git log -p audit/axiom-baseline.txt`
   - Revert or replace with theorem

**Debugging steps:**
1. Click failing `axiom-diff-ca` run
2. Read diff output (shows exact axiom added/removed)
3. Decide: intended or bug?
4. If intended, update baseline + document. If bug, revert.

### Performance Benchmark Failures

**Symptom:** `performance-benchmarks` job fails or posts regression warning

**Common causes:**

1. **Regression >20%**
   ```
   Registration: baseline 3.0s, current 4.5s (+50% ⚠️)
   ```
   **Diagnosis:** Performance regression
   **Fix:** See [LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md](LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md)
   - Profile with `lake build --profile`
   - Check recent changes for expensive tactics
   - Consider `@[irreducible]` if missing

2. **Benchmark script error**
   ```
   ./scripts/benchmark_verification.sh: line 42: syntax error
   ```
   **Diagnosis:** Script broken by recent change
   **Fix:** Check `scripts/benchmark_verification.sh` edits

**Debugging steps:**
1. Click "Performance Benchmarks" job
2. Download `benchmark.json` artifact (Actions → Summary → Artifacts)
3. Compare against `audit/performance-baseline.json`
4. Investigate operations with >20% regression

---

## Adding New Checks

### Adding a New Operation to CI

When you add a 6th operation (e.g., `Deposit`), update CI:

**Step 1:** Add to `lean-verification` job in `ca-verification-suite.yaml`:
```yaml
- name: Verify all operations
  run: |
    cd ${{ env.FORMAL_ROOT }}
    for op in register withdraw transfer normalize rotate deposit; do
      ./audit/verify-ca.sh --op $op --stack lean || exit 1
    done
```

**Step 2:** Add to performance baseline:
```bash
cd aptos-move/framework/formal
./scripts/benchmark_verification.sh --format json > audit/performance-baseline.json
git add audit/performance-baseline.json
git commit -m "perf: add Deposit to baseline"
```

**Step 3:** Add to `CLAIMS.md`:
```markdown
## Deposit

**Property:** Deposit increments pending balance by deposit amount  
**Lean theorem:** `deposit_eval_equiv_functional_sim` (`Deposit/EvalEquiv.lean:542`)  
**Rerun command:** `./audit/verify-ca.sh --op deposit --stack lean`  
**Axioms:** 21 crypto axioms (see `TRUST_BOUNDARIES.md` §2)
```

**Step 4:** Update `verify-ca.sh`:
```bash
# In verify-ca.sh, add to OPERATIONS array:
OPERATIONS=("register" "withdraw" "transfer" "normalize" "rotate" "deposit")
```

**Step 5:** Test locally:
```bash
./audit/verify-ca.sh --op deposit
# Should pass in ≤3 min
```

### Adding a New Verification Check

Example: Add a check that all `spec` blocks have `aborts_if` clauses.

**Step 1:** Create script `scripts/check_aborts_if_coverage.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SPEC_DIR="aptos-move/framework/aptos-experimental/sources/confidential_asset"
MISSING=0

for file in "$SPEC_DIR"/*.spec.move; do
  SPEC_BLOCKS=$(grep -c "^spec " "$file" || true)
  ABORTS_IFS=$(grep -c "aborts_if" "$file" || true)
  
  if [ "$ABORTS_IFS" -lt "$SPEC_BLOCKS" ]; then
    echo "⚠️ $file: $SPEC_BLOCKS spec blocks, only $ABORTS_IFS with aborts_if"
    MISSING=$((MISSING + 1))
  fi
done

if [ "$MISSING" -gt 0 ]; then
  echo "❌ $MISSING files missing aborts_if clauses"
  exit 1
fi

echo "✅ All spec blocks have aborts_if"
```

**Step 2:** Add job to `ca-verification-suite.yaml`:
```yaml
  aborts-if-coverage:
    name: Check aborts_if Coverage
    runs-on: ubuntu-latest
    needs: quick-check
    timeout-minutes: 2
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Check aborts_if coverage
        run: ./scripts/check_aborts_if_coverage.sh
```

**Step 3:** Test locally:
```bash
chmod +x scripts/check_aborts_if_coverage.sh
./scripts/check_aborts_if_coverage.sh
```

**Step 4:** Commit and push:
```bash
git add scripts/check_aborts_if_coverage.sh .github/workflows/ca-verification-suite.yaml
git commit -m "ci: add aborts_if coverage check"
git push
```

**Step 5:** Verify in PR that new job runs and passes.

### Adding a Nightly/Weekly Check

Example: Weekly full difftest corpus run.

**Step 1:** Create `.github/workflows/difftest-weekly.yaml`:
```yaml
name: Difftest Weekly Full Corpus

on:
  schedule:
    - cron: '0 2 * * 0'  # 2am UTC every Sunday
  workflow_dispatch:

jobs:
  difftest-full:
    name: Full Difftest Corpus (97 scenarios)
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Install Lean
        run: |
          curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y --default-toolchain v4.24.0
          echo "$HOME/.elan/bin" >> $GITHUB_PATH
      
      - name: Fetch mathlib cache
        run: |
          cd aptos-move/framework/formal/lean
          lake exe cache get
      
      - name: Build Lean tree
        run: |
          cd aptos-move/framework/formal/lean
          lake build
      
      - name: Build difftest harness
        run: |
          cd aptos-move/framework/formal/difftest
          cargo build --release
      
      - name: Run full corpus
        run: |
          cd aptos-move/framework/formal/difftest
          ./difftest.sh --all --output json > corpus-results.json
      
      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: difftest-corpus-results
          path: aptos-move/framework/formal/difftest/corpus-results.json
          retention-days: 30
      
      - name: Check coverage
        run: |
          cd aptos-move/framework/formal/difftest
          PASS=$(jq '.pass' corpus-results.json)
          TOTAL=$(jq '.total' corpus-results.json)
          COVERAGE=$((PASS * 100 / TOTAL))
          
          if [ "$COVERAGE" -lt 95 ]; then
            echo "❌ Coverage $COVERAGE% < 95% target"
            exit 1
          fi
          
          echo "✅ Coverage $COVERAGE% ≥ 95%"
```

**Step 2:** Test manually via workflow_dispatch before enabling schedule.

**Step 3:** Document in this guide under "Workflow Inventory".

---

## Docker Reproducibility

### Docker Image for Auditors

**Location:** `audit/Dockerfile`

**What it pins:**
- Ubuntu 22.04 base
- Lean v4.24.0 (via elan)
- Movement CLI (latest stable)
- Boogie 3.5.1
- Z3 4.11.2
- CVC5 0.0.3
- Rust 1.75 (for difftest harness)

**Build:**
```bash
cd aptos-move/framework/formal/audit
docker build -t ca-verification:latest .
```

**Run verification:**
```bash
docker run --rm -v $(pwd):/workspace ca-verification:latest \
  /workspace/audit/verify-ca.sh --op transfer
```

**Why Docker:**
- Pins all tool versions → reproducibility
- Auditors get identical environment
- CI can use same image → CI = local

### Docker Image Maintenance

**Update Lean version:**
1. Edit `audit/Dockerfile`:
   ```dockerfile
   ENV LEAN_VERSION=v4.25.0
   RUN elan install $LEAN_VERSION && elan default $LEAN_VERSION
   ```

2. Rebuild and test:
   ```bash
   docker build -t ca-verification:v4.25.0 audit/
   docker run --rm ca-verification:v4.25.0 lean --version
   # Should output: Lean (version 4.25.0, ...)
   ```

3. Update `audit/DOCKER_REPRODUCIBILITY_GUIDE.md` with new version.

4. Push image to registry (if published):
   ```bash
   docker tag ca-verification:v4.25.0 ghcr.io/movement/ca-verification:v4.25.0
   docker push ghcr.io/movement/ca-verification:v4.25.0
   ```

**Update Z3/Boogie versions:**
1. Edit `audit/Dockerfile`:
   ```dockerfile
   ENV Z3_VERSION=4.12.0
   RUN wget https://github.com/Z3Prover/z3/releases/download/z3-$Z3_VERSION/z3-$Z3_VERSION-x64-glibc-2.35.zip
   # ... extract and install ...
   ```

2. Test compatibility with Movement CLI:
   ```bash
   docker run --rm ca-verification:test movement move prove --help
   # Check for version warnings
   ```

3. If Movement CLI rejects new version, either:
   - Revert to compatible version, OR
   - Update Movement CLI in Dockerfile

**Monthly maintenance:**
- Rebuild image with latest patches (Ubuntu security updates)
- Test full verification suite passes
- Push updated image with date tag: `ca-verification:2026-04`

### Using Docker in CI

**Option 1: Build image in CI (slower, always fresh)**
```yaml
- name: Build verification image
  run: docker build -t ca-verification:ci audit/

- name: Run verification
  run: |
    docker run --rm -v ${{ github.workspace }}:/workspace \
      ca-verification:ci /workspace/audit/verify-ca.sh
```

**Option 2: Use pre-built image (faster, requires registry)**
```yaml
- name: Pull verification image
  run: docker pull ghcr.io/movement/ca-verification:latest

- name: Run verification
  run: |
    docker run --rm -v ${{ github.workspace }}:/workspace \
      ghcr.io/movement/ca-verification:latest \
      /workspace/audit/verify-ca.sh
```

**Current approach:** CI installs tools directly (not Docker) for speed. Docker is for auditor reproducibility.

---

## Maintenance Procedures

### Weekly Maintenance

**Monday morning checklist:**

1. **Check CI health**
   ```bash
   # Open GitHub Actions, check last 7 days
   # Any recurring failures? Flaky tests?
   ```

2. **Review performance trends**
   ```bash
   # Download last 7 days of benchmark.json artifacts
   # Plot build times, look for gradual regressions
   ```

3. **Check cache hit rates**
   ```bash
   # In CI logs, search for "Cache fetch failed"
   # If >20% of runs fail cache fetch, investigate mathlib compatibility
   ```

4. **Update dependencies (if needed)**
   ```bash
   cd aptos-move/framework/formal/lean
   lake update
   # Test locally before pushing
   ```

### Monthly Maintenance

**First Monday of month:**

1. **Update Docker image**
   ```bash
   cd aptos-move/framework/formal/audit
   docker build --no-cache -t ca-verification:$(date +%Y-%m) .
   # Test full suite passes
   docker run --rm -v $(pwd)/..:/workspace \
     ca-verification:$(date +%Y-%m) /workspace/audit/verify-ca.sh
   # If pass, push to registry
   ```

2. **Review and prune artifacts**
   ```bash
   # GitHub Actions → Settings → Actions → Artifacts
   # Delete artifacts >30 days old (benchmark.json, logs)
   ```

3. **Audit axiom baseline**
   ```bash
   cd aptos-move/framework/formal
   ./audit/verify-ca.sh --coverage > /tmp/axioms-current.txt
   diff audit/axiom-baseline.txt /tmp/axioms-current.txt
   # Should be zero diff; if not, investigate
   ```

4. **Check for dependency updates**
   ```bash
   # Check for new Lean releases: https://github.com/leanprover/lean4/releases
   # Check for new Z3 releases: https://github.com/Z3Prover/z3/releases
   # Update if compatible with Movement CLI
   ```

### Quarterly Maintenance

**First Monday of quarter:**

1. **Full verification matrix audit**
   - Run all operations, all stacks, all modes
   - Document any new failure modes
   - Update troubleshooting section of this guide

2. **Performance budget review**
   - Analyze 3 months of benchmark data
   - Adjust budgets if consistently under/over
   - Update table in §3 "Performance Budgets"

3. **CI efficiency review**
   - Check average PR feedback time (target: <15 min)
   - Check cache hit rate (target: >80%)
   - Check flaky test rate (target: <5%)
   - Optimize if missing targets

4. **Documentation sync**
   - Update all CI-related guides with new learnings
   - Add new troubleshooting entries
   - Archive obsolete workflows

### Annual Maintenance

**January (after holidays):**

1. **CI infrastructure overhaul**
   - Review all workflows for obsolete patterns
   - Consolidate duplicated logic
   - Update to latest GitHub Actions syntax

2. **Baseline reset**
   - Regenerate `performance-baseline.json` from scratch
   - Regenerate `axiom-baseline.txt`
   - Document in git history why baseline changed

3. **Dependency lockfile update**
   - Update `audit/toolchain.lock` with latest stable versions
   - Test full reproducibility from clean clone
   - Update `DOCKER_REPRODUCIBILITY_GUIDE.md`

---

## Troubleshooting

### Common Issues

#### Issue: "Cache fetch failed" in every CI run

**Symptom:**
```
lake exe cache get || echo "Cache fetch failed, continuing..."
```
Appears in every run, builds take 30+ minutes.

**Diagnosis:** Mathlib version incompatible or cache server down.

**Fix:**
1. Check mathlib compatibility:
   ```bash
   cd aptos-move/framework/formal/lean
   cat lean-toolchain  # Should be v4.24.0
   grep leanprover-community/mathlib4 lakefile.lean
   # Version should match cache server
   ```

2. Test cache manually:
   ```bash
   lake exe cache get
   # If "No cache available", check mathlib4 version
   ```

3. If persistent, build mathlib once and cache it:
   ```bash
   lake build Cache  # Builds mathlib (slow, 1-2 hours)
   lake exe cache pack  # Packs for reuse
   ```

#### Issue: Flaky test failures (passes on retry)

**Symptom:** CI fails randomly, succeeds on re-run with no code changes.

**Diagnosis:** Non-deterministic test or timing-dependent assertion.

**Fix:**
1. Identify flaky test from logs
2. Add retry logic if timeout-based:
   ```yaml
   - name: Run flaky step
     uses: nick-invision/retry@v2
     with:
       timeout_minutes: 5
       max_attempts: 3
       command: ./some-flaky-test.sh
   ```
3. If logic bug (non-determinism), fix test to be deterministic

#### Issue: CI passes but local build fails

**Symptom:** PR shows green checkmark, but `lake build` fails locally.

**Diagnosis:** Local environment differs from CI (different Lean version, stale cache, etc.).

**Fix:**
1. Match Lean version:
   ```bash
   cat lean-toolchain  # Should be v4.24.0
   elan show  # Check active toolchain
   elan default v4.24.0  # If mismatch
   ```

2. Clear local cache:
   ```bash
   lake clean
   rm -rf .lake
   lake exe cache get
   lake build
   ```

3. If still fails, reproduce CI environment with Docker:
   ```bash
   docker run --rm -v $(pwd):/workspace ca-verification:latest \
     bash -c "cd /workspace/lean && lake build"
   ```

#### Issue: Performance regression not caught by CI

**Symptom:** Build becomes slow over time, but no single PR flagged.

**Diagnosis:** Gradual regression (each PR +2%, total +30% over 15 PRs).

**Fix:**
1. Identify regression window with bisect:
   ```bash
   git bisect start HEAD v1.0.0
   git bisect run ./scripts/benchmark_verification.sh --quick --exit-on-slow
   ```

2. Once identified, analyze changes in that PR:
   ```bash
   git show <commit> | grep -A10 "\.lean"
   # Look for simp → simp only, new axioms, etc.
   ```

3. Fix root cause (see [LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md](LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md))

4. Tighten performance thresholds:
   ```yaml
   # In ca-verification-suite.yaml
   - name: Check performance
     run: |
       REGRESSION=$(jq '.regression_pct' benchmark.json)
       if [ "$REGRESSION" -gt 10 ]; then  # Was 20, now 10
         exit 1
       fi
   ```

#### Issue: Axiom baseline diff shows false positive

**Symptom:** CI claims new axiom, but `#print axioms` shows same list.

**Diagnosis:** Axiom order changed (non-deterministic output).

**Fix:**
1. Regenerate baseline with sorted output:
   ```bash
   ./audit/verify-ca.sh --coverage | sort > audit/axiom-baseline.txt
   ```

2. Update workflow to sort before diff:
   ```yaml
   - name: Check axiom drift
     run: |
       ./audit/verify-ca.sh --coverage | sort > /tmp/axioms-current.txt
       sort audit/axiom-baseline.txt > /tmp/axioms-baseline-sorted.txt
       diff /tmp/axioms-baseline-sorted.txt /tmp/axioms-current.txt
   ```

### Getting Help

**Internal team:**
- Slack: `#formal-verification` channel
- Tag: `@verification-team` in PR for CI issues

**External (open source):**
- GitHub Discussions: `aptos-core` repo → Discussions → Formal Verification
- File issue: `.github/ISSUE_TEMPLATE/ci-failure.md`

**Escalation:**
- CI infrastructure broken >4 hours → page on-call
- Verification regression blocking release → escalate to PM

---

## Related Guides

- [VERIFICATION_METRICS_DASHBOARD_GUIDE.md](VERIFICATION_METRICS_DASHBOARD_GUIDE.md) — Metrics and observability
- [LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md](LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md) — Fixing performance regressions
- [DOCKER_REPRODUCIBILITY_GUIDE.md](audit/DOCKER_REPRODUCIBILITY_GUIDE.md) — Docker setup details
- [CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md](CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md) §10.5-10.6 — Acceptance criteria

---

**Document Status:** v1.0 (2026-04-22)  
**Maintainer:** Verification team  
**Last Updated:** 2026-04-22  
**Next Review:** 2026-07-22 (quarterly)
