# MSL-to-Lean Coordination Guide

**Purpose:** Practical workflow for keeping MSL specifications and Lean proofs synchronized across the verification lifecycle.

**Audience:** Formal verification engineers working on both MSL and Lean stacks.

**Scope:** Coordination patterns, consistency checks, update workflows, cross-stack validation.

**Status:** Production-ready patterns for CA verification.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Coordination Architecture](#2-coordination-architecture)
3. [Consistency Guarantees](#3-consistency-guarantees)
4. [Update Workflows](#4-update-workflows)
5. [Cross-Stack Validation](#5-cross-stack-validation)
6. [Common Patterns](#6-common-patterns)
7. [Troubleshooting](#7-troubleshooting)
8. [Maintenance](#8-maintenance)

---

## 1. Overview

### 1.1 Why Coordinate MSL and Lean?

**MSL and Lean verify different aspects:**

```
MSL (Move Specification Language):
  - State-level properties (balance preservation, frame conditions)
  - Human-readable specifications
  - Automatic VC generation
  - Accessible to Move developers

Lean 4:
  - Bytecode-level verification
  - Deep mathematical proofs
  - Composition and equivalence
  - Rigorous but complex
```

**Both are necessary:**
- MSL provides **high-level guarantees** (what the operation achieves)
- Lean provides **low-level guarantees** (how the bytecode implements it)
- Together: **end-to-end correctness** from intent to execution

**Risk if uncoordinated:**
- MSL and Lean verify different properties → gaps in coverage
- Specifications drift apart → inconsistent claims
- Abort codes mismatch → runtime errors
- Oracle modeling diverges → unsound proofs

**Solution:** Systematic coordination workflow ensuring both stacks stay aligned.

### 1.2 Coordination Goals

**Goal 1: Semantic alignment**
- MSL spec and Lean proof verify the same property
- Example: Both prove "balance preservation"

**Goal 2: Abort code consistency**
- MSL `aborts_if` conditions match Lean abort paths
- Example: Both specify abort code `65537` for invalid proof

**Goal 3: Oracle coherence**
- MSL `pragma opaque` and Lean axioms agree on oracle behavior
- Example: Both model `verify_proof_native` as returning bool

**Goal 4: Maintainability**
- Changes to Move code trigger coordinated updates in both stacks
- No stack left behind when requirements evolve

### 1.3 Coordination Challenges

**Challenge 1: Different abstraction levels**
- MSL operates on symbolic state (Move values)
- Lean operates on bytecode (instruction sequences)
- Must bridge the semantic gap

**Challenge 2: Different proof strategies**
- MSL: automatic VC generation, SMT solver
- Lean: manual PC-chaining, step lemmas
- Update effort differs between stacks

**Challenge 3: Different expressiveness**
- MSL can't model elliptic curve operations (pragma opaque)
- Lean can model them (but axiomatizes for crypto)
- Must coordinate what each stack proves vs assumes

**Challenge 4: Asynchronous progress**
- Lean proofs complete first (Phase 1, Phase 6)
- MSL blocked on ristretto255 patches
- Must maintain consistency even when one stack ahead

**Solution:** This guide provides coordination patterns addressing all challenges.

---

## 2. Coordination Architecture

### 2.1 Three-Layer Model

**Verification stack layers:**

```
┌─────────────────────────────────────────────────┐
│ Layer 1: Move Source Code                      │
│ - confidential_asset.move                      │
│ - Ground truth for intended behavior           │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ Layer 2: MSL Specifications                    │
│ - confidential_asset.spec.move                 │
│ - State-level properties, abort conditions     │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ Layer 3: Lean Proofs                           │
│ - Registration/EvalEquivRebuild.lean           │
│ - Bytecode-level equivalence to oracle         │
└─────────────────────────────────────────────────┘
```

**Information flow:**

```
Move source changes
    ↓
MSL specs updated (reflect new behavior)
    ↓
Lean proofs updated (reflect new bytecode)
    ↓
Cross-stack validation (difftest, axiom checks)
```

**Coordination points:**
- Move → MSL: Specification accuracy
- MSL → Lean: Semantic alignment
- Lean → Difftest: Transcription accuracy
- All stacks → Audit: Consistency report

### 2.2 Coordination Invariants

**Invariant 1: Abort code agreement**

```
∀ operation, ∀ error condition:
  MSL aborts_with code
  ↔ Lean proves eval = .aborted code
  ↔ Difftest asserts abort_code == code
```

**Example:**

```move
// MSL
spec confidential_transfer_internal {
    aborts_if !verify_transfer_proof(proof) with 65537;
}
```

```lean
-- Lean
theorem transfer_aborts_on_invalid_proof
    (h_oracle : verify_transfer_oracle proof = .verifyFailed)
    : eval env (transferState 0 ...) = .aborted 65537
```

```rust
// Difftest
assert_eq!(result.abort_code(), 65537);
```

**All three must match!**

---

**Invariant 2: Balance preservation**

```
∀ successful transfer:
  MSL ensures: sum_balance(sender) = old(...) - amount
  Lean proves: decrypt(balance[sender]) = old_balance - amount
  Difftest validates: get_balance(sender) == initial - amount
```

---

**Invariant 3: Oracle modeling**

```
∀ native function F:
  MSL pragma opaque F
  ↔ Lean axiom oracle_F : ...
  ↔ Difftest mocks F with oracle result
```

**Example:**

```move
// MSL
pragma opaque = verify_transfer_proof_internal;
```

```lean
-- Lean
axiom verify_transfer_oracle :
  TransferProof → OracleResult
```

```rust
// Difftest
let oracle_result = mock_verify_transfer(proof);
```

---

**Invariant 4: Frame conditions**

```
∀ operation, ∀ unmodified state:
  MSL ensures: unchanged[resource@address]
  Lean proves: state.memory[address] = old_state.memory[address]
```

### 2.3 Coordination Workflow

**Standard workflow for new operation:**

```
Step 1: Design (1-2 hours)
  - Draft Move implementation
  - Identify properties to verify
  - Determine oracle boundary (crypto functions)
    ↓
Step 2: Implement Move (2-4 hours)
  - Write Move source
  - Compile and test locally
  - Document intended behavior
    ↓
Step 3: Write MSL spec (1-2 hours)
  - Balance preservation
  - Abort conditions
  - Frame conditions
  - Pragma opaque for crypto
    ↓
Step 4: Transcribe to Lean (3-6 hours)
  - Disassemble bytecode
  - Create Lean state definitions
  - Write step lemmas
    ↓
Step 5: Prove in Lean (6-12 hours)
  - Complete PC-chaining proof
  - Prove equivalence to oracle
  - Check axiom count
    ↓
Step 6: Cross-validate (1 hour)
  - Run difftest (all stacks)
  - Check abort code consistency
  - Verify oracle modeling alignment
    ↓
Step 7: Document (1 hour)
  - Update CLAIMS.md
  - Update AXIOM_INVENTORY.md
  - Update coverage reports
```

**Total effort:** 15-28 hours per operation (depending on complexity).

---

## 3. Consistency Guarantees

### 3.1 Abort Code Consistency

**Requirement:** All stacks must agree on abort codes for each error condition.

**Enforcement:**

**Step 1: Define abort codes in Move**

```move
// Move constants (source of truth)
const EVERIFY_FAILED: u64 = 65537;
const EINVALID_PROOF_FORMAT: u64 = 524289;
const EINSUFFICIENT_BALANCE: u64 = 524290;
```

**Step 2: Reference in MSL spec**

```move
spec confidential_transfer_internal {
    aborts_if !verify_transfer_proof(proof) with EVERIFY_FAILED;
    aborts_if !has_sufficient_balance(sender, amount) with EINSUFFICIENT_BALANCE;
}
```

**Step 3: Transcribe exact values to Lean**

```lean
-- Lean constants (must match Move exactly)
def EVERIFY_FAILED : UInt64 := 65537
def EINSUFFICIENT_BALANCE : UInt64 := 524290

theorem transfer_aborts_on_invalid_proof :
    eval env state = .aborted EVERIFY_FAILED := by
  -- Proof using exact constant
  ...
```

**Step 4: Assert in difftest**

```rust
// Difftest (validates consistency)
const EVERIFY_FAILED: u64 = 65537;

#[test]
fn test_transfer_invalid_proof() {
    let result = execute_transfer(invalid_proof);
    assert_eq!(result.abort_code(), EVERIFY_FAILED);
}
```

**Automated check:**

```bash
# Script: check_abort_code_consistency.sh
grep -r "EVERIFY_FAILED.*65537" sources/ specs/ lean/ difftest/

# Should find:
# sources/confidential_asset.move: const EVERIFY_FAILED: u64 = 65537;
# specs/confidential_asset.spec.move: aborts_if ... with EVERIFY_FAILED;
# lean/.../Registration.lean: def EVERIFY_FAILED : UInt64 := 65537
# difftest/tests/registration.rs: const EVERIFY_FAILED: u64 = 65537;

# If any mismatch → CI fails
```

### 3.2 Balance Preservation Consistency

**Requirement:** MSL and Lean both prove balance is preserved across operations.

**MSL version (state-level):**

```move
spec confidential_transfer_internal {
    let sender_addr = signer::address_of(sender);
    let receiver_addr = signer::address_of(receiver);
    
    ensures sum_balance(global<ConfidentialAssetStore>(sender_addr).balance) ==
            old(sum_balance(global<ConfidentialAssetStore>(sender_addr).balance)) - amount;
    
    ensures sum_balance(global<ConfidentialAssetStore>(receiver_addr).balance) ==
            old(sum_balance(global<ConfidentialAssetStore>(receiver_addr).balance)) + amount;
}

// Helper function (Ghost code)
spec fun sum_balance(balance: ConfidentialBalance): u64 {
    decrypt_balance(balance)  // Abstract function
}
```

**Lean version (bytecode-level):**

```lean
theorem transfer_preserves_balance
    (sender : Address)
    (receiver : Address)
    (amount : Nat)
    (h_oracle : verify_transfer_oracle proof = .success)
    : let ms' := eval env (transferState 0 sender receiver amount) cs ms
      in (decrypt_balance (get_balance ms' sender) = decrypt_balance (get_balance ms sender) - amount) ∧
         (decrypt_balance (get_balance ms' receiver) = decrypt_balance (get_balance ms receiver) + amount)
  := by
    -- Proof by PC-chaining + balance update lemmas
    unfold eval
    rw [transfer_eval_equiv h_oracle]
    constructor
    · -- Sender balance decreases
      rw [update_balance_sender_decreases]
      ring
    · -- Receiver balance increases
      rw [update_balance_receiver_increases]
      ring
```

**Alignment check:**

| Aspect | MSL | Lean | Consistent? |
|--------|-----|------|-------------|
| Property | sum_balance decreases/increases | decrypt_balance decreases/increases | ✅ |
| Amount | `amount` | `amount` | ✅ |
| Condition | On success | `h_oracle = .success` | ✅ |

**Difftest validation:**

```rust
#[test]
fn test_transfer_balance_preservation() {
    let initial_sender = get_balance(sender);
    let initial_receiver = get_balance(receiver);
    let amount = 100;
    
    execute_transfer(sender, receiver, amount, valid_proof);
    
    assert_eq!(get_balance(sender), initial_sender - amount);
    assert_eq!(get_balance(receiver), initial_receiver + amount);
}
```

### 3.3 Oracle Modeling Consistency

**Requirement:** MSL pragma opaque and Lean axioms agree on oracle interfaces.

**Pattern:**

**1. Identify oracle boundary (crypto functions that can't be fully verified)**

```
Native functions requiring oracles:
- verify_registration_proof_internal
- verify_transfer_proof_internal
- verify_withdrawal_proof_internal
- verify_rotation_proof_internal
- ristretto255_point_add
- ristretto255_scalar_mul
```

**2. MSL pragma opaque**

```move
// Mark as opaque (Move Prover won't try to verify internals)
pragma opaque = verify_transfer_proof_internal;

spec verify_transfer_proof_internal {
    // Abstract specification
    ensures result == true ⟹ is_valid_transfer_proof(proof);
    ensures result == false ⟹ !is_valid_transfer_proof(proof);
}
```

**3. Lean oracle axiom**

```lean
-- Oracle type
inductive TransferOracleResult
  | success
  | verifyFailed
  | error

-- Oracle axiom (matches MSL abstract spec)
axiom verify_transfer_oracle :
  TransferProof → TransferOracleResult

-- Oracle correctness (assumed, not proven)
axiom verify_transfer_oracle_correct :
  ∀ proof,
    verify_transfer_oracle proof = .success ↔ is_valid_transfer_proof proof
```

**4. Difftest mock**

```rust
// Mock oracle (matches Lean oracle interface)
fn mock_verify_transfer_oracle(proof: &TransferProof) -> OracleResult {
    if is_valid_transfer_proof(proof) {
        OracleResult::Success
    } else {
        OracleResult::VerifyFailed
    }
}
```

**Alignment:**

| Stack | Oracle Interface | Oracle Semantics |
|-------|------------------|------------------|
| MSL | `bool` return | `true` ⟹ valid, `false` ⟹ invalid |
| Lean | `TransferOracleResult` | `.success` ⟹ valid, `.verifyFailed` ⟹ invalid |
| Difftest | `OracleResult` enum | `Success` ⟹ valid, `VerifyFailed` ⟹ invalid |

**Consistent? ✅** (modulo representation differences)

### 3.4 Frame Condition Consistency

**Requirement:** MSL and Lean agree on what state is NOT modified.

**MSL frame conditions:**

```move
spec confidential_transfer_internal {
    // What IS modified
    modifies global<ConfidentialAssetStore>(sender_addr);
    modifies global<ConfidentialAssetStore>(receiver_addr);
    
    // What is NOT modified (implicit: everything else)
    ensures ∀ addr : address where addr != sender_addr && addr != receiver_addr,
            global<ConfidentialAssetStore>(addr) == old(global<ConfidentialAssetStore>(addr));
}
```

**Lean frame conditions:**

```lean
theorem transfer_frame_condition
    (addr : Address)
    (h_not_sender : addr ≠ sender)
    (h_not_receiver : addr ≠ receiver)
    : let ms' := eval env (transferState 0 sender receiver amount) cs ms
      in get_balance ms' addr = get_balance ms addr
  := by
    -- Proof: transfer only modifies sender and receiver
    unfold eval
    rw [transfer_eval_equiv]
    apply balance_unchanged_for_other_addresses
    · exact h_not_sender
    · exact h_not_receiver
```

**Alignment:**

| Aspect | MSL | Lean |
|--------|-----|------|
| Modified | sender, receiver | sender, receiver |
| Unchanged | all other addresses | all other addresses |
| Proof obligation | Prover checks | Manual proof |

---

## 4. Update Workflows

### 4.1 Move Source Change → Propagation

**Scenario:** Move source code changes (bug fix, feature addition, refactoring).

**Workflow:**

```
Step 1: Update Move source
    ↓
Step 2: Recompile bytecode
    ↓
Step 3: Check if bytecode changed
    ↓ (if bytecode changed)
Step 4: Update MSL spec (if behavior changed)
    ↓
Step 5: Re-transcribe Lean (if bytecode changed)
    ↓
Step 6: Update Lean proofs (if semantics changed)
    ↓
Step 7: Re-run difftest
    ↓
Step 8: Update documentation
```

**Example: Adding balance check to transfer**

**Step 1: Move source change**

```move
// Before
public fun confidential_transfer_internal(
    sender: &signer,
    receiver: &signer,
    amount: u64,
    proof: vector<u8>
): u64 {
    let proof_obj = deserialize_transfer_proof(proof);
    if (!verify_transfer_proof_internal(proof_obj)) {
        abort EVERIFY_FAILED
    };
    update_balances(sender, receiver, amount);
    0
}

// After (add balance check)
public fun confidential_transfer_internal(...) {
    let proof_obj = deserialize_transfer_proof(proof);
    if (!verify_transfer_proof_internal(proof_obj)) {
        abort EVERIFY_FAILED
    };
    if (!has_sufficient_balance(sender, amount)) {  // NEW
        abort EINSUFFICIENT_BALANCE                  // NEW
    };
    update_balances(sender, receiver, amount);
    0
}
```

**Step 2: Recompile**

```bash
movement move build
```

**Step 3: Check bytecode diff**

```bash
# Disassemble old and new
movement move disassemble --bytecode old.mv > old.dis
movement move disassemble --bytecode new.mv > new.dis

# Diff
diff old.dis new.dis

# Output: additional instructions for balance check
#   + 15: CopyLoc[0]
#   + 16: CopyLoc[2]
#   + 17: Call has_sufficient_balance
#   + 18: BrTrue 22
#   + 19: LdU64 524290
#   + 20: Abort
#   + 21: Branch 22
#   PC 22: (original code continues)
```

**Bytecode changed → must update Lean!**

**Step 4: Update MSL spec**

```move
spec confidential_transfer_internal {
    aborts_if !verify_transfer_proof(proof) with EVERIFY_FAILED;
    aborts_if !has_sufficient_balance(sender, amount) with EINSUFFICIENT_BALANCE;  // NEW
    ensures sum_balance(sender) == old(...) - amount;
    ensures sum_balance(receiver) == old(...) + amount;
}
```

**Step 5: Re-transcribe Lean**

```lean
def verifyTransferCode : Code := [
  .CopyLoc 0,
  -- ... (original instructions)
  .CopyLoc 0,                                      -- PC 15 (NEW)
  .CopyLoc 2,                                      -- PC 16 (NEW)
  .Call «confidential_asset::has_sufficient_balance», -- PC 17 (NEW)
  .BrTrue 22,                                      -- PC 18 (NEW)
  .LdU64 524290,                                   -- PC 19 (NEW)
  .Abort,                                          -- PC 20 (NEW)
  .Branch 22,                                      -- PC 21 (NEW)
  -- ... (rest of code, PCs shifted)
]
```

**Step 6: Update Lean proofs**

```lean
-- New step lemmas for balance check
theorem transferStep_15_to_16 : ... := by ...
theorem transferStep_16_to_17 : ... := by ...
theorem transferStep_17_to_18 : ... := by ...
theorem transferStep_18_to_19_insufficient : ... := by ...  -- Branch to abort
theorem transferStep_18_to_22_sufficient : ... := by ...    -- Skip abort

-- Update composition proof
theorem transfer_eval_equiv_functional_sim :
    eval env state = ... := by
  cases oracleResult with
  | success =>
    cases balanceCheckResult with  -- NEW case split
    | sufficient =>
      -- Original success path
      rw [transferStep_0_to_1]
      -- ...
      rw [transferStep_18_to_22_sufficient]  -- Skip balance check abort
      -- ... (rest of success path)
    | insufficient =>
      -- New insufficient balance abort path
      rw [transferStep_0_to_1]
      -- ...
      rw [transferStep_18_to_19_insufficient]  -- Branch to abort
      rw [transferStep_19_to_20]               -- Load abort code
      rw [transferStep_20_abort]               -- Abort
      rfl
  | verifyFailed =>
    -- ... (existing failure path)
```

**Step 7: Re-run difftest**

```bash
cargo test test_transfer_insufficient_balance --release

# New test case
#[test]
fn test_transfer_insufficient_balance() {
    let sender = create_account_with_balance(50);
    let receiver = create_account();
    let amount = 100;  // More than sender has
    let proof = generate_valid_proof(sender, receiver, amount);
    
    let result = execute_transfer(sender, receiver, amount, proof);
    
    assert!(result.is_aborted());
    assert_eq!(result.abort_code(), 524290);  // EINSUFFICIENT_BALANCE
}
```

**Step 8: Update documentation**

```markdown
# CLAIMS.md

## Transfer Operation

### Verified Properties
- Balance preservation (sender -= amount, receiver += amount)
- Abort on invalid proof (code 65537)
- Abort on insufficient balance (code 524290)  // NEW

### Abort Conditions
1. Invalid proof: 65537
2. Insufficient balance: 524290  // NEW
```

**Effort estimate:** 4-8 hours for moderate change (new abort condition).

### 4.2 MSL Spec Change → Lean Update

**Scenario:** MSL spec updated without Move code change (clarification, strengthening).

**Example: Strengthen frame condition**

**Before:**

```move
spec confidential_transfer_internal {
    modifies global<ConfidentialAssetStore>(sender_addr);
    modifies global<ConfidentialAssetStore>(receiver_addr);
}
```

**After:**

```move
spec confidential_transfer_internal {
    modifies global<ConfidentialAssetStore>(sender_addr);
    modifies global<ConfidentialAssetStore>(receiver_addr);
    
    // NEW: Explicitly state other accounts unchanged
    ensures ∀ addr : address where addr != sender_addr && addr != receiver_addr,
            global<ConfidentialAssetStore>(addr) == old(global<ConfidentialAssetStore>(addr));
}
```

**Lean update:**

```lean
-- Add corresponding theorem
theorem transfer_preserves_other_balances
    (addr : Address)
    (h_not_sender : addr ≠ sender)
    (h_not_receiver : addr ≠ receiver)
    : get_balance ms' addr = get_balance ms addr
  := by
    -- Proof that transfer doesn't modify other balances
    unfold eval transfer_eval_equiv
    apply memory_update_only_sender_receiver
    · exact h_not_sender
    · exact h_not_receiver
```

**Bytecode unchanged → no transcription update needed.**

**Effort estimate:** 1-2 hours (add theorem, update documentation).

### 4.3 Lean Proof Refactoring

**Scenario:** Lean proofs refactored for clarity/performance, no semantic change.

**Example: Extract common lemma**

**Before (repetitive):**

```lean
theorem transfer_step_5_to_6 :
    step env (state 5 ...) = .inProgress (state 6 ...) := by
  unfold step
  rw [state_code, state_pc]
  simp [verifyTransferCode]
  apply step_copyLoc
  · simp [locals_length]
  · rfl

theorem transfer_step_7_to_8 :
    step env (state 7 ...) = .inProgress (state 8 ...) := by
  unfold step
  rw [state_code, state_pc]
  simp [verifyTransferCode]
  apply step_copyLoc
  · simp [locals_length]
  · rfl

-- Repeated 10 times...
```

**After (refactored with lemma):**

```lean
-- Common lemma for CopyLoc steps
theorem transfer_step_copyLoc
    (pc : Nat)
    (h_code : verifyTransferCode[pc] = .CopyLoc n)
    (h_locals : locals.length > n)
    : step env (state pc ...) = .inProgress (state (pc+1) ...) := by
  unfold step
  rw [state_code, state_pc, h_code]
  apply step_copyLoc
  · exact h_locals
  · rfl

-- Now each step lemma is one line
theorem transfer_step_5_to_6 :
    step env (state 5 ...) = .inProgress (state 6 ...) :=
  transfer_step_copyLoc 5 rfl (by omega)

theorem transfer_step_7_to_8 :
    step env (state 7 ...) = .inProgress (state 8 ...) :=
  transfer_step_copyLoc 7 rfl (by omega)
```

**MSL unchanged → no MSL update needed.**

**Effort estimate:** 2-4 hours (extract lemmas, verify no semantic change).

### 4.4 Axiom Addition/Removal

**Scenario:** New axiom added or temporary axiom removed.

**Example: Remove temporary ristretto255 axiom (when patches land)**

**Before:**

```lean
-- Temporary axiom (waiting for Move Prover ristretto255 support)
axiom ristretto255_add_commutative :
  ∀ (p q : RistrettoPoint),
    ristretto255_point_add p q = ristretto255_point_add q p
```

**After (ristretto255 patches land):**

```lean
-- Now proven, not axiomatized
theorem ristretto255_add_commutative :
  ∀ (p q : RistrettoPoint),
    ristretto255_point_add p q = ristretto255_point_add q p := by
  intro p q
  apply ristretto255_group_law_commutative  -- From crypto library
```

**Update workflow:**

```bash
# 1. Check current axiom count
./scripts/check_axioms.sh
# Output: 23 axioms (21 permanent + 2 temporary)

# 2. Replace axiom with theorem

# 3. Rebuild Lean
lake clean
lake build MovementFormal

# 4. Re-check axiom count
./scripts/check_axioms.sh
# Output: 22 axioms (21 permanent + 1 temporary)

# 5. Update documentation
# AXIOM_INVENTORY.md: mark ristretto255_add_commutative as "removed"
# CLAIMS.md: update claim status from "axiomatized" to "proven"

# 6. CI should pass with reduced axiom count
```

**MSL impact:** None (MSL already uses ristretto255 via pragma opaque).

**Effort estimate:** 1-2 hours (replace axiom, test, document).

---

## 5. Cross-Stack Validation

### 5.1 Automated Consistency Checks

**CI pipeline validates cross-stack consistency:**

```yaml
# .github/workflows/verification-consistency.yaml

name: Cross-Stack Consistency

on: [push, pull_request]

jobs:
  check_abort_codes:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check abort code consistency
        run: ./scripts/check_abort_code_consistency.sh

  check_axioms:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check axiom count
        run: |
          cd lean
          lake build MovementFormal
          ../scripts/check_axioms.sh
          # Fail if > 23 axioms (21 permanent + 2 temporary)
          if [ $(./scripts/check_axioms.sh | wc -l) -gt 23 ]; then
            echo "ERROR: Too many axioms!"
            exit 1
          fi

  check_oracle_alignment:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check oracle modeling alignment
        run: ./scripts/check_oracle_alignment.sh
```

**Consistency check scripts:**

**check_abort_code_consistency.sh:**

```bash
#!/bin/bash
# Check that abort codes are consistent across Move, MSL, Lean, Difftest

set -e

# Extract abort codes from Move constants
move_codes=$(grep "const E.*: u64 = " sources/confidential_asset.move | \
             sed 's/.*const \(E[A-Z_]*\).*= \([0-9]*\);/\1=\2/')

# Check each code appears in MSL, Lean, Difftest
for code_def in $move_codes; do
  code_name=$(echo $code_def | cut -d= -f1)
  code_value=$(echo $code_def | cut -d= -f2)
  
  echo "Checking $code_name ($code_value)..."
  
  # MSL
  if ! grep -q "with $code_name" specs/confidential_asset.spec.move; then
    echo "ERROR: $code_name not found in MSL spec"
    exit 1
  fi
  
  # Lean
  if ! grep -q "def $code_name.*:=.*$code_value" lean/**/*.lean; then
    echo "ERROR: $code_name not found in Lean or value mismatch"
    exit 1
  fi
  
  # Difftest
  if ! grep -q "const $code_name.*=.*$code_value" difftest/**/*.rs; then
    echo "ERROR: $code_name not found in Difftest or value mismatch"
    exit 1
  fi
done

echo "✓ All abort codes consistent"
```

**check_oracle_alignment.sh:**

```bash
#!/bin/bash
# Check that MSL pragma opaque and Lean axioms agree

set -e

# Extract pragma opaque functions from MSL
msl_opaque=$(grep "pragma opaque =" specs/*.spec.move | \
             sed 's/.*pragma opaque = \([a-z_]*\);/\1/')

# Check each has corresponding Lean axiom
for func in $msl_opaque; do
  echo "Checking $func..."
  
  # Lean should have axiom for this function
  if ! grep -q "axiom ${func}_oracle" lean/**/*.lean; then
    echo "ERROR: No Lean axiom for MSL opaque function $func"
    exit 1
  fi
  
  # Difftest should have mock for this function
  if ! grep -q "mock_$func" difftest/**/*.rs; then
    echo "ERROR: No Difftest mock for oracle function $func"
    exit 1
  fi
done

echo "✓ All oracles aligned"
```

### 5.2 Manual Review Checklist

**Before claiming verification complete, manually review:**

**Checklist:**

- [ ] All Move functions have corresponding MSL specs
- [ ] All MSL `aborts_if` conditions proven in Lean
- [ ] All MSL `ensures` properties proven in Lean
- [ ] All Lean axioms justified in AXIOM_INVENTORY.md
- [ ] All abort codes consistent (Move = MSL = Lean = Difftest)
- [ ] All oracle functions modeled consistently (MSL pragma = Lean axiom = Difftest mock)
- [ ] All frame conditions aligned (MSL modifies = Lean memory update)
- [ ] All difftest scenarios cover MSL spec cases
- [ ] Documentation updated (CLAIMS.md, coverage reports)

**Review process:**

```bash
# 1. Run automated checks
./scripts/check_abort_code_consistency.sh
./scripts/check_oracle_alignment.sh
./scripts/check_axioms.sh

# 2. Manually review MSL-Lean alignment
# For each MSL spec:
#   - Find corresponding Lean theorem
#   - Check property is semantically equivalent
#   - Verify proof is complete (no sorry)

# 3. Run full verification suite
./audit/verify-ca.sh

# 4. Check coverage
./scripts/generate_coverage_report.sh

# 5. If all pass → mark as reviewed
```

### 5.3 Difftest as Ground Truth

**Difftest validates both MSL and Lean:**

```
         MSL spec
             ↓ (claims property P)
         Move Prover
             ↓ (generates VCs)
         SMT Solver
             ↓ (proves VCs)
         ✓ Verified

         Lean proof
             ↓ (proves property P)
         Lean kernel
             ↓ (checks proof)
         ✓ Verified

         BUT: Do MSL and Lean agree?
             ↓
         Difftest
             ↓ (executes bytecode in real VM)
         Observes:
         - Abort codes match both specs? ✓
         - Balance changes match both proofs? ✓
         - Oracle results match both models? ✓
         
         → High confidence in consistency
```

**Difftest scenarios cover:**

| Scenario | MSL Coverage | Lean Coverage |
|----------|--------------|---------------|
| Happy path | `ensures` clauses | Success path proof |
| Invalid proof | `aborts_if !verify(...)` | Verify failed path |
| Insufficient balance | `aborts_if !sufficient(...)` | Insufficient balance path |
| Edge cases | Implicit (coverage gaps) | Explicit test cases |

**If difftest fails:**
1. Check if MSL spec wrong
2. Check if Lean proof wrong
3. Check if Move implementation wrong
4. Check if difftest wrong

**Debugging workflow:**

```bash
# Run single difftest with debug output
cargo test test_transfer_invalid_proof -- --nocapture

# Output shows:
# - Expected abort code (from MSL/Lean): 65537
# - Actual abort code (from VM): 65536
# → Mismatch! Investigate.

# Check Lean proof
grep "aborted.*6553" Transfer/EvalEquiv.lean
# Shows: .aborted 65537

# Check MSL spec
grep "with.*EVERIFY" confidential_transfer.spec.move
# Shows: with EVERIFY_FAILED

# Check Move constant
grep "EVERIFY_FAILED" confidential_asset.move
# Shows: const EVERIFY_FAILED: u64 = 65537;

# Check difftest constant
grep "EVERIFY_FAILED" test_transfer.rs
# Shows: const EVERIFY_FAILED: u64 = 65536;  ← BUG FOUND!

# Fix difftest constant, re-run
# Now passes ✓
```

---

## 6. Common Patterns

### 6.1 Crypto Boundary Pattern

**Pattern:** Native crypto functions are opaque in MSL, axiomatized in Lean, mocked in difftest.

**When to use:** Elliptic curve operations, zero-knowledge proofs, complex crypto.

**Example: verify_transfer_proof_internal**

**Move (native implementation):**

```move
native fun verify_transfer_proof_internal(
    proof: &TransferProof
): bool;
```

**MSL (pragma opaque):**

```move
pragma opaque = verify_transfer_proof_internal;

spec verify_transfer_proof_internal {
    pragma opaque;
    
    // Abstract spec (what it means, not how it works)
    ensures result == true ⟹ is_valid_transfer_proof(proof);
    ensures result == false ⟹ !is_valid_transfer_proof(proof);
}

// Ghost function (uninterpreted)
spec fun is_valid_transfer_proof(proof: &TransferProof): bool;
```

**Lean (axiom oracle):**

```lean
-- Oracle result type
inductive TransferOracleResult
  | success
  | verifyFailed
  | error

-- Oracle axiom
axiom verify_transfer_oracle :
  TransferProof → TransferOracleResult

-- Correctness assumption
axiom verify_transfer_oracle_sound :
  ∀ proof,
    verify_transfer_oracle proof = .success →
    is_valid_transfer_proof proof

axiom verify_transfer_oracle_complete :
  ∀ proof,
    is_valid_transfer_proof proof →
    verify_transfer_oracle proof = .success
```

**Difftest (mock):**

```rust
fn mock_verify_transfer_oracle(proof: &TransferProof) -> OracleResult {
    // Simplified check (real implementation is complex Bulletproofs verification)
    if proof.range_proof.is_valid() &&
       proof.sigma_proof.is_valid() &&
       proof.commitment_proof.is_valid() {
        OracleResult::Success
    } else {
        OracleResult::VerifyFailed
    }
}
```

**Alignment:**
- MSL: Declares function opaque, states abstract correctness
- Lean: Axiomatizes oracle, states soundness/completeness
- Difftest: Mocks with simplified check, validates behavior

**Trust:** All three stacks trust the Rust native implementation is correct.

**See:** `audit/AXIOM_INVENTORY.md` for all crypto oracles.

### 6.2 Balance Update Pattern

**Pattern:** MSL specifies balance change, Lean proves bytecode achieves it.

**When to use:** Any operation modifying confidential balances.

**Example: Withdrawal**

**MSL:**

```move
spec confidential_withdraw_internal {
    let addr = signer::address_of(account);
    
    ensures sum_balance(global<ConfidentialAssetStore>(addr).balance) ==
            old(sum_balance(global<ConfidentialAssetStore>(addr).balance)) - amount;
    
    ensures public_balance(account) ==
            old(public_balance(account)) + amount;
}
```

**Lean:**

```lean
theorem withdrawal_updates_balances
    (account : Address)
    (amount : Nat)
    (h_oracle : verify_withdrawal_oracle proof = .success)
    : let ms' := eval env (withdrawalState 0 account amount) cs ms
      in (decrypt_balance (get_confidential_balance ms' account) =
          decrypt_balance (get_confidential_balance ms account) - amount) ∧
         (get_public_balance ms' account =
          get_public_balance ms account + amount)
  := by
    unfold eval
    rw [withdrawal_eval_equiv h_oracle]
    constructor
    · -- Confidential balance decreases
      rw [update_confidential_balance_withdrawal]
      ring
    · -- Public balance increases
      rw [update_public_balance_withdrawal]
      ring
```

**Alignment:**
- Both prove confidential balance decreases by `amount`
- Both prove public balance increases by `amount`
- MSL uses `sum_balance` (decrypt), Lean uses `decrypt_balance` (same semantics)

### 6.3 Abort Condition Pattern

**Pattern:** MSL `aborts_if` mirrors Lean abort path proof.

**When to use:** Any error condition leading to abort.

**Example: Registration with invalid proof**

**MSL:**

```move
spec verify_registration_proof_internal {
    aborts_if !verify_registration_proof(proof) with EVERIFY_FAILED;
}
```

**Lean:**

```lean
theorem registration_aborts_on_invalid_proof
    (h_oracle : verify_registration_oracle proof = .verifyFailed)
    : eval env (registrationState 0 proofRef) cs ms =
        .aborted 65537
  := by
    unfold eval
    rw [registration_eval_equiv]
    cases h_oracle
    -- Proof follows verify failed path
    rw [registrationStep_0_to_1]
    -- ... (steps leading to abort)
    rw [registrationStep_N_ldU64]  -- Load abort code 65537
    rw [registrationStep_N1_abort] -- Execute abort
    rfl
```

**Difftest:**

```rust
#[test]
fn test_registration_invalid_proof() {
    let proof = generate_invalid_proof();
    let result = execute_registration(proof);
    
    assert!(result.is_aborted());
    assert_eq!(result.abort_code(), 65537);
}
```

**Alignment:**
- MSL: Declares abort condition and code
- Lean: Proves bytecode aborts with that code
- Difftest: Validates VM aborts with that code

### 6.4 Frame Condition Pattern

**Pattern:** MSL `modifies` mirrors Lean memory update proof.

**When to use:** Documenting what state is/isn't changed.

**Example: Transfer frame**

**MSL:**

```move
spec confidential_transfer_internal {
    modifies global<ConfidentialAssetStore>(sender_addr);
    modifies global<ConfidentialAssetStore>(receiver_addr);
    
    // Implicit: all other addresses unchanged
}
```

**Lean:**

```lean
theorem transfer_frame_other_addresses
    (addr : Address)
    (h_not_sender : addr ≠ sender)
    (h_not_receiver : addr ≠ receiver)
    : get_balance ms' addr = get_balance ms addr
  := by
    unfold ms' eval
    rw [transfer_eval_equiv]
    -- Proof: memory update only touches sender and receiver
    apply memory_update_preserves_others
    · exact h_not_sender
    · exact h_not_receiver
```

**Alignment:**
- MSL: Declares modified resources
- Lean: Proves unmodified resources unchanged

---

## 7. Troubleshooting

### 7.1 Abort Code Mismatch

**Problem:** Difftest shows different abort code than MSL/Lean.

**Symptoms:**

```
Difftest output:
  expected: 65537 (EVERIFY_FAILED)
  actual: 524289 (EINVALID_PROOF_FORMAT)
```

**Diagnosis:**

```bash
# Check Lean proof
grep "aborted" Registration/EvalEquiv.lean
# Shows: .aborted 65537

# Check MSL spec
grep "aborts_if.*verify" registration.spec.move
# Shows: aborts_if !verify_proof(...) with EVERIFY_FAILED

# Check Move bytecode
movement move disassemble --bytecode registration.mv | grep "LdU64"
# Shows: LdU64 524289  ← Mismatch!

# Root cause: Move code changed but Lean transcription not updated
```

**Fix:**

```bash
# Re-transcribe bytecode
# Update Lean code definition with correct abort code
# Rebuild and test
lake build MovementFormal
cargo test test_registration_invalid_proof
```

### 7.2 MSL and Lean Prove Different Properties

**Problem:** MSL spec and Lean theorem claim different properties.

**Example:**

```move
// MSL (wrong)
spec transfer {
    ensures balance[sender] >= 0;  // Only ensures non-negative
}
```

```lean
-- Lean (correct)
theorem transfer_preserves_balance :
    balance[sender]' = balance[sender] - amount
    ∧ balance[receiver]' = balance[receiver] + amount
  := by ...
```

**Diagnosis:** MSL spec is weaker than Lean proof (doesn't state balance preservation).

**Fix:** Strengthen MSL spec to match Lean:

```move
spec transfer {
    ensures balance[sender] == old(balance[sender]) - amount;
    ensures balance[receiver] == old(balance[receiver]) + amount;
}
```

### 7.3 Oracle Modeling Divergence

**Problem:** MSL pragma opaque and Lean axiom have different interfaces.

**Example:**

```move
// MSL
pragma opaque = verify_proof;
spec verify_proof(proof: Proof): bool;
```

```lean
-- Lean (different return type)
axiom verify_proof_oracle : Proof → Option Bool
```

**Diagnosis:** MSL returns `bool`, Lean returns `Option Bool` (can fail).

**Impact:** MSL can't model proof deserialization errors.

**Fix:**

**Option 1:** MSL uses broader abort condition:

```move
aborts_if !can_deserialize(proof) || !verify_proof(proof) with EVERIFY_FAILED;
```

**Option 2:** Lean splits oracle into deserialize + verify:

```lean
axiom deserialize_proof : ProofBytes → Option Proof
axiom verify_proof : Proof → Bool
```

**Choose based on what's more natural for each stack.**

### 7.4 Lean Proof Complete But Difftest Fails

**Problem:** Lean proof compiles, but difftest fails.

**Symptoms:**

```
Lean:
  theorem transfer_eval_equiv : ... := by
    ... (proof complete, no sorry)
  ✓ Compiled successfully

Difftest:
  test test_transfer_happy_path ... FAILED
  assertion failed: balance[sender] == initial - amount
  expected: 900, actual: 1000
```

**Diagnosis:** Lean bytecode transcription is wrong (doesn't match actual VM).

**Cause:** Transcription error (missed instruction, wrong PC, etc.).

**Fix:**

```bash
# Compare Lean code to disassembly
movement move disassemble --bytecode transfer.mv > transfer.dis
vim -d Transfer/Transfer.lean transfer.dis

# Look for differences in instruction sequence
# Update Lean transcription to match bytecode exactly
# Re-test
cargo test test_transfer_happy_path
```

---

## 8. Maintenance

### 8.1 Regular Consistency Audits

**Schedule:** Monthly (or before each release).

**Checklist:**

- [ ] Run all automated consistency checks (CI)
- [ ] Manually review MSL-Lean alignment for all operations
- [ ] Check axiom count (should be ≤23)
- [ ] Verify abort codes consistent across all stacks
- [ ] Update coverage reports
- [ ] Review and update CLAIMS.md

**Audit script:**

```bash
#!/bin/bash
# monthly_consistency_audit.sh

set -e

echo "=== Monthly Consistency Audit ==="

echo "1. Running automated checks..."
./scripts/check_abort_code_consistency.sh
./scripts/check_oracle_alignment.sh
./scripts/check_axioms.sh

echo "2. Checking axiom count..."
axiom_count=$(./scripts/check_axioms.sh | wc -l)
if [ "$axiom_count" -gt 23 ]; then
  echo "WARNING: Axiom count increased to $axiom_count (budget: 23)"
fi

echo "3. Running full verification suite..."
./audit/verify-ca.sh

echo "4. Generating coverage report..."
./scripts/generate_coverage_report.sh > reports/coverage_$(date +%Y-%m).md

echo "5. Checking for MSL-Lean property alignment..."
./scripts/check_property_alignment.sh

echo "=== Audit Complete ==="
```

### 8.2 Documentation Sync

**Keep docs aligned with verification artifacts:**

**Update triggers:**

| Trigger | Docs to Update |
|---------|----------------|
| New axiom | AXIOM_INVENTORY.md, TRUST_BOUNDARIES.md |
| New operation | CLAIMS.md, coverage reports |
| Abort code change | CLAIMS.md, error code reference |
| Proof complete | CLAIMS.md (mark as verified) |
| MSL spec change | MSL_SPECIFICATION_PATTERNS_GUIDE.md examples |
| Lean proof pattern | LEAN_ARCHITECTURE_DEEP_DIVE.md patterns |

**Documentation review process:**

```bash
# After any verification change:
1. Update CLAIMS.md
2. Update coverage report
3. If axiom added/removed: update AXIOM_INVENTORY.md
4. If new pattern emerged: update pattern guides
5. Commit docs with verification change (same PR)
```

### 8.3 Quarterly Axiom Review

**Purpose:** Ensure all axioms still justified, remove temporary axioms when possible.

**Process:**

```bash
# 1. List all axioms
./scripts/check_axioms.sh > axioms_current.txt

# 2. Categorize (permanent vs temporary)
grep "temporary" axioms_current.txt > axioms_temporary.txt
grep -v "temporary" axioms_current.txt > axioms_permanent.txt

# 3. For each temporary axiom:
#    - Check if blocking issue resolved
#    - If yes: replace with proof
#    - If no: update justification, estimate resolution date

# 4. For each permanent axiom:
#    - Re-verify justification still valid
#    - Check if new research/tools allow removal
#    - Document any changes

# 5. Update AXIOM_INVENTORY.md
```

**Example quarterly review:**

```markdown
# Axiom Quarterly Review (2026-Q2)

## Temporary Axioms
1. ristretto255_add_associative
   - Status: Still temporary
   - Blocker: Waiting for Move Prover ristretto255 patches
   - ETA: 2026-Q3
   - Action: None

2. bulletproofs_range_soundness
   - Status: REMOVED (replaced with proof)
   - Resolution: Crypto library now provides verified implementation
   - Action: Updated AXIOM_INVENTORY.md, CLAIMS.md

## Permanent Axioms
- All 21 permanent axioms re-reviewed
- All justifications still valid (standard crypto assumptions)
- No changes
```

**See:** `VERIFICATION_MAINTENANCE_HANDBOOK.md` for complete maintenance procedures.

---

**END OF GUIDE**

**Key takeaways:**

1. **MSL and Lean must stay aligned** — cross-stack validation catches inconsistencies
2. **Abort codes are the easiest consistency check** — automate it
3. **Oracle modeling is critical** — MSL pragma opaque = Lean axiom = Difftest mock
4. **Difftest is ground truth** — if MSL and Lean agree but difftest fails, something wrong
5. **Update workflows prevent drift** — propagate Move changes to both MSL and Lean
6. **Regular audits maintain quality** — monthly consistency checks, quarterly axiom reviews
7. **Documentation is part of verification** — keep docs synced with artifacts

**Next steps:**

- Set up automated consistency checks in CI
- Schedule monthly audits
- Document coordination patterns as they emerge
- Train team on cross-stack validation

**Questions?** See `DEVELOPER_WORKFLOW_GUIDE.md` or `VERIFICATION_MAINTENANCE_HANDBOOK.md`.
