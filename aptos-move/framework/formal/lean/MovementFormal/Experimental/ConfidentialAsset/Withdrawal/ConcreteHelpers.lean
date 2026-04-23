import MovementFormal.MoveModel.Programs.Withdrawal
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.Experimental.ConfidentialAsset.Helpers.ArgumentMarshaling
import MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleComposition

/-!
# Withdrawal Concrete Proof Helpers

Concrete helpers for Withdrawal verifier proofs.

Withdrawal has 7 params but one is `amount: u64` (not a ref).
Follows dual-oracle pattern (sigma + range) like Normalization/Rotation.
15 PCs total.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Withdrawal.ConcreteHelpers

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Withdrawal
open MovementFormal.Experimental.ConfidentialAsset.Helpers

/-! ## Entry point args -/

def withdrawalArgs (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef : MoveValue) (amount : UInt64) (proofRef : MoveValue) : List MoveValue :=
  [.u8 chainId, .address sender, .address contract,
   ekRef, curBalRef, .u64 amount, proofRef]

/-! ## PC 0-6 argument marshaling -/

/-- Withdrawal PCs 0-5: moveLoc chain for 6 arguments.

Unlike Normalization/Rotation which moveLoc 5 args, Withdrawal moveLocs 6
because `amount` is a value (u64) not a ref.
-/
axiom withdrawal_pc0_to_pc5_concrete
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef : MoveValue)
    (amount : UInt64)
    (proofRef : MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 6) :
    let args := withdrawalArgs chainId sender contract ekRef curBalRef amount proofRef
    let initFrame : Frame := {
      code := verifyWithdrawalProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 7 none).toArray
    }
    ∃ (locals6 : Array (Option MoveValue)),
    locals6.size = 7 ∧
    run (withdrawalModuleEnv o) initFrame [] [] initMs fuel =
    run (withdrawalModuleEnv o)
      { initFrame with pc := 6, locals := locals6 }
      []
      [proofRef, .u64 amount, curBalRef, ekRef, .address contract, .address sender, .u8 chainId]
      initMs
      (fuel - 6)

/-- Withdrawal PCs 6-7: copyLoc chain for curBalRef and proofRef. -/
axiom withdrawal_pc6_to_pc7_concrete
    (o : WithdrawalModuleOracle)
    (curBalRef proofRef : MoveValue)
    (locals6 : Array (Option MoveValue))
    (stack6 : List MoveValue)
    (ms : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 2)
    (hlocals_size : locals6.size = 7)
    (hlocal4 : ∃ h : 4 < locals6.size, locals6[4]'h = some curBalRef)
    (hlocal6 : ∃ h : 6 < locals6.size, locals6[6]'h = some proofRef) :
    run (withdrawalModuleEnv o)
      { code := verifyWithdrawalProofCode, pc := 6,
        locals := locals6,
        localRefs := (List.replicate 7 none).toArray }
      []
      stack6
      ms
      fuel =
    run (withdrawalModuleEnv o)
      { code := verifyWithdrawalProofCode, pc := 8,
        locals := locals6,
        localRefs := (List.replicate 7 none).toArray }
      []
      (proofRef :: curBalRef :: stack6)
      ms
      (fuel - 2)

/-! ## PC 8 field borrow -/

/-- Withdrawal PC 8: immBorrowField 0 to get sigma proof field from proof struct. -/
axiom withdrawal_pc8_immBorrowField_sigma
    (o : WithdrawalModuleOracle)
    (proofRef : MoveValue)
    (proofRid : RefId)
    (proofFields : List MoveValue)
    (locals8 : Array (Option MoveValue))
    (stack8 : List MoveValue)
    (ms : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 1)
    (hstack_top : stack8.head? = some proofRef)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : ms.containers.read proofRid = some (.struct_ proofFields))
    (hfield0 : 0 < proofFields.length) :
    let (sigmaCs, sigmaFid) := ms.containers.alloc (proofFields[0]'hfield0)
    run (withdrawalModuleEnv o)
      { code := verifyWithdrawalProofCode, pc := 8,
        locals := locals8,
        localRefs := (List.replicate 7 none).toArray }
      []
      stack8
      ms
      fuel =
    run (withdrawalModuleEnv o)
      { code := verifyWithdrawalProofCode, pc := 9,
        locals := locals8,
        localRefs := (List.replicate 7 none).toArray }
      []
      (.immRef sigmaFid :: stack8.tail)
      { ms with containers := sigmaCs }
      (fuel - 1)

/-! ## PC 9-13 oracle and range marshal -/

/-- After sigma oracle succeeds at PC 9, PCs 10-12 marshal range proof arguments.

PCs:
- 10: moveLoc 4 (curBalRef)
- 11: copyLoc 6 (proofRef)
- 12: immBorrowField 1 (range proof field)
-/
axiom withdrawal_pc10_to_pc13_range_marshal
    (o : WithdrawalModuleOracle)
    (curBalRef proofRef : MoveValue)
    (proofRid : RefId)
    (proofFields : List MoveValue)
    (cs_after_sigma : ContainerStore)
    (locals10 : Array (Option MoveValue))
    (stack10 : List MoveValue)
    (fuel : Nat)
    (hfuel : fuel ≥ 4)
    (hlocals_size : locals10.size = 7)
    (hlocal4 : ∃ h : 4 < locals10.size, locals10[4]'h = some curBalRef)
    (hlocal6 : ∃ h : 6 < locals10.size, locals10[6]'h = some proofRef)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : cs_after_sigma.read proofRid = some (.struct_ proofFields))
    (hfield1 : 1 < proofFields.length) :
    let (rangeCs, _rangeFid) := cs_after_sigma.alloc (proofFields[1]'hfield1)
    ∃ (stack13 : List MoveValue),
    stack13.length ≥ 2 ∧
    run (withdrawalModuleEnv o)
      { code := verifyWithdrawalProofCode, pc := 10,
        locals := locals10,
        localRefs := (List.replicate 7 none).toArray }
      []
      stack10
      { containers := cs_after_sigma, globals := [] }
      fuel =
    run (withdrawalModuleEnv o)
      { code := verifyWithdrawalProofCode, pc := 13,
        locals := locals10,
        localRefs := (List.replicate 7 none).toArray }
      []
      stack13
      { containers := rangeCs, globals := [] }
      (fuel - 4)

/-! ## Complete happy-path composition -/

/-- Withdrawal happy path: both oracles succeed, verification returns empty. -/
axiom withdrawal_happy_path_complete
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef : MoveValue)
    (amount : UInt64)
    (proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 15)
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
    let args := withdrawalArgs chainId sender contract ekRef curBalRef amount proofRef
    let initFrame : Frame := {
      code := verifyWithdrawalProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 7 none).toArray
    }
    run (withdrawalModuleEnv o) initFrame [] [] initMs fuel =
    .returned [] ({ initMs with containers := cs_after_range } : MachineState)

/-! ## Error path compositions -/

/-- Withdrawal sigma oracle fails → .error. -/
axiom withdrawal_sigma_fails_to_error
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef : MoveValue)
    (amount : UInt64)
    (proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 10)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hfield_count : 0 < proofFields.length)
    -- Sigma oracle fails
    (sigma_args : List MoveValue)
    (hsigma_args : sigma_args.length = 7)
    (hsigma_fail : o.verifySigmaProof initMs.containers sigma_args = none) :
    let args := withdrawalArgs chainId sender contract ekRef curBalRef amount proofRef
    let initFrame : Frame := {
      code := verifyWithdrawalProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 7 none).toArray
    }
    run (withdrawalModuleEnv o) initFrame [] [] initMs fuel = .error

/-- Withdrawal range oracle fails (sigma succeeded) → .error. -/
axiom withdrawal_range_fails_to_error
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef : MoveValue)
    (amount : UInt64)
    (proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 14)
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
    let args := withdrawalArgs chainId sender contract ekRef curBalRef amount proofRef
    let initFrame : Frame := {
      code := verifyWithdrawalProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 7 none).toArray
    }
    run (withdrawalModuleEnv o) initFrame [] [] initMs fuel = .error

end MovementFormal.Experimental.ConfidentialAsset.Withdrawal.ConcreteHelpers
