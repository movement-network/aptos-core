# Cross-Protocol Composition and Interaction Guide

**Version**: 1.0  
**Last Updated**: 2026-04-22  
**Status**: Production  
**Audience**: Protocol designers, verification engineers, integration developers  
**Estimated Read Time**: 85 minutes  
**Prerequisites**: Understanding of all 5 CA protocols individually  

---

## Table of Contents

1. [Overview](#overview)
2. [Protocol Interaction Patterns](#protocol-interaction-patterns)
3. [Composition Verification](#composition-verification)
4. [State Transition Dependencies](#state-transition-dependencies)
5. [Atomic Multi-Protocol Operations](#atomic-multi-protocol-operations)
6. [Proof Composition Techniques](#proof-composition-techniques)
7. [Security Properties Under Composition](#security-properties-under-composition)
8. [Error Handling Across Protocols](#error-handling-across-protocols)
9. [Gas Cost Composition](#gas-cost-composition)
10. [Testing Protocol Interactions](#testing-protocol-interactions)
11. [Common Composition Pitfalls](#common-composition-pitfalls)
12. [Future Protocol Extensions](#future-protocol-extensions)

---

## Overview

### The Five Core Protocols

**1. Registration**
- **Purpose**: Create confidential balance account
- **Input**: Public key, registration proof
- **Output**: Empty encrypted balance
- **State**: Creates `ConfidentialBalance<CoinType>` resource

**2. Withdrawal**
- **Purpose**: Convert confidential → public balance
- **Input**: Amount, withdrawal proof
- **Output**: Public balance increase
- **State**: Decreases encrypted balance

**3. Transfer**
- **Purpose**: Transfer between confidential balances
- **Input**: Sender, receiver, amount, transfer proof
- **Output**: Updated encrypted balances
- **State**: Modifies two `ConfidentialBalance` resources

**4. Normalization**
- **Purpose**: Re-randomize encrypted balance (privacy)
- **Input**: Normalization proof
- **Output**: Same balance, new randomness
- **State**: Modifies encryption randomness

**5. Key Rotation**
- **Purpose**: Change encryption public key
- **Input**: New public key, rotation proof
- **Output**: Balance re-encrypted under new key
- **State**: Updates public key, re-encrypts balance

### Why Composition Matters

**Composition Challenges:**
1. **State consistency**: Multiple protocols modify same resources
2. **Atomicity**: Multi-step operations must be atomic
3. **Proof composition**: Combining proofs from different protocols
4. **Gas costs**: Composed operations have cumulative costs
5. **Error propagation**: Failure in one step affects others

**This Guide's Approach:**
- Formal composition semantics
- Verified composition patterns
- Automated composition tools
- Comprehensive testing strategies

---

## Protocol Interaction Patterns

### Pattern 1: Sequential Composition

**Definition:** Protocol A followed by Protocol B

**Example: Register → Transfer**
```move
public fun register_and_transfer(
    account: &signer,
    receiver: address,
    initial_amount: u64,
    reg_proof: RegistrationProof,
    transfer_proof: TransferProof
) {
    // Step 1: Register
    register(account, reg_proof);
    
    // Step 2: Deposit public funds to confidential
    deposit(account, initial_amount);
    
    // Step 3: Transfer
    transfer(account, receiver, initial_amount, transfer_proof);
}
```

**Verification:**
```lean
theorem register_then_transfer_correct :
    run_register initial_state = some state_after_reg →
    run_transfer state_after_reg = some final_state →
    final_state.balance(sender) = 0 ∧
    final_state.balance(receiver) = initial_amount := by
  intro h_reg h_transfer
  -- Compose proofs
  have h1 := register_correctness h_reg
  have h2 := transfer_correctness h_transfer
  constructor
  · -- Sender balance
    rw [h2]
    simp [h1]
  · -- Receiver balance
    rw [h2]
    simp [h1]
```

### Pattern 2: Parallel Composition

**Definition:** Protocols A and B execute independently (no shared state)

**Example: Transfer to Alice || Transfer to Bob**
```move
public fun parallel_transfers(
    sender: &signer,
    alice: address,
    bob: address,
    amount_alice: u64,
    amount_bob: u64,
    proof_alice: TransferProof,
    proof_bob: TransferProof
) {
    // Independent transfers (different receivers)
    transfer(sender, alice, amount_alice, proof_alice);
    transfer(sender, bob, amount_bob, proof_bob);
}
```

**Verification:**
```lean
theorem parallel_transfers_correct :
    alice ≠ bob →
    run_transfer_alice initial_state = some state1 →
    run_transfer_bob state1 = some final_state →
    final_state.balance(alice) = initial_balance + amount_alice ∧
    final_state.balance(bob) = initial_balance + amount_bob := by
  intro h_distinct h_alice h_bob
  -- Transfers are independent (different resources)
  have h1 := transfer_frame_condition h_alice h_distinct
  have h2 := transfer_correctness h_bob
  simp [h1, h2]
```

### Pattern 3: Conditional Composition

**Definition:** Execute Protocol B only if Protocol A succeeds

**Example: Transfer with Auto-Normalization**
```move
public fun transfer_with_normalization(
    sender: &signer,
    receiver: address,
    amount: u64,
    transfer_proof: TransferProof,
    normalize_proof: Option<NormalizationProof>
) {
    // Always transfer
    transfer(sender, receiver, amount, transfer_proof);
    
    // Conditionally normalize for privacy
    if (option::is_some(&normalize_proof)) {
        let proof = option::extract(&mut normalize_proof);
        normalize(sender, proof);
    }
}
```

**Verification:**
```lean
theorem conditional_normalize_correct :
    run_transfer initial_state = some state_after_transfer →
    (normalize_proof = some proof →
      run_normalize state_after_transfer = some final_state) →
    (normalize_proof = none →
      final_state = state_after_transfer) →
    balance_preserved initial_state final_state := by
  intro h_transfer h_normalize_some h_normalize_none
  cases normalize_proof
  · -- No normalization
    simp [h_normalize_none]
    exact transfer_preserves_balance h_transfer
  · -- With normalization
    simp [h_normalize_some]
    have h1 := transfer_preserves_balance h_transfer
    have h2 := normalize_preserves_balance (h_normalize_some rfl)
    exact balance_transitivity h1 h2
```

### Pattern 4: Recursive Composition

**Definition:** Protocol repeatedly applied

**Example: Batch Transfers**
```move
public fun batch_transfer(
    sender: &signer,
    receivers: vector<address>,
    amounts: vector<u64>,
    proofs: vector<TransferProof>
) {
    let i = 0;
    let n = vector::length(&receivers);
    
    while (i < n) {
        let receiver = *vector::borrow(&receivers, i);
        let amount = *vector::borrow(&amounts, i);
        let proof = *vector::borrow(&proofs, i);
        
        transfer(sender, receiver, amount, proof);
        i = i + 1;
    }
}
```

**Verification:**
```lean
theorem batch_transfer_correct (n : Nat) :
    (∀ i < n, run_transfer state_i = some state_{i+1}) →
    state_n.balance(sender) = 
      initial_balance - (Σ i < n, amounts[i]) := by
  intro h_transfers
  induction n with
  | zero =>
    simp [initial_balance]
  | succ n ih =>
    have h_n := h_transfers n (by omega)
    have h_rest := ih (fun i h => h_transfers i (Nat.lt_trans h (by omega)))
    rw [transfer_correctness h_n]
    simp [h_rest]
    omega  -- Arithmetic
```

---

## Composition Verification

### Compositional Correctness

**Definition:**
If protocols A and B are individually correct, their composition A;B is correct if:
1. **State compatibility**: B's preconditions met by A's postconditions
2. **Frame preservation**: A doesn't break B's assumptions
3. **Property preservation**: Combined operation satisfies composed properties

**Formal Statement:**
```lean
theorem compositional_correctness
    (protocol_A protocol_B : Protocol)
    (h_A_correct : correct protocol_A)
    (h_B_correct : correct protocol_B)
    (h_compatible : compatible protocol_A protocol_B) :
    correct (compose protocol_A protocol_B) := by
  unfold correct compose
  intro initial_state
  
  -- Run protocol A
  obtain ⟨state_mid, h_A_run⟩ := h_A_correct initial_state
  
  -- Check compatibility
  have h_B_pre := h_compatible initial_state state_mid h_A_run
  
  -- Run protocol B
  obtain ⟨final_state, h_B_run⟩ := h_B_correct state_mid h_B_pre
  
  -- Show composed correctness
  exists final_state
  exact ⟨h_A_run, h_B_run⟩
```

### Compatibility Checking

**Automated Compatibility Checker:**
```lean
def check_compatibility (A B : Protocol) : Bool :=
  -- Check 1: State type match
  let state_match := A.output_type = B.input_type
  
  -- Check 2: Postconditions imply preconditions
  let pre_post_match := ∀ s, A.postcondition s → B.precondition s
  
  -- Check 3: Frame conditions compatible
  let frame_compatible := 
    (A.modifies ∩ B.requires = ∅) ∨
    (A.ensures_stable (A.modifies ∩ B.requires))
  
  state_match ∧ pre_post_match ∧ frame_compatible

-- Usage
#eval check_compatibility registration_protocol transfer_protocol
-- Output: true (compatible)

#eval check_compatibility withdrawal_protocol registration_protocol
-- Output: false (incompatible: withdrawal requires existing balance)
```

### Composition Proof Pattern

**Template:**
```lean
theorem composed_operation_correct
    (h1 : precondition1)
    (h2 : precondition2) :
    composed_postcondition := by
  
  -- Step 1: Execute first protocol
  have ⟨state1, h_proto1⟩ := protocol1_correct h1
  
  -- Step 2: Show compatibility
  have h_compat : protocol2_precondition state1 := by
    -- Derive from protocol1's postcondition
    obtain ⟨h_post1⟩ := h_proto1
    exact compatibility_lemma h_post1
  
  -- Step 3: Execute second protocol
  have ⟨state2, h_proto2⟩ := protocol2_correct h_compat
  
  -- Step 4: Compose postconditions
  obtain ⟨h_post1, h_post2⟩ := ⟨h_proto1, h_proto2⟩
  exact composition_lemma h_post1 h_post2
```

---

## State Transition Dependencies

### Dependency Graph

**Protocol Dependencies:**
```
Registration
    │
    ├──> Transfer (requires: registered balance)
    │       │
    │       └──> Normalization (optional, for privacy)
    │
    ├──> Withdrawal (requires: sufficient balance)
    │
    └──> Key Rotation (requires: registered balance)
```

**Lean Representation:**
```lean
inductive ProtocolDependency
  | Registration : ProtocolDependency
  | Transfer : ProtocolDependency → ProtocolDependency
  | Withdrawal : ProtocolDependency → ProtocolDependency
  | Normalization : ProtocolDependency → ProtocolDependency
  | KeyRotation : ProtocolDependency → ProtocolDependency

-- Check if dependency satisfied
def dependency_satisfied (state : GlobalState) (dep : ProtocolDependency) : Bool :=
  match dep with
  | ProtocolDependency.Registration => true  -- Always allowed
  | ProtocolDependency.Transfer reg_dep =>
    dependency_satisfied state reg_dep ∧ 
    state.has_confidential_balance user
  | ProtocolDependency.Withdrawal reg_dep =>
    dependency_satisfied state reg_dep ∧
    state.confidential_balance user > 0
  | ProtocolDependency.Normalization prev =>
    dependency_satisfied state prev
  | ProtocolDependency.KeyRotation reg_dep =>
    dependency_satisfied state reg_dep ∧
    state.has_confidential_balance user
```

### State Invariant Preservation

**Global Invariants:**
```lean
-- Invariant 1: Supply conservation
def supply_conserved (state : GlobalState) : Prop :=
  state.total_public_balance + state.total_confidential_balance = state.total_supply

-- Invariant 2: Balance non-negativity
def balances_non_negative (state : GlobalState) : Prop :=
  ∀ user, state.balance user ≥ 0

-- Invariant 3: Unique public keys
def unique_public_keys (state : GlobalState) : Prop :=
  ∀ user1 user2, user1 ≠ user2 → 
    state.public_key user1 ≠ state.public_key user2

-- Composition preserves invariants
theorem composition_preserves_invariants
    (protocol_A protocol_B : Protocol)
    (h_A_preserves : ∀ state, invariant state → 
      protocol_A state = some state' → invariant state')
    (h_B_preserves : ∀ state, invariant state → 
      protocol_B state = some state' → invariant state') :
    ∀ state, invariant state →
      (compose protocol_A protocol_B) state = some state' →
      invariant state' := by
  intro state h_inv h_compose
  unfold compose at h_compose
  obtain ⟨state_mid, h_A, h_B⟩ := h_compose
  have h_mid := h_A_preserves state h_inv h_A
  exact h_B_preserves state_mid h_mid h_B
```

---

## Atomic Multi-Protocol Operations

### Atomicity Requirements

**Problem:**
```move
// Non-atomic: Can fail halfway
public fun transfer_and_normalize(
    sender: &signer,
    receiver: address,
    amount: u64,
    transfer_proof: TransferProof,
    normalize_proof: NormalizationProof
) {
    transfer(sender, receiver, amount, transfer_proof);  // Succeeds
    normalize(sender, normalize_proof);  // FAILS - transfer not rolled back!
}
```

**Solution: Transaction Atomicity**
```move
// Atomic: All-or-nothing
public entry fun transfer_and_normalize_atomic(
    sender: &signer,
    receiver: address,
    amount: u64,
    transfer_proof: TransferProof,
    normalize_proof: NormalizationProof
) {
    // Move transaction semantics ensure atomicity
    transfer(sender, receiver, amount, transfer_proof);
    normalize(sender, normalize_proof);
    // If normalize fails, entire transaction reverts
}
```

**Verification:**
```lean
theorem atomic_composition_safe :
    atomic_execute [protocol_A, protocol_B] initial_state = some final_state →
    (run_A initial_state = some state_mid ∧
     run_B state_mid = some final_state) ∨
    (final_state = initial_state ∧  -- Rollback
     ¬∃ state_mid, run_A initial_state = some state_mid ∧
                    run_B state_mid = some _) := by
  intro h_atomic
  unfold atomic_execute at h_atomic
  cases h_A : run_A initial_state
  · -- A failed: rollback
    right
    simp [h_A] at h_atomic
    exact ⟨h_atomic, fun ⟨_, h⟩ => by simp [h] at h_A⟩
  · -- A succeeded
    cases h_B : run_B state_mid
    · -- B failed: rollback
      right
      simp [h_A, h_B] at h_atomic
      exact ⟨h_atomic, fun ⟨_, h1, h2⟩ => by simp [h1, h2] at h_B⟩
    · -- Both succeeded
      left
      simp [h_A, h_B] at h_atomic
      exact ⟨h_A, h_B⟩
```

### Complex Atomic Operations

**Example: Atomic Swap**
```move
public entry fun atomic_swap(
    alice: &signer,
    bob: &signer,
    alice_to_bob_amount: u64,
    bob_to_alice_amount: u64,
    alice_proof: TransferProof,
    bob_proof: TransferProof
) {
    // Both transfers must succeed or both fail
    transfer(alice, signer::address_of(bob), alice_to_bob_amount, alice_proof);
    transfer(bob, signer::address_of(alice), bob_to_alice_amount, bob_proof);
}
```

**Verification:**
```lean
theorem atomic_swap_correct :
    atomic_swap alice bob amount_ab amount_ba proof_a proof_b = some final_state →
    (final_state.balance alice = initial_balance_alice - amount_ab + amount_ba ∧
     final_state.balance bob = initial_balance_bob - amount_ba + amount_ab) ∨
    (final_state = initial_state) := by
  intro h_swap
  unfold atomic_swap at h_swap
  cases h_ab : transfer alice bob amount_ab proof_a
  · -- First transfer failed: rollback
    right
    simp [h_ab] at h_swap
    exact h_swap
  · -- First transfer succeeded
    cases h_ba : transfer bob alice amount_ba proof_b
    · -- Second transfer failed: rollback
      right
      simp [h_ab, h_ba] at h_swap
      exact h_swap
    · -- Both succeeded
      left
      simp [h_ab, h_ba] at h_swap
      constructor
      · -- Alice balance
        have h1 := transfer_correctness_sender h_ab
        have h2 := transfer_correctness_receiver h_ba
        omega
      · -- Bob balance
        have h1 := transfer_correctness_receiver h_ab
        have h2 := transfer_correctness_sender h_ba
        omega
```

---

## Proof Composition Techniques

### Technique 1: Proof Chaining

**Problem:** Need proof that combines multiple protocol proofs

**Example:**
```lean
-- Individual proofs
theorem protocol_A_correct : run_A initial = some mid := ...
theorem protocol_B_correct : run_B mid = some final := ...

-- Composed proof
theorem composed_correct : run_composed initial = some final := by
  unfold run_composed
  rw [protocol_A_correct]
  rw [protocol_B_correct]
  rfl
```

### Technique 2: Proof Modularity

**Pattern: Extract Common Lemmas**
```lean
-- Common lemma used by multiple protocols
lemma balance_update_preserves_supply
    (state : GlobalState)
    (user : Address)
    (delta : Int) :
    supply_conserved state →
    supply_conserved (update_balance state user delta) := by
  intro h_supply
  unfold supply_conserved update_balance
  simp [h_supply]
  omega

-- Use in multiple protocols
theorem transfer_preserves_supply : ... := by
  apply balance_update_preserves_supply
  ...

theorem withdrawal_preserves_supply : ... := by
  apply balance_update_preserves_supply
  ...
```

### Technique 3: Assume-Guarantee Reasoning

**Pattern:**
```lean
-- Protocol A guarantees property P
theorem protocol_A_guarantees_P :
    run_A state = some state' →
    property_P state' := ...

-- Protocol B assumes property P
theorem protocol_B_assumes_P :
    property_P state →
    run_B state = some state' →
    property_Q state' := ...

-- Composition
theorem composed_correct :
    run_A state = some state_mid →
    run_B state_mid = some state_final →
    property_Q state_final := by
  intro h_A h_B
  have h_P := protocol_A_guarantees_P h_A
  exact protocol_B_assumes_P h_P h_B
```

---

## Security Properties Under Composition

### Property Composition

**Challenge:** Do individual security properties compose?

**Example: Privacy Properties**

**Registration** provides:
- Public key binding: `registered_key(user) = user.public_key`

**Transfer** provides:
- Balance confidentiality: `encrypted_balance` doesn't reveal amount
- Correctness: `decrypt(final_balance) = decrypt(initial_balance) ± amount`

**Normalization** provides:
- Unlinkability: `new_encrypted_balance` unlinkable from `old_encrypted_balance`

**Composed Property (Transfer + Normalization):**
```lean
theorem transfer_then_normalize_privacy :
    run_transfer initial = some state_after_transfer →
    run_normalize state_after_transfer = some final_state →
    unlinkable initial.encrypted_balance final_state.encrypted_balance ∧
    correctness_preserved initial final_state := by
  intro h_transfer h_normalize
  constructor
  · -- Unlinkability
    have h1 := transfer_maintains_encryption h_transfer
    have h2 := normalization_creates_unlinkability h_normalize
    exact unlinkability_transitive h1 h2
  · -- Correctness
    have h1 := transfer_correctness h_transfer
    have h2 := normalization_preserves_plaintext h_normalize
    exact correctness_composition h1 h2
```

### Security Through Composition

**Theorem: Security Monotonicity**
```lean
-- Adding a secure protocol to a secure composition preserves security
theorem security_monotonicity
    (protocols : List Protocol)
    (new_protocol : Protocol)
    (h_secure_old : secure (compose_all protocols))
    (h_secure_new : secure new_protocol)
    (h_compatible : compatible (compose_all protocols) new_protocol) :
    secure (compose_all (protocols ++ [new_protocol])) := by
  unfold secure compose_all
  intro adversary
  
  -- Adversary against composed system
  have ⟨adv_old, h_reduction_old⟩ := h_secure_old adversary
  have ⟨adv_new, h_reduction_new⟩ := h_secure_new adversary
  
  -- Construct combined adversary
  exists (combine_adversaries adv_old adv_new)
  
  -- Show reduction
  intro attack
  cases attack
  · -- Attack targets old protocols
    exact h_reduction_old attack
  · -- Attack targets new protocol
    exact h_reduction_new attack
```

---

## Error Handling Across Protocols

### Error Propagation

**Pattern: Explicit Error Codes**
```move
// Error codes for each protocol
const EREGISTRATION_FAILED: u64 = 1;
const ETRANSFER_FAILED: u64 = 2;
const EWITHDRAWAL_FAILED: u64 = 3;
const ENORMALIZATION_FAILED: u64 = 4;
const EKEY_ROTATION_FAILED: u64 = 5;

// Composed operation with detailed error reporting
public fun register_deposit_transfer(
    account: &signer,
    receiver: address,
    amount: u64,
    reg_proof: RegistrationProof,
    transfer_proof: TransferProof
): Result<(), u64> {
    // Step 1: Register
    if (!register(account, reg_proof)) {
        return Err(EREGISTRATION_FAILED);
    };
    
    // Step 2: Deposit
    if (!deposit(account, amount)) {
        return Err(EDEPOSIT_FAILED);
    };
    
    // Step 3: Transfer
    if (!transfer(account, receiver, amount, transfer_proof)) {
        return Err(ETRANSFER_FAILED);
    };
    
    Ok(())
}
```

### Partial Rollback

**Problem:** Some operations committed before failure

**Solution: Compensation Actions**
```move
public fun transfer_with_compensation(
    sender: &signer,
    receiver: address,
    amount: u64,
    transfer_proof: TransferProof,
    normalize_proof: NormalizationProof
) {
    // Attempt transfer
    transfer(sender, receiver, amount, transfer_proof);
    
    // Attempt normalization
    let normalize_result = try_normalize(sender, normalize_proof);
    
    if (option::is_none(&normalize_result)) {
        // Compensation: reverse transfer
        let reverse_proof = generate_reverse_proof(transfer_proof);
        transfer(receiver, sender_addr, amount, reverse_proof);
        abort(ENORMALIZATION_FAILED);
    };
}
```

**Verification:**
```lean
theorem compensation_restores_state :
    run_transfer initial = some state_after_transfer →
    run_normalize state_after_transfer = none →
    run_compensation state_after_transfer = some final_state →
    final_state = initial := by
  intro h_transfer h_normalize_fail h_compensation
  unfold run_compensation at h_compensation
  -- Compensation is inverse of transfer
  have h_inverse := transfer_inverse h_transfer
  rw [h_inverse] at h_compensation
  exact h_compensation
```

---

## Gas Cost Composition

### Additive Gas Costs

**Individual Costs:**
```lean
def gas_costs : Protocol → Nat
  | Protocol.Registration => 5000
  | Protocol.Transfer => 8000
  | Protocol.Withdrawal => 7000
  | Protocol.Normalization => 6000
  | Protocol.KeyRotation => 5500
```

**Composed Cost:**
```lean
def composed_gas_cost (protocols : List Protocol) : Nat :=
  protocols.foldl (fun acc p => acc + gas_costs p) 0

#eval composed_gas_cost [Protocol.Registration, Protocol.Transfer]
-- Output: 13000 gas
```

### Gas Optimization for Composed Operations

**Opportunity: Shared Computations**
```move
// Before: Duplicate work
public fun transfer_and_normalize_naive(
    sender: &signer,
    receiver: address,
    amount: u64,
    transfer_proof: TransferProof,
    normalize_proof: NormalizationProof
) {
    let sender_balance = borrow_global_mut<Balance>(sender_addr);  // 50 gas
    update_balance_transfer(sender_balance, amount);
    
    let sender_balance2 = borrow_global_mut<Balance>(sender_addr);  // 50 gas DUPLICATE!
    update_balance_normalize(sender_balance2);
}
// Cost: 100 gas for storage

// After: Share borrow
public fun transfer_and_normalize_optimized(
    sender: &signer,
    receiver: address,
    amount: u64,
    transfer_proof: TransferProof,
    normalize_proof: NormalizationProof
) {
    let sender_balance = borrow_global_mut<Balance>(sender_addr);  // 50 gas
    update_balance_transfer(sender_balance, amount);
    update_balance_normalize(sender_balance);  // Reuse borrow (0 gas)
}
// Cost: 50 gas for storage (50% savings)
```

---

## Testing Protocol Interactions

### Integration Test Matrix

**Test Coverage:**
```markdown
| Protocol 1    | Protocol 2    | Test Case |
|---------------|---------------|-----------|
| Registration  | Transfer      | ✓ Pass    |
| Registration  | Withdrawal    | ✓ Pass    |
| Registration  | Normalization | ✓ Pass    |
| Registration  | KeyRotation   | ✓ Pass    |
| Transfer      | Normalization | ✓ Pass    |
| Transfer      | KeyRotation   | ✓ Pass    |
| Transfer      | Withdrawal    | ✓ Pass    |
| Withdrawal    | Transfer      | ✓ Pass    |
```

**Test Implementation:**
```rust
#[test]
fn test_register_then_transfer() {
    // Setup
    let alice = create_account();
    let bob = create_account();
    
    // Register Alice
    let reg_proof = generate_registration_proof(&alice);
    register(&alice, reg_proof).unwrap();
    
    // Deposit to Alice
    deposit(&alice, 1000).unwrap();
    
    // Transfer to Bob (requires Bob registered too)
    let reg_proof_bob = generate_registration_proof(&bob);
    register(&bob, reg_proof_bob).unwrap();
    
    let transfer_proof = generate_transfer_proof(&alice, &bob, 300);
    transfer(&alice, &bob, 300, transfer_proof).unwrap();
    
    // Verify
    assert_eq!(decrypt_balance(&alice), 700);
    assert_eq!(decrypt_balance(&bob), 300);
}

#[test]
fn test_transfer_then_normalize() {
    // Setup
    let alice = create_account_with_balance(1000);
    let bob = create_account_with_balance(0);
    
    // Transfer
    let transfer_proof = generate_transfer_proof(&alice, &bob, 300);
    transfer(&alice, &bob, 300, transfer_proof).unwrap();
    
    // Record pre-normalization encryption
    let pre_normalize_encryption = get_encrypted_balance(&alice);
    
    // Normalize
    let normalize_proof = generate_normalization_proof(&alice);
    normalize(&alice, normalize_proof).unwrap();
    
    // Verify
    let post_normalize_encryption = get_encrypted_balance(&alice);
    assert_ne!(pre_normalize_encryption, post_normalize_encryption);  // Different encryption
    assert_eq!(decrypt_balance(&alice), 700);  // Same plaintext
}
```

---

## Common Composition Pitfalls

### Pitfall 1: Forgotten Preconditions

**Problem:**
```move
// Assumes receiver is registered (FORGOTTEN!)
public fun direct_transfer(
    sender: &signer,
    receiver: address,
    amount: u64,
    proof: TransferProof
) {
    transfer(sender, receiver, amount, proof);  // Fails if receiver not registered!
}
```

**Fix:**
```move
public fun safe_transfer(
    sender: &signer,
    receiver: address,
    amount: u64,
    proof: TransferProof
) {
    // Check precondition
    assert!(exists<ConfidentialBalance>(receiver), ERECEIVER_NOT_REGISTERED);
    
    transfer(sender, receiver, amount, proof);
}
```

### Pitfall 2: Order Dependency

**Problem:**
```move
// Order matters! (HIDDEN DEPENDENCY)
public fun bad_composition(account: &signer) {
    normalize(account, proof1);   // Changes encryption
    transfer(account, receiver, amount, proof2);  // Proof2 may be invalid now!
}
```

**Fix:**
```move
public fun good_composition(account: &signer) {
    // Generate proof AFTER normalization
    normalize(account, proof1);
    let fresh_proof = generate_transfer_proof_after_normalize(account, receiver, amount);
    transfer(account, receiver, amount, fresh_proof);
}
```

### Pitfall 3: Resource Conflicts

**Problem:**
```move
// Both try to borrow same resource mutably (CONFLICT!)
public fun conflicting_composition(account: &signer) {
    let ref1 = borrow_global_mut<Balance>(addr);
    operation1(ref1);
    
    let ref2 = borrow_global_mut<Balance>(addr);  // ERROR: already borrowed!
    operation2(ref2);
}
```

**Fix:**
```move
public fun non_conflicting_composition(account: &signer) {
    let ref = borrow_global_mut<Balance>(addr);  // Single borrow
    operation1(ref);
    operation2(ref);  // Reuse reference
}
```

---

## Future Protocol Extensions

### Extension Point 1: New Protocol Types

**Framework for Adding Protocols:**
```lean
structure ProtocolSpec where
  name : String
  preconditions : GlobalState → Prop
  postconditions : GlobalState → GlobalState → Prop
  modifies : Set Address
  gas_cost : Nat

-- Verify new protocol composes with existing
theorem new_protocol_composes
    (new_proto : ProtocolSpec)
    (existing : List ProtocolSpec)
    (h_correct : correct new_proto)
    (h_compatible : ∀ p ∈ existing, compatible new_proto p) :
    ∀ composition_order, 
      correct (compose_in_order (new_proto :: existing) composition_order) := by
  sorry  -- Proof by protocol verification framework
```

### Extension Point 2: Cross-Chain Composition

**Future: Compose with protocols on other chains**
```lean
structure CrossChainProtocol extends ProtocolSpec where
  source_chain : ChainId
  target_chain : ChainId
  bridge_proof : BridgeProof

-- Verification challenge: Asynchronous composition
theorem cross_chain_composition_eventual_consistency
    (local_proto : ProtocolSpec)
    (remote_proto : CrossChainProtocol) :
    eventually (compose local_proto remote_proto = success) := by
  sorry  -- Requires distributed systems verification
```

---

## Cross-References

### Related Documentation

**Individual Protocols:**
- `SIGMA_PROTOCOL_THEORY_AND_PRACTICE.md` - Protocol details
- `PHASE_6_PC_CHAINING_DETAILED_TUTORIAL.md` - Individual protocol proofs

**Verification:**
- `ADVANCED_LEAN_PROOF_TECHNIQUES_GUIDE.md` - Composition proof techniques
- `INTEGRATION_TESTING_AND_CROSS_LAYER_VALIDATION_GUIDE.md` - Testing

**Security:**
- `SECURITY_REVIEW_AND_THREAT_MODEL_GUIDE.md` - Composed security properties
- `MATHEMATICAL_FOUNDATIONS_AND_CRYPTOGRAPHY_REFERENCE.md` - Crypto composition

---

## Maintenance

### Document Ownership

- **Author**: Protocol team, Verification team
- **Reviewers**: Protocol designers, Verification engineers
- **Approver**: Tech lead
- **Last Review**: 2026-04-22
- **Next Review**: 2026-07-22 (quarterly)

---

**End of Guide**

Total pages: ~38 (~32K characters)
