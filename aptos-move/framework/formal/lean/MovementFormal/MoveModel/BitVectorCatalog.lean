/-
Copyright (c) Move Industries.

Closed catalog of **`bitVector*`** natives (`Native/StdPrimitives`) for VM↔Lean `std::bit_vector`
tests (`0x1::difftest_bit_vector`). Indices **0–4**.

**Source:** `aptos-move/framework/move-stdlib/sources/bit_vector.move`
-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native.StdPrimitives

namespace MovementFormal.MoveModel.BitVectorCatalog

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.StdPrimitives

/-!
## Function table (indices 0–4)

| Idx | Role |
|-----|------|
| 0 | `new` |
| 1 | `set` |
| 2 | `unset` |
| 3 | `is_index_set` |
| 4 | `shift_left` |
-/

def bitVectorCatalogFunctions : Array FuncDesc := #[
  { numParams := 1, numReturns := 1, body := .native bitVectorNew },
  { numParams := 2, numReturns := 1, body := .native bitVectorSet },
  { numParams := 2, numReturns := 1, body := .native bitVectorUnset },
  { numParams := 2, numReturns := 1, body := .native bitVectorIsIndexSet },
  { numParams := 2, numReturns := 1, body := .native bitVectorShiftLeft }
]

@[simp] theorem bitVectorCatalogFunctions_size : bitVectorCatalogFunctions.size = 5 := by native_decide

def bitVectorCatalogModuleEnv : ModuleEnv :=
  { constants := #[], functions := bitVectorCatalogFunctions }

end MovementFormal.MoveModel.BitVectorCatalog
