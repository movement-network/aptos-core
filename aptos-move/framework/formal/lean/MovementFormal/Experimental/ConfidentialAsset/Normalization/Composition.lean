import MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv

namespace MovementFormal.Experimental.ConfidentialAsset.Normalization.Composition

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Normalization  
open MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv
open MovementFormal.MoveModel.StepLemmas

/-! ## Simple error-path composition: sigma proof fails at PC 8

When the sigma verifier returns none, the bytecode aborts at PC 8.
This is a short composition: PCs 0-7 build arguments, PC 8 calls and fails. -/

theorem normalization_eval_error_sigmaFails
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (fuel : Nat) (hfuel : 8 ≤ fuel)
    (proofRid : RefId) (proofFields : List MoveValue)
    (hProofRef : getRefId proofRef = some proofRid)
    (hProofRead : MachineState.empty.containers.read proofRid =
                   some (.struct_ proofFields))
    (hFieldCount : 1 < proofFields.length)
    -- Critical: sigma verifier returns none
    (hSigmaFail : ∀ cs args, o.verifySigmaProof cs args = none) :
    (eval (normalizationModuleEnv o) verifyNormalizationProofIdx
        (normalizationArgs chainId sender contract ekRef curBalRef newBalRef proofRef)
        fuel MachineState.empty).dropMs = .error := by
  -- ATTEMPT 3 (2026-04-23): Simplified approach - avoid free variables entirely
  -- Use term-mode witness construction instead of tactic-mode destructuring

  rw [eval_normalization_eq_run]

  -- PC 0 → PC 5: Use helper axiom
  obtain ⟨locals5, h0to5⟩ := norm_run_pc0_to_pc5 o chainId sender contract ekRef curBalRef newBalRef proofRef
    MachineState.empty fuel (by omega : fuel ≥ 5)
  rw [h0to5]

  -- PC 5 → PC 8: Use helper theorem (has sorry at line 624)
  have h5to8 := norm_run_pc5_to_pc8 o chainId sender contract ekRef curBalRef newBalRef proofRef
    proofRid proofFields MachineState.empty locals5 hFieldCount hProofRead hProofRef
    (fuel - 5) (by omega : fuel - 5 ≥ 3)
  rw [h5to8]

  -- At PC 8: Need to show run produces .error
  -- This requires applying step_normalization_pc8_none, which needs:
  -- 1. Stack with 7 elements for takeN
  -- 2. Oracle call that returns none
  -- 3. Proper frame at PC 8

  -- The stack from h5to8 is:
  -- [.immRef sigmaFid, proofRef, newBalRef, curBalRef, ekRef, .address contract, .address sender, .u8 chainId]
  -- where (sigmaCs, sigmaFid) = MachineState.empty.containers.alloc (proofFields[0]'...)

  -- BLOCKER: Cannot construct this without let-destructuring, which creates free variables
  -- Even with `let alloc_result := ...`, using alloc_result.fst/snd in dependent contexts
  -- triggers the same free variable issue

  -- This approach also hits the blocker. Needs architectural change.
  sorry

end MovementFormal.Experimental.ConfidentialAsset.Normalization.Composition
