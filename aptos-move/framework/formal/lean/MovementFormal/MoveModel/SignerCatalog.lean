/-
Copyright (c) Move Industries.

Closed catalog of `std::signer` natives used by `move-lean-difftest` (`signer` suite) and
`Refinement/Std/Signer.lean`. Indices **0–1** are **`borrow_address`**, **`address_of`**
(value-level semantics match; both return the embedded address bytes).

**Source:** `aptos-move/framework/move-stdlib/sources/signer.move`
-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Native.StdPrimitives

namespace MovementFormal.MoveModel.SignerCatalog

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.StdPrimitives

/-!
## Function table (indices 0–1)

| Idx | Move API |
|-----|----------|
| 0 | `borrow_address(&signer): &address` → value `address` |
| 1 | `address_of(&signer): address` |
-/

def signerCatalogFunctions : Array FuncDesc := #[
  { numParams := 1, numReturns := 1, body := .native signerBorrowAddress },
  { numParams := 1, numReturns := 1, body := .native signerAddressOf }
]

@[simp] theorem signerCatalogFunctions_size : signerCatalogFunctions.size = 2 := by native_decide

@[simp] theorem signerCatalogFunctions_0_numParams :
    (signerCatalogFunctions[0]'(by decide : 0 < 2)).numParams = 1 :=
  rfl

@[simp] theorem signerCatalogFunctions_0_numReturns :
    (signerCatalogFunctions[0]'(by decide : 0 < 2)).numReturns = 1 :=
  rfl

@[simp] theorem signerCatalogFunctions_1_numParams :
    (signerCatalogFunctions[1]'(by decide : 1 < 2)).numParams = 1 :=
  rfl

@[simp] theorem signerCatalogFunctions_1_numReturns :
    (signerCatalogFunctions[1]'(by decide : 1 < 2)).numReturns = 1 :=
  rfl

def signerCatalogModuleEnv : ModuleEnv :=
  { constants := #[], functions := signerCatalogFunctions }

@[simp] theorem signerCatalogModuleEnv_constants_size :
    signerCatalogModuleEnv.constants.size = 0 :=
  rfl

@[simp] theorem signerCatalogModuleEnv_functions_size :
    signerCatalogModuleEnv.functions.size = 2 :=
  rfl

end MovementFormal.MoveModel.SignerCatalog
