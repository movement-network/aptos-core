# Cross-Stack Verification Reconciliation Guide

**Status:** Complete guide for ensuring consistency across Lean, MSL, and Difftest  
**Audience:** Verification engineers maintaining three-stack verification consistency  
**Prerequisites:** All three stacks operational (Lean complete, MSL when unblocked, Difftest active)  
**Purpose:** Prevent divergence between verification stacks, detect inconsistencies, maintain synchronized coverage

## Overview

The CA verification strategy uses three independent proof checkers that must remain synchronized:
1. **Lean 4:** Bytecode-level proofs (PC-by-PC stepping, `MoveModel.step`)
2. **MSL (Move Prover):** Source-level specs (resource invariants, balance conservation, abort codes)
3. **Difftest:** VM-model consistency (concrete input/output agreement)

**This guide addresses:**
- How to ensure all three stacks verify the same properties
- Detecting divergence between stacks (e.g., Lean proves X but MSL doesn't, or vice versa)
- Maintaining synchronized test coverage (same operations, same edge cases)
- Reconciliation workflows when stacks disagree
- Automated consistency checking in CI

**Key principle:** The three stacks are _complementary_, not redundant. Each covers different aspects, but they must _agree_ on observable behavior (abort codes, state transitions, balance conservation).

## 1. Cross-Stack Property Matrix

### 1.1 Property Coverage by Stack

| Property | Lean | MSL | Difftest | Notes |
|----------|------|-----|----------|-------|
| **PC-level bytecode correctness** | ✅ Full | ❌ No | ✅ Partial (difftest validates PC sequences indirectly) | Lean is authoritative for bytecode semantics |
| **Balance conservation** | ✅ Full | ✅ Full | ✅ Partial (validates on test cases) | All three must agree on this |
| **Abort codes** | ✅ Full | ✅ Full | ✅ Full | **CRITICAL:** Must match exactly across all stacks |
| **Frozen account enforcement** | ✅ Full | ✅ Full | ✅ Full | Must agree: frozen → abort with ETOKEN_IS_FROZEN |
| **Allow-list enforcement** | ✅ Full | ✅ Full | ✅ Full | Must agree: not on list → abort with ERECIPIENT_REJECTED_TRANSFER |
| **Proof verification** | ✅ Full (opaque oracle) | ✅ Partial (opaque) | ✅ Full (VM execution) | Lean + difftest verify, MSL abstracts via `pragma opaque` |
| **Non-negativity** | ✅ Full | ✅ Full | ✅ Partial (on test cases) | Lean + MSL verify ∀, difftest validates samples |
| **Heap threading** | ✅ Full | ✅ Partial (framework handles) | ✅ Full (VM execution) | Lean proves explicit heap updates, MSL relies on framework specs |
| **FA integration** | ❌ Abstracted | ✅ Full (composes with upstream FA specs) | ✅ Full (VM execution) | MSL is authoritative for FA interactions |
| **Container table operations** | ✅ Full | ❌ Abstracted | ✅ Full (VM execution) | Lean models containers explicitly, MSL treats as opaque object ops |

**Reconciliation rule:** For properties covered by multiple stacks, all must agree. Divergence = bug in one or more stacks.

### 1.2 Abort Code Synchronization Table

**CRITICAL:** Abort codes must match exactly across all three stacks.

| Operation | Abort Condition | Code | Lean | MSL | Difftest |
|-----------|-----------------|------|------|-----|----------|
| **register** | Already registered | 196608 | ✅ | ✅ | ✅ |
| **register** | Schnorr verify fails | 65537 | ✅ | ✅ | ✅ |
| **register** | HMAC verify fails | 65538 | ✅ | ✅ | ✅ |
| **transfer** | Sender frozen | 196613 | ✅ | ✅ | ✅ |
| **transfer** | Receiver frozen | 196613 | ✅ | ✅ | ✅ |
| **transfer** | Not on allow-list | 196614 | ✅ | ✅ | ✅ |
| **transfer** | Proof fails | 65537 | ✅ | ✅ | ✅ |
| **transfer** | Insufficient balance | 196612 | ✅ | ✅ | ✅ |
| **withdrawal** | Frozen | 196613 | ✅ | ✅ | ✅ |
| **withdrawal** | Proof fails | 65537 | ✅ | ✅ | ✅ |
| **withdrawal** | Insufficient balance | 196612 | ✅ | ✅ | ✅ |
| **freeze** | Already frozen | 196615 | ✅ | ✅ | ✅ |
| **freeze** | Not owner | 196617 | ✅ | ✅ | ✅ |
| **unfreeze** | Not frozen | 196616 | ✅ | ✅ | ✅ |
| **unfreeze** | Not owner | 196617 | ✅ | ✅ | ✅ |

**Verification:**
```bash
./scripts/reconcile_abort_codes.sh
```

Checks that:
- Lean theorems specify correct abort codes (e.g., `frozen → .aborted 196613`)
- MSL specs have matching `aborts_if` clauses (e.g., `aborts_if frozen with ETOKEN_IS_FROZEN`)
- Difftest test cases expect correct abort codes (e.g., `"expected_abort": 196613`)

## 2. Reconciliation Workflows

### 2.1 Workflow 1: New Operation Added

**Scenario:** A new CA operation is added to the Move source code.

**Steps:**

**Step 1: Update all three stacks simultaneously**

Don't implement in one stack and backfill others later — this leads to divergence.

| Stack | Action | Timeline |
|-------|--------|----------|
| **Move source** | Implement new operation | Day 1 |
| **MSL spec** | Write spec (aborts_if, ensures, requires) | Day 1 |
| **Lean model** | Transcribe bytecode, write step theorems | Day 2-3 |
| **Difftest** | Add test cases (happy path + error paths) | Day 2 |

**Step 2: Validate abort codes match**

```bash
# Check Move source abort codes
grep -r "abort" aptos-move/framework/aptos-experimental/sources/confidential_asset/new_operation.move

# Check MSL spec abort codes
grep "aborts_if" aptos-move/framework/aptos-experimental/sources/confidential_asset/new_operation.spec.move

# Check Lean model abort codes
grep "aborted" lean/MovementFormal/Experimental/ConfidentialAsset/NewOperation/EvalEquiv.lean

# Check difftest expected aborts
grep "expected_abort" difftest/corpus/confidential_assets/*new_operation*.json
```

All must agree on abort code values.

**Step 3: Validate state transitions match**

For a successful operation:
- **Lean:** Prove `run env initialState fuel cs ms = .returned [] cs' ms'`
- **MSL:** Specify postconditions `ensures global<Store>(addr).field == new_value`
- **Difftest:** Test case `"expected_result": "success"`, `"final_state": {...}`

All three must agree on what changes (and what doesn't).

**Step 4: Run cross-stack consistency check**

```bash
./scripts/validate_cross_stack_consistency.sh --operation new_operation
```

Reports:
- Abort codes: ✅ All match
- State transitions: ✅ Lean, MSL, difftest agree
- Coverage: ❌ Missing difftest case for frozen account

Fix gaps, re-run until all ✅.

### 2.2 Workflow 2: Divergence Detected

**Scenario:** CI reports that Lean proves property X but difftest shows violation.

**Example:** Lean proves `transfer_preserves_balance` but difftest case `e2e_transfer_max_amount` fails balance check.

**Root causes:**
1. Lean model is wrong (doesn't match VM bytecode)
2. Difftest test case is wrong (incorrect expected values)
3. VM has a bug (least likely, but possible)

**Debugging workflow:**

**Step 1: Isolate the divergence**

Run the specific difftest case:
```bash
./difftest/difftest.sh run-single difftest/corpus/confidential_assets/e2e_transfer_max_amount.json
```

Extract actual vs expected:
```
Actual final balance (sender): 0
Expected final balance (sender): 100

Actual final balance (receiver): 1000100
Expected final balance (receiver): 1000000
```

Receiver gained 100 extra! Sender lost 100 less than expected.

**Step 2: Check Lean proof**

Read the Lean theorem:
```lean
theorem transfer_preserves_balance
    : sender_balance_post + receiver_balance_post == 
      sender_balance_pre + receiver_balance_pre
```

Does this account for encrypted homomorphic addition correctly? Check the `homomorphic_add` definition.

**Step 3: Check MSL spec**

Read the MSL postcondition:
```move
spec confidential_transfer_internal {
    ensures sum_balance_chunks(global<ConfidentialAssetStore>(sender).pending_balance) +
            sum_balance_chunks(global<ConfidentialAssetStore>(receiver).pending_balance)
            ==
            old(sum_balance_chunks(global<ConfidentialAssetStore>(sender).pending_balance)) +
            old(sum_balance_chunks(global<ConfidentialAssetStore>(receiver).pending_balance));
}
```

Does `sum_balance_chunks` correctly sum encrypted chunks? Is it opaque or defined?

**Step 4: Manually execute the difftest case**

Run the Move code with the exact inputs from the test case:
```bash
movement move run \
  --function confidential_asset::confidential_transfer_internal \
  --args <exact args from test case> \
  --verbose
```

Inspect actual output. Compare to difftest expected output and Lean/MSL predictions.

**Step 5: Identify root cause**

Suppose the issue is: Lean model's `homomorphic_add` doesn't handle overflow correctly.

**Step 6: Fix the divergence**

Update Lean model:
```lean
-- Before (wrong)
def homomorphic_add (chunk : ElGamalCiphertext) (amount : u64) : ElGamalCiphertext :=
  { commitment := chunk.commitment + amount, ... }  -- Overflow not handled!

-- After (correct)
def homomorphic_add (chunk : ElGamalCiphertext) (amount : u64) : ElGamalCiphertext :=
  { commitment := (chunk.commitment + amount) % FIELD_MODULUS, ... }  -- Modular arithmetic
```

**Step 7: Re-verify all stacks**

```bash
# Lean
lake build MovementFormal.Experimental.ConfidentialAsset.Transfer

# MSL (once unblocked)
movement move prove --filter confidential_asset::confidential_transfer_internal

# Difftest
./difftest/difftest.sh run-single difftest/corpus/confidential_assets/e2e_transfer_max_amount.json
```

All must pass.

### 2.3 Workflow 3: MSL Spec Strengthening

**Scenario:** MSL spec is too weak (allows behaviors Lean/difftest forbid).

**Example:** MSL spec for `normalize` doesn't require pending balance to be cleared:

```move
spec normalize_internal {
    ensures global<ConfidentialAssetStore>(addr).actual_balance.chunks != old(...).actual_balance.chunks;
    // MISSING: ensures pending_balance cleared!
}
```

But Lean proves:
```lean
theorem normalize_clears_pending
    : store_post.pending_balance.chunks == vector::empty
```

And difftest validates this.

**Fix:** Strengthen MSL spec:
```move
spec normalize_internal {
    ensures global<ConfidentialAssetStore>(addr).actual_balance.chunks != old(...).actual_balance.chunks;
    ensures len(global<ConfidentialAssetStore>(addr).pending_balance.chunks) == 0;  // ADDED
}
```

**Validation:** Re-run Move Prover, ensure it verifies the strengthened spec.

## 3. Automated Consistency Checking

### 3.1 Abort Code Reconciliation Script

**Script:** `scripts/reconcile_abort_codes.sh`

**Purpose:** Ensure abort codes match across Lean, MSL, and difftest.

**Implementation:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Extract abort codes from each stack
declare -A lean_aborts
declare -A msl_aborts
declare -A difftest_aborts

# Parse Lean theorems
while IFS= read -r line; do
  if [[ $line =~ aborted\ ([0-9]+) ]]; then
    code="${BASH_REMATCH[1]}"
    operation=$(echo "$line" | grep -oP 'theorem \K[a-z_]+')
    lean_aborts["$operation"]="$code"
  fi
done < <(grep -r "aborted" lean/MovementFormal/Experimental/ConfidentialAsset/*/EvalEquiv.lean)

# Parse MSL specs
while IFS= read -r line; do
  if [[ $line =~ aborts_if.*with\ E([A-Z_]+) ]]; then
    error_name="${BASH_REMATCH[1]}"
    # Map error name to code (would need a lookup table)
    # code=$(map_error_name_to_code "$error_name")
    # msl_aborts["$operation"]="$code"
  fi
done < <(grep -r "aborts_if" aptos-move/framework/aptos-experimental/sources/confidential_asset/*.spec.move)

# Parse difftest test cases
for test_file in difftest/corpus/confidential_assets/*.json; do
  expected_abort=$(jq -r '.expected.abort_code // empty' "$test_file")
  if [[ -n "$expected_abort" ]]; then
    operation=$(jq -r '.operation' "$test_file")
    difftest_aborts["$operation"]="$expected_abort"
  fi
done

# Compare
echo "Abort Code Reconciliation Report"
echo "================================="
echo ""

for operation in "${!lean_aborts[@]}"; do
  lean_code="${lean_aborts[$operation]}"
  msl_code="${msl_aborts[$operation]:-MISSING}"
  difftest_code="${difftest_aborts[$operation]:-MISSING}"

  if [[ "$lean_code" == "$msl_code" ]] && [[ "$lean_code" == "$difftest_code" ]]; then
    echo "✅ $operation: $lean_code (all stacks agree)"
  else
    echo "❌ $operation: Lean=$lean_code, MSL=$msl_code, Difftest=$difftest_code"
  fi
done
```

**Usage:**
```bash
./scripts/reconcile_abort_codes.sh
```

**Output:**
```
Abort Code Reconciliation Report
=================================

✅ transfer_frozen: 196613 (all stacks agree)
✅ transfer_not_allowed: 196614 (all stacks agree)
❌ normalize_invalid_proof: Lean=65537, MSL=65538, Difftest=65537
```

**Action:** Fix MSL spec for `normalize_invalid_proof` (should be 65537, not 65538).

### 3.2 State Transition Consistency Checker

**Script:** `scripts/check_state_transition_consistency.sh`

**Purpose:** Validate that Lean, MSL, and difftest agree on what state changes occur.

**Implementation idea:**

For each operation:
1. **Extract Lean postcondition:** Parse `ensures` clauses from theorems
2. **Extract MSL postcondition:** Parse `ensures` clauses from specs
3. **Extract difftest expected state:** Parse `expected.final_state` from test cases
4. **Compare:** Report any mismatches

**Example:**

```bash
# For operation: deposit_to_internal

Lean postcondition:
  store.pending_balance.chunks[0] == old_store.pending_balance.chunks[0] + deposit_amount

MSL postcondition:
  global<ConfidentialAssetStore>(addr).pending_balance.chunks[0].value ==
    old(global<ConfidentialAssetStore>(addr)).pending_balance.chunks[0].value + amount

Difftest expected state:
  "pending_balance": {"chunks": [{"value": 1100}, ...]}  # old was 100, deposit was 1000

All three agree: ✅
```

### 3.3 Coverage Consistency Matrix

**Script:** `scripts/generate_coverage_matrix.sh`

**Purpose:** Show which operations/scenarios are covered by which stacks.

**Output:**
```
Coverage Matrix
===============

Operation: register
  Lean:     ✅ 197 theorems (all PCs + composition)
  MSL:      ✅ Spec complete (6 ensures, 5 aborts_if)
  Difftest: ✅ 9 test cases (3 happy path, 4 error, 2 edge)

Operation: transfer
  Lean:     ✅ 24 theorems (all PCs + composition)
  MSL:      ✅ Spec complete (8 ensures, 5 aborts_if)
  Difftest: ⚠️  11 test cases (3 happy path, 5 error, 3 edge) - MISSING: range proof invalid cases

Operation: normalization
  Lean:     ✅ 14 theorems (all PCs + composition)
  MSL:      ⚠️  Spec partial (4 ensures, 2 aborts_if) - MISSING: range proof failure
  Difftest: ✅ 5 test cases (2 happy path, 2 error, 1 edge)
```

**Action:** Add missing test case for transfer range proof invalid, strengthen MSL spec for normalization.

## 4. CI Integration

### 4.1 Cross-Stack Validation Job

**GitHub Actions workflow:** `.github/workflows/cross-stack-validation.yaml`

```yaml
name: Cross-Stack Verification Consistency

on:
  pull_request:
  push:
    branches: [main, lean-fv]

jobs:
  cross-stack-consistency:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install dependencies
        run: |
          # Install Lean, Movement CLI, jq, etc.
          ...

      - name: Reconcile abort codes
        run: ./scripts/reconcile_abort_codes.sh

      - name: Check state transition consistency
        run: ./scripts/check_state_transition_consistency.sh

      - name: Generate coverage matrix
        run: ./scripts/generate_coverage_matrix.sh

      - name: Validate all stacks agree
        run: |
          # If any reconciliation failed, exit 1
          if grep "❌" reconciliation_report.txt; then
            echo "Cross-stack divergence detected!"
            exit 1
          fi

      - name: Upload reports as artifacts
        uses: actions/upload-artifact@v3
        with:
          name: cross-stack-reports
          path: |
            reconciliation_report.txt
            coverage_matrix.txt
```

### 4.2 Per-Operation Validation

**For each new operation or modification:**

```yaml
- name: Validate transfer operation
  run: |
    # Lean
    lake build MovementFormal.Experimental.ConfidentialAsset.Transfer

    # MSL (when unblocked)
    movement move prove --filter confidential_asset::confidential_transfer_internal

    # Difftest
    ./difftest/difftest.sh run-tag transfer

    # Cross-stack check
    ./scripts/validate_cross_stack_consistency.sh --operation transfer

- name: Check for abort code divergence
  run: |
    LEAN_ABORT=$(grep "transfer_frozen" lean/.../*.lean | grep -oP 'aborted \K[0-9]+')
    MSL_ABORT=$(grep "aborts_if.*frozen" *.spec.move | map_to_code)
    DIFFTEST_ABORT=$(jq -r '.expected.abort_code' difftest/corpus/.../e2e_transfer_frozen.json)

    if [[ "$LEAN_ABORT" != "$MSL_ABORT" ]] || [[ "$LEAN_ABORT" != "$DIFFTEST_ABORT" ]]; then
      echo "Abort code mismatch: Lean=$LEAN_ABORT, MSL=$MSL_ABORT, Difftest=$DIFFTEST_ABORT"
      exit 1
    fi
```

## 5. Reconciliation Patterns

### 5.1 Pattern: Lean Abstract, MSL Concrete

**Scenario:** Lean models crypto as opaque oracle, MSL must specify balance constraints.

**Example:**

**Lean:**
```lean
-- Crypto is opaque oracle
axiom homomorphic_add_preserves_sum : 
  decrypt (homomorphic_add chunk amount) == decrypt chunk + amount
```

**MSL:**
```move
spec fun sum_balance_chunks(chunks: BalanceChunks): int {
  // Must specify balance sum explicitly (can't call decrypt)
  len(chunks.chunks) == 4 &&
  chunks.chunks[0].value + chunks.chunks[1].value + chunks.chunks[2].value + chunks.chunks[3].value
}

spec add_balance_chunks {
    ensures sum_balance_chunks(result) == sum_balance_chunks(balance) + amount;
}
```

**Reconciliation:** MSL spec must be _at least as strong_ as Lean axiom. If Lean proves `sum_preserved`, MSL must `ensures sum_preserved` (or stronger).

### 5.2 Pattern: MSL Relies on Upstream, Lean Must Model

**Scenario:** MSL composes with FA framework specs, Lean must model FA operations explicitly (or abstract them).

**Example:**

**MSL:**
```move
spec deposit_coins<CoinType> {
    // Relies on fungible_asset::deposit spec (upstream)
    ensures coin::value(coins) == 0;  // Coin consumed
    ensures global<FungibleStore>(store_addr).balance == 
        old(global<FungibleStore>(store_addr)).balance + old(coin::value(coins));
}
```

**Lean:**
```lean
-- Must model FA deposit explicitly or abstract it
axiom fa_deposit_preserves_supply :
  fa_total_supply_post == fa_total_supply_pre  -- Axiomatize FA behavior
```

**Reconciliation:** Lean axiom must match MSL upstream spec. If MSL relies on FA spec property X, Lean must axiomatize X (and document dependency).

### 5.3 Pattern: Difftest Validates Samples, Lean/MSL Verify ∀

**Scenario:** Difftest tests 87 concrete cases, Lean/MSL prove ∀ inputs.

**Example:**

**Difftest:**
```json
{
  "test_id": "e2e_transfer_max_amount",
  "inputs": {"amount": 18446744073709551615},  // u64::MAX
  "expected": {"result": "success"}
}
```

**Lean:**
```lean
theorem transfer_accepts_max_amount
    (amount : u64)
    (h_amount : amount == u64_max)
    : run env ... = .returned [] ...
```

**MSL:**
```move
spec confidential_transfer_internal {
    // No upper bound on amount (as long as balance sufficient)
    requires sender_balance >= amount;
}
```

**Reconciliation:** If difftest shows `max_amount` succeeds, Lean/MSL must allow `amount == u64_max`. If Lean/MSL forbid some value, difftest must have a test case showing the abort.

## 6. Maintenance Best Practices

### 6.1 Always Update All Three Stacks

**Anti-pattern:**
1. Implement feature in Move source
2. Write Lean proofs
3. **Later (weeks):** Add MSL specs
4. **Later (months):** Add difftest cases

**Problem:** Stacks diverge. By the time MSL specs are added, Move source may have changed, Lean proofs are stale.

**Best practice:**
1. Implement feature in Move source
2. **Simultaneously:** Write MSL spec, Lean model transcription, difftest test cases
3. Validate all three stacks in same PR

### 6.2 Document Cross-Stack Dependencies

**Example:** In Lean axiom, reference MSL spec:

```lean
-- AXIOM: FA deposit increases balance by coin value
-- Justification: aptos-framework/sources/fungible_asset.spec.move:78
--   ensures global<FungibleStore>(store).balance == old(...).balance + coin_value
axiom fa_deposit_increases_balance : ...
```

In MSL spec, reference Lean proof:
```move
// See Lean proof: MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean:234
// Lean proves: transfer preserves total balance (sender + receiver sum unchanged)
spec confidential_transfer_internal {
    ensures sum_balance_chunks(sender) + sum_balance_chunks(receiver) == 
        old(sum_balance_chunks(sender)) + old(sum_balance_chunks(receiver));
}
```

### 6.3 Regression Testing on Cross-Stack Divergence

**When divergence is fixed, add regression test:**

**Example:** After fixing abort code mismatch for `normalize_invalid_proof`:

Add to CI:
```bash
# Regression test: ensure abort codes match
LEAN_ABORT=$(grep "normalize_invalid_proof" lean/.../Normalization.lean | grep -oP 'aborted \K[0-9]+')
test "$LEAN_ABORT" = "65537" || exit 1

MSL_ABORT=$(grep "aborts_if.*invalid_proof" .../normalization.spec.move | map_to_code)
test "$MSL_ABORT" = "65537" || exit 1

DIFFTEST_ABORT=$(jq -r '.expected.abort_code' difftest/.../e2e_normalize_invalid_proof.json)
test "$DIFFTEST_ABORT" = "65537" || exit 1
```

## 7. Case Studies

### 7.1 Case Study: Transfer Abort Code Mismatch

**Problem:** Lean proved `transfer_frozen` aborts with `196613`, but difftest case expected `196614`.

**Investigation:**
1. Check Move source:
   ```move
   assert!(!sender_store.frozen, ETOKEN_IS_FROZEN);  // ETOKEN_IS_FROZEN = 196613
   ```
2. Check difftest test case:
   ```json
   {"expected_abort": 196614}  // WRONG! Should be 196613
   ```
3. Check Lean:
   ```lean
   theorem transfer_frozen_aborts
       : run env ... = .aborted 196613  // CORRECT
   ```

**Root cause:** Difftest test case had wrong expected abort code (copy-paste error from allow-list test).

**Fix:** Update difftest test case:
```json
{"expected_abort": 196613}  // Corrected
```

**Validation:** Re-run difftest, passes. Add regression check to CI.

### 7.2 Case Study: Balance Conservation Divergence

**Problem:** MSL proved balance conservation, but difftest case `e2e_transfer_with_rollover` showed balance loss.

**Investigation:**
1. Difftest shows: Sender lost 100, receiver gained 90. Total decreased by 10!
2. Lean proof: `sender_post + receiver_post == sender_pre + receiver_pre` ✅ (but didn't account for rollover)
3. MSL spec: `sum_balance_chunks(sender) + sum_balance_chunks(receiver)` ✅ (but rollover clears pending)

**Root cause:** Rollover moves pending → actual, clearing pending balance. Neither Lean nor MSL accounted for this in transfer + rollover combination.

**Fix:**
- Lean: Strengthen theorem to account for rollover state:
  ```lean
  theorem transfer_with_rollover_preserves_total_balance
      : sender_pending_post + sender_actual_post + receiver_pending_post + receiver_actual_post ==
        sender_pending_pre + sender_actual_pre + receiver_pending_pre + receiver_actual_pre
  ```
- MSL: Strengthen spec:
  ```move
  spec transfer_then_rollover {
      ensures total_balance_all_accounts() == old(total_balance_all_accounts());
  }
  ```
- Difftest: Add explicit test case for `transfer + rollover` (was missing).

**Outcome:** All three stacks now agree on total balance preservation even with rollover.

## 8. Quick Reference

### 8.1 Consistency Checklist

Before merging a PR that touches CA verification:

- [ ] Abort codes match across Lean, MSL, difftest (run `reconcile_abort_codes.sh`)
- [ ] State transitions consistent (Lean postconditions ↔ MSL ensures ↔ difftest expected state)
- [ ] Coverage symmetric (if Lean proves error path X, difftest has test case for X)
- [ ] Axioms documented (Lean axioms reference MSL specs or difftest validation)
- [ ] CI cross-stack validation passes
- [ ] No temporary axioms (Lean), no `pragma verify = false` (MSL), no `SKIP` (difftest)

### 8.2 Reconciliation Scripts

```bash
# Abort code reconciliation
./scripts/reconcile_abort_codes.sh

# State transition consistency
./scripts/check_state_transition_consistency.sh

# Coverage matrix
./scripts/generate_coverage_matrix.sh

# Per-operation validation
./scripts/validate_cross_stack_consistency.sh --operation transfer

# Full cross-stack validation (all operations)
./scripts/validate_cross_stack_consistency.sh --all
```

### 8.3 Common Divergence Scenarios

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Lean proves X, difftest fails X | Lean model doesn't match VM bytecode | Update Lean model to match VM semantics |
| MSL proves X, difftest fails X | MSL spec too strong (over-specifies) | Weaken MSL spec or fix Move implementation |
| Difftest passes X, Lean/MSL don't prove X | Lean/MSL specs too weak | Strengthen Lean theorems and MSL specs |
| Abort codes differ | Copy-paste error or constant mismatch | Align all abort codes to Move source constants |
| Balance conservation fails in difftest | Missed edge case (rollover, freeze, etc.) | Add test case, strengthen Lean/MSL specs |

## Summary

**Cross-stack consistency principles:**
1. **Always update all three stacks together** (same PR, same commit)
2. **Abort codes must match exactly** (automated reconciliation in CI)
3. **State transitions must agree** (Lean postconditions ↔ MSL ensures ↔ difftest expected state)
4. **Coverage must be symmetric** (if Lean proves, difftest validates; if difftest tests, Lean proves)
5. **Document dependencies** (Lean axioms reference MSL specs, MSL specs reference upstream)

**Automation:**
- `reconcile_abort_codes.sh` - Checks abort code consistency
- `check_state_transition_consistency.sh` - Validates state transition agreement
- `generate_coverage_matrix.sh` - Shows coverage by stack
- `validate_cross_stack_consistency.sh` - Full validation for operation

**CI enforcement:**
- Cross-stack validation job runs on every PR
- Fails if abort codes diverge
- Fails if coverage gaps detected
- Reports uploaded as artifacts

**Maintenance:**
- Run reconciliation scripts weekly
- Update scripts when new operations added
- Regression tests for past divergences
- Documentation of cross-stack dependencies
