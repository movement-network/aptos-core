# Integration Testing Strategy for CA Formal Verification

**Purpose:** Complete guide to integration testing across the three verification stacks (Lean, Move Prover, Difftest), ensuring consistency and catching cross-stack regressions.

**Audience:** Developers adding new CA operations or modifying existing verification infrastructure.

---

## Table of Contents

1. [Testing Philosophy](#1-testing-philosophy)
2. [Three-Stack Integration Points](#2-three-stack-integration-points)
3. [Test Matrix](#3-test-matrix)
4. [Workflow: Adding a New Operation](#4-workflow-adding-a-new-operation)
5. [Workflow: Modifying Existing Verification](#5-workflow-modifying-existing-verification)
6. [Regression Detection](#6-regression-detection)
7. [Continuous Integration](#7-continuous-integration)
8. [Local Testing Checklist](#8-local-testing-checklist)
9. [Debugging Cross-Stack Failures](#9-debugging-cross-stack-failures)
10. [Performance Benchmarking](#10-performance-benchmarking)

---

## 1. Testing Philosophy

### 1.1 Three Independent Verifiers

**Core principle:** Lean, Move Prover, and Difftest are **independent proof checkers** that must agree on the same properties.

- **Lean** proves bytecode-level theorems (crypto layer, PC-level correctness)
- **Move Prover** proves source-level MSL specs (state layer, resource invariants)
- **Difftest** binds both to the VM (concrete input/output consistency)

**Disagreement is a bug** — if Lean proves a property but difftest fails on a concrete input, either:
1. The Lean proof has an unsound axiom
2. The Lean model doesn't match the VM
3. The difftest test case is wrong

Integration testing catches these mismatches.

---

### 1.2 Falsification vs Verification

**Verification (Lean + Move Prover):** Proves ∀ inputs, property holds.

**Falsification (Difftest):** Checks ∃ input where property fails.

**Integration strategy:**
- Use Lean/MSL to prove the universal claim
- Use difftest to **falsify** violations (find counterexamples to incorrect specs)
- A passing difftest suite doesn't prove correctness, but a **failing** difftest is a definitive bug signal

**Example:**
- MSL spec says: `ensures sum_balance(store) == sum_balance(old(store))`
- Difftest finds: input where sum changes (bug in implementation or spec)
- Lean proves: `eval ... = functional_sim ...` (bytecode correctness)
- Difftest validates: Lean model matches VM on 17 concrete inputs

---

## 2. Three-Stack Integration Points

### 2.1 Lean ↔ VM (via Difftest)

**Integration point:** `BytecodeDifftestBridge.lean`

**What's tested:**
- For a given input, `eval (registrationModuleEnv o) funcIdx args cs ms` in Lean produces the same result as the VM execution

**Test mechanism:**
1. Difftest runner executes a Move transaction in the VM
2. Captures the result (success, abort code, or error)
3. Feeds the same inputs to the Lean `eval` function
4. Compares outputs byte-for-byte

**Example test case:**
```json
{
  "test_id": "register_happy_path_001",
  "inputs": { "owner_addr": "0x123...", "pubkey": "0x456...", ... },
  "expected_vm_result": { "status": "success", "events": [...] },
  "expected_lean_result": { "eval_result": "returned", "num_steps": 97 }
}
```

**Failure modes:**
- **VM succeeds, Lean aborts** — Lean model too strict (missing case)
- **VM aborts, Lean succeeds** — Lean model too permissive (missing abort check)
- **Both succeed, different outputs** — Semantic mismatch (e.g., different balance values)

---

### 2.2 Move Prover ↔ VM (via Difftest)

**Integration point:** MSL spec abort codes match VM abort codes.

**What's tested:**
- If MSL spec says `aborts_if store.frozen with ETOKEN_IS_FROZEN`, then running the VM with a frozen store should produce abort code `196612` (ETOKEN_IS_FROZEN)

**Test mechanism:**
1. Difftest corpus includes "expected abort" test cases
2. VM executes, produces abort code
3. Compare to MSL spec's declared abort code

**Example test case:**
```json
{
  "test_id": "transfer_sender_frozen_001",
  "inputs": { "sender_store": { "frozen": true, ... }, ... },
  "expected_vm_result": { "status": "aborted", "abort_code": "196612" },
  "msl_spec_ref": "spec confidential_transfer_internal { aborts_if sender_store.frozen with ETOKEN_IS_FROZEN; }"
}
```

**Failure modes:**
- **VM aborts with wrong code** — Implementation doesn't match spec
- **VM succeeds when spec says abort** — Missing abort check in implementation

---

### 2.3 Lean ↔ Move Prover (via Composition Claims)

**Integration point:** `audit/COMPOSITION_CLAIMS.md`

**What's tested:**
- Lean proves: `verify_transfer_proof` bytecode is correct
- MSL proves: `confidential_transfer_internal` preserves balance
- Composition claim: The entry point `confidential_transfer` is correct because it calls `verify_transfer_proof` (Lean-verified) and `confidential_transfer_internal` (MSL-verified)

**Test mechanism:**
1. Manual audit of COMPOSITION_CLAIMS.md
2. Check that every operation has both a Lean theorem and an MSL spec
3. Verify the composition logic (entry point calls both the crypto verifier and the state updater)

**Example claim:**
```markdown
## confidential_transfer

**Lean proves:** `transfer_eval_equiv_functional_sim` — the `verify_transfer_proof` bytecode is semantically equivalent to the sigma verifier predicate.

**MSL proves:** `spec confidential_transfer_internal` — balance sum is preserved, sender loses `amount`, recipient gains `amount`.

**Composition:** `confidential_transfer` entry point calls `verify_transfer_proof` (Lean-verified) followed by `confidential_transfer_internal` (MSL-verified). The combination ensures both crypto soundness and state correctness.

**Difftest validates:** 17 test cases covering happy path + error paths.
```

**Failure modes:**
- **Missing composition** — Operation has Lean proof but no MSL spec (or vice versa)
- **Incorrect composition** — Entry point doesn't actually call the Lean-verified function

---

## 3. Test Matrix

### 3.1 Per-Operation Test Coverage

For each operation, ensure:

| Stack | Test Type | Minimum Coverage | Where to Check |
|---|---|---|---|
| **Lean** | EvalEquiv proof | 1 top-level theorem, 0 sorry | `lake build <Operation>/EvalEquiv.lean` |
| **Lean** | Phase 6 composition | 1 `*_eval_equiv_functional_sim` theorem | `lake build <Operation>/Phase6Composition.lean` |
| **Move Prover** | MSL spec | 1 `spec` block for the `*_internal` function | `movement move prove --filter <module>` |
| **Difftest** | Happy path | ≥1 test case (success) | `./scripts/manage_difftest_corpus.sh list <operation>` |
| **Difftest** | Error paths | ≥1 test case per abort condition | Same as above |
| **Difftest** | Edge cases | ≥1 test case for boundary conditions | Same as above |

**Example for `normalization`:**
- ✅ Lean EvalEquiv: `Normalization/EvalEquiv.lean` (14 PC steps, builds in ~0.5s)
- ✅ Lean Phase 6: `Normalization/Phase6Composition.lean` (`normalization_eval_equiv_functional_sim`)
- ✅ MSL spec: `confidential_proof.spec.move` (`spec normalize_internal { ... }`)
- ✅ Difftest happy path: `normalization_happy_path_001.json`
- ✅ Difftest error path: `normalization_proof_failed_001.json`

---

### 3.2 Cross-Stack Consistency Matrix

| Property | Lean | MSL | Difftest | Consistency Check |
|---|---|---|---|---|
| Balance sum preserved (normalization) | `sum(new_balance) = sum(old_balance)` theorem | `ensures sum_balance(...) == sum_balance(old(...))` | Test case with input sum=4000, output sum=4000 | All three agree |
| Frozen account aborts (transfer) | Abort code 196612 in functional sim | `aborts_if sender_store.frozen with ETOKEN_IS_FROZEN` | Test case with frozen=true, expect abort 196612 | All three agree |
| Withdrawal decreases balance | `sum(new) + amount = sum(old)` theorem | `ensures old_sum == new_sum + amount` | Test case with old=3000, amount=500, new=2500 | All three agree |

**How to check:**
```bash
# Run all three stacks on the same operation
./audit/verify-ca.sh --op transfer --stack lean       # Check Lean theorems
./audit/verify-ca.sh --op transfer --stack move-prover  # Check MSL specs
./audit/verify-ca.sh --op transfer --stack difftest    # Check concrete tests

# All three should exit 0 (success)
```

---

## 4. Workflow: Adding a New Operation

### Step 1: Define the operation (Move source)

Write the Move implementation:
```move
// In confidential_asset.move
public entry fun new_operation(owner: &signer, amount: u64, proof: &NewProof) {
    let store = borrow_global_mut<ConfidentialAssetStore>(signer::address_of(owner));
    assert!(!store.frozen, ETOKEN_IS_FROZEN);
    
    assert!(verify_new_proof(proof), EPROOF_VERIFICATION_FAILED);
    
    // ... update store ...
}
```

---

### Step 2: Add MSL spec (Move Prover stack)

Write the spec in `confidential_asset.spec.move`:
```move
spec new_operation(owner: &signer, amount: u64, proof: &NewProof) {
    pragma aborts_if_is_strict;
    
    let owner_addr = signer::address_of(owner);
    let store = global<ConfidentialAssetStore>(owner_addr);
    
    aborts_if store.frozen with ETOKEN_IS_FROZEN;
    aborts_if !verify_new_proof(proof) with EPROOF_VERIFICATION_FAILED;
    
    ensures sum_balance(global<ConfidentialAssetStore>(owner_addr).pending_balance) ==
            sum_balance(old(global<ConfidentialAssetStore>(owner_addr).pending_balance)) + amount;
}
```

**Test:**
```bash
movement move prove --package-dir aptos-move/framework/aptos-experimental \
  --filter confidential_asset::new_operation
```

Expected: `{ "Result": "Success" }` with 0 VCs (or N VCs all verified).

---

### Step 3: Add Lean EvalEquiv proof

Create `lean/MovementFormal/Experimental/ConfidentialAsset/NewOperation/EvalEquiv.lean`:

```lean
import MovementFormal.MoveModel.StepLemmas.Basic
...

@[irreducible]
def newOperationState (pc : Nat) (...) : Frame := { ... }

theorem step_pc0 : step env (newOperationState 0 ...) cs ms = ... := by
  rw [step_immBorrowLoc_frame]; rfl

...

theorem eval_new_operation_eq_run : ... := by
  rw [step_pc0, step_pc1, ..., step_pcN]; rfl
```

**Test:**
```bash
lake build MovementFormal.Experimental.ConfidentialAsset.NewOperation.EvalEquiv
```

Expected: Builds in under 3 minutes, 0 errors.

---

### Step 4: Add Lean Phase 6 composition

Create `lean/MovementFormal/Experimental/ConfidentialAsset/NewOperation/Phase6Composition.lean`:

```lean
theorem new_operation_eval_equiv_functional_sim : ... := by
  unfold verifyNewOperationBytecodeResult
  cases h : oracle.verifyNewProof ...
  case none => exact new_operation_shape_verifyFailed ...
  case some proof => exact new_operation_shape_success ...
```

**Test:**
```bash
lake build MovementFormal.Experimental.ConfidentialAsset.NewOperation.Phase6Composition
```

Expected: Builds in under 1 minute, 0 errors.

---

### Step 5: Add difftest corpus

Create `examples/difftest/new_operation_happy_path.json`:
```json
{
  "test_id": "new_operation_happy_path_001",
  "operation": "new_operation",
  "inputs": { ... },
  "expected_output": { "status": "success", ... },
  ...
}
```

Add error-path test cases for each abort condition.

**Test:**
```bash
./scripts/manage_difftest_corpus.sh validate new_operation
```

Expected: All test cases validate against the JSON schema.

---

### Step 6: Run integration test

```bash
./audit/verify-ca.sh --op new_operation
```

Expected:
- Lean: ✅ Builds successfully
- Move Prover: ✅ 0 VCs or all VCs verified
- Difftest: ✅ All test cases pass

If any stack fails, debug cross-stack inconsistency (see §9).

---

## 5. Workflow: Modifying Existing Verification

### Scenario: Change abort condition in `withdraw_to_internal`

**Example:** Add a new abort check for maximum withdrawal amount.

---

#### Step 1: Update Move implementation

```move
public fun withdraw_to_internal(store: &mut ConfidentialAssetStore, amount: u64, proof: &WithdrawalProof) {
    assert!(!store.frozen, ETOKEN_IS_FROZEN);
    assert!(amount <= MAX_WITHDRAWAL_AMOUNT, EWITHDRAWAL_TOO_LARGE);  // NEW
    assert!(verify_withdrawal_proof(proof), EPROOF_VERIFICATION_FAILED);
    // ...
}
```

---

#### Step 2: Update MSL spec

```move
spec withdraw_to_internal(store: &mut ConfidentialAssetStore, amount: u64, proof: &WithdrawalProof) {
    pragma aborts_if_is_strict;
    
    aborts_if store.frozen with ETOKEN_IS_FROZEN;
    aborts_if amount > MAX_WITHDRAWAL_AMOUNT with EWITHDRAWAL_TOO_LARGE;  // NEW
    aborts_if !verify_withdrawal_proof(proof) with EPROOF_VERIFICATION_FAILED;
    
    ensures ...;
}
```

**Test:** `movement move prove --filter withdraw_to_internal`

---

#### Step 3: Update Lean EvalEquiv proof

If the bytecode changed (new instruction for the check), add a new PC step:

```lean
theorem step_pcK_amountCheck :
    step env (withdrawalState K ...) cs ms =
      if amount > MAX_WITHDRAWAL_AMOUNT then
        .aborted EWITHDRAWAL_TOO_LARGE
      else
        .ok (withdrawalState (K+1) ...) cs ms := by
  rw [step_brTrue_frame]  -- or step_brFalse_frame
  ...
```

Update the top-level theorem to include the new PC step.

**Test:** `lake build MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv`

---

#### Step 4: Update Lean Phase 6 composition

Add a new shape lemma for the new abort case:

```lean
theorem withdrawal_shape_amountTooLarge
    (h_amount : amount > MAX_WITHDRAWAL_AMOUNT) :
    run env frame cs ms = .aborted EWITHDRAWAL_TOO_LARGE := by
  rw [step_pc0, ..., step_pcK_amountCheck]
  rw [h_amount]
  simp
  rfl
```

Update the main composition theorem:

```lean
theorem withdrawal_eval_equiv_functional_sim : ... := by
  ...
  cases h_amount : amount ≤ MAX_WITHDRAWAL_AMOUNT
  case false =>
    exact withdrawal_shape_amountTooLarge ...
  case true =>
    ...  -- Existing proof
```

**Test:** `lake build MovementFormal.Experimental.ConfidentialAsset.Withdrawal.Phase6Composition`

---

#### Step 5: Add difftest test case

Create `examples/difftest/withdrawal_amount_too_large.json`:
```json
{
  "test_id": "withdrawal_amount_too_large_001",
  "operation": "withdraw_to_internal",
  "inputs": { "amount": "1000000000", ... },  // Exceeds MAX_WITHDRAWAL_AMOUNT
  "expected_output": { "status": "aborted", "abort_code": "<EWITHDRAWAL_TOO_LARGE>" }
}
```

**Test:** `./scripts/manage_difftest_corpus.sh validate withdrawal`

---

#### Step 6: Run integration test

```bash
./audit/verify-ca.sh --op withdrawal
```

Expected:
- Lean: ✅ Builds with new PC step
- Move Prover: ✅ New abort condition verified
- Difftest: ✅ New test case passes

---

## 6. Regression Detection

### 6.1 Axiom drift guard

**What it catches:** New axioms introduced in Lean proofs.

**How it works:**
```bash
# Generate baseline
lake env lean --run scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv \
  > audit/withdrawal-axioms-baseline.txt

# In CI, diff against baseline
lake env lean --run scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv \
  > current-axioms.txt
diff audit/withdrawal-axioms-baseline.txt current-axioms.txt

# Exit non-zero if diff is non-empty
```

**Triggered by:**
- Adding a new `axiom` declaration
- Using an opaque native without documenting it

---

### 6.2 Performance regression

**What it catches:** Build time increases beyond budget.

**How it works:**
```bash
./scripts/detect_performance_regression.sh --mode check
```

Compares current build times to `audit/performance-baseline.json`. Fails if:
- Any file exceeds 180s (per-file budget)
- Full tree exceeds 600s (full-tree budget)

**Triggered by:**
- Using bare `simp` instead of `simp only`
- Removing `@[irreducible]` from state constructors
- Adding expensive rewrites

---

### 6.3 Test coverage regression

**What it catches:** Removal of test cases without replacement.

**How it works:**
```bash
./scripts/count_verification_coverage.sh
```

Counts:
- Lean theorems per operation
- MSL spec blocks per operation
- Difftest test cases per operation

Fails if counts drop below thresholds:
- Lean: ≥1 EvalEquiv theorem + ≥1 Phase6 theorem per operation
- MSL: ≥1 spec block per `*_internal` function
- Difftest: ≥10 test cases per operation (happy path + error paths)

---

## 7. Continuous Integration

### 7.1 CI matrix

**Jobs:**
1. `lean-verification` — Build full Lean tree, check axioms
2. `move-prover-verification` — Run Move Prover on all CA modules
3. `difftest-verification` — Run difftest corpus (all 87+ rows)
4. `performance-check` — Detect performance regressions
5. `trust-boundaries-check` — Reconcile TRUST_BOUNDARIES.md
6. `full-report` — Aggregate all results into a single JSON report

**Parallelization:**
- Jobs 1-5 run in parallel
- Job 6 waits for 1-5 to complete

**Total CI time:** ~13 minutes (measured on `lean-fv` branch as of 2026-04-22).

---

### 7.2 CI failure modes

| Job | Failure Reason | How to Debug |
|---|---|---|
| `lean-verification` | Proof failed, build timeout | Run `lake build` locally, check for `sorry` or axioms |
| `move-prover-verification` | VC failed, timeout | Run `movement move prove --filter <module>` locally |
| `difftest-verification` | VM output != Lean model | Run `./scripts/manage_difftest_corpus.sh run <operation>`, inspect diff |
| `performance-check` | Build time exceeded budget | Run `./scripts/profile_lean_build.sh`, identify slow files |
| `trust-boundaries-check` | TRUST_BOUNDARIES.md out of sync | Run `./scripts/reconcile_trust_boundaries.sh`, commit updates |

---

## 8. Local Testing Checklist

Before pushing a PR:

### 8.1 Lean stack
```bash
# Build the modified file
lake build MovementFormal.Experimental.ConfidentialAsset.<Operation>.<File>

# Build the full CA tree
lake build MovementFormal.Experimental.ConfidentialAsset

# Check axioms
lake env lean --run scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.<Operation>.<File>

# Profile build time (if you touched performance-critical code)
./scripts/profile_lean_build.sh --file MovementFormal.Experimental.ConfidentialAsset.<Operation>.<File>
```

---

### 8.2 Move Prover stack
```bash
# Verify the modified module
movement move prove --package-dir aptos-move/framework/aptos-experimental \
  --filter <module_name>

# Verify all CA modules (full suite)
movement move prove --package-dir aptos-move/framework/aptos-experimental \
  --filter 'confidential_(asset|balance|proof|twisted_elgamal)'
```

---

### 8.3 Difftest stack
```bash
# Validate corpus structure
./scripts/manage_difftest_corpus.sh validate <operation>

# Run tests for modified operation
./scripts/manage_difftest_corpus.sh run <operation>

# Generate coverage report
./scripts/manage_difftest_corpus.sh coverage
```

---

### 8.4 Integration check
```bash
# Run full verification suite (all three stacks)
./audit/verify-ca.sh --op <operation>

# Or run all operations (takes longer)
./audit/verify-ca.sh
```

---

## 9. Debugging Cross-Stack Failures

### 9.1 Lean succeeds, VM aborts (Lean model too permissive)

**Symptoms:**
- Lean proof builds successfully
- Difftest shows VM abort on a concrete input
- Lean model predicts success

**Debugging steps:**

1. **Identify the input:**
   ```bash
   ./scripts/manage_difftest_corpus.sh run <operation> --verbose
   ```
   Look for the failing test case ID.

2. **Check the VM abort code:**
   ```json
   {
     "vm_result": { "status": "aborted", "abort_code": "196612" }
   }
   ```

3. **Map abort code to error:**
   ```bash
   grep -r "196612" aptos-move/framework/aptos-experimental/sources/
   ```
   Find the corresponding `const ETOKEN_IS_FROZEN: u64 = 196612;`

4. **Check if Lean functional sim handles this abort:**
   ```lean
   -- In FunctionalSim.lean
   def verifyOperationBytecodeResult (oracle : Oracle) (...) : ExecResult :=
     if store.frozen then
       .aborted 196612  -- ETOKEN_IS_FROZEN
     else
       ...
   ```

5. **If missing, add the abort case to the functional sim and update the Lean proof.**

---

### 9.2 VM succeeds, Lean aborts (Lean model too strict)

**Symptoms:**
- Lean proof predicts abort
- Difftest shows VM success on the same input

**Debugging steps:**

1. **Check the Lean functional sim:**
   ```lean
   def verifyOperationBytecodeResult (oracle : Oracle) (...) : ExecResult :=
     if <condition> then
       .aborted <code>
     else
       ...
   ```

2. **Verify the condition against the Move source:**
   ```move
   assert!(<condition>, ERROR_CODE);
   ```

3. **If the condition is wrong in Lean, fix the functional sim and reprove.**

---

### 9.3 MSL spec fails, but VM passes (spec too strict)

**Symptoms:**
- Move Prover reports VC failure
- VM executes successfully on similar inputs

**Debugging steps:**

1. **Read the VC failure message:**
   ```
   error: post-condition does not hold
     --> confidential_asset.spec.move:42:5
      |
   42 |     ensures sum_balance(store.pending_balance) == sum_balance(old(store.pending_balance));
      |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   ```

2. **Check if the postcondition is correct:**
   - Review the Move implementation
   - Trace through the logic manually
   - Verify the spec matches the intended behavior

3. **If the spec is wrong, relax it to match the implementation.**

---

## 10. Performance Benchmarking

### 10.1 Benchmark all stacks

```bash
./scripts/benchmark_verification.sh
```

**Output:**
```
=== Lean Stack ===
Registration:   3.2s
Normalization:  0.5s
Withdrawal:     0.5s
Transfer:       0.7s
Rotation:       0.5s
Total Lean:     5.4s

=== Move Prover Stack ===
confidential_asset:   1.2s
confidential_balance: 0.8s
confidential_proof:   0.9s
Total MSL:            2.9s

=== Difftest Stack ===
Total test cases: 87
Passed: 87
Failed: 0
Total Difftest: 45.3s

OVERALL: 53.6s (under 60s budget ✅)
```

---

### 10.2 Track performance over time

```bash
# Store baseline
./scripts/benchmark_verification.sh --output audit/performance-baseline.json

# Compare to baseline (in CI)
./scripts/detect_performance_regression.sh --mode check
```

---

## Summary

Integration testing ensures the three verification stacks (Lean, Move Prover, Difftest) agree on:
- **Abort conditions** (all three predict the same abort codes)
- **Success outcomes** (all three predict the same final states)
- **Behavioral equivalence** (Lean model matches VM execution on concrete inputs)

**Workflow:**
1. Add new operation → write Move + MSL + Lean + difftest
2. Modify operation → update all three stacks consistently
3. Test locally → run `verify-ca.sh` before pushing
4. CI validates → 6 parallel jobs ensure no regressions

**Key tools:**
- `./audit/verify-ca.sh` — single-command integration test
- `./scripts/manage_difftest_corpus.sh` — difftest corpus management
- `./scripts/detect_performance_regression.sh` — performance guard
- `./scripts/reconcile_trust_boundaries.sh` — trust boundary consistency check

**Next steps:**
- Study the test matrix (§3) to understand coverage goals
- Practice the workflow (§4) on a simple operation (normalization)
- Use the debugging guide (§9) when cross-stack failures occur
