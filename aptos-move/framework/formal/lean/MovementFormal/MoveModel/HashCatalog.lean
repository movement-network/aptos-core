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

def hashCatalogModuleEnv : ModuleEnv :=
  { constants := #[], functions := hashCatalogFunctions }

end MovementFormal.MoveModel.HashCatalog
