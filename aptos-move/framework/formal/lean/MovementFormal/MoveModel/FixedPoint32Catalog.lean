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

@[simp] theorem fixedPoint32CatalogFunctions_0_numParams :
    (fixedPoint32CatalogFunctions[0]'(by decide : 0 < 12)).numParams = 2 :=
  rfl

@[simp] theorem fixedPoint32CatalogFunctions_0_numReturns :
    (fixedPoint32CatalogFunctions[0]'(by decide : 0 < 12)).numReturns = 1 :=
  rfl

@[simp] theorem fixedPoint32CatalogFunctions_1_numParams :
    (fixedPoint32CatalogFunctions[1]'(by decide : 1 < 12)).numParams = 1 :=
  rfl

@[simp] theorem fixedPoint32CatalogFunctions_1_numReturns :
    (fixedPoint32CatalogFunctions[1]'(by decide : 1 < 12)).numReturns = 1 :=
  rfl

@[simp] theorem fixedPoint32CatalogFunctions_3_numParams :
    (fixedPoint32CatalogFunctions[3]'(by decide : 3 < 12)).numParams = 2 :=
  rfl

@[simp] theorem fixedPoint32CatalogFunctions_3_numReturns :
    (fixedPoint32CatalogFunctions[3]'(by decide : 3 < 12)).numReturns = 1 :=
  rfl

@[simp] theorem fixedPoint32CatalogFunctions_5_numParams :
    (fixedPoint32CatalogFunctions[5]'(by decide : 5 < 12)).numParams = 1 :=
  rfl

@[simp] theorem fixedPoint32CatalogFunctions_5_numReturns :
    (fixedPoint32CatalogFunctions[5]'(by decide : 5 < 12)).numReturns = 1 :=
  rfl

def fixedPoint32CatalogModuleEnv : ModuleEnv :=
  { constants := #[], functions := fixedPoint32CatalogFunctions }

@[simp] theorem fixedPoint32CatalogModuleEnv_constants_size :
    fixedPoint32CatalogModuleEnv.constants.size = 0 :=
  rfl

@[simp] theorem fixedPoint32CatalogModuleEnv_functions_size :
    fixedPoint32CatalogModuleEnv.functions.size = 12 :=
  rfl

end MovementFormal.MoveModel.FixedPoint32Catalog
