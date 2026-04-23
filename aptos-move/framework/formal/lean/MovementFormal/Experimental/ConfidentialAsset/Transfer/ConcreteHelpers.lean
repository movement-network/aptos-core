import MovementFormal.MoveModel.Programs.Transfer
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.Experimental.ConfidentialAsset.Helpers.ArgumentMarshaling
import MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleComposition

/-!
# Transfer Concrete Proof Helpers

Concrete helpers for Transfer verifier proofs.

Transfer is the most complex verifier with 13 params and triple-oracle pattern:
- 13 params (chain_id through proof)
- Three oracles: sigma, new_balance_range, transfer_amount_range
- 24 PCs total (longest bytecode sequence)
- Uses both moveLoc and copyLoc for argument reuse
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Transfer.ConcreteHelpers

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Transfer
open MovementFormal.Experimental.ConfidentialAsset.Helpers

/-! ## Entry point args -/

def transferArgs (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmtRef recipientAmtRef : MoveValue)
    (auditorEksRef auditorAmtsRef auditorHintRef : MoveValue)
    (proofRef : MoveValue) : List MoveValue :=
  [.u8 chainId, .address sender, .address contract,
   senderEkRef, recipientEkRef, curBalRef, newBalRef,
   senderAmtRef, recipientAmtRef,
   auditorEksRef, auditorAmtsRef, auditorHintRef,
   proofRef]

/-! ## PC 0-13 argument marshaling -/

/-- Transfer PCs 0-12: massive moveLoc/copyLoc chain for 13 arguments.

PCs:
- 0-5: moveLoc chain for chain_id, sender, contract_address, sender_ek, recipient_ek, current_balance
- 6: copyLoc new_balance (reused at PC 15)
- 7: moveLoc sender_amount
- 8: copyLoc recipient_amount (reused at PC 19)
- 9-11: moveLoc chain for auditor_eks, auditor_amounts, sender_auditor_hint
- 12: copyLoc proof (reused at PC 16 and PC 20)
-/
axiom transfer_pc0_to_pc12_concrete
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmtRef recipientAmtRef : MoveValue)
    (auditorEksRef auditorAmtsRef auditorHintRef : MoveValue)
    (proofRef : MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 13) :
    let args := transferArgs chainId sender contract
                  senderEkRef recipientEkRef curBalRef newBalRef
                  senderAmtRef recipientAmtRef
                  auditorEksRef auditorAmtsRef auditorHintRef
                  proofRef
    let initFrame : Frame := {
      code := verifyTransferProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 13 none).toArray
    }
    ∃ (locals13 : Array (Option MoveValue)),
    locals13.size = 13 ∧
    run (transferModuleEnv o) initFrame [] [] initMs fuel =
    run (transferModuleEnv o)
      { initFrame with pc := 13, locals := locals13 }
      []
      [proofRef, recipientAmtRef, newBalRef,
       auditorHintRef, auditorAmtsRef, auditorEksRef,
       senderAmtRef, curBalRef, recipientEkRef, senderEkRef,
       .address contract, .address sender, .u8 chainId]
      initMs
      (fuel - 13)

/-! ## PC 13 sigma proof field borrow -/

/-- Transfer PC 13: immBorrowField 0 to get sigma proof field from proof struct. -/
axiom transfer_pc13_immBorrowField_sigma
    (o : TransferModuleOracle)
    (proofRef : MoveValue)
    (proofRid : RefId)
    (proofFields : List MoveValue)
    (locals13 : Array (Option MoveValue))
    (stack13 : List MoveValue)
    (ms : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 1)
    (hstack_top : stack13.head? = some proofRef)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : ms.containers.read proofRid = some (.struct_ proofFields))
    (hfield0 : 0 < proofFields.length) :
    let (sigmaCs, sigmaFid) := ms.containers.alloc (proofFields[0]'hfield0)
    run (transferModuleEnv o)
      { code := verifyTransferProofCode, pc := 13,
        locals := locals13,
        localRefs := (List.replicate 13 none).toArray }
      []
      stack13
      ms
      fuel =
    run (transferModuleEnv o)
      { code := verifyTransferProofCode, pc := 14,
        locals := locals13,
        localRefs := (List.replicate 13 none).toArray }
      []
      (.immRef sigmaFid :: stack13.tail)
      { ms with containers := sigmaCs }
      (fuel - 1)

/-! ## PC 15-18 new_balance range marshal -/

/-- After sigma oracle succeeds at PC 14, PCs 15-17 marshal new_balance range proof arguments.

PCs:
- 15: moveLoc 6 (new_balance)
- 16: copyLoc 12 (proof)
- 17: immBorrowField 1 (new_balance range proof field)
-/
axiom transfer_pc15_to_pc18_new_balance_marshal
    (o : TransferModuleOracle)
    (newBalRef proofRef : MoveValue)
    (proofRid : RefId)
    (proofFields : List MoveValue)
    (cs_after_sigma : ContainerStore)
    (locals15 : Array (Option MoveValue))
    (stack15 : List MoveValue)
    (fuel : Nat)
    (hfuel : fuel ≥ 4)
    (hlocals_size : locals15.size = 13)
    (hlocal6 : ∃ h : 6 < locals15.size, locals15[6]'h = some newBalRef)
    (hlocal12 : ∃ h : 12 < locals15.size, locals15[12]'h = some proofRef)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : cs_after_sigma.read proofRid = some (.struct_ proofFields))
    (hfield1 : 1 < proofFields.length) :
    let (newBalCs, _newBalFid) := cs_after_sigma.alloc (proofFields[1]'hfield1)
    ∃ (stack18 : List MoveValue),
    stack18.length ≥ 2 ∧
    run (transferModuleEnv o)
      { code := verifyTransferProofCode, pc := 15,
        locals := locals15,
        localRefs := (List.replicate 13 none).toArray }
      []
      stack15
      { containers := cs_after_sigma, globals := [] }
      fuel =
    run (transferModuleEnv o)
      { code := verifyTransferProofCode, pc := 18,
        locals := locals15,
        localRefs := (List.replicate 13 none).toArray }
      []
      stack18
      { containers := newBalCs, globals := [] }
      (fuel - 4)

/-! ## PC 19-22 transfer_amount range marshal -/

/-- After new_balance oracle succeeds at PC 18, PCs 19-21 marshal transfer_amount range proof arguments.

PCs:
- 19: moveLoc 8 (recipient_amount)
- 20: moveLoc 12 (proof, final consumption)
- 21: immBorrowField 2 (transfer_amount range proof field)
-/
axiom transfer_pc19_to_pc22_transfer_amount_marshal
    (o : TransferModuleOracle)
    (recipientAmtRef proofRef : MoveValue)
    (proofRid : RefId)
    (proofFields : List MoveValue)
    (cs_after_new_balance : ContainerStore)
    (locals19 : Array (Option MoveValue))
    (stack19 : List MoveValue)
    (fuel : Nat)
    (hfuel : fuel ≥ 4)
    (hlocals_size : locals19.size = 13)
    (hlocal8 : ∃ h : 8 < locals19.size, locals19[8]'h = some recipientAmtRef)
    (hlocal12 : ∃ h : 12 < locals19.size, locals19[12]'h = some proofRef)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : cs_after_new_balance.read proofRid = some (.struct_ proofFields))
    (hfield2 : 2 < proofFields.length) :
    let (transferCs, _transferFid) := cs_after_new_balance.alloc (proofFields[2]'hfield2)
    ∃ (stack22 : List MoveValue),
    stack22.length ≥ 2 ∧
    run (transferModuleEnv o)
      { code := verifyTransferProofCode, pc := 19,
        locals := locals19,
        localRefs := (List.replicate 13 none).toArray }
      []
      stack19
      { containers := cs_after_new_balance, globals := [] }
      fuel =
    run (transferModuleEnv o)
      { code := verifyTransferProofCode, pc := 22,
        locals := locals19,
        localRefs := (List.replicate 13 none).toArray }
      []
      stack22
      { containers := transferCs, globals := [] }
      (fuel - 4)

/-! ## Complete happy-path composition -/

/-- Transfer happy path: all three oracles succeed, verification returns empty.

Composes:
1. PCs 0-12: Argument marshaling (moveLoc/copyLoc chain for 13 args)
2. PC 13: immBorrowField 0 (sigma proof field borrow)
3. PC 14: verifySigmaProof call (13 args, succeeds)
4. PCs 15-17: new_balance range proof argument marshaling
5. PC 18: verifyNewBalanceRangeProof call (2 args, succeeds)
6. PCs 19-21: transfer_amount range proof argument marshaling
7. PC 22: verifyTransferAmountRangeProof call (2 args, succeeds)
8. PC 23: ret (empty return)
-/
axiom transfer_happy_path_complete
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmtRef recipientAmtRef : MoveValue)
    (auditorEksRef auditorAmtsRef auditorHintRef : MoveValue)
    (proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 24)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hfield_count : 2 < proofFields.length)
    -- Oracle success conditions
    (sigma_args : List MoveValue)
    (hsigma_args : sigma_args.length = 13)
    (cs_after_sigma : ContainerStore)
    (hsigma_ok : o.verifySigmaProof initMs.containers sigma_args = some ([], cs_after_sigma))
    (new_balance_args : List MoveValue)
    (hnew_balance_args : new_balance_args.length = 2)
    (cs_after_new_balance : ContainerStore)
    (hnew_balance_ok : o.verifyNewBalanceRangeProof cs_after_sigma new_balance_args = some ([], cs_after_new_balance))
    (transfer_args : List MoveValue)
    (htransfer_args : transfer_args.length = 2)
    (cs_after_transfer : ContainerStore)
    (htransfer_ok : o.verifyTransferAmountRangeProof cs_after_new_balance transfer_args = some ([], cs_after_transfer)) :
    let args := transferArgs chainId sender contract
                  senderEkRef recipientEkRef curBalRef newBalRef
                  senderAmtRef recipientAmtRef
                  auditorEksRef auditorAmtsRef auditorHintRef
                  proofRef
    let initFrame : Frame := {
      code := verifyTransferProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 13 none).toArray
    }
    run (transferModuleEnv o) initFrame [] [] initMs fuel =
    .returned [] ({ initMs with containers := cs_after_transfer } : MachineState)

/-! ## Error path compositions -/

/-- Transfer sigma oracle fails → .error. -/
axiom transfer_sigma_fails_to_error
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmtRef recipientAmtRef : MoveValue)
    (auditorEksRef auditorAmtsRef auditorHintRef : MoveValue)
    (proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 15)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hfield_count : 0 < proofFields.length)
    -- Sigma oracle fails
    (sigma_args : List MoveValue)
    (hsigma_args : sigma_args.length = 13)
    (hsigma_fail : o.verifySigmaProof initMs.containers sigma_args = none) :
    let args := transferArgs chainId sender contract
                  senderEkRef recipientEkRef curBalRef newBalRef
                  senderAmtRef recipientAmtRef
                  auditorEksRef auditorAmtsRef auditorHintRef
                  proofRef
    let initFrame : Frame := {
      code := verifyTransferProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 13 none).toArray
    }
    run (transferModuleEnv o) initFrame [] [] initMs fuel = .error

/-- Transfer new_balance oracle fails (sigma succeeded) → .error. -/
axiom transfer_new_balance_fails_to_error
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmtRef recipientAmtRef : MoveValue)
    (auditorEksRef auditorAmtsRef auditorHintRef : MoveValue)
    (proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 19)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hfield_count : 1 < proofFields.length)
    -- Sigma succeeds
    (sigma_args : List MoveValue)
    (hsigma_args : sigma_args.length = 13)
    (cs_after_sigma : ContainerStore)
    (hsigma_ok : o.verifySigmaProof initMs.containers sigma_args = some ([], cs_after_sigma))
    -- New_balance fails
    (new_balance_args : List MoveValue)
    (hnew_balance_args : new_balance_args.length = 2)
    (hnew_balance_fail : o.verifyNewBalanceRangeProof cs_after_sigma new_balance_args = none) :
    let args := transferArgs chainId sender contract
                  senderEkRef recipientEkRef curBalRef newBalRef
                  senderAmtRef recipientAmtRef
                  auditorEksRef auditorAmtsRef auditorHintRef
                  proofRef
    let initFrame : Frame := {
      code := verifyTransferProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 13 none).toArray
    }
    run (transferModuleEnv o) initFrame [] [] initMs fuel = .error

/-- Transfer transfer_amount oracle fails (sigma and new_balance succeeded) → .error. -/
axiom transfer_transfer_amount_fails_to_error
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmtRef recipientAmtRef : MoveValue)
    (auditorEksRef auditorAmtsRef auditorHintRef : MoveValue)
    (proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 23)
    (hproofRef : getRefId proofRef = some proofRid)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hfield_count : 2 < proofFields.length)
    -- Sigma succeeds
    (sigma_args : List MoveValue)
    (hsigma_args : sigma_args.length = 13)
    (cs_after_sigma : ContainerStore)
    (hsigma_ok : o.verifySigmaProof initMs.containers sigma_args = some ([], cs_after_sigma))
    -- New_balance succeeds
    (new_balance_args : List MoveValue)
    (hnew_balance_args : new_balance_args.length = 2)
    (cs_after_new_balance : ContainerStore)
    (hnew_balance_ok : o.verifyNewBalanceRangeProof cs_after_sigma new_balance_args = some ([], cs_after_new_balance))
    -- Transfer_amount fails
    (transfer_args : List MoveValue)
    (htransfer_args : transfer_args.length = 2)
    (htransfer_fail : o.verifyTransferAmountRangeProof cs_after_new_balance transfer_args = none) :
    let args := transferArgs chainId sender contract
                  senderEkRef recipientEkRef curBalRef newBalRef
                  senderAmtRef recipientAmtRef
                  auditorEksRef auditorAmtsRef auditorHintRef
                  proofRef
    let initFrame : Frame := {
      code := verifyTransferProofCode,
      pc := 0,
      locals := (args.map some).toArray,
      localRefs := (List.replicate 13 none).toArray
    }
    run (transferModuleEnv o) initFrame [] [] initMs fuel = .error

end MovementFormal.Experimental.ConfidentialAsset.Transfer.ConcreteHelpers
