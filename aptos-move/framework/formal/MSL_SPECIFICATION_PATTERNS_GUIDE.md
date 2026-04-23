# MSL Specification Patterns Guide

**Purpose:** Comprehensive guide to Move Specification Language (MSL) patterns used in Confidential Assets verification, with proven examples and anti-patterns to avoid.

**Audience:** Developers writing MSL specs, formal verification engineers, Move Prover users.

**Scope:** MSL syntax, specification patterns, common idioms, performance optimization, debugging strategies.

---

## Table of Contents

1. [MSL Fundamentals](#1-msl-fundamentals)
2. [Basic Specification Patterns](#2-basic-specification-patterns)
3. [Advanced Patterns](#3-advanced-patterns)
4. [Crypto-Opaque Boundary Pattern](#4-crypto-opaque-boundary-pattern)
5. [Balance Preservation Patterns](#5-balance-preservation-patterns)
6. [Frame Conditions](#6-frame-conditions)
7. [Abort Specification Patterns](#7-abort-specification-patterns)
8. [Quantifier Patterns](#8-quantifier-patterns)
9. [Spec Function Library](#9-spec-function-library)
10. [Performance Patterns](#10-performance-patterns)
11. [Anti-Patterns to Avoid](#11-anti-patterns-to-avoid)
12. [Complete Examples](#12-complete-examples)

---

## 1. MSL Fundamentals

### 1.1 MSL vs Move

**Move code (implementation):**
```move
public fun withdraw_to(account: &signer, amount: u64) acquires ConfidentialAssetStore {
    let addr = signer::address_of(account);
    let store = borrow_global_mut<ConfidentialAssetStore>(addr);
    assert!(!store.frozen, ESTORE_FROZEN);
    store.balance = store.balance - amount;
}
```

**MSL spec (mathematical specification):**
```move
spec withdraw_to {
    requires exists<ConfidentialAssetStore>(signer::address_of(account));
    requires !global<ConfidentialAssetStore>(signer::address_of(account)).frozen;
    
    ensures global<ConfidentialAssetStore>(signer::address_of(account)).balance == 
            old(global<ConfidentialAssetStore>(signer::address_of(account)).balance) - amount;
    
    aborts_if !exists<ConfidentialAssetStore>(signer::address_of(account));
    aborts_if global<ConfidentialAssetStore>(signer::address_of(account)).frozen;
}
```

**Key differences:**
- MSL uses `global<T>(addr)` to access resources (mathematical model, not VM access)
- MSL uses `old(expr)` to refer to pre-state
- MSL uses `requires/ensures/aborts_if` to specify behavior mathematically
- MSL specs are checked by Move Prover (Boogie + Z3), not executed

### 1.2 Spec Block Structure

```move
spec function_name {
    // Preconditions (what must be true before function executes)
    requires condition1;
    requires condition2;
    
    // Postconditions (what must be true after function executes)
    ensures property1;
    ensures property2;
    
    // Abort conditions (when function is allowed to abort)
    aborts_if error_condition1 with ERROR_CODE1;
    aborts_if error_condition2 with ERROR_CODE2;
    
    // Modifies clause (what resources this function may change)
    modifies global<ResourceType>(addr);
    
    // Pragmas (hints to the prover)
    pragma opaque;
    pragma verify = true;
}
```

### 1.3 Spec Function vs Implementation Function

**Spec functions:** Pure mathematical functions, only callable in specs.

```move
spec fun sum_balance(balance: vector<u8>): u256 {
    if (len(balance) == 0) {
        0
    } else {
        balance[0] as u256 + sum_balance(slice(balance, 1, len(balance)))
    }
}
```

**Implementation functions:** Actual Move code, callable in Move.

```move
public fun sum_balance(balance: &vector<u8>): u256 {
    let sum = 0u256;
    let i = 0;
    while (i < vector::length(balance)) {
        sum = sum + (*vector::borrow(balance, i) as u256);
        i = i + 1;
    };
    sum
}
```

**Bridge:** Connect spec function to implementation.

```move
spec sum_balance {
    ensures result == spec::sum_balance(balance);
}
```

---

## 2. Basic Specification Patterns

### Pattern 1: Resource Existence Check

**Use case:** Verify resource exists before accessing.

```move
spec function_name {
    requires exists<ConfidentialAssetStore>(addr);
    
    aborts_if !exists<ConfidentialAssetStore>(addr) with ESTORE_NOT_FOUND;
}
```

**Variation: Multiple resources**

```move
spec function_name {
    requires exists<ConfidentialAssetStore>(sender);
    requires exists<ConfidentialAssetStore>(receiver);
    
    aborts_if !exists<ConfidentialAssetStore>(sender) with ESTORE_NOT_FOUND;
    aborts_if !exists<ConfidentialAssetStore>(receiver) with ESTORE_NOT_FOUND;
}
```

---

### Pattern 2: Field Preservation

**Use case:** Prove certain fields don't change.

```move
spec withdraw_to_internal {
    ensures global<ConfidentialAssetStore>(addr).frozen == 
            old(global<ConfidentialAssetStore>(addr).frozen);
    
    ensures global<ConfidentialAssetStore>(addr).allow_list == 
            old(global<ConfidentialAssetStore>(addr).allow_list);
    
    // Only balance changes
    ensures global<ConfidentialAssetStore>(addr).balance != 
            old(global<ConfidentialAssetStore>(addr).balance);
}
```

**Shorthand with helper:**

```move
spec fun store_frame_preserved(addr: address): bool {
    global<ConfidentialAssetStore>(addr).frozen == 
        old(global<ConfidentialAssetStore>(addr).frozen) &&
    global<ConfidentialAssetStore>(addr).allow_list == 
        old(global<ConfidentialAssetStore>(addr).allow_list)
}

spec withdraw_to_internal {
    ensures store_frame_preserved(addr);
}
```

---

### Pattern 3: Balance Conservation

**Use case:** Prove total balance is preserved across operations.

```move
spec confidential_transfer_internal {
    let sender_addr = sender;
    let receiver_addr = receiver;
    
    let old_sender_balance = old(global<ConfidentialAssetStore>(sender_addr).balance);
    let old_receiver_balance = old(global<ConfidentialAssetStore>(receiver_addr).balance);
    let new_sender_balance = global<ConfidentialAssetStore>(sender_addr).balance;
    let new_receiver_balance = global<ConfidentialAssetStore>(receiver_addr).balance;
    
    ensures sum_balance(old_sender_balance) + sum_balance(old_receiver_balance) == 
            sum_balance(new_sender_balance) + sum_balance(new_receiver_balance);
}
```

---

### Pattern 4: Length Preservation

**Use case:** Prove vector lengths don't change.

```move
spec normalize_internal {
    ensures len(global<ConfidentialAssetStore>(addr).pending_balance) == 
            len(old(global<ConfidentialAssetStore>(addr).pending_balance));
    
    ensures len(global<ConfidentialAssetStore>(addr).actual_balance) == 
            len(old(global<ConfidentialAssetStore>(addr).actual_balance));
}
```

**Why important for CA:** Balance vectors have cryptographic structure; changing length breaks encryption.

---

## 3. Advanced Patterns

### Pattern 5: Conditional Property

**Use case:** Property holds only under certain conditions.

```move
spec freeze_token_internal {
    // If not already frozen, freeze it
    ensures !old(global<ConfidentialAssetStore>(addr).frozen) ==> 
            global<ConfidentialAssetStore>(addr).frozen;
    
    // If already frozen, stays frozen
    ensures old(global<ConfidentialAssetStore>(addr).frozen) ==> 
            global<ConfidentialAssetStore>(addr).frozen;
}
```

**Simplified:**

```move
spec freeze_token_internal {
    ensures global<ConfidentialAssetStore>(addr).frozen;
    // Regardless of old state, result is frozen
}
```

---

### Pattern 6: Disjunctive Abort

**Use case:** Function aborts if ANY of several conditions holds.

```move
spec withdraw_to_internal {
    aborts_if !exists<ConfidentialAssetStore>(addr);
    aborts_if global<ConfidentialAssetStore>(addr).frozen;
    aborts_if sum_balance(global<ConfidentialAssetStore>(addr).balance) < amount;
    
    // Abort code depends on which condition triggered
    aborts_if !exists<ConfidentialAssetStore>(addr) with ESTORE_NOT_FOUND;
    aborts_if global<ConfidentialAssetStore>(addr).frozen with ESTORE_FROZEN;
    aborts_if sum_balance(...) < amount with EINSUFFICIENT_BALANCE;
}
```

---

### Pattern 7: Forall Quantification

**Use case:** Property holds for all elements.

```move
spec batch_transfer_internal {
    requires forall i in 0..len(recipients): 
        exists<ConfidentialAssetStore>(recipients[i]);
    
    ensures forall i in 0..len(recipients):
        sum_balance(global<ConfidentialAssetStore>(recipients[i]).balance) ==
        old(sum_balance(global<ConfidentialAssetStore>(recipients[i]).balance)) + amounts[i];
}
```

**Performance note:** Quantifiers are expensive. See §10 for optimization.

---

## 4. Crypto-Opaque Boundary Pattern

### 4.1 The Problem

CA crypto functions (Ristretto, Bulletproofs, Sigma protocols) are too complex for SMT solvers.

**Naive approach (doesn't work):**
```move
spec verify_transfer_proof {
    ensures result == sigma_verify(proof, sender, receiver, amount);
    // Z3 can't reason about elliptic curves!
}
```

### 4.2 The Solution: Pragma Opaque

**Mark crypto functions as opaque (uninterpreted):**

```move
spec verify_transfer_proof_internal {
    pragma opaque;
    aborts_if false;  // Never aborts (returns bool, doesn't abort)
}
```

**Then in caller:**

```move
spec confidential_transfer_internal {
    // Assume verify_transfer_proof_internal is correct (verified separately in Lean)
    aborts_if !verify_transfer_proof_internal(proof) with EVERIFY_FAILED;
}
```

### 4.3 Complete Crypto-Opaque Pattern

**In `confidential_proof.spec.move`:**

```move
spec module {
    // Declare crypto functions opaque at module level
    pragma opaque = verify_transfer_proof_internal;
    pragma opaque = verify_withdrawal_proof_internal;
    pragma opaque = verify_normalization_proof_internal;
    pragma opaque = verify_rotation_proof_internal;
}

spec verify_transfer_proof_internal {
    pragma opaque;
    aborts_if false;
}

spec verify_withdrawal_proof_internal {
    pragma opaque;
    aborts_if false;
}
```

**In `confidential_asset.spec.move`:**

```move
spec confidential_transfer_internal {
    // Use crypto function as black box
    requires verify_transfer_proof_internal(proof);  // Precondition: proof valid
    
    // OR
    aborts_if !verify_transfer_proof_internal(proof) with EVERIFY_FAILED;
}
```

**Verification split:**
- **MSL proves:** State manipulation correct *given* proof is valid
- **Lean proves:** Bytecode for `verify_transfer_proof_internal` matches sigma math
- **Composition:** Trust both

---

## 5. Balance Preservation Patterns

### 5.1 Simple Balance Change

**Use case:** Single account balance changes.

```move
spec withdraw_to_internal {
    ensures sum_balance(global<ConfidentialAssetStore>(addr).balance) == 
            old(sum_balance(global<ConfidentialAssetStore>(addr).balance)) - amount;
}
```

### 5.2 Transfer (Two-Account Balance Conservation)

**Use case:** Balance moves from sender to receiver.

```move
spec transfer_internal {
    let sender_addr = sender;
    let receiver_addr = receiver;
    
    ensures sum_balance(global<ConfidentialAssetStore>(sender_addr).balance) == 
            old(sum_balance(global<ConfidentialAssetStore>(sender_addr).balance)) - amount;
    
    ensures sum_balance(global<ConfidentialAssetStore>(receiver_addr).balance) == 
            old(sum_balance(global<ConfidentialAssetStore>(receiver_addr).balance)) + amount;
    
    // Total conserved
    ensures sum_balance(global<ConfidentialAssetStore>(sender_addr).balance) +
            sum_balance(global<ConfidentialAssetStore>(receiver_addr).balance) ==
            old(sum_balance(global<ConfidentialAssetStore>(sender_addr).balance)) +
            old(sum_balance(global<ConfidentialAssetStore>(receiver_addr).balance));
}
```

### 5.3 Batch Operations

**Use case:** Multiple transfers in one transaction.

```move
spec batch_transfer_internal {
    let sender_addr = sender;
    
    // Sender loses sum of all amounts
    ensures sum_balance(global<ConfidentialAssetStore>(sender_addr).balance) ==
            old(sum_balance(global<ConfidentialAssetStore>(sender_addr).balance)) - 
            vector_sum(amounts);
    
    // Each recipient gains their amount
    ensures forall i in 0..len(recipients):
        sum_balance(global<ConfidentialAssetStore>(recipients[i]).balance) ==
        old(sum_balance(global<ConfidentialAssetStore>(recipients[i]).balance)) + amounts[i];
}
```

---

## 6. Frame Conditions

### 6.1 What are Frame Conditions?

**Frame axiom:** "What doesn't change stays the same."

**Example:** `withdraw_to` changes only the caller's balance, not other accounts.

### 6.2 Explicit Frame Pattern

```move
spec withdraw_to_internal {
    // Changes only this account
    modifies global<ConfidentialAssetStore>(addr);
    
    // Other accounts unchanged
    ensures forall other_addr: address where other_addr != addr:
        global<ConfidentialAssetStore>(other_addr) == 
        old(global<ConfidentialAssetStore>(other_addr));
}
```

**Problem:** Expensive quantifier.

### 6.3 Implicit Frame (Modifies Clause)

**Better approach:** Use `modifies` clause, Move Prover infers frame.

```move
spec withdraw_to_internal {
    modifies global<ConfidentialAssetStore>(addr);
    // Prover automatically knows: all other ConfidentialAssetStore unchanged
}
```

### 6.4 Field-Level Frame

**Use case:** Function changes only specific fields.

```move
spec freeze_token_internal {
    // Only frozen field changes
    ensures global<ConfidentialAssetStore>(addr).balance == 
            old(global<ConfidentialAssetStore>(addr).balance);
    ensures global<ConfidentialAssetStore>(addr).allow_list == 
            old(global<ConfidentialAssetStore>(addr).allow_list);
    
    // frozen may change
    ensures global<ConfidentialAssetStore>(addr).frozen;
}
```

---

## 7. Abort Specification Patterns

### 7.1 Complete Abort Specification

**Best practice:** Specify ALL abort conditions, not just some.

**Incomplete (bad):**
```move
spec withdraw_to {
    aborts_if global<ConfidentialAssetStore>(addr).frozen;
    // What about ESTORE_NOT_FOUND? EINSUFFICIENT_BALANCE?
}
```

**Complete (good):**
```move
spec withdraw_to {
    aborts_if !exists<ConfidentialAssetStore>(addr) with ESTORE_NOT_FOUND;
    aborts_if global<ConfidentialAssetStore>(addr).frozen with ESTORE_FROZEN;
    aborts_if sum_balance(global<ConfidentialAssetStore>(addr).balance) < amount 
        with EINSUFFICIENT_BALANCE;
    aborts_if !verify_withdrawal_proof(proof) with EVERIFY_FAILED;
}
```

### 7.2 Abort Code Precision

**Pattern:** Every `aborts_if` has exact error code.

```move
spec function_name {
    aborts_if condition1 with ERROR_CODE_1;
    aborts_if condition2 with ERROR_CODE_2;
    // NOT: aborts_if condition1 || condition2;
}
```

**Why:** Difftest checks exact abort codes. Imprecise specs miss bugs.

### 7.3 Never Aborts

**Use case:** Function is total (always succeeds).

```move
spec helper_function {
    aborts_if false;  // Never aborts
}
```

**Alternative:**
```move
spec helper_function {
    ensures result == expected_value;
    // No aborts_if clause → Move Prover assumes it may abort anywhere
    // So better to be explicit: aborts_if false
}
```

---

## 8. Quantifier Patterns

### 8.1 Universal Quantification (forall)

**Pattern:**
```move
forall <var> in <range> where <filter>: <property>
```

**Example:**
```move
spec batch_transfer {
    requires forall i in 0..len(recipients): 
        exists<ConfidentialAssetStore>(recipients[i]);
}
```

**Performance tip:** Avoid nested quantifiers.

**Bad (O(N²)):**
```move
ensures forall i in 0..len(v): 
    forall j in 0..len(v): 
        i != j ==> v[i] != v[j];
```

**Good (O(N)):**
```move
ensures all_unique(v);  // Defined as spec fun with single loop
```

### 8.2 Existential Quantification (exists)

**Pattern:**
```move
exists <var> in <range> where <filter>: <property>
```

**Example:**
```move
spec find_index {
    ensures exists i in 0..len(list): list[i] == target;
}
```

**Performance tip:** Existentials are expensive. Avoid if possible.

### 8.3 Bounded Quantification

**Always bound quantifiers:** Unbounded quantifiers don't terminate.

**Bad (unbounded):**
```move
ensures forall x: address: ...;  // Over ALL addresses? Infinite!
```

**Good (bounded):**
```move
ensures forall i in 0..len(recipients): ...;  // Finite range
```

---

## 9. Spec Function Library

### 9.1 Vector Sum

```move
spec fun vector_sum(v: vector<u64>): u256 {
    if (len(v) == 0) {
        0
    } else {
        (v[0] as u256) + vector_sum(slice(v, 1, len(v)))
    }
}
```

### 9.2 All Unique

```move
spec fun all_unique<T>(v: vector<T>): bool {
    forall i in 0..len(v):
        forall j in 0..len(v):
            i != j ==> v[i] != v[j]
}
```

**Optimized version:**

```move
spec fun all_unique<T>(v: vector<T>): bool {
    forall i in 0..len(v):
        !vector::contains(&slice(v, i+1, len(v)), &v[i])
}
```

### 9.3 Range Check

```move
spec fun all_in_range(v: vector<u64>, min: u64, max: u64): bool {
    forall i in 0..len(v): min <= v[i] && v[i] <= max
}
```

### 9.4 Sorted

```move
spec fun is_sorted(v: vector<u64>): bool {
    forall i in 0..(len(v)-1): v[i] <= v[i+1]
}
```

---

## 10. Performance Patterns

### 10.1 Pragma Opaque for Expensive Functions

**Use case:** Function body is complex, inlining creates huge VCs.

```move
spec fun complex_computation(x: u64, y: u64): u64 {
    pragma opaque;
    // Body hidden from SMT solver
}

spec function_name {
    ensures result == complex_computation(a, b);
    // Prover treats complex_computation as uninterpreted function
}
```

### 10.2 Factor Out Repeated Expressions

**Bad (repeated evaluation):**
```move
spec withdraw_to {
    requires sum_balance(global<ConfidentialAssetStore>(addr).balance) >= amount;
    ensures sum_balance(global<ConfidentialAssetStore>(addr).balance) == 
            old(sum_balance(global<ConfidentialAssetStore>(addr).balance)) - amount;
}
```

**Good (let binding):**
```move
spec withdraw_to {
    let old_balance_sum = old(sum_balance(global<ConfidentialAssetStore>(addr).balance));
    let new_balance_sum = sum_balance(global<ConfidentialAssetStore>(addr).balance);
    
    requires old_balance_sum >= amount;
    ensures new_balance_sum == old_balance_sum - amount;
}
```

### 10.3 Simplify Quantifiers

**Bad (complex body):**
```move
ensures forall i in 0..len(recipients):
    sum_balance(global<ConfidentialAssetStore>(recipients[i]).balance) ==
    old(sum_balance(global<ConfidentialAssetStore>(recipients[i]).balance)) + amounts[i];
```

**Good (helper function):**
```move
spec fun recipient_balance_increased(i: u64): bool {
    sum_balance(global<ConfidentialAssetStore>(recipients[i]).balance) ==
    old(sum_balance(global<ConfidentialAssetStore>(recipients[i]).balance)) + amounts[i]
}

ensures forall i in 0..len(recipients): recipient_balance_increased(i);
```

---

## 11. Anti-Patterns to Avoid

### Anti-Pattern 1: Partial Abort Specification

**Problem:** Missing abort conditions.

```move
spec function_name {
    aborts_if condition1;
    // But function can also abort on condition2!
}
```

**Fix:** Specify ALL abort conditions.

---

### Anti-Pattern 2: Circular Spec Function

**Problem:** Recursive spec function without base case.

```move
spec fun sum(v: vector<u64>): u64 {
    sum(v)  // Infinite recursion!
}
```

**Fix:** Always have base case.

```move
spec fun sum(v: vector<u64>): u64 {
    if (len(v) == 0) { 0 } else { v[0] + sum(slice(v, 1, len(v))) }
}
```

---

### Anti-Pattern 3: Quantifier Alternation

**Problem:** Nested quantifiers (expensive).

```move
ensures forall i: exists j: ...;  // O(N × M) SMT queries
```

**Fix:** Flatten or use spec functions.

---

### Anti-Pattern 4: Modifying Read-Only Function

**Problem:** Spec says function modifies state, but code is read-only.

```move
public fun get_balance(addr: address): u64 acquires ConfidentialAssetStore {
    borrow_global<ConfidentialAssetStore>(addr).balance
}

spec get_balance {
    modifies global<ConfidentialAssetStore>(addr);  // WRONG! Read-only function.
}
```

**Fix:** No `modifies` clause for read-only functions.

---

### Anti-Pattern 5: Incomplete Ensures

**Problem:** Spec doesn't fully specify behavior.

```move
spec transfer {
    ensures global<ConfidentialAssetStore>(sender).balance < 
            old(global<ConfidentialAssetStore>(sender).balance);
    // Sender balance decreased, but by how much? Missing precision.
}
```

**Fix:** Specify exact change.

```move
ensures global<ConfidentialAssetStore>(sender).balance == 
        old(global<ConfidentialAssetStore>(sender).balance) - amount;
```

---

## 12. Complete Examples

### Example 1: Deposit (No Crypto)

```move
spec deposit_to_internal {
    let addr = user_addr;
    
    // Preconditions
    requires exists<ConfidentialAssetStore>(addr);
    requires len(encrypted_amount) == CHUNK_SIZE;
    
    // Postconditions
    ensures len(global<ConfidentialAssetStore>(addr).pending_balance) ==
            len(old(global<ConfidentialAssetStore>(addr).pending_balance));
    
    ensures sum_balance(global<ConfidentialAssetStore>(addr).pending_balance) ==
            old(sum_balance(global<ConfidentialAssetStore>(addr).pending_balance)) + amount;
    
    // Frame: actual_balance unchanged
    ensures global<ConfidentialAssetStore>(addr).actual_balance ==
            old(global<ConfidentialAssetStore>(addr).actual_balance);
    
    // Abort conditions
    aborts_if !exists<ConfidentialAssetStore>(addr) with ESTORE_NOT_FOUND;
    aborts_if global<ConfidentialAssetStore>(addr).frozen with ESTORE_FROZEN;
    aborts_if len(encrypted_amount) != CHUNK_SIZE with EINVALID_CHUNK_SIZE;
}
```

### Example 2: Withdraw (With Crypto Boundary)

```move
spec withdraw_to_internal {
    let addr = user_addr;
    
    // Preconditions
    requires exists<ConfidentialAssetStore>(addr);
    requires verify_withdrawal_proof_internal(proof);  // Crypto boundary
    
    // Postconditions
    ensures len(global<ConfidentialAssetStore>(addr).pending_balance) ==
            len(old(global<ConfidentialAssetStore>(addr).pending_balance));
    
    ensures sum_balance(global<ConfidentialAssetStore>(addr).pending_balance) ==
            old(sum_balance(global<ConfidentialAssetStore>(addr).pending_balance)) - amount;
    
    // Frame
    ensures global<ConfidentialAssetStore>(addr).frozen ==
            old(global<ConfidentialAssetStore>(addr).frozen);
    
    // Abort conditions
    aborts_if !exists<ConfidentialAssetStore>(addr) with ESTORE_NOT_FOUND;
    aborts_if global<ConfidentialAssetStore>(addr).frozen with ESTORE_FROZEN;
    aborts_if sum_balance(global<ConfidentialAssetStore>(addr).pending_balance) < amount
        with EINSUFFICIENT_BALANCE;
    aborts_if !verify_withdrawal_proof_internal(proof) with EVERIFY_FAILED;
}
```

### Example 3: Transfer (Two Accounts + Crypto)

```move
spec confidential_transfer_internal {
    let sender_addr = sender;
    let receiver_addr = receiver;
    
    // Preconditions
    requires exists<ConfidentialAssetStore>(sender_addr);
    requires exists<ConfidentialAssetStore>(receiver_addr);
    requires sender_addr != receiver_addr;  // No self-transfer
    requires verify_transfer_proof_internal(proof);  // Crypto boundary
    
    // Balance conservation
    let old_sender = old(sum_balance(global<ConfidentialAssetStore>(sender_addr).balance));
    let old_receiver = old(sum_balance(global<ConfidentialAssetStore>(receiver_addr).balance));
    let new_sender = sum_balance(global<ConfidentialAssetStore>(sender_addr).balance);
    let new_receiver = sum_balance(global<ConfidentialAssetStore>(receiver_addr).balance);
    
    ensures new_sender == old_sender - amount;
    ensures new_receiver == old_receiver + amount;
    ensures new_sender + new_receiver == old_sender + old_receiver;  // Total conserved
    
    // Length preservation
    ensures len(global<ConfidentialAssetStore>(sender_addr).balance) ==
            len(old(global<ConfidentialAssetStore>(sender_addr).balance));
    ensures len(global<ConfidentialAssetStore>(receiver_addr).balance) ==
            len(old(global<ConfidentialAssetStore>(receiver_addr).balance));
    
    // Frame: freeze states unchanged
    ensures global<ConfidentialAssetStore>(sender_addr).frozen ==
            old(global<ConfidentialAssetStore>(sender_addr).frozen);
    ensures global<ConfidentialAssetStore>(receiver_addr).frozen ==
            old(global<ConfidentialAssetStore>(receiver_addr).frozen);
    
    // Abort conditions
    aborts_if !exists<ConfidentialAssetStore>(sender_addr) with ESTORE_NOT_FOUND;
    aborts_if !exists<ConfidentialAssetStore>(receiver_addr) with ESTORE_NOT_FOUND;
    aborts_if sender_addr == receiver_addr with ESELF_TRANSFER;
    aborts_if global<ConfidentialAssetStore>(sender_addr).frozen with ESENDER_FROZEN;
    aborts_if global<ConfidentialAssetStore>(receiver_addr).frozen with ERECEIVER_FROZEN;
    aborts_if old_sender < amount with EINSUFFICIENT_BALANCE;
    aborts_if !verify_transfer_proof_internal(proof) with EVERIFY_FAILED;
}
```

---

## Appendix A: MSL Quick Reference

| Clause | Purpose | Example |
|--------|---------|---------|
| `requires` | Precondition | `requires x > 0;` |
| `ensures` | Postcondition | `ensures result == x + 1;` |
| `aborts_if` | Abort condition | `aborts_if x == 0 with EDIV_BY_ZERO;` |
| `modifies` | Side effects | `modifies global<T>(addr);` |
| `pragma opaque` | Hide function body | `pragma opaque;` |
| `let` | Local binding | `let y = x + 1;` |
| `old(expr)` | Pre-state value | `old(balance)` |
| `global<T>(addr)` | Access resource | `global<Store>(0x1)` |
| `exists<T>(addr)` | Resource exists | `exists<Store>(addr)` |
| `forall` | Universal quantifier | `forall i in 0..len(v): ...` |

---

## Appendix B: Common Spec Functions

```move
// Vector operations
spec fun len<T>(v: vector<T>): u64;
spec fun slice<T>(v: vector<T>, start: u64, end: u64): vector<T>;
spec fun contains<T>(v: &vector<T>, e: &T): bool;

// Arithmetic
spec fun max(x: u64, y: u64): u64;
spec fun min(x: u64, y: u64): u64;

// Logic
spec fun implies(p: bool, q: bool): bool { !p || q }
```

---

**END OF GUIDE**

**Key Takeaway:** Good MSL specs are precise (complete abort conditions), performant (avoid quantifiers), and maintainable (use spec functions for reuse).

**References:**
- CA MSL specs: `aptos-experimental/sources/confidential_asset/*.spec.move`
- Move Prover docs: https://github.com/move-language/move/tree/main/language/move-prover/doc
- MSL tutorial: https://github.com/move-language/move/blob/main/language/move-prover/doc/user/spec-lang.md
