# MSL Spec Patterns Library

**Last updated:** 2026-04-22

Reusable MSL (Move Specification Language) spec patterns for CA formal verification. Covers common specification structures, pragma usage, and best practices for Move Prover.

## Table of Contents

1. [Basic Function Specs](#basic-function-specs)
2. [Preconditions](#preconditions)
3. [Postconditions](#postconditions)
4. [Abort Conditions](#abort-conditions)
5. [Frame Conditions](#frame-conditions)
6. [Crypto Boundaries](#crypto-boundaries)
7. [Entry Point Patterns](#entry-point-patterns)
8. [Resource Invariants](#resource-invariants)
9. [Helper Spec Functions](#helper-spec-functions)
10. [Common Pragmas](#common-pragmas)

---

## Basic Function Specs

### Pattern: Internal Function (No Global State)

**When to use:** Functions that take store as argument (not global resource).

**Template:**

```move
spec <function_name> {
    // Preconditions (what must be true on entry)
    requires <preconditions>;
    
    // Postconditions (what's guaranteed on success)
    ensures <postconditions>;
    
    // Abort conditions (when function aborts)
    aborts_if <condition_1> with <error_code_1>;
    aborts_if <condition_2> with <error_code_2>;
}
```

**Example (from confidential_balance.spec.move):**

```move
spec add_balances_mut {
    requires len(balance1.chunks) == PENDING_BALANCE_CHUNKS;
    requires len(balance2.chunks) == ACTUAL_BALANCE_CHUNKS;
    
    ensures len(balance1.chunks) == PENDING_BALANCE_CHUNKS;
    ensures len(balance2.chunks) == ACTUAL_BALANCE_CHUNKS;
    
    // Never aborts (crypto operations are infallible at type level)
}
```

**Key principles:**
- Start with `requires` (what caller must ensure)
- Then `ensures` (what function guarantees)
- Then `aborts_if` (when it fails)
- Order matters: readers scan top-to-bottom

### Pattern: Entry Point (Global State)

**When to use:** `public entry` functions that access global resources.

**Template:**

```move
spec <entry_function> {
    // Global state preconditions
    requires exists<FAConfig>(RESOURCE_ACCOUNT_ADDRESS);
    
    // Postconditions
    ensures exists<ConfidentialAssetStore>(signer::address_of(owner));
    ensures global<ConfidentialAssetStore>(signer::address_of(owner)).encryption_key == encryption_key;
    
    // Abort conditions
    aborts_if !exists<FAConfig>(RESOURCE_ACCOUNT_ADDRESS) with ESOMEERROR;
    aborts_if exists<ConfidentialAssetStore>(signer::address_of(owner)) with ESTORE_ALREADY_EXISTS;
    
    // Frame (what resources are modified)
    modifies global<ConfidentialAssetStore>(signer::address_of(owner));
}
```

**Key principles:**
- Use `global<T>(addr)` to access global state
- Use `exists<T>(addr)` to check resource existence
- `modifies` declares side effects (required for purity checking)

---

## Preconditions

### Pattern: Length Invariants

**When to use:** Functions that operate on fixed-size vectors.

**Example:**

```move
spec normalize_internal {
    requires len(store.pending_balance.chunks) == PENDING_BALANCE_CHUNKS;
    requires len(store.actual_balance.chunks) == ACTUAL_BALANCE_CHUNKS;
    
    // Function body operates on these lengths
}
```

**Key techniques:**
- Use `len(vec)` not `vector::length(vec)` in specs
- Define constants: `const PENDING_BALANCE_CHUNKS: u64 = 4;`
- Check on entry, assert preservation on exit

### Pattern: Resource Existence

**When to use:** Functions that assume global resources exist.

**Example:**

```move
spec register {
    requires exists<FAConfig>(RESOURCE_ACCOUNT_ADDRESS);
    requires !exists<ConfidentialAssetStore>(signer::address_of(owner));
    
    // If these don't hold, function aborts
}
```

**Key techniques:**
- `exists<T>(addr)`: resource T exists at addr
- `!exists<T>(addr)`: resource doesn't exist
- Combine with `aborts_if` for complete abort specification

### Pattern: Value Bounds

**When to use:** Functions with numeric constraints.

**Example:**

```move
spec withdraw_to_internal {
    requires amount > 0;
    requires amount <= MAX_U128;
    
    // Prevents overflow, ensures meaningful operation
}
```

**Key techniques:**
- Use MSL `num` type for unbounded integers in specs
- Cast back to bounded types: `(amount as u64)`
- Document overflow behavior explicitly

---

## Postconditions

### Pattern: State Updates

**When to use:** Functions that modify store fields.

**Example:**

```move
spec register_internal {
    ensures store.encryption_key == encryption_key;
    ensures store.pending_balance == new_pending_balance_no_randomness(0);
    ensures store.actual_balance == new_actual_balance_no_randomness(0);
    ensures len(store.pending_balance.chunks) == PENDING_BALANCE_CHUNKS;
}
```

**Key techniques:**
- Use `==` for equality (not `=` assignment)
- Reference input parameters by name
- Spec pure functions for complex values: `new_pending_balance_no_randomness(0)`

### Pattern: Length Preservation

**When to use:** Functions that must preserve vector lengths.

**Example:**

```move
spec deposit_to_internal {
    requires len(store.pending_balance.chunks) == PENDING_BALANCE_CHUNKS;
    ensures len(store.pending_balance.chunks) == PENDING_BALANCE_CHUNKS;
    
    // Length is invariant
}
```

**Key techniques:**
- Pair `requires` with matching `ensures`
- Move Prover checks length preserved through updates
- Catches accidental resize bugs

### Pattern: Balance Homomorphism

**When to use:** Functions that must preserve encrypted balance sum.

**Example (future, after ristretto255 fix):**

```move
spec confidential_transfer_internal {
    // Homomorphic property: encrypted sum preserved
    ensures spec_decrypt(sender_store.actual_balance) ==
            spec_decrypt(old(sender_store.actual_balance)) - amount;
    ensures spec_decrypt(recipient_store.actual_balance) ==
            spec_decrypt(old(recipient_store.actual_balance)) + amount;
}
```

**Key techniques:**
- Use `spec fun` for crypto operations (see §9)
- Use `old(expr)` for pre-state values
- Currently blocked on ristretto255 patches (pragma opaque for now)

---

## Abort Conditions

### Pattern: Resource Not Found

**When to use:** Functions that require global resources.

**Example:**

```move
spec register {
    aborts_if !exists<FAConfig>(RESOURCE_ACCOUNT_ADDRESS) with ECONFIG_NOT_FOUND;
    aborts_if exists<ConfidentialAssetStore>(signer::address_of(owner)) with ESTORE_ALREADY_EXISTS;
}
```

**Key techniques:**
- Use `aborts_if !exists<T>(addr)` for missing resource
- Use `with <error_code>` to pin error code
- One `aborts_if` per error condition (not combined)

### Pattern: Proof Verification Failed

**When to use:** Functions that call `verify_*_proof`.

**Example:**

```move
spec withdraw_to_internal {
    pragma opaque;  // verify_withdrawal_proof is crypto boundary
    
    aborts_if !spec_verify_withdrawal_proof(...) with ESIGMA_PROTOCOL_VERIFY_FAILED;
    aborts_if !spec_verify_range_proof(...) with EBULLETPROOFS_VERIFY_FAILED;
}
```

**Key techniques:**
- `pragma opaque` on crypto verifiers (see §6)
- Declare `spec fun` for verify (abstraction, see §9)
- Pin error codes: `ESIGMA_PROTOCOL_VERIFY_FAILED = 65537`

### Pattern: Frozen Token

**When to use:** Operations blocked when token is frozen.

**Example:**

```move
spec withdraw_to_internal {
    aborts_if store.frozen with ETOKEN_FROZEN;
    aborts_if !is_allowed(store, signer::address_of(owner)) with ENOT_ALLOWED;
}
```

**Key techniques:**
- Boolean field: `store.frozen`
- Helper spec function: `is_allowed(store, addr)`
- Clear error codes for each condition

---

## Frame Conditions

### Pattern: Single Resource Modified

**When to use:** Function modifies one global resource.

**Example:**

```move
spec register {
    modifies global<ConfidentialAssetStore>(signer::address_of(owner));
    
    // No other global resources modified
}
```

**Key techniques:**
- `modifies global<T>(addr)` declares write
- Omitting `modifies` means function is pure
- Move Prover checks no other writes occur

### Pattern: Multiple Resources Modified

**When to use:** Function touches multiple global resources.

**Example:**

```move
spec confidential_transfer {
    modifies global<ConfidentialAssetStore>(sender_addr);
    modifies global<ConfidentialAssetStore>(recipient_addr);
    modifies global<FAStore>(fa_metadata_addr);  // FA framework side-effect
    
    // All writes declared
}
```

**Key techniques:**
- One `modifies` per resource type × address
- Include transitive writes (FA calls)
- Currently: FA writes are `pragma opaque` (upstream audit pending)

### Pattern: No Side Effects (Pure Function)

**When to use:** View functions, helpers.

**Example:**

```move
spec pending_balance {
    // No modifies clause → function is pure
    ensures result == global<ConfidentialAssetStore>(addr).pending_balance;
}
```

**Key techniques:**
- Omit `modifies` for pure functions
- Move Prover checks no global writes
- Return value via `result` keyword

---

## Crypto Boundaries

### Pattern: Native Crypto Function

**When to use:** Functions that call ristretto255 / SHA / Bulletproofs natives.

**Example:**

```move
spec module aptos_experimental::confidential_proof {
    pragma verify = true;  // Module is verified
    
    spec verify_withdrawal_proof {
        pragma opaque;  // Function body is black-box
        
        // Only pre/post, no internal reasoning
        aborts_if !spec_verify_sigma(...) with ESIGMA_PROTOCOL_VERIFY_FAILED;
    }
}
```

**Key techniques:**
- Module-level `pragma verify = true` (default, explicit for clarity)
- Function-level `pragma opaque` (crypto boundary)
- Define `spec fun spec_verify_sigma` (abstract model, see §9)
- Document in `TRUST_BOUNDARIES.md` §3

### Pattern: Ristretto255 Operations

**When to use:** Functions using point/scalar arithmetic.

**Example:**

```move
spec add_balances_mut {
    pragma opaque;  // Crypto operations inside
    
    // Abstract spec: result is sum
    ensures spec_decrypt(balance1) == spec_decrypt(old(balance1)) + spec_decrypt(balance2);
}
```

**Key techniques:**
- `pragma opaque` on functions calling ristretto255 natives
- Use abstract `spec fun` for decryption (unimplemented, axiomatized)
- Currently blocked on ristretto255 patches (0 VCs expected until fixed)

---

## Entry Point Patterns

### Pattern: Deposit (FA → CA)

**When to use:** Entry points that convert FA to confidential balance.

**Example:**

```move
spec deposit_to {
    // FA preconditions (upstream specs)
    requires exists<FAStore>(fa_metadata_addr);
    
    // CA preconditions
    requires exists<ConfidentialAssetStore>(recipient_addr);
    
    // Postconditions
    ensures spec_decrypt(global<ConfidentialAssetStore>(recipient_addr).pending_balance) ==
            spec_decrypt(old(global<ConfidentialAssetStore>(recipient_addr).pending_balance)) + amount;
    
    // FA side-effects (trust upstream specs)
    pragma opaque;  // FA transfer is upstream-verified
    modifies global<FAStore>(fa_metadata_addr);
    modifies global<ConfidentialAssetStore>(recipient_addr);
}
```

**Key techniques:**
- Compose with upstream FA specs
- FA operations are `pragma opaque` (trust framework)
- Document FA dependency in `TRUST_BOUNDARIES.md` §2

### Pattern: Withdrawal (CA → FA)

**When to use:** Entry points that convert confidential to FA.

**Example:**

```move
spec withdraw_to {
    // Proof verification
    pragma opaque;  // verify_withdrawal_proof is crypto
    
    // Balance updates
    ensures spec_decrypt(global<ConfidentialAssetStore>(owner_addr).actual_balance) ==
            spec_decrypt(old(global<ConfidentialAssetStore>(owner_addr).actual_balance)) - amount;
    
    // FA side-effects
    ensures global<FAStore>(fa_metadata_addr).balance ==
            old(global<FAStore>(fa_metadata_addr).balance) + amount;
    
    aborts_if !spec_verify_withdrawal_proof(...) with ESIGMA_PROTOCOL_VERIFY_FAILED;
    aborts_if store.frozen with ETOKEN_FROZEN;
}
```

**Key techniques:**
- Verify proof before withdrawal (abort if verify fails)
- CA balance decreases, FA balance increases
- Both must be provably balanced

---

## Resource Invariants

### Pattern: Store Invariant

**When to use:** Properties that must hold for every `ConfidentialAssetStore` instance.

**Example:**

```move
spec module aptos_experimental::confidential_asset {
    invariant forall addr: address where exists<ConfidentialAssetStore>(addr):
        len(global<ConfidentialAssetStore>(addr).pending_balance.chunks) == PENDING_BALANCE_CHUNKS &&
        len(global<ConfidentialAssetStore>(addr).actual_balance.chunks) == ACTUAL_BALANCE_CHUNKS;
}
```

**Key techniques:**
- Module-level `invariant` checked after every function
- `forall addr: address where exists<T>(addr)`: for all instances
- Conjunction `&&` for multiple properties
- Move Prover checks invariant preserved by all functions

### Pattern: Singleton Resource

**When to use:** Resources with exactly one instance.

**Example:**

```move
spec module aptos_experimental::confidential_asset {
    invariant exists<FAConfig>(RESOURCE_ACCOUNT_ADDRESS);
    invariant forall addr: address where exists<FAConfig>(addr):
        addr == RESOURCE_ACCOUNT_ADDRESS;
}
```

**Key techniques:**
- First invariant: singleton exists
- Second invariant: no other instances
- Prevents accidental duplication

---

## Helper Spec Functions

### Pattern: Abstract Crypto Operation

**When to use:** Crypto operations that MSL can't express.

**Example:**

```move
spec module aptos_experimental::confidential_balance {
    spec fun spec_decrypt(balance: ConfidentialBalance): num;
    
    // Homomorphic property (axiomatized)
    axiom forall b1: ConfidentialBalance, b2: ConfidentialBalance:
        spec_decrypt(spec_add(b1, b2)) == spec_decrypt(b1) + spec_decrypt(b2);
}
```

**Key techniques:**
- `spec fun` without body (uninterpreted function)
- `axiom` for crypto properties (external audit)
- Document in `AXIOM_INVENTORY.md` + `TRUST_BOUNDARIES.md`

### Pattern: Verification Abstraction

**When to use:** Abstracting verify_*_proof for specs.

**Example:**

```move
spec module aptos_experimental::confidential_proof {
    spec fun spec_verify_withdrawal_proof(
        balance: vector<u8>,
        proof: vector<u8>,
        pubkey: vector<u8>
    ): bool;
    
    // Axiom: soundness (if verify passes, proof is valid)
    axiom forall balance, proof, pubkey:
        spec_verify_withdrawal_proof(balance, proof, pubkey) ==>
        spec_proof_is_valid(balance, proof, pubkey);
}
```

**Key techniques:**
- `spec fun` signature matches Move function
- Return type `bool` for verify result
- Axioms capture soundness/completeness
- Lean proves bytecode matches this abstraction (Phase 4)

### Pattern: Helper Predicate

**When to use:** Complex conditions used in multiple specs.

**Example:**

```move
spec module aptos_experimental::confidential_asset {
    spec fun is_allowed(store: ConfidentialAssetStore, addr: address): bool {
        !store.allow_list_enabled || vector::contains(&store.allowed_addresses, &addr)
    }
    
    spec fun is_operational(store: ConfidentialAssetStore): bool {
        !store.frozen && store.enabled
    }
}
```

**Key techniques:**
- `spec fun` with body (inline expansion)
- Boolean predicates for readability
- Reuse across multiple function specs

---

## Common Pragmas

### Pragma: `pragma opaque`

**When to use:** Crypto boundaries, upstream framework calls.

**Effect:** Move Prover treats function as black-box (only pre/post, no body).

**Example:**

```move
spec verify_withdrawal_proof {
    pragma opaque;
    // Only spec clauses matter, body ignored
}
```

**Document in:** `TRUST_BOUNDARIES.md` §3 "Native-function assumptions"

### Pragma: `pragma verify = false`

**When to use:** **NEVER in production code.** Only test-only modules.

**Effect:** Skip verification entirely.

**Example (acceptable):**

```move
spec module aptos_experimental::confidential_gas_e2e_helpers {
    pragma verify = false;  // Test-only module
}
```

**Document in:** `TRUST_BOUNDARIES.md` §5 "Verification escapes"

### Pragma: `pragma aborts_if_is_strict`

**When to use:** Module where ALL abort conditions are exhaustively specified.

**Effect:** Move Prover checks no other aborts possible.

**Example:**

```move
spec module aptos_experimental::confidential_balance {
    pragma aborts_if_is_strict = true;
    
    // Now every function must have complete aborts_if coverage
}
```

**Caution:** Hard to maintain (every new abort needs spec update).

### Pragma: `pragma deactivated_proof`

**When to use:** Temporary workaround for upstream bugs (document blocker).

**Effect:** Skip specific proof obligation.

**Example:**

```move
spec some_function {
    pragma deactivated_proof = "invariant";  // Skip invariant check
    
    // TODO: Remove when upstream bug #123 fixed
}
```

**Document in:** `TRUST_BOUNDARIES.md` + GitHub issue tracking removal

---

## Anti-Patterns (What NOT to Do)

### ❌ Incomplete Abort Specification

**Problem:** Function aborts but spec doesn't cover all cases.

```move
// BAD
spec withdraw {
    aborts_if !exists<ConfidentialAssetStore>(addr);
    // Missing: frozen check, verification failure, range proof failure
}

// GOOD
spec withdraw {
    aborts_if !exists<ConfidentialAssetStore>(addr) with ESTORE_NOT_FOUND;
    aborts_if global<ConfidentialAssetStore>(addr).frozen with ETOKEN_FROZEN;
    aborts_if !spec_verify_withdrawal_proof(...) with ESIGMA_PROTOCOL_VERIFY_FAILED;
    aborts_if !spec_verify_range_proof(...) with EBULLETPROOFS_VERIFY_FAILED;
}
```

### ❌ Mixing Implementation and Spec Logic

**Problem:** Spec duplicates Move implementation (brittle).

```move
// BAD
spec add_balances {
    ensures result.chunks[0] == balance1.chunks[0] + balance2.chunks[0];
    ensures result.chunks[1] == balance1.chunks[1] + balance2.chunks[1];
    // Repeats implementation logic
}

// GOOD
spec add_balances {
    ensures spec_decrypt(result) == spec_decrypt(balance1) + spec_decrypt(balance2);
    // Abstract property, robust to implementation changes
}
```

### ❌ Overly Specific Postconditions

**Problem:** Spec constrains implementation too tightly.

```move
// BAD
spec transfer {
    ensures global<ConfidentialAssetStore>(sender).actual_balance.chunks[0] ==
            old(global<ConfidentialAssetStore>(sender).actual_balance.chunks[0]) - amount_chunks[0];
    // Constrains chunking strategy
}

// GOOD
spec transfer {
    ensures spec_decrypt(global<ConfidentialAssetStore>(sender).actual_balance) ==
            spec_decrypt(old(global<ConfidentialAssetStore>(sender).actual_balance)) - amount;
    // Abstract, allows implementation flexibility
}
```

### ❌ Missing Frame Declarations

**Problem:** Function modifies global state without `modifies` clause.

```move
// BAD
spec register {
    ensures exists<ConfidentialAssetStore>(addr);
    // Missing: modifies global<ConfidentialAssetStore>(addr);
}

// GOOD
spec register {
    ensures exists<ConfidentialAssetStore>(addr);
    modifies global<ConfidentialAssetStore>(addr);
}
```

---

## Quick Reference

| Task | Pattern | Section |
|------|---------|---------|
| Spec internal function | Internal function template | §1 |
| Spec entry point | Entry point template | §1 |
| Check vector length | Length invariants | §2 |
| Check resource exists | Resource existence | §2 |
| Specify state updates | State updates | §3 |
| Preserve vector length | Length preservation | §3 |
| Handle resource not found | Resource not found | §4 |
| Handle proof verify failed | Proof verification failed | §4 |
| Declare resource modification | Single/multiple resource modified | §5 |
| Mark crypto boundary | Native crypto function | §6 |
| Spec deposit entry point | Deposit pattern | §7 |
| Spec withdrawal entry point | Withdrawal pattern | §7 |
| Declare store invariant | Store invariant | §8 |
| Abstract crypto operation | Abstract crypto operation | §9 |
| Use pragma opaque | §10 Pragma: opaque | |

---

## For More Examples

- **confidential_balance.spec.move** — Balance operations, length invariants
- **confidential_asset.spec.move** — Entry points, FA composition
- **confidential_proof.spec.move** — Crypto boundaries, pragma opaque

---

## Getting Help

- **Pattern not listed here?** Ask in #formal-verification Slack
- **Spec fails to verify?** Check `movement move prove` output for VC
- **New pattern discovered?** PR this doc with addition

**Happy specifying!** 📝
