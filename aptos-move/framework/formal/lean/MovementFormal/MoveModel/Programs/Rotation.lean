import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Instr

/-!
# `verify_rotation_proof` bytecode — Phase 4

Transcribed from **`movement` v7.4.0** disassembly (`confidential_proof.mv.asm`, def_idx 38,
PC 0–14).

## Local layout (8 locals: 8 params + 0 temporaries)

| Index | Name | Type |
|-------|------|------|
| 0 | `chain_id` | `u8` |
| 1 | `sender` | `address` |
| 2 | `contract_address` | `address` |
| 3 | `current_ek` | `&CompressedPubkey` |
| 4 | `new_ek` | `&CompressedPubkey` |
| 5 | `current_balance` | `&ConfidentialBalance` |
| 6 | `new_balance` | `&ConfidentialBalance` |
| 7 | `proof` | `&RotationProof` |

## Function table

| Index | Function | Body kind |
|-------|----------|-----------|
| 0 | `verify_rotation_sigma_proof` | nativeRef (oracle) |
| 1 | `verify_new_balance_range_proof` | nativeRef (oracle) |
| 2 | `verify_rotation_proof` (entry) | bytecode (15 instrs, 8 locals) |
-/

namespace MovementFormal.MoveModel.Programs.Rotation

open MovementFormal.MoveModel

structure RotationModuleOracle where
  verifySigmaProof : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)
  verifyRangeProof : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)

def verifyRotationProofCode : Array MoveInstr := #[
  .moveLoc 0,         -- 0: push chain_id
  .moveLoc 1,         -- 1: push sender
  .moveLoc 2,         -- 2: push contract_address
  .moveLoc 3,         -- 3: push current_ek (ref)
  .moveLoc 4,         -- 4: push new_ek (ref)
  .moveLoc 5,         -- 5: push current_balance (ref)
  .copyLoc 6,         -- 6: copy new_balance (ref, reused at PC 10)
  .copyLoc 7,         -- 7: copy proof (ref, reused at PC 11)
  .immBorrowField 0,  -- 8: RotationProof.sigma_proof (field 0)
  .call 0,            -- 9: verify_rotation_sigma_proof (8 args, 0 returns)
  .moveLoc 6,         -- 10: push new_balance (ref, consumed)
  .moveLoc 7,         -- 11: push proof (ref, consumed)
  .immBorrowField 1,  -- 12: RotationProof.zkrp_new_balance (field 1)
  .call 1,            -- 13: verify_new_balance_range_proof (2 args, 0 returns)
  .ret                -- 14: return
]

def verifyRotationProofDesc : FuncDesc :=
  { numParams := 8
    numReturns := 0
    body := .bytecode verifyRotationProofCode 8 }

def rotationModuleEnv (o : RotationModuleOracle) : ModuleEnv :=
  { constants := #[]
    functions := #[
      { numParams := 8, numReturns := 0,
        body := .nativeRef o.verifySigmaProof },
      { numParams := 2, numReturns := 0,
        body := .nativeRef o.verifyRangeProof },
      verifyRotationProofDesc
    ] }

def verifyRotationProofIdx : Nat := 2

end MovementFormal.MoveModel.Programs.Rotation
