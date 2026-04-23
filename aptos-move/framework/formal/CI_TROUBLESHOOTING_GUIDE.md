# CI Troubleshooting Guide

**Purpose:** Systematic diagnosis and resolution of CI failures in Confidential Assets formal verification workflows.

**Audience:** Developers responding to CI failures, formal verification maintainers.

**Scope:** All CI workflows in `.github/workflows/*ca*.yaml` and `*lean*.yaml`.

---

## Table of Contents

1. [Quick Diagnostic Flowchart](#1-quick-diagnostic-flowchart)
2. [Lean CI Failures](#2-lean-ci-failures)
3. [Move Prover CI Failures](#3-move-prover-ci-failures)
4. [Difftest CI Failures](#4-difftest-ci-failures)
5. [Axiom Drift CI Failures](#5-axiom-drift-ci-failures)
6. [Performance CI Failures](#6-performance-ci-failures)
7. [Documentation CI Failures](#7-documentation-ci-failures)
8. [Trust Boundaries CI Failures](#8-trust-boundaries-ci-failures)
9. [Timeout Failures](#9-timeout-failures)
10. [Flaky Test Diagnosis](#10-flaky-test-diagnosis)

---

## 1. Quick Diagnostic Flowchart

```
CI Failed
   │
   ├─ Is it red on main branch?
   │  ├─ YES → Critical: follow §1.1 (Main Branch Red)
   │  └─ NO  → Continue
   │
   ├─ Which job failed?
   │  ├─ lean-ca           → §2 (Lean CI Failures)
   │  ├─ move-prover-ca    → §3 (Move Prover CI Failures)
   │  ├─ difftest-ca       → §4 (Difftest CI Failures)
   │  ├─ axiom-diff-ca     → §5 (Axiom Drift CI Failures)
   │  ├─ performance-ca    → §6 (Performance CI Failures)
   │  ├─ docs-ca           → §7 (Documentation CI Failures)
   │  └─ trust-boundaries-ca → §8 (Trust Boundaries CI Failures)
   │
   ├─ Is it a timeout?
   │  └─ YES → §9 (Timeout Failures)
   │
   ├─ Does it pass locally?
   │  └─ YES → §10 (Flaky Test Diagnosis)
   │
   └─ Is there an error message?
      ├─ YES → Search this guide for error message
      └─ NO  → Enable debug logging, re-run
```

### 1.1 Main Branch Red

**CRITICAL: Main branch must always be green.**

**Immediate actions (within 1 hour):**

1. **Identify which commit broke main:**
   ```bash
   git log --oneline -10
   # Find last green commit in CI
   ```

2. **Triage severity:**
   - **Blocking:** Breaks verification of existing operations → revert immediately
   - **Non-blocking:** New feature incomplete → disable feature, fix forward

3. **Revert if blocking:**
   ```bash
   git revert <breaking-commit-sha>
   git push origin movement
   # Alert team in Slack #formal-verification
   ```

4. **Fix forward if non-blocking:**
   ```bash
   git checkout -b hotfix/ci-green-main
   # Apply minimal fix
   git push origin hotfix/ci-green-main
   # Fast-track PR (ping formal verification team lead)
   ```

**Post-incident (within 24 hours):**
- Root cause analysis
- Update pre-commit hooks to catch this failure mode
- Update this guide with new diagnostic pattern

---

## 2. Lean CI Failures

### 2.1 Workflow Location

`.github/workflows/lean-ca.yaml`

**What it does:**
- Installs Lean 4.24.0
- Downloads mathlib cache
- Runs `lake build MovementFormal`
- Checks axiom count
- Validates build time <600s

### 2.2 Common Failures

#### Failure: "lake build MovementFormal failed with exit code 1"

**Error message:**
```
error: type mismatch at step_pc42
  expected: step env (state 42) = state 43
  got:      step env (state 42) = .error
```

**Cause:** Bytecode changed, Lean proof out of sync.

**Diagnosis:**
```bash
# Check if Move source changed recently
git log --oneline -5 -- aptos-move/framework/aptos-experimental/sources/confidential_asset/
```

**Fix:**
```bash
# Locally rebuild Lean proofs for affected operation
cd lean
lake clean
lake build MovementFormal.Experimental.ConfidentialAsset.OPERATION.EvalEquiv

# If build fails, follow §4.1 of VERIFICATION_MAINTENANCE_HANDBOOK.md
# Update PC-chaining to match new bytecode

# Once green locally, push
git commit -am "lean: update OPERATION proofs for bytecode changes"
git push
```

---

#### Failure: "mathlib cache download failed"

**Error message:**
```
curl: (28) Failed to connect to port 443: Connection timed out
```

**Cause:** GitHub cache service down or network issue.

**Fix (CI):**
```yaml
# In .github/workflows/lean-ca.yaml, add retry:
- name: Download mathlib cache
  run: lake exe cache get || lake exe cache get || lake exe cache get
  # Three attempts with automatic retry
```

**Fix (local):**
```bash
# Download cache manually
lake exe cache get --force
```

---

#### Failure: "Build time exceeded 600s"

**Error message:**
```
Build took 723s, exceeded budget of 600s
```

**Cause:** Performance regression in Lean proofs.

**Fix:** Follow §6 (Performance CI Failures).

---

### 2.3 Lean CI Debug Mode

**Enable verbose logging:**

```yaml
# In .github/workflows/lean-ca.yaml:
- name: Build Lean verification
  run: lake build MovementFormal --verbose
```

**Check specific file:**

```yaml
- name: Build specific file
  run: lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv --verbose
```

**Print axiom count:**

```yaml
- name: Check axioms
  run: |
    cd lean
    lake build MovementFormal
    ./scripts/check_axioms.sh
```

---

## 3. Move Prover CI Failures

### 3.1 Workflow Location

`.github/workflows/move-prover-ca.yaml`

**What it does:**
- Installs Movement CLI
- Installs Boogie 3.5.1, Z3 4.11.2, CVC5 0.0.3
- Runs `movement move prove` on all CA modules
- Validates VC count, timeout budget

### 3.2 Common Failures

#### Failure: "VC timeout"

**Error message:**
```
Verification of confidential_asset::withdraw_to_internal failed after 120s
```

**Cause:** Z3 couldn't prove the property in time.

**Quick fix (increase timeout):**
```yaml
# In .github/workflows/move-prover-ca.yaml:
- name: Run Move Prover
  run: movement move prove --vc-timeout 300 ...  # Was 120
```

**Permanent fix (optimize spec):**
```move
// In confidential_asset.spec.move:
spec module {
    pragma opaque = verify_proof_internal;  // Don't inline expensive function
}
```

**Diagnosis:**
```bash
# Run locally with verbose output
movement move prove \
  --package-dir aptos-move/framework/aptos-experimental \
  --filter confidential_asset::withdraw_to_internal \
  --vc-timeout 120 \
  --verbose

# Check which VC timed out
# Look for: "VC #4: timeout after 120.1s"
```

**Follow:** `MSL_DEBUGGING_AND_TROUBLESHOOTING_GUIDE.md` §4 (Timeout Diagnosis).

---

#### Failure: "Z3 version mismatch"

**Error message:**
```
Expected Z3 version 4.11.2 but found 4.14.0
```

**Cause:** CI installed wrong Z3 version (likely from Homebrew instead of Movement CLI).

**Fix:**
```yaml
# In .github/workflows/move-prover-ca.yaml:
- name: Install prover dependencies
  run: |
    movement update prover-dependencies --assume-yes
    echo "Z3_EXE=$HOME/.local/bin/z3" >> $GITHUB_ENV
    echo "BOOGIE_EXE=$HOME/.local/bin/boogie" >> $GITHUB_ENV
    
- name: Verify Z3 version
  run: |
    $Z3_EXE --version
    $Z3_EXE --version | grep "4.11.2" || exit 1
```

---

#### Failure: "BV/Int mismatch"

**Error message:**
```
Type error in Boogie translation: expected bv64, got int
```

**Cause:** Spec function type mismatch (see `PHASE_0_RISTRETTO255_PATCH_NOTES.md`).

**Fix:**
```move
// In ristretto255.spec.move or confidential_balance.spec.move:
spec scalar_from_u64_internal(v: u64): Scalar {
    pragma opaque;  // Don't inline, avoid BV/int issues
    ensures result == spec_scalar_from_u64(int2bv(v));
}
```

---

### 3.3 Move Prover CI Debug Mode

**Enable verbose output:**
```yaml
- name: Run Move Prover (verbose)
  run: |
    movement move prove \
      --package-dir aptos-move/framework/aptos-experimental \
      --filter confidential_asset \
      --vc-timeout 120 \
      --verbose \
      --debug
```

**Test single function:**
```yaml
- name: Test single function
  run: |
    movement move prove \
      --package-dir aptos-move/framework/aptos-experimental \
      --filter confidential_asset::register_internal \
      --vc-timeout 120
```

---

## 4. Difftest CI Failures

### 4.1 Workflow Location

`.github/workflows/difftest-ca.yaml` (if exists) or integrated in `ca-verification-suite.yaml`.

**What it does:**
- Builds difftest Rust corpus
- Runs all CA difftest tests
- Validates output matches expected

### 4.2 Common Failures

#### Failure: "test_transfer_sender_frozen ... FAILED"

**Error message:**
```
assertion `left == right` failed
  left: Aborted(0x30003)
 right: Aborted(0x30002)
```

**Cause:** VM output changed (abort code mismatch).

**Diagnosis:**
```bash
# Run test locally
cargo test --package difftest test_transfer_sender_frozen -- --show-output

# Check what abort code VM actually returns
# Compare with expected (right-hand side)
```

**Fix (if VM output is correct):**
```rust
// In difftest/corpus/confidential_asset_e2e.rs:
#[test]
fn test_transfer_sender_frozen() {
    // ...
    assert_eq!(result, Aborted(0x30003));  // Was: 0x30002, updated
}
```

**Fix (if VM output is wrong):**
- This is a Move source bug → fix Move source, update MSL/Lean, then update difftest

**Cross-check:** Run `./scripts/reconcile_abort_codes.sh` to ensure all stacks agree.

---

#### Failure: "Rust compilation failed"

**Error message:**
```
error[E0425]: cannot find value `ESIGMA_PROTOCOL_VERIFY_FAILED` in this scope
```

**Cause:** Constant not exported from difftest bridge.

**Fix:**
```rust
// In difftest bridge file:
pub const ESIGMA_PROTOCOL_VERIFY_FAILED: u64 = 0x10001;
```

---

### 4.3 Difftest CI Debug Mode

**Run single test:**
```yaml
- name: Run single difftest
  run: cargo test --package difftest test_transfer_sender_frozen -- --show-output
```

**Run all CA tests with verbose output:**
```yaml
- name: Run all CA difftests
  run: cargo test --package difftest ca_ -- --show-output
```

---

## 5. Axiom Drift CI Failures

### 5.1 Workflow Location

`.github/workflows/axiom-diff-ca.yaml`

**What it does:**
- Runs `./scripts/check_axioms.sh`
- Diffs output against `audit/axiom-baseline.txt`
- Fails if new axiom detected

### 5.2 Common Failures

#### Failure: "Axiom count increased"

**Error message:**
```
New axiom detected: transfer_helper_lemma_unproved
Expected: 23 axioms
Found: 24 axioms
```

**Diagnosis:**
```bash
# Locally check which axiom was added
./scripts/check_axioms.sh > current-axioms.txt
diff audit/axiom-baseline.txt current-axioms.txt
```

**Fix Option 1: Eliminate axiom (preferred)**
```lean
-- In Transfer/EvalEquiv.lean:
-- Change:
axiom transfer_helper_lemma_unproved : ...

-- To:
theorem transfer_helper_lemma_unproved : ... := by
  -- Actual proof
  ...
```

**Fix Option 2: Approve as temporary axiom**
```lean
-- In Transfer/EvalEquiv.lean:
-- Add comment:
-- TEMPORARY AXIOM: will be eliminated in Phase 6 completion (issue #1234)
axiom transfer_helper_lemma_unproved : ...
```

Then update baseline:
```bash
./scripts/check_axioms.sh > audit/axiom-baseline.txt
git add audit/axiom-baseline.txt
git commit -m "axiom: approve temporary axiom for transfer (issue #1234)"
```

**Fix Option 3: New crypto axiom (requires security approval)**
- Document in `audit/AXIOM_INVENTORY.md`
- Get security team sign-off
- Update baseline

---

## 6. Performance CI Failures

### 6.1 Workflow Location

`.github/workflows/ca-verification-suite.yaml` (performance job)

**What it does:**
- Runs `./scripts/benchmark_verification.sh`
- Compares against previous baseline
- Fails if any operation >20% slower

### 6.2 Common Failures

#### Failure: "Transfer verification 45% slower than baseline"

**Error message:**
```
Performance regression detected:
  transfer: 7.2s (baseline: 4.9s, +47%)
  Threshold: +20%
```

**Diagnosis:**
```bash
# Run benchmark locally
./scripts/benchmark_verification.sh --output benchmark-local.json

# Compare with CI baseline
./scripts/compare_benchmarks.sh audit/performance-baseline.json benchmark-local.json

# Identify which stack slowed down (Lean, MSL, or difftest)
./scripts/benchmark_verification.sh --breakdown transfer
```

**Fix for Lean slowdown:**
```bash
# Profile the slow file
cd lean
time lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv --verbose

# Check heartbeat count (>10M is a red flag)
lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv --verbose 2>&1 | grep heartbeats

# Apply standard performance fixes (LEAN_PROOF_TACTICS_REFERENCE.md §10):
# - Add @[irreducible] to state constructors
# - Convert simp to simp only [...]
# - Factor out PC-range helpers

# Rebuild and verify fix
time lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv
# Should be back under budget
```

**Fix for MSL slowdown:**
```bash
# Add pragma opaque to expensive functions
# In confidential_asset.spec.move:
spec module {
    pragma opaque = verify_transfer_proof_internal;
}

# Or increase VC timeout if close to passing
# In .github/workflows/move-prover-ca.yaml:
# --vc-timeout 180  # Was 120
```

**Update baseline after fix:**
```bash
./scripts/benchmark_verification.sh --output audit/performance-baseline.json
git add audit/performance-baseline.json
git commit -m "perf: update baseline after transfer optimization"
```

---

## 7. Documentation CI Failures

### 7.1 Workflow Location

`.github/workflows/ca-verification-suite.yaml` (docs job)

**What it does:**
- Checks all internal links in `formal/*.md`
- Validates code examples compile
- Checks documentation coverage (all public functions documented)

### 7.2 Common Failures

#### Failure: "Broken link detected"

**Error message:**
```
Broken link in PHASE_6_PC_CHAINING_COMPLETE_GUIDE.md:
  Link: [Step Lemmas](lean/MovementFormal/MoveModel/StepLemmas/Basic.lean)
  Target does not exist
```

**Fix:**
```bash
# Check if file was moved
find lean -name "Basic.lean"

# Update link in doc
vim PHASE_6_PC_CHAINING_COMPLETE_GUIDE.md
# Fix: [Step Lemmas](lean/MovementFormal/MoveModel/StepLemmas/Basic.lean)
# To:   [Step Lemmas](lean/MovementFormal/MoveModel/StepLemmas.lean)  # If file was renamed
```

---

#### Failure: "Undocumented public function"

**Error message:**
```
Public function not documented in CLAIMS.md:
  Function: batch_transfer_internal
  File: confidential_asset.move:543
```

**Fix:**
```markdown
<!-- In audit/CLAIMS.md: -->
## Batch Transfer Internal

**Property:** Transfers balance between two accounts in batch.

**Stacks:** MSL, Difftest

**MSL:** `confidential_asset.spec.move:156`
  - Spec: `spec batch_transfer_internal { ensures ...; aborts_if ...; }`
  - Verify: `movement move prove --filter batch_transfer_internal`

**Difftest:** `difftest/corpus/confidential_asset_e2e.rs:test_batch_transfer`
```

---

## 8. Trust Boundaries CI Failures

### 8.1 Workflow Location

`.github/workflows/ca-verification-suite.yaml` (trust-boundaries job)

**What it does:**
- Runs `./scripts/reconcile_trust_boundaries.sh`
- Checks `audit/TRUST_BOUNDARIES.md` matches reality
- Validates axiom count, pragma opaque count, test-only pragmas

### 8.2 Common Failures

#### Failure: "Axiom count mismatch"

**Error message:**
```
TRUST_BOUNDARIES.md claims 23 axioms, but found 24
```

**Fix:**
```bash
# Regenerate axiom list
./scripts/check_axioms.sh > audit/axiom-list-current.txt

# Update TRUST_BOUNDARIES.md
vim audit/TRUST_BOUNDARIES.md
# Find section "Residual axioms in Lean" and update count
```

---

#### Failure: "Undocumented pragma opaque"

**Error message:**
```
Found pragma opaque not listed in TRUST_BOUNDARIES.md:
  Module: ristretto255
  Function: decompress_point_internal
  File: ristretto255.spec.move:42
```

**Fix:**
```markdown
<!-- In audit/TRUST_BOUNDARIES.md: -->
### Native-function assumptions

- **`ristretto255::decompress_point_internal`** (pragma opaque)
  - **Location:** `ristretto255.spec.move:42`
  - **Asserts:** Decompression is deterministic and matches VM native
  - **Why accept:** Ristretto255 RFC 9496 specifies decompression
  - **How to challenge:** Implement decompression in MSL (out of scope, crypto primitive)
```

---

## 9. Timeout Failures

### 9.1 CI Job Timeout

**Error message:**
```
Job exceeded maximum time limit (45 minutes)
```

**Cause:** One operation taking too long.

**Diagnosis:**
```bash
# Check which operation is slow
# Look at CI logs for:
#   "Building Registration... 12.3s"
#   "Building Transfer... 567.8s"  <-- This one!
```

**Immediate fix (disable slow operation):**
```yaml
# In .github/workflows/ca-verification-suite.yaml:
matrix:
  op: [register, withdraw, normalization, rotation]  # Removed 'transfer'
```

**Permanent fix:**
- Profile slow operation (§6)
- Apply performance optimizations
- Re-enable in CI once under budget

---

### 9.2 Individual VC Timeout (Move Prover)

**Already covered in §3.2.**

---

### 9.3 Lean Build Timeout

**Error message:**
```
lake build exceeded 10 minutes (job timeout)
```

**Cause:** Elaboration hanging on a proof.

**Diagnosis:**
```bash
# Rebuild locally with verbose output
lake build MovementFormal --verbose

# Look for which file is stuck (last "Building X" message before hang)
```

**Fix:**
- **Infinite loop in tactic:** Check for recursive `simp` or `rw` patterns
- **Elaboration explosion:** Add `@[irreducible]`, use `simp only`, avoid bound proofs in statements
- **Dependency cycle:** Check imports, break cycle

**Emergency fix (disable file):**
```lean
-- In problematic file:
-- #exit  -- Temporarily disable this file
```

---

## 10. Flaky Test Diagnosis

### 10.1 Identifying Flaky Tests

**Symptoms:**
- Test passes locally but fails in CI (or vice versa)
- Test fails intermittently (passes 80% of the time)
- Different results on different CI runners

**Diagnosis workflow:**

**Step 1: Run test 10 times locally**
```bash
for i in {1..10}; do
  cargo test test_transfer_sender_frozen || echo "FAILED on attempt $i"
done
```

**Step 2: Check for non-determinism**
- **Random inputs:** Are test inputs truly deterministic?
- **Timing-dependent:** Does test depend on timeouts, async behavior?
- **Environment-dependent:** Does test read env vars, check filesystem state?

**Step 3: Check CI vs local differences**
| Difference | Impact | Fix |
|------------|--------|-----|
| CPU count | Parallel test execution order | Disable test parallelism: `cargo test -- --test-threads=1` |
| OS (CI: Ubuntu, Local: macOS) | Platform-specific behavior | Use Docker locally to match CI |
| Timezone | Time-sensitive tests | Pin timezone: `TZ=UTC cargo test` |
| Mathlib cache | Cache corruption | Force re-download: `lake exe cache get --force` |

**Step 4: Add determinism guards**
```rust
// In difftest test:
#[test]
fn test_transfer_sender_frozen() {
    // Pin randomness
    let mut rng = StdRng::seed_from_u64(42);
    
    // Use deterministic inputs
    let proof = generate_proof_deterministic(sender, receiver, &mut rng);
    
    // ...
}
```

### 10.2 Flaky Lean Builds

**Symptom:** `lake build` sometimes fails with "typeclass instance expected".

**Cause:** Mathlib cache corruption or race condition.

**Fix:**
```bash
# Clean everything
lake clean
rm -rf build/ .lake/

# Re-download mathlib cache
lake exe cache get --force

# Rebuild
lake build MovementFormal
```

**CI fix (add cache validation):**
```yaml
- name: Validate mathlib cache
  run: |
    lake exe cache get
    lake build Mathlib  # Smoke-test mathlib before building CA
    lake build MovementFormal
```

---

## Appendix A: CI Job Dependency Graph

```
ca-verification-suite (workflow)
  ├─ lean-ca (job)
  │  ├─ Install Lean 4.24.0
  │  ├─ Download mathlib cache
  │  ├─ lake build MovementFormal
  │  └─ Check axiom count
  │
  ├─ move-prover-ca (job)
  │  ├─ Install Movement CLI
  │  ├─ Install Boogie/Z3/CVC5
  │  ├─ movement move prove
  │  └─ Validate VC count
  │
  ├─ difftest-ca (job)
  │  ├─ Install Rust
  │  ├─ cargo build --release
  │  └─ cargo test
  │
  ├─ axiom-diff-ca (job)
  │  ├─ Depends on: lean-ca
  │  ├─ ./scripts/check_axioms.sh
  │  └─ diff against baseline
  │
  ├─ performance-ca (job)
  │  ├─ Depends on: lean-ca, move-prover-ca, difftest-ca
  │  ├─ ./scripts/benchmark_verification.sh
  │  └─ compare against baseline
  │
  ├─ docs-ca (job)
  │  ├─ Check markdown links
  │  ├─ Validate code examples
  │  └─ Check documentation coverage
  │
  └─ trust-boundaries-ca (job)
     ├─ Depends on: lean-ca, move-prover-ca
     ├─ ./scripts/reconcile_trust_boundaries.sh
     └─ Validate TRUST_BOUNDARIES.md
```

---

## Appendix B: Emergency Contacts

| Issue Type | Contact | SLA |
|------------|---------|-----|
| Main branch red | Formal verification team lead | 1 hour |
| Security-critical failure | Security team + FV lead | Immediate |
| Lean toolchain breakage | Lean team (Zulip) | 24 hours |
| Move Prover breakage | Movement eng team | 4 hours |
| CI infrastructure | DevOps team | 2 hours |

---

## Appendix C: CI Configuration Files

**All CI workflows:**
```
.github/workflows/
  lean-ca.yaml                  — Lean verification
  move-prover-ca.yaml           — Move Prover verification
  axiom-diff-ca.yaml            — Axiom drift detection
  ca-verification-suite.yaml    — Full verification suite (all jobs)
```

**Scripts called by CI:**
```
scripts/
  check_axioms.sh               — Axiom count
  benchmark_verification.sh     — Performance tracking
  reconcile_abort_codes.sh      — Cross-stack consistency
  reconcile_trust_boundaries.sh — Trust boundary validation
  run_verification_suite.sh     — Full verification suite
```

**Audit artifacts:**
```
audit/
  axiom-baseline.txt            — Expected axiom list
  performance-baseline.json     — Performance baseline
  verify-ca.sh                  — Single-command reproducer
```

---

**END OF GUIDE**

**Maintenance:** Update this guide when new CI failure modes are discovered. Add real error messages from recent CI failures to make searching easier.

**Questions?** Check `VERIFICATION_MAINTENANCE_HANDBOOK.md` for ongoing maintenance or file issue in #formal-verification Slack channel.
