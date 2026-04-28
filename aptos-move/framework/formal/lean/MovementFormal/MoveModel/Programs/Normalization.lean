import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Instr

/-!
# Transcribed bytecode for `verify_normalization_proof`

**Source:** `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`
(`verify_normalization_proof`); transcribed from **`movement` v7.4.0** disassembly
(`movement move disassemble`, `confidential_proof.mv.asm`, def_idx 34, PC 0-13).

## Local layout (7 locals: 7 params + 0 temporaries)

| Index | Name | Type |
|-------|------|------|
| 0 | `chain_id` | `u8` |
| 1 | `sender` | `address` |
| 2 | `contract_address` | `address` |
| 3 | `ek` | `&CompressedPubkey` (immutable reference) |
| 4 | `current_balance` | `&ConfidentialBalance` (immutable reference) |
| 5 | `new_balance` | `&ConfidentialBalance` (immutable reference) |
| 6 | `proof` | `&NormalizationProof` (immutable reference) |

## Function table

| Index | Function | Params | Returns | Body |
|-------|----------|--------|---------|------|
| 0 | `verify_normalization_sigma_proof` | 7 | 0 | nativeRef (can abort) |
| 1 | `verify_new_balance_range_proof` | 2 | 0 | nativeRef (can abort) |
| 2 | `verify_normalization_proof` | 7 | 0 | bytecode entry point |

## Notes on sub-call modeling

Both sub-calls (`verify_normalization_sigma_proof`, `verify_new_balance_range_proof`) take
reference arguments and can abort (e.g. with `error::invalid_argument`). The current `FuncBody`
model has no `nativeRefAbort` variant, so we use `.nativeRef` where `none` return maps to
`.error` in the step semantics. This is a sound over-approximation: any execution that would
abort in the real VM maps to `.error` in the model. The precise abort codes are captured in
the functional simulation layer.
-/

namespace MovementFormal.MoveModel.Programs.Normalization

open MovementFormal.MoveModel

/-- Module-level oracle for the normalization dispatcher. Abstracts the two sub-calls
    at the function boundary rather than at the curve-operation level.

    Both sub-calls take reference arguments (refs into the ContainerStore) and may abort.
    Since `FuncBody.nativeRef` maps failure to `.error`, `none` return represents either
    a verification failure (abort) or a malformed-input error. -/
structure NormalizationModuleOracle where
  /-- `verify_normalization_sigma_proof(chain_id, sender, contract_address, &ek,
      &current_balance, &new_balance, &NormalizationSigmaProof)`.
      Returns `some ([], cs')` on success, `none` on abort/error. -/
  verifySigmaProof : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)
  /-- `verify_new_balance_range_proof(&ConfidentialBalance, &RangeProof)`.
      Returns `some ([], cs')` on success, `none` on abort/error. -/
  verifyRangeProof : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore)

/-- Transcribed bytecode from `movement` v7.4.0 disassembly.
    14 instructions, 7 parameters, 0 temporaries, 7 locals total.

    The function dispatches to two sub-calls:
    1. `verify_normalization_sigma_proof` (function 0) -- sigma equality proof
    2. `verify_new_balance_range_proof` (function 1)   -- Bulletproofs range proof

    `ImmBorrowField` indices are struct-local (0 = sigma_proof, 1 = zkrp_new_balance),
    mapped from the global field table indices 23 and 24 in the compiled module. -/
def verifyNormalizationProofCode : Array MoveInstr := #[
  .moveLoc 0,          -- 0: push chain_id (u8, consumed)
  .moveLoc 1,          -- 1: push sender (address, consumed)
  .moveLoc 2,          -- 2: push contract_address (address, consumed)
  .moveLoc 3,          -- 3: push ek (&CompressedPubkey, consumed)
  .moveLoc 4,          -- 4: push current_balance (&ConfidentialBalance, consumed)
  .copyLoc 5,          -- 5: copy new_balance (&ConfidentialBalance, used again at PC 9)
  .copyLoc 6,          -- 6: copy proof (&NormalizationProof, used again at PC 10)
  .immBorrowField 0,   -- 7: proof.sigma_proof (&NormalizationSigmaProof, field 0)
  .call 0,             -- 8: verify_normalization_sigma_proof(7 args, 0 returns)
  .moveLoc 5,          -- 9: push new_balance (&ConfidentialBalance, consumed)
  .moveLoc 6,          -- 10: push proof (&NormalizationProof, consumed)
  .immBorrowField 1,   -- 11: proof.zkrp_new_balance (&RangeProof, field 1)
  .call 1,             -- 12: verify_new_balance_range_proof(2 args, 0 returns)
  .ret                 -- 13: return
]

def verifyNormalizationProofDesc : FuncDesc :=
  { numParams := 7
    numReturns := 0
    body := .bytecode verifyNormalizationProofCode 7 }

/-- Build a `ModuleEnv` for `verify_normalization_proof` from a `NormalizationModuleOracle`.

    Function indices:
    - 0: `verify_normalization_sigma_proof` (nativeRef, 7 params, 0 returns)
    - 1: `verify_new_balance_range_proof` (nativeRef, 2 params, 0 returns)
    - 2: `verify_normalization_proof` (bytecode entry point, 7 params, 0 returns) -/
def normalizationModuleEnv (o : NormalizationModuleOracle) : ModuleEnv :=
  { constants := #[]
    functions := #[
      -- 0: verify_normalization_sigma_proof
      { numParams := 7, numReturns := 0,
        body := .nativeRef o.verifySigmaProof },
      -- 1: verify_new_balance_range_proof
      { numParams := 2, numReturns := 0,
        body := .nativeRef o.verifyRangeProof },
      -- 2: verify_normalization_proof (bytecode entry)
      verifyNormalizationProofDesc
    ] }

/-- The function index of `verify_normalization_proof` in `normalizationModuleEnv`. -/
def verifyNormalizationProofIdx : Nat := 2

end MovementFormal.MoveModel.Programs.Normalization
