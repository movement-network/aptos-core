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
  sorry

end MovementFormal.Experimental.ConfidentialAsset.Normalization.Composition
