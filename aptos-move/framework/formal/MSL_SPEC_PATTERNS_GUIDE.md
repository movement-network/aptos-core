# MSL Spec Patterns Guide: Move Specification Language Best Practices

**Date:** 2026-04-23  
**Purpose:** Document proven MSL patterns from 88+ spec blocks across CA verification  
**Audience:** Move developers writing formal specifications

---

## Overview

This guide catalogs successful Move Specification Language (MSL) patterns from the CA formal verification work. These patterns are extracted from 6 spec files covering 40+ functions with comprehensive abort conditions, ensures clauses, and frame conditions.

**Key insight:** Good MSL specs are precise, complete, and composable. These patterns show how.

---

## Pattern Categories

1. **Module-Level Invariants** - Global properties that hold across all functions
2. **Abort Conditions** - Precise characterization of when functions fail
3. **Ensures Clauses** - Post-conditions and state mutations
4. **Frame Conditions** - What does and doesn't change
5. **Opaque Boundaries** - Where to stop specification
6. **Composition** - How specs interact with upstream/downstream

---

## Pattern 1: Module-Level Invariants for Data Structure Consistency

**When:** You have data structures with internal consistency requirements

**Problem:** Per-function specs can't capture cross-function invariants

**Solution:** Use module-level `invariant` clauses

### Example

```move
spec aptos_experimental::confidential_asset {
    spec module {
        pragma verify = true;
        pragma aborts_if_is_strict;

        // Invariant 1: Pending counter never exceeds rollover threshold
        invariant forall addr: address, token: Object<Metadata>:
            exists<ConfidentialAssetStore>(spec_get_user_address(addr, token)) ==>
                global<ConfidentialAssetStore>(spec_get_user_address(addr, token)).pending_counter
                    <= MAX_TRANSFERS_BEFORE_ROLLOVER;

        // Invariant 2: Balance chunk counts are always correct
        invariant forall addr: address, token: Object<Metadata>:
            exists<ConfidentialAssetStore>(spec_get_user_address(addr, token)) ==>
                (len(global<ConfidentialAssetStore>(spec_get_user_address(addr, token)).pending_balance.chunks)
                    == confidential_balance::PENDING_BALANCE_CHUNKS &&
                 len(global<ConfidentialAssetStore>(spec_get_user_address(addr, token)).actual_balance.chunks)
                    == confidential_balance::ACTUAL_BALANCE_CHUNKS);

        // Invariant 3: Normalized flag semantics
        invariant forall addr: address, token: Object<Metadata>:
            exists<ConfidentialAssetStore>(spec_get_user_address(addr, token)) ==>
                (!global<ConfidentialAssetStore>(spec_get_user_address(addr, token)).normalized ==>
                 global<ConfidentialAssetStore>(spec_get_user_address(addr, token)).pending_counter > 0);
    }
}
```

**Why it works:**
- Checked at entry and exit of every function
- Enforces consistency across the entire module
- Catches violations early (at function boundaries)

**Used in:**
- `confidential_asset.spec.move` (3 module invariants)

**Benefits:**
- Ensures data structure integrity
- Catches bugs that single-function specs miss
- Documents global assumptions

**Caveat:** Module invariants add overhead - keep them focused and essential

---

## Pattern 2: Precise Abort Conditions with Error Codes

**When:** Functions can abort for specific reasons

**Problem:** Generic "aborts" is too weak, doesn't capture why

**Solution:** Use `aborts_if` with error code constants

### Example

```move
spec freeze_token_internal {
    let user = signer::address_of(sender);
    let store_addr = spec_get_user_address(user, token);

    // Abort 1: Store doesn't exist
    aborts_if !exists<ConfidentialAssetStore>(store_addr);

    // Abort 2: Already frozen (with error code)
    aborts_if global<ConfidentialAssetStore>(store_addr).frozen
        with EALREADY_FROZEN;

    // Success post-condition
    ensures global<ConfidentialAssetStore>(store_addr).frozen;
}
```

**Move source:**
```move
public fun freeze_token_internal(sender: &signer, token: Object<Metadata>) {
    let store = borrow_global_mut<ConfidentialAssetStore>(get_user_address(sender, token));
    assert!(!store.frozen, error::invalid_state(EALREADY_FROZEN));
    store.frozen = true;
}
```

**Spec mirrors source:**
- `borrow_global_mut` → `aborts_if !exists<...>`
- `assert!(!store.frozen, ...)` → `aborts_if store.frozen with ERROR_CODE`
- `store.frozen = true` → `ensures store.frozen`

**Pattern:** One `aborts_if` per `assert!` in source

**Used in:**
- All internal functions in `confidential_asset.spec.move`
- All view functions

**Benefits:**
- Precise error characterization
- Easier debugging (know exactly which assert fired)
- Complete abort coverage

---

## Pattern 3: Frame Conditions via Ensures Clauses

**When:** Functions modify some fields but not others

**Problem:** Without frame conditions, we don't know what's preserved

**Solution:** Explicit `ensures old(field) == field` for unchanged fields

### Example

```move
spec freeze_token_internal {
    let store_addr = spec_get_user_address(user, token);

    // What changes
    ensures global<ConfidentialAssetStore>(store_addr).frozen;

    // What doesn't change (frame conditions)
    ensures global<ConfidentialAssetStore>(store_addr).normalized
        == old(global<ConfidentialAssetStore>(store_addr)).normalized;
    ensures global<ConfidentialAssetStore>(store_addr).pending_counter
        == old(global<ConfidentialAssetStore>(store_addr)).pending_counter;
    ensures global<ConfidentialAssetStore>(store_addr).pending_balance
        == old(global<ConfidentialAssetStore>(store_addr)).pending_balance;
    ensures global<ConfidentialAssetStore>(store_addr).actual_balance
        == old(global<ConfidentialAssetStore>(store_addr)).actual_balance;
    ensures global<ConfidentialAssetStore>(store_addr).ek
        == old(global<ConfidentialAssetStore>(store_addr)).ek;
}
```

**Why it works:**
- Makes frame explicit (not implicit)
- Catches unintended mutations
- Documents what's stable across call

**Pattern:**
1. List all fields of modified resource
2. For each field: `ensures` if modified, `ensures old(...) == ...` if preserved

**Used in:**
- All store-mutating functions
- All internal functions

**Benefits:**
- Complete frame specification
- Prevents accidental field modification
- Clear contract for callers

---

## Pattern 4: Modifies Clauses for Global Resources

**When:** Functions modify global state

**Problem:** Move Prover needs to know which resources can change

**Solution:** Comprehensive `modifies` clauses

### Example

```move
spec deposit_to_internal {
    let recipient_store = spec_get_user_address(to, token);

    // Function aborts/ensures clauses ...

    // Modifies: CA store
    modifies global<ConfidentialAssetStore>(recipient_store);

    // Modifies: FA framework resources (from primary_fungible_store::deposit)
    modifies global<object::ObjectCore>(@aptos_framework);
    modifies global<object::Untransferable>(@aptos_framework);
    modifies global<aptos_framework::permissioned_signer::PermissionStorage>(@aptos_framework);
    modifies global<aptos_framework::fungible_asset::FungibleStore>(@aptos_framework);
    modifies global<aptos_framework::fungible_asset::ConcurrentFungibleBalance>(@aptos_framework);
}
```

**How to determine modifies clauses:**
1. Read the function source
2. For each `borrow_global_mut` / `move_to` / `move_from`: add that resource
3. For each function call: add its modifies clauses (transitively)

**Pattern for FA-integrated functions:**
- CA store: `modifies global<ConfidentialAssetStore>(...)`
- Object framework: `modifies global<object::ObjectCore>(...)`
- FA framework: `modifies global<fungible_asset::FungibleStore>(...)`
- ... (see example above for full list)

**Used in:**
- All FA-integrated operations (deposit, withdraw, transfer)
- All functions calling FA primitives

**Benefits:**
- Move Prover can verify frame conditions
- Catches missing dependencies
- Documents side-effect footprint

**Added in Phase 2/3/5:** Comprehensive modifies clauses reduced compilation errors from 79+ to 33

---

## Pattern 5: Pragma Opaque for Crypto/Framework Boundaries

**When:** Function delegates to crypto primitives or framework functions

**Problem:** Can't (or don't want to) verify the internals

**Solution:** Mark as `pragma opaque` with high-level contract

### Example

```move
/// Crypto boundary: proof verification
spec verify_withdrawal_proof {
    pragma opaque;
    aborts_if false;  // Never aborts (returns boolean)

    // High-level contract: result = true iff proof is valid
    // Detailed semantics in Lean (SigmaVerifiers.lean)
    // MSL treats this as uninterpreted predicate
}

/// Framework boundary: FA transfer
spec ensure_sufficient_fa {
    pragma opaque;
    pragma aborts_if_is_strict = false;

    // Touches complex FA framework internals
    // Defer to upstream FA specs
    modifies global<object::ObjectCore>(@aptos_framework);
    modifies global<fungible_asset::FungibleStore>(@aptos_framework);
    // ... (other FA resources)
}
```

**When to use opaque:**
1. **Crypto primitives:** ristretto255 operations, Bulletproofs, proof verification
2. **Framework functions:** FA transfer, object creation, coin conversion
3. **Complex helpers:** Where full spec would be longer than helpful

**Pattern:**
- `pragma opaque` to stop inlining
- `aborts_if` for error conditions (even if can't verify them)
- `modifies` for side-effect footprint
- Comment documenting where detailed semantics live

**Used in:**
- `confidential_proof.spec.move` (all crypto operations)
- `ristretto255_twisted_elgamal.spec.move` (all operations)
- FA-integrated helpers

**Benefits:**
- Clear trust boundary
- Composition without full verification
- Documents what's assumed vs proved

---

## Pattern 6: Spec Functions for Pure Computations

**When:** Spec needs to compute a derived value

**Problem:** Can't call Move functions from spec context

**Solution:** Define `spec fun` parallel to Move function

### Example

```move
// Move source
public fun get_user_address(user: address, token: Object<Metadata>): address {
    object::create_object_address(&@aptos_experimental, compute_seed(user, token))
}

// Spec function (computable in spec context)
spec fun spec_get_user_address(user: address, token: Object<Metadata>): address {
    object::spec_create_object_address(@aptos_experimental, spec_compute_seed(user, token))
}

// Usage in specs
spec register_internal {
    let store_addr = spec_get_user_address(signer::address_of(sender), token);
    ensures exists<ConfidentialAssetStore>(store_addr);
}
```

**Pattern:**
1. Define `spec fun` with same signature
2. Name it `spec_<original_name>`
3. Implement using spec-context-available operations
4. Use in all specs that need the value

**Alternative (for simple functions):**
```move
// Mark Move function as pure
public fun get_user_address(user: address, token: Object<Metadata>): address {
    object::create_object_address(&@aptos_experimental, compute_seed(user, token))
}

spec get_user_address {
    pragma opaque;
    ensures result == spec_get_user_address(user, token);
}
```

**Used in:**
- `spec_get_user_address` (used in 40+ specs)
- `spec_get_fa_config_address` (governance functions)
- `spec_compute_seed` (underlying helper)

**Benefits:**
- Specs can reference computed values
- Avoid duplication (single definition)
- Type-checked consistency

---

## Pattern 7: Incremental Spec Strengthening

**When:** Writing specs for the first time

**Problem:** Hard to get complete spec on first try

**Solution:** Incremental approach with pragmas

### Progression

**Stage 1: Compilation (structural scaffold)**
```move
spec my_function {
    pragma aborts_if_is_strict = false;  // Don't require complete aborts
    pragma opaque;  // Don't verify internals yet

    // Minimal: just document modifies
    modifies global<MyResource>(@my_address);
}
```

**Stage 2: Abort conditions**
```move
spec my_function {
    pragma aborts_if_is_strict = false;  // Still partial
    pragma opaque;

    // Add known abort conditions
    aborts_if !exists<MyResource>(@my_address);
    aborts_if some_condition with ERROR_CODE;

    modifies global<MyResource>(@my_address);
}
```

**Stage 3: Post-conditions**
```move
spec my_function {
    pragma aborts_if_is_strict = false;
    pragma opaque;  // Keep opaque while debugging

    aborts_if !exists<MyResource>(@my_address);
    aborts_if some_condition with ERROR_CODE;

    // Add observable post-conditions
    ensures global<MyResource>(@my_address).field == new_value;

    modifies global<MyResource>(@my_address);
}
```

**Stage 4: Complete and verified**
```move
spec my_function {
    // Remove pragmas - full verification
    pragma verify = true;

    // Complete abort conditions
    aborts_if !exists<MyResource>(@my_address);
    aborts_if some_condition with ERROR_CODE;

    // Complete post-conditions
    ensures global<MyResource>(@my_address).field1 == new_value;
    ensures global<MyResource>(@my_address).field2 == old(...);

    // Frame conditions
    ensures global<MyResource>(@my_address).unchanged_field
        == old(global<MyResource>(@my_address)).unchanged_field;

    modifies global<MyResource>(@my_address);
}
```

**Current status (2026-04-23):**
- Most CA specs at Stage 3 (structural complete, opaque for ristretto255 blocker)
- Ready for Stage 4 once ristretto255 patches applied

**Pattern:** Always compile before verify, always partial before complete

---

## Pattern 8: Balance Length Preservation

**When:** Functions operate on homomorphic encrypted balances

**Problem:** Chunk counts must stay constant across operations

**Solution:** Explicit length ensures clauses

### Example

```move
spec deposit_to_internal {
    let recipient_store = spec_get_user_address(to, token);

    // Other conditions ...

    // Balance length preservation (homomorphic operations preserve chunk counts)
    ensures len(global<ConfidentialAssetStore>(recipient_store).pending_balance.chunks)
        == len(old(global<ConfidentialAssetStore>(recipient_store)).pending_balance.chunks);
    ensures len(global<ConfidentialAssetStore>(recipient_store).actual_balance.chunks)
        == len(old(global<ConfidentialAssetStore>(recipient_store)).actual_balance.chunks);

    modifies global<ConfidentialAssetStore>(recipient_store);
}
```

**Why needed:**
- Homomorphic operations (add, sub) preserve structure
- Chunk count = 4 for pending, 8 for actual (constants)
- Violations indicate crypto bugs

**Used in:**
- All functions that touch balances (deposit, withdraw, transfer, normalize, rotate)
- 12 ensures clauses added in Phase 2 strengthening

**Pattern:** For every balance field, ensure `len(...) == len(old(...))`

**Benefits:**
- Catches structural invariant violations
- Documents chunk-count stability
- Verifies crypto operations preserve format

---

## Pattern 9: Event Emission Placeholders

**When:** Functions emit events

**Problem:** MSL doesn't have full `emits` clause support yet

**Solution:** Placeholder comments for future

### Example

```move
spec register {
    let user = signer::address_of(sender);
    let store_addr = spec_get_user_address(user, token);

    // Current: structural spec
    aborts_if exists<ConfidentialAssetStore>(store_addr);
    ensures exists<ConfidentialAssetStore>(store_addr);

    // Future: event emission spec (awaiting MSL emits clause support)
    // emits Registered {
    //     user: user,
    //     token: object::object_address(&token),
    //     ek: ek
    // }

    modifies global<ConfidentialAssetStore>(store_addr);
}
```

**Pattern:**
1. Comment documenting which event is emitted
2. Comment listing event fields
3. Note waiting for MSL framework support

**Used in:**
- `register`, `withdraw_to`, `confidential_transfer`, `rotate_encryption_key`

**Benefits:**
- Documents intent for future work
- Placeholder won't break when `emits` support lands
- Clear TODO for Phase 5 completion

---

## Pattern 10: Spec-Only Helpers for Complex Conditions

**When:** Abort condition or ensures clause is complex

**Problem:** Repeating complex expression in multiple specs

**Solution:** Extract to spec function

### Example

```move
// Complex condition: is token allowed?
spec fun spec_is_token_allowed(token: Object<Metadata>): bool {
    !global<FAController>(@aptos_experimental).allow_list_enabled ||
    (exists<FAConfig>(spec_get_fa_config_address(token)) &&
     global<FAConfig>(spec_get_fa_config_address(token)).allowed)
}

// Usage in multiple specs
spec register_internal {
    aborts_if !spec_is_token_allowed(token) with ETOKEN_DISABLED;
    ...
}

spec deposit_to {
    aborts_if !spec_is_token_allowed(token) with ETOKEN_DISABLED;
    ...
}
```

**Benefits:**
- DRY (Don't Repeat Yourself)
- Single definition ensures consistency
- Named condition is self-documenting

**Used in:**
- Token allow-list checks
- FA config address computation
- Seed computation

**Pattern:** If expression appears 3+ times, extract to spec function

---

## Common Spec Structures

### Structure 1: View Function Spec

```move
spec view_function {
    let store_addr = spec_get_user_address(owner, token);

    // Abort: resource must exist
    aborts_if !exists<MyResource>(store_addr);

    // Ensures: result equals field
    ensures result == global<MyResource>(store_addr).field;

    // No modifies (pure read)
}
```

**Characteristics:**
- Single `aborts_if` (resource existence)
- Single `ensures` (result = field)
- No `modifies` clauses

---

### Structure 2: Mutating Function Spec

```move
spec mutating_function {
    let store_addr = spec_get_user_address(user, token);

    // Aborts: multiple conditions
    aborts_if !exists<MyResource>(store_addr);
    aborts_if precondition_violated with ERROR_CODE;

    // Ensures: what changes
    ensures global<MyResource>(store_addr).field1 == new_value;
    ensures global<MyResource>(store_addr).counter
        == old(global<MyResource>(store_addr)).counter + 1;

    // Frame: what doesn't change
    ensures global<MyResource>(store_addr).field2
        == old(global<MyResource>(store_addr)).field2;

    // Modifies
    modifies global<MyResource>(store_addr);
}
```

**Characteristics:**
- Multiple `aborts_if` clauses
- Mix of changed and preserved fields
- `modifies` clause present

---

### Structure 3: FA-Integrated Function Spec

```move
spec fa_integrated_function {
    pragma opaque;  // Complex FA interactions
    pragma aborts_if_is_strict = false;

    let store_addr = spec_get_user_address(user, token);

    // CA-level conditions
    aborts_if !exists<ConfidentialAssetStore>(store_addr);
    aborts_if global<ConfidentialAssetStore>(store_addr).frozen;

    // CA-level post-conditions
    ensures global<ConfidentialAssetStore>(store_addr).field == value;

    // Modifies: CA + FA framework
    modifies global<ConfidentialAssetStore>(store_addr);
    modifies global<fungible_asset::FungibleStore>(@aptos_framework);
    modifies global<object::ObjectCore>(@aptos_framework);
    // ... (other FA resources)
}
```

**Characteristics:**
- `pragma opaque` for FA composition
- Both CA and FA modifies clauses
- CA-level conditions explicit, FA-level deferred

---

## MSL Anti-Patterns

### Anti-Pattern 1: Incomplete Abort Conditions

```move
// BAD: Missing abort conditions
spec my_function {
    // Only lists one of three asserts in source
    aborts_if !exists<Resource>(@addr);
    
    ensures result > 0;
}

// GOOD: Complete abort characterization
spec my_function {
    aborts_if !exists<Resource>(@addr);
    aborts_if global<Resource>(@addr).value == 0 with EZERO_VALUE;
    aborts_if other_condition with OTHER_ERROR;
    
    ensures result > 0;
}
```

**Rule:** One `aborts_if` per `assert!` in source

---

### Anti-Pattern 2: Missing Frame Conditions

```move
// BAD: Only specifies what changes
spec update_field {
    ensures global<Resource>(@addr).field1 == new_value;
    // What about field2, field3, ...? Underspecified!
}

// GOOD: Explicit frame
spec update_field {
    ensures global<Resource>(@addr).field1 == new_value;
    ensures global<Resource>(@addr).field2 == old(...).field2;
    ensures global<Resource>(@addr).field3 == old(...).field3;
}
```

**Rule:** Specify all fields (changed + preserved)

---

### Anti-Pattern 3: Over-Specific Specs

```move
// BAD: Implementation detail leaked into spec
spec my_function {
    ensures result == field1 + field2 * 2 - 3;
    // Exposes exact computation (brittle)
}

// GOOD: Abstract contract
spec my_function {
    ensures result > 0;
    ensures result <= MAX_VALUE;
    // Specifies contract, not implementation
}
```

**Rule:** Specs should be abstract contracts, not reimplementation

---

## Spec Quality Checklist

For each function spec:

- [ ] Complete abort conditions (one per `assert!`)
- [ ] All error codes documented
- [ ] Post-conditions for all observable changes
- [ ] Frame conditions for all preserved fields
- [ ] Modifies clauses for all touched resources
- [ ] Opaque marked where appropriate
- [ ] Comments for deferred work (event emission, etc.)
- [ ] Spec functions extracted for repeated expressions
- [ ] No leaked implementation details

---

## Integration with Lean Proofs

MSL specs and Lean proofs are complementary:

| Concern | MSL | Lean |
|---------|-----|------|
| **Store invariants** | ✅ Module invariants | ❌ |
| **Abort conditions** | ✅ aborts_if clauses | ⚠️ Implicit in .error |
| **FA composition** | ✅ Upstream specs | ❌ |
| **Crypto correctness** | ❌ opaque | ✅ Sigma predicates |
| **Bytecode execution** | ❌ | ✅ eval ≡ functional sim |

**Pattern:** MSL covers store/FA, Lean covers crypto/bytecode, difftest binds to VM

---

## References

**Spec files:**
- `confidential_asset.spec.move` - Main specs (40+ functions)
- `confidential_balance.spec.move` - Balance operations
- `confidential_proof.spec.move` - Proof verification (opaque)
- `ristretto255_twisted_elgamal.spec.move` - Crypto boundary (opaque)

**Related guides:**
- `PROOF_PATTERNS_GUIDE.md` - Lean proof techniques
- `MOVE_PROVER_INTEGRATION_STATUS.md` - Current blocker state
- `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` - Phases 2/3/5

---

## Conclusion

Good MSL specs are:
- **Precise:** Complete abort conditions with error codes
- **Complete:** All fields specified (changed + preserved)
- **Composable:** Clear modifies clauses, opaque boundaries
- **Incremental:** Pragma scaffolding while developing

Follow these patterns for maintainable, verifiable specifications. 📋
