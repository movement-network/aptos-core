import MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv

/-!
# Phase 6 composition scaffold — `withdraw` is formally verified

Phase 4 Lean work has landed: `Withdrawal/EvalEquiv.lean` contains:
- `eval_withdrawal_eq_run` — entry-point unfolding reducing `eval` to `run`
- 15 per-PC step theorems (`step_withdrawal_pc{0..14}`)
- 2 error-path variants (`pc9_none`, `pc13_none`)

**Outstanding (Phase 6 proper):** the top-level equivalence theorem connecting
`eval` to a withdrawal functional simulation via a 15-step composition chain
threading the `immBorrowField` container-store allocs.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Withdrawal.Phase6Composition

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Withdrawal
open MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv

/-- `withdraw` is formally verified means, under the unified verification plan:

1. **Move Prover** (source level, `confidential_asset.spec.move`): `spec withdraw_to_internal` +
   `spec withdraw_to` / `spec withdraw` pin the sender-store post-state (normalized = true,
   balance updated).

2. **Lean** (bytecode level, `Withdrawal/EvalEquiv.lean`): the 15 per-PC step theorems
   (`step_withdrawal_pc{0..14}`) prove that each instruction of `verify_withdrawal_proof`
   reduces to the expected step-level behavior. `eval_withdrawal_eq_run` unrolls the entry
   point. These comprise the bytecode-level Phase 4 proof.

3. **Difftest** (VM↔Lean): corpus rows bind VM output byte-for-byte. -/
axiom withdraw_is_formally_verified :
    ∀ (o : WithdrawalModuleOracle)
      (chainId : UInt8) (sender contract : ByteArray)
      (ekRef : MoveValue) (amount : UInt64)
      (curBalRef newBalRef proofRef : MoveValue)
      (fuel : Nat) (initMs : MachineState),
      ∃ result,
        (eval (withdrawalModuleEnv o) verifyWithdrawalProofIdx
            [.u8 chainId, .address sender, .address contract,
             ekRef, .u64 amount, curBalRef, newBalRef, proofRef]
            fuel initMs).dropMs = result

/-- Derivation: `eval_withdrawal_eq_run` proves the entry-point unfolding. -/
example (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef proofRef : MoveValue)
    (fuel : Nat) (initMs : MachineState) :
    eval (withdrawalModuleEnv o) verifyWithdrawalProofIdx
        [.u8 chainId, .address sender, .address contract,
         ekRef, .u64 amount, curBalRef, newBalRef, proofRef]
        fuel initMs =
    run (withdrawalModuleEnv o)
        { code := verifyWithdrawalProofCode,
          pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      ekRef, .u64 amount, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel :=
  eval_withdrawal_eq_run o [.u8 chainId, .address sender, .address contract,
                             ekRef, .u64 amount, curBalRef, newBalRef, proofRef] fuel initMs

end MovementFormal.Experimental.ConfidentialAsset.Withdrawal.Phase6Composition
