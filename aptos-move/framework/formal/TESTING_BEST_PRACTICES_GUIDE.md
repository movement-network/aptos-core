# Testing Best Practices Guide: CA Formal Verification

**Last updated:** 2026-04-23  
**Audience:** Developers, reviewers, maintainers  
**Purpose:** Comprehensive guide to testing verification work correctly

---

## Quick Start

```bash
# Pre-commit check (30 sec)
cd aptos-move/framework/formal
./scripts/test_verification_infrastructure.sh --quick

# Validate current state (1 min)
./scripts/validate_current_state.sh

# Full verification (varies by operation)
cd audit
./verify-ca.sh --op register    # ~1-2s
./verify-ca.sh --op transfer    # ~1-2s
./verify-ca.sh                  # Full matrix ~6s

# Benchmark (2 min)
cd ..
./scripts/benchmark_verification.sh
```

---

## Testing Philosophy

### Core Principles

1. **Test at the right level**
   - Unit: Individual lemmas and theorems
   - Integration: Per-operation full proofs
   - System: Full 3-stack verification

2. **Test early, test often**
   - Pre-commit: Quick checks (<30s)
   - Pre-PR: Standard suite (~5 min)
   - Pre-merge: Comprehensive (~15 min)

3. **Automate everything**
   - Manual testing is error-prone
   - CI catches regressions
   - Local tests give fast feedback

4. **Measure what matters**
   - Build time (target: <3 min per operation)
   - Sorry count (target: 0, baseline: 21)
   - Axiom count (target: permanent only, baseline: 62)
   - VC coverage (target: all specs verified)

---

## Test Categories

### Category 1: Lean Build Tests

**What:** Verify Lean code compiles and type-checks correctly

**When:** After any Lean file change

**Commands:**
```bash
cd lean

# Single file
lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv

# Full tree
lake build

# Clean rebuild (if cached artifacts suspect)
lake clean && lake exe cache get && lake build
```

**Success criteria:**
- No compilation errors
- No type errors
- Build completes in reasonable time (<10 min full tree)

**Common issues:**
- Missing mathlib cache: Run `lake exe cache get`
- Import cycle: Check imports with `lakefile.lean`
- Version mismatch: Check `lean-toolchain` matches installed version

**Debugging:**
```bash
# Check lake configuration
lake env printenv

# Verbose build
lake build -v

# Single-threaded build (easier to debug)
lake build -j 1
```

---

### Category 2: Proof Correctness Tests

**What:** Verify proofs are actually proving what they claim

**When:** After adding/modifying theorems

**Checks:**
1. **No sorry:** All proof obligations discharged
2. **No TEMPORARY axioms:** Only permanent axioms remain
3. **Axiom count stable:** No unexpected axiom growth

**Commands:**
```bash
cd lean

# Count sorries
grep -r "^[[:space:]]*sorry" MovementFormal/Experimental/ConfidentialAsset --include="*.lean" | wc -l
# Target: 0 (current baseline: 21 with known locations)

# Count axioms
grep -r "^axiom " MovementFormal/Experimental/ConfidentialAsset --include="*.lean" | wc -l
# Target: 62 (57 permanent + 5 TEMPORARY for elimination)

# Check for TEMPORARY axioms
grep -B2 "^axiom " MovementFormal/Experimental/ConfidentialAsset --include="*.lean" | grep -i "TEMPORARY"
# Target: 0 eventually (currently 5)
```

**Validation:**
```bash
# Run axiom baseline diff
cd ..
./scripts/check_axioms.sh --baseline

# Expected: No unexpected new axioms
# If axioms changed: Update AXIOM_INVENTORY.md with rationale
```

---

### Category 3: MSL Spec Tests

**What:** Verify Move Specification Language specs compile and verify

**When:** After any .spec.move file change

**Commands:**
```bash
# Compilation only (fast)
cd aptos-move/framework/aptos-experimental
movement move compile \
    --package-dir . \
    --named-addresses aptos_experimental=0x7 \
    --skip-fetch-latest-git-deps

# Expected: {"Result": [...]} with no errors

# Verification (slower, blocked on ristretto255 currently)
movement move prove \
    --package-dir . \
    --named-addresses aptos_experimental=0x7 \
    --filter confidential_asset \
    --vc-timeout 120 \
    --skip-fetch-latest-git-deps

# Expected: VCs generated and verified (or 0 VCs if ristretto255 blocker)
```

**Success criteria:**
- Compilation succeeds
- VCs generated (> 0, once ristretto255 fixed)
- VCs verify or fail with actionable errors
- Per-operation verification ≤ 180s

**Common issues:**
- Syntax errors: Check spec blocks match source functions
- Type errors: Check `spec fun` signatures match `fun` signatures
- Timeout: Increase `--vc-timeout` or optimize spec
- Ristretto255 blocker: See RISTRETTO255_BLOCKER_INVESTIGATION_PLAN.md

---

### Category 4: Difftest Corpus Tests

**What:** Verify VM output matches Lean evaluation on concrete inputs

**When:** After any behavioral change to Lean oracles or VM natives

**Commands:**
```bash
# Via verify-ca.sh
cd aptos-move/framework/formal/audit
./verify-ca.sh --stack difftest

# Direct difftest (if available)
cd ../../../difftest
./difftest.sh --corpus confidential_asset

# Check corpus integrity
grep -c "^|" inventory/confidential_assets.md
# Expected: 87+ rows
```

**Success criteria:**
- All corpus rows pass (VM output == Lean eval)
- Hygiene check passes (no line-start sorries in production code)
- No `Blocked` or `Option B` entries

**Common failures:**
- Sorry hygiene: Phase 6 work in progress (expected until proofs complete)
- VM divergence: Update either VM or Lean to match, document in difftest inventory

---

### Category 5: Infrastructure Tests

**What:** Verify all scripts, documentation, and CI are functional

**When:** After any infrastructure change

**Commands:**
```bash
cd aptos-move/framework/formal

# Quick infrastructure test (~1 min)
./scripts/test_verification_infrastructure.sh --quick

# Full infrastructure test (~3 min)
./scripts/test_verification_infrastructure.sh

# State validation
./scripts/validate_current_state.sh
```

**Test coverage:**
- File structure (deliverables present)
- Script executability
- Documentation cross-references
- Lean configuration
- MSL spec files
- Metrics (sorry/axiom counts)
- Git status (no artifacts tracked)
- Build artifacts (Dockerfile, CI YAML)

**Success criteria:**
- 14/15 tests pass (current: 1 script not executable)
- All core deliverables present
- Documentation links valid
- Metrics within bounds

---

### Category 6: Performance Tests

**What:** Measure and track build times, proof complexity

**When:** After optimization work or before releases

**Commands:**
```bash
cd aptos-move/framework/formal

# Benchmark all operations
./scripts/benchmark_verification.sh

# Benchmark single operation
./scripts/benchmark_verification.sh --operation register

# Generate baseline
./scripts/benchmark_verification.sh --baseline > baseline_$(date +%Y%m%d).txt

# Compare against baseline
./scripts/benchmark_verification.sh --compare baseline_YYYYMMDD.txt
```

**Metrics tracked:**
- Per-file build time (target: <3 min)
- Full tree build time (target: <10 min)
- Per-operation verification time (target: <3 min)
- Theorem count per file
- Heartbeat usage (target: <200K per theorem)

**Regression detection:**
- > 20% slower: Investigate and optimize
- > 50% slower: Block merge, requires fix
- Build time > 3 min: Architecture issue, redesign needed

---

## Testing Workflows

### Pre-Commit Workflow (30 sec - 2 min)

```bash
# Run quick checks
./scripts/test_verification_infrastructure.sh --quick
./scripts/validate_current_state.sh

# Expected results:
# - 14/15 infrastructure tests pass
# - Sorry count ≤ baseline
# - Axiom count ≤ baseline
# - No tracked artifacts
```

**What to check:**
- Infrastructure tests pass
- No new sorries introduced
- No unexpected axioms added
- No build artifacts accidentally staged

**If failing:**
- Fix issues before committing
- Or document intentional changes in commit message

---

### Pre-PR Workflow (5-10 min)

```bash
# Full infrastructure test
./scripts/test_verification_infrastructure.sh

# Full verification check
cd audit
./verify-ca.sh

# Benchmark (to detect regressions)
cd ..
./scripts/benchmark_verification.sh --compare baseline_latest.txt

# Axiom diff check
./scripts/check_axioms.sh --baseline

# Trust boundary reconciliation
./scripts/reconcile_trust_boundaries.sh
```

**What to check:**
- All infrastructure tests pass
- Verification succeeds for affected operations
- No performance regressions (>20% slower)
- No unexpected axiom growth
- Trust boundaries still reconcile

**If failing:**
- Fix issues before opening PR
- Or document known issues in PR description
- Update baselines if intentional change

---

### Pre-Merge Workflow (15-30 min)

```bash
# Comprehensive verification suite
./scripts/run_verification_suite.sh --comprehensive

# Full 3-stack verification
cd audit
./verify-ca.sh  # All operations, all stacks

# Integration tests
cd ..
./scripts/integration_test_suite.sh

# Performance benchmarking
./scripts/benchmark_verification.sh

# Documentation validation
./scripts/validate_deliverables.sh
```

**What to check:**
- Full verification suite passes
- All 3 stacks green (Lean + MSL + difftest)
- Integration tests pass (50+ cases)
- Performance within budget
- All Phase 7 deliverables valid

**If failing:**
- Block merge until fixed
- Or get explicit approval for known issue
- Document limitation in TRUST_BOUNDARIES.md

---

### Release Workflow (30-45 min)

```bash
# Pre-release checklist
./scripts/release_checklist.sh --version X.Y.Z

# Full verification with all checks
cd audit
./verify-ca.sh --full

# Regenerate baselines
cd ..
./scripts/benchmark_verification.sh --baseline > baselines/baseline_vX.Y.Z.txt
./scripts/check_axioms.sh --update-baseline

# Update documentation
# - AXIOM_INVENTORY.md
# - PHASE_*_STATUS.md
# - COMPLETION_ROADMAP.md
# - CURRENT_STATE_ANALYSIS_YYYYMMDD.md

# Tag release
git tag -a vX.Y.Z -m "CA FV Release vX.Y.Z"
```

**Release checklist:**
1. ✅ All tests pass
2. ✅ No sorries in production code
3. ✅ Axiom count documented
4. ✅ Performance benchmarks updated
5. ✅ Documentation current
6. ✅ CI green
7. ✅ Docker image published
8. ✅ Baselines regenerated

---

## Common Testing Patterns

### Pattern 1: Test-Driven Proof Development

```bash
# 1. Write theorem signature with sorry
theorem new_theorem : statement := by sorry

# 2. Test that it builds
lake build MovementFormal.Path.To.File

# 3. Fill in proof structure
theorem new_theorem : statement := by
  have part1 : ... := by sorry
  have part2 : ... := by sorry
  exact combine part1 part2

# 4. Test again
lake build MovementFormal.Path.To.File

# 5. Fill in parts incrementally, testing after each
theorem new_theorem : statement := by
  have part1 : ... := by
    -- actual proof
  have part2 : ... := by sorry
  exact combine part1 part2

# 6. Test final
lake build MovementFormal.Path.To.File
# Expected: Success, no sorry

# 7. Verify axiom count unchanged
./scripts/check_axioms.sh --baseline
```

---

### Pattern 2: Regression Testing After Optimization

```bash
# 1. Benchmark before optimization
./scripts/benchmark_verification.sh > /tmp/before.txt

# 2. Apply optimization

# 3. Test still builds
lake build

# 4. Benchmark after optimization
./scripts/benchmark_verification.sh > /tmp/after.txt

# 5. Compare
diff /tmp/before.txt /tmp/after.txt

# 6. Verify speedup
# Expected: Build time decreased, all theorems still proved
```

---

### Pattern 3: Testing MSL Spec Strengthening

```bash
# 1. Compile current spec
movement move compile --package-dir aptos-experimental --filter confidential_asset
# Expected: Success

# 2. Count VCs before strengthening
movement move prove ... | grep "VC" | wc -l
# Note count

# 3. Add stronger ensures/requires clauses

# 4. Compile again
movement move compile ...
# Expected: Success (syntax valid)

# 5. Count VCs after strengthening
movement move prove ... | grep "VC" | wc -l
# Expected: More VCs (stronger spec)

# 6. Verify VCs prove
# Expected: All VCs verify within timeout (180s)
```

---

## Debugging Failing Tests

### Lean Build Failure

**Symptom:** `lake build` fails with error

**Debug steps:**
```bash
# 1. Check which file failed
lake build -v 2>&1 | grep "error"

# 2. Build just that file
lake build MovementFormal.Path.To.FailingFile

# 3. Read error carefully
# Common: missing import, type mismatch, sorry in theorem

# 4. Check imports
grep "^import" lean/MovementFormal/Path/To/FailingFile.lean

# 5. Check for circular imports
# (lakefile.lean should catch these)

# 6. Fix and rebuild
lake build
```

**Common fixes:**
- Add missing import
- Fix type annotation
- Remove accidentally introduced sorry
- Update dependent lemma signature

---

### MSL Verification Failure

**Symptom:** `movement move prove` fails or times out

**Debug steps:**
```bash
# 1. Run with verbose output
movement move prove ... --verbose 2>&1 | tee /tmp/msl_debug.log

# 2. Check which VC failed
grep "VC.*failed" /tmp/msl_debug.log

# 3. Identify corresponding spec
# VC names map to spec clauses

# 4. Common issues:
# - Too strong: spec claims something that doesn't hold
# - Too weak: spec doesn't capture actual behavior
# - Missing modifies: spec doesn't list all modified resources

# 5. Fix spec and retry
movement move prove ...
```

**Common fixes:**
- Weaken overly strong ensures clause
- Add missing abort_if condition
- Add missing modifies clause
- Split complex spec into simpler parts

---

### Difftest Failure

**Symptom:** VM output ≠ Lean eval

**Debug steps:**
```bash
# 1. Identify failing corpus row
./verify-ca.sh --stack difftest 2>&1 | grep "FAIL"

# 2. Extract input/output
# Check difftest/difftest_oracle.json for the failing case

# 3. Reproduce in isolation
# Run VM on input, run Lean eval on input

# 4. Compare outputs byte-by-byte
# Identify where they diverge

# 5. Determine correct behavior
# Is VM wrong or Lean wrong?

# 6. Fix and retest
./verify-ca.sh --stack difftest
```

**Common fixes:**
- Update Lean oracle to match VM behavior
- Fix VM implementation (if incorrect)
- Update difftest corpus with correct output

---

## Best Practices Summary

### DO

- ✅ Test locally before pushing
- ✅ Run quick tests pre-commit
- ✅ Run full tests pre-PR
- ✅ Benchmark after optimization
- ✅ Update baselines when intentional change
- ✅ Document known limitations
- ✅ Keep tests fast (<30s quick, <5min standard)
- ✅ Automate repetitive checks

### DON'T

- ❌ Push without testing locally
- ❌ Skip quick tests ("it's just a comment")
- ❌ Introduce sorries in production code without plan
- ❌ Add axioms without documentation
- ❌ Commit build artifacts
- ❌ Optimize prematurely (test first, measure, then optimize)
- ❌ Rely on manual testing
- ❌ Ignore performance regressions

---

## Quick Reference

### Daily Commands

```bash
# Morning sync
./scripts/validate_current_state.sh

# Pre-commit
./scripts/test_verification_infrastructure.sh --quick

# Full check
cd audit && ./verify-ca.sh && cd ..

# End of day
./scripts/benchmark_verification.sh
```

### Weekly Commands

```bash
# Phase progress tracking
./scripts/track_phase_progress.sh

# Baseline comparison
./scripts/diff_verification_baseline.sh

# Comprehensive suite
./scripts/run_verification_suite.sh --comprehensive
```

### Release Commands

```bash
# Pre-release validation
./scripts/release_checklist.sh --version X.Y.Z
./scripts/validate_deliverables.sh

# Baseline updates
./scripts/benchmark_verification.sh --baseline
./scripts/check_axioms.sh --update-baseline

# Trust boundary check
./scripts/reconcile_trust_boundaries.sh
```

---

## Troubleshooting

### "Lake command not found"

```bash
# Install elan (Lean version manager)
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh

# Restart terminal or source profile
source ~/.profile

# Verify
lake --version
```

### "Mathlib cache missing, build taking hours"

```bash
cd lean
lake exe cache get
lake build
# Should complete in minutes, not hours
```

### "Z3_EXE not set" (Move Prover)

```bash
movement update prover-dependencies --assume-yes
source ~/.zshrc  # or ~/.bashrc
echo $Z3_EXE  # Should show path
```

### "Script not executable"

```bash
chmod +x scripts/*.sh
# Or specific script:
chmod +x scripts/validate_current_state.sh
```

---

## Conclusion

Testing is not optional - it's how we ensure verification claims hold. Follow these practices:

1. **Test early and often** - Catch issues before they compound
2. **Test at the right level** - Unit → Integration → System
3. **Automate everything** - Manual testing doesn't scale
4. **Measure performance** - "Works" isn't enough, "works fast" is the goal

With proper testing discipline, we maintain high quality while moving fast. Happy testing! 🧪
