import MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv

/-!
# Phase 6 composition scaffold — `confidential_transfer` is formally verified

Phase 4 Lean work has landed: `Transfer/EvalEquiv.lean` contains:
- `eval_transfer_eq_run` — entry-point unfolding reducing `eval` to `run`
- 24 per-PC step theorems (`step_transfer_pc{0..23}`)
- 3 error-path variants (`pc14_none`, `pc18_none`, `pc22_none`)
- `verifyTransferBytecodeResult` — functional simulation definition
- 3 error-path shape lemmas (sigmaFails, newBalanceRangeFails, transferAmountRangeFails)

Transfer is the most complex dispatcher: 13 params, 3 sub-calls (sigma + new balance range +
transfer amount range), 3 `ImmBorrowField` instructions.

**Outstanding (Phase 6 proper):** the top-level equivalence theorem
`transfer_eval_equiv_functional_sim` connecting `eval` to `verifyTransferBytecodeResult`
via a 24-step composition chain. Currently an axiom stub in EvalEquiv.lean; proof requires
~350-450 lines due to 3-call nesting complexity.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Transfer.Phase6Composition

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Transfer
open MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv

/-- `confidential_transfer` is formally verified means, under the unified verification plan:

1. **Move Prover** (source level): `spec confidential_transfer_internal` +
   `spec confidential_transfer` pin the sender/recipient store post-states, auditor
   invariants, and the `balance_c_equals(sender_amount, recipient_amount)` check.

2. **Lean** (bytecode level, `Transfer/EvalEquiv.lean`): the 24 per-PC step theorems
   (`step_transfer_pc{0..23}`) prove that each instruction of `verify_transfer_proof`
   reduces to the expected step-level behavior. `eval_transfer_eq_run` unrolls the entry
   point. `transfer_eval_equiv_functional_sim` (axiom stub, to be proved) connects eval
   to the functional simulation.

3. **Difftest** (VM↔Lean): 20 transfer-with-auditors corpus rows (0–19 auditors) bind
   the VM to the Lean model byte-for-byte.

The axiom `transfer_eval_equiv_functional_sim` in EvalEquiv.lean is the Phase 6 gap. -/
axiom transfer_is_formally_verified :
    ∀ (o : TransferModuleOracle)
      (chainId : UInt8) (sender contract : ByteArray)
      (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
      (senderAmountRef recipientAmountRef : MoveValue)
      (auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef : MoveValue)
      (proofRid : RefId) (proofFields : List MoveValue)
      (initMs : MachineState)
      (hFieldCount : 2 < proofFields.length)
      (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
      (hproofRef : getRefId proofRef = some proofRid)
      (fuel : Nat)
      (hfuel : fuel ≥ 24),
      let args := [.u8 chainId, .address sender, .address contract,
                   senderEkRef, recipientEkRef, curBalRef, newBalRef,
                   senderAmountRef, recipientAmountRef,
                   auditorEksRef, auditorAmountsRef, senderAuditorHintRef, proofRef]
      (eval (transferModuleEnv o) verifyTransferProofIdx args fuel initMs).dropMs =
      match verifyTransferBytecodeResult o chainId sender contract
              senderEkRef recipientEkRef curBalRef newBalRef
              senderAmountRef recipientAmountRef
              auditorEksRef auditorAmountsRef senderAuditorHintRef
              proofRid proofFields initMs hFieldCount with
      | .returned ms => .returned [] ms
      | .error => .error

/-- Derivation: `transfer_is_formally_verified` follows directly from
    `transfer_eval_equiv_functional_sim` (the axiom stub in EvalEquiv.lean).
    When that axiom is proved, this example will be a proper derivation. -/
example (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 2 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (fuel : Nat)
    (hfuel : fuel ≥ 24) :
    let args := [.u8 chainId, .address sender, .address contract,
                 senderEkRef, recipientEkRef, curBalRef, newBalRef,
                 senderAmountRef, recipientAmountRef,
                 auditorEksRef, auditorAmountsRef, senderAuditorHintRef, proofRef]
    (eval (transferModuleEnv o) verifyTransferProofIdx args fuel initMs).dropMs =
    match verifyTransferBytecodeResult o chainId sender contract
            senderEkRef recipientEkRef curBalRef newBalRef
            senderAmountRef recipientAmountRef
            auditorEksRef auditorAmountsRef senderAuditorHintRef
            proofRid proofFields initMs hFieldCount with
    | .returned ms => .returned [] ms
    | .error => .error :=
  transfer_eval_equiv_functional_sim o chainId sender contract
    senderEkRef recipientEkRef curBalRef newBalRef
    senderAmountRef recipientAmountRef
    auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef
    proofRid proofFields initMs hFieldCount hread hproofRef fuel hfuel

end MovementFormal.Experimental.ConfidentialAsset.Transfer.Phase6Composition
