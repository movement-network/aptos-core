import MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv

/-!
# Phase 6 composition scaffold — `normalize` is formally verified

Phase 4 Lean work has landed: `Normalization/EvalEquiv.lean` contains:
- `eval_normalization_eq_run` — entry-point unfolding reducing `eval` to `run`
- 14 per-PC step theorems (`step_normalization_pc{0..13}`)
- 2 error-path variants (`pc8_none`, `pc12_none`)
- `verifyNormalizationBytecodeResult` — functional simulation definition

**Outstanding (Phase 6 proper):** the top-level equivalence theorem connecting
`eval` to `verifyNormalizationBytecodeResult` via a 14-step composition chain
threading the `immBorrowField` container-store allocs.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Normalization.Phase6Composition

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Normalization
open MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv

/-- `normalize` is formally verified means, under the unified verification plan:

1. **Move Prover** (source level, `confidential_asset.spec.move`): `spec normalize_internal` +
   `spec normalize` pin the post-state (`normalized = true`, `actual_balance = new_balance`,
   abort if already normalized).

2. **Lean** (bytecode level, `Normalization/EvalEquiv.lean`): the 14 per-PC step theorems
   (`step_normalization_pc{0..13}`) prove that each instruction of `verify_normalization_proof`
   reduces to the expected step-level behavior. `eval_normalization_eq_run` unrolls the entry
   point. Together these comprise the bytecode-level Phase 4 proof.

3. **Difftest** (VM↔Lean): corpus rows bind VM output byte-for-byte.

The top-level equivalence `eval ... = verifyNormalizationBytecodeResult ...` is the Phase 6
composition target; the per-PC building blocks are in place. -/
axiom normalize_is_formally_verified :
    ∀ (o : NormalizationModuleOracle)
      (chainId : UInt8) (sender contract : ByteArray)
      (ekRef curBalRef newBalRef proofRef : MoveValue)
      (fuel : Nat) (initMs : MachineState),
      ∃ result,
        (eval (normalizationModuleEnv o) verifyNormalizationProofIdx
            [.u8 chainId, .address sender, .address contract,
             ekRef, curBalRef, newBalRef, proofRef]
            fuel initMs).dropMs = result

/-- Derivation: `eval_normalization_eq_run` proves the entry-point unfolding (PC 0 start).
    Per-PC step theorems cover all 14 instructions. -/
example (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (fuel : Nat) (initMs : MachineState) :
    eval (normalizationModuleEnv o) verifyNormalizationProofIdx
        [.u8 chainId, .address sender, .address contract,
         ekRef, curBalRef, newBalRef, proofRef]
        fuel initMs =
    run (normalizationModuleEnv o)
        { code := verifyNormalizationProofCode,
          pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      ekRef, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 7 none).toArray }
        [] [] initMs fuel :=
  eval_normalization_eq_run o [.u8 chainId, .address sender, .address contract,
                                ekRef, curBalRef, newBalRef, proofRef] fuel initMs

end MovementFormal.Experimental.ConfidentialAsset.Normalization.Phase6Composition
