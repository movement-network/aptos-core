/-
Copyright (c) Move Industries.

Closed catalog of **`aclOracle*`** natives (`Native/StdPrimitives`) for VM↔Lean `std::acl` tests
(`0x1::difftest_acl`). Indices **0–4**.

**Source:** `aptos-move/framework/move-stdlib/sources/acl.move`
-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native.StdPrimitives

namespace MovementFormal.MoveModel.AclCatalog

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.StdPrimitives

/-!
## Function table (indices 0–4)

| Idx | Role |
|-----|------|
| 0 | `empty` |
| 1 | `contains` |
| 2 | `add` |
| 3 | `remove` |
| 4 | `assert_contains` |
-/

def aclCatalogFunctions : Array FuncDesc := #[
  { numParams := 0, numReturns := 1, body := .native aclOracleEmpty },
  { numParams := 2, numReturns := 1, body := .native aclOracleContains },
  { numParams := 2, numReturns := 1, body := .native aclOracleAdd },
  { numParams := 2, numReturns := 1, body := .native aclOracleRemove },
  { numParams := 2, numReturns := 0, body := .native aclOracleAssertContains }
]

@[simp] theorem aclCatalogFunctions_size : aclCatalogFunctions.size = 5 := by native_decide

def aclCatalogModuleEnv : ModuleEnv :=
  { constants := #[], functions := aclCatalogFunctions }

end MovementFormal.MoveModel.AclCatalog
