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
  -- Strategy: This proof is blocked by the array elaboration issue.
  -- The structure is clear: chain PCs 0→5→8 using the helper axioms,
  -- then apply step_normalization_pc8_none at PC 8 to get .error.
  -- However, the intermediate `have (sigmaCs, sigmaFid) := ...` binding
  -- introduces free variables that Lean's elaborator rejects.
  --
  -- This is the same "Expected type must not contain free variables" blocker
  -- documented in norm_run_pc0_to_pc5. Completion requires either:
  -- 1. Term-mode witness construction
  -- 2. Alternative proof architecture that avoids array indexing in theorem statements
  -- 3. Deep Lean 4 elaborator workarounds
  --
  -- Estimated effort: 40-60 lines once elaboration blocker is solved.
  sorry

end MovementFormal.Experimental.ConfidentialAsset.Normalization.Composition
