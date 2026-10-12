/-
Copyright (c) Move Industries.

Closed catalog of `std::hash` natives used by `move-lean-difftest` (`hash` suite) and
`Refinement/Std/Hash.lean`. Indices **0–1** are **`sha2_256`**, **`sha3_256`**.

**Source:** `aptos-move/framework/move-stdlib/sources/hash.move`
-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native

namespace MovementFormal.MoveModel.HashCatalog

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native

/-!
## Function table (indices 0–1)

| Idx | Move API |
|-----|----------|
| 0 | `sha2_256(vector<u8>)` |
| 1 | `sha3_256(vector<u8>)` |
-/

def hashCatalogFunctions : Array FuncDesc := #[
  { numParams := 1, numReturns := 1, body := .native sha2_256_native },
  { numParams := 1, numReturns := 1, body := .native sha3_256_native }
]

@[simp] theorem hashCatalogFunctions_size : hashCatalogFunctions.size = 2 := by native_decide

@[simp] theorem hashCatalogFunctions_0_numParams :
    (hashCatalogFunctions[0]'(by decide : 0 < 2)).numParams = 1 :=
  rfl

@[simp] theorem hashCatalogFunctions_0_numReturns :
    (hashCatalogFunctions[0]'(by decide : 0 < 2)).numReturns = 1 :=
  rfl

@[simp] theorem hashCatalogFunctions_1_numParams :
    (hashCatalogFunctions[1]'(by decide : 1 < 2)).numParams = 1 :=
  rfl

@[simp] theorem hashCatalogFunctions_1_numReturns :
    (hashCatalogFunctions[1]'(by decide : 1 < 2)).numReturns = 1 :=
  rfl

def hashCatalogModuleEnv : ModuleEnv :=
  { constants := #[], functions := hashCatalogFunctions }

@[simp] theorem hashCatalogModuleEnv_constants_size :
    hashCatalogModuleEnv.constants.size = 0 :=
  rfl

@[simp] theorem hashCatalogModuleEnv_functions_size :
    hashCatalogModuleEnv.functions.size = 2 :=
  rfl

end MovementFormal.MoveModel.HashCatalog
