# MSL Debugging and Verification Guide

**Audience:** Verification engineers debugging Move Prover failures  
**Prerequisites:** MSL basics, Move Prover setup (plan §5.1)  
**Related:** `MSL_SPECIFICATION_PATTERNS_GUIDE.md`, `MSL_TO_LEAN_COORDINATION_GUIDE.md`

## Purpose

This guide provides systematic debugging strategies for Move Prover verification failures. Covers interpreting error messages, diagnosing timeouts, fixing false failures, and optimizing slow specs.

## Table of Contents

1. [Common Failure Modes](#common-failure-modes)
2. [Interpreting Error Messages](#interpreting-error-messages)
3. [Debugging Workflow](#debugging-workflow)
4. [Timeout Diagnosis](#timeout-diagnosis)
5. [False Failure Fixes](#false-failure-fixes)
6. [Performance Optimization](#performance-optimization)

---

## Common Failure Modes

### Failure Mode 1: Verification Condition (VC) Fails

**Symptom:**
```
error: post-condition does not hold
  ┌─ confidential_asset.spec.move:42:9
  │
42 │     ensures balance_sum(global<Store>(addr).balance) == 
   │             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

**Meaning:** Z3 found a counterexample where the `ensures` clause is false

**Cause:** Either:
- Spec is too strong (claims something not true)
- Code is buggy (doesn't satisfy spec)

**Example:**
```move
spec withdraw_to_internal {
    ensures balance_sum(global<Store>(addr).balance) == 
            old(balance_sum(global<Store>(addr).balance)) - amount;
    // ❌ Fails if balance < amount (underflow)
}
```

**Fix:** Add precondition or abort condition:
```move
spec withdraw_to_internal {
    requires balance_sum(global<Store>(addr).balance) >= amount;  // Precondition
    aborts_if balance_sum(global<Store>(addr).balance) < amount;  // Or abort spec
    
    ensures balance_sum(global<Store>(addr).balance) == 
            old(balance_sum(global<Store>(addr).balance)) - amount;
}
```

### Failure Mode 2: Timeout

**Symptom:**
```
timeout: verification condition at confidential_asset.spec.move:42 timed out after 40s
```

**Meaning:** Z3 couldn't decide within timeout (default 40s)

**Cause:**
- Spec too complex (e.g., nested quantifiers)
- SMT solver search space explosion
- Expensive spec functions

**Example:**
```move
spec transfer_internal {
    ensures forall i in 0..len(recipients):
        forall j in 0..len(recipients):
            i != j ==> recipients[i] != recipients[j];  // O(N²) quantifier
}
```

**Fix:** Simplify or increase timeout:
```move
spec transfer_internal {
    pragma timeout = 120;  // Increase timeout to 2 minutes
    
    // OR: Replace nested quantifier with spec function
    ensures all_unique(recipients);
}

spec fun all_unique<T>(v: vector<T>): bool {
    forall i in 0..len(v):
        !vector::contains(&slice(v, i+1, len(v)), &v[i])
    // Still O(N²) but easier for Z3
}
```

### Failure Mode 3: Incomplete Abort Specification

**Symptom:**
```
error: abort not covered
  ┌─ confidential_asset.spec.move:42:5
  │
42 │     ensures balance > 0;
   │     ^^^^^^^^^^^^^^^^^^^^
```

**Meaning:** Function can abort in ways not specified by `aborts_if`

**Cause:** Missing `aborts_if` clause

**Example:**
```move
spec withdraw_to_internal {
    aborts_if !exists<Store>(addr);
    // ❌ Missing: aborts if frozen, aborts if balance < amount
}
```

**Fix:** Add all abort conditions:
```move
spec withdraw_to_internal {
    pragma aborts_if_is_strict;  // Enforce completeness
    
    aborts_if !exists<Store>(addr) with ESTORE_NOT_FOUND;
    aborts_if global<Store>(addr).frozen with ESTORE_FROZEN;
    aborts_if balance_sum(global<Store>(addr).balance) < amount with EINSUFFICIENT_BALANCE;
}
```

### Failure Mode 4: Boogie Compilation Error

**Symptom:**
```
error: undeclared identifier: spec_scalar_from_u64_internal
```

**Meaning:** Boogie codegen failed (before Z3 runs)

**Cause:** Upstream framework spec bug or missing monomorphization

**Example:** Ristretto255 vector-of-CompressedRistretto (Plan Phase 0 blocker)

**Fix:** Apply patches from `PHASE_0_RISTRETTO255_PATCH_NOTES.md` or mark `pragma opaque`

### Failure Mode 5: False Counterexample

**Symptom:**
```
error: post-condition does not hold
  counterexample:
    addr = 0x1
    amount = 0
```

But `amount = 0` is rejected by code (`assert!(amount > 0)`).

**Meaning:** Spec doesn't rule out impossible inputs

**Cause:** Missing `aborts_if` or `requires`

**Fix:**
```move
spec withdraw_to_internal {
    requires amount > 0;  // OR: aborts_if amount == 0;
    ensures ...;
}
```

---

## Interpreting Error Messages

### Error: "post-condition does not hold"

**Full example:**
```
error: post-condition does not hold
  ┌─ confidential_asset.spec.move:42:9
  │
42 │     ensures balance_sum(global<Store>(addr).balance) == 
   │             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  │
  = counterexample:
      addr = 0x1
      amount = 100
      balance (before) = 50
      balance (after) = 0
```

**What it means:**
- Line 42: The `ensures` clause that failed
- Counterexample: Concrete values Z3 found where `ensures` is false

**How to interpret:**
- Check if counterexample is realistic (possible in real execution)
- If realistic: spec is wrong or code is buggy
- If unrealistic: missing precondition or abort spec

**Example diagnosis:**
- Before: 50, After: 0, Amount: 100
- Expected: After = Before - Amount = 50 - 100 = -50 (impossible, u64 can't be negative)
- Conclusion: Missing `aborts_if balance < amount`

**Fix:**
```move
aborts_if balance_sum(...) < amount with EINSUFFICIENT_BALANCE;
```

### Error: "timeout"

**Full example:**
```
timeout: verification condition at confidential_asset.spec.move:42 timed out after 40s
  ┌─ confidential_asset.spec.move:42:9
  │
42 │     ensures forall i in 0..len(v): P(v[i]);
   │             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

**What it means:**
- Z3 couldn't decide if `ensures` holds within 40 seconds
- Not a definite failure, just "unknown"

**Common causes:**
- Quantifier (forall/exists) → exponential search
- Non-linear arithmetic (multiplication, division)
- Large spec function (many branches)

**Diagnosis steps:**
1. **Simplify spec:** Remove parts of `ensures`, see if timeout persists
2. **Check quantifier nesting:** Nested `forall` is O(N²), avoid
3. **Increase timeout:** `pragma timeout = 120` (last resort)

### Error: "abort not covered"

**Full example:**
```
error: abort not covered
  ┌─ confidential_asset.move:42:9
  │
42 │     assert!(balance >= amount, EINSUFFICIENT_BALANCE);
   │     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  │
  = at confidential_asset.spec.move:20:5
  note: abort code EINSUFFICIENT_BALANCE is not specified
```

**What it means:**
- Code aborts with `EINSUFFICIENT_BALANCE`, but spec doesn't list this in `aborts_if`

**Fix:**
```move
spec withdraw_to_internal {
    aborts_if balance < amount with EINSUFFICIENT_BALANCE;
}
```

### Error: "undeclared identifier"

**Full example:**
```
error: undeclared identifier: balance_sum
  ┌─ confidential_asset.spec.move:42:13
  │
42 │     ensures balance_sum(global<Store>(addr).balance) == ...;
   │             ^^^^^^^^^^^
```

**What it means:**
- Spec function `balance_sum` not found (typo, wrong scope, or not defined)

**Diagnosis:**
1. Check spelling: `balance_sum` vs `balanceSum`
2. Check scope: Is `balance_sum` defined in current module?
3. Check import: If in different module, need `use` statement

**Fix:**
```move
spec module {
    use aptos_experimental::confidential_balance;  // Import module
    
    spec withdraw_to_internal {
        ensures confidential_balance::balance_sum(...) == ...;  // Qualified name
    }
}
```

---

## Debugging Workflow

### Step 1: Isolate the Failing Spec

**Goal:** Narrow down which `ensures`/`aborts_if` clause is failing

**Process:**
```bash
# Run Move Prover on single function
movement move prove --package-dir aptos-experimental \
    --filter withdraw_to_internal \
    --verbose

# Output will show which VC failed (e.g., "VC #3: ensures clause at line 42")
```

**If multiple VCs fail:** Comment out all `ensures` clauses except one, find which fails

```move
spec withdraw_to_internal {
    // ensures balance > 0;  // Comment out
    ensures balance_sum(...) == old(balance_sum(...)) - amount;  // Test this one
    // ensures frozen == old(frozen);  // Comment out
}
```

**Repeat:** Uncomment one at a time, find all failing clauses

### Step 2: Examine Counterexample

**Read counterexample carefully:**
```
counterexample:
  addr = 0x1
  amount = 100
  frozen (before) = false
  balance (before) = 50
  balance (after) = 50  # ❌ Expected: 50 - 100 = -50 (impossible)
```

**Questions to ask:**
1. Is this input realistic? (Can `amount > balance` happen in real execution?)
2. If realistic, is the code buggy? (Should balance decrease, but didn't?)
3. If unrealistic, what precondition/abort is missing?

### Step 3: Check Code vs Spec

**Compare code to spec:**
```move
// Code:
public fun withdraw_to_internal(addr: address, amount: u64) {
    let store = borrow_global_mut<Store>(addr);
    assert!(store.balance >= amount, EINSUFFICIENT_BALANCE);  // ✅ Aborts if balance < amount
    store.balance = store.balance - amount;
}

// Spec:
spec withdraw_to_internal {
    // ❌ Missing: aborts_if balance < amount
    ensures balance_sum(...) == old(balance_sum(...)) - amount;
}
```

**Conclusion:** Spec incomplete, add `aborts_if`

### Step 4: Simplify Spec Until It Passes

**Binary search for problematic clause:**
```move
// Start: All clauses (fails)
spec withdraw_to_internal {
    ensures A;
    ensures B;
    ensures C;
}

// Try: Half clauses (comment out B, C)
spec withdraw_to_internal {
    ensures A;  // Does this pass?
    // ensures B;
    // ensures C;
}

// If A passes: Problem is in B or C
// If A fails: Problem is in A

// Repeat until isolated
```

### Step 5: Strengthen Preconditions

**If spec fails because input is unrealistic:**
```move
spec withdraw_to_internal {
    // Add precondition to rule out unrealistic inputs
    requires balance_sum(...) >= amount;
    
    ensures balance_sum(...) == old(balance_sum(...)) - amount;
}
```

**Trade-off:** Stronger `requires` = easier to verify, but harder for callers

**Alternative:** Use `aborts_if` instead (weaker, more flexible)

### Step 6: Add Pragmas

**If spec is correct but Z3 times out:**
```move
spec withdraw_to_internal {
    pragma timeout = 120;  // Increase timeout
    pragma seed = 42;      // Deterministic Z3 behavior
    pragma verify = true;  // Force verification (even if disabled globally)
    
    ensures ...;
}
```

**When to use:**
- `timeout`: Spec is complex but correct
- `seed`: Flaky verification (passes sometimes, fails others)
- `verify = false`: Skip verification (temporary, during development)

---

## Timeout Diagnosis

### Identifying the Bottleneck

**Enable verbose mode:**
```bash
movement move prove --package-dir aptos-experimental \
    --filter withdraw_to_internal \
    --verbose \
    --vc-timeout 60
```

**Output shows per-VC time:**
```
VC #1 (requires clause at line 20): 0.5s ✅
VC #2 (ensures clause at line 30): 45.2s ⚠️ (slow!)
VC #3 (aborts_if clause at line 40): 1.2s ✅
```

**Conclusion:** VC #2 (ensures clause at line 30) is the bottleneck

### Common Timeout Causes

**Cause 1: Nested Quantifiers**
```move
// BAD (O(N²)):
ensures forall i in 0..len(v):
    forall j in 0..len(v):
        i != j ==> v[i] != v[j];

// GOOD (O(N)):
ensures all_unique(v);  // Defined as spec function with single loop
```

**Cause 2: Non-Linear Arithmetic**
```move
// BAD (multiplication is non-linear):
ensures balance * price == total;

// GOOD (avoid multiplication if possible):
requires price > 0;
ensures balance == total / price;  // Still non-linear, but simpler for Z3
```

**Cause 3: Large Spec Function**
```move
spec fun complex_computation(x: u64): u64 {
    if (x == 0) { 0 }
    else if (x == 1) { 1 }
    else if (x == 2) { 2 }
    // ... 100 more branches ...
}

// Every call to complex_computation expands to 100 branches → timeout
```

**Fix:** Mark `pragma opaque`:
```move
spec fun complex_computation(x: u64): u64 {
    pragma opaque;  // Treat as uninterpreted function (faster)
    // ... branches ...
}
```

### Incremental Timeout Increase

**Start conservative:**
```move
pragma timeout = 60;  // Try 1 minute first
```

**If still times out:**
```move
pragma timeout = 120;  // Try 2 minutes
```

**If still times out at 120s:** Spec is too complex, simplify (don't keep increasing forever)

**Rule of thumb:** If >3 minutes needed, spec is probably too complex (Z3 won't scale)

---

## False Failure Fixes

### Fix 1: Add Missing Aborts-If

**Scenario:** Counterexample shows impossible input

**Example:**
```move
// Code:
assert!(amount > 0, EINVALID_AMOUNT);

// Spec (missing abort):
spec withdraw_to_internal {
    ensures ...;
}

// Counterexample:
//   amount = 0  (impossible, rejected by assert!)
```

**Fix:**
```move
spec withdraw_to_internal {
    aborts_if amount == 0 with EINVALID_AMOUNT;
    ensures ...;
}
```

### Fix 2: Add Missing Requires

**Scenario:** Spec assumes something not guaranteed by caller

**Example:**
```move
spec withdraw_to_internal {
    ensures balance >= 0;  // Always true for u64, but Z3 doesn't know
}

// Counterexample:
//   balance = <underflow>  (Z3 models u64 as unbounded int)
```

**Fix:**
```move
spec withdraw_to_internal {
    requires balance >= 0;  // Explicit precondition
    ensures balance >= 0;
}
```

**OR:** Use u64 range axiom:
```move
spec module {
    axiom forall x: u64: x >= 0 && x <= MAX_U64;
}
```

### Fix 3: Strengthen Loop Invariant

**Scenario:** Spec on function with while-loop

**Example:**
```move
// Code:
while (i < len(v)) {
    v[i] = v[i] + 1;
    i = i + 1;
}

// Spec:
spec function_with_loop {
    ensures forall i in 0..len(v): v[i] == old(v[i]) + 1;
}

// Fails: Z3 can't prove loop maintains invariant
```

**Fix:** Add explicit loop invariant:
```move
spec function_with_loop {
    ensures forall i in 0..len(v): v[i] == old(v[i]) + 1;
}

// In code:
while (i < len(v))
    invariant i <= len(v)
    invariant forall j in 0..i: v[j] == old(v[j]) + 1
{
    v[i] = v[i] + 1;
    i = i + 1;
}
```

### Fix 4: Use Spec Function for Complex Property

**Scenario:** Inline property too complex

**Example:**
```move
// BAD (complex inline):
ensures len(global<Store>(addr).pending_balance.chunks) == 
        len(old(global<Store>(addr).pending_balance.chunks)) &&
        len(global<Store>(addr).actual_balance.chunks) == 
        len(old(global<Store>(addr).actual_balance.chunks));
```

**Fix (spec function):**
```move
spec fun chunks_preserved(addr: address): bool {
    len(global<Store>(addr).pending_balance.chunks) == 
        len(old(global<Store>(addr).pending_balance.chunks)) &&
    len(global<Store>(addr).actual_balance.chunks) == 
        len(old(global<Store>(addr).actual_balance.chunks))
}

ensures chunks_preserved(addr);  // Simpler, easier for Z3
```

---

## Performance Optimization

### Optimization 1: Factor Out Common Expressions

**Before (repeated evaluation):**
```move
spec withdraw_to_internal {
    ensures balance_sum(global<Store>(addr).balance) == 
            old(balance_sum(global<Store>(addr).balance)) - amount;
    ensures frozen(global<Store>(addr)) == old(frozen(global<Store>(addr)));
}
```

**After (let-binding):**
```move
spec withdraw_to_internal {
    let store = global<Store>(addr);
    let old_balance = old(balance_sum(store.balance));
    let new_balance = balance_sum(store.balance);
    
    ensures new_balance == old_balance - amount;
    ensures frozen(store) == old(frozen(store));
}
```

**Speedup:** 2-3× faster (Z3 evaluates `balance_sum` once, not 4 times)

### Optimization 2: Use Pragma Opaque for Expensive Spec Functions

**Before (inlined):**
```move
spec fun recursive_sum(v: vector<u64>): u64 {
    if (len(v) == 0) { 0 }
    else { v[0] + recursive_sum(slice(v, 1, len(v))) }
}

spec function_using_sum {
    ensures recursive_sum(balance) == ...;  // Inlines full recursion
}
```

**After (opaque):**
```move
spec fun recursive_sum(v: vector<u64>): u64 {
    pragma opaque;  // Treat as uninterpreted function
    if (len(v) == 0) { 0 }
    else { v[0] + recursive_sum(slice(v, 1, len(v))) }
}

spec function_using_sum {
    ensures recursive_sum(balance) == ...;  // Opaque, faster
}
```

**Speedup:** 10-100× for complex spec functions

**Trade-off:** Z3 knows less about `recursive_sum` (can't inline), may fail to prove some properties

### Optimization 3: Avoid Quantifier Alternation

**Before (alternating ∀∃):**
```move
ensures forall i: exists j: v[j] > v[i];  // Very expensive
```

**After (skolemization):**
```move
spec fun has_greater(v: vector<u64>, i: u64): bool {
    exists j: v[j] > v[i]
}

ensures forall i: has_greater(v, i);  // Still expensive, but better
```

**Best:** Avoid if possible (reformulate property)

### Optimization 4: Parallelize Verification

**Scenario:** Verifying 10 functions, each takes 2 minutes = 20 minutes total

**Sequential:**
```bash
movement move prove --package-dir aptos-experimental  # 20 min
```

**Parallel (per-function):**
```bash
# Terminal 1:
movement move prove --filter function1  # 2 min

# Terminal 2:
movement move prove --filter function2  # 2 min

# ... 10 terminals ...

# Wall-clock time: 2 min (if 10 cores available)
```

**Speedup:** 10× wall-clock time (linear in cores)

---

## Related Guides

- [MSL_SPECIFICATION_PATTERNS_GUIDE.md](MSL_SPECIFICATION_PATTERNS_GUIDE.md) — Spec patterns
- [MSL_TO_LEAN_COORDINATION_GUIDE.md](MSL_TO_LEAN_COORDINATION_GUIDE.md) — MSL-Lean sync
- [CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md](CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md) §5 — MSL phases

---

**Document Status:** v1.0 (2026-04-22)  
**Maintainer:** Verification team  
**Last Updated:** 2026-04-22  
**Next Review:** 2026-07-22 (quarterly)

**Key Takeaway:** MSL debugging is systematic: (1) isolate failing VC, (2) examine counterexample, (3) check if realistic, (4) add missing preconditions/aborts, (5) simplify if timeout. Most failures are incomplete specs (missing `aborts_if`), not code bugs. Use `pragma timeout` and `pragma opaque` sparingly (last resort). Profile per-VC time to find bottlenecks.
