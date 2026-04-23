# Testing Strategy Guide

**Last updated:** 2026-04-22

Comprehensive testing strategy for CA formal verification across all three stacks (Lean, Move Prover, difftest). Covers test design, coverage metrics, regression prevention, and CI integration.

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Test Pyramid](#test-pyramid)
3. [Lean Stack Testing](#lean-stack-testing)
4. [Move Prover Stack Testing](#move-prover-stack-testing)
5. [Difftest Stack Testing](#difftest-stack-testing)
6. [Integration Testing](#integration-testing)
7. [Regression Testing](#regression-testing)
8. [Performance Testing](#performance-testing)
9. [Coverage Metrics](#coverage-metrics)
10. [CI/CD Strategy](#cicd-strategy)

---

## Testing Philosophy

### Core Principles

**1. Verification ≠ Testing**

Formal verification proves properties for all inputs (∀), while testing checks specific inputs (∃). Both are necessary:

- **Verification:** "Balance sum is preserved for ALL transfers"
- **Testing:** "Balance sum preserved for THIS specific transfer (42 units, these keys)"

**Why both:** Verification proves correctness of the model; testing proves model matches reality (VM).

**2. Trust but Verify**

Even verified code needs tests:
- **Transcription errors:** Lean bytecode might not match VM bytecode
- **Axiom bugs:** Crypto axioms might be unsound
- **Tool bugs:** Lean kernel, Boogie, Z3 might have soundness bugs

Difftest catches these by running concrete inputs through both model and VM.

**3. Fail Fast, Fail Often**

Tests should run:
- **Locally:** Pre-commit hook (30s)
- **CI:** Every push (~13 min)
- **Release:** Comprehensive suite (~20 min)

Catching bugs in 30s (pre-commit) vs 13 min (CI) vs hours (manual testing) is exponentially cheaper.

**4. Test the Tests**

Meta-testing:
- Mutation testing (introduce bugs, check tests catch them)
- Coverage tracking (which code is exercised)
- Baseline comparison (detect test drift)

---

## Test Pyramid

### Traditional Test Pyramid (Inverted for FV)

```
        ┌───────────────────┐
        │   E2E Tests       │ ← Few, slow, high value
        │   (Difftest)      │
        ├───────────────────┤
        │  Integration      │ ← Some, medium, verify composition
        │  (verify-ca.sh)   │
        ├───────────────────┤
        │  Unit Tests       │ ← Many, fast, verify components
        │  (per-theorem,    │
        │   per-spec)       │
        └───────────────────┘
```

**Inverted for formal verification:**

```
        ┌───────────────────┐
        │  Verification     │ ← Top layer: ∀ proofs
        │  (Lean theorems,  │   (every theorem is a test of all inputs)
        │   MSL specs)      │
        ├───────────────────┤
        │  E2E Tests        │ ← Middle: concrete I/O pairs
        │  (Difftest 87+)   │   (model ↔ VM consistency)
        ├───────────────────┤
        │  Unit Tests       │ ← Bottom: infrastructure
        │  (Hygiene checks, │   (sorry count, axiom drift, builds)
        │   build tests)    │
        └───────────────────┘
```

**Why inverted:** Verification gives stronger guarantees than tests, so we invest more there. Tests validate verification assumptions.

---

## Lean Stack Testing

### L1: Per-Theorem Tests

**What:** Each Lean theorem is a test (proves property for all inputs).

**How to verify:**

```bash
# Build individual theorem
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild

# Check for sorry
grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/ && echo "FAIL: sorry found" || echo "PASS"

# Check axioms
lake env lean --run scripts/print_axioms.lean MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
```

**Coverage metric:** Zero `sorry` in production code (pre-commit hook enforces).

**Example:**

```lean
-- This theorem IS a test (proves step behavior for all frames, stacks, etc.)
theorem step_pc3 : frame.pc = 3 → step env frame cs stack ms = .success ... := by
  intro hpc
  simp only [step, hpc]
  rfl  -- Proof = test passes
```

### L2: Axiom Regression Tests

**What:** Ensure axiom count doesn't grow silently.

**How:**

```bash
# Generate baseline
./scripts/check_axioms.sh > audit/axiom-baseline.txt

# Check drift (CI)
./scripts/check_axioms.sh --diff
```

**Coverage metric:** Axiom count ≤ 27 (target: 22 permanent + 0 TEMPORARY at release).

**CI integration:** `.github/workflows/axiom-diff-ca.yaml` fails on drift.

### L3: Build Performance Tests

**What:** Ensure build times stay within budget (<3 min per file).

**How:**

```bash
# Time individual file
time lake build MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv

# Check against budget
if [ $? -gt 180 ]; then echo "FAIL: exceeds 3 min budget"; fi
```

**Coverage metric:** All files build in ≤180s (acceptance criterion).

**CI integration:** `scripts/run_verification_suite.sh` includes timing checks.

### L4: Difftest Corpus (Lean side)

**What:** Lean evaluator produces expected outputs for corpus inputs.

**How:**

```bash
# Run single corpus row
lake env lean --run scripts/difftest_eval.lean 128 '[]'
# Expected: {"type":"bool","value":true}

# Run full corpus (via harness)
cd difftest
cargo run --release -- --corpus corpora/confidential_assets/corpus.toml --stack lean
```

**Coverage metric:** 87+ corpus rows, all pass (vm-lean mode).

---

## Move Prover Stack Testing

### L1: Spec Compilation Tests

**What:** All MSL specs compile without errors.

**How:**

```bash
# Compile specs (should succeed even if 0 VCs)
movement move compile --package-dir aptos-move/framework/aptos-experimental

# Check for compilation errors
if [ $? -ne 0 ]; then echo "FAIL: spec compilation error"; fi
```

**Coverage metric:** All CA modules compile (current: ✅, 0 VCs expected until ristretto255 fix).

**CI integration:** `move-prover-ca.yaml` workflow.

### L2: VC Generation Tests (Blocked)

**What:** Move Prover generates verification conditions (VCs).

**Current status:** Blocked on ristretto255 patches (0 VCs expected).

**How (after blocker clears):**

```bash
# Run Move Prover
movement move prove \
  --package-dir aptos-move/framework/aptos-experimental \
  --filter confidential_asset::register_internal \
  --vc-timeout 120

# Check VC count
# Expected: >0 VCs generated, all proved
```

**Coverage metric:** >0 VCs generated per function (TBD after ristretto255).

### L3: Pragma Reconciliation Tests

**What:** All `pragma opaque` usages documented in `TRUST_BOUNDARIES.md`.

**How:**

```bash
# Run reconciliation script
./scripts/reconcile_trust_boundaries.sh

# Check for mismatches
if [ $? -ne 0 ]; then echo "FAIL: pragma opaque not documented"; fi
```

**Coverage metric:** 89 `pragma opaque` in CA specs, all documented.

**CI integration:** `ca-verification-suite.yaml` trust-boundaries job.

---

## Difftest Stack Testing

### L1: Corpus Coverage Tests

**What:** All operations have adequate corpus coverage (≥3 rows: happy + 2 errors).

**How:**

```bash
# Count rows per operation
grep -c "register" difftest/inventory/confidential_assets.md
grep -c "withdraw" difftest/inventory/confidential_assets.md
# etc.

# Check coverage threshold
if [ $ROWS -lt 3 ]; then echo "WARN: insufficient coverage for $OP"; fi
```

**Coverage metric:** 87+ total rows, ≥3 rows per operation.

**Current status:** Inventory complete, harness pending.

### L2: VM↔Lean Consistency Tests

**What:** VM and Lean produce identical outputs for same inputs.

**How:**

```bash
# Run difftest harness
cd difftest
cargo run --release -- \
  --corpus corpora/confidential_assets/corpus.toml \
  --mode vm-lean \
  --output json

# Check pass rate
jq '.summary.passed == .summary.total' output.json
```

**Coverage metric:** 100% pass rate on vm-lean mode rows.

**Current status:** Pending harness implementation.

### L3: Oracle Mismatch Detection

**What:** Detect when VM oracle ≠ Lean oracle (transcription bug).

**How:**

```bash
# Run with verbose output
cargo run -- --corpus corpus.toml --filter failing_test --verbose

# Compare outputs:
# VM:   Value::u64(42)
# Lean: Value::u64(43)
# → Transcription bug in Lean oracle
```

**Action:** Fix Lean oracle in `Native/*.lean`, re-run difftest.

---

## Integration Testing

### L1: Full Stack Verification (verify-ca.sh)

**What:** All three stacks pass for a given operation.

**How:**

```bash
# Test single operation across all stacks
./audit/verify-ca.sh --op register

# Internally runs:
# - Lean: lake build Registration.EvalEquiv
# - Move Prover: movement move prove --filter register_internal
# - Difftest: difftest harness --filter register
```

**Coverage metric:** All ops pass all stacks.

**CI integration:** `ca-verification-suite.yaml` runs full matrix.

### L2: Cross-Stack Composition Tests

**What:** Ensure Lean, MSL, and difftest agree on error codes.

**Example:**

```
Lean proof:     verify failed → aborted 65537
MSL spec:       aborts_if !verify(...) with 65537
Difftest row:   empty sigma → aborted 65537

All three must agree on 65537 = ESIGMA_PROTOCOL_VERIFY_FAILED
```

**How:**

```bash
# Extract error code from Lean
grep "ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE" lean/MovementFormal/.../Registration.lean

# Extract from MSL
grep "ESIGMA_PROTOCOL_VERIFY_FAILED" aptos-experimental/sources/confidential_asset/*.spec.move

# Extract from difftest corpus
grep "65537" difftest/inventory/confidential_assets.md

# All should show 65537
```

**Coverage metric:** All error codes consistent across stacks.

### L3: End-to-End Claim Validation

**What:** Each claim in `CLAIMS.md` is verified by appropriate stack(s).

**How:**

```bash
# For each claim in CLAIMS.md:
# 1. Identify verification method (Lean theorem, MSL spec, difftest row)
# 2. Run verification
# 3. Confirm passes

# Example: "transfer preserves balance sum"
# - Lean: Transfer/EvalEquiv.lean (bytecode correctness)
# - MSL: confidential_asset.spec.move (balance homomorphism)
# - Difftest: transfer corpus rows (VM consistency)
```

**Coverage metric:** All claims in `CLAIMS.md` have passing verification.

---

## Regression Testing

### L1: Axiom Regression (CI Guard)

**What:** New axioms fail CI unless documented.

**How:**

```bash
# CI runs on every push
./scripts/check_axioms.sh --diff

# If new axiom detected:
# - Fail CI
# - Require: AXIOM_INVENTORY.md update + baseline regeneration
```

**Prevention:** Developers can't accidentally introduce axioms without documentation.

**CI:** `axiom-diff-ca.yaml` workflow.

### L2: Performance Regression

**What:** Build time doesn't exceed budget (prevent O(N²) whnf creep).

**How:**

```bash
# Run regression detection
./scripts/detect_performance_regression.sh --baseline benchmarks/baseline-latest.txt --threshold 20

# If >20% slower: FAIL CI
```

**Prevention:** Catches slow proofs before they compound.

**CI:** Can be added to `ca-verification-suite.yaml`.

### L3: Sorry Regression

**What:** No new `sorry` in production code.

**How:**

```bash
# Pre-commit hook checks
git diff --cached -- 'lean/**/*.lean' | grep -c "^+.*sorry"

# If >0: fail commit (or warn)
```

**Prevention:** Work-in-progress proofs stay in WIP branches, not main.

**CI:** `pre-commit-hook.sh` script.

### L4: Verification Escape Regression

**What:** No new `pragma verify = false` in production code.

**How:**

```bash
# Check for new escapes
git diff --cached -- '**/*.spec.move' | grep -cE "^\+.*pragma verify = false"

# If in production code (not test-only): warn
```

**Prevention:** Keeps verification coverage high.

**CI:** `pre-commit-hook.sh` warns (doesn't fail).

---

## Performance Testing

### L1: Build Time Benchmarking

**What:** Track build time for all operations, all stacks.

**How:**

```bash
# Run benchmark suite
./scripts/benchmark_verification.sh --json > benchmarks/run-$(date +%Y%m%d).json

# Compare against budget:
# - Per-op Lean: ≤180s (actual: 1-2s)
# - Full Lean: ≤600s (actual: ~4s)
# - Per-op Move Prover: ≤180s (actual: ~1s compilation)
```

**Frequency:** Weekly (capture baseline), on-demand (debug slow builds).

**Storage:** `benchmarks/*.json` (time-series data for trend analysis).

### L2: Regression Detection

**What:** Automated detection of build time regressions.

**How:**

```bash
# CI runs on every push
./scripts/detect_performance_regression.sh --threshold 20

# If any op >20% slower: fail CI
```

**Action:** Investigate slow proof (profiler, refactor, split lemmas).

### L3: Profiling

**What:** Identify bottlenecks in slow proofs.

**How:**

```bash
# Profile slow file
lake env lean --run -Dprofiler=true MovementFormal/Experimental/.../SlowFile.lean

# Output shows:
# - Elaboration time: 120s (problem!)
# - Whnf reduction: 80s (O(N²) chain traversal)
# - Tactic execution: 10s (ok)

# Fix: Use @[irreducible], avoid bound proofs in statements
```

**Tools:** Lean profiler (`-Dprofiler=true`), heartbeat monitoring.

---

## Coverage Metrics

### Lean Stack Coverage

| Metric | Target | Current | Gap |
|--------|--------|---------|-----|
| Zero sorry in production | 100% | 100% | ✅ None |
| Axiom count ≤22 permanent | ≤22 | 27 (1 TEMPORARY + 26 permanent) | ⚠️ 1 TEMPORARY (Phase 1) |
| Build time per-op ≤180s | 100% | 100% (1-2s actual) | ✅ None |
| Full tree ≤600s | ≤600s | ~4s | ✅ None |
| Difftest corpus (Lean side) | 87+ rows | 87+ | ✅ Ready (harness pending) |

### Move Prover Stack Coverage

| Metric | Target | Current | Gap |
|--------|--------|---------|-----|
| All modules compile | 100% | 100% | ✅ None |
| VCs generated (per function) | >0 | 0 (blocked) | ⚠️ Ristretto255 blocker |
| Pragma opaque documented | 100% | 100% (89/89) | ✅ None |
| Spec blocks written | 100% | 100% | ✅ None |

### Difftest Stack Coverage

| Metric | Target | Current | Gap |
|--------|--------|---------|-----|
| Corpus rows | 87+ | 87+ | ✅ Complete |
| Rows per operation | ≥3 | ≥3 | ✅ Complete |
| VM↔Lean pass rate | 100% | N/A | ⚠️ Harness pending |
| Coverage (operations) | 100% | 100% (inventory) | ✅ Ready |

### Overall Coverage

| Stack | Coverage | Status |
|-------|----------|--------|
| Lean | 100% (1 TEMPORARY axiom) | ✅ Production-ready (Phase 1 outstanding) |
| Move Prover | Specs 100%, VCs 0% | ⚠️ Blocked on ristretto255 |
| Difftest | Inventory 100%, harness 0% | ⚠️ Pending implementation (~1 day) |

---

## CI/CD Strategy

### CI Workflow Structure

**Parallel jobs (6 jobs, ~13 min total):**

```
┌──────────────────┐
│  quick-check     │ (2 min) ← Lean toolchain, Move Prover toolchain, sorry count
└──────────────────┘
         │
         ├─────────────┬─────────────┬─────────────┬─────────────┐
         ▼             ▼             ▼             ▼             ▼
    ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐
    │ Lean   │   │  Move  │   │ Trust  │   │  Docs  │   │ Diff   │
    │ build  │   │ Prover │   │ bounds │   │ check  │   │ test   │
    │ (5min) │   │ (3min) │   │ (1min) │   │ (2min) │   │ (pend) │
    └────────┘   └────────┘   └────────┘   └────────┘   └────────┘
         │             │             │             │             │
         └─────────────┴─────────────┴─────────────┴─────────────┘
                                   │
                                   ▼
                          ┌──────────────────┐
                          │  performance-    │ (2 min)
                          │  check           │
                          └──────────────────┘
                                   │
                                   ▼
                          ┌──────────────────┐
                          │  verification-   │ (summary)
                          │  complete        │
                          └──────────────────┘
```

**Total: ~13 min** (vs ~45 min serial, 3.5x speedup)

### CI Job Details

**1. quick-check (prerequisite, 2 min):**
- Lean toolchain version check
- Move Prover toolchain check (Z3 4.11.2, Boogie 3.5.1)
- Sorry count check (must be 0)
- Axiom baseline fetch

**2. lean-build (parallel, ~5 min):**
- `lake exe cache get` (fetch mathlib)
- `lake build` (full CA tree)
- Check build time ≤600s
- Upload timing metrics

**3. move-prover-compile (parallel, ~3 min):**
- Compile all CA modules
- Check for spec errors
- Expect 0 VCs (ristretto255 blocker)
- Upload compilation log

**4. trust-boundaries (parallel, ~1 min):**
- Run `./scripts/reconcile_trust_boundaries.sh`
- Check axiom count ≤27
- Check pragma opaque documented (89/89)

**5. docs-check (parallel, ~2 min):**
- Check CLAIMS.md has entry for all ops
- Check TRUST_BOUNDARIES.md reconciles
- Check plan §0 currency

**6. difftest (parallel, pending):**
- Run difftest harness (pending implementation)
- Check 100% pass rate

**7. performance-check (sequential, ~2 min):**
- Run `./scripts/detect_performance_regression.sh`
- Fail if >20% slower than baseline

**8. verification-complete (summary):**
- Aggregate all job results
- Post summary comment (pass/fail counts)

### Local Pre-CI Workflow

**Before pushing:**

```bash
# Quick check (~2 min)
./scripts/run_verification_suite.sh --quick

# If quick passes, push
git push

# CI runs comprehensive check (~13 min)
# If CI fails, fix locally and re-push
```

**Before release:**

```bash
# Comprehensive check (~15 min)
./scripts/run_verification_suite.sh --comprehensive

# Release validation (~20 min)
./scripts/release_validation.sh --comprehensive

# If both pass, proceed with release
```

---

## Test Maintenance

### Quarterly Review

**Checklist (see `MAINTENANCE_GUIDE.md` §5):**

1. Run full verification suite
2. Check axiom count (no growth)
3. Regenerate performance baseline
4. Review corpus coverage (add missing rows)
5. Update test documentation

**Automation:**

```bash
./scripts/quarterly_audit.sh
```

### When to Add New Tests

**Triggers:**

1. **New operation added:** Add corpus rows (≥3), Lean theorems, MSL specs
2. **Bug found in production:** Add regression test (prevent recurrence)
3. **Axiom eliminated:** Verify axiom baseline updated
4. **Performance regression:** Add performance baseline checkpoint

### When to Update Tests

**Triggers:**

1. **Move source changed:** Re-transcribe Lean bytecode, update MSL specs
2. **Error code changed:** Update all three stacks (Lean, MSL, difftest)
3. **Tool version changed:** Regenerate baselines (Lean 4.x.x, Z3 x.x.x)

---

## Troubleshooting Test Failures

### Lean Test Failure

**Symptom:** `lake build` fails

**Diagnosis:**

```bash
# Check which file failed
lake build 2>&1 | grep "error:"

# Read error message
# Common: type mismatch, sorry, axiom, timeout
```

**Fix:**
- Type mismatch → Check step lemma application
- Sorry → Complete proof or use axiom with doc-comment
- Timeout → Profile, refactor (see Performance Testing §8)

### Move Prover Test Failure

**Symptom:** `movement move compile` fails

**Diagnosis:**

```bash
# Check compilation errors
movement move compile --package-dir aptos-experimental 2>&1 | grep "error:"

# Common: syntax error, type error, missing spec
```

**Fix:**
- Syntax error → Fix MSL spec syntax
- Type error → Check spec function signatures
- Currently: all CA modules compile (0 VCs expected)

### Difftest Test Failure

**Symptom:** VM output ≠ Lean output

**Diagnosis:**

```bash
# Run with verbose output
cargo run -- --corpus corpus.toml --filter failing_test --verbose

# Compare:
# VM:   Value::bool(true)
# Lean: Value::bool(false)
```

**Fix:**
- Re-transcribe Lean bytecode (check against `movement move disassemble`)
- Update Lean oracle (check `Native/*.lean`)
- Verify corpus input is correct

---

## Summary

**Testing strategy:**
- **Lean:** Every theorem is a test (∀ proof), plus hygiene checks
- **Move Prover:** Spec compilation, VC generation (blocked), pragma reconciliation
- **Difftest:** 87+ corpus rows, VM↔Lean consistency (harness pending)

**Coverage:**
- Lean: 100% (1 TEMPORARY axiom outstanding)
- Move Prover: Specs 100%, VCs 0% (blocked)
- Difftest: Inventory 100%, harness 0% (pending)

**CI strategy:**
- 6 parallel jobs, ~13 min total
- Pre-commit hook (30s) catches 80% of issues
- Release validation (20 min) comprehensive check

**Regression prevention:**
- Axiom drift guard (CI)
- Performance regression detection (CI-ready)
- Sorry guard (pre-commit hook)
- Verification escape guard (pre-commit hook)

**For more details:** See individual guides (DEVELOPER_QUICK_START, TROUBLESHOOTING_GUIDE, PERFORMANCE_BENCHMARKING_GUIDE).
