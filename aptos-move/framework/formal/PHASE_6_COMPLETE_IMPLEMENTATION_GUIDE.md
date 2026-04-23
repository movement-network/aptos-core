# Phase 6 Complete Implementation Guide

**Phase:** Composition Proofs (PC-chaining theorems)  
**Status:** 30% complete (scaffolded), ~20-30 hours remaining  
**Goal:** Prove bytecode execution matches functional specification  
**Complexity:** MEDIUM-HIGH (requires PC chaining, case-splitting, shape lemmas)

---

## Executive Summary

Phase 6 connects low-level bytecode execution (`run env frame cs ms`) to high-level functional specifications. This is the final step in establishing end-to-end correctness.

**What Phase 6 proves:**
```lean
theorem operation_eval_equiv_functional_sim :
    run env (initialState inputs) cs ms =
      functionalSpec inputs
```

**Translation:** "Running the bytecode produces the same result as our high-level specification."

**Why this matters:**
- ✅ Validates Phase 4 work (bytecode execution correct)
- ✅ Connects to Phase 2/3/5 MSL specs (shared semantics)
- ✅ Provides human-readable verification result

**Estimated effort:**
- Normalization: 3-5 hours (~200 lines)
- Withdrawal: 2-4 hours (~200 lines)
- Rotation: 4-6 hours (~250 lines)
- Transfer: 8-12 hours (~450 lines)
- **Total: 20-30 hours (~1,100 lines)**

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Pattern Library](#pattern-library)
3. [Step-by-Step: Normalization](#step-by-step-normalization)
4. [Step-by-Step: Withdrawal](#step-by-step-withdrawal)
5. [Step-by-Step: Rotation](#step-by-step-rotation)
6. [Step-by-Step: Transfer](#step-by-step-transfer)
7. [Testing and Validation](#testing-and-validation)
8. [Common Patterns](#common-patterns)

---

## Architecture Overview

### The Phase 6 Structure

```
Phase6Composition.lean
├── Functional Simulation (high-level spec)
│   └── def verifyOperationResult : Oracle → Inputs → Result
├── Shape Lemmas (one per execution path)
│   ├── theorem shape_frozen : frozen = true → run ... = .error "frozen"
│   ├── theorem shape_proofInvalid : verify = false → run ... = .error "invalid"
│   └── theorem shape_success : verify = true → run ... = .returned []
└── Main Composition Theorem
    └── theorem eval_equiv_functional_sim :
            run ... = matchFunctionalResult (verifyOperationResult ...)
```

**Key components:**

1. **Functional Simulation:** High-level model abstracting bytecode details
2. **Shape Lemmas:** One theorem per execution path (happy path, error paths)
3. **Main Theorem:** Case-split on oracle results, dispatch to shape lemmas

---

### Relationship to Phase 4

**Phase 4 (EvalEquiv):** Proves individual PC steps
```lean
theorem step_pc0 : step env (state 0) = .ok (state 1)
theorem step_pc1 : step env (state 1) = .ok (state 2)
-- ...
theorem step_pc14 : step env (state 14) = .returned []
```

**Phase 6 (Composition):** Chains Phase 4 steps together
```lean
theorem shape_success :
    run env (state 0) = .returned [] := by
  unfold run
  rw [step_pc0, step_pc1, ..., step_pc14]
  rfl
```

**Mental model:** Phase 4 = individual Lego bricks, Phase 6 = assembled structure

---

## Pattern Library

### Pattern 1: Binary Oracle Decision

**Use case:** Operation with single oracle call (yes/no decision)

**Example:** Normalization (verify proof: some(true) vs some(false) vs none)

```lean
-- Functional spec
def verifyNormalizationResult (oracle : Oracle) (proofRef : RefValue) : Result :=
  match oracle.verifyNormalizationProof proofRef with
  | none => .error "oracle failure"
  | some false => .error "proof verification failed"
  | some true => .success

-- Main theorem (case-split pattern)
theorem normalization_eval_equiv_functional_sim
    (oracle : Oracle)
    (proofRef : RefValue)
    (cs : CallStack)
    (ms : MachineState)
    : run env (normalizationState 0 proofRef) cs ms =
        matchResult (verifyNormalizationResult oracle proofRef) := by
  unfold verifyNormalizationResult
  unfold matchResult
  
  -- Case-split on oracle result
  cases h : oracle.verifyNormalizationProof proofRef
  case none =>
    exact normalization_shape_oracleFailed oracle proofRef cs ms h
  case some proof_valid =>
    cases proof_valid
    case false =>
      exact normalization_shape_proofInvalid oracle proofRef cs ms h
    case true =>
      exact normalization_shape_success oracle proofRef cs ms h
```

**When to use:** Operations with 1-2 oracle calls, 2-3 execution paths

---

### Pattern 2: Multi-Path with State Checks

**Use case:** Operation with multiple guards (frozen check, proof check, balance check)

**Example:** Withdrawal (frozen → proof → balance → success)

```lean
-- Functional spec
def verifyWithdrawalResult (oracle : Oracle) (storeRef : RefValue) (proofRef : RefValue) (ms : MachineState) : Result :=
  match ms.heap.get? storeRef with
  | none => .error "store not found"
  | some store =>
    if store.frozen then
      .error "account frozen"
    else
      match oracle.verifyWithdrawalProof proofRef with
      | none => .error "oracle failure"
      | some false => .error "proof invalid"
      | some true =>
        let amount := oracle.extractAmount proofRef
        let balance := sum_balance_chunks store.pending_balance
        if balance < amount then
          .error "insufficient balance"
        else
          .success

-- Main theorem (nested case-split pattern)
theorem withdrawal_eval_equiv_functional_sim
    (oracle : Oracle)
    (storeRef : RefValue)
    (proofRef : RefValue)
    (cs : CallStack)
    (ms : MachineState)
    : run env (withdrawalState 0 storeRef proofRef) cs ms =
        matchResult (verifyWithdrawalResult oracle storeRef proofRef ms) := by
  unfold verifyWithdrawalResult
  
  -- Case-split on store existence
  cases h_store : ms.heap.get? storeRef
  case none =>
    exact withdrawal_shape_storeNotFound ...
  case some store =>
    -- Case-split on frozen
    cases h_frozen : store.frozen
    case true =>
      exact withdrawal_shape_frozen oracle storeRef proofRef cs ms h_store h_frozen
    case false =>
      -- Case-split on proof
      cases h_verify : oracle.verifyWithdrawalProof proofRef
      case none =>
        exact withdrawal_shape_oracleFailed ...
      case some proof_valid =>
        cases proof_valid
        case false =>
          exact withdrawal_shape_proofInvalid ...
        case true =>
          -- Case-split on balance
          let amount := oracle.extractAmount proofRef
          let balance := sum_balance_chunks store.pending_balance
          cases h_balance : balance < amount
          case true =>
            exact withdrawal_shape_insufficientBalance ...
          case false =>
            exact withdrawal_shape_success ...
```

**When to use:** Operations with 3+ guards, 4+ execution paths

---

### Pattern 3: Multi-Party with Dual State

**Use case:** Operation affecting two accounts (transfer: sender + receiver)

**Example:** Transfer (sender frozen → receiver frozen → allow list → proof → success)

```lean
-- Functional spec
def verifyTransferResult 
    (oracle : Oracle)
    (senderStoreRef : RefValue)
    (receiverStoreRef : RefValue)
    (proofRef : RefValue)
    (ms : MachineState) : Result :=
  match ms.heap.get? senderStoreRef, ms.heap.get? receiverStoreRef with
  | none, _ => .error "sender store not found"
  | _, none => .error "receiver store not found"
  | some senderStore, some receiverStore =>
    if senderStore.frozen then
      .error "sender frozen"
    else if receiverStore.frozen then
      .error "receiver frozen"
    else if !is_allowed receiverStore.allow_list sender_addr then
      .error "recipient rejected"
    else
      match oracle.verifyTransferProof proofRef with
      | none => .error "oracle failure"
      | some false => .error "proof invalid"
      | some true => .success

-- Main theorem (dual state case-split pattern)
theorem transfer_eval_equiv_functional_sim
    (oracle : Oracle)
    (senderStoreRef : RefValue)
    (receiverStoreRef : RefValue)
    (proofRef : RefValue)
    (sender_addr : Address)
    (cs : CallStack)
    (ms : MachineState)
    : run env (transferState 0 senderStoreRef receiverStoreRef proofRef sender_addr) cs ms =
        matchResult (verifyTransferResult oracle senderStoreRef receiverStoreRef proofRef ms) := by
  unfold verifyTransferResult
  
  -- Case-split on both stores
  cases h_sender : ms.heap.get? senderStoreRef <;>
  cases h_receiver : ms.heap.get? receiverStoreRef
  case none.none =>
    exact transfer_shape_bothStoresNotFound ...
  case none.some =>
    exact transfer_shape_senderStoreNotFound ...
  case some.none =>
    exact transfer_shape_receiverStoreNotFound ...
  case some.some sender_store receiver_store =>
    -- Both stores exist, continue checking guards
    cases h_sender_frozen : sender_store.frozen
    case true =>
      exact transfer_shape_senderFrozen ...
    case false =>
      cases h_receiver_frozen : receiver_store.frozen
      case true =>
        exact transfer_shape_receiverFrozen ...
      case false =>
        -- Continue with allow list, proof, etc.
        ...
```

**When to use:** Transfer and other multi-party operations

---

## Step-by-Step: Normalization

**Operation:** Normalization (simplest, good starting point)  
**Estimated time:** 3-5 hours  
**Lines of code:** ~200

### Step 1: Create File Structure (10 min)

```bash
cd lean/MovementFormal/Experimental/ConfidentialAsset/Normalization

# Generate scaffold
../../../../scripts/generate_phase6_scaffold.sh --operation normalization --overwrite

# Output: Phase6Composition.lean created
```

**Verify scaffold:**
```lean
-- Should contain:
-- 1. Imports
-- 2. Namespace declaration
-- 3. Functional simulation stub
-- 4. Shape lemma stubs (with sorry)
-- 5. Main theorem stub (with sorry)
```

---

### Step 2: Define Functional Simulation (30 min)

**Open:** `Phase6Composition.lean`

**Replace functional sim stub:**

```lean
/-!
# Functional Simulation for Normalization

High-level specification: what should normalization do?
-/

/-- Result type for normalization execution -/
inductive NormalizationResult
  | frozen : NormalizationResult
  | proofInvalid : NormalizationResult
  | success : NormalizationResult
  deriving DecidableEq

/-- Functional specification for normalization -/
def verifyNormalizationBytecodeResult
    (oracle : NormalizationNativeOracle)
    (storeRef : RefValue)
    (proofRef : RefValue)
    (ms : MachineState) : NormalizationResult :=
  -- Check 1: Store exists and not frozen
  match ms.heap.get? storeRef with
  | none => .frozen  -- Shouldn't happen with well-formed inputs
  | some store =>
    if store.frozen then
      .frozen
    else
      -- Check 2: Proof verifies
      match oracle.verifyNormalizationProof proofRef with
      | none => .proofInvalid
      | some false => .proofInvalid
      | some true => .success
```

**Test:** `lake build MovementFormal.Experimental.ConfidentialAsset.Normalization.Phase6Composition`

---

### Step 3: Write Shape Lemma - Frozen (45 min)

```lean
/-!
# Shape Lemma: Account Frozen

When store.frozen = true, execution aborts at PC ~3-5.
-/

theorem normalization_shape_frozen
    (oracle : NormalizationNativeOracle)
    (storeRef : RefValue)
    (proofRef : RefValue)
    (cs : CallStack)
    (ms : MachineState)
    (h_store : ms.heap.get? storeRef = some store)
    (h_frozen : store.frozen = true)
    : run env (normalizationInitialState storeRef proofRef) cs ms =
        .error "account is frozen" := by
  -- Unfold run to start stepping
  unfold run
  unfold normalizationInitialState
  
  -- Step PC 0: ImmBorrowField (borrow store.frozen)
  rw [step_pc0_immBorrowField_frozen oracle storeRef proofRef cs ms h_store]
  
  -- Step PC 1: ReadRef (read frozen flag)
  unfold run
  rw [step_pc1_readRef_frozen oracle storeRef proofRef cs ms h_frozen]
  
  -- Step PC 2: Not (negate frozen flag)
  unfold run
  rw [step_pc2_not oracle storeRef proofRef cs ms]
  
  -- Step PC 3: BrFalse (branch taken because frozen=true → !frozen=false)
  unfold run
  rw [step_pc3_brFalse_frozen oracle storeRef proofRef cs ms h_frozen]
  
  -- Now at error path PC ~8
  unfold run
  rw [step_pc8_ldConst_errorCode oracle storeRef proofRef cs ms]
  
  unfold run
  rw [step_pc9_abort oracle storeRef proofRef cs ms]
  
  -- Abort returns .error
  rfl
```

**Tips:**
- Use step lemmas from Phase 4 (already proven)
- Chain with `rw [step_pc<N>_<name> ...]`
- Unfold `run` between each step
- Final `rfl` closes proof once `.error = .error`

---

### Step 4: Write Shape Lemma - Proof Invalid (45 min)

```lean
/-!
# Shape Lemma: Proof Verification Failed

When oracle returns some(false), execution aborts at PC ~14.
-/

theorem normalization_shape_proofInvalid
    (oracle : NormalizationNativeOracle)
    (storeRef : RefValue)
    (proofRef : RefValue)
    (cs : CallStack)
    (ms : MachineState)
    (h_store : ms.heap.get? storeRef = some store)
    (h_not_frozen : store.frozen = false)
    (h_verify : oracle.verifyNormalizationProof proofRef = some false)
    : run env (normalizationInitialState storeRef proofRef) cs ms =
        .error "proof verification failed" := by
  unfold run
  unfold normalizationInitialState
  
  -- PCs 0-3: Frozen check (passes)
  rw [step_pc0_immBorrowField_frozen oracle storeRef proofRef cs ms h_store]
  unfold run
  rw [step_pc1_readRef_frozen oracle storeRef proofRef cs ms h_not_frozen]
  unfold run
  rw [step_pc2_not oracle storeRef proofRef cs ms]
  unfold run
  rw [step_pc3_brFalse_notFrozen oracle storeRef proofRef cs ms h_not_frozen]
  
  -- PCs 4-6: Proof verification (fails)
  unfold run
  rw [step_pc4_immBorrowLoc_proof oracle storeRef proofRef cs ms]
  unfold run
  rw [step_pc5_call_verify_proof oracle storeRef proofRef cs ms h_verify]
  unfold run
  rw [step_pc6_brFalse_proofInvalid oracle storeRef proofRef cs ms h_verify]
  
  -- PCs 14-15: Error path
  unfold run
  rw [step_pc14_ldConst_errorCode oracle storeRef proofRef cs ms]
  unfold run
  rw [step_pc15_abort oracle storeRef proofRef cs ms]
  
  rfl
```

---

### Step 5: Write Shape Lemma - Success (60-90 min)

```lean
/-!
# Shape Lemma: Success

When not frozen and proof valid, execution succeeds.
-/

theorem normalization_shape_success
    (oracle : NormalizationNativeOracle)
    (storeRef : RefValue)
    (proofRef : RefValue)
    (cs : CallStack)
    (ms : MachineState)
    (h_store : ms.heap.get? storeRef = some store)
    (h_not_frozen : store.frozen = false)
    (h_verify : oracle.verifyNormalizationProof proofRef = some true)
    (h_extract : oracle.extractNormalizedChunks proofRef = some new_chunks)
    : run env (normalizationInitialState storeRef proofRef) cs ms =
        .returned [] ms' := by
  unfold run
  unfold normalizationInitialState
  
  -- PCs 0-3: Frozen check (passes)
  rw [step_pc0_immBorrowField_frozen ...]
  unfold run
  rw [step_pc1_readRef_frozen ...]
  unfold run
  rw [step_pc2_not ...]
  unfold run
  rw [step_pc3_brFalse_notFrozen ...]
  
  -- PCs 4-6: Proof verification (succeeds)
  unfold run
  rw [step_pc4_immBorrowLoc_proof ...]
  unfold run
  rw [step_pc5_call_verify_proof ... h_verify]
  unfold run
  rw [step_pc6_brFalse_proofValid ...]
  
  -- PCs 7-11: Extract and update balance
  unfold run
  rw [step_pc7_immBorrowLoc_proof ...]
  unfold run
  rw [step_pc8_call_extractChunks ... h_extract]
  unfold run
  rw [step_pc9_mutBorrowField_balance ...]
  unfold run
  rw [step_pc10_moveLoc_chunks ...]
  unfold run
  rw [step_pc11_writeRef ...]
  
  -- PC 12: Ret
  unfold run
  rw [step_pc12_ret ...]
  
  rfl
```

**Note:** This is the longest shape lemma (happy path chains through all PCs).

---

### Step 6: Write Main Composition Theorem (30 min)

```lean
/-!
# Main Composition Theorem

Connects bytecode execution to functional specification.
-/

/-- Helper: Convert functional result to execution result -/
def matchNormalizationResult (r : NormalizationResult) : ExecutionResult :=
  match r with
  | .frozen => .error "account is frozen"
  | .proofInvalid => .error "proof verification failed"
  | .success => .returned [] ms'  -- ms' is updated machine state

theorem normalization_eval_equiv_functional_sim
    (oracle : NormalizationNativeOracle)
    (storeRef : RefValue)
    (proofRef : RefValue)
    (cs : CallStack)
    (ms : MachineState)
    : run env (normalizationInitialState storeRef proofRef) cs ms =
        matchNormalizationResult (verifyNormalizationBytecodeResult oracle storeRef proofRef ms) := by
  -- Unfold functional spec
  unfold verifyNormalizationBytecodeResult
  unfold matchNormalizationResult
  
  -- Case-split on store existence
  cases h_store : ms.heap.get? storeRef
  case none =>
    -- Shouldn't happen with well-formed inputs
    sorry  -- Or prove unreachable
  case some store =>
    -- Case-split on frozen
    cases h_frozen : store.frozen
    case true =>
      -- Dispatch to frozen shape lemma
      exact normalization_shape_frozen oracle storeRef proofRef cs ms h_store h_frozen
    case false =>
      -- Case-split on proof verification
      cases h_verify : oracle.verifyNormalizationProof proofRef
      case none =>
        -- Oracle failure (shouldn't happen with well-formed inputs)
        sorry  -- Or handle explicitly
      case some proof_valid =>
        cases proof_valid
        case false =>
          -- Dispatch to proof invalid shape lemma
          exact normalization_shape_proofInvalid oracle storeRef proofRef cs ms h_store h_frozen h_verify
        case true =>
          -- Dispatch to success shape lemma
          -- Need extract hypothesis
          cases h_extract : oracle.extractNormalizedChunks proofRef
          case none =>
            sorry  -- Unreachable if verify succeeded
          case some new_chunks =>
            exact normalization_shape_success oracle storeRef proofRef cs ms h_store h_frozen h_verify h_extract
```

---

### Step 7: Build and Test (15 min)

```bash
# Build
lake build MovementFormal.Experimental.ConfidentialAsset.Normalization.Phase6Composition

# Expected: Build succeeds in < 1 minute

# Check for axioms
../../../../scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Normalization.Phase6Composition

# Expected: 0 temporary axioms (only permanent crypto axioms from Phase 4)
```

---

### Step 8: Integration Test (15 min)

```bash
# Run full verification suite
cd ../../../../
./audit/verify-ca.sh --lean --operation normalization

# Expected output:
# ✅ Phase 4 (EvalEquiv): PASS
# ✅ Phase 6 (Composition): PASS
# Build time: < 1 minute
# Axioms: 5 permanent, 0 temporary
```

---

## Step-by-Step: Withdrawal

**Operation:** Withdrawal  
**Estimated time:** 2-4 hours  
**Lines of code:** ~200  
**Complexity:** Similar to Normalization, one additional guard (balance check)

**Differences from Normalization:**
- +1 shape lemma: insufficient balance error path
- +1 oracle call: extract withdrawal amount

**Implementation strategy:** Follow Normalization pattern, add balance check case-split

**Key theorem:**
```lean
theorem withdrawal_shape_insufficientBalance
    (oracle : WithdrawalNativeOracle)
    (storeRef : RefValue)
    (proofRef : RefValue)
    (cs : CallStack)
    (ms : MachineState)
    (h_not_frozen : store.frozen = false)
    (h_verify : oracle.verifyWithdrawalProof proofRef = some true)
    (h_amount : oracle.extractWithdrawalAmount proofRef = amount)
    (h_balance : sum_balance_chunks store.pending_balance < amount)
    : run env (withdrawalInitialState storeRef proofRef) cs ms =
        .error "insufficient balance" := by
  -- Chain through PCs 0-6 (frozen + proof checks pass)
  -- Then show PC 7-9 (balance check fails, branch to error)
  sorry  -- ~60-90 min to complete
```

---

## Step-by-Step: Rotation

**Operation:** Rotation  
**Estimated time:** 4-6 hours  
**Lines of code:** ~250  
**Complexity:** Medium (state mutation via writeRef)

**Differences from Normalization:**
- +2 oracle calls: extract new public key, extract re-encrypted chunks
- +State mutation: Must thread heap updates through proof
- +Heap assertions: Final state must reflect updated public_key and chunks

**Critical challenge:** Heap threading

**Example:**
```lean
theorem rotation_shape_success
    ...
    (h_verify : oracle.verifyRotationProof proofRef = some true)
    (h_extract_key : oracle.extractNewPublicKey proofRef = some new_key)
    (h_extract_chunks : oracle.extractReEncryptedChunks proofRef = some new_chunks)
    : run env (rotationInitialState storeRef proofRef) cs ms =
        .returned [] ms' ∧
        ms'.heap.get? storeRef = some (store with
          public_key := new_key,
          pending_balance := new_chunks) := by
  -- Chain through all PCs
  -- At PC 15 (writeRef for public_key):
  have h_heap1 : ms1.heap = ms.heap.update storeRef.public_key new_key := by
    -- Prove heap update
  -- At PC 18 (writeRef for pending_balance):
  have h_heap2 : ms2.heap = ms1.heap.update storeRef.pending_balance new_chunks := by
    -- Prove heap update
  -- Final state combines both updates
  constructor
  · -- First goal: execution succeeds
    sorry  -- Chain all PCs
  · -- Second goal: heap contains updated store
    sorry  -- Combine h_heap1 and h_heap2
```

**Estimated breakdown:**
- Functional sim: 30 min
- Frozen shape lemma: 45 min
- Proof invalid shape lemma: 45 min
- Success shape lemma (with heap threading): 2-3 hours
- Main theorem: 45 min
- Testing: 30 min

---

## Step-by-Step: Transfer

**Operation:** Transfer  
**Estimated time:** 8-12 hours  
**Lines of code:** ~450  
**Complexity:** High (dual-party, 4+ execution paths)

**Differences from others:**
- +Dual state: sender and receiver stores
- +Allow list check: recipient must allow sender
- +4 distinct error paths: sender frozen, receiver frozen, recipient rejected, proof invalid
- +Heap threading: Updates both stores

**Shape lemmas needed:**
1. `transfer_shape_senderFrozen` (~60 min)
2. `transfer_shape_receiverFrozen` (~60 min)
3. `transfer_shape_recipientRejected` (~60 min)
4. `transfer_shape_proofInvalid` (~60 min)
5. `transfer_shape_success` (~4-6 hours)

**Success shape lemma complexity:**

```lean
theorem transfer_shape_success
    (oracle : TransferNativeOracle)
    (senderStoreRef : RefValue)
    (receiverStoreRef : RefValue)
    (proofRef : RefValue)
    (sender_addr : Address)
    (cs : CallStack)
    (ms : MachineState)
    -- Preconditions (all guards pass)
    (h_sender_not_frozen : sender_store.frozen = false)
    (h_receiver_not_frozen : receiver_store.frozen = false)
    (h_allowed : is_allowed receiver_store.allow_list sender_addr = true)
    (h_verify : oracle.verifyTransferProof proofRef = some true)
    (h_extract_sender : oracle.extractSenderChunk proofRef = some sender_chunk)
    (h_extract_receiver : oracle.extractReceiverChunk proofRef = some receiver_chunk)
    : run env (transferInitialState senderStoreRef receiverStoreRef proofRef sender_addr) cs ms =
        .returned [] ms' ∧
        ms'.heap.get? senderStoreRef = some (sender_store with
          pending_balance := sender_store.pending_balance.push sender_chunk) ∧
        ms'.heap.get? receiverStoreRef = some (receiver_store with
          pending_balance := receiver_store.pending_balance.push receiver_chunk) := by
  -- This is the longest proof in Phase 6 (~300-400 lines)
  -- Chain through all 24 PCs
  -- Thread dual heap updates
  sorry  -- 4-6 hours to complete
```

**Recommended strategy:**
- Work in 2-hour sessions
- Complete one shape lemma per session
- Leave `transfer_shape_success` for last (most complex)
- Consider pair programming for success case

---

## Testing and Validation

### Test 1: Build Time

```bash
# Profile each operation
for op in Normalization Withdrawal Rotation Transfer; do
  ./scripts/profile_lean_build.sh MovementFormal.Experimental.ConfidentialAsset.$op.Phase6Composition
done

# Expected:
# Normalization: < 1 min
# Withdrawal: < 1 min
# Rotation: < 1 min
# Transfer: < 2 min (largest)
```

**If build time > 2 min:** Apply optimizations (see PERFORMANCE_TUNING_DEEP_DIVE.md)

---

### Test 2: Axiom Count

```bash
# Check for temporary axioms
./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Normalization.Phase6Composition

# Expected: 0 temporary axioms
# (Only permanent crypto axioms from Phase 4)
```

**If temporary axioms found:** Replace `sorry` with proof or axiomatize permanently with justification

---

### Test 3: Integration with Phase 4

```bash
# Verify Phase 6 builds on Phase 4
lake build MovementFormal.Experimental.ConfidentialAsset.Normalization

# Should build both EvalEquiv (Phase 4) and Phase6Composition
```

---

### Test 4: Cross-Operation Consistency

```bash
# Check pattern consistency across operations
./scripts/compare_verification_stacks.sh --all --semantics

# Should report consistent abort codes and semantics
```

---

## Common Patterns

### Pattern: Chaining Multiple PCs

```lean
-- Bad (verbose):
theorem shape_success : ... := by
  unfold run
  rw [step_pc0]
  unfold run
  rw [step_pc1]
  unfold run
  rw [step_pc2]
  -- ... (repeat 20 times)

-- Good (batched):
theorem shape_success : ... := by
  unfold run
  rw [step_pc0]
  simp only [run]  -- Unfold run multiple times at once
  rw [step_pc1, step_pc2, step_pc3, step_pc4]  -- Batch rewrites
  simp only [run]
  rw [step_pc5, step_pc6, step_pc7, step_pc8]
  -- ...
```

**Benefit:** 2-3× faster compilation

---

### Pattern: Dealing with `sorry` in Shape Lemmas

```lean
-- During development, keep sorry with comment
theorem shape_success : ... := by
  -- PCs 0-3: Frozen check
  rw [step_pc0, step_pc1, step_pc2, step_pc3]
  sorry  -- TODO: Continue from PC 4 (proof check)

-- When ready, fill in incrementally
theorem shape_success : ... := by
  -- PCs 0-3: Frozen check
  rw [step_pc0, step_pc1, step_pc2, step_pc3]
  -- PCs 4-6: Proof check
  unfold run
  rw [step_pc4, step_pc5, step_pc6]
  sorry  -- TODO: Continue from PC 7 (balance update)
```

**Strategy:** Complete one section at a time, test builds frequently

---

### Pattern: Heap Threading in State Mutation

```lean
-- When PC updates heap (writeRef), thread updated state through
theorem step_pc15_writeRef :
    step env (state 15 ... ms) = .ok (state 16 ... ms') := by
  -- ms' = ms with heap updated at ref
  let ms' := ms.update_heap ref new_value
  
  rw [state]
  rw [step_writeRef]
  
  -- Prove heap update
  have h : ms'.heap.get? ref = some new_value := by
    simp only [MachineState.update_heap]
    rfl
  
  simp only [h]
  rfl

-- Later PCs must use ms', not ms
theorem step_pc16_next :
    step env (state 16 ... ms') = ... := by
  -- Use ms' (updated heap)
```

---

## Summary

**Phase 6 completion checklist:**

**Per operation:**
- [ ] Functional simulation defined
- [ ] All shape lemmas complete (no `sorry`)
- [ ] Main composition theorem proven
- [ ] Build time < 2 min
- [ ] 0 temporary axioms
- [ ] Integration test passes

**Overall:**
- [ ] 4 operations complete (Normalization, Withdrawal, Rotation, Transfer)
- [ ] All builds in < 5 min total
- [ ] Documentation updated (VERIFICATION_PROGRESS_SUMMARY.md)
- [ ] CI/CD workflows passing

**Estimated timeline:**
- Week 1: Normalization (3-5h) + Withdrawal (2-4h) = 5-9 hours
- Week 2: Rotation (4-6h) + Transfer (8-12h) = 12-18 hours
- **Total: 2-3 weeks at 10-15 hours/week**

**Next steps after Phase 6:**
1. Update VERIFICATION_PROGRESS_SUMMARY.md (Phase 6 ✅ 100%)
2. Apply ristretto255 patches (unblocks Phases 2/3/5)
3. Run Move Prover verification (Phases 2/3/5)
4. Publish Docker image (Phase 7)

---

**Good luck with Phase 6! You're in the final stretch of the CA formal verification effort. 🚀**
