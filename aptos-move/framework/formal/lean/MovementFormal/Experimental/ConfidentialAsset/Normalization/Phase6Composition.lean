import MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv

/-!
# Phase 6 composition scaffold — `normalize` is formally verified

Phase 4 Lean work has landed: `Normalization/EvalEquiv.lean` contains:
- `eval_normalization_eq_run` — entry-point unfolding reducing `eval` to `run`
- 14 per-PC step theorems (`step_normalization_pc{0..13}`)
- 2 error-path variants (`pc8_none`, `pc12_none`)
- `verifyNormalizationBytecodeResult` — functional simulation definition
- 3 shape lemmas (sigmaFails, rangeFails, success)

**Outstanding (Phase 6 proper):** the top-level equivalence theorem
`normalization_eval_equiv_functional_sim` connecting `eval` to `verifyNormalizationBytecodeResult`
via a 14-step composition chain. Currently an axiom stub in EvalEquiv.lean; proof requires ~250
lines chaining PCs with run_succ_ok_of_step and splitting on oracle outcomes.
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
   point. `normalization_eval_equiv_functional_sim` (axiom stub, to be proved) connects eval
   to the functional simulation.

3. **Difftest** (VM↔Lean): corpus rows bind VM output byte-for-byte.

The axiom `normalization_eval_equiv_functional_sim` in EvalEquiv.lean is the Phase 6 gap. -/
axiom normalize_is_formally_verified :
    ∀ (o : NormalizationModuleOracle)
      (chainId : UInt8) (sender contract : ByteArray)
      (ekRef curBalRef newBalRef proofRef : MoveValue)
      (proofRid : RefId) (proofFields : List MoveValue)
      (initMs : MachineState)
      (hFieldCount : 1 < proofFields.length)
      (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
      (hproofRef : getRefId proofRef = some proofRid)
      (fuel : Nat)
      (hfuel : fuel ≥ 14),
      let args := [.u8 chainId, .address sender, .address contract,
                   ekRef, curBalRef, newBalRef, proofRef]
      (eval (normalizationModuleEnv o) verifyNormalizationProofIdx args fuel initMs).dropMs =
      match verifyNormalizationBytecodeResult o chainId sender contract ekRef curBalRef newBalRef
              proofRid proofFields initMs hFieldCount with
      | .returned ms => .returned [] ms
      | .error => .error

/-- Derivation: `normalize_is_formally_verified` follows directly from
    `normalization_eval_equiv_functional_sim` (the axiom stub in EvalEquiv.lean).
    When that axiom is proved, this example will be a proper derivation. -/
example (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (fuel : Nat)
    (hfuel : fuel ≥ 14) :
    let args := [.u8 chainId, .address sender, .address contract,
                 ekRef, curBalRef, newBalRef, proofRef]
    (eval (normalizationModuleEnv o) verifyNormalizationProofIdx args fuel initMs).dropMs =
    match verifyNormalizationBytecodeResult o chainId sender contract ekRef curBalRef newBalRef
            proofRid proofFields initMs hFieldCount with
    | .returned ms => .returned [] ms
    | .error => .error :=
  normalization_eval_equiv_functional_sim o chainId sender contract ekRef curBalRef newBalRef
    proofRef proofRid proofFields initMs hFieldCount hread hproofRef fuel hfuel

end MovementFormal.Experimental.ConfidentialAsset.Normalization.Phase6Composition
