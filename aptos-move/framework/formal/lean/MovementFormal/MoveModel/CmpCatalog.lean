/-
Copyright (c) Move Industries.

Closed catalog of **`cmpOracle*`** for `std::cmp` on **`u64`**, **`bool`**, **`u8`**, **`address`**,
**`u128`**, **`u16`**, **`u32`**, **`u256`**
(`compare` + `Ordering` predicates). Used by VM↔Lean `0x1::difftest_cmp`. Indices **0–47**.

**Source:** `aptos-move/framework/move-stdlib/sources/cmp.move`
-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native.StdPrimitives

namespace MovementFormal.MoveModel.CmpCatalog

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.StdPrimitives

/-!
## Function table (indices 0–47)

| Idx | Types | Move surface |
|-----|-------|----------------|
| 0–5 | `u64` | `is_{eq,ne,lt,le,gt,ge}(&compare(&a,&b))` |
| 6–11 | `bool` | same |
| 12–17 | `u8` | same |
| 18–23 | `address` | same |
| 24–29 | `u128` | same |
| 30–35 | `u16` | same |
| 36–41 | `u32` | same |
| 42–47 | `u256` | same |
-/

def cmpCatalogFunctions : Array FuncDesc := #[
  { numParams := 2, numReturns := 1, body := .native cmpOracleIsEq },
  { numParams := 2, numReturns := 1, body := .native cmpOracleIsNe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleIsLt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleIsLe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleIsGt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleIsGe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleBoolIsEq },
  { numParams := 2, numReturns := 1, body := .native cmpOracleBoolIsNe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleBoolIsLt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleBoolIsLe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleBoolIsGt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleBoolIsGe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU8IsEq },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU8IsNe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU8IsLt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU8IsLe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU8IsGt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU8IsGe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleAddressIsEq },
  { numParams := 2, numReturns := 1, body := .native cmpOracleAddressIsNe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleAddressIsLt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleAddressIsLe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleAddressIsGt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleAddressIsGe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU128IsEq },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU128IsNe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU128IsLt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU128IsLe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU128IsGt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU128IsGe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU16IsEq },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU16IsNe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU16IsLt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU16IsLe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU16IsGt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU16IsGe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU32IsEq },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU32IsNe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU32IsLt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU32IsLe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU32IsGt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU32IsGe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU256IsEq },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU256IsNe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU256IsLt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU256IsLe },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU256IsGt },
  { numParams := 2, numReturns := 1, body := .native cmpOracleU256IsGe }
]

@[simp] theorem cmpCatalogFunctions_size : cmpCatalogFunctions.size = 48 := by native_decide

@[simp] theorem cmpCatalogFunctions_0_numParams :
    (cmpCatalogFunctions[0]'(by decide : 0 < 48)).numParams = 2 :=
  rfl

@[simp] theorem cmpCatalogFunctions_0_numReturns :
    (cmpCatalogFunctions[0]'(by decide : 0 < 48)).numReturns = 1 :=
  rfl

def cmpCatalogModuleEnv : ModuleEnv :=
  { constants := #[], functions := cmpCatalogFunctions }

@[simp] theorem cmpCatalogModuleEnv_constants_size :
    cmpCatalogModuleEnv.constants.size = 0 :=
  rfl

@[simp] theorem cmpCatalogModuleEnv_functions_size :
    cmpCatalogModuleEnv.functions.size = 48 :=
  rfl

end MovementFormal.MoveModel.CmpCatalog
