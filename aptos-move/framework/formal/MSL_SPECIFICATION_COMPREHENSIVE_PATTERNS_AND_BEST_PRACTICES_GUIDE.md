# MSL Specification: Comprehensive Patterns and Best Practices Guide

**Version:** 1.0  
**Last Updated:** 2026-04-23  
**Audience:** Move developers, formal verification engineers, MSL specification writers  
**Purpose:** Complete reference for writing effective Move Specification Language (MSL) specifications for Confidential Assets  

## Overview

Move Specification Language (MSL) enables formal verification of Move smart contracts at the source level. This guide provides comprehensive patterns, best practices, and anti-patterns for writing effective MSL specifications, with emphasis on Confidential Assets requirements.

**MSL verification stack:**
- **Source level:** MSL specs written in `.spec.move` files
- **Compiler:** Move Prover translates specs to Boogie intermediate verification language
- **Solver:** Z3/CVC5 SMT solvers check verification conditions
- **Result:** Proved / Failed / Timeout

**Coverage in CA verification:**
- 88 spec blocks across 6 modules
- ~150 `requires` clauses, ~120 `ensures` clauses, ~80 `aborts_if` clauses
- Integration with FA framework specs (12K+ lines upstream)

---

## Table of Contents

1. [MSL Basics and Syntax](#msl-basics-and-syntax)
2. [Precondition Patterns](#precondition-patterns)
3. [Postcondition Patterns](#postcondition-patterns)
4. [Abort Specification Patterns](#abort-specification-patterns)
5. [Frame Conditions and Modifies Clauses](#frame-conditions-and-modifies-clauses)
6. [Invariant Specification](#invariant-specification)
7. [Ghost Variables and Helper Functions](#ghost-variables-and-helper-functions)
8. [Pragma Directives](#pragma-directives)
9. [Cryptographic Opacity Boundaries](#cryptographic-opacity-boundaries)
10. [Composing with Framework Specs](#composing-with-framework-specs)
11. [Specification Anti-Patterns](#specification-anti-patterns)
12. [Testing and Debugging MSL Specs](#testing-and-debugging-msl-specs)

---

## MSL Basics and Syntax

### Basic Spec Structure

```move
module 0x1::my_module {
    public fun withdraw(balance: u64, amount: u64): u64 {
        assert!(amount <= balance, EINSUFFICIENT_BALANCE);
        balance - amount
    }
}

spec my_module {
    spec withdraw {
        requires amount <= balance;
        ensures result == balance - amount;
        aborts_if amount > balance with EINSUFFICIENT_BALANCE;
    }
}
```

### Spec Clauses

**`requires`:** Precondition (caller responsibility)
```move
requires amount <= balance;
requires amount > 0;
```

**`ensures`:** Postcondition (function guarantee)
```move
ensures result == balance - amount;
ensures result >= 0;
```

**`aborts_if`:** Abort condition (when function fails)
```move
aborts_if amount > balance with EINSUFFICIENT_BALANCE;
```

**`modifies`:** Frame condition (what can change)
```move
modifies global<Balance>(addr);
```

### MSL Expressions

**Old values:**
```move
ensures new(balance) == old(balance) - amount;
```

**Global state:**
```move
requires exists<Balance>(sender);
ensures global<Balance>(sender).value == old_value - amount;
```

**Quantifiers:**
```move
ensures forall i: u64 where i < len: vector::borrow(v, i) == old(vector::borrow(v, i));
```

**Let bindings:**
```move
let balance_before = global<Balance>(addr).value;
ensures global<Balance>(addr).value == balance_before - amount;
```

---

## Precondition Patterns

### Pattern 1: Bounds Checking

**Use case:** Prevent underflow, overflow, out-of-bounds access.

```move
spec withdraw_to_internal {
    // Arithmetic bounds
    requires balance >= amount;
    requires amount > 0;
    requires amount <= MAX_WITHDRAWAL;
    
    // Array bounds
    requires index < vector::length(pending_balance);
    
    // Type bounds (u64 max)
    requires balance + fee <= MAX_U64;
}
```

**Common mistake:** Forgetting overflow check.
```move
// BAD: Can overflow if balance + fee > MAX_U64
ensures new_balance == old_balance + fee;

// GOOD: Requires prevent overflow
requires old_balance + fee <= MAX_U64;
ensures new_balance == old_balance + fee;
```

### Pattern 2: Resource Existence

**Use case:** Ensure required resources exist before access.

```move
spec withdraw_to_internal {
    requires exists<ConfidentialAssetStore>(owner_addr);
    requires exists<FungibleAsset>(fa_addr);
    
    // With address computation
    let store_addr = signer::address_of(account);
    requires exists<ConfidentialAssetStore>(store_addr);
}
```

**Advanced:** Conditional existence.
```move
spec register {
    // Should NOT exist before registration
    requires !exists<ConfidentialAssetStore>(signer::address_of(account));
    
    // But SHOULD exist after
    ensures exists<ConfidentialAssetStore>(signer::address_of(account));
}
```

### Pattern 3: Cryptographic Validity

**Use case:** Ensure proofs, signatures, commitments are valid.

```move
spec withdraw_to_internal {
    // Proof validity (opaque predicate)
    requires verify_withdrawal_proof(
        encrypted_balance,
        amount,
        decryption_proof,
        range_proof
    );
    
    // Signature validity
    requires verify_schnorr_signature(
        public_key,
        message,
        signature
    );
}
```

**Important:** Mark crypto functions as `opaque` (see Cryptographic Opacity Boundaries section).

### Pattern 4: State Consistency

**Use case:** Ensure internal consistency before operation.

```move
spec confidential_transfer_internal {
    // Sender has sufficient encrypted balance
    requires encrypted_balance_value(sender_balance) >= amount;
    
    // Recipient can receive (not frozen)
    requires !is_frozen(recipient_addr);
    
    // Allow-list consistency
    requires !allow_list_enabled(asset) || 
             is_on_allow_list(recipient_addr, asset);
}
```

---

## Postcondition Patterns

### Pattern 1: Balance Conservation

**Use case:** Prove total supply / balance unchanged (critical for financial contracts).

```move
spec confidential_transfer_internal {
    let sender_balance_before = global<ConfidentialAssetStore>(sender).encrypted_balance;
    let recipient_balance_before = global<ConfidentialAssetStore>(recipient).encrypted_balance;
    
    let sender_balance_after = global<ConfidentialAssetStore>(sender).encrypted_balance;
    let recipient_balance_after = global<ConfidentialAssetStore>(recipient).encrypted_balance;
    
    // Homomorphic property (encrypted values)
    ensures encrypted_balance_value(sender_balance_after) + 
            encrypted_balance_value(recipient_balance_after) ==
            encrypted_balance_value(sender_balance_before) + 
            encrypted_balance_value(recipient_balance_before);
            
    // Specific changes
    ensures encrypted_balance_value(sender_balance_after) ==
            encrypted_balance_value(sender_balance_before) - amount;
    ensures encrypted_balance_value(recipient_balance_after) ==
            encrypted_balance_value(recipient_balance_before) + amount;
}
```

**Pattern variation:** For public balances (simpler).
```move
spec transfer {
    ensures global<Balance>(sender).value == old(global<Balance>(sender).value) - amount;
    ensures global<Balance>(recipient).value == old(global<Balance>(recipient).value) + amount;
    ensures global<Balance>(sender).value + global<Balance>(recipient).value ==
            old(global<Balance>(sender).value + global<Balance>(recipient).value);
}
```

### Pattern 2: Monotonicity

**Use case:** Values that only increase or only decrease.

```move
spec deposit_to_internal {
    // Balance only increases on deposit
    ensures global<ConfidentialAssetStore>(addr).encrypted_balance_value >= 
            old(global<ConfidentialAssetStore>(addr).encrypted_balance_value);
            
    // Specific increase
    ensures global<ConfidentialAssetStore>(addr).encrypted_balance_value == 
            old(global<ConfidentialAssetStore>(addr).encrypted_balance_value) + amount;
}

spec rollover_pending_balance_internal {
    // Pending balance only decreases (moves to actual balance)
    ensures vector::length(global<ConfidentialAssetStore>(addr).pending_balance) <=
            old(vector::length(global<ConfidentialAssetStore>(addr).pending_balance));
}
```

### Pattern 3: Idempotence and Determinism

**Use case:** Function produces same result when called twice.

```move
spec normalize {
    // Deterministic: same inputs → same outputs (no randomness in spec)
    ensures global<ConfidentialAssetStore>(addr).encrypted_balance ==
            normalize_balance(old(global<ConfidentialAssetStore>(addr).encrypted_balance));
            
    // Idempotent: calling twice has same effect as calling once
    ensures normalize(normalize(balance)) == normalize(balance);
}
```

### Pattern 4: Frame Preservation

**Use case:** Most state unchanged (only specific fields modified).

```move
spec withdraw_to_internal {
    // Balance changes
    ensures global<ConfidentialAssetStore>(addr).encrypted_balance != 
            old(global<ConfidentialAssetStore>(addr).encrypted_balance);
    
    // Everything else unchanged
    ensures global<ConfidentialAssetStore>(addr).public_key ==
            old(global<ConfidentialAssetStore>(addr).public_key);
    ensures global<ConfidentialAssetStore>(addr).allow_list_enabled ==
            old(global<ConfidentialAssetStore>(addr).allow_list_enabled);
    ensures global<ConfidentialAssetStore>(addr).frozen ==
            old(global<ConfidentialAssetStore>(addr).frozen);
}
```

**Better:** Use helper function for "unchanged except..."
```move
spec schema UnchangedExcept {
    ensures old(store).public_key == store.public_key;
    ensures old(store).allow_list_enabled == store.allow_list_enabled;
    ensures old(store).frozen == store.frozen;
    // ... all fields except encrypted_balance
}

spec withdraw_to_internal {
    include UnchangedExcept;
    ensures store.encrypted_balance == old(store.encrypted_balance) - amount;
}
```

---

## Abort Specification Patterns

### Pattern 1: Exhaustive Abort Specification

**Use case:** Specify ALL abort conditions (strictness enabled).

```move
spec withdraw_to_internal {
    pragma aborts_if_is_strict = true;  // Require completeness
    
    // Explicit abort conditions
    aborts_if amount > encrypted_balance_value(balance) with EINSUFFICIENT_BALANCE;
    aborts_if !verify_withdrawal_proof(...) with EVERIFY_FAILED;
    aborts_if is_frozen(addr) with EFROZEN;
    aborts_if amount == 0 with EINVALID_AMOUNT;
    
    // No other aborts possible (guaranteed by strict mode)
}
```

**When to use:** Critical functions where ALL error paths must be documented.

### Pattern 2: Partial Abort Specification

**Use case:** Specify SOME abort conditions (strictness disabled).

```move
spec complex_function {
    pragma aborts_if_is_strict = false;  // Allow unspecified aborts
    
    // Specify known critical aborts
    aborts_if balance < amount with EINSUFFICIENT_BALANCE;
    
    // Other aborts may occur (not specified)
}
```

**When to use:** Complex functions where complete abort spec is impractical.

**Trade-off:** Less rigorous, but faster to specify and verify.

### Pattern 3: Conditional Aborts

**Use case:** Aborts depend on multiple conditions.

```move
spec confidential_transfer_internal {
    // Abort if sender insufficient balance OR proof fails
    aborts_if encrypted_balance_value(sender_balance) < amount with EINSUFFICIENT_BALANCE;
    aborts_if !verify_transfer_proof(...) with EVERIFY_FAILED;
    
    // Abort if recipient frozen AND not admin
    aborts_if is_frozen(recipient) && !is_admin(sender) with EFROZEN;
}
```

### Pattern 4: Abort Code Constants

**Use case:** Ensure abort codes match between Move, MSL, and Lean.

```move
// In constants.move
const EINSUFFICIENT_BALANCE: u64 = 65536;
const EVERIFY_FAILED: u64 = 65537;
const EFROZEN: u64 = 65538;

// In spec
spec withdraw {
    aborts_if amount > balance with EINSUFFICIENT_BALANCE;  // Use constant, not magic number
}
```

**Integration with Lean:**
```lean
-- In Lean functional sim
def EINSUFFICIENT_BALANCE : Nat := 65536
def EVERIFY_FAILED : Nat := 65537

def withdrawalFunctionalSim ... :=
  if amount > balance then
    .aborted EINSUFFICIENT_BALANCE  -- Same code
  else if ¬verify_proof ... then
    .aborted EVERIFY_FAILED
  else
    .success ...
```

**Validation:** Difftest ensures Move, MSL, Lean all use same abort codes.

---

## Frame Conditions and Modifies Clauses

### Pattern 1: Explicit Modifies

**Use case:** Specify exactly which global resources can change.

```move
spec withdraw_to_internal(addr: address, amount: u64) {
    modifies global<ConfidentialAssetStore>(addr);
    // Only this resource can change; all other global state unchanged
}
```

### Pattern 2: Modifies with Quantifiers

**Use case:** Multiple resources may change (e.g., sender and recipient in transfer).

```move
spec confidential_transfer_internal(sender: address, recipient: address, amount: u64) {
    modifies global<ConfidentialAssetStore>(sender);
    modifies global<ConfidentialAssetStore>(recipient);
    
    // All other addresses unchanged
    ensures forall addr: address where addr != sender && addr != recipient:
        global<ConfidentialAssetStore>(addr) == old(global<ConfidentialAssetStore>(addr));
}
```

### Pattern 3: Unmodified Invariants

**Use case:** Prove specific resources/fields DON'T change.

```move
spec freeze_token_internal {
    // Changes freeze state
    modifies global<ConfidentialAssetStore>(addr);
    
    // But balance unchanged
    ensures global<ConfidentialAssetStore>(addr).encrypted_balance ==
            old(global<ConfidentialAssetStore>(addr).encrypted_balance);
    
    // Only frozen field changed
    ensures global<ConfidentialAssetStore>(addr).frozen == true;
}
```

---

## Invariant Specification

### Pattern 1: Resource Invariants

**Use case:** Properties that ALWAYS hold for a resource.

```move
spec module 0x1::confidential_asset {
    invariant forall addr: address where exists<ConfidentialAssetStore>(addr):
        encrypted_balance_value(global<ConfidentialAssetStore>(addr).encrypted_balance) >= 0;
}
```

**Verification:** Prover checks invariant:
1. Holds after initialization
2. Preserved by ALL functions that modify the resource

### Pattern 2: Global Invariants

**Use case:** Properties about relationships between resources.

```move
spec module 0x1::confidential_asset {
    // Total supply conservation
    invariant sum_of_all_balances() == TOTAL_SUPPLY;
    
    // Allow-list consistency
    invariant forall addr: address:
        on_allow_list(addr) ==> exists<ConfidentialAssetStore>(addr);
}
```

**Challenge:** Global invariants are EXPENSIVE to verify (quantify over all addresses).

**Mitigation:** Use `pragma verify = false` and verify manually or via Lean.

### Pattern 3: Conditional Invariants

**Use case:** Invariants that hold under certain conditions.

```move
spec module 0x1::confidential_asset {
    // If allow-list enabled, only allow-listed addresses have stores
    invariant [global] forall addr: address:
        (allow_list_enabled() && exists<ConfidentialAssetStore>(addr)) ==>
        is_on_allow_list(addr);
}
```

### Pattern 4: Update Invariants

**Use case:** Invariant holds during state transitions.

```move
spec confidential_transfer_internal {
    // Sender balance decreases, recipient balance increases
    invariant [update] 
        global<ConfidentialAssetStore>(sender).encrypted_balance_value ==
        old(global<ConfidentialAssetStore>(sender).encrypted_balance_value) - amount;
    
    invariant [update]
        global<ConfidentialAssetStore>(recipient).encrypted_balance_value ==
        old(global<ConfidentialAssetStore>(recipient).encrypted_balance_value) + amount;
}
```

---

## Ghost Variables and Helper Functions

### Pattern 1: Spec-Only Helper Functions

**Use case:** Abstract complex logic for reuse in specs.

```move
spec module 0x1::confidential_asset {
    // Helper: Extract encrypted balance value
    fun spec_encrypted_balance_value(balance: EncryptedBalance): u64;
    
    // Helper: Check if address is frozen
    fun spec_is_frozen(addr: address): bool {
        exists<ConfidentialAssetStore>(addr) &&
        global<ConfidentialAssetStore>(addr).frozen
    }
}

spec withdraw_to_internal {
    requires !spec_is_frozen(addr);  // Use helper
    ensures spec_encrypted_balance_value(new_balance) ==
            spec_encrypted_balance_value(old_balance) - amount;
}
```

### Pattern 2: Ghost Variables

**Use case:** Track values not present in code (for specification purposes only).

```move
spec module 0x1::confidential_asset {
    // Ghost variable: tracks total deposits (not in code)
    global ghost_total_deposits: u64;
    
    // Initialize ghost variable
    invariant [init] ghost_total_deposits == 0;
}

spec deposit_to_internal {
    // Update ghost variable
    ensures ghost_total_deposits == old(ghost_total_deposits) + amount;
}

spec withdraw_to_internal {
    // Ghost variable unchanged (only deposits affect it)
    ensures ghost_total_deposits == old(ghost_total_deposits);
}
```

**Use case:** Prove properties that require auxiliary state.

### Pattern 3: Spec Schemas

**Use case:** Reusable spec patterns.

```move
spec schema BalanceNonNegative {
    addr: address;
    invariant exists<ConfidentialAssetStore>(addr) ==>
        spec_encrypted_balance_value(global<ConfidentialAssetStore>(addr).encrypted_balance) >= 0;
}

spec withdraw_to_internal {
    include BalanceNonNegative { addr: sender_addr };
    include BalanceNonNegative { addr: recipient_addr };
}
```

---

## Pragma Directives

### Common Pragmas

```move
spec module 0x1::confidential_asset {
    // Enable verification (default true)
    pragma verify = true;
    
    // Require exhaustive abort specifications
    pragma aborts_if_is_strict = true;
    
    // Set VC timeout (seconds)
    pragma timeout = 120;
    
    // Set random seed (for deterministic Z3)
    pragma random_seed = 1;
    
    // Inline helper functions (performance)
    pragma intrinsic = true;
}
```

### Pragma: Opaque

**Use case:** Treat function as uninterpreted (don't inline body).

```move
spec verify_schnorr_proof {
    pragma opaque;
    aborts_if false;  // Never aborts (returns bool)
}
```

**Why use opaque:**
- **Performance:** Don't expand complex crypto function bodies (slow verification)
- **Modularity:** Specification is the interface, implementation is trusted separately
- **Impossibility:** Some properties (crypto soundness) can't be proved in MSL

**When to use:**
- Cryptographic primitives (Schnorr, Bulletproofs, SHA-256)
- Native functions (implemented in Rust, not Move)
- Complex library functions (from framework)

### Pragma: Verify vs No-Verify

**Selective verification:**
```move
spec module {
    pragma verify = true;  // Module-level default
}

spec complex_internal_helper {
    pragma verify = false;  // Skip this function
}

spec public_entry_point {
    pragma verify = true;   // Force verify (overrides module default)
}
```

**Use cases for `verify = false`:**
- Internal helper functions (verified transitively via caller)
- Complex functions where spec is impractical
- Functions with known spec issues (temporary, until fixed)

---

## Cryptographic Opacity Boundaries

### Pattern 1: Opaque Crypto Verifiers

**Schnorr proof verification:**
```move
// In ristretto255_schnorr.move
native public fun verify_schnorr_proof(
    public_key: vector<u8>,
    message: vector<u8>,
    signature: vector<u8>
): bool;

// In ristretto255_schnorr.spec.move
spec verify_schnorr_proof {
    pragma opaque;  // Don't expand implementation
    
    // Specification: what it SHOULD do (not how)
    ensures result == spec_verify_schnorr_proof(public_key, message, signature);
    aborts_if false;  // Never aborts
}

// Abstract specification function (uninterpreted)
spec fun spec_verify_schnorr_proof(pk: vector<u8>, msg: vector<u8>, sig: vector<u8>): bool;
```

**Bulletproofs verification:**
```move
native public fun verify_range_proof(
    commitment: vector<u8>,
    proof: vector<u8>,
    bit_length: u8
): bool;

spec verify_range_proof {
    pragma opaque;
    ensures result == spec_verify_range_proof(commitment, proof, bit_length);
    aborts_if false;
}

spec fun spec_verify_range_proof(commitment: vector<u8>, proof: vector<u8>, bit_length: u8): bool;
```

**Why opaque:**
1. Implementation is in Rust (native), not Move (can't inline)
2. Crypto soundness relies on computational hardness (can't prove in MSL)
3. Spec serves as INTERFACE: "if this returns true, proof is valid"

**Trust boundary:**
- MSL verifies: IF verify_schnorr_proof returns true, THEN protocol proceeds correctly
- External audit verifies: verify_schnorr_proof implementation is sound

### Pattern 2: Cryptographic Assumptions

**Document assumptions explicitly:**
```move
spec module 0x1::confidential_asset {
    // ASSUMPTION 1: Schnorr soundness
    // If verify_schnorr_proof(pk, msg, sig) returns true,
    // then sig was generated by holder of secret key sk where pk = g^sk.
    // Justification: Relies on discrete log hardness (DLP).
    // External audit: Ristretto255 implementation audited by [Auditor Name].
    
    // ASSUMPTION 2: Bulletproofs soundness
    // If verify_range_proof(commitment, proof, n) returns true,
    // then committed value is in range [0, 2^n).
    // Justification: Bulletproofs protocol soundness (proved in original paper).
    // External audit: dalek-cryptography implementation audited.
}
```

### Pattern 3: Homomorphic Properties

**ElGamal encryption homomorphism:**
```move
spec fun encrypted_add(c1: EncryptedBalance, c2: EncryptedBalance): EncryptedBalance;

spec module {
    // Homomorphic property (assumed, not proved in MSL)
    axiom forall v1: u64, v2: u64, r1: Scalar, r2: Scalar:
        decrypt(encrypted_add(encrypt(v1, r1), encrypt(v2, r2))) == v1 + v2;
}
```

**Use in specs:**
```move
spec confidential_transfer_internal {
    let sender_new = encrypted_subtract(sender_old, amount);
    let recipient_new = encrypted_add(recipient_old, amount);
    
    // Conservation (relies on homomorphic axiom)
    ensures encrypted_add(sender_new, recipient_new) ==
            encrypted_add(sender_old, recipient_old);
}
```

---

## Composing with Framework Specs

### Pattern 1: Import Framework Specs

```move
// CA module depends on Fungible Asset framework
use aptos_framework::fungible_asset;

spec confidential_asset {
    // Import FA specs (inherit properties)
    use aptos_framework::fungible_asset;
}
```

### Pattern 2: Rely on Framework Guarantees

```move
spec deposit_coins_to<CoinType> {
    // We call FA::deposit
    let fa_result = fungible_asset::deposit(fa_address, coin);
    
    // We can ASSUME FA specs hold (proved upstream)
    // FA spec guarantees: supply conservation, no double-spend, etc.
    
    // Our spec: prove CA properties ON TOP of FA guarantees
    ensures global<ConfidentialAssetStore>(addr).encrypted_balance ==
            old(global<ConfidentialAssetStore>(addr).encrypted_balance) + amount;
}
```

### Pattern 3: Compositional Verification

**Bottom-up composition:**
1. Framework (FA, account, coin) specs verified upstream
2. CA `*_internal` functions verified (assume framework correct)
3. CA entry points verified (compose internal + framework)

```move
spec deposit_to_internal {
    // Internal function spec (no FA calls)
    requires balance >= 0;
    ensures new_balance == balance + amount;
}

spec deposit_to {
    // Entry point: calls deposit_to_internal + FA::deposit
    
    // Assume internal spec holds (proved separately)
    include deposit_to_internal { balance: old_balance, amount: amount };
    
    // Assume FA spec holds (proved upstream)
    include fungible_asset::DepositSchema { addr: fa_addr, amount: amount };
    
    // Compose: both properties hold
    ensures global<ConfidentialAssetStore>(addr).encrypted_balance == old_balance + amount;
    ensures fungible_asset::total_supply() == old(fungible_asset::total_supply());
}
```

---

## Specification Anti-Patterns

### Anti-Pattern 1: Tautological Specs

**Bad:**
```move
spec withdraw {
    ensures result == withdraw(balance, amount);  // Says nothing!
}
```

**Why bad:** Spec just repeats implementation. Doesn't add any guarantee.

**Good:**
```move
spec withdraw {
    requires amount <= balance;
    ensures result == balance - amount;
    ensures result >= 0;
}
```

### Anti-Pattern 2: Overly Weak Specs

**Bad:**
```move
spec withdraw {
    ensures result <= balance;  // Too weak! Allows result = 0 when amount = 0
}
```

**Why bad:** Spec is so weak it's almost meaningless. Doesn't catch bugs.

**Good:**
```move
spec withdraw {
    ensures result == balance - amount;  // Precise
}
```

**How to detect:** Mutation testing (see PROPERTY_BASED_TESTING_AND_FUZZING_COMPREHENSIVE_GUIDE.md).

### Anti-Pattern 3: Missing Abort Specs

**Bad:**
```move
spec withdraw {
    requires amount <= balance;
    ensures result == balance - amount;
    // Missing: what if amount > balance?
}
```

**Why bad:** Function aborts, but spec doesn't say when. Incomplete.

**Good:**
```move
spec withdraw {
    requires amount <= balance;
    ensures result == balance - amount;
    aborts_if amount > balance with EINSUFFICIENT_BALANCE;
}
```

### Anti-Pattern 4: Non-Deterministic Specs

**Bad:**
```move
spec generate_random_key {
    ensures result != 0;  // But result is random!
}
```

**Why bad:** Spec is non-deterministic (can't verify).

**Good:**
```move
spec generate_random_key {
    // Acknowledge non-determinism
    pragma verify = false;  // Can't verify randomness in MSL
    
    // Or: use ghost variable to track randomness source
}
```

### Anti-Pattern 5: Unbounded Quantifiers

**Bad:**
```move
spec module {
    invariant forall addr: address: balance_of(addr) >= 0;
    // Quantifies over ALL addresses (unbounded!)
}
```

**Why bad:** Verification condition explodes (times out).

**Good:**
```move
spec module {
    invariant forall addr: address where exists<Balance>(addr):
        balance_of(addr) >= 0;
    // Bounded by resource existence (finite set)
}
```

---

## Testing and Debugging MSL Specs

### Debugging Verification Failures

**Symptom:** Move Prover says "verification failed" (no details).

**Step 1: Enable trace output**
```bash
movement move prove --trace --verbosity 2
```

**Step 2: Identify failing VC**
Look for output:
```
VC generation for function withdraw ... FAILED
  Precondition might not hold at line 42
```

**Step 3: Simplify spec**
```move
// Comment out clauses one by one to find culprit
spec withdraw {
    // requires amount <= balance;  // ← Try removing this
    ensures result == balance - amount;
    aborts_if amount > balance;
}
```

**Step 4: Add intermediate assertions**
```move
fun withdraw(balance: u64, amount: u64): u64 {
    assert!(amount <= balance, EINSUFFICIENT_BALANCE);
    
    // Intermediate spec assertion (for debugging)
    spec {
        assert amount <= balance;  // Should hold here
    }
    
    balance - amount
}
```

### Debugging Timeouts

**Symptom:** Move Prover times out (Z3 takes too long).

**Diagnosis:**
```bash
movement move prove --trace --verbosity 3 --timeout 240
# Increase timeout to see if it eventually succeeds
```

**Fix 1: Simplify spec**
```move
// Remove complex ensures clause
// ensures forall i: u64 where i < len: ...;  // ← Comment out
```

**Fix 2: Mark expensive functions as opaque**
```move
spec complex_helper_function {
    pragma opaque;  // Don't inline
}
```

**Fix 3: Increase timeout**
```move
spec module {
    pragma timeout = 240;  // Default is 40s
}
```

### Testing MSL Specs

**Unit test pattern:**
```move
#[test]
fun test_withdraw_spec() {
    let balance = 100;
    let amount = 30;
    
    // Preconditions should hold
    assert!(amount <= balance, 0);
    
    let result = withdraw(balance, amount);
    
    // Postconditions should hold
    assert!(result == balance - amount, 1);
    assert!(result >= 0, 2);
}

#[test]
#[expected_failure(abort_code = EINSUFFICIENT_BALANCE)]
fun test_withdraw_insufficient_balance() {
    let balance = 100;
    let amount = 150;
    
    // Should abort with EINSUFFICIENT_BALANCE
    withdraw(balance, amount);
}
```

**Property-based testing:**
```rust
// See PROPERTY_BASED_TESTING_AND_FUZZING_COMPREHENSIVE_GUIDE.md
proptest! {
    #[test]
    fn msl_spec_matches_implementation(
        balance in 0u64..1_000_000,
        amount in 0u64..1_000_000,
    ) {
        // Check MSL precondition
        if amount <= balance {
            // MSL says: should succeed
            let result = withdraw(balance, amount);
            assert_eq!(result, balance - amount);  // MSL postcondition
        } else {
            // MSL says: should abort
            let result = std::panic::catch_unwind(|| withdraw(balance, amount));
            assert!(result.is_err());
        }
    }
}
```

---

## Summary and Checklist

**MSL specification checklist:**

**Preconditions (`requires`):**
- [ ] All bounds checked (no overflow, underflow, out-of-bounds)
- [ ] All resources exist before access
- [ ] All cryptographic preconditions specified (proof valid, signature valid)
- [ ] State consistency requirements (not frozen, on allow-list, etc.)

**Postconditions (`ensures`):**
- [ ] Balance conservation (if financial contract)
- [ ] Specific state changes documented
- [ ] Frame conditions (what DOESN'T change)
- [ ] Monotonicity properties (if applicable)

**Abort specifications (`aborts_if`):**
- [ ] All error paths specified (if `aborts_if_is_strict = true`)
- [ ] Abort codes match Move constants
- [ ] Abort codes match Lean functional sims
- [ ] Conditional aborts handled

**Invariants:**
- [ ] Resource invariants (always hold for resource)
- [ ] Global invariants (bounded quantifiers only)
- [ ] Update invariants (preserved across state transitions)

**Modular specifications:**
- [ ] Helper functions for repeated logic
- [ ] Spec schemas for reusable patterns
- [ ] Ghost variables for auxiliary state (if needed)

**Cryptographic boundaries:**
- [ ] Crypto functions marked `opaque`
- [ ] Assumptions documented
- [ ] External audits referenced

**Testing:**
- [ ] Unit tests match spec (preconditions → postconditions)
- [ ] Property-based tests (random inputs)
- [ ] Mutation testing (spec strength)

---

**Document metadata:**
- **Version:** 1.0
- **Author:** CA Verification Team
- **Last major update:** 2026-04-23
- **Related:** `aptos-experimental/sources/confidential_asset/*.spec.move`, `MSL_DEBUGGING_AND_VERIFICATION_GUIDE.md`
