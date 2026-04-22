# Phase 6 Composition Proof Progress Summary

## Date: 2026-04-22

## Overview

Major progress on Phase 6 composition theorems and MSL spec strengthening. All 4 Phase 4 verifier operations now have structured composition theorem scaffolding in place.

## 1. Lean Composition Theorems (Phase 6)

### Work Completed

Converted 4 axiom stubs to theorems with structured proof scaffolding:

#### Normalization (14 PCs)
- **File**: `MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean`
- **Theorem**: `normalization_eval_equiv_functional_sim`
- **Structure**: 
  - Entry point unfolding via `eval_normalization_eq_run`
  - TODO: Chain PCs 0-13 using `run_succ_ok_of_step`
  - Oracle splits at PC 8 (sigma) and PC 12 (range)
  - Shape lemmas: `sigmaFails`, `rangeFails`, `success`
- **Status**: Builds with sorry placeholder (~540 lines total)

#### Withdrawal (15 PCs)
- **File**: `MovementFormal/Experimental/ConfidentialAsset/Withdrawal/EvalEquiv.lean`
- **Theorem**: `withdrawal_eval_equiv_functional_sim`
- **Structure**:
  - Entry point unfolding via `eval_withdrawal_eq_run`
  - TODO: Chain PCs 0-14
  - Oracle splits at PC 9 (sigma) and PC 13 (range)
  - Shape lemmas: `sigmaFails`, `rangeFails`, `success`
- **Status**: Builds with sorry placeholder

#### Rotation (15 PCs)
- **File**: `MovementFormal/Experimental/ConfidentialAsset/Rotation/EvalEquiv.lean`
- **Theorem**: `rotation_eval_equiv_functional_sim`
- **Structure**:
  - Entry point unfolding via `eval_rotation_eq_run`
  - TODO: Chain PCs 0-14
  - Oracle splits at PC 10 (sigma) and PC 13 (range)
  - Shape lemmas: `sigmaFails`, `rangeFails`, `success`
- **Status**: Builds with sorry placeholder

#### Transfer (24 PCs - Most Complex)
- **File**: `MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean`
- **Theorem**: `transfer_eval_equiv_functional_sim`
- **Structure**:
  - Entry point unfolding via `eval_transfer_eq_run`
  - TODO: Chain PCs 0-23
  - Oracle splits at PC 14 (sigma), PC 18 (new balance range), PC 22 (transfer amount range)
  - Shape lemmas: `sigmaFails`, `newBalanceRangeFails`, `transferAmountRangeFails`
- **Status**: Builds with sorry placeholder (~730 lines total)

### Build Status
```bash
$ lake build
Build completed successfully (1886 jobs).
```

All 4 theorems compile with 4 sorry warnings (expected).

### Remaining Work (Per Operation)

Each composition proof requires ~200-400 lines to complete:

1. **PC chaining**: Apply step theorems sequentially using `run_succ_ok_of_step`
2. **Frame construction**: Build frame state after each PC with explicit locals/localRefs arrays
3. **Oracle splitting**: Match on oracle outcomes at call PCs, branch on success/failure
4. **Shape lemma application**: Connect bytecode result to functional simulation via shape lemmas
5. **Arithmetic reasoning**: Omega tactics for fuel decomposition and array bounds

**Estimated effort**: 3-5 days per operation for careful PC-by-PC proof construction.

## 2. MSL Spec Strengthening (Phase 2/3)

### Balance Length Preservation Postconditions

Added 12 new `ensures` clauses to strengthen balance invariants:

#### deposit_to_internal
```move
ensures len(global<ConfidentialAssetStore>(recipient_store).pending_balance.chunks)
    == len(old(global<ConfidentialAssetStore>(recipient_store)).pending_balance.chunks);
ensures len(global<ConfidentialAssetStore>(recipient_store).actual_balance.chunks)
    == len(old(global<ConfidentialAssetStore>(recipient_store)).actual_balance.chunks);
```

#### withdraw_to_internal
```move
ensures len(global<ConfidentialAssetStore>(sender_store).pending_balance.chunks)
    == len(old(global<ConfidentialAssetStore>(sender_store)).pending_balance.chunks);
ensures len(global<ConfidentialAssetStore>(sender_store).actual_balance.chunks)
    == len(old(global<ConfidentialAssetStore>(sender_store)).actual_balance.chunks);
```

#### rotate_encryption_key_internal
```move
ensures len(global<ConfidentialAssetStore>(store_addr).pending_balance.chunks)
    == len(old(global<ConfidentialAssetStore>(store_addr)).pending_balance.chunks);
ensures len(global<ConfidentialAssetStore>(store_addr).actual_balance.chunks)
    == len(old(global<ConfidentialAssetStore>(store_addr)).actual_balance.chunks);
```

#### normalize_internal
```move
ensures len(global<ConfidentialAssetStore>(store_addr).pending_balance.chunks)
    == len(old(global<ConfidentialAssetStore>(store_addr)).pending_balance.chunks);
ensures len(global<ConfidentialAssetStore>(store_addr).actual_balance.chunks)
    == len(old(global<ConfidentialAssetStore>(store_addr)).actual_balance.chunks);
```

#### confidential_transfer_internal (Sender & Recipient)
```move
ensures len(global<ConfidentialAssetStore>(sender_store).pending_balance.chunks)
    == len(old(global<ConfidentialAssetStore>(sender_store)).pending_balance.chunks);
ensures len(global<ConfidentialAssetStore>(sender_store).actual_balance.chunks)
    == len(old(global<ConfidentialAssetStore>(sender_store)).actual_balance.chunks);
ensures len(global<ConfidentialAssetStore>(recipient_store).pending_balance.chunks)
    == len(old(global<ConfidentialAssetStore>(recipient_store)).pending_balance.chunks);
ensures len(global<ConfidentialAssetStore>(recipient_store).actual_balance.chunks)
    == len(old(global<ConfidentialAssetStore>(recipient_store)).actual_balance.chunks);
```

### Rationale

These postconditions strengthen the MSL specs by ensuring that homomorphic operations (add, subtract, re-encrypt) preserve balance chunk structure:
- Pending balances always have 4 chunks
- Actual balances always have 8 chunks
- Operations never corrupt or reallocate balance vectors

This complements the existing length invariants in `confidential_balance.spec.move` by pinning preservation at the operation level.

## 3. Next Steps

### Immediate (Phase 6 Completion)
1. Complete `normalization_eval_equiv_functional_sim` proof (smallest, 14 PCs)
2. Use Normalization as template for Withdrawal/Rotation (similar 15-PC structure)
3. Complete Transfer last (most complex, 24 PCs with 3 oracle calls)

### Short-term (Phase 7 Audit Package)
4. Update `audit/BYTECODE_VERIFICATION_COVERAGE.md` with Phase 6 progress
5. Update `audit/MSL_SPEC_COVERAGE.md` with new balance length postconditions
6. Update `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` Phase 6 status row

### Medium-term (Phase 1 Registration)
7. Complete singleton-some branch container-store threading
8. Remove final `sorry` from Registration EvalEquivRebuild.lean

## Summary

**Total lines added**: ~400 lines of Lean theorem scaffolding + 12 MSL postcondition clauses

**Build status**: ✅ All code compiles successfully
- Lean tree: 1886 jobs, 0 errors (4 expected sorry warnings)
- MSL specs: Enhanced with balance length preservation invariants

**Verification coverage increase**:
- Phase 6: 0 → 4 theorem scaffolds with clear roadmap for completion
- Phase 2/3: 5 operations strengthened with 12 new balance structure postconditions

**Estimated completion time for Phase 6**: 2-3 weeks for full PC-chaining proofs across all 4 operations.
