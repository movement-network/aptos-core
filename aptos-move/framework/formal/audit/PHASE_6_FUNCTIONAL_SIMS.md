# Phase 6 Functional Simulation Catalog

This document catalogs the functional simulations and shape lemmas added to Phase 4 EvalEquiv
files as part of Phase 6 composition work.

## Overview

Phase 4 delivered per-PC step theorems for all 4 crypto verifiers. Phase 6 connects these to
functional simulations — high-level specifications that abstract the 14/15/24-PC bytecode chains
into match expressions over oracle outcomes.

**Status as of 2026-04-22:**
- ✅ All 4 operations have functional simulation definitions
- ✅ All 4 operations have error-path shape lemmas proving oracle-failure correspondence
- ✅ 3 of 4 operations have happy-path success lemmas
- 🟡 Transfer happy-path deferred (3-call nested allocation complexity)
- 🟡 Top-level eval↔functional-sim equivalence theorems outstanding for all 4

## Normalization (14 PCs, 2 sub-calls)

**File:** `MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean`

**Added:**
- `NormalizationBytecodeResult` inductive (`.returned ms | .error`)
- `verifyNormalizationBytecodeResult` functional simulation definition
- `verifyNormalizationBytecodeResult_sigmaFails` — sigma verification fails → `.error`
- `verifyNormalizationBytecodeResult_rangeFails` — range verification fails → `.error`
- `verifyNormalizationBytecodeResult_success` — both succeed → `.returned { initMs with containers := cs4 }`

**Lines added:** ~67
**Build time:** ~0.6s

**Functional simulation structure:**
```lean
match o.verifySigmaProof cs1 sigmaArgs with
| none => .error
| some ([], cs2) =>
  match o.verifyRangeProof cs3 rangeArgs with
  | none => .error
  | some ([], cs4) => .returned { initMs with containers := cs4 }
  | some (_ :: _, _) => .error
| some (_ :: _, _) => .error
```

## Withdrawal (15 PCs, 2 sub-calls)

**File:** `MovementFormal/Experimental/ConfidentialAsset/Withdrawal/EvalEquiv.lean`

**Added:**
- `WithdrawalBytecodeResult` inductive
- `verifyWithdrawalBytecodeResult` functional simulation definition
- `verifyWithdrawalBytecodeResult_sigmaFails`
- `verifyWithdrawalBytecodeResult_rangeFails`
- `verifyWithdrawalBytecodeResult_success`

**Lines added:** ~107
**Build time:** ~0.57s

**Functional simulation structure:** Same 2-call pattern as Normalization, but with 8 params
(includes `amount: u64`) instead of 7.

## Rotation (15 PCs, 2 sub-calls)

**File:** `MovementFormal/Experimental/ConfidentialAsset/Rotation/EvalEquiv.lean`

**Added:**
- `RotationBytecodeResult` inductive
- `verifyRotationBytecodeResult` functional simulation definition
- `verifyRotationBytecodeResult_sigmaFails`
- `verifyRotationBytecodeResult_rangeFails`
- `verifyRotationBytecodeResult_success`

**Lines added:** ~105
**Build time:** ~0.58s

**Functional simulation structure:** Same 2-call pattern as Normalization, but sigma proof
takes both `current_ek` and `new_ek` (proving dual knowledge of secret key under key rotation).

## Transfer (24 PCs, 3 sub-calls)

**File:** `MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean`

**Added:**
- `TransferBytecodeResult` inductive
- `verifyTransferBytecodeResult` functional simulation definition
- `verifyTransferBytecodeResult_sigmaFails`
- `verifyTransferBytecodeResult_newBalanceRangeFails`
- `verifyTransferBytecodeResult_transferAmountRangeFails`
- Happy-path success lemma deferred (complex 3-call nested allocation chain)

**Lines added:** ~140
**Build time:** ~0.71s

**Functional simulation structure:** 3-call nested match:
```lean
match o.verifySigmaProof cs1 sigmaArgs with
| none => .error
| some ([], cs2) =>
  match o.verifyNewBalanceRangeProof cs3 newBalRangeArgs with
  | none => .error
  | some ([], cs4) =>
    match o.verifyTransferAmountRangeProof cs5 transferRangeArgs with
    | none => .error
    | some ([], cs6) => .returned { initMs with containers := cs6 }
    ...
```

Transfer is the most complex verifier with 13 params and 3 sub-calls (sigma + new balance
range + transfer amount range).

## Total Impact

- **Lines of Lean added:** ~420 lines across 4 files
- **Theorems added:** 13 shape lemmas (3 per operation except Transfer which has 4 error paths)
- **Build time impact:** +0.3s total (still well under 3-minute per-file budget)
- **Coverage:** All 4 Phase 4 operations now have functional simulations

## Reusability

These shape lemmas are building blocks for the full Phase 6 composition theorems. The pattern:

1. **Functional simulation:** high-level `def` matching oracle outcomes to `.returned` / `.error`
2. **Shape lemmas:** prove specific oracle-outcome branches evaluate to expected results
3. **Full composition (outstanding):** chain all 14/15/24 PCs via `run_succ_ok_of_step`,
   split on oracle outcomes, apply shape lemmas to close each branch

The Registration rebuild (`EvalEquivRebuild.lean`) demonstrates this pattern at scale:
197 theorems including 16 functional-sim shape reductions.

## Axiom Stubs Added (2026-04-22)

ALL 4 operations now have axiom stubs for the top-level composition theorem:
- `normalization_eval_equiv_functional_sim` (Normalization/EvalEquiv.lean:529)
- `withdrawal_eval_equiv_functional_sim` (Withdrawal/EvalEquiv.lean:462)
- `rotation_eval_equiv_functional_sim` (Rotation/EvalEquiv.lean:464)
- `transfer_eval_equiv_functional_sim` (Transfer/EvalEquiv.lean:688)

Each axiom stub states the full eval↔functional-sim equivalence, connecting
`(eval ... fuel initMs).dropMs` to the `match verifyXBytecodeResult ...` expression.

The Phase6Composition.lean files for all 4 operations have been updated to:
1. Reference the new axiom stubs in their descriptions
2. Show `*_is_formally_verified` axiom follows from `*_eval_equiv_functional_sim`
3. Provide `example` derivations demonstrating the connection

**Build status:** All files build cleanly (~1.6s for full CA Lean tree).

## Next Steps (Phase 6 Completion)

Prove the 4 axiom stubs by implementing the PC-chaining pattern:
1. Chain PCs 0–N using `run_succ_ok_of_step` pattern
2. Split on oracle outcomes (sigma fail / range fail / success for 2-call ops; add transfer
   amount range fail for Transfer's 3-call structure)
3. Apply the corresponding shape lemma to close each branch

Estimated effort per operation: 200–300 lines for Normalization/Withdrawal/Rotation (14-15 PCs,
2 oracle calls), 350-450 lines for Transfer (24 PCs, 3 oracle calls).

Pattern from Registration: Registration's `registration_run_through_pc1_some` and
`registration_run_through_pc2` theorems (lines 3360-3433 in EvalEquivRebuild.lean) demonstrate
the 2-PC and 3-PC chaining pattern. Extend this to 14/15/24 PCs using the same run_succ_ok_of_step
recursion.
