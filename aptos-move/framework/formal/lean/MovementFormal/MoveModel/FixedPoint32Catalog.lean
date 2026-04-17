/-
Copyright (c) Move Industries.

Closed catalog of **`fp32Oracle*`** natives (`Native/StdPrimitives`) aligned with
`0x1::difftest_fixed_point32`: **u64**/**bool** IO matching JSON `TypedValue` (no `FixedPoint32` struct
wire in the oracle). Indices **0–11**.

**Source:** `aptos-move/framework/move-stdlib/sources/fixed_point32.move` (via test wrappers).
-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native.StdPrimitives

namespace MovementFormal.MoveModel.FixedPoint32Catalog

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.StdPrimitives

/-!
## Function table (indices 0–11)

| Idx | Difftest `test_fp32_*` |
|-----|------------------------|
| 0 | `create_from_rational` → raw |
| 1 | `create_from_u64` → raw |
| 2 | `create_from_raw_value` |
| 3 | `multiply_u64` |
| 4 | `divide_u64` |
| 5 | `get_raw_value` |
| 6 | `is_zero` |
| 7 | `floor` |
| 8 | `ceil` |
| 9 | `round` |
| 10 | `min` |
| 11 | `max` |
-/

def fixedPoint32CatalogFunctions : Array FuncDesc := #[
  { numParams := 2, numReturns := 1, body := .native fp32OracleCreateFromRational },
  { numParams := 1, numReturns := 1, body := .native fp32OracleCreateFromU64 },
  { numParams := 1, numReturns := 1, body := .native fp32OracleCreateFromRawValue },
  { numParams := 2, numReturns := 1, body := .native fp32OracleMultiplyU64 },
  { numParams := 2, numReturns := 1, body := .native fp32OracleDivideU64 },
  { numParams := 1, numReturns := 1, body := .native fp32OracleGetRawValue },
  { numParams := 1, numReturns := 1, body := .native fp32OracleIsZero },
  { numParams := 1, numReturns := 1, body := .native fp32OracleFloor },
  { numParams := 1, numReturns := 1, body := .native fp32OracleCeil },
  { numParams := 1, numReturns := 1, body := .native fp32OracleRound },
  { numParams := 2, numReturns := 1, body := .native fp32OracleMin },
  { numParams := 2, numReturns := 1, body := .native fp32OracleMax }
]

@[simp] theorem fixedPoint32CatalogFunctions_size : fixedPoint32CatalogFunctions.size = 12 := by native_decide

def fixedPoint32CatalogModuleEnv : ModuleEnv :=
  { constants := #[], functions := fixedPoint32CatalogFunctions }

end MovementFormal.MoveModel.FixedPoint32Catalog
