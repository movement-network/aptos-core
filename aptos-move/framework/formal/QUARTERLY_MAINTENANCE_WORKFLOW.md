# Quarterly Maintenance Workflow — CA Formal Verification

**Purpose:** Comprehensive quarterly maintenance checklist for sustaining CA formal verification infrastructure  
**Frequency:** Every 3 months (Q1: Jan, Q2: Apr, Q3: Jul, Q4: Oct)  
**Time Required:** 4-8 hours per quarter  
**Owner:** Verification team lead

---

## Executive Summary

The CA formal verification infrastructure requires quarterly maintenance to:
- **Review and update axiom inventory** (23 permanent crypto axioms)
- **Audit performance baselines** (ensure builds stay under budget)
- **Update dependency versions** (Lean 4, Aptos CLI, Move Prover)
- **Refresh documentation** (sync with code changes)
- **Validate reproducibility** (Docker image, CI workflows)
- **Health check difftest corpus** (87 test cases)
- **Reconcile trust boundaries** (documentation vs implementation)

**Last completed:** [DATE - UPDATE QUARTERLY]  
**Next scheduled:** [DATE + 3 MONTHS]  
**Status:** ✅ / 🟡 / ❌

---

## Table of Contents

1. [Pre-Maintenance Checklist](#pre-maintenance-checklist)
2. [Task 1: Axiom Review and Audit](#task-1-axiom-review-and-audit)
3. [Task 2: Performance Baseline Update](#task-2-performance-baseline-update)
4. [Task 3: Dependency Updates](#task-3-dependency-updates)
5. [Task 4: Documentation Refresh](#task-4-documentation-refresh)
6. [Task 5: Difftest Corpus Health Check](#task-5-difftest-corpus-health-check)
7. [Task 6: CI/CD Workflow Validation](#task-6-cicd-workflow-validation)
8. [Task 7: Trust Boundary Reconciliation](#task-7-trust-boundary-reconciliation)
9. [Task 8: Reproducibility Validation](#task-8-reproducibility-validation)
10. [Post-Maintenance Checklist](#post-maintenance-checklist)
11. [Quarterly Report Template](#quarterly-report-template)

---

## Pre-Maintenance Checklist

**Before starting quarterly maintenance, ensure:**

- [ ] All pending PRs merged or documented for next quarter
- [ ] CI/CD workflows passing on main branch
- [ ] No critical blockers (e.g., ristretto255 patches still pending)
- [ ] Backup of current state (git tag: `pre-maintenance-Q[N]-YYYY`)
- [ ] Stakeholders notified (maintenance window: [START] to [END])
- [ ] Maintenance branch created: `maintenance/YYYY-Q[N]`

**Commands:**
```bash
# Create maintenance tag and branch
git tag -a "pre-maintenance-Q1-2026" -m "Pre-maintenance snapshot Q1 2026"
git checkout -b maintenance/2026-Q1

# Verify CI status
gh workflow list --repo movement-labs/aptos-core
gh run list --branch main --limit 10

# Document pending PRs
gh pr list --state open --label "formal-verification" > pending_prs_Q1_2026.txt
```

---

## Task 1: Axiom Review and Audit

**Goal:** Review all 23 permanent crypto axioms, assess reduction opportunities

**Time:** 90-120 minutes

**Steps:**

### Step 1.1: Count Current Axioms

```bash
cd aptos-move/framework/formal

# Generate axiom report
./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset > current_axiom_report.txt

# Expected output:
# Total axioms: 23
# Temporary axioms: 0
# Permanent axioms: 23
#   - Group theory: 12
#   - Ristretto encoding: 4
#   - Bulletproofs: 5
#   - CA-specific: 2
```

**Acceptance criteria:**
- ✅ Total axioms = 23 (no drift)
- ✅ Temporary axioms = 0
- ❌ If total > 23 OR temp > 0: investigate and remediate

---

### Step 1.2: Cross-Reference with AXIOM_INVENTORY.md

```bash
# Compare implementation vs documentation
./scripts/reconcile_trust_boundaries.sh | grep "MISMATCH"

# Should output nothing (no mismatches)
```

**If mismatches found:**
1. Identify new axioms: `diff AXIOM_INVENTORY.md current_axiom_report.txt`
2. For each new axiom:
   - Categorize (group theory, ristretto, bulletproofs, CA-specific)
   - Document justification
   - Add to AXIOM_INVENTORY.md
   - Update TRUST_BOUNDARIES.md

---

### Step 1.3: Assess Reduction Opportunities

**Review each axiom category:**

**Group theory axioms (12):**
- Can any be proven from existing Mathlib lemmas?
- Check Mathlib4 changelog for new theorems
- Command: `grep "Edwards" mathlib4-changelog.md`

**Ristretto encoding axioms (4):**
- Can compression/decompression be proven?
- Check if Lean Ristretto library published
- Command: `search-lean-packages "ristretto"`

**Bulletproofs axioms (5):**
- Decision: axiomatize permanently OR implement?
- Revisit decision framework (AXIOM_REVIEW_AND_REDUCTION_STRATEGY.md §4)
- Update status: still axiomatized, implementation started, or implemented

**CA-specific axioms (2):**
- Can Schnorr soundness be proven from crypto primitives?
- Can HMAC soundness be proven from hash function properties?

**Document findings:**
```markdown
# Q[N] YYYY Axiom Review

## Summary
- Total axioms: 23 (unchanged from Q[N-1])
- Reduction opportunities: [COUNT]
- Planned reductions for Q[N+1]: [LIST]

## Details
[For each category: status, opportunities, blockers]
```

---

## Task 2: Performance Baseline Update

**Goal:** Update performance baselines, detect regressions, validate budget margins

**Time:** 60-90 minutes

---

### Step 2.1: Profile Current Build Times

```bash
cd aptos-move/framework/formal

# Profile all operations
for op in Registration Normalization Withdrawal Transfer Rotation; do
  ./scripts/profile_lean_build.sh MovementFormal.Experimental.ConfidentialAsset.$op | tee profile_${op}.txt
done

# Aggregate results
./scripts/collect_all_metrics.sh > quarterly_metrics_Q[N]_YYYY.json
```

**Expected results (from current baselines):**
| Operation | Current Budget | Baseline | Margin |
|-----------|----------------|----------|--------|
| Registration | 180s | 3.0s | 60× |
| Normalization | 180s | 0.5s | 360× |
| Withdrawal | 180s | 0.5s | 360× |
| Transfer | 180s | 0.7s | 257× |
| Rotation | 180s | 0.5s | 360× |
| **Full tree** | **600s** | **~4s** | **150×** |

---

### Step 2.2: Compare Against Previous Quarter

```bash
# Compare current vs Q[N-1]
diff quarterly_metrics_Q[N-1]_YYYY.json quarterly_metrics_Q[N]_YYYY.json

# Look for regressions (> 10% increase)
./scripts/detect_performance_regression.sh \
  --baseline quarterly_metrics_Q[N-1]_YYYY.json \
  --current quarterly_metrics_Q[N]_YYYY.json \
  --threshold 10
```

**If regressions detected:**
1. Identify hot spots: `./scripts/analyze_proof_structure.sh <operation>`
2. Check for missing `@[irreducible]` annotations
3. Check for bare `simp` (should be `simp only`)
4. Review recent commits for performance-impacting changes

**Remediation:**
- Apply optimizations from PERFORMANCE_TUNING_DEEP_DIVE.md
- Re-profile after fixes
- Document changes in quarterly report

---

### Step 2.3: Update Baseline Files

```bash
# If no regressions, update baselines
cp quarterly_metrics_Q[N]_YYYY.json baseline_metrics.json

# Commit updated baselines
git add baseline_metrics.json
git commit -m "chore: update performance baselines Q[N] YYYY"
```

---

## Task 3: Dependency Updates

**Goal:** Update Lean 4, Aptos CLI, Move Prover to latest stable versions

**Time:** 90-120 minutes

---

### Step 3.1: Check Current Versions

```bash
# Lean version
lean --version
# Expected: leanprover/lean4:v4.X.Y

# Aptos CLI version
aptos --version
# Expected: aptos X.Y.Z

# Lake version (Lean package manager)
lake --version
```

**Document current versions:**
```
Lean: 4.X.Y
Aptos CLI: X.Y.Z
Lake: 4.X.Y
```

---

### Step 3.2: Check for Updates

```bash
# Lean 4 releases
curl -s https://api.github.com/repos/leanprover/lean4/releases/latest | jq '.tag_name'

# Aptos CLI releases
curl -s https://api.github.com/repos/aptos-labs/aptos-core/releases/latest | jq '.tag_name'
```

**Evaluate updates:**
- Major version changes (X.0.0): Careful review, may break API
- Minor version changes (0.X.0): Usually safe, new features
- Patch version changes (0.0.X): Safe, bug fixes

---

### Step 3.3: Update Lean 4 (if available)

```bash
# Update elan (Lean version manager)
elan self update

# Install latest Lean
elan install leanprover/lean4:stable
elan default leanprover/lean4:stable

# Verify
lean --version
```

**Test build:**
```bash
cd aptos-move/framework/formal/lean
lake build MovementFormal.Experimental.ConfidentialAsset

# Check for breakage
# If errors: review Lean 4 changelog, fix deprecated APIs
```

---

### Step 3.4: Update Aptos CLI (if available)

```bash
# Install latest Aptos CLI
curl -fsSL https://aptos.dev/scripts/install_cli.py | python3

# Verify
aptos --version
```

**Test compilation:**
```bash
cd aptos-move/framework/aptos-experimental
aptos move compile --skip-fetch-latest-git-deps

# Check for breakage
# If errors: review Move changelog, fix deprecated features
```

---

### Step 3.5: Update lakefile.lean Dependencies

```bash
# Check for Mathlib4 updates
cd aptos-move/framework/formal/lean
lake update

# Re-build
lake build
```

**If build fails after update:**
1. Review breaking changes in dependency changelogs
2. Update import statements
3. Fix deprecated APIs
4. Re-test all proofs

---

### Step 3.6: Update CI Workflow Versions

**File:** `.github/workflows/ca-verification-suite.yaml`

```yaml
# Update Lean installation step
- name: Install Lean 4
  run: |
    curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y --default-toolchain leanprover/lean4:v4.X.Y
    echo "$HOME/.elan/bin" >> $GITHUB_PATH
```

**Test CI:**
```bash
# Push to test branch
git push origin maintenance/2026-Q1

# Trigger CI manually
gh workflow run ca-verification-suite.yaml --ref maintenance/2026-Q1

# Monitor
gh run watch
```

---

## Task 4: Documentation Refresh

**Goal:** Sync documentation with code, update stale content

**Time:** 60-90 minutes

---

### Step 4.1: Audit Documentation Inventory

```bash
cd aptos-move/framework/formal

# List all .md files
find . -name "*.md" | sort > doc_inventory.txt

# Count total lines
find . -name "*.md" -exec wc -l {} + | tail -n 1

# Expected: ~14,650 lines across 30+ documents
```

---

### Step 4.2: Check for Stale Content

**Review each major document:**

**VERIFICATION_PROGRESS_SUMMARY.md:**
- [ ] Phase completion percentages up-to-date
- [ ] Build time metrics current
- [ ] Axiom counts correct
- [ ] Next steps reflect current roadmap

**AXIOM_INVENTORY.md:**
- [ ] All 23 axioms documented
- [ ] Categories correct
- [ ] Justifications current
- [ ] No missing axioms (cross-check with `check_axioms.sh` output)

**TRUST_BOUNDARIES.md:**
- [ ] Opaque functions list current
- [ ] Native oracles documented
- [ ] Axiom cross-references correct

**Procedure:**
```bash
# For each document, compare documented state with actual state
./scripts/reconcile_trust_boundaries.sh

# Fix mismatches
vim TRUST_BOUNDARIES.md
```

---

### Step 4.3: Update "Last Updated" Dates

**Pattern:** Search for date stamps in documentation

```bash
# Find documents with date stamps
grep -r "Last updated:" . --include="*.md"
grep -r "Generated:" . --include="*.md"

# Update to current quarter
sed -i 's/Last updated: 2026-Q[0-9]/Last updated: 2026-Q1/' VERIFICATION_PROGRESS_SUMMARY.md
```

---

### Step 4.4: Validate Cross-References

**Check that all document cross-references are valid:**

```bash
# Extract all markdown links
grep -rho '\[.*\](.*\.md)' . --include="*.md" | sort | uniq > all_links.txt

# Check each link exists
while read -r link; do
  file=$(echo "$link" | sed 's/.*(\(.*\.md\)).*/\1/')
  if [[ ! -f "$file" ]]; then
    echo "Broken link: $link"
  fi
done < all_links.txt
```

**Fix broken links:**
- Update file paths if files moved
- Remove links to deleted files
- Add redirect comments for renamed files

---

## Task 5: Difftest Corpus Health Check

**Goal:** Validate all 87 difftest test cases, add coverage for new features

**Time:** 45-60 minutes

---

### Step 5.1: Run Full Difftest Suite

```bash
cd aptos-move/framework/formal

# Run all tests
./scripts/manage_difftest_corpus.sh test all | tee difftest_health_check.txt

# Expected output:
# Running 87 tests...
# ✅ 87 passed
# ❌ 0 failed
```

**If failures detected:**
1. Identify failing test: `grep "FAIL" difftest_health_check.txt`
2. Inspect test case: `cat difftest/confidential_asset/<test_id>.json`
3. Debug: Compare VM output with Lean model
4. Fix: Update test case or fix model bug
5. Re-run: `./scripts/manage_difftest_corpus.sh test <operation>`

---

### Step 5.2: Check Coverage

```bash
# Generate coverage report
./scripts/manage_difftest_corpus.sh coverage | tee difftest_coverage.txt

# Expected:
# Registration: 12 tests (happy + 3 error paths)
# Normalization: 14 tests (happy + 4 error paths)
# Withdrawal: 10 tests (happy + 3 error paths)
# Transfer: 17 tests (happy + 6 error paths)
# Rotation: 12 tests (happy + 3 error paths)
# Other ops: 22 tests
# Total: 87 tests, 85% coverage
```

---

### Step 5.3: Identify Coverage Gaps

**Review TEST_MATRIX.md:**
- [ ] All operations have happy path test
- [ ] All operations have error path tests (frozen, proof invalid, etc.)
- [ ] Edge cases covered (overflow, underflow, boundary conditions)

**Add missing tests:**
```bash
# Generate test skeleton
./scripts/generate_difftest_test.sh --operation <op> --scenario <scenario>

# Fill in test details
vim difftest/confidential_asset/<op>_<scenario>.json

# Validate
./scripts/manage_difftest_corpus.sh test <op>
```

---

## Task 6: CI/CD Workflow Validation

**Goal:** Ensure all CI workflows passing, optimize if needed

**Time:** 30-45 minutes

---

### Step 6.1: Check Workflow Status

```bash
# List all workflows
gh workflow list --repo movement-labs/aptos-core

# Check recent runs
gh run list --workflow=ca-verification-suite.yaml --limit 10

# Expected: All recent runs passed
```

---

### Step 6.2: Review Workflow Artifacts

```bash
# Download recent artifacts
RECENT_RUN=$(gh run list --workflow=ca-verification-suite.yaml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run download $RECENT_RUN

# Inspect
ls -la
cat lean-build-profile/build_profile.txt
cat axiom-report/current_axioms.txt
```

**Verify:**
- [ ] Build times within budget
- [ ] Axiom counts correct
- [ ] No unexpected errors

---

### Step 6.3: Optimize Workflow (if needed)

**If CI time > 15 minutes:**

**Optimization 1: Add caching**
```yaml
- name: Cache Lean build
  uses: actions/cache@v4
  with:
    path: ~/.elan
    key: ${{ runner.os }}-lean-${{ hashFiles('lakefile.lean') }}
```

**Optimization 2: Parallelize difftest**
```yaml
difftest-validation:
  strategy:
    matrix:
      operation: [registration, normalization, withdrawal, transfer, rotation]
  # ... (test only ${{ matrix.operation }})
```

**Expected improvement:** 2-3× faster CI

---

## Task 7: Trust Boundary Reconciliation

**Goal:** Ensure TRUST_BOUNDARIES.md and AXIOM_INVENTORY.md match implementation

**Time:** 30-45 minutes

---

### Step 7.1: Run Reconciliation Script

```bash
cd aptos-move/framework/formal

./scripts/reconcile_trust_boundaries.sh | tee trust_reconciliation.txt
```

**Expected output:**
```
Checking trust boundaries...
✅ All axioms documented in AXIOM_INVENTORY.md
✅ All opaque functions documented in TRUST_BOUNDARIES.md
✅ No mismatches detected

Summary:
- Total axioms: 23
- Documented axioms: 23
- Missing from docs: 0
- Extra in docs: 0
```

---

### Step 7.2: Fix Mismatches (if any)

**If mismatches detected:**

```bash
# Example mismatch output:
# ❌ Axiom MovementFormal.Crypto.bulletproof_soundness not documented
# ❌ Opaque function extract_proof_commitment documented but not found
```

**Remediation:**
1. **New axioms:** Add to AXIOM_INVENTORY.md with justification
2. **Removed axioms:** Remove from AXIOM_INVENTORY.md, celebrate axiom reduction!
3. **New opaque functions:** Add to TRUST_BOUNDARIES.md
4. **Removed opaque functions:** Remove from TRUST_BOUNDARIES.md

---

### Step 7.3: Update Documentation

```bash
# Edit AXIOM_INVENTORY.md
vim AXIOM_INVENTORY.md

# Edit TRUST_BOUNDARIES.md
vim TRUST_BOUNDARIES.md

# Re-run reconciliation
./scripts/reconcile_trust_boundaries.sh

# Should now output: ✅ No mismatches
```

---

## Task 8: Reproducibility Validation

**Goal:** Validate Docker build reproduces verification results

**Time:** 60-90 minutes

---

### Step 8.1: Build Docker Image

```bash
cd aptos-move/framework/formal

# Build image
docker build -t ca-verification:Q[N]-YYYY .

# Expected: Build succeeds
```

---

### Step 8.2: Run Verification in Container

```bash
# Run full verification suite in container
docker run --rm ca-verification:Q[N]-YYYY ./audit/verify-ca.sh --all

# Expected output:
# ✅ Lean verification: PASS
# ✅ MSL verification: BLOCKED (ristretto255)
# ✅ Difftest: PASS (87/87)
# ✅ Performance: PASS (4s < 600s)
# ✅ Axioms: PASS (23 permanent, 0 temporary)
```

---

### Step 8.3: Compare Container vs Local Results

```bash
# Run locally
./audit/verify-ca.sh --all > local_results.txt

# Run in container
docker run --rm ca-verification:Q[N]-YYYY ./audit/verify-ca.sh --all > container_results.txt

# Compare
diff local_results.txt container_results.txt

# Should be identical (or only differ in timestamps)
```

---

### Step 8.4: Publish Docker Image (Phase 7)

**If Phase 7 complete:**

```bash
# Tag image
docker tag ca-verification:Q[N]-YYYY movement/ca-verification:Q[N]-YYYY
docker tag ca-verification:Q[N]-YYYY movement/ca-verification:latest

# Push to registry
docker push movement/ca-verification:Q[N]-YYYY
docker push movement/ca-verification:latest
```

**Update DOCKER_REPRODUCIBILITY_GUIDE.md:**
```markdown
## Latest Image

**Tag:** `movement/ca-verification:Q1-2026`
**Digest:** `sha256:abc123...`
**Published:** 2026-01-15
```

---

## Post-Maintenance Checklist

**After completing all tasks:**

- [ ] All tasks completed (8/8)
- [ ] All acceptance criteria met
- [ ] Quarterly report drafted (see template below)
- [ ] Changes committed to maintenance branch
- [ ] Pull request created for review
- [ ] Stakeholders notified (quarterly report shared)
- [ ] Next quarter maintenance scheduled

**Commands:**
```bash
# Commit all changes
git add -A
git commit -m "chore: Q[N] YYYY quarterly maintenance

- Updated axiom inventory (still 23, 0 temporary)
- Refreshed performance baselines
- Updated dependencies (Lean X.Y.Z, Aptos X.Y.Z)
- Validated difftest corpus (87 tests passing)
- Reconciled trust boundaries (0 mismatches)
- Validated reproducibility (Docker image Q[N]-YYYY)

See quarterly report for details."

# Push and create PR
git push origin maintenance/2026-Q[N]
gh pr create --title "Quarterly Maintenance Q[N] YYYY" --body "See commit message for details"

# Tag post-maintenance state
git tag -a "post-maintenance-Q[N]-YYYY" -m "Post-maintenance snapshot Q[N] YYYY"
git push --tags
```

---

## Quarterly Report Template

```markdown
# Confidential Assets Formal Verification — Q[N] YYYY Maintenance Report

**Date:** [YYYY-MM-DD]  
**Maintainer:** [NAME]  
**Duration:** [X] hours  
**Status:** ✅ Complete

---

## Summary

Quarterly maintenance completed for Q[N] YYYY. All systems healthy, no critical issues identified.

**Key highlights:**
- Axiom count stable at 23 (0 temporary)
- Build times well under budget (4s vs 600s)
- Difftest coverage at 85% (87 tests passing)
- Dependencies updated to latest stable versions
- CI/CD workflows optimized ([X]% faster)

---

## Task Completion

| Task | Status | Time | Notes |
|------|--------|------|-------|
| 1. Axiom review | ✅ | 90 min | No new axioms, [X] reduction opportunities identified |
| 2. Performance baselines | ✅ | 60 min | No regressions, baselines updated |
| 3. Dependency updates | ✅ | 120 min | Lean 4.X.Y, Aptos X.Y.Z, no breaking changes |
| 4. Documentation refresh | ✅ | 75 min | [X] documents updated, all cross-refs valid |
| 5. Difftest health check | ✅ | 45 min | 87/87 passing, [X] new tests added |
| 6. CI/CD validation | ✅ | 30 min | All workflows passing, [X]% faster after optimization |
| 7. Trust boundary reconciliation | ✅ | 30 min | 0 mismatches |
| 8. Reproducibility validation | ✅ | 75 min | Docker image published: Q[N]-YYYY |

**Total time:** [X] hours

---

## Findings

### Axioms
- **Total:** 23 (unchanged)
- **Temporary:** 0 (unchanged)
- **Reduction opportunities:** [LIST]
  - [Opportunity 1]: [Description]
  - [Opportunity 2]: [Description]
- **Planned for Q[N+1]:** [ACTION ITEMS]

### Performance
- **Regression count:** [X] ([LIST if any])
- **Build time trend:** [UP/DOWN/STABLE] ([X]% change from Q[N-1])
- **Hotspots identified:** [LIST]
- **Optimizations applied:** [LIST]

### Dependencies
- **Lean:** [OLD VERSION] → [NEW VERSION]
- **Aptos CLI:** [OLD VERSION] → [NEW VERSION]
- **Breaking changes:** [LIST OR "None"]
- **Migration effort:** [X] hours

### Difftest
- **Coverage:** 85% (87 tests)
- **New tests added:** [X]
- **Failed tests remediated:** [X]
- **Coverage gaps:** [LIST]

### CI/CD
- **Workflow success rate:** [X]%
- **Average run time:** [X] min ([UP/DOWN] [X]% from Q[N-1])
- **Optimizations:** [LIST]
- **New workflows:** [LIST OR "None"]

---

## Action Items for Q[N+1]

**High priority:**
1. [ACTION 1]
2. [ACTION 2]

**Medium priority:**
1. [ACTION 1]
2. [ACTION 2]

**Low priority:**
1. [ACTION 1]
2. [ACTION 2]

---

## Recommendations

[Any strategic recommendations for the verification infrastructure]

---

## Next Maintenance

**Scheduled:** Q[N+1] YYYY ([MONTH])  
**Owner:** [TBD]  
**Preparation:** Review this report and action items 1 week before
```

---

## Appendix: Common Issues and Resolutions

### Issue 1: Axiom Count Increased

**Symptom:** `check_axioms.sh` reports > 23 axioms

**Cause:** New code introduced temporary axioms

**Resolution:**
1. Identify new axioms: `diff Q[N-1]_axioms.txt Q[N]_axioms.txt`
2. Review commit history: `git log --grep="axiom"`
3. Replace temporary axioms with theorems + proofs
4. Document permanent axioms in AXIOM_INVENTORY.md

---

### Issue 2: Build Time Regression

**Symptom:** Build time > 10% slower than Q[N-1]

**Cause:** Missing optimizations in new code

**Resolution:**
1. Profile: `./scripts/profile_lean_build.sh ...`
2. Identify hotspots: `./scripts/analyze_proof_structure.sh ...`
3. Apply fixes: Check for `@[irreducible]`, bare `simp`, etc.
4. Re-profile and validate

---

### Issue 3: Difftest Failures After Dependency Update

**Symptom:** Tests fail after updating Aptos CLI

**Cause:** VM behavior changed in new version

**Resolution:**
1. Identify changed tests: `diff old_results.txt new_results.txt`
2. Re-generate test cases with new VM output
3. Update Lean model if semantics changed
4. Re-validate: `./scripts/manage_difftest_corpus.sh test all`

---

**For questions, see:** `ERROR_DIAGNOSIS_GUIDE.md` or `TROUBLESHOOTING_GUIDE.md`
