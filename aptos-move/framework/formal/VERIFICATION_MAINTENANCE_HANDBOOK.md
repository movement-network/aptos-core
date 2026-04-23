# Verification Maintenance Handbook

**Purpose:** Comprehensive guide for maintaining the Confidential Assets formal verification infrastructure as the codebase evolves.

**Audience:** Developers responsible for keeping verification in sync with Move source changes, security auditors, and formal verification team leads.

**Scope:** Covers all three verification stacks (Lean, MSL, Difftest) and their coordination.

---

## Table of Contents

1. [Overview: Verification Lifecycle](#1-overview-verification-lifecycle)
2. [When Move Source Changes](#2-when-move-source-changes)
3. [When Specifications Change](#3-when-specifications-change)
4. [When Proofs Break](#4-when-proofs-break)
5. [Axiom Management](#5-axiom-management)
6. [Performance Monitoring](#6-performance-monitoring)
7. [Cross-Stack Consistency](#7-cross-stack-consistency)
8. [Quarterly Audit Checklist](#8-quarterly-audit-checklist)
9. [Emergency Procedures](#9-emergency-procedures)
10. [Onboarding New Verifiers](#10-onboarding-new-verifiers)

---

## 1. Overview: Verification Lifecycle

### 1.1 The Three Stacks

Confidential Assets verification uses three independent proof systems:

| Stack | Covers | Artifacts | Maintenance Trigger |
|-------|--------|-----------|---------------------|
| **Lean** | Bytecode-level crypto verification (`verify_*_proof`) | `*.lean` files in `lean/MovementFormal/` | Native function changes, bytecode changes, oracle changes |
| **MSL** | Source-level state/invariants | `*.spec.move` files in `sources/` | Move source changes, spec strengthening |
| **Difftest** | VM↔Model fidelity | Rust test corpus in `difftest/` | Any of the above, new operations |

**Key principle:** All three must stay synchronized. A change in one stack often requires updates in the others.

### 1.2 Maintenance Cadence

**Daily:** CI monitors all three stacks — any red build is a blocker.

**Weekly:** Review axiom count (`scripts/check_axioms.sh`), performance metrics (`scripts/benchmark_verification.sh`).

**Quarterly:** Full verification audit (§8), axiom reduction review (§5), cross-stack reconciliation (§7).

**Per-release:** Lock verification state, update audit package, publish Docker image.

---

## 2. When Move Source Changes

### 2.1 Change Impact Matrix

| Move Change Type | Lean Impact | MSL Impact | Difftest Impact |
|------------------|-------------|------------|-----------------|
| Pure refactor (no bytecode change) | ❌ None | ✅ Likely (spec points to source names) | ❌ None |
| Add new function (no crypto) | ❌ None | ✅ New spec block | ✅ New test cases |
| Modify crypto function | ✅ Bytecode proof update | ✅ Spec update | ✅ Update test vectors |
| Change abort code | ✅ Update expected code | ✅ Update `aborts_with` | ✅ Update expected output |
| Add new operation | ✅ New EvalEquiv file | ✅ New spec module | ✅ New test corpus |
| Optimize bytecode (semantics unchanged) | ✅ PC-chaining update | ❌ None if source spec unchanged | ❌ None if I/O unchanged |

### 2.2 Step-by-Step: Move Source Changed

**Step 1: Identify what changed**
```bash
git diff movement..HEAD -- aptos-move/framework/aptos-experimental/sources/confidential_asset/
```

**Step 2: Determine scope**
- **Refactor only:** Update MSL specs (§2.3), skip Lean unless bytecode changed
- **Crypto function changed:** Full update (§2.4)
- **New operation added:** Onboarding workflow (§10)

**Step 3: Update MSL specs first**

Move Prover is fastest to iterate, so update MSL specs before Lean proofs.

```bash
# Edit the spec file
vim aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_asset.spec.move

# Run Move Prover on the affected module
movement move prove \
  --package-dir aptos-move/framework/aptos-experimental \
  --filter confidential_asset \
  --vc-timeout 120

# If VCs fail, iterate on spec (§3.2)
```

**Step 4: Update Lean proofs if bytecode changed**

Check if bytecode changed:
```bash
# Compile Move to bytecode
movement move build --package-dir aptos-move/framework/aptos-experimental

# Compare bytecode (no easy diff tool yet — manual inspection)
# Look for PC count changes, instruction order changes
```

If bytecode changed, update affected `EvalEquiv.lean` files (§4).

**Step 5: Update difftest corpus**

```bash
# Run existing tests to see what broke
./difftest/run_ca_tests.sh

# Update test vectors if needed (§2.5)
vim difftest/corpus/confidential_asset_e2e.rs

# Re-run to confirm
./difftest/run_ca_tests.sh
```

**Step 6: Update cross-stack consistency**

```bash
# Check abort codes match across stacks
./scripts/reconcile_abort_codes.sh

# Check state transitions match
./scripts/check_state_transition_consistency.sh
```

**Step 7: Update documentation**

- `audit/CLAIMS.md` — if properties changed
- `audit/MSL_SPEC_COVERAGE.md` — if spec coverage changed
- `audit/BYTECODE_VERIFICATION_COVERAGE.md` — if Lean proofs changed

**Step 8: Run full verification suite**

```bash
./scripts/run_verification_suite.sh --mode standard
```

### 2.3 Example: Refactor with No Bytecode Change

**Scenario:** Rename `normalize_internal` to `normalize_balance_internal` (pure refactor).

**Changes needed:**
1. **MSL:** Update spec block name
   ```move
   spec normalize_balance_internal {  // Was: normalize_internal
       ensures ...
   }
   ```

2. **Lean:** No changes (bytecode identifier didn't change)

3. **Difftest:** No changes (external I/O unchanged)

4. **Documentation:** Update `CLAIMS.md` to reflect new name

### 2.4 Example: Modify Crypto Function (Full Update)

**Scenario:** `verify_transfer_proof` bytecode changed (extra validation step added).

**Changes needed:**
1. **Lean:** Update `Transfer/EvalEquiv.lean`
   - Add new PC step theorem
   - Update PC count in `eval_transfer_eq_run`
   - Adjust PC-chaining in `transfer_eval_equiv_functional_sim`
   - Rebuild and verify axiom count unchanged

2. **MSL:** Update spec for `confidential_transfer_internal`
   ```move
   spec confidential_transfer_internal {
       aborts_if !verify_transfer_proof(...);  // May need strengthening
       ensures ...
   }
   ```

3. **Difftest:** Update test vectors
   - Rerun VM to get new output
   - Update expected results in corpus

4. **Verification:** Run `./audit/verify-ca.sh --op transfer` until green

### 2.5 Updating Difftest Corpus

**When to update:**
- Move source changed and VM output changed
- New edge case discovered
- Coverage gap identified

**Workflow:**
```bash
# 1. Identify what test failed
./difftest/run_ca_tests.sh
# Example output: test_transfer_sender_frozen FAILED

# 2. Capture new VM output
movement move test --package-dir aptos-move/framework/aptos-experimental --filter transfer_sender_frozen

# 3. Update test corpus
vim difftest/corpus/confidential_asset_e2e.rs
# Update expected output in test_transfer_sender_frozen

# 4. Re-run to confirm
./difftest/run_ca_tests.sh test_transfer_sender_frozen
```

**Golden rule:** Never update expected output without understanding WHY it changed. VM output change might be a regression, not a valid update.

---

## 3. When Specifications Change

### 3.1 Spec Strengthening

**Scenario:** Security audit reveals missing invariant, need to strengthen MSL spec.

**Example:** Audit finds balance length should be preserved across `withdraw_to_internal`.

**Workflow:**

**Step 1:** Add new `ensures` clause to MSL spec
```move
spec withdraw_to_internal {
    ensures len(result.pending_balance) == len(old(store.pending_balance));
    ensures len(result.actual_balance) == len(old(store.actual_balance));
}
```

**Step 2:** Run Move Prover to check if it verifies
```bash
movement move prove --package-dir aptos-move/framework/aptos-experimental \
  --filter confidential_asset::withdraw_to_internal
```

**Step 3a:** If it verifies, done. Update `MSL_SPEC_COVERAGE.md`.

**Step 3b:** If it fails, investigate why:
- **True bug:** Fix Move source, repeat workflow from §2
- **False alarm:** Spec too strong, need weakening or `pragma`
- **Prover limitation:** Add helper spec function or `pragma opaque`

**Step 4:** Document the new property in `audit/CLAIMS.md`

### 3.2 MSL Verification Failures

**Common failure modes:**

#### Failure: "VC timeout"

**Diagnosis:** Z3 couldn't prove the property in 120 seconds.

**Fixes (in order of preference):**
1. **Increase timeout** (if close to succeeding):
   ```bash
   movement move prove --vc-timeout 300 ...
   ```

2. **Add `pragma opaque`** to expensive functions:
   ```move
   spec module {
       pragma opaque = verify_proof_internal;  // Don't inline this
   }
   ```

3. **Break down spec** into smaller pieces:
   ```move
   spec withdraw_to_internal {
       ensures balance_preserved(...);  // Was: large inline expression
   }
   
   spec fun balance_preserved(...): bool {
       ...  // Factor out complex logic
   }
   ```

4. **Switch solver** (Z3 vs CVC5):
   ```bash
   movement move prove --cvc5 ...
   ```

#### Failure: "Unsat core" (false alarm)

**Diagnosis:** Move Prover thinks property is violated but it's not.

**Fixes:**
1. **Add preconditions** to narrow the verification scope:
   ```move
   spec withdraw_to_internal {
       requires store.balance_length > 0;  // Was missing
       ensures ...
   }
   ```

2. **Add invariants** to rule out impossible states:
   ```move
   spec ConfidentialAssetStore {
       invariant len(pending_balance) == len(actual_balance);
   }
   ```

3. **Deactivate specific invariants** if they conflict:
   ```move
   spec withdraw_to_internal {
       pragma deactivated_invariants = ConfidentialAssetStore::length_invariant;
   }
   ```

#### Failure: "BV/Int mismatch"

**Diagnosis:** Boogie translation expects `bv64` but got `int` (or vice versa).

**Fixes:**
1. **Use spec functions with correct types:**
   ```move
   spec fun spec_scalar_from_u64(v: u64): Scalar {
       pragma opaque;
       ensures result == ...;  // Don't inline, avoid BV/int issues
   }
   ```

2. **Module-level pragma:**
   ```move
   spec module {
       pragma bv_implementation = false;  // Use int representation
   }
   ```

See `MSL_DEBUGGING_AND_TROUBLESHOOTING_GUIDE.md` for full diagnosis flowchart.

---

## 4. When Proofs Break

### 4.1 Lean Build Failures

**Common causes:**

#### Cause 1: PC count mismatch

**Error:**
```
type mismatch at step_pc42
  expected: step env (state 42) = state 43
  got:      step env (state 42) = .error
```

**Diagnosis:** Bytecode changed, PC 42 no longer exists or has different instruction.

**Fix:** Re-transcribe bytecode, update PC count, rebuild step theorems.

**Workflow:**
```bash
# 1. Dump new bytecode
movement move build --package-dir aptos-move/framework/aptos-experimental
movement move disassemble --bytecode-path <path-to-compiled-module>

# 2. Compare with Lean transcription
diff <disassembly> lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/Bytecode.lean

# 3. Update Lean bytecode transcription
vim lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/Bytecode.lean

# 4. Rebuild step theorems
vim lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean
# Update PC count, adjust step chains

# 5. Rebuild
lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv
```

#### Cause 2: Oracle result changed

**Error:**
```
type mismatch at transfer_eval_equiv_functional_sim
  oracle type changed
```

**Diagnosis:** Native function signature changed, oracle type no longer matches.

**Fix:** Update oracle type in `Native/*.lean`, update functional sim, rebuild proofs.

#### Cause 3: Axiom used unexpectedly

**Error:**
```
#print axioms shows new axiom: my_helper_lemma
```

**Diagnosis:** A lemma was marked `axiom` instead of proved, or imported a file with axioms.

**Fix:** 
1. Find which theorem introduced the axiom:
   ```bash
   grep -r "axiom my_helper_lemma" lean/
   ```

2. Prove it instead of axiomatizing:
   ```lean
   theorem my_helper_lemma : ... := by
     -- Actual proof instead of axiom
   ```

3. Verify axiom count:
   ```bash
   ./scripts/check_axioms.sh
   diff audit/axiom-baseline.txt <(./scripts/check_axioms.sh --output)
   ```

### 4.2 Build Time Regressions

**Symptom:** `lake build` takes >3 min for a single file (was <1 min).

**Diagnosis workflow:**

**Step 1:** Identify slow file
```bash
lake build --verbose 2>&1 | grep "Building" | sort -k3 -n
# Look for files taking >180s
```

**Step 2:** Check for common performance issues
- [ ] Bare `simp` instead of `simp only [...]`
- [ ] Missing `@[irreducible]` on state constructors
- [ ] Bound proofs in theorem statements (§10.3 of LEAN_PROOF_TACTICS_REFERENCE.md)
- [ ] Repeated unfolding of large definitions

**Step 3:** Profile the file
```bash
lake build MovementFormal.Experimental.ConfidentialAsset.OPERATION.EvalEquiv --verbose
# Check heartbeat count — >10M heartbeats is a red flag
```

**Step 4:** Apply standard fixes
1. Convert `simp` to `simp only [explicit, lemma, list]`
2. Add `@[irreducible]` to all state constructors
3. Factor out PC-range helpers (§4.3 of PHASE_6_PC_CHAINING_COMPLETE_GUIDE.md)
4. Check theorem statements don't contain array access with `!` (use `get?` instead)

**Step 5:** Verify fix
```bash
lake clean
lake build MovementFormal.Experimental.ConfidentialAsset.OPERATION.EvalEquiv
# Should be <180s
```

If still slow, escalate to Lean Zulip for profiling help.

---

## 5. Axiom Management

### 5.1 Axiom Baseline

**Current baseline:** 23 axioms (21 permanent + 2 temporary)

**Location:** `audit/axiom-baseline.txt`

**How to regenerate:**
```bash
./scripts/check_axioms.sh > audit/axiom-baseline.txt
```

### 5.2 Axiom Drift Detection

**CI job:** `.github/workflows/axiom-diff-ca.yaml` runs on every PR.

**Failure:** PR introduced a new axiom.

**Workflow when CI fails:**

**Step 1:** Identify what axiom was added
```bash
./scripts/check_axioms.sh > current-axioms.txt
diff audit/axiom-baseline.txt current-axioms.txt
```

**Step 2:** Determine if it's acceptable
- **Temporary axiom:** Expected if a new operation was added in-progress (Phase 1 pattern)
- **Helper axiom:** Should be eliminated — factor into main proof instead
- **Crypto axiom:** Acceptable ONLY for new crypto primitives (requires security team approval)

**Step 3a:** If temporary, document and approve
```bash
# Add comment to axiom
# In the .lean file:
-- TEMPORARY AXIOM: will be eliminated in Phase 6 completion (issue #1234)
axiom transfer_eval_equiv_functional_sim : ...

# Update baseline
./scripts/check_axioms.sh > audit/axiom-baseline.txt
git add audit/axiom-baseline.txt
```

**Step 3b:** If not acceptable, eliminate it
```bash
# Replace axiom with proof
# In the .lean file:
theorem my_helper_lemma : ... := by
  -- Actual proof
  ...

# Verify axiom count returned to baseline
./scripts/check_axioms.sh > current.txt
diff audit/axiom-baseline.txt current.txt
# Should show no diff (or only expected temporary axiom from Step 3a)
```

### 5.3 Quarterly Axiom Review

**When:** Every quarter (Q1, Q2, Q3, Q4 end).

**Checklist:**

- [ ] Run `./scripts/check_axioms.sh --verbose` (lists all axioms with source files)
- [ ] For each axiom in `audit/AXIOM_INVENTORY.md`:
  - [ ] Still needed? (Can it be eliminated now?)
  - [ ] Correctly classified? (A: Irreducible, B: Defer, C: Eliminate, D: Eliminated)
  - [ ] Documentation accurate? (Citation, justification, elimination plan)
- [ ] Temporary axioms: are any >6 months old? (Red flag — should have been eliminated)
- [ ] New axioms since last review: approved by security team?
- [ ] Update `AXIOM_REDUCTION_IMPLEMENTATION_STRATEGY.md` with new elimination plans

**Deliverable:** Updated `AXIOM_INVENTORY.md` with any status changes, new elimination timelines.

---

## 6. Performance Monitoring

### 6.1 Build Time Budgets

**Per-file budgets:**
- Lean EvalEquiv files: ≤ 180s each
- Lean full tree: ≤ 600s cold build
- MSL per-operation: ≤ 60s (Move Prover)
- Difftest per-test: ≤ 5s

**CI budget:** ≤ 13 min total (6 jobs in parallel)

### 6.2 Weekly Performance Check

**Every Monday:**
```bash
# Run benchmark suite
./scripts/benchmark_verification.sh --output benchmark-$(date +%Y%m%d).json

# Compare to last week
./scripts/compare_benchmarks.sh benchmark-$(date -d '7 days ago' +%Y%m%d).json benchmark-$(date +%Y%m%d).json

# Alert if any operation >20% slower
```

**If regression detected:**
1. Bisect to find which commit introduced slowdown
2. Profile that commit (§6.3)
3. Apply performance fixes (§4.2)
4. Verify fix restored performance

### 6.3 Profiling Commands

**Lean:**
```bash
# Detailed heartbeat count per declaration
lake build MovementFormal.Experimental.ConfidentialAsset.OPERATION.EvalEquiv --verbose 2>&1 | grep heartbeats

# Total build time
time lake build MovementFormal.Experimental.ConfidentialAsset.OPERATION.EvalEquiv
```

**Move Prover:**
```bash
# Per-VC timing
movement move prove --package-dir aptos-move/framework/aptos-experimental \
  --filter OPERATION \
  --vc-timeout 120 \
  --verbose

# Total verification time
time movement move prove --package-dir aptos-move/framework/aptos-experimental --filter confidential_asset
```

**Difftest:**
```bash
# Per-test timing
cargo test --package difftest --release -- --show-output test_ca_transfer

# Full corpus timing
time ./difftest/run_ca_tests.sh
```

---

## 7. Cross-Stack Consistency

### 7.1 Consistency Checks

**Abort codes:** Must match exactly across all three stacks.

**Check:**
```bash
./scripts/reconcile_abort_codes.sh
```

**Failure:** Mismatch detected.

**Fix:**
1. Identify which stack is authoritative (usually Move source)
2. Update other stacks to match:
   - **Lean:** Update expected abort code in theorems
   - **MSL:** Update `aborts_with` clauses
   - **Difftest:** Update expected output in test corpus

**State transitions:** Operation input → output mapping must be consistent.

**Check:**
```bash
./scripts/check_state_transition_consistency.sh
```

**Failure:** Divergence detected (e.g., Lean says transfer succeeds, MSL says it aborts).

**Fix:**
1. Identify root cause (usually a spec/proof mismatch)
2. Run operation end-to-end in all three stacks
3. Compare outputs, fix divergence
4. Re-run consistency check until green

### 7.2 Adding New Properties

**Workflow:** New property should be covered by ALL applicable stacks.

**Example:** Add "freeze prevents withdrawal" property.

**Step 1: Decide which stacks cover it**
- **Lean:** No (not crypto, state-level property)
- **MSL:** Yes (state property)
- **Difftest:** Yes (end-to-end behavior)

**Step 2: Add to MSL**
```move
spec withdraw_to_internal {
    aborts_if store.frozen with ESTORE_FROZEN;
}
```

**Step 3: Add difftest test case**
```rust
#[test]
fn test_withdraw_from_frozen_store() {
    // Setup: frozen store
    // Execute: attempt withdrawal
    // Assert: aborts with ESTORE_FROZEN
}
```

**Step 4: Update documentation**

Add to `audit/CLAIMS.md`:
```markdown
## Freeze prevents withdrawal

**Property:** Attempting to withdraw from a frozen store aborts with `ESTORE_FROZEN`.

**Stacks:** MSL, Difftest

**MSL:** `aptos-experimental/sources/confidential_asset/confidential_asset.spec.move:123`
  - Spec: `spec withdraw_to_internal { aborts_if store.frozen with 0x30003; }`
  - Verify: `movement move prove --filter withdraw_to_internal`

**Difftest:** `difftest/corpus/confidential_asset_e2e.rs:test_withdraw_from_frozen_store`
  - Test: Frozen store → withdrawal → abort 0x30003
  - Run: `cargo test test_withdraw_from_frozen_store`
```

**Step 5: Run cross-stack consistency check**
```bash
./scripts/check_property_coverage.sh "freeze prevents withdrawal"
```

---

## 8. Quarterly Audit Checklist

**When:** End of each quarter (March 31, June 30, September 30, December 31).

**Owner:** Formal verification team lead.

**Deliverable:** Audit report with pass/fail on each item, filed as quarterly-audit-YYYY-QN.md.

### 8.1 Verification Health

- [ ] All three stacks green on CI for last 30 days
- [ ] No temporary axioms older than 6 months
- [ ] No `sorry` in any Lean file
- [ ] No `pragma verify = false` in MSL (unless explicitly documented why)
- [ ] Performance within budget (§6.1) for all operations

### 8.2 Coverage

- [ ] All public CA functions have MSL specs
- [ ] All crypto functions have Lean bytecode proofs
- [ ] Difftest corpus ≥95% coverage (check `DIFFTEST_CORPUS_EXPANSION_GUIDE.md`)
- [ ] `audit/CLAIMS.md` has entry for every public function

### 8.3 Trust Boundaries

- [ ] `audit/TRUST_BOUNDARIES.md` reconciled (run `./scripts/reconcile_trust_boundaries.sh`)
- [ ] `audit/AXIOM_INVENTORY.md` reconciled (run `./scripts/check_axioms.sh`)
- [ ] No new `pragma opaque` without justification
- [ ] Crypto axiom citations still valid (papers/audits not retracted)

### 8.4 Reproducibility

- [ ] `./audit/verify-ca.sh` runs green from fresh clone
- [ ] Docker image builds and runs verification suite
- [ ] `audit/toolchain.lock` matches current CI
- [ ] `audit/AUDITOR_GUIDE.md` instructions still accurate (test with new team member)

### 8.5 Documentation

- [ ] `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §0 progress tracker up to date
- [ ] All guides in `formal/` directory reviewed for accuracy
- [ ] Broken links fixed (run link checker)
- [ ] Examples in guides still build (spot-check 3 examples)

### 8.6 Axiom Reduction

- [ ] Quarterly axiom review complete (§5.3)
- [ ] Elimination plans for all Class C axioms have target dates
- [ ] At least 1 axiom eliminated this quarter (unless already at permanent baseline)

---

## 9. Emergency Procedures

### 9.1 Critical Bug Found in Production

**Scenario:** Security bug found in deployed CA code, need to verify fix doesn't break verification.

**Workflow:**

**Step 1: Triage (within 1 hour)**
- Which operation is affected?
- Does it impact crypto (Lean) or state (MSL)?
- Is there a proposed fix?

**Step 2: Verify fix locally (within 4 hours)**
```bash
# Apply fix to Move source
git checkout -b hotfix/ca-bug-NNNN

# Update MSL specs if needed
vim aptos-move/framework/aptos-experimental/sources/confidential_asset/*.spec.move

# Run Move Prover
movement move prove --package-dir aptos-move/framework/aptos-experimental --filter confidential_asset

# Update Lean proofs if bytecode changed
vim lean/MovementFormal/Experimental/ConfidentialAsset/*/EvalEquiv.lean
lake build MovementFormal

# Update difftest
vim difftest/corpus/confidential_asset_e2e.rs
cargo test

# Run full verification suite
./scripts/run_verification_suite.sh --mode comprehensive
```

**Step 3: Fast-track PR (within 8 hours)**
- Create PR with `[SECURITY]` prefix
- Tag formal verification team + security team
- Include verification evidence (CI green screenshot, local `verify-ca.sh` output)

**Step 4: Post-incident review (within 1 week)**
- Why didn't verification catch this?
- What spec/proof needs strengthening?
- Update `LESSONS_LEARNED.md`

### 9.2 CI Completely Red (All Three Stacks Failing)

**Scenario:** Upstream dependency changed, everything broke.

**Likely causes:**
1. Lean toolchain update (mathlib incompatibility)
2. Movement CLI update (Move Prover breaking change)
3. Rust toolchain update (difftest breakage)

**Workflow:**

**Step 1: Identify what updated**
```bash
git log --all --oneline --graph -- lean-toolchain rust-toolchain movement.toml
```

**Step 2: Rollback to last-known-good**
```bash
git checkout <last-green-commit> -- lean-toolchain rust-toolchain movement.toml
git commit -m "Rollback toolchains to last-known-good"
git push
```

**Step 3: CI should go green (if not, broader issue — escalate)**

**Step 4: Isolate the breaking update**
```bash
# Test Lean toolchain update in isolation
git checkout -b test-lean-update
git checkout <breaking-commit> -- lean-toolchain
lake clean
lake build MovementFormal
# If fails, file issue with Lean team
```

**Step 5: File upstream issue or apply workaround, then update pinned versions**

### 9.3 Verification Takes Too Long (>1 Hour)

**Scenario:** `verify-ca.sh` times out in CI (exceeded 45 min budget).

**Immediate fix (within 1 hour):**
```bash
# Identify slowest operation
./scripts/benchmark_verification.sh

# Disable slow operation temporarily
# In .github/workflows/ca-verification-suite.yaml:
# Comment out the slow operation from the matrix
# - op: transfer  # Temporarily disabled: performance regression

git commit -m "CI: disable transfer verification pending perf fix"
git push
```

**Permanent fix (within 1 day):**
1. Profile slow operation (§6.3)
2. Apply performance fixes (§4.2)
3. Verify fix brings build time under budget
4. Re-enable in CI

---

## 10. Onboarding New Verifiers

### 10.1 Adding a New Operation

**Scenario:** New CA operation added (e.g., `batch_transfer`), need to verify it.

**Workflow:**

**Step 1: Update master plan**
```bash
vim CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md
# Add row to §3 tool assignment table
# Decide: which stacks cover this operation?
```

**Step 2: Add MSL spec (if state/resource property)**
```bash
vim aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_asset.spec.move

# Add spec block
spec batch_transfer_internal {
    requires ...;
    ensures ...;
    aborts_if ...;
}

# Verify
movement move prove --filter batch_transfer_internal
```

**Step 3: Add Lean proof (if crypto property)**
```bash
# Create new directory
mkdir -p lean/MovementFormal/Experimental/ConfidentialAsset/BatchTransfer

# Create files
touch lean/MovementFormal/Experimental/ConfidentialAsset/BatchTransfer/{Bytecode,FunctionalSim,EvalEquiv,Phase6Composition}.lean

# Follow Phase 4 pattern from existing operations
# Reference: PHASE_6_PC_CHAINING_COMPLETE_GUIDE.md

# Build
lake build MovementFormal.Experimental.ConfidentialAsset.BatchTransfer.EvalEquiv
```

**Step 4: Add difftest coverage**
```bash
# Add test cases
vim difftest/corpus/confidential_asset_e2e.rs

#[test]
fn test_batch_transfer_happy_path() {
    // Setup, execute, assert
}

#[test]
fn test_batch_transfer_frozen() {
    // Error case
}

# Run
cargo test test_batch_transfer
```

**Step 5: Update audit package**
```bash
# Add claims
vim audit/CLAIMS.md
## Batch Transfer

**Property:** ...
**Stacks:** Lean, MSL, Difftest
**Lean:** `...`
**MSL:** `...`
**Difftest:** `...`

# Update coverage docs
vim audit/MSL_SPEC_COVERAGE.md
vim audit/BYTECODE_VERIFICATION_COVERAGE.md

# Update verify-ca.sh
vim audit/verify-ca.sh
# Add batch_transfer to operation list
```

**Step 6: CI integration**
```bash
# Update workflow
vim .github/workflows/ca-verification-suite.yaml
# Add batch_transfer to operation matrix

# Verify CI green
git push
# Watch CI run
```

### 10.2 Onboarding a New Team Member

**Day 1: Local setup**
- [ ] Clone repo
- [ ] Install Lean (follow `lean/README.md`)
- [ ] Install Movement CLI (follow §5.1 of CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md)
- [ ] Install Rust/cargo (for difftest)
- [ ] Run `./audit/verify-ca.sh --op register` to smoke-test (should complete in ~3 min)

**Week 1: Read documentation**
- [ ] `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` (master plan)
- [ ] `audit/CLAIMS.md` (what's verified)
- [ ] `audit/TRUST_BOUNDARIES.md` (what's assumed)
- [ ] `LEAN_PROOF_TACTICS_REFERENCE.md` (Lean tactics)

**Week 2: Small contribution**
- [ ] Pick a simple task: strengthen an MSL spec, add a difftest test case
- [ ] Submit PR, get code review
- [ ] Fix any verification breakage

**Month 1: Independent operation**
- [ ] Assigned one operation end-to-end (e.g., Normalization)
- [ ] Update Lean proof, MSL spec, difftest
- [ ] Run `verify-ca.sh` and confirm green
- [ ] Can debug common verification failures independently

---

## Appendix A: File Organization

**Lean proofs:**
```
lean/MovementFormal/
  Experimental/
    ConfidentialAsset/
      Registration/
        Bytecode.lean           — Bytecode transcription
        FunctionalSim.lean      — High-level functional model
        EvalEquiv.lean          — Bytecode ↔ functional equivalence
        Phase6Composition.lean  — End-to-end composition theorem
      Withdrawal/
        ...
      Transfer/
        ...
      Normalization/
        ...
      Rotation/
        ...
```

**MSL specs:**
```
aptos-move/framework/aptos-experimental/sources/confidential_asset/
  confidential_asset.move        — Move source
  confidential_asset.spec.move   — MSL specs (entry points)
  confidential_balance.spec.move — MSL specs (balance arithmetic)
  confidential_proof.spec.move   — MSL specs (crypto opaque boundary)
  ristretto255_twisted_elgamal.spec.move
```

**Difftest:**
```
difftest/
  corpus/
    confidential_asset_e2e.rs    — Rust test corpus
  run_ca_tests.sh                — Test runner
```

**Audit package:**
```
audit/
  CLAIMS.md                      — What's verified
  TRUST_BOUNDARIES.md            — What's assumed
  AXIOM_INVENTORY.md             — Axiom catalog
  verify-ca.sh                   — Single-command reproducer
  toolchain.lock                 — Pinned tool versions
```

**Maintenance scripts:**
```
scripts/
  check_axioms.sh                — Axiom drift detection
  benchmark_verification.sh      — Performance tracking
  reconcile_abort_codes.sh       — Cross-stack consistency
  run_verification_suite.sh      — Full verification suite
```

---

## Appendix B: Common Error Messages

| Error | Stack | Likely Cause | Fix |
|-------|-------|--------------|-----|
| "PC count mismatch" | Lean | Bytecode changed | Re-transcribe bytecode, update PC theorems |
| "VC timeout" | MSL | Spec too complex | Add `pragma opaque`, increase timeout |
| "BV/Int mismatch" | MSL | Type coercion issue | Use spec functions, avoid direct coercion |
| "Axiom count increased" | Lean | New axiom introduced | Eliminate axiom or document as temporary |
| "Build time >180s" | Lean | Performance regression | Add `@[irreducible]`, factor out helpers |
| "Test output mismatch" | Difftest | VM behavior changed | Update expected output (after confirming not a regression) |
| "Abort code mismatch" | All | Inconsistency across stacks | Run `reconcile_abort_codes.sh`, fix divergence |

---

## Appendix C: Quick Reference Commands

**Check verification status:**
```bash
./audit/verify-ca.sh                           # Full verification (~45 min)
./audit/verify-ca.sh --op transfer             # Single operation (~3 min)
./audit/verify-ca.sh --op transfer --stack lean  # Single stack (~1 min)
```

**Performance:**
```bash
./scripts/benchmark_verification.sh            # Benchmark all operations
./scripts/profile_verification_performance.sh  # Detailed profiling
```

**Consistency:**
```bash
./scripts/reconcile_abort_codes.sh             # Check abort code consistency
./scripts/check_state_transition_consistency.sh # Check state transition consistency
./scripts/reconcile_trust_boundaries.sh        # Check trust boundaries
```

**Axioms:**
```bash
./scripts/check_axioms.sh                      # List all axioms
./scripts/check_axioms.sh > audit/axiom-baseline.txt  # Regenerate baseline
```

**Testing:**
```bash
./scripts/run_verification_suite.sh --mode quick         # Quick (~2 min)
./scripts/run_verification_suite.sh --mode standard      # Standard (~5 min)
./scripts/run_verification_suite.sh --mode comprehensive # Full (~15 min)
```

---

**END OF HANDBOOK**

**Maintenance cadence:** Review this handbook quarterly, update with new patterns/issues discovered.

**Questions?** Escalate to formal verification team lead or file issue in #formal-verification Slack channel.
