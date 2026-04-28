import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Instr

/-!
# `verify_withdrawal_proof` bytecode — Phase 4

Transcribed from **`movement` v7.4.0** disassembly (`confidential_proof.mv.asm`, def_idx 43, PC 0–14).

## Local layout (8 locals: 8 params + 0 temporaries)

| Index | Name | Type |
|-------|------|------|
| 0 | chain_id | u8 |
| 1 | sender | address |
| 2 | contract_address | address |
| 3 | ek | &CompressedPubkey |
| 4 | amount | u64 |
| 5 | current_balance | &ConfidentialBalance |
| 6 | new_balance | &ConfidentialBalance |
| 7 | proof | &WithdrawalProof |

## Function table

| Index | Function | Body kind |
|-------|----------|-----------|
| 0 | verify_withdrawal_sigma_proof | nativeRef (oracle) |
| 1 | verify_new_balance_range_proof | nativeRef (oracle) |
| 2 | verify_withdrawal_proof (entry) | bytecode (15 instrs, 8 locals) |
-/

namespace MovementFormal.MoveModel.Programs.Withdrawal

open MovementFormal.MoveModel

/-- Oracle for the two sub-function calls in `verify_withdrawal_proof`.
    These are modeled as opaque nativeRef operations since they take
    reference arguments and may abort internally. -/
structure WithdrawalModuleOracle where
  verifySigmaProof : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)
  verifyRangeProof : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)

def verifyWithdrawalProofCode : Array MoveInstr := #[
  .moveLoc 0,         -- 0: push chain_id
  .moveLoc 1,         -- 1: push sender
  .moveLoc 2,         -- 2: push contract_address
  .moveLoc 3,         -- 3: push ek (ref)
  .moveLoc 4,         -- 4: push amount
  .moveLoc 5,         -- 5: push current_balance (ref)
  .copyLoc 6,         -- 6: copy new_balance (ref)
  .copyLoc 7,         -- 7: copy proof (ref)
  .immBorrowField 0,  -- 8: proof.sigma_proof (field 0)
  .call 0,            -- 9: verify_withdrawal_sigma_proof (8 args, 0 returns)
  .moveLoc 6,         -- 10: push new_balance (ref)
  .moveLoc 7,         -- 11: push proof (ref)
  .immBorrowField 1,  -- 12: proof.zkrp_new_balance (field 1)
  .call 1,            -- 13: verify_new_balance_range_proof (2 args, 0 returns)
  .ret                -- 14: return
]

def verifyWithdrawalProofDesc : FuncDesc :=
  { numParams := 8
    numReturns := 0
    body := .bytecode verifyWithdrawalProofCode 8 }

def withdrawalModuleEnv (o : WithdrawalModuleOracle) : ModuleEnv :=
  { constants := #[]
    functions := #[
      { numParams := 8, numReturns := 0,
        body := .nativeRef o.verifySigmaProof },
      { numParams := 2, numReturns := 0,
        body := .nativeRef o.verifyRangeProof },
      verifyWithdrawalProofDesc
    ] }

def verifyWithdrawalProofIdx : Nat := 2

end MovementFormal.MoveModel.Programs.Withdrawal
