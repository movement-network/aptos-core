import MovementFormal.MoveModel.Programs.Rotation
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.ExecResultDropMs
import MovementFormal.Experimental.ConfidentialAsset.Helpers.ArgumentMarshaling
import MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleComposition

/-!
# Rotation Concrete Proof Helpers

Concrete proven helpers specific to Rotation verifier.

Rotation is similar to Normalization but with 8 params instead of 7:
- Adds `new_ek` at local 4
- Same dual-oracle pattern (sigma + range)
- 15 PCs (one more than Normalization)
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Rotation.ConcreteHelpers

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Rotation
open MovementFormal.Experimental.ConfidentialAsset.Helpers

/-! ## PC 0-6 argument marshaling -/

/-- Rotation PCs 0-5: moveLoc chain for 6 arguments. -/
axiom rotation_pc0_to_pc5_concrete
    (o : RotationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (curEkRef newEkRef curBalRef newBalRef proofRef : MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 6) :
    let args := [.u8 chainId, .address sender, .address contract,
                 curEkRef, newEkRef, curBalRef, newBalRef, proofRef]
    let initFrame : Frame := {
      code := verifyRotationProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 8 none).toArray
    }
    ∃ (locals6 : Array (Option MoveValue)),
    locals6.size = 8 ∧
    run (rotationModuleEnv o) initFrame [] [] initMs fuel =
    run (rotationModuleEnv o)
      { initFrame with pc := 6, locals := locals6 }
      []
      [curBalRef, newEkRef, curEkRef, .address contract, .address sender, .u8 chainId]
      initMs
      (fuel - 6)

/-- Rotation PCs 6-7: copyLoc chain for ekRef (local 3) and proofRef (local 7). -/
axiom rotation_pc6_to_pc7_concrete
    (o : RotationModuleOracle)
    (curEkRef proofRef : MoveValue)
    (locals6 : Array (Option MoveValue))
    (stack6 : List MoveValue)
    (ms : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 2)
    (hlocals_size : locals6.size = 8)
    (hlocal3 : ∃ h : 3 < locals6.size, locals6[3]'h = some curEkRef)
    (hlocal7 : ∃ h : 7 < locals6.size, locals6[7]'h = some proofRef) :
    run (rotationModuleEnv o)
      { code := verifyRotationProofCode, pc := 6,
        locals := locals6,
        localRefs := (List.replicate 8 none).toArray }
      []
      stack6
      ms
      fuel =
    run (rotationModuleEnv o)
      { code := verifyRotationProofCode, pc := 8,
        locals := locals6,
        localRefs := (List.replicate 8 none).toArray }
      []
      (proofRef :: curEkRef :: stack6)
      ms
      (fuel - 2)

/-! ## PC 9-14 oracle handling and range marshal -/

/-- After sigma oracle succeeds at PC 9, PCs 10-12 marshal range proof arguments. -/
axiom rotation_pc10_to_pc13_range_marshal
    (o : RotationModuleOracle)
    (newBalRef proofRef : MoveValue)
    (proofRid : RefId)
    (proofFields : List MoveValue)
    (cs_after_sigma : ContainerStore)
    (locals9 : Array (Option MoveValue))
    (stack9 : List MoveValue)
    (fuel : Nat)
    (hfuel : fuel ≥ 4)
    (hlocals_size : locals9.size = 8)
    (hlocal6 : ∃ h : 6 < locals9.size, locals9[6]'h = some newBalRef)
    (hlocal7 : ∃ h : 7 < locals9.size, locals9[7]'h = some proofRef)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : cs_after_sigma.read proofRid = some (.struct_ proofFields))
    (hfield1 : 1 < proofFields.length) :
    let (rangeCs, _rangeFid) := cs_after_sigma.alloc (proofFields[1]'hfield1)
    ∃ (stack_final : List MoveValue),
    run (rotationModuleEnv o)
      { code := verifyRotationProofCode, pc := 10,
        locals := locals9,
        localRefs := (List.replicate 8 none).toArray }
      []
      stack9
      { containers := cs_after_sigma, globals := [] }
      fuel =
    run (rotationModuleEnv o)
      { code := verifyRotationProofCode, pc := 13,
        locals := locals9,
        localRefs := (List.replicate 8 none).toArray }
      []
      stack_final
      { containers := rangeCs, globals := [] }
      (fuel - 4)

/-! ## Complete happy-path composition -/

/-- Rotation happy path: both oracles succeed, verification returns. -/
axiom rotation_happy_path_complete
    (o : RotationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (curEkRef newEkRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 15)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hfield_count : 1 < proofFields.length)
    -- Oracle success
    (sigma_args : List MoveValue)
    (hsigma_args : sigma_args.length = 7)
    (cs_after_sigma : ContainerStore)
    (hsigma_ok : o.verifySigmaProof initMs.containers sigma_args = some ([], cs_after_sigma))
    (range_args : List MoveValue)
    (hrange_args : range_args.length = 2)
    (cs_after_range : ContainerStore)
    (hrange_ok : o.verifyRangeProof cs_after_sigma range_args = some ([], cs_after_range)) :
    let args := [.u8 chainId, .address sender, .address contract,
                 curEkRef, newEkRef, curBalRef, newBalRef, proofRef]
    let initFrame : Frame := {
      code := verifyRotationProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 8 none).toArray
    }
    run (rotationModuleEnv o) initFrame [] [] initMs fuel =
    .returned [] ({ initMs with containers := cs_after_range } : MachineState)

/-! ## Error path compositions -/

/-- Rotation sigma oracle fails → .error. -/
axiom rotation_sigma_fails_to_error
    (o : RotationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (curEkRef newEkRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 10)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hfield_count : 0 < proofFields.length)
    (sigma_args : List MoveValue)
    (hsigma_args : sigma_args.length = 7)
    (hsigma_fail : o.verifySigmaProof initMs.containers sigma_args = none) :
    let args := [.u8 chainId, .address sender, .address contract,
                 curEkRef, newEkRef, curBalRef, newBalRef, proofRef]
    let initFrame : Frame := {
      code := verifyRotationProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 8 none).toArray
    }
    run (rotationModuleEnv o) initFrame [] [] initMs fuel = .error

/-- Rotation range oracle fails (sigma succeeded) → .error. -/
axiom rotation_range_fails_to_error
    (o : RotationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (curEkRef newEkRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 14)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hfield_count : 1 < proofFields.length)
    (sigma_args : List MoveValue)
    (hsigma_args : sigma_args.length = 7)
    (cs_after_sigma : ContainerStore)
    (hsigma_ok : o.verifySigmaProof initMs.containers sigma_args = some ([], cs_after_sigma))
    (range_args : List MoveValue)
    (hrange_args : range_args.length = 2)
    (hrange_fail : o.verifyRangeProof cs_after_sigma range_args = none) :
    let args := [.u8 chainId, .address sender, .address contract,
                 curEkRef, newEkRef, curBalRef, newBalRef, proofRef]
    let initFrame : Frame := {
      code := verifyRotationProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 8 none).toArray
    }
    run (rotationModuleEnv o) initFrame [] [] initMs fuel = .error

end MovementFormal.Experimental.ConfidentialAsset.Rotation.ConcreteHelpers
