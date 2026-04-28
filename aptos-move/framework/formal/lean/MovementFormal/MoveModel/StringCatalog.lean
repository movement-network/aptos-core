/-
Copyright (c) Move Industries.

Closed catalog of **`stringOracle*`** natives for VM↔Lean `std::string` UTF-8 tests
(`0x1::difftest_string`). Indices **0–3** mirror `move-stdlib/src/natives/string.rs` in this repo:
`internal_check_utf8`, `internal_sub_string`, `internal_index_of`, `internal_is_char_boundary`.

**Source:** `aptos-move/framework/move-stdlib/sources/string.move`
-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native.StdPrimitives

namespace MovementFormal.MoveModel.StringCatalog

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.StdPrimitives

/-!
## Function table (indices 0–3)

| Idx | Move API |
|-----|----------|
| 0 | `internal_check_utf8(&vector<u8>)` |
| 1 | `internal_sub_string(&vector<u8>, i, j)` |
| 2 | `internal_index_of(&vector<u8>, &vector<u8>)` |
| 3 | `internal_is_char_boundary(&vector<u8>, i)` |
-/

def stringCatalogFunctions : Array FuncDesc := #[
  { numParams := 1, numReturns := 1, body := .native stringOracleInternalCheckUtf8 },
  { numParams := 3, numReturns := 1, body := .native stringOracleInternalSubString },
  { numParams := 2, numReturns := 1, body := .native stringOracleInternalIndexOf },
  { numParams := 2, numReturns := 1, body := .native stringOracleInternalIsCharBoundary }
]

@[simp] theorem stringCatalogFunctions_size : stringCatalogFunctions.size = 4 := by native_decide

@[simp] theorem stringCatalogFunctions_0_numParams :
    (stringCatalogFunctions[0]'(by decide : 0 < 4)).numParams = 1 :=
  rfl

@[simp] theorem stringCatalogFunctions_0_numReturns :
    (stringCatalogFunctions[0]'(by decide : 0 < 4)).numReturns = 1 :=
  rfl

@[simp] theorem stringCatalogFunctions_1_numParams :
    (stringCatalogFunctions[1]'(by decide : 1 < 4)).numParams = 3 :=
  rfl

@[simp] theorem stringCatalogFunctions_1_numReturns :
    (stringCatalogFunctions[1]'(by decide : 1 < 4)).numReturns = 1 :=
  rfl

@[simp] theorem stringCatalogFunctions_2_numParams :
    (stringCatalogFunctions[2]'(by decide : 2 < 4)).numParams = 2 :=
  rfl

def stringCatalogModuleEnv : ModuleEnv :=
  { constants := #[], functions := stringCatalogFunctions }

@[simp] theorem stringCatalogModuleEnv_constants_size :
    stringCatalogModuleEnv.constants.size = 0 :=
  rfl

@[simp] theorem stringCatalogModuleEnv_functions_size :
    stringCatalogModuleEnv.functions.size = 4 :=
  rfl

end MovementFormal.MoveModel.StringCatalog
