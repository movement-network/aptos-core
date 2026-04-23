# Complete Verification Workflow for Confidential Assets

**Purpose:** End-to-end workflow guide for verifying a CA operation from initial implementation through to production-ready formal verification across all three stacks.

**Audience:** Developers implementing new CA operations or modifying existing ones.

**Estimated time:** 2-4 weeks per operation (depending on complexity).

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Phase A: Move Implementation](#phase-a-move-implementation)
4. [Phase B: MSL Specification](#phase-b-msl-specification)
5. [Phase C: Lean EvalEquiv Proof](#phase-c-lean-evalequiv-proof)
6. [Phase D: Lean Composition Proof](#phase-d-lean-composition-proof)
7. [Phase E: Difftest Corpus](#phase-e-difftest-corpus)
8. [Phase F: Integration Testing](#phase-f-integration-testing)
9. [Phase G: Documentation and Audit Package](#phase-g-documentation-and-audit-package)
10. [Phase H: Review and Merge](#phase-h-review-and-merge)

---

## 1. Overview

### 1.1 Three-Stack Verification

Every CA operation must be verified across three independent proof systems:

1. **Lean** — Bytecode-level correctness (crypto verifiers, PC-level semantics)
2. **Move Prover** — Source-level correctness (state invariants, resource safety)
3. **Difftest** — VM fidelity (concrete input/output consistency)

### 1.2 Workflow Phases

| Phase | Deliverable | Time Estimate | Blocking Dependencies |
|---|---|---|---|
| A | Move implementation + tests | 1-3 days | Design doc, security review |
| B | MSL specs | 2-4 days | Phase A complete |
| C | Lean EvalEquiv proof | 5-10 days | Phase A complete |
| D | Lean Phase 6 composition | 3-5 days | Phase C complete |
| E | Difftest corpus | 2-3 days | Phase A complete |
| F | Integration testing | 1-2 days | Phases B, C, D, E complete |
| G | Documentation | 2-3 days | Phase F complete |
| H | Review and merge | 3-7 days | Phase G complete |

**Total:** 2-4 weeks per operation.

---

## 2. Prerequisites

### 2.1 Environment Setup

Ensure all three stacks are installed and working:

```bash
# Lean 4
cd lean
lake exe cache get
lake build MovementFormal.MoveModel

# Move Prover
movement update prover-dependencies --assume-yes
movement move prove --package-dir aptos-move/framework/move-stdlib --filter vector

# Difftest
# (Assuming difftest runner is set up)
./scripts/manage_difftest_corpus.sh list registration
```

All three should complete without errors.

### 2.2 Familiarize with Examples

Before starting, review existing operations:

- **Simplest:** Normalization (14 PCs, 1 proof, no state mutation)
- **Medium:** Withdrawal (15 PCs, 1 proof, balance decrease)
- **Complex:** Transfer (24 PCs, 3 proofs, multi-party balance updates)

Read the worked examples:
- `NORMALIZATION_PROOF_WORKED_EXAMPLE.md` (if it exists, or Withdrawal/Rotation examples)
- `PHASE_4_ARCHITECTURE_OVERVIEW.md`

### 2.3 Design Doc

Write a design doc outlining:
- **What:** Operation purpose (e.g., "rotate encryption key and re-encrypt all balance chunks")
- **Inputs:** Parameters and their types
- **Preconditions:** What must be true before the operation runs (e.g., account not frozen)
- **Postconditions:** What must be true after (e.g., balance sum preserved)
- **Abort conditions:** All error paths
- **Security properties:** What the verification will prove

Get this reviewed before writing code.

---

## Phase A: Move Implementation

### A.1 Write the Move Code

**Location:** `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_asset.move`

**Pattern:**
```move
/// Rotates the encryption key for a confidential asset store.
/// 
/// Preconditions:
/// - Caller owns the ConfidentialAssetStore
/// - Store is not frozen
/// - Rotation proof is valid
///
/// Postconditions:
/// - encryption_pubkey is updated to new_pubkey
/// - All balance chunks are re-encrypted under new_pubkey
/// - Balance sum is preserved
public entry fun rotate_encryption_key(
    owner: &signer,
    new_pubkey: RistrettoPoint,
    rotation_proof: &RotationProof
) acquires ConfidentialAssetStore {
    let owner_addr = signer::address_of(owner);
    let store = borrow_global_mut<ConfidentialAssetStore>(owner_addr);
    
    // Precondition checks
    assert!(!store.frozen, ETOKEN_IS_FROZEN);
    
    // Verify proof
    assert!(
        verify_rotation_proof(&store.encryption_pubkey, &new_pubkey, rotation_proof),
        EPROOF_VERIFICATION_FAILED
    );
    
    // Update state
    store.encryption_pubkey = new_pubkey;
    // Re-encrypt balance chunks (implementation details omitted)
    
    // Emit event
    event::emit(KeyRotationEvent {
        owner: owner_addr,
        old_pubkey: store.encryption_pubkey,
        new_pubkey,
    });
}
```

**Key points:**
- Document preconditions, postconditions, abort conditions
- Use descriptive error codes (defined as constants at module level)
- Emit events for observable state changes

### A.2 Write Move Unit Tests

**Location:** `aptos-move/framework/aptos-experimental/tests/confidential_asset_tests.move`

```move
#[test]
fun test_rotation_happy_path() {
    // Setup
    let owner = account::create_account_for_test(@0x123);
    let old_pubkey = /* ... */;
    let new_pubkey = /* ... */;
    let proof = /* ... */;
    
    // Register
    confidential_asset::register(&owner, old_pubkey, /* ... */);
    
    // Rotate
    confidential_asset::rotate_encryption_key(&owner, new_pubkey, &proof);
    
    // Verify
    let store = borrow_global<ConfidentialAssetStore>(@0x123);
    assert!(store.encryption_pubkey == new_pubkey, 0);
}

#[test]
#[expected_failure(abort_code = ETOKEN_IS_FROZEN)]
fun test_rotation_fails_when_frozen() {
    // Setup
    let owner = account::create_account_for_test(@0x123);
    register(...);
    freeze_token(...);
    
    // Attempt rotation (should abort)
    rotate_encryption_key(...);
}
```

### A.3 Test Locally

```bash
movement move test --package-dir aptos-move/framework/aptos-experimental
```

**Expected:** All tests pass.

### A.4 Milestone: A Complete

**Checklist:**
- ✅ Move implementation compiles
- ✅ Unit tests pass (happy path + error paths)
- ✅ Code reviewed for security vulnerabilities (no injection attacks, proper bounds checks)
- ✅ Error codes documented

**Commit:** `feat(ca): add rotation operation Move implementation`

---

## Phase B: MSL Specification

### B.1 Write the Spec

**Location:** `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_asset.spec.move`

```move
spec rotate_encryption_key_internal(
    store: &mut ConfidentialAssetStore,
    new_pubkey: RistrettoPoint,
    rotation_proof: &RotationProof
) {
    pragma aborts_if_is_strict;
    
    // Precondition: account not frozen
    aborts_if store.frozen with ETOKEN_IS_FROZEN;
    
    // Precondition: proof must verify
    aborts_if !verify_rotation_proof(
        store.encryption_pubkey,
        new_pubkey,
        rotation_proof
    ) with EPROOF_VERIFICATION_FAILED;
    
    // Postcondition: key is updated
    ensures store.encryption_pubkey == new_pubkey;
    
    // Postcondition: balance sum preserved
    let old_sum = sum_balance_chunks(old(store.pending_balance));
    let new_sum = sum_balance_chunks(store.pending_balance);
    ensures old_sum == new_sum;
    
    // Postcondition: chunk count preserved
    ensures len(store.pending_balance) == len(old(store.pending_balance));
}
```

### B.2 Run Move Prover

```bash
movement move prove \
  --package-dir aptos-move/framework/aptos-experimental \
  --filter confidential_asset::rotate_encryption_key_internal \
  --vc-timeout 120
```

**Expected:**
```
{
  "Result": "Success",
  "VCs": [
    { "status": "verified", "duration": 2.3 }
  ]
}
```

If VCs fail, debug:
1. Read the VC failure message
2. Check if the spec is too strong (relax it)
3. Check if the implementation is wrong (fix it)

### B.3 Milestone: B Complete

**Checklist:**
- ✅ MSL spec compiles
- ✅ All VCs verify
- ✅ Spec accurately reflects implementation behavior
- ✅ All abort conditions enumerated

**Commit:** `feat(ca): add rotation operation MSL spec`

---

## Phase C: Lean EvalEquiv Proof

### C.1 Transcribe Bytecode

**Location:** `lean/MovementFormal/MoveModel/Programs/ConfidentialAsset.lean`

1. **Compile Move to bytecode:**
   ```bash
   movement move build --package-dir aptos-move/framework/aptos-experimental --save-bytecode
   ```

2. **Disassemble the function:**
   ```bash
   movement move disassemble \
     --bytecode-path target/bytecode/modules/*.mv \
     --function rotate_encryption_key_internal
   ```

3. **Transcribe to Lean:**
   ```lean
   def rotateEncryptionKeyCode : Array Instruction := #[
     Instruction.immBorrowLoc 0,       -- PC 0
     Instruction.ldConst 0,            -- PC 1
     -- ... (15 instructions total)
     Instruction.ret,                  -- PC 14
   ]
   ```

   **Guide:** `BYTECODE_TRANSCRIPTION_GUIDE.md`

### C.2 Define Symbolic States

**Location:** `lean/MovementFormal/Experimental/ConfidentialAsset/Rotation/EvalEquiv.lean`

```lean
@[irreducible]
def rotationState (pc : Nat) (storeRef : RefValue) (newPubkey : RistrettoPoint) (...) : Frame :=
  { code := rotateEncryptionKeyCode,
    pc := pc,
    locals := #[
      some (MoveValue.ref storeRef),  -- loc 0: &mut ConfidentialAssetStore
      some (MoveValue.struct [newPubkey]),  -- loc 1: new pubkey
      ...
    ],
    localRefs := #[...] }
```

### C.3 Prove Per-PC Step Lemmas

```lean
theorem step_pc0_immBorrowLoc :
    step env (rotationState 0 storeRef newPubkey ...) cs ms =
      .ok (rotationState 1 storeRef newPubkey ...) cs ms := by
  rw [rotationState]
  rw [step_immBorrowLoc_frame]
  rfl

theorem step_pc1_ldConst : ... := by
  rw [rotationState]
  rw [step_ldConst_frame]
  rfl

-- ... (one theorem per PC, 15 total)
```

**Use step-lemma library:**
- `step_immBorrowLoc_frame`
- `step_ldConst_frame`
- `step_call_frame`
- `step_ret_frame`
- etc. (from `MovementFormal.MoveModel.StepLemmas.*`)

### C.4 Prove Top-Level Eval Theorem

```lean
theorem eval_rotation_eq_run :
    eval (rotationModuleEnv o) rotateEncryptionKeyIdx args cs ms =
      run env (rotationInitFrame args) cs ms := by
  unfold eval rotationModuleEnv rotateEncryptionKeyIdx
  rw [step_pc0, step_pc1, ..., step_pc14]
  rfl
```

### C.5 Test Build

```bash
lake build MovementFormal.Experimental.ConfidentialAsset.Rotation.EvalEquiv
```

**Target:** < 3 minutes (per Phase 4 budget).

If it exceeds 3 min, optimize:
- Ensure states are `@[irreducible]`
- Use `simp only [...]` not bare `simp`
- Avoid bound proofs in theorem statements

### C.6 Milestone: C Complete

**Checklist:**
- ✅ All 15 PC steps proved (no `sorry`)
- ✅ Top-level `eval_rotation_eq_run` proved
- ✅ Zero new axioms (check with `scripts/check_axioms.sh`)
- ✅ Builds in < 3 minutes

**Commit:** `feat(ca): add rotation operation Lean EvalEquiv proof`

---

## Phase D: Lean Composition Proof

### D.1 Define Functional Simulation

**Location:** `lean/MovementFormal/Experimental/ConfidentialAsset/Rotation/FunctionalSim.lean`

```lean
def verifyRotationBytecodeResult
    (oracle : RotationNativeOracle)
    (storeRef : RefValue)
    (newPubkey : RistrettoPoint)
    (proof : RotationProof) : ExecResult :=
  match oracle.verifyRotationProof storeRef newPubkey proof with
  | none => .error "rotation proof verification failed"
  | some _ => .returned [] empty
```

### D.2 Prove Shape Lemmas

**Location:** `lean/MovementFormal/Experimental/ConfidentialAsset/Rotation/Phase6Composition.lean`

```lean
theorem rotation_shape_verifyFailed
    (h_oracle : oracle.verifyRotationProof ... = none) :
    run env frame cs ms = .error "rotation proof verification failed" := by
  unfold run
  rw [step_pc0, ..., step_pc7]  -- PCs up to the native call
  rw [h_oracle]  -- Substitute oracle result
  simp only [step_call_native_none]
  rfl

theorem rotation_shape_success
    (h_oracle : oracle.verifyRotationProof ... = some proof) :
    run env frame cs ms = .returned [] ms' := by
  unfold run
  rw [step_pc0, ..., step_pc14]  -- All PCs
  rw [h_oracle]
  simp only [step_call_native_some]
  rfl
```

### D.3 Prove Main Composition Theorem

```lean
theorem rotation_eval_equiv_functional_sim :
    run env (rotationInitFrame args) cs ms =
      verifyRotationBytecodeResult oracle storeRef newPubkey proof := by
  unfold verifyRotationBytecodeResult
  cases h : oracle.verifyRotationProof storeRef newPubkey proof
  case none =>
    exact rotation_shape_verifyFailed oracle storeRef newPubkey proof cs ms h
  case some proof' =>
    exact rotation_shape_success oracle storeRef newPubkey proof' cs ms h
```

### D.4 Test Build

```bash
lake build MovementFormal.Experimental.ConfidentialAsset.Rotation.Phase6Composition
```

**Target:** < 1 minute.

### D.5 Milestone: D Complete

**Checklist:**
- ✅ `rotation_eval_equiv_functional_sim` proved (no `sorry`)
- ✅ Zero new axioms
- ✅ Builds in < 1 minute

**Commit:** `feat(ca): add rotation operation Lean Phase 6 composition`

---

## Phase E: Difftest Corpus

### E.1 Create Test Cases

**Location:** `examples/difftest/`

Create JSON test cases covering:
1. **Happy path** (rotation succeeds)
2. **Proof fails** (invalid rotation proof)
3. **Frozen account** (account is frozen, operation aborts)

**Example:**
```json
{
  "test_id": "rotation_happy_path_001",
  "operation": "rotate_encryption_key_internal",
  "inputs": {
    "owner_address": "0x123...",
    "old_pubkey": "0x456...",
    "new_pubkey": "0x789...",
    "rotation_proof": { ... }
  },
  "expected_output": {
    "status": "success",
    "new_pubkey": "0x789..."
  }
}
```

**Guide:** `DIFFTEST_HARNESS_GUIDE.md`

### E.2 Validate Test Cases

```bash
./scripts/manage_difftest_corpus.sh validate rotation
```

**Expected:** All test cases validate against the schema.

### E.3 Run Difftest

```bash
./scripts/manage_difftest_corpus.sh run rotation
```

**Expected:** All tests pass (VM output matches expected output).

### E.4 Milestone: E Complete

**Checklist:**
- ✅ ≥10 test cases (happy path + error paths)
- ✅ All test cases validate
- ✅ All test cases pass

**Commit:** `feat(ca): add rotation operation difftest corpus`

---

## Phase F: Integration Testing

### F.1 Run Full Verification Suite

```bash
./audit/verify-ca.sh --op rotation
```

**Expected output:**
```
=== Verifying operation: rotation ===

Lean verification... ✅ (build time: 3.2s)
MSL verification...  ✅ (0 VCs, 1.8s)
Difftest...          ✅ (12 tests passed)

Overall: ✅ PASS (5.0s)
```

If any stack fails, debug cross-stack inconsistency (see `ERROR_DIAGNOSIS_GUIDE.md`).

### F.2 Performance Benchmarking

```bash
./scripts/benchmark_verification.sh --operation rotation
```

**Budget check:**
- Lean EvalEquiv build: < 180s (per-file budget)
- MSL verification: < 60s
- Difftest: < 120s (all test cases)

### F.3 Axiom Audit

```bash
lake env lean --run scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Rotation.EvalEquiv
```

**Expected:** Only documented crypto axioms (Ristretto, Bulletproofs), zero temporary axioms.

### F.4 Milestone: F Complete

**Checklist:**
- ✅ All three stacks pass
- ✅ Performance within budget
- ✅ Zero unexpected axioms

**Commit:** `test(ca): rotation operation integration tests pass`

---

## Phase G: Documentation and Audit Package

### G.1 Update CLAIMS.md

**Location:** `audit/CLAIMS.md`

Add entries for the new operation:

```markdown
## rotate_encryption_key

**Lean proves:**
- `rotation_eval_equiv_functional_sim` — The `verify_rotation_proof` bytecode is semantically equivalent to the rotation verifier predicate.

**MSL proves:**
- `spec rotate_encryption_key_internal` — Encryption key is updated, balance sum is preserved, chunk count is preserved.

**Composition:**
The entry point `rotate_encryption_key` calls `verify_rotation_proof` (Lean-verified) followed by state updates (MSL-verified).

**Difftest validates:**
- 12 test cases covering happy path + error paths (frozen, proof failed).

**Command to verify:**
```
./audit/verify-ca.sh --op rotation
```
```

### G.2 Update TRUST_BOUNDARIES.md

If new axioms or `pragma opaque` declarations were added, document them:

```markdown
### Rotation Operation

**Lean axioms:**
- `ristretto_point_re_encrypt` — Re-encryption under a new key (crypto-opaque, difftest-validated)

**MSL pragmas:**
- `pragma opaque verify_rotation_proof` — Rotation proof verifier (external ZK proof system)
```

### G.3 Update Test Matrix

**Location:** `audit/TEST_MATRIX.md`

Add a row for rotation:

| Operation | Lean Theorems | MSL Specs | Difftest Cases | Status |
|---|---|---|---|---|
| Rotation | `rotation_eval_equiv_functional_sim`, `rotation_shape_success`, `rotation_shape_verifyFailed` | `spec rotate_encryption_key_internal` | 12 | ✅ |

### G.4 Write Worked Example (Optional)

If the operation is complex or introduces new patterns, write a worked example:

**Location:** `ROTATION_PROOF_WORKED_EXAMPLE.md`

Follow the structure of existing worked examples (Normalization, Withdrawal).

### G.5 Milestone: G Complete

**Checklist:**
- ✅ CLAIMS.md updated
- ✅ TRUST_BOUNDARIES.md updated
- ✅ TEST_MATRIX.md updated
- ✅ (Optional) Worked example written

**Commit:** `docs(ca): rotation operation audit package`

---

## Phase H: Review and Merge

### H.1 Self-Review Checklist

Before requesting review:

- [ ] All tests pass locally (Move, Lean, difftest)
- [ ] `./audit/verify-ca.sh --op rotation` exits 0
- [ ] No `sorry` in Lean proofs
- [ ] No unexpected axioms
- [ ] Performance within budget
- [ ] Code is well-commented
- [ ] Documentation updated (CLAIMS.md, TRUST_BOUNDARIES.md)
- [ ] Commit messages are descriptive

### H.2 Request Code Review

**Reviewers:**
1. **Move/MSL expert** — review Move implementation + MSL specs
2. **Lean expert** — review Lean proofs
3. **Security expert** — review for crypto vulnerabilities, abort condition completeness

**PR description template:**
```markdown
## Summary
Add rotation operation with full three-stack verification (Lean + MSL + Difftest).

## Changes
- Move implementation: `confidential_asset.move`
- MSL spec: `confidential_asset.spec.move`
- Lean EvalEquiv proof: `Rotation/EvalEquiv.lean`
- Lean Phase 6 composition: `Rotation/Phase6Composition.lean`
- Difftest corpus: 12 test cases

## Verification Status
- Lean: ✅ (3.2s build time, zero axioms)
- MSL: ✅ (0 VCs, 1.8s)
- Difftest: ✅ (12/12 tests pass)

## Review Focus
- Security: Are all abort conditions covered?
- Correctness: Does the MSL spec match the implementation?
- Performance: Is the Lean build time acceptable?

## Related Issues
Closes #123
```

### H.3 Address Review Comments

Iterate with reviewers until all concerns are addressed.

### H.4 Merge

Once approved:

```bash
git merge --no-ff rotation-operation
```

### H.5 Post-Merge

1. **Update progress tracker:**
   - Edit `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §0
   - Mark rotation as ✅ COMPLETE with commit SHA and metrics

2. **Announce:**
   - Post in `#formal-verification` Slack channel
   - "Rotation operation is now formally verified across all three stacks! 🎉"

---

## Summary

### Timeline

| Phase | Duration | Dependencies |
|---|---|---|
| A: Move implementation | 1-3 days | Design doc |
| B: MSL spec | 2-4 days | Phase A |
| C: Lean EvalEquiv | 5-10 days | Phase A |
| D: Lean composition | 3-5 days | Phase C |
| E: Difftest corpus | 2-3 days | Phase A |
| F: Integration testing | 1-2 days | B, C, D, E |
| G: Documentation | 2-3 days | Phase F |
| H: Review and merge | 3-7 days | Phase G |

**Total:** 2-4 weeks.

### Deliverables Checklist

By the end of Phase H, you should have:

- [ ] Move implementation + unit tests
- [ ] MSL spec (all VCs verified)
- [ ] Lean EvalEquiv proof (all PCs proved, zero sorry)
- [ ] Lean Phase 6 composition (eval ↔ functional sim)
- [ ] Difftest corpus (≥10 test cases)
- [ ] Integration test passing (all three stacks)
- [ ] Documentation updated (CLAIMS.md, TRUST_BOUNDARIES.md, TEST_MATRIX.md)
- [ ] Code reviewed and merged

### Resources

- **Guides:**
  - `PHASE_1_SINGLETON_SOME_BRANCH_GUIDE.md`
  - `PHASE_6_PC_CHAINING_IMPLEMENTATION_GUIDE.md`
  - `BYTECODE_TRANSCRIPTION_GUIDE.md`
  - `MSL_SPEC_PATTERN_LIBRARY.md`
  - `LEAN_PROOF_TACTICS_REFERENCE.md`
  - `INTEGRATION_TESTING_STRATEGY.md`
  - `ERROR_DIAGNOSIS_GUIDE.md`

- **Scripts:**
  - `./scripts/generate_test_template.sh`
  - `./scripts/manage_difftest_corpus.sh`
  - `./audit/verify-ca.sh`
  - `./scripts/profile_lean_build.sh`
  - `./scripts/check_axioms.sh`

- **Examples:**
  - Normalization (simplest)
  - Withdrawal (medium)
  - Transfer (most complex)

**Next steps:** Pick an operation to implement (or modify an existing one) and follow this workflow end-to-end!
