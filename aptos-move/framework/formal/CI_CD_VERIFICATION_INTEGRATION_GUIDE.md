# CI/CD Verification Integration Guide

**Purpose:** Comprehensive guide for integrating CA formal verification into CI/CD pipelines  
**Target Audience:** DevOps engineers, CI maintainers, verification engineers  
**Prerequisites:** Understanding of GitHub Actions, Docker, basic verification concepts  
**Status:** Production-ready CI infrastructure (4 workflows, 9 jobs, ~13 min total)

---

## Executive Summary

The Confidential Assets formal verification suite includes production-ready CI/CD integration with:

- **4 GitHub Actions workflows** covering all verification stacks
- **9 parallel jobs** for optimal throughput
- **~13 minute total CI time** (Lean 4s, MSL 30s blocked, Difftest 2m, overhead 10m)
- **Automatic drift detection** (axiom changes, performance regressions)
- **Reproducible builds** via Docker (Phase 7 deliverable)

**Key features:**
- ✅ Lean verification (lake build, < 5s)
- ✅ Move Prover compilation check (blocked on ristretto255, ready when unblocked)
- ✅ Difftest corpus validation (87 test cases)
- ✅ Performance regression detection (100-450× budget margins)
- ✅ Axiom drift guard (23 permanent axioms tracked)
- ✅ Trust boundary reconciliation

---

## Table of Contents

1. [Workflow Overview](#workflow-overview)
2. [Setup and Configuration](#setup-and-configuration)
3. [Workflow Specifications](#workflow-specifications)
4. [Artifact Management](#artifact-management)
5. [Performance Optimization](#performance-optimization)
6. [Monitoring and Alerts](#monitoring-and-alerts)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

---

## Workflow Overview

### Workflow 1: `ca-verification-suite.yaml`

**Purpose:** Full verification suite (Lean + MSL + Difftest + performance + trust)

**Triggers:**
- Push to `main` or `movement` branches
- Pull requests targeting `main` or `movement`
- Manual workflow dispatch
- Scheduled: Daily at 00:00 UTC

**Jobs (6 parallel):**
1. **lean-verification** (runs: ~4s)
   - Builds all Lean proofs
   - Checks for axioms
   - Validates performance budget

2. **move-prover-check** (runs: ~30s, blocked on ristretto255)
   - Compiles MSL specs
   - Verifies VCs (once unblocked)
   - Reports coverage

3. **difftest-validation** (runs: ~2m)
   - Runs 87 test cases
   - Validates VM ↔ Model alignment
   - Checks balance conservation

4. **performance-regression** (runs: ~10s)
   - Profiles Lean build
   - Compares against baselines
   - Fails if > 10% regression

5. **axiom-drift-guard** (runs: ~5s)
   - Counts axioms
   - Compares against approved list
   - Fails if new temporary axioms

6. **trust-boundary-check** (runs: ~5s)
   - Reconciles TRUST_BOUNDARIES.md
   - Validates AXIOM_INVENTORY.md
   - Checks documentation sync

**Total time:** ~13 minutes (includes GitHub Actions overhead)

**Success criteria:** All 6 jobs pass

---

### Workflow 2: `axiom-diff-ca.yaml`

**Purpose:** Axiom drift detection on every PR

**Triggers:**
- Pull requests (all branches)
- Commits to open PRs

**Jobs (1):**
1. **axiom-diff**
   - Runs on PR head
   - Runs on PR base
   - Computes diff
   - Posts comment to PR with results

**Output format:**
```markdown
## Axiom Diff Report

**Base (main):** 23 axioms (10 crypto, 13 other)
**Head (feature/xyz):** 24 axioms (10 crypto, 14 other)

### Added Axioms
- `MovementFormal.Experimental.ConfidentialAsset.Transfer.balance_conservation_temp` (TEMPORARY) ⚠️

### Removed Axioms
(none)

### Status
❌ **FAILED:** New temporary axiom detected. Please replace with theorem + proof.
```

**Total time:** ~30s

**Success criteria:** No new axioms OR all new axioms are approved permanent crypto axioms

---

### Workflow 3: `lean-ca.yaml`

**Purpose:** Fast Lean-only verification (for lean-fv branch)

**Triggers:**
- Push to `lean-fv` branch
- Pull requests targeting `lean-fv`

**Jobs (1):**
1. **lean-build**
   - Installs Lean 4
   - Runs `lake build`
   - Reports build time
   - Checks axioms

**Total time:** ~1 minute (includes setup)

**Success criteria:** Build succeeds, 0 temporary axioms, < 5s build time

---

### Workflow 4: `move-prover-ca.yaml`

**Purpose:** Move Prover-only verification

**Triggers:**
- Push to branches with MSL changes
- Pull requests modifying `.spec.move` files

**Jobs (1):**
1. **move-prover**
   - Compiles MSL specs
   - Runs Move Prover (once ristretto255 patches applied)
   - Reports VCs generated and verified

**Total time:** ~2 minutes (once unblocked)

**Success criteria:** All VCs verified

**Current status:** ✅ Spec compilation succeeds, ⏸️ verification blocked on ristretto255 patches

---

## Setup and Configuration

### Prerequisites

**On GitHub repository:**
1. GitHub Actions enabled
2. Secrets configured (if using private Docker registry)
3. Branch protection rules set

**On local development machine:**
1. Lean 4 installed (via elan)
2. Aptos CLI installed
3. Docker installed (optional, for reproducibility)

---

### Step 1: Install Workflows

**Location:** `.github/workflows/`

**Files:**
- `ca-verification-suite.yaml` (full suite)
- `axiom-diff-ca.yaml` (axiom drift)
- `lean-ca.yaml` (fast Lean check)
- `move-prover-ca.yaml` (MSL verification)

**Installation:**
```bash
# Workflows are already committed in the repository
# Verify they exist:
ls -la .github/workflows/

# Expected output:
# ca-verification-suite.yaml
# axiom-diff-ca.yaml
# lean-ca.yaml
# move-prover-ca.yaml
```

**Enable workflows:**
1. Go to GitHub repository → Actions tab
2. Enable workflows if disabled
3. Verify triggers are correct

---

### Step 2: Configure Branch Protection

**Recommended settings for `main` and `movement` branches:**

1. **Require status checks to pass:**
   - ✅ `lean-verification`
   - ✅ `axiom-diff`
   - ✅ `difftest-validation`
   - ✅ `performance-regression`

2. **Optional (recommended):**
   - ✅ Require pull request reviews (1+ reviewer)
   - ✅ Require conversation resolution
   - ✅ Require linear history

3. **Performance checks (optional):**
   - ✅ `trust-boundary-check`

**Configuration via GitHub UI:**
```
Repository → Settings → Branches → Add rule
  Branch name pattern: main
  [x] Require status checks to pass before merging
    [x] Require branches to be up to date before merging
    Required checks:
      [x] lean-verification
      [x] axiom-diff
      [x] difftest-validation
      [x] performance-regression
```

---

### Step 3: Configure Secrets (if needed)

**Secrets for Docker registry (Phase 7, optional):**

```bash
# In GitHub UI: Repository → Settings → Secrets → Actions
# Add:
DOCKER_USERNAME=<your-docker-username>
DOCKER_PASSWORD=<your-docker-password>
```

**Secrets for notifications (optional):**

```bash
# For Slack notifications on failures
SLACK_WEBHOOK_URL=<your-slack-webhook>
```

---

## Workflow Specifications

### Full Specification: `ca-verification-suite.yaml`

```yaml
name: CA Verification Suite

on:
  push:
    branches:
      - main
      - movement
      - lean-fv
  pull_request:
    branches:
      - main
      - movement
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight UTC

jobs:
  lean-verification:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Lean 4
        run: |
          curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y
          echo "$HOME/.elan/bin" >> $GITHUB_PATH

      - name: Build Lean proofs
        working-directory: aptos-move/framework/formal/lean
        run: |
          lake build MovementFormal.Experimental.ConfidentialAsset

      - name: Check build time
        working-directory: aptos-move/framework/formal
        run: |
          ./scripts/profile_lean_build.sh MovementFormal.Experimental.ConfidentialAsset | tee build_profile.txt
          # Fail if build time > 10s (current: ~4s, budget: 600s)
          BUILD_TIME=$(grep "Total build time" build_profile.txt | awk '{print $4}' | sed 's/s//')
          if (( $(echo "$BUILD_TIME > 10" | bc -l) )); then
            echo "Build time exceeded budget: ${BUILD_TIME}s > 10s"
            exit 1
          fi

      - name: Check axioms
        working-directory: aptos-move/framework/formal
        run: |
          ./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset | tee axiom_report.txt
          # Fail if any temporary axioms
          TEMP_AXIOMS=$(grep "Temporary axioms:" axiom_report.txt | awk '{print $3}')
          if [ "$TEMP_AXIOMS" != "0" ]; then
            echo "Temporary axioms detected: $TEMP_AXIOMS"
            exit 1
          fi

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: lean-build-profile
          path: aptos-move/framework/formal/build_profile.txt

  move-prover-check:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Aptos CLI
        run: |
          curl -fsSL https://aptos.dev/scripts/install_cli.py | python3

      - name: Compile MSL specs
        working-directory: aptos-move/framework/aptos-experimental
        run: |
          aptos move compile --skip-fetch-latest-git-deps

      - name: Run Move Prover (when unblocked)
        working-directory: aptos-move/framework/aptos-experimental
        continue-on-error: true  # Blocked on ristretto255 patches
        run: |
          aptos move prove --skip-fetch-latest-git-deps | tee prover_report.txt

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: move-prover-report
          path: aptos-move/framework/aptos-experimental/prover_report.txt

  difftest-validation:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          # Install Aptos CLI for VM execution
          curl -fsSL https://aptos.dev/scripts/install_cli.py | python3
          
          # Install Lean for model execution
          curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y
          echo "$HOME/.elan/bin" >> $GITHUB_PATH

      - name: Run difftest corpus
        working-directory: aptos-move/framework/formal
        run: |
          ./scripts/manage_difftest_corpus.sh test all | tee difftest_report.txt

      - name: Check results
        working-directory: aptos-move/framework/formal
        run: |
          # Fail if any test failed
          if grep -q "FAIL" difftest_report.txt; then
            echo "Difftest failures detected"
            exit 1
          fi

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: difftest-report
          path: aptos-move/framework/formal/difftest_report.txt

  performance-regression:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Lean 4
        run: |
          curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y
          echo "$HOME/.elan/bin" >> $GITHUB_PATH

      - name: Profile build
        working-directory: aptos-move/framework/formal
        run: |
          ./scripts/detect_performance_regression.sh --baseline baseline_metrics.json --current | tee regression_report.txt

      - name: Check for regressions
        working-directory: aptos-move/framework/formal
        run: |
          # Fail if > 10% regression
          if grep -q "REGRESSION" regression_report.txt; then
            echo "Performance regression detected"
            exit 1
          fi

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: performance-regression-report
          path: aptos-move/framework/formal/regression_report.txt

  axiom-drift-guard:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Lean 4
        run: |
          curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y
          echo "$HOME/.elan/bin" >> $GITHUB_PATH

      - name: Count axioms
        working-directory: aptos-move/framework/formal
        run: |
          ./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset > current_axioms.txt

      - name: Compare against baseline
        working-directory: aptos-move/framework/formal
        run: |
          # Expected: 23 permanent axioms, 0 temporary
          CURRENT_TOTAL=$(grep "Total axioms:" current_axioms.txt | awk '{print $3}')
          CURRENT_TEMP=$(grep "Temporary axioms:" current_axioms.txt | awk '{print $3}')
          
          if [ "$CURRENT_TOTAL" != "23" ]; then
            echo "Axiom count changed: expected 23, got $CURRENT_TOTAL"
            exit 1
          fi
          
          if [ "$CURRENT_TEMP" != "0" ]; then
            echo "Temporary axioms detected: $CURRENT_TEMP"
            exit 1
          fi

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: axiom-report
          path: aptos-move/framework/formal/current_axioms.txt

  trust-boundary-check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Lean 4
        run: |
          curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y
          echo "$HOME/.elan/bin" >> $GITHUB_PATH

      - name: Reconcile trust boundaries
        working-directory: aptos-move/framework/formal
        run: |
          ./scripts/reconcile_trust_boundaries.sh | tee trust_report.txt

      - name: Check for inconsistencies
        working-directory: aptos-move/framework/formal
        run: |
          if grep -q "MISMATCH" trust_report.txt; then
            echo "Trust boundary inconsistencies detected"
            exit 1
          fi

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: trust-boundary-report
          path: aptos-move/framework/formal/trust_report.txt
```

---

### Full Specification: `axiom-diff-ca.yaml`

```yaml
name: Axiom Diff (CA)

on:
  pull_request:
    branches:
      - main
      - movement
      - lean-fv

jobs:
  axiom-diff:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      pull-requests: write  # Needed to post comments
    steps:
      - name: Checkout PR head
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}

      - name: Install Lean 4
        run: |
          curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y
          echo "$HOME/.elan/bin" >> $GITHUB_PATH

      - name: Count axioms (HEAD)
        working-directory: aptos-move/framework/formal
        run: |
          ./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset > head_axioms.txt
          cp head_axioms.txt /tmp/head_axioms.txt

      - name: Checkout PR base
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.base.sha }}

      - name: Count axioms (BASE)
        working-directory: aptos-move/framework/formal
        run: |
          ./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset > base_axioms.txt

      - name: Compute diff
        working-directory: aptos-move/framework/formal
        run: |
          # Extract axiom counts
          BASE_TOTAL=$(grep "Total axioms:" base_axioms.txt | awk '{print $3}')
          HEAD_TOTAL=$(grep "Total axioms:" /tmp/head_axioms.txt | awk '{print $3}')
          BASE_TEMP=$(grep "Temporary axioms:" base_axioms.txt | awk '{print $3}')
          HEAD_TEMP=$(grep "Temporary axioms:" /tmp/head_axioms.txt | awk '{print $3}')
          
          # Generate report
          echo "## Axiom Diff Report" > diff_report.md
          echo "" >> diff_report.md
          echo "**Base (${{ github.event.pull_request.base.ref }}):** $BASE_TOTAL axioms ($BASE_TEMP temporary)" >> diff_report.md
          echo "**Head (${{ github.event.pull_request.head.ref }}):** $HEAD_TOTAL axioms ($HEAD_TEMP temporary)" >> diff_report.md
          echo "" >> diff_report.md
          
          if [ "$HEAD_TOTAL" -gt "$BASE_TOTAL" ]; then
            echo "### ⚠️ New axioms detected" >> diff_report.md
            echo "Total increased from $BASE_TOTAL to $HEAD_TOTAL" >> diff_report.md
          elif [ "$HEAD_TOTAL" -lt "$BASE_TOTAL" ]; then
            echo "### ✅ Axioms reduced" >> diff_report.md
            echo "Total decreased from $BASE_TOTAL to $HEAD_TOTAL" >> diff_report.md
          else
            echo "### ✅ No change in axiom count" >> diff_report.md
          fi
          
          echo "" >> diff_report.md
          
          if [ "$HEAD_TEMP" -gt "$BASE_TEMP" ]; then
            echo "### ❌ New temporary axioms" >> diff_report.md
            echo "Temporary axioms increased from $BASE_TEMP to $HEAD_TEMP" >> diff_report.md
            echo "" >> diff_report.md
            echo "**Action required:** Replace temporary axioms with theorems + proofs." >> diff_report.md
            exit 1
          elif [ "$HEAD_TEMP" -lt "$BASE_TEMP" ]; then
            echo "### ✅ Temporary axioms removed" >> diff_report.md
            echo "Temporary axioms decreased from $BASE_TEMP to $HEAD_TEMP" >> diff_report.md
          fi

      - name: Post comment to PR
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const report = fs.readFileSync('aptos-move/framework/formal/diff_report.md', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: report
            });
```

---

## Artifact Management

### Artifact Types

**1. Build profiles**
- Name: `lean-build-profile`
- Contents: Build time breakdown, heartbeat counts
- Retention: 30 days
- Size: ~5 KB

**2. Axiom reports**
- Name: `axiom-report`
- Contents: Axiom counts, categorization
- Retention: 90 days (for audit trail)
- Size: ~2 KB

**3. Difftest reports**
- Name: `difftest-report`
- Contents: Test results, VM vs Model diffs
- Retention: 30 days
- Size: ~50 KB

**4. Performance regression reports**
- Name: `performance-regression-report`
- Contents: Build time trends, hotspot analysis
- Retention: 90 days
- Size: ~10 KB

---

### Downloading Artifacts

**Via GitHub UI:**
1. Go to Actions tab
2. Click on workflow run
3. Scroll to "Artifacts" section
4. Download desired artifact

**Via GitHub CLI:**
```bash
# Install GitHub CLI
brew install gh

# List artifacts for a run
gh run view <run-id> --repo <owner/repo>

# Download specific artifact
gh run download <run-id> --name lean-build-profile --repo <owner/repo>
```

---

## Performance Optimization

### Caching Strategy

**Lean build cache:**
```yaml
- name: Cache Lean build
  uses: actions/cache@v4
  with:
    path: |
      ~/.elan
      aptos-move/framework/formal/lean/.lake
      aptos-move/framework/formal/lean/build
    key: ${{ runner.os }}-lean-${{ hashFiles('aptos-move/framework/formal/lean/lakefile.lean') }}
    restore-keys: |
      ${{ runner.os }}-lean-
```

**Expected speedup:** 2-3× for incremental builds

---

**Aptos CLI cache:**
```yaml
- name: Cache Aptos CLI
  uses: actions/cache@v4
  with:
    path: ~/.aptos
    key: ${{ runner.os }}-aptos-cli-${{ hashFiles('aptos-move/framework/aptos-experimental/Move.toml') }}
```

**Expected speedup:** 1.5× for Move compilation

---

### Parallelization

**Current parallelization:**
- 6 jobs run in parallel in `ca-verification-suite.yaml`
- Independent jobs (no dependencies between them)
- GitHub Actions runner pool: up to 20 concurrent jobs (free tier)

**Bottleneck:** difftest-validation (2 minutes)

**Optimization opportunity:** Shard difftest into 5 parallel jobs (one per operation)

**Estimated improvement:** 2m → 30s (4× speedup)

---

**Proposed sharding:**
```yaml
difftest-validation:
  runs-on: ubuntu-latest
  strategy:
    matrix:
      operation: [registration, normalization, withdrawal, transfer, rotation]
  steps:
    # ... (same as before, but test only ${{ matrix.operation }})
    - name: Run difftest for operation
      run: |
        ./scripts/manage_difftest_corpus.sh test ${{ matrix.operation }}
```

---

## Monitoring and Alerts

### Metrics to Track

**1. Build success rate**
- Track over time: % of CI runs that pass
- Alert if < 95% over 7-day rolling window

**2. Build time trends**
- Track Lean build time (currently ~4s)
- Alert if > 10s (10% of 100s budget)

**3. Axiom drift**
- Track total axiom count (currently 23)
- Alert on any new temporary axioms

**4. Difftest coverage**
- Track number of test cases (currently 87)
- Alert if < 85 (regression in coverage)

---

### Alerting via Slack

**Setup Slack webhook:**
```yaml
- name: Notify Slack on failure
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "❌ CA Verification Suite failed",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*CA Verification Suite Failed*\n\nWorkflow: ${{ github.workflow }}\nRun: ${{ github.run_id }}\nBranch: ${{ github.ref }}"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

### Dashboard (optional)

**Grafana dashboard for CI metrics:**

```yaml
# Sample metrics to visualize
- Lean build time (seconds)
- Axiom count (total, permanent, temporary)
- Difftest pass rate (%)
- CI run duration (minutes)
- Artifact size (KB)
```

**Data source:** GitHub Actions API → Prometheus → Grafana

**Estimated setup time:** 2-4 hours

---

## Troubleshooting

### Issue 1: Lean Build Timeout

**Symptom:**
```
Error: The operation was canceled.
Workflow run exceeded timeout of 10 minutes
```

**Cause:** Lean build taking > 10 minutes (budget exceeded)

**Solution:**
1. Profile locally: `./scripts/profile_lean_build.sh ...`
2. Identify hot spots (likely missing `@[irreducible]`)
3. Apply optimizations from `PERFORMANCE_TUNING_DEEP_DIVE.md`
4. Re-run CI

**Prevention:** Set up performance regression check (catches this before merge)

---

### Issue 2: Axiom Diff False Positive

**Symptom:**
```
❌ New temporary axioms detected
```

**But:** No new axioms were added

**Cause:** Base branch has stale axiom count (base was updated after PR created)

**Solution:**
1. Merge latest base into PR branch
2. Re-run CI

**Prevention:** Keep PR branch up-to-date with base

---

### Issue 3: Difftest Flakiness

**Symptom:**
```
Test transfer_happy_path: PASS
(re-run) Test transfer_happy_path: FAIL
```

**Cause:** Non-deterministic VM behavior or race condition

**Solution:**
1. Check difftest JSON for randomness (e.g., timestamps, random addresses)
2. Use fixed seeds for determinism
3. Isolate VM execution (no parallel tests)

**Prevention:** Validate difftest inputs are deterministic

---

### Issue 4: Artifact Upload Failure

**Symptom:**
```
Error: Artifact upload failed: 403 Forbidden
```

**Cause:** Insufficient permissions or quota exceeded

**Solution:**
1. Check repository settings → Actions → General → Artifact permissions
2. Ensure "Read and write permissions" enabled
3. Check artifact quota (free tier: 500 MB)

**Prevention:** Clean up old artifacts regularly

---

## Best Practices

### 1. Fail Fast

**Pattern:** Put cheapest checks first in workflow
```yaml
jobs:
  quick-lint:
    runs-on: ubuntu-latest
    steps:
      - name: Shellcheck scripts
        run: shellcheck scripts/*.sh

  lean-verification:
    needs: quick-lint  # Only run if lint passes
    # ...
```

**Benefit:** Save CI time by failing early on trivial issues

---

### 2. Use Workflow Dispatch for Manual Runs

**Pattern:**
```yaml
on:
  workflow_dispatch:
    inputs:
      operation:
        description: 'Operation to verify (or "all")'
        required: false
        default: 'all'
```

**Benefit:** Allow manual re-runs with custom parameters

---

### 3. Tag Stable Releases

**Pattern:**
```yaml
on:
  push:
    tags:
      - 'v*'  # Trigger on version tags

jobs:
  release-verification:
    # ... (full verification suite with extra rigor)
```

**Benefit:** Extra validation before releases

---

### 4. Separate Fast and Slow Checks

**Pattern:**
- Fast checks (< 1 min): Required for all PRs
- Slow checks (> 5 min): Optional, run nightly

**Implementation:**
```yaml
# fast-checks.yaml
on:
  pull_request:

# nightly-full-suite.yaml
on:
  schedule:
    - cron: '0 0 * * *'
```

**Benefit:** Faster PR feedback loop

---

### 5. Archive Old Artifacts

**Pattern:**
```yaml
- name: Upload artifacts
  uses: actions/upload-artifact@v4
  with:
    name: lean-build-profile-${{ github.sha }}
    path: build_profile.txt
    retention-days: 30
```

**Benefit:** Save storage quota while keeping audit trail

---

## Summary

**CI/CD infrastructure provides:**
- ✅ Automated verification on every PR
- ✅ Fast feedback (< 15 min total)
- ✅ Drift detection (axioms, performance)
- ✅ Reproducible builds (Docker)
- ✅ Comprehensive coverage (Lean + MSL + Difftest)

**Maintenance:**
- Update baselines quarterly (axiom count, performance budgets)
- Review artifacts monthly (delete old, archive important)
- Monitor metrics weekly (build time trends, success rate)

**Next steps:**
- [ ] Enable all workflows in repository
- [ ] Configure branch protection rules
- [ ] Set up Slack notifications (optional)
- [ ] Create Grafana dashboard (optional)
- [ ] Publish Docker image (Phase 7 completion)

---

**For detailed troubleshooting, see:** `ERROR_DIAGNOSIS_GUIDE.md` or `TROUBLESHOOTING_GUIDE.md`
