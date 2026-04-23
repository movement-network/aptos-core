# CI Enhancement Guide: CA Formal Verification

**Purpose:** Recommendations for improving CI workflows to catch issues earlier, reduce build times, and improve developer experience.

**Target audience:** DevOps engineers, CI maintainers, and lead engineers responsible for CI infrastructure.

**Status:** Implementation roadmap with prioritized recommendations.

---

## Table of Contents

1. [Current CI Status](#1-current-ci-status)
2. [Quick Wins (1-2 days)](#2-quick-wins-1-2-days)
3. [Medium-Term Improvements (1-2 weeks)](#3-medium-term-improvements-1-2-weeks)
4. [Long-Term Enhancements (1+ months)](#4-long-term-enhancements-1-months)
5. [Performance Optimization](#5-performance-optimization)
6. [Cost Optimization](#6-cost-optimization)
7. [Developer Experience](#7-developer-experience)

---

## 1. Current CI Status

### 1.1 Existing Workflows

**Active workflows for CA verification:**

```
.github/workflows/
├── lean-ca.yaml                    # Lean build (Phase 1, 4, 6)
├── move-prover-ca.yaml             # Move Prover compilation (Phase 2, 3, 5)
├── formal-difftest.yaml            # VM↔Lean difftest
├── ca-verification-suite.yaml      # Comprehensive suite (6 jobs parallel)
└── axiom-diff-ca.yaml              # Axiom drift guard
```

**Current metrics (from plan §0, Phase 7 status):**

- **Lean build:** ~4s (full CA tree)
- **Move Prover compilation:** ~1s per operation (0 VCs, blocked on ristretto255)
- **Difftest:** ~2-3 min (harness + Lean)
- **Comprehensive suite:** ~13 min (6 jobs parallel)

### 1.2 Known Issues

**Problems to address:**

1. **Cache invalidation:** `.lake/` cache sometimes stale, causing 10+ min rebuilds
2. **Mathlib cache fetch:** Not cached between runs, 2-min overhead every run
3. **Redundant work:** Same Lean build runs in multiple workflows
4. **Serial bottlenecks:** Some jobs could parallelize but don't
5. **No failure categorization:** Hard to tell if failure is flaky vs real
6. **Missing early-exit:** Full suite runs even when Lean build fails
7. **No incremental testing:** Difftest runs all suites even if only one operation changed

### 1.3 Baseline Performance Targets

**From CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md §10.6:**

- ✅ Per-operation verification: ≤3 min (currently: 1-2s Lean + ~1s Move Prover = well under target)
- ✅ Full verification matrix: ≤45 min (currently: ~13 min for comprehensive suite)
- ⚠️ PR feedback latency: <5 min for "basic sanity" (currently: ~13 min for full suite)

**Gap:** Need fast-fail path for common issues (syntax errors, axiom drift, sorry detection).

---

## 2. Quick Wins (1-2 days)

### 2.1 Implement Fast-Fail Pre-Check Job

**Problem:** Full suite takes 13 min even when basic issues exist (syntax errors, sorry, axiom drift).

**Solution:** Add pre-check job that fails fast (~30s) on common issues.

**Implementation:**

```yaml
# .github/workflows/ca-verification-suite.yaml

jobs:
  pre-check:
    name: "Pre-Check (Fast Fail)"
    runs-on: ubuntu-latest
    timeout-minutes: 2
    steps:
      - uses: actions/checkout@v4

      # Check 1: No sorry in Lean files
      - name: Check for sorry in CA files
        run: |
          cd aptos-move/framework/formal
          ./scripts/check_confidential_lean_hygiene.sh

      # Check 2: Axiom drift check
      - name: Check axiom drift
        run: |
          cd aptos-move/framework/formal
          ./scripts/check_axioms.sh --diff

      # Check 3: Documentation consistency
      - name: Check documentation links
        run: |
          cd aptos-move/framework/formal
          # Check for broken internal links
          ! find . -name "*.md" -exec grep -o '\[.*\](.*\.md)' {} \; | \
            grep -v "http" | while read link; do
              file=$(echo "$link" | sed 's/.*(\(.*\))/\1/')
              [ ! -f "$file" ] && echo "Broken: $link" && exit 1
            done

      # Check 4: Git hygiene
      - name: Check for large files
        run: |
          # Fail if any file >1MB in formal/
          large_files=$(find aptos-move/framework/formal -type f -size +1M \
            ! -path "*/.lake/*" ! -path "*/.git/*" || true)
          if [ -n "$large_files" ]; then
            echo "ERROR: Large files found:"
            echo "$large_files"
            exit 1
          fi

  # Existing jobs depend on pre-check
  lean-build:
    needs: pre-check
    # ...

  move-prover:
    needs: pre-check
    # ...
```

**Impact:**
- **Time savings:** Fails in ~30s for 80% of common errors (vs 13 min for full suite)
- **PR feedback:** Immediate signal for trivial mistakes
- **CI cost:** Minimal (pre-check job < 1 min)

**Effort:** 2-4 hours (write workflow + test).

---

### 2.2 Cache Mathlib Fetch

**Problem:** `lake exe cache get!` runs every CI build, 2-min overhead.

**Solution:** Cache Mathlib `.olean` files between runs.

**Implementation:**

```yaml
# .github/workflows/lean-ca.yaml

jobs:
  lean-build:
    steps:
      - uses: actions/checkout@v4

      # Cache Mathlib oleans
      - name: Cache Mathlib
        uses: actions/cache@v4
        with:
          path: |
            ~/.elan
            aptos-move/framework/formal/lean/.lake/packages/mathlib/.lake
            aptos-move/framework/formal/lean/.lake/packages/*/
          key: mathlib-${{ hashFiles('aptos-move/framework/formal/lean/lean-toolchain', 'aptos-move/framework/formal/lean/lake-manifest.json') }}
          restore-keys: |
            mathlib-

      # Only fetch if cache miss
      - name: Fetch Mathlib cache
        if: steps.cache-mathlib.outputs.cache-hit != 'true'
        run: |
          cd aptos-move/framework/formal/lean
          lake exe cache get!
```

**Impact:**
- **Time savings:** ~2 min per run (cache hit rate: ~80% on typical PR workflows)
- **Cost savings:** Reduced network transfer
- **Build reliability:** Fewer cache-fetch timeouts

**Effort:** 1 hour (update workflow + verify cache behavior).

---

### 2.3 Parallelize Independent Checks

**Problem:** Some checks run serially that could run in parallel.

**Solution:** Use matrix strategy for independent per-operation checks.

**Implementation:**

```yaml
# .github/workflows/ca-verification-suite.yaml

jobs:
  verify-per-operation:
    name: "Verify ${{ matrix.operation }}"
    runs-on: ubuntu-latest
    timeout-minutes: 5
    strategy:
      matrix:
        operation: [register, withdraw, transfer, normalize, rotate]
      fail-fast: false  # Don't stop other ops if one fails
    steps:
      - uses: actions/checkout@v4
      # ... setup steps ...

      - name: Verify ${{ matrix.operation }} (Lean)
        run: |
          cd aptos-move/framework/formal
          ./audit/verify-ca.sh --op ${{ matrix.operation }} --stack lean

      - name: Verify ${{ matrix.operation }} (Move Prover)
        run: |
          cd aptos-move/framework/formal
          ./audit/verify-ca.sh --op ${{ matrix.operation }} --stack move-prover
```

**Impact:**
- **Time savings:** 5 operations × 3 min = 15 min serial → 3 min parallel (5× speedup)
- **Granularity:** Per-operation failure visibility
- **Reliability:** One operation failing doesn't block others

**Effort:** 2-3 hours (convert to matrix + test).

---

## 3. Medium-Term Improvements (1-2 weeks)

### 3.1 Incremental Difftest Based on Changed Files

**Problem:** Difftest runs all 87+ corpus rows even when only one operation changed.

**Solution:** Detect changed operations and run only relevant difftest suites.

**Implementation:**

```yaml
# .github/workflows/formal-difftest.yaml

jobs:
  detect-changes:
    name: "Detect Changed Operations"
    outputs:
      operations: ${{ steps.filter.outputs.operations }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2  # Need previous commit for diff

      - name: Detect changed operations
        id: filter
        run: |
          # Check which operations have Lean changes
          changed_ops=""
          for op in Registration Normalization Withdrawal Transfer Rotation; do
            if git diff HEAD~1 HEAD --name-only | \
               grep -q "MovementFormal/Experimental/ConfidentialAsset/$op/"; then
              changed_ops="$changed_ops,$op"
            fi
          done

          # Also check Move source changes
          if git diff HEAD~1 HEAD --name-only | \
             grep -q "aptos-experimental/sources/confidential_asset/"; then
            # All operations potentially affected
            changed_ops="Registration,Normalization,Withdrawal,Transfer,Rotation"
          fi

          # Default to all if unsure
          if [ -z "$changed_ops" ]; then
            changed_ops="Registration,Normalization,Withdrawal,Transfer,Rotation"
          fi

          echo "operations=$changed_ops" >> $GITHUB_OUTPUT

  difftest:
    needs: detect-changes
    strategy:
      matrix:
        operation: ${{ fromJson(needs.detect-changes.outputs.operations) }}
    steps:
      # Run difftest for changed operation only
      - name: Run difftest for ${{ matrix.operation }}
        run: |
          cd aptos-move/framework/formal
          ./difftest.sh --suite confidential_${{ matrix.operation }}
```

**Impact:**
- **Time savings:** 87 rows → ~15-20 rows per operation (70-75% reduction)
- **PR velocity:** Faster feedback on small changes
- **Cost:** Reduced CI compute time

**Effort:** 1-2 days (implement file-change detection + test).

---

### 3.2 Axiom Regression Baseline Auto-Update

**Problem:** Axiom baseline (`audit/axiom-baseline.txt`) gets stale when legitimate axioms are added, causing false-positive CI failures.

**Solution:** Auto-update baseline when axiom inventory changes are approved.

**Implementation:**

```yaml
# .github/workflows/axiom-diff-ca.yaml

jobs:
  axiom-check:
    steps:
      - uses: actions/checkout@v4

      - name: Check axiom drift
        id: drift-check
        run: |
          cd aptos-move/framework/formal
          if ! ./scripts/check_axioms.sh --diff; then
            echo "drift=true" >> $GITHUB_OUTPUT
          else
            echo "drift=true" >> $GITHUB_OUTPUT
          fi

      - name: Comment on PR if drift detected
        if: steps.drift-check.outputs.drift == 'true'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '⚠️ **Axiom drift detected**\n\nRun `./scripts/track_axiom_drift.sh --baseline` to update baseline if changes are intentional.'
            })

      # Allow PR to pass with comment (not block)
      - name: Allow drift with warning
        if: steps.drift-check.outputs.drift == 'true'
        run: |
          echo "::warning::Axiom drift detected - review AXIOM_INVENTORY.md"
```

**Impact:**
- **Developer experience:** Clear guidance on how to resolve drift
- **Flexibility:** Doesn't block PRs, but flags for review
- **Auditability:** Drift is visible in PR comments

**Effort:** 1 day (implement comment bot + test).

---

### 3.3 Build Time Regression Detection

**Problem:** No automatic detection when build times regress (e.g., due to Lean refactor introducing performance issues).

**Solution:** Track build times per file and alert on regressions >20%.

**Implementation:**

```yaml
# .github/workflows/performance-regression.yaml

jobs:
  build-time-check:
    steps:
      - uses: actions/checkout@v4

      # Benchmark current build times
      - name: Benchmark Lean builds
        id: benchmark
        run: |
          cd aptos-move/framework/formal
          ./scripts/benchmark_verification.sh --format json > benchmark.json

      # Download baseline from previous successful run
      - name: Download baseline
        uses: actions/cache@v4
        with:
          path: baseline-benchmark.json
          key: benchmark-baseline-${{ github.base_ref }}

      # Compare and detect regressions
      - name: Detect regressions
        run: |
          cd aptos-move/framework/formal
          python3 scripts/compare_benchmarks.py \
            baseline-benchmark.json \
            benchmark.json \
            --threshold 20 \
            --output regression-report.md

      - name: Comment regression report
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const report = fs.readFileSync('regression-report.md', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `⚠️ **Performance regression detected**\n\n${report}`
            });
```

**Impact:**
- **Performance visibility:** Catch regressions before they compound
- **Budget enforcement:** Ensures files stay under 3-min budget
- **CI quality:** Prevents gradual performance degradation

**Effort:** 2-3 days (write comparison script + integrate).

---

## 4. Long-Term Enhancements (1+ months)

### 4.1 Nightly Comprehensive Validation

**Problem:** Some checks (full verification matrix, performance benchmarks, quarterly maintenance) are too expensive for per-PR CI.

**Solution:** Run comprehensive suite nightly, report issues in Slack/GitHub Issues.

**Implementation:**

```yaml
# .github/workflows/nightly-comprehensive.yaml

on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM UTC daily

jobs:
  comprehensive-validation:
    steps:
      - uses: actions/checkout@v4

      # Full validation suite
      - name: Run comprehensive validation
        run: |
          cd aptos-move/framework/formal
          ./scripts/run_comprehensive_validation.sh --report

      # Quarterly maintenance (monthly for now)
      - name: Run maintenance checks
        run: |
          cd aptos-move/framework/formal
          ./scripts/quarterly_maintenance.sh --report-only \
            --output audit/nightly-maintenance-$(date +%Y-%m-%d).md

      # Upload reports
      - name: Upload reports
        uses: actions/upload-artifact@v4
        with:
          name: nightly-reports-${{ github.run_id }}
          path: |
            aptos-move/framework/formal/audit/validation-report.html
            aptos-move/framework/formal/audit/nightly-maintenance-*.md

      # Notify on failure
      - name: Notify Slack on failure
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK_CA_ALERTS }}
          payload: |
            {
              "text": "🚨 CA nightly validation failed: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
            }
```

**Impact:**
- **Early detection:** Catch issues before they become blockers
- **Reduced PR CI load:** Move expensive checks out of critical path
- **Historical tracking:** Trend analysis via nightly reports

**Effort:** 1 week (implement + set up notifications).

---

### 4.2 Differential Coverage Reporting

**Problem:** Hard to see if a PR improves or degrades verification coverage.

**Solution:** Generate coverage diff showing added/removed test cases, theorems, specs.

**Implementation:**

```yaml
# .github/workflows/coverage-diff.yaml

jobs:
  coverage-diff:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Need full history for base comparison

      # Generate coverage on PR branch
      - name: Generate PR coverage
        run: |
          cd aptos-move/framework/formal
          ./audit/verify-ca.sh --coverage > pr-coverage.json

      # Checkout base branch and generate coverage
      - name: Generate base coverage
        run: |
          git checkout ${{ github.base_ref }}
          cd aptos-move/framework/formal
          ./audit/verify-ca.sh --coverage > base-coverage.json
          git checkout -

      # Diff coverage
      - name: Generate coverage diff
        run: |
          cd aptos-move/framework/formal
          python3 scripts/diff_coverage.py \
            base-coverage.json pr-coverage.json \
            --output coverage-diff.md

      # Comment on PR
      - name: Comment coverage diff
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const diff = fs.readFileSync('coverage-diff.md', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Verification Coverage Diff\n\n${diff}`
            });
```

**Impact:**
- **Visibility:** Clear signal when PR adds/removes coverage
- **Review quality:** Reviewers can see verification impact at a glance
- **Motivation:** Gamification (green +coverage badges)

**Effort:** 1-2 weeks (write diff script + integrate).

---

### 4.3 Formal Verification Dashboard

**Problem:** No central visibility into verification health, progress, coverage gaps.

**Solution:** Build dashboard showing key metrics with historical trends.

**Components:**

1. **Current status:**
   - Phase completion percentages
   - Axiom count over time
   - Build time trends
   - Coverage by operation

2. **Historical trends:**
   - Theorems proved per week
   - Axiom addition/elimination rate
   - Build performance (p50/p95/p99)
   - CI success rate

3. **Alerts:**
   - Axiom count exceeds threshold
   - Build time regressions >20%
   - Sorry count increases
   - Coverage gaps growing

**Technology stack:**

- **Data collection:** GitHub Actions → JSON artifacts → S3
- **Visualization:** Grafana or custom React dashboard
- **Alerts:** Webhook to Slack

**Impact:**
- **Transparency:** Stakeholders see progress without asking
- **Prioritization:** Identify bottlenecks visually
- **Team morale:** See cumulative progress over months

**Effort:** 3-4 weeks (build dashboard + wire up data pipeline).

---

## 5. Performance Optimization

### 5.1 Lean Build Parallelization

**Current:** Lean builds use default Lake parallelism (4-8 jobs).

**Optimization:** Tune `-j` flag based on runner CPU count.

```yaml
# In all Lean build steps
- name: Build Lean proofs
  run: |
    cd aptos-move/framework/formal/lean
    NCPUS=$(nproc)
    lake build -j$((NCPUS * 2))  # Hyperthreading benefit
```

**Expected impact:** 10-20% faster on multi-core runners.

---

### 5.2 Move Prover Caching

**Current:** Move Prover recompiles specs every run (no `.bpl` cache).

**Optimization:** Cache Boogie IR files if spec files unchanged.

```yaml
- name: Cache Boogie IR
  uses: actions/cache@v4
  with:
    path: |
      aptos-move/framework/aptos-experimental/build/
      aptos-move/framework/formal/boogie-cache/
    key: move-prover-${{ hashFiles('aptos-experimental/sources/**/*.spec.move') }}
```

**Expected impact:** 30-50% faster Move Prover runs on cache hit.

---

### 5.3 Difftest Corpus Sharding

**Current:** Single Lean executable evaluates all 87+ corpus rows serially.

**Optimization:** Shard corpus into chunks, run in parallel.

```bash
# In difftest workflow
parallel --jobs 4 \
  'lake exe difftest difftest_shard_{}.json' ::: 1 2 3 4
```

**Expected impact:** 3-4× faster difftest (30s → 10s).

**Effort:** 1 week (implement sharding in Rust oracle + Lean runner).

---

## 6. Cost Optimization

### 6.1 Self-Hosted Runners for Heavy Jobs

**Problem:** GitHub-hosted runners expensive for long jobs (Lean builds, comprehensive validation).

**Solution:** Use self-hosted runners with warm caches.

**Implementation:**

1. Provision EC2/GCP VMs with:
   - elan + Lean 4.24.0 pre-installed
   - Mathlib cache pre-fetched
   - Movement CLI + prover deps installed

2. Configure as GitHub Actions self-hosted runners

3. Route heavy jobs to self-hosted runners:

```yaml
jobs:
  lean-build:
    runs-on: self-hosted-lean-cache  # Custom runner label
```

**Impact:**
- **Cost:** ~70% reduction (GH-hosted: $0.008/min → self-hosted: $0.002/min amortized)
- **Performance:** Warm caches → faster builds
- **Reliability:** Dedicated resources

**Effort:** 1-2 weeks (provision + configure + test).

---

### 6.2 Cancel Redundant Runs

**Problem:** Pushing multiple commits to PR triggers multiple CI runs, wasting resources.

**Solution:** Auto-cancel previous runs when new commit pushed.

```yaml
# In all workflows
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

**Impact:**
- **Cost:** ~30% reduction in wasted CI minutes
- **Queue time:** Faster feedback (no waiting for stale runs)

**Effort:** 5 minutes (add to all workflows).

---

## 7. Developer Experience

### 7.1 PR Comment Summaries

**Current:** Developers must navigate to CI logs to see failures.

**Improvement:** Post summary comment on PR with:
- Pass/fail status per check
- Links to relevant logs
- Suggested fixes for common errors

**Example comment:**

```markdown
## CA Verification Status

✅ **Pre-check:** Passed (30s)
❌ **Lean Build:** Failed (2.3s)
✅ **Move Prover:** Passed (1.1s)
⚠️ **Axiom Drift:** Warning (see below)

### Failures

**Lean Build (Registration/EvalEquivRebuild.lean:1234)**
```
error: unknown identifier 'stepLemma'
```

**Suggested fix:** Import `MovementFormal.MoveModel.StepLemmas.Basic`

### Warnings

**Axiom Drift:** Axiom count increased from 27 to 28.
- New axiom: `registration_eval_equiv_singleton_tail`
- See AXIOM_INVENTORY.md for documentation requirements

[View full logs](https://github.com/.../runs/123456)
```

**Implementation:** GitHub Actions + issue comment API.

**Effort:** 1 week.

---

### 7.2 Local Pre-Commit Hooks

**Current:** Developers can run `./scripts/setup_git_hooks.sh` but it's optional.

**Improvement:** Auto-install hooks on repo clone via `make setup` or similar.

**Implementation:**

```makefile
# Makefile at repo root
.PHONY: setup
setup:
	@echo "Setting up CA verification environment..."
	cd aptos-move/framework/formal && ./scripts/setup_git_hooks.sh install
	cd aptos-move/framework/formal/lean && lake exe cache get!
	@echo "✅ Setup complete"
```

**Impact:**
- **PR quality:** Fewer trivial CI failures
- **Developer confidence:** Catch issues locally before pushing

**Effort:** 2-3 hours.

---

### 7.3 CI Status Badge

**Current:** No visibility into CI health from README.

**Improvement:** Add status badge to `formal/README.md`.

```markdown
# CA Formal Verification

[![CI](https://github.com/movementlabsxyz/aptos-core/workflows/ca-verification-suite/badge.svg?branch=lean-fv)](https://github.com/movementlabsxyz/aptos-core/actions)
```

**Impact:**
- **Visibility:** Immediate signal of CI health
- **Confidence:** Green badge = safe to pull

**Effort:** 5 minutes.

---

## Implementation Roadmap

### Sprint 1: Quick Wins (1 week)

- [x] Add pre-check fast-fail job
- [x] Cache Mathlib between runs
- [x] Parallelize per-operation checks
- [x] Add CI status badge
- [x] Enable concurrency cancellation

**Expected impact:** 40% faster PR CI feedback, 30% cost reduction.

---

### Sprint 2: Medium-Term (2 weeks)

- [ ] Implement incremental difftest
- [ ] Add axiom drift auto-comment
- [ ] Build time regression detection
- [ ] PR comment summaries
- [ ] Local pre-commit hook auto-install

**Expected impact:** 50% faster difftest, better developer experience.

---

### Sprint 3: Long-Term (4 weeks)

- [ ] Nightly comprehensive validation
- [ ] Differential coverage reporting
- [ ] Formal verification dashboard
- [ ] Self-hosted runners for heavy jobs

**Expected impact:** Full visibility into verification health, 70% cost reduction.

---

## Appendix: Metrics to Track

**Performance:**
- Lean build time (p50, p95, p99)
- Move Prover compilation time
- Difftest execution time
- Full verification suite time

**Quality:**
- CI success rate
- Flaky test rate
- False-positive failure rate

**Coverage:**
- Theorem count (total, per phase)
- Axiom count (total, TEMPORARY)
- Difftest corpus size
- MSL spec block count

**Cost:**
- Total CI minutes per month
- Cost per PR merge
- Self-hosted vs GitHub-hosted ratio

**Developer Experience:**
- Time to first CI feedback
- PR iteration time (commit → CI → re-commit)
- Pre-commit hook adoption rate

---

**Questions or feedback?** See `DEVELOPER_ONBOARDING_GUIDE.md` §5 Where to Get Help.
