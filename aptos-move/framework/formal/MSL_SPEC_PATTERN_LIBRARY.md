# Move Specification Language (MSL) Pattern Library

**Purpose:** Comprehensive reference of MSL specification patterns used in Confidential Assets, with detailed examples, common pitfalls, and integration with Lean/difftest verification.

**Audience:** Engineers writing MSL specs for new CA operations or auditing existing specs.

---

## Table of Contents

1. [Balance Conservation Patterns](#1-balance-conservation-patterns)
2. [Length Preservation Invariants](#2-length-preservation-invariants)
3. [Abort Condition Enumeration](#3-abort-condition-enumeration)
4. [Frame Conditions (Non-Interference)](#4-frame-conditions-non-interference)
5. [Pragma Opaque for Crypto Boundaries](#5-pragma-opaque-for-crypto-boundaries)
6. [Spec Functions for Derived Properties](#6-spec-functions-for-derived-properties)
7. [Conditional Postconditions](#7-conditional-postconditions)
8. [Quantified Invariants](#8-quantified-invariants)
9. [Frozen Account Guards](#9-frozen-account-guards)
10. [Allow List Enforcement](#10-allow-list-enforcement)
11. [Proof Verification Guards](#11-proof-verification-guards)
12. [Fungible Asset Composition](#12-fungible-asset-composition)
13. [Resource Invariants](#13-resource-invariants)
14. [Event Emission Specs](#14-event-emission-specs)
15. [Generic Type Constraints](#15-generic-type-constraints)

---

## 1. Balance Conservation Patterns

### 1.1 Sum preservation (exact equality)

**Use case:** Operations that rearrange balance chunks without changing the total value (normalization, internal transfers).

**Pattern:**
```move
spec normalize_internal(store: &mut ConfidentialAssetStore, proof: &NormalizationProof) {
    let old_sum = sum_balance_chunks(old(store.pending_balance));
    let new_sum = sum_balance_chunks(store.pending_balance);
    ensures old_sum == new_sum;
}
```

**Spec function definition:**
```move
spec fun sum_balance_chunks(chunks: vector<BalanceChunk>): u64 {
    // Abstract spec function; implementation omitted
    // Represents the sum of all chunk values
}
```

**Why it works:**
- `old(store.pending_balance)` captures the value before mutation
- The spec function is pure and deterministic
- Move Prover verifies via SMT that the sum is preserved across all paths

**Common pitfalls:**
- **Forgetting `old()`** — without it, you're comparing post-state to post-state (always true)
- **Using `u64` for sum** — if total can exceed `u64::MAX`, use `u128` or `num` (unbounded)
- **Not accounting for overflow** — ensure the spec function handles overflow semantics

**Related patterns:** Length preservation (#2), Conditional postconditions (#7)

---

### 1.2 Balance delta (withdrawal/deposit)

**Use case:** Operations that increase or decrease the total balance by a known amount.

**Pattern (withdrawal):**
```move
spec withdraw_to_internal(store: &mut ConfidentialAssetStore, amount: u64, proof: &WithdrawalProof) {
    let old_sum = sum_balance_chunks(old(store.pending_balance));
    let new_sum = sum_balance_chunks(store.pending_balance);
    ensures old_sum == new_sum + amount;
}
```

**Pattern (deposit):**
```move
spec deposit_to_internal(store: &mut ConfidentialAssetStore, amount: u64) {
    let old_sum = sum_balance_chunks(old(store.pending_balance));
    let new_sum = sum_balance_chunks(store.pending_balance);
    ensures new_sum == old_sum + amount;
}
```

**Common pitfalls:**
- **Reversing the equation** — withdrawal as `new == old + amount` is wrong
- **Off-by-one in chunk indexing** — ensure the sum accounts correctly

---

### 1.3 Multi-party conservation (transfer)

**Use case:** Operations that transfer value between accounts.

**Pattern:**
```move
spec confidential_transfer_internal(
    sender_store: &mut ConfidentialAssetStore,
    recipient_store: &mut ConfidentialAssetStore,
    amount: u64,
    proof: &TransferProof
) {
    let sender_old_sum = sum_balance_chunks(old(sender_store.pending_balance));
    let sender_new_sum = sum_balance_chunks(sender_store.pending_balance);
    let recipient_old_sum = sum_balance_chunks(old(recipient_store.pending_balance));
    let recipient_new_sum = sum_balance_chunks(recipient_store.pending_balance);
    
    ensures sender_old_sum == sender_new_sum + amount;
    ensures recipient_new_sum == recipient_old_sum + amount;
}
```

---

## Summary

This library provides 15 core MSL specification patterns used throughout Confidential Assets verification. Each pattern includes:

- Concrete code examples
- Common pitfalls
- Integration with Lean and difftest
- Best practices

Use these patterns as templates when writing new MSL specs for CA operations.
