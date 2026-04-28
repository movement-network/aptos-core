import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Instr

/-!
# `verify_transfer_proof` bytecode — Phase 4

Transcribed from **`movement` v7.4.0** disassembly (`confidential_proof.mv.asm`, def_idx 41,
PC 0–23).

## Local layout (13 locals: 13 params + 0 temporaries)

| Index | Name | Type |
|-------|------|------|
| 0 | `chain_id` | `u8` |
| 1 | `sender` | `address` |
| 2 | `contract_address` | `address` |
| 3 | `sender_ek` | `&CompressedPubkey` |
| 4 | `recipient_ek` | `&CompressedPubkey` |
| 5 | `current_balance` | `&ConfidentialBalance` |
| 6 | `new_balance` | `&ConfidentialBalance` |
| 7 | `sender_amount` | `&ConfidentialBalance` |
| 8 | `recipient_amount` | `&ConfidentialBalance` |
| 9 | `auditor_eks` | `&vector<CompressedPubkey>` |
| 10 | `auditor_amounts` | `&vector<ConfidentialBalance>` |
| 11 | `sender_auditor_hint` | `&vector<u8>` |
| 12 | `proof` | `&TransferProof` |

## Function table

| Index | Function | Body kind |
|-------|----------|-----------|
| 0 | `verify_transfer_sigma_proof` | nativeRef (oracle) |
| 1 | `verify_new_balance_range_proof` | nativeRef (oracle) |
| 2 | `verify_transfer_amount_range_proof` | nativeRef (oracle) |
| 3 | `verify_transfer_proof` (entry) | bytecode (24 instrs, 13 locals) |
-/

namespace MovementFormal.MoveModel.Programs.Transfer

open MovementFormal.MoveModel

structure TransferModuleOracle where
  verifySigmaProof : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)
  verifyNewBalanceRangeProof : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)
  verifyTransferAmountRangeProof : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)

def verifyTransferProofCode : Array MoveInstr := #[
  .moveLoc 0,          -- 0: push chain_id
  .moveLoc 1,          -- 1: push sender
  .moveLoc 2,          -- 2: push contract_address
  .moveLoc 3,          -- 3: push sender_ek (ref)
  .moveLoc 4,          -- 4: push recipient_ek (ref)
  .moveLoc 5,          -- 5: push current_balance (ref)
  .copyLoc 6,          -- 6: copy new_balance (ref, reused at PC 15)
  .moveLoc 7,          -- 7: push sender_amount (ref)
  .copyLoc 8,          -- 8: copy recipient_amount (ref, reused at PC 19)
  .moveLoc 9,          -- 9: push auditor_eks (ref)
  .moveLoc 10,         -- 10: push auditor_amounts (ref)
  .moveLoc 11,         -- 11: push sender_auditor_hint (ref)
  .copyLoc 12,         -- 12: copy proof (ref, reused at PC 16 and PC 20)
  .immBorrowField 0,   -- 13: TransferProof.sigma_proof (field 0)
  .call 0,             -- 14: verify_transfer_sigma_proof (13 args, 0 returns)
  .moveLoc 6,          -- 15: push new_balance (ref, consumed)
  .copyLoc 12,         -- 16: copy proof (ref, reused at PC 20)
  .immBorrowField 1,   -- 17: TransferProof.zkrp_new_balance (field 1)
  .call 1,             -- 18: verify_new_balance_range_proof (2 args, 0 returns)
  .moveLoc 8,          -- 19: push recipient_amount (ref, consumed)
  .moveLoc 12,         -- 20: push proof (ref, consumed)
  .immBorrowField 2,   -- 21: TransferProof.zkrp_transfer_amount (field 2)
  .call 2,             -- 22: verify_transfer_amount_range_proof (2 args, 0 returns)
  .ret                 -- 23: return
]

def verifyTransferProofDesc : FuncDesc :=
  { numParams := 13
    numReturns := 0
    body := .bytecode verifyTransferProofCode 13 }

def transferModuleEnv (o : TransferModuleOracle) : ModuleEnv :=
  { constants := #[]
    functions := #[
      { numParams := 13, numReturns := 0,
        body := .nativeRef o.verifySigmaProof },
      { numParams := 2, numReturns := 0,
        body := .nativeRef o.verifyNewBalanceRangeProof },
      { numParams := 2, numReturns := 0,
        body := .nativeRef o.verifyTransferAmountRangeProof },
      verifyTransferProofDesc
    ] }

def verifyTransferProofIdx : Nat := 3

end MovementFormal.MoveModel.Programs.Transfer
