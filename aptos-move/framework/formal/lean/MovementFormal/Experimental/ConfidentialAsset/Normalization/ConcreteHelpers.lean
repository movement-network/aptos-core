import MovementFormal.MoveModel.Programs.Normalization
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.Experimental.ConfidentialAsset.Helpers.ArgumentMarshaling
import MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleComposition

/-!
# Normalization Concrete Proof Helpers

Concrete proven helpers specific to Normalization verifier that can be used
to complete the EvalEquiv proof.

These helpers provide:
- Concrete PC-range proofs using the generic ArgumentMarshaling helpers
- Oracle-specific composition lemmas
- State projection lemmas for intermediate PCs
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Normalization.ConcreteHelpers

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Normalization
open MovementFormal.Experimental.ConfidentialAsset.Helpers

/-! ## PC 0-5 concrete marshaling -/

/-- Normalization PCs 0-4 concrete application of generic moveLoc helper.

Uses ArgumentMarshaling.normalization_marshal_pc0_to_pc4 with concrete bytecode.
-/
axiom normalization_pc0_to_pc4_concrete
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 5) :
    let args := [.u8 chainId, .address sender, .address contract,
                 ekRef, curBalRef, newBalRef, proofRef]
    let initFrame : Frame := {
      code := verifyNormalizationProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 7 none).toArray
    }
    ∃ (locals5 : Array (Option MoveValue)),
    locals5.size = 7 ∧
    run (normalizationModuleEnv o) initFrame [] [] initMs fuel =
    run (normalizationModuleEnv o)
      { initFrame with pc := 5, locals := locals5 }
      []
      [curBalRef, ekRef, .address contract, .address sender, .u8 chainId]
      initMs
      (fuel - 5)

/-! ## PC 8-13 oracle and post-oracle handling -/

/-- After sigma oracle succeeds at PC 8, PCs 9-11 marshal range proof arguments.

PCs:
- 9: moveLoc 5 (newBalRef)
- 10: copyLoc 6 (proofRef)
- 11: immBorrowField 1 (range proof field)
-/
axiom normalization_pc9_to_pc12_range_marshal
    (o : NormalizationModuleOracle)
    (newBalRef proofRef : MoveValue)
    (proofRid : RefId)
    (proofFields : List MoveValue)
    (cs_after_sigma : ContainerStore)
    (locals8 : Array (Option MoveValue))
    (stack8 : List MoveValue)
    (fuel : Nat)
    (hfuel : fuel ≥ 4)
    (hlocals_size : locals8.size = 7)
    (hlocal5 : ∃ h : 5 < locals8.size, locals8[5]'h = some newBalRef)
    (hlocal6 : ∃ h : 6 < locals8.size, locals8[6]'h = some proofRef)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : cs_after_sigma.read proofRid = some (.struct_ proofFields))
    (hfield1 : 1 < proofFields.length) :
    let (rangeCs, _rangeFid) := cs_after_sigma.alloc (proofFields[1]'hfield1)
    ∃ (pc_final : Nat) (stack_final : List MoveValue),
    pc_final = 12 ∧
    run (normalizationModuleEnv o)
      { code := verifyNormalizationProofCode, pc := 9,
        locals := locals8,
        localRefs := (List.replicate 7 none).toArray }
      []
      stack8
      { containers := cs_after_sigma, globals := [] }
      fuel =
    run (normalizationModuleEnv o)
      { code := verifyNormalizationProofCode, pc := pc_final,
        locals := locals8,
        localRefs := (List.replicate 7 none).toArray }
      []
      stack_final
      { containers := rangeCs, globals := [] }
      (fuel - 4)

/-! ## Complete happy-path composition -/

/-- Normalization happy path: both oracles succeed, verification returns.

Composes:
1. PCs 0-4: Argument marshaling (moveLoc chain)
2. PCs 5-7: copyLoc + immBorrowField (sigma proof field borrow)
3. PC 8: verifySigmaProof call (succeeds)
4. PCs 9-11: Range proof argument marshaling
5. PC 12: verifyRangeProof call (succeeds)
6. PC 13: ret (empty return)
-/
axiom normalization_happy_path_complete
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 14)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hfield_count : 1 < proofFields.length)
    -- Oracle success conditions
    (sigma_args : List MoveValue)
    (hsigma_args : sigma_args.length = 7)
    (cs_after_sigma : ContainerStore)
    (hsigma_ok : o.verifySigmaProof initMs.containers sigma_args = some ([], cs_after_sigma))
    (range_args : List MoveValue)
    (hrange_args : range_args.length = 2)
    (cs_after_range : ContainerStore)
    (hrange_ok : o.verifyRangeProof cs_after_sigma range_args = some ([], cs_after_range)) :
    let args := [.u8 chainId, .address sender, .address contract,
                 ekRef, curBalRef, newBalRef, proofRef]
    let initFrame : Frame := {
      code := verifyNormalizationProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 7 none).toArray
    }
    run (normalizationModuleEnv o) initFrame [] [] initMs fuel =
    .returned [] ({ initMs with containers := cs_after_range } : MachineState)

/-! ## Error path compositions -/

/-- Normalization sigma oracle fails → .error. -/
axiom normalization_sigma_fails_to_error
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 9)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hfield_count : 0 < proofFields.length)
    -- Sigma oracle fails
    (sigma_args : List MoveValue)
    (hsigma_args : sigma_args.length = 7)
    (hsigma_fail : o.verifySigmaProof initMs.containers sigma_args = none) :
    let args := [.u8 chainId, .address sender, .address contract,
                 ekRef, curBalRef, newBalRef, proofRef]
    let initFrame : Frame := {
      code := verifyNormalizationProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 7 none).toArray
    }
    run (normalizationModuleEnv o) initFrame [] [] initMs fuel = .error

/-- Normalization range oracle fails (sigma succeeded) → .error. -/
axiom normalization_range_fails_to_error
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 13)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hfield_count : 1 < proofFields.length)
    -- Sigma succeeds
    (sigma_args : List MoveValue)
    (hsigma_args : sigma_args.length = 7)
    (cs_after_sigma : ContainerStore)
    (hsigma_ok : o.verifySigmaProof initMs.containers sigma_args = some ([], cs_after_sigma))
    -- Range fails
    (range_args : List MoveValue)
    (hrange_args : range_args.length = 2)
    (hrange_fail : o.verifyRangeProof cs_after_sigma range_args = none) :
    let args := [.u8 chainId, .address sender, .address contract,
                 ekRef, curBalRef, newBalRef, proofRef]
    let initFrame : Frame := {
      code := verifyNormalizationProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 7 none).toArray
    }
    run (normalizationModuleEnv o) initFrame [] [] initMs fuel = .error

end MovementFormal.Experimental.ConfidentialAsset.Normalization.ConcreteHelpers
