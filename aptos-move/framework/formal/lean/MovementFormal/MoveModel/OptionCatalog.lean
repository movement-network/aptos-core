/-
Copyright (c) Move Industries.

Closed catalog of **`optionOracleU64*`** natives (`Native/StdPrimitives`) for VM↔Lean `Option<u64>`
tests (`0x1::difftest_option`). Indices **0–16** — scratch-arg materialization `(is_some, inner, …)`,
`vector<u64>` for `from_vec`, or **constructors** `none` / `some` (indices **15–16**).
**`nativeAbort`:** indices **4–7, 9–10, 14** (borrow / fill / extract / swap / destroy_* / from_vec).

**Source:** `aptos-move/framework/move-stdlib/sources/option.move`
-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native.StdPrimitives

namespace MovementFormal.MoveModel.OptionCatalog

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.StdPrimitives

/-!
## Function table (indices 0–16)

| Idx | Role |
|-----|------|
| 0 | `is_none` |
| 1 | `is_some` |
| 2 | `contains` |
| 3 | `get_with_default` |
| 4 | `borrow` |
| 5 | `fill` |
| 6 | `extract` |
| 7 | `swap` |
| 8 | `swap_or_fill` |
| 9 | `destroy_none` |
| 10 | `destroy_some` |
| 11 | `borrow_with_default` |
| 12 | `destroy_with_default` |
| 13 | `to_vec` |
| 14 | `from_vec` (`nativeAbort`: ok if len ≤ 1, else abort `EOPTION_VEC_TOO_LONG`) |
| 15 | `none` |
| 16 | `some` |
-/

def optionCatalogFunctions : Array FuncDesc := #[
  { numParams := 2, numReturns := 1, body := .native optionOracleU64IsNone },
  { numParams := 2, numReturns := 1, body := .native optionOracleU64IsSome },
  { numParams := 3, numReturns := 1, body := .native optionOracleU64Contains },
  { numParams := 3, numReturns := 1, body := .native optionOracleU64GetWithDefault },
  { numParams := 2, numReturns := 1, body := .nativeAbort optionOracleU64Borrow },
  { numParams := 3, numReturns := 0, body := .nativeAbort optionOracleU64Fill },
  { numParams := 2, numReturns := 1, body := .nativeAbort optionOracleU64Extract },
  { numParams := 3, numReturns := 1, body := .nativeAbort optionOracleU64Swap },
  { numParams := 3, numReturns := 1, body := .native optionOracleU64SwapOrFill },
  { numParams := 2, numReturns := 0, body := .nativeAbort optionOracleU64DestroyNone },
  { numParams := 2, numReturns := 1, body := .nativeAbort optionOracleU64DestroySome },
  { numParams := 3, numReturns := 1, body := .native optionOracleU64BorrowWithDefault },
  { numParams := 3, numReturns := 1, body := .native optionOracleU64DestroyWithDefault },
  { numParams := 2, numReturns := 1, body := .native optionOracleU64ToVec },
  { numParams := 1, numReturns := 1, body := .nativeAbort optionOracleU64FromVec },
  { numParams := 0, numReturns := 1, body := .native optionOracleU64StdNone },
  { numParams := 1, numReturns := 1, body := .native optionOracleU64StdSome }
]

@[simp] theorem optionCatalogFunctions_size : optionCatalogFunctions.size = 17 := by native_decide

def optionCatalogModuleEnv : ModuleEnv :=
  { constants := #[], functions := optionCatalogFunctions }

end MovementFormal.MoveModel.OptionCatalog
