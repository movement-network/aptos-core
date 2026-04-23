# Native Function Oracle Modeling Guide

**Purpose:** Complete methodology for modeling Move native functions as oracles in Lean formal verification.

**Audience:** Formal verification engineers working on Lean proofs that call native functions.

**Scope:** Oracle design patterns, axiom management, difftest validation, cross-stack consistency.

**Status:** Production-ready patterns from CA verification (21 permanent oracles).

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Oracle Design Principles](#2-oracle-design-principles)
3. [Oracle Pattern Library](#3-oracle-pattern-library)
4. [Axiom Formulation](#4-axiom-formulation)
5. [Difftest Validation](#5-difftest-validation)
6. [MSL Coordination](#6-msl-coordination)
7. [Performance Considerations](#7-performance-considerations)
8. [Maintenance](#8-maintenance)

---

## 1. Introduction

### 1.1 What is Native Function Oracle Modeling?

**Native functions** are Move functions implemented in Rust (not Move bytecode).

**Example native function:**

```move
// Move declaration (no body)
native fun verify_registration_proof_internal(
    proof: &RegistrationProof
): bool;

// Implementation in Rust (outside Move)
// aptos-move/framework/aptos-experimental/src/natives/mod.rs
fn verify_registration_proof_internal(
    context: &mut NativeContext,
    ty_args: Vec<Type>,
    mut args: VecDeque<Value>,
) -> PartialVMResult<NativeResult> {
    // Complex Rust implementation using crypto libraries
    // Ristretto255, SHA512, Bulletproofs, etc.
    ...
}
```

**Problem:** Lean can't directly verify Rust code.

**Solution:** Model native function as an **oracle** (black box with specified behavior).

**Oracle modeling:**

```lean
-- Oracle type
inductive RegistrationOracleResult
  | success
  | verifyFailed
  | error

-- Oracle function (axiomatized, not implemented)
axiom verify_registration_oracle :
  RegistrationProof → RegistrationOracleResult

-- Oracle correctness (assumed, validated by difftest)
axiom verify_registration_oracle_sound :
  ∀ proof,
    verify_registration_oracle proof = .success →
    is_valid_registration_proof proof
```

### 1.2 Why Oracle Modeling?

**Native functions can't be verified in Lean because:**

1. **Implementation is in Rust** — Lean proofs operate on Lean code, not Rust
2. **Crypto complexity** — Verifying Ristretto255 group operations, Bulletproofs, etc. requires cryptographic expertise beyond typical formal verification
3. **Performance** — Verifying crypto primitives could take years of proof engineering

**Oracle modeling allows:**

1. **Proof progress** — Verify Move bytecode that calls natives without verifying native implementations
2. **Compositionality** — Separate crypto assumptions (axioms) from bytecode correctness (proofs)
3. **Tractability** — Finite axiom count, manageable proof complexity

**Trust model:**

```
Move bytecode correctness: PROVEN in Lean
    ↓ (calls)
Native function behavior: AXIOMATIZED in Lean
    ↓ (validated)
Actual VM execution: TESTED via difftest
```

### 1.3 Oracle Lifecycle

**Lifecycle of a native function oracle:**

```
1. Design Oracle Interface
   - Identify native function in Move
   - Determine oracle result type
   - Design axiom structure
     ↓
2. Implement Oracle in Lean
   - Define oracle result type
   - Axiomatize oracle function
   - State soundness/completeness axioms
     ↓
3. Use Oracle in Proofs
   - Call oracle in eval theorems
   - Case-split on oracle results
   - Prove bytecode correctness modulo oracle
     ↓
4. Validate with Difftest
   - Mock oracle in difftest harness
   - Run concrete test cases
   - Ensure oracle behavior matches VM
     ↓
5. Coordinate with MSL
   - Mark native as pragma opaque in MSL
   - Ensure abort codes consistent
   - Document trust boundary
     ↓
6. Maintain and Review
   - Track in AXIOM_INVENTORY.md
   - Quarterly axiom review
   - Update if native implementation changes
```

---

## 2. Oracle Design Principles

### 2.1 Principle 1: Minimal Interface

**Design oracles with the smallest interface that supports verification.**

**Bad (over-specified):**

```lean
-- Too detailed, couples to Rust implementation
axiom verify_proof_oracle :
  Proof →
  Environment →
  TranscriptState →
  RandomnessSource →
  (Result × TranscriptState × RemainingGas)
```

**Good (minimal):**

```lean
-- Just enough to prove bytecode correctness
axiom verify_proof_oracle :
  Proof → OracleResult
```

**Rationale:** Smaller interface = fewer axioms = smaller trust base.

### 2.2 Principle 2: Observable Behavior Only

**Oracles should model observable VM behavior, not implementation details.**

**Bad (implementation detail):**

```lean
-- Exposes internal Rust types
axiom ristretto255_add_oracle :
  RistrettoPointInternalRepr →
  RistrettoPointInternalRepr →
  RistrettoPointInternalRepr
```

**Good (observable behavior):**

```lean
-- Models Move-level observable result
axiom ristretto255_add_oracle :
  RistrettoPoint →
  RistrettoPoint →
  RistrettoPoint
```

**Rationale:** Oracle should match what Move code observes, not Rust internals.

### 2.3 Principle 3: Error Modes Explicit

**All error modes must be explicit in oracle type.**

**Bad (errors hidden):**

```lean
-- Can't distinguish error cases
axiom verify_proof_oracle : Proof → Bool
```

**Good (errors explicit):**

```lean
inductive OracleResult
  | success
  | verifyFailed    -- Proof invalid
  | deserializeError  -- Proof malformed
  | error           -- Other error

axiom verify_proof_oracle : Proof → OracleResult
```

**Rationale:** Bytecode has different abort paths for different errors; oracle must distinguish them.

### 2.4 Principle 4: Deterministic Results

**Oracles should be deterministic (same input → same output).**

**Bad (non-deterministic):**

```lean
-- Random oracle (different results each call)
axiom random_oracle : Unit → Nat
```

**Good (deterministic, randomness explicit):**

```lean
-- Randomness explicit in input
axiom hash_to_scalar : ByteString → Randomness → Scalar
```

**Rationale:** Lean proofs assume determinism; non-deterministic oracles break soundness.

**Exception:** Crypto randomness is acceptable if it's an input (not hidden state).

### 2.5 Principle 5: Axiom Economy

**Minimize axiom count; prefer fewer powerful axioms over many weak ones.**

**Bad (many specific axioms):**

```lean
axiom verify_proof_case1 : Proof1 → Bool
axiom verify_proof_case2 : Proof2 → Bool
axiom verify_proof_case3 : Proof3 → Bool
-- 10 more axioms...
```

**Good (one general axiom):**

```lean
inductive ProofType
  | type1 (Proof1)
  | type2 (Proof2)
  | type3 (Proof3)

axiom verify_proof_oracle : ProofType → OracleResult
```

**Rationale:** Fewer axioms = easier to review, maintain, justify.

**CA verification:** 21 permanent axioms cover all native functions (economy achieved).

---

## 3. Oracle Pattern Library

### 3.1 Pattern: Boolean Oracle

**Use case:** Native function returns true/false.

**Example:** `verify_proof_internal(proof) : bool`

**Oracle design:**

```lean
-- Result type (distinguishes success/failure/error)
inductive BooleanOracleResult
  | success     -- Returns true
  | failed      -- Returns false
  | error       -- Aborts or errors

-- Oracle function
axiom verify_proof_oracle :
  Proof → BooleanOracleResult

-- Soundness axiom (what true means)
axiom verify_proof_oracle_sound :
  ∀ proof,
    verify_proof_oracle proof = .success →
    is_valid_proof proof

-- Completeness axiom (what false means)
axiom verify_proof_oracle_complete :
  ∀ proof,
    is_valid_proof proof →
    verify_proof_oracle proof = .success
```

**Usage in proof:**

```lean
theorem eval_verify_proof
    (h_oracle : verify_proof_oracle proof = result)
    : eval env (state 0) cs ms =
        match result with
        | .success => .returned [.bool true] ms
        | .failed => .returned [.bool false] ms
        | .error => .error ms
  := by
  cases result with
  | success =>
    -- Proof when oracle returns true
    unfold eval
    rw [step_call_oracle h_oracle]
    -- ... (chain to Ret with true)
  | failed =>
    -- Proof when oracle returns false
    unfold eval
    rw [step_call_oracle h_oracle]
    -- ... (chain to Ret with false)
  | error =>
    -- Proof when oracle errors
    rw [step_call_oracle_error h_oracle]
    rfl
```

**CA examples:**
- `verify_registration_proof_internal`
- `verify_transfer_proof_internal`
- `verify_withdrawal_proof_internal`
- `verify_rotation_proof_internal`
- `verify_normalization_proof_internal`

---

### 3.2 Pattern: Value-Returning Oracle

**Use case:** Native function computes and returns a value.

**Example:** `deserialize_proof(bytes) : Option<Proof>`

**Oracle design:**

```lean
-- Result type (value or error)
inductive DeserializeOracleResult (α : Type)
  | success (value : α)
  | deserializeError
  | error

-- Oracle function
axiom deserialize_proof_oracle :
  ByteVector → DeserializeOracleResult Proof

-- Well-formedness axiom
axiom deserialize_proof_oracle_wf :
  ∀ bytes proof,
    deserialize_proof_oracle bytes = .success proof →
    is_well_formed_proof proof
```

**Usage in proof:**

```lean
theorem eval_deserialize
    (h_oracle : deserialize_proof_oracle bytes = result)
    : eval env (state 0 bytes) cs ms =
        match result with
        | .success proof => .returned [.proof proof] ms
        | .deserializeError => .aborted EINVALID_FORMAT ms
        | .error => .error ms
  := by
  cases result with
  | success proof =>
    unfold eval
    rw [step_call_oracle h_oracle]
    -- ... (chain to Ret with proof)
  | deserializeError =>
    rw [step_call_oracle_deserialize_error h_oracle]
    -- ... (chain to abort)
  | error =>
    rw [step_call_oracle_error h_oracle]
    rfl
```

**CA examples:**
- `deserialize_registration_proof`
- `deserialize_transfer_proof`

---

### 3.3 Pattern: Arithmetic Oracle

**Use case:** Native function performs arithmetic (crypto or otherwise).

**Example:** `ristretto255_point_add(p1, p2) : RistrettoPoint`

**Oracle design:**

```lean
-- Oracle function (pure computation)
axiom ristretto255_add_oracle :
  RistrettoPoint → RistrettoPoint → RistrettoPoint

-- Group law axioms
axiom ristretto255_add_commutative :
  ∀ p q, ristretto255_add_oracle p q = ristretto255_add_oracle q p

axiom ristretto255_add_associative :
  ∀ p q r,
    ristretto255_add_oracle (ristretto255_add_oracle p q) r =
    ristretto255_add_oracle p (ristretto255_add_oracle q r)

axiom ristretto255_add_identity :
  ∀ p, ristretto255_add_oracle p ristretto255_identity = p
```

**Usage in proof:**

```lean
theorem eval_point_add
    (h_oracle : ristretto255_add_oracle p1 p2 = result)
    : eval env (state 0 p1 p2) cs ms =
        .returned [.ristrettoPoint result] ms
  := by
  unfold eval
  rw [step_call_oracle h_oracle]
  -- ... (chain to Ret with result)
  rfl
```

**Proof using group laws:**

```lean
theorem point_addition_symmetric
    (h1 : ristretto255_add_oracle p q = r1)
    (h2 : ristretto255_add_oracle q p = r2)
    : r1 = r2 := by
  rw [←h1, ←h2]
  apply ristretto255_add_commutative
```

**CA examples:**
- `ristretto255_point_add`
- `ristretto255_point_sub`
- `ristretto255_scalar_mul`
- `ristretto255_multi_scalar_mul`

---

### 3.4 Pattern: Stateful Oracle

**Use case:** Native function modifies state or has side effects.

**Example:** `event::emit(event_handle, event_data)`

**Oracle design:**

```lean
-- State type
structure EventState where
  emittedEvents : List Event

-- Oracle function (returns new state)
axiom emit_event_oracle :
  EventHandle → EventData → EventState → EventState

-- Axiom: emit appends event
axiom emit_event_oracle_appends :
  ∀ handle data oldState newState,
    newState = emit_event_oracle handle data oldState →
    newState.emittedEvents = oldState.emittedEvents ++ [Event.mk handle data]
```

**Usage in proof:**

```lean
theorem eval_emit_event
    (h_oracle : emit_event_oracle handle data ms.eventState = newEventState)
    : eval env (state 0 handle data) cs ms =
        .returned [] (ms.updateEventState newEventState)
  := by
  unfold eval
  rw [step_call_oracle h_oracle]
  -- ... (chain to Ret)
  rfl
```

**CA examples:**
- Event emission (when MSL `emits` framework lands)

---

### 3.5 Pattern: Multi-Step Oracle

**Use case:** Native function involves multiple sub-operations.

**Example:** `verify_proof_with_transcript(proof, transcript_state)`

**Oracle design:**

```lean
-- Sub-oracle for transcript update
axiom update_transcript_oracle :
  TranscriptState → ProofChallenge → TranscriptState

-- Main oracle uses sub-oracle
axiom verify_proof_with_transcript_oracle :
  Proof → TranscriptState →
  (OracleResult × TranscriptState)

-- Axiom: verification updates transcript correctly
axiom verify_proof_transcript_update :
  ∀ proof ts result ts',
    verify_proof_with_transcript_oracle proof ts = (result, ts') →
    ts' = update_transcript_oracle ts (extract_challenge proof)
```

**Usage in proof:**

```lean
theorem eval_verify_with_transcript
    (h_oracle : verify_proof_with_transcript_oracle proof ts = (result, ts'))
    : eval env (state 0 proof ts) cs ms =
        match result with
        | .success => .returned [.bool true] (ms.updateTranscript ts')
        | .verifyFailed => .returned [.bool false] (ms.updateTranscript ts')
  := by
  cases result with
  | success =>
    unfold eval
    rw [step_call_oracle h_oracle]
    -- Use transcript update axiom
    have h_ts : ts' = update_transcript_oracle ts _ :=
      verify_proof_transcript_update proof ts .success ts' h_oracle
    rw [h_ts]
    -- ... (chain to Ret)
  | verifyFailed =>
    -- Similar
    sorry
```

**CA examples:**
- Sigma protocol verification (multi-round)
- Fiat-Shamir transcript handling

---

## 4. Axiom Formulation

### 4.1 Soundness Axioms

**Soundness:** If oracle returns success, property holds.

**Pattern:**

```lean
axiom oracle_name_sound :
  ∀ input,
    oracle_name input = .success →
    desired_property input
```

**Example (Registration):**

```lean
axiom verify_registration_oracle_sound :
  ∀ proof,
    verify_registration_oracle proof = .success →
    is_valid_registration_proof proof

-- is_valid_registration_proof is defined mathematically
def is_valid_registration_proof (proof : RegistrationProof) : Prop :=
  -- Sigma protocol conditions
  verify_schnorr_signature proof.schnorr_sig proof.public_key ∧
  verify_pedersen_commitment proof.balance_commitment proof.amount ∧
  -- Range proof
  verify_bulletproof proof.range_proof proof.amount ∧
  -- Transcript integrity
  proof.challenge = fiat_shamir_hash proof.transcript
```

**Use in proofs:**

```lean
theorem registration_ensures_valid_proof
    (h_eval : eval env (state 0 proof) cs ms = .returned [] ms')
    : ∃ proof, is_valid_registration_proof proof := by
  -- Extract oracle result from eval
  have h_oracle : verify_registration_oracle proof = .success :=
    extract_oracle_success_from_eval h_eval
  -- Apply soundness axiom
  have h_valid : is_valid_registration_proof proof :=
    verify_registration_oracle_sound proof h_oracle
  exact ⟨proof, h_valid⟩
```

### 4.2 Completeness Axioms

**Completeness:** If property holds, oracle returns success.

**Pattern:**

```lean
axiom oracle_name_complete :
  ∀ input,
    desired_property input →
    oracle_name input = .success
```

**Example:**

```lean
axiom verify_registration_oracle_complete :
  ∀ proof,
    is_valid_registration_proof proof →
    verify_registration_oracle proof = .success
```

**Use in proofs:**

```lean
theorem valid_proof_accepted
    (h_valid : is_valid_registration_proof proof)
    : eval env (state 0 proof) cs ms = .returned [] ms' := by
  -- Apply completeness axiom
  have h_oracle : verify_registration_oracle proof = .success :=
    verify_registration_oracle_complete proof h_valid
  -- Prove eval using oracle result
  unfold eval
  rw [step_call_oracle h_oracle]
  -- ... (chain to success path)
```

**Note:** Completeness is less critical than soundness for security. Can be omitted if not needed.

### 4.3 Determinism Axioms

**Determinism:** Same input always produces same output.

**Pattern:**

```lean
axiom oracle_name_deterministic :
  ∀ input result1 result2,
    oracle_name input = result1 →
    oracle_name input = result2 →
    result1 = result2
```

**Example:**

```lean
axiom verify_registration_oracle_deterministic :
  ∀ proof result1 result2,
    verify_registration_oracle proof = result1 →
    verify_registration_oracle proof = result2 →
    result1 = result2
```

**Note:** In Lean, functions are deterministic by definition (same input → same output), so this axiom is often redundant. Only needed if modeling non-functional behavior.

### 4.4 Error Condition Axioms

**Error conditions:** When does oracle return error vs success vs specific failure?

**Pattern:**

```lean
axiom oracle_name_error_condition :
  ∀ input,
    oracle_name input = .error ↔ error_condition input

axiom oracle_name_failure_condition :
  ∀ input,
    oracle_name input = .failed ↔ failure_condition input
```

**Example:**

```lean
axiom verify_registration_oracle_error_on_malformed :
  ∀ proof,
    verify_registration_oracle proof = .deserializeError ↔
    ¬is_well_formed_proof proof

axiom verify_registration_oracle_fails_on_invalid :
  ∀ proof,
    is_well_formed_proof proof →
    (verify_registration_oracle proof = .verifyFailed ↔
     ¬is_valid_registration_proof proof)
```

**Use in proofs:**

```lean
theorem malformed_proof_aborts
    (h_malformed : ¬is_well_formed_proof proof)
    : eval env (state 0 proof) cs ms = .aborted EINVALID_FORMAT ms := by
  -- Apply error condition axiom
  have h_oracle : verify_registration_oracle proof = .deserializeError :=
    (verify_registration_oracle_error_on_malformed proof).mpr h_malformed
  -- Prove eval aborts
  unfold eval
  rw [step_call_oracle_error h_oracle]
  -- ... (chain to abort)
```

### 4.5 Axiom Naming Convention

**Consistent naming improves maintainability:**

| Axiom Type | Naming Pattern | Example |
|------------|----------------|---------|
| Oracle function | `<operation>_oracle` | `verify_registration_oracle` |
| Soundness | `<oracle>_sound` | `verify_registration_oracle_sound` |
| Completeness | `<oracle>_complete` | `verify_registration_oracle_complete` |
| Determinism | `<oracle>_deterministic` | `verify_registration_oracle_deterministic` |
| Error condition | `<oracle>_error_on_<condition>` | `verify_registration_oracle_error_on_malformed` |
| Property definition | `is_<property>` | `is_valid_registration_proof` |

**Benefits:**
- Easy to find related axioms
- Consistent documentation
- Automated axiom inventory generation

---

## 5. Difftest Validation

### 5.1 Difftest Role in Oracle Validation

**Oracles are axiomatized, not proven. Difftest validates they match reality.**

**Validation strategy:**

```
Lean Oracle Axiom
    ↓ (defines expected behavior)
Difftest Mock Oracle
    ↓ (implements simplified version)
Difftest Test Cases
    ↓ (runs concrete inputs)
VM Execution
    ↓ (actual Rust native)
Compare Results
    ↓
If match: Oracle axiom is empirically validated
If mismatch: Oracle axiom is wrong OR VM has bug
```

**Example:**

```lean
-- Lean axiom (abstract)
axiom verify_registration_oracle : Proof → OracleResult
```

```rust
// Difftest mock (concrete)
fn mock_verify_registration_oracle(proof: &Proof) -> OracleResult {
    // Simplified check (not full crypto, but matches VM observable behavior)
    if !proof.is_well_formed() {
        return OracleResult::DeserializeError;
    }
    if !crypto::verify_schnorr(&proof.schnorr_sig, &proof.public_key) {
        return OracleResult::VerifyFailed;
    }
    if !crypto::verify_bulletproof(&proof.range_proof) {
        return OracleResult::VerifyFailed;
    }
    OracleResult::Success
}
```

```rust
// Difftest test case
#[test]
fn test_verify_registration_valid_proof() {
    let proof = generate_valid_proof();
    
    // Mock oracle
    let mock_result = mock_verify_registration_oracle(&proof);
    assert_eq!(mock_result, OracleResult::Success);
    
    // Actual VM
    let vm_result = execute_vm_native_verify(proof);
    assert_eq!(vm_result, true);  // VM returns bool
    
    // Results match ✓
}

#[test]
fn test_verify_registration_invalid_proof() {
    let proof = generate_invalid_proof();
    
    let mock_result = mock_verify_registration_oracle(&proof);
    assert_eq!(mock_result, OracleResult::VerifyFailed);
    
    let vm_result = execute_vm_native_verify(proof);
    assert_eq!(vm_result, false);
    
    // Results match ✓
}
```

### 5.2 Coverage Requirements

**Difftest must cover all oracle paths:**

| Oracle Result | Difftest Coverage Required |
|---------------|----------------------------|
| `.success` | ≥ 3 test cases (happy paths) |
| `.verifyFailed` | ≥ 2 test cases (different failure reasons) |
| `.deserializeError` | ≥ 1 test case (malformed input) |
| `.error` | ≥ 1 test case (if reachable) |

**Example coverage matrix:**

```markdown
## Oracle: verify_registration_oracle

| Test Case | Input | Expected Result | Status |
|-----------|-------|-----------------|--------|
| Valid proof (happy path) | Well-formed, valid signature, valid range proof | .success | ✅ Pass |
| Valid proof (edge case: min amount) | Amount = 0 | .success | ✅ Pass |
| Valid proof (edge case: max amount) | Amount = 2^64-1 | .success | ✅ Pass |
| Invalid signature | Bad schnorr_sig | .verifyFailed | ✅ Pass |
| Invalid range proof | Amount outside range | .verifyFailed | ✅ Pass |
| Malformed proof | Truncated bytes | .deserializeError | ✅ Pass |
```

**Acceptance:** ≥95% oracle path coverage (97/102 scenarios for CA).

### 5.3 Mock Oracle Implementation

**Mock oracles should:**

1. **Match VM observable behavior** (not internal implementation)
2. **Be simple** (not full crypto implementation, just enough to test)
3. **Cover all result types** (success, fail, error)

**Example mock:**

```rust
fn mock_verify_registration_oracle(proof_bytes: &[u8]) -> OracleResult {
    // Step 1: Deserialize
    let proof = match deserialize_proof(proof_bytes) {
        Ok(p) => p,
        Err(_) => return OracleResult::DeserializeError,
    };
    
    // Step 2: Check well-formedness
    if !is_well_formed(&proof) {
        return OracleResult::VerifyFailed;
    }
    
    // Step 3: Simplified crypto check (NOT full verification)
    // Just check structure, not actual crypto math
    if proof.schnorr_sig.is_empty() || proof.public_key.is_empty() {
        return OracleResult::VerifyFailed;
    }
    
    // For difftest: accept if proof has expected structure
    // Real VM does full crypto, but mock just validates test scenarios
    OracleResult::Success
}
```

**Why simplified?**
- Difftest runs thousands of times in CI
- Full crypto is slow (Bulletproofs verification ~100ms)
- Mock validates API contract, not crypto correctness
- Crypto correctness is external audit responsibility

### 5.4 Abort Code Validation

**Oracle error paths must match abort codes across stacks:**

```lean
-- Lean: Oracle returns .verifyFailed → abort 65537
theorem registration_aborts_on_invalid_proof
    (h_oracle : verify_registration_oracle proof = .verifyFailed)
    : eval env (state 0 proof) cs ms = .aborted 65537 ms
```

```move
// MSL: Native aborts with 65537 on invalid proof
spec verify_registration_proof_internal {
    aborts_if !is_valid_proof(proof) with EVERIFY_FAILED;  // 65537
}
```

```rust
// Difftest: VM aborts with 65537
#[test]
fn test_registration_invalid_proof_abort_code() {
    let proof = generate_invalid_proof();
    let result = execute_registration(proof);
    
    assert!(result.is_aborted());
    assert_eq!(result.abort_code(), 65537);  // Must match Lean and MSL
}
```

**Consistency check:**

```bash
./scripts/check_abort_code_consistency.sh

# Output:
# Checking EVERIFY_FAILED (65537)...
#   Lean: ✓ found (.aborted 65537)
#   MSL: ✓ found (aborts_if ... with 65537)
#   Difftest: ✓ found (assert_eq!(..., 65537))
# Consistency: 100%
```

---

## 6. MSL Coordination

### 6.1 Pragma Opaque Pattern

**MSL marks native functions as `pragma opaque` (black box).**

**Example:**

```move
// Native declaration
native fun verify_registration_proof_internal(
    proof: &RegistrationProof
): bool;

// MSL spec (sidecar file)
spec verify_registration_proof_internal {
    pragma opaque;  // Move Prover treats as uninterpreted function
    
    // Abstract specification (what, not how)
    ensures result == true ⟹ is_valid_registration_proof(proof);
    ensures result == false ⟹ !is_valid_registration_proof(proof);
    
    aborts_if !is_well_formed_proof(proof) with EINVALID_FORMAT;
}

// Ghost function (uninterpreted)
spec fun is_valid_registration_proof(proof: &RegistrationProof): bool;
```

**MSL behavior:**
- Move Prover doesn't try to verify function body (no body to verify)
- Treats function as axiom with pre/post conditions
- Composes with caller specs via abstract `ensures` clauses

**Lean-MSL alignment:**

| Aspect | Lean | MSL |
|--------|------|-----|
| Native modeling | Oracle axiom | Pragma opaque |
| Result type | `OracleResult` | `bool` |
| Success semantics | `.success` | `true` |
| Failure semantics | `.verifyFailed` | `false` |
| Error semantics | `.deserializeError` | `aborts_if !is_well_formed` |
| Property definition | `is_valid_registration_proof` (Lean) | `is_valid_registration_proof` (MSL ghost) |

**Consistency:** Both stacks agree on abstract semantics, modulo representation.

### 6.2 Abort Condition Alignment

**MSL `aborts_if` must match Lean oracle error conditions.**

**Example:**

```move
// MSL
spec verify_registration_proof_internal {
    aborts_if !is_well_formed_proof(proof) with EINVALID_FORMAT;
    aborts_if is_well_formed_proof(proof) && !is_valid_proof(proof) with EVERIFY_FAILED;
}
```

```lean
-- Lean
axiom verify_registration_oracle_error_on_malformed :
  ∀ proof,
    verify_registration_oracle proof = .deserializeError ↔
    ¬is_well_formed_proof proof

axiom verify_registration_oracle_fails_on_invalid :
  ∀ proof,
    is_well_formed_proof proof →
    (verify_registration_oracle proof = .verifyFailed ↔
     ¬is_valid_registration_proof proof)
```

**Mapping:**

```
MSL aborts_if !is_well_formed with EINVALID_FORMAT
    ↔
Lean oracle = .deserializeError when ¬is_well_formed
    ↔
Difftest assert_eq!(abort_code, EINVALID_FORMAT)
```

**Consistency script validates this alignment automatically.**

### 6.3 Ghost Function Coordination

**MSL ghost functions and Lean axiom predicates should align.**

**Example:**

```move
// MSL ghost function
spec fun is_valid_registration_proof(proof: &RegistrationProof): bool;
```

```lean
-- Lean predicate (same name, same semantics)
def is_valid_registration_proof (proof : RegistrationProof) : Prop :=
  verify_schnorr_signature proof.schnorr_sig proof.public_key ∧
  verify_pedersen_commitment proof.balance_commitment proof.amount ∧
  verify_bulletproof proof.range_proof proof.amount ∧
  proof.challenge = fiat_shamir_hash proof.transcript
```

**Benefit:** Shared vocabulary across stacks, easier to review consistency.

**Caveat:** MSL ghost is uninterpreted (no body), Lean predicate has mathematical definition. They align semantically, not syntactically.

---

## 7. Performance Considerations

### 7.1 Oracle Call Overhead

**Each oracle call in proof adds:**
- Hypothesis in theorem statement (`h_oracle : oracle ... = result`)
- Case split on result (`cases result with ...`)
- Rewrite step (`rw [step_call_oracle h_oracle]`)

**Impact:**
- ~5-10 lines Lean per oracle call
- ~0.1-0.5s elaboration time per oracle call
- Cumulative overhead for operations with many native calls

**Example (Transfer with 3 oracles):**

```lean
theorem transfer_eval_equiv
    (h_deserialize : deserialize_proof_oracle bytes = deserializeResult)
    (h_verify : verify_transfer_oracle proof = verifyResult)
    (h_balance_check : check_balance_oracle sender amount = balanceResult)
    : eval env (state 0 ...) cs ms = ... := by
  -- 3 oracles → 3 case splits → O(3^3) = 27 proof branches!
  cases deserializeResult with
  | success proof =>
    cases verifyResult with
    | success =>
      cases balanceResult with
      | sufficient =>
        -- Happy path
        unfold eval
        rw [step_deserialize h_deserialize]
        rw [step_verify h_verify]
        rw [step_balance_check h_balance_check]
        -- ... (chain to Ret)
      | insufficient =>
        -- Balance check fails
        -- ... (chain to abort)
    | verifyFailed =>
      -- Verify fails
      -- ... (chain to abort)
  | deserializeError =>
    -- Deserialize fails
    -- ... (chain to abort)
```

**27 branches is too many!**

**Optimization: Factor oracles into lemmas:**

```lean
-- Lemma for deserialize + verify sequence
theorem transfer_deserialize_and_verify
    (h_deserialize : deserialize_proof_oracle bytes = .success proof)
    (h_verify : verify_transfer_oracle proof = .success)
    : run env (state 0 bytes) 10 = .inProgress (state 10 proof) := by
  rw [run_succ, step_deserialize h_deserialize]
  rw [run_succ, step_verify h_verify]
  -- ... (short chain)
  rfl

-- Main theorem uses lemma
theorem transfer_eval_equiv
    (h_deserialize : deserialize_proof_oracle bytes = deserializeResult)
    (h_verify : verify_transfer_oracle proof = verifyResult)
    (h_balance : check_balance_oracle sender amount = balanceResult)
    : eval env (state 0 ...) cs ms = ... := by
  cases deserializeResult with
  | success proof =>
    cases verifyResult with
    | success =>
      cases balanceResult with
      | sufficient =>
        -- Use lemma (2 oracles factored out)
        rw [transfer_deserialize_and_verify h_deserialize h_verify]
        -- Only need to handle balance check here
        rw [step_balance_check h_balance]
        -- ... (shorter proof)
      | insufficient =>
        -- ... (factored proof)
    | verifyFailed =>
      -- ... (factored proof)
  | deserializeError =>
    -- ... (short abort path)
```

**Result:** Proof complexity O(N) instead of O(2^N) in oracle count.

### 7.2 Axiom Minimization

**Fewer axioms = faster proof checking.**

**Redundant axioms:**

```lean
-- Bad (3 axioms for same concept)
axiom verify_oracle_sound : ...
axiom verify_oracle_complete : ...
axiom verify_oracle_deterministic : ...
```

**Minimal axioms:**

```lean
-- Good (1 axiom, others derived)
axiom verify_oracle : Proof → OracleResult

-- Soundness follows from oracle definition + predicate
def is_valid_proof (proof : Proof) : Prop :=
  verify_oracle proof = .success

-- No need for separate soundness axiom!
```

**When to minimize:**
- If axiom can be derived from others → remove it
- If axiom is never used in proofs → remove it
- If axiom is redundant with definition → remove it

**CA axiom count:** 21 permanent (minimal, all justified).

### 7.3 Build Time Impact

**Each axiom adds to build time:**

| Axiom Count | Typical Build Time Impact |
|-------------|---------------------------|
| 0-5 axioms | Negligible (<1s) |
| 5-10 axioms | Low (~1-5s) |
| 10-20 axioms | Moderate (~5-15s) |
| 20-50 axioms | High (~15-60s) |
| >50 axioms | Very high (>60s) |

**CA verification:** 21 axioms → ~15s overhead (acceptable).

**If build time exceeds budget:**
1. Check axiom count (`./scripts/check_axioms.sh`)
2. Identify unused axioms (grep theorem files)
3. Remove redundant axioms
4. Factor axioms into lemmas where possible

---

## 8. Maintenance

### 8.1 Axiom Inventory

**All oracles and axioms tracked in `audit/AXIOM_INVENTORY.md`.**

**Inventory format:**

```markdown
## Oracle: verify_registration_proof_internal

**Location:** `MovementFormal/AptosStd/Crypto/Registration.lean`

**Axioms (3 total):**

1. `verify_registration_oracle : RegistrationProof → OracleResult`
   - **Type:** Oracle function
   - **Justification:** Native Rust implementation (aptos-experimental/src/natives/registration.rs)
   - **Validation:** Difftest coverage 100% (3 happy paths, 2 failure paths, 1 error path)
   - **Category:** Permanent (crypto oracle)

2. `verify_registration_oracle_sound`
   - **Type:** Soundness axiom
   - **Statement:** `oracle proof = .success → is_valid_registration_proof proof`
   - **Justification:** Defines what valid proof means
   - **Category:** Permanent

3. `verify_registration_oracle_complete`
   - **Type:** Completeness axiom
   - **Statement:** `is_valid_proof proof → oracle proof = .success`
   - **Justification:** Ensures oracle accepts all valid proofs
   - **Category:** Permanent

**Difftest coverage:** 6/6 test cases passing

**MSL coordination:** `pragma opaque` in `confidential_proof.spec.move`

**Abort codes:** EVERIFY_FAILED (65537), EINVALID_FORMAT (524289)

**Review date:** 2026-04-22

**Next review:** 2026-07-22 (quarterly)
```

**Update triggers:**
- New oracle added → add to inventory
- Axiom added/removed → update inventory
- Difftest coverage changes → update coverage
- MSL spec changes → update coordination section

### 8.2 Quarterly Review

**Every quarter, review all oracles:**

**Review checklist:**

- [ ] Axiom still necessary? (Check if used in proofs)
- [ ] Axiom still justified? (Native implementation unchanged?)
- [ ] Difftest coverage adequate? (≥95%?)
- [ ] MSL alignment maintained? (Pragma opaque still there?)
- [ ] Abort codes consistent? (Lean = MSL = Difftest?)
- [ ] Performance acceptable? (Build time within budget?)

**Review process:**

```bash
# 1. Generate current axiom list
./scripts/check_axioms.sh > axioms_current.txt

# 2. Diff against baseline
diff audit/axiom-baseline.txt axioms_current.txt

# 3. For each change:
#    - If added: justify in AXIOM_INVENTORY.md
#    - If removed: document removal reason
#    - If modified: explain why

# 4. Update baseline if changes justified
cp axioms_current.txt audit/axiom-baseline.txt

# 5. Update AXIOM_INVENTORY.md review dates
```

**Quarterly review takes ~2 hours for 21 axioms.**

### 8.3 Native Function Changes

**If Rust native implementation changes, update oracle:**

**Change detection:**

```bash
# Monitor native implementations
git log --oneline -- aptos-move/framework/aptos-experimental/src/natives/

# If natives changed, check if oracle needs update
```

**Update workflow:**

1. **Review native change**
   - Read commit diff
   - Understand semantic change

2. **Check if oracle affected**
   - Does change affect observable behavior?
   - Does change affect error conditions?
   - Does change affect abort codes?

3. **Update oracle if needed**
   - Modify oracle axioms
   - Update difftest mocks
   - Re-run difftest
   - Update AXIOM_INVENTORY.md

4. **Update proofs if needed**
   - Re-check theorems using oracle
   - Update case splits if oracle result type changed
   - Rebuild Lean files

5. **Validate cross-stack consistency**
   - Check MSL pragma opaque still applies
   - Check abort codes still match
   - Run full verification suite

**Example:**

```
Native change: verify_registration_proof_internal now returns u8 instead of bool

Impact:
- Oracle result type needs update (OracleResult now has .successWithCode variant)
- Difftest mock needs update (return u8, not bool)
- Proofs need update (case-split on u8 values)
- MSL spec needs update (return type changed)

Effort: ~4 hours (oracle update + proof update + validation)
```

### 8.4 Deprecating Temporary Oracles

**Some oracles are temporary (waiting for upstream fixes).**

**Deprecation workflow:**

1. **Identify temporary oracle** (marked in AXIOM_INVENTORY.md)
2. **Check if blocker resolved** (e.g., ristretto255 patches landed)
3. **Replace oracle with proof**
   - Implement Lean proof using new infrastructure
   - Remove axiom declaration
   - Verify downstream proofs still build
4. **Update inventory**
   - Mark axiom as REMOVED
   - Document replacement theorem
   - Update axiom count

**Example:**

```lean
-- Before (temporary axiom)
axiom ristretto255_add_commutative :
  ∀ p q, ristretto255_add p q = ristretto255_add q p

-- After (proven theorem using crypto library)
theorem ristretto255_add_commutative :
  ∀ p q, ristretto255_add p q = ristretto255_add q p := by
  intro p q
  apply ristretto255_group_law_commutative  -- From verified crypto library
```

**Axiom count:** 23 → 22 (temporary axiom removed).

---

**END OF GUIDE**

**Key takeaways:**

1. **Oracles model native functions as black boxes** — axiomatized, not implemented
2. **Design minimal interfaces** — smallest oracle that supports verification
3. **Use oracle pattern library** — Boolean, value-returning, arithmetic, stateful, multi-step
4. **Formulate axioms carefully** — soundness, completeness, error conditions
5. **Validate with difftest** — ≥95% coverage, all oracle paths tested
6. **Coordinate with MSL** — pragma opaque, abort codes, ghost functions
7. **Optimize for performance** — factor oracles into lemmas, minimize axiom count
8. **Maintain rigorously** — inventory, quarterly reviews, deprecate temporary oracles

**Next steps:**

- Apply patterns to new native functions
- Review existing oracles for optimization
- Update AXIOM_INVENTORY.md
- Run quarterly oracle review

**Questions?** See `audit/AXIOM_INVENTORY.md` or `audit/TRUST_BOUNDARIES.md`.
