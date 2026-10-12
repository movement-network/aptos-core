/-
Copyright (c) Move Industries.

Closed catalog of `std::error` bytecode used by `move-lean-difftest` (`error` suite) and
`Refinement/Std/Error.lean`. Indices **0–12** are the only definitions in `errorCatalogModuleEnv`.

**Note:** `error.move` in this tree exposes `CANCELLED` as a constant but has **no** `cancelled(r)` wrapper
function; the catalog therefore matches the **12** public wrappers plus `canonical` (13 functions).
`Programs/StdPrimitives.lean` still defines `errorCancelledDesc` for other proofs.

**Source:** `aptos-move/framework/move-stdlib/sources/error.move`
-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Programs.StdPrimitives

namespace MovementFormal.MoveModel.ErrorCatalog

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.StdPrimitives

/-!
## Function table (indices 0–12)

| Idx | Move API |
|-----|----------|
| 0 | `canonical(category, reason)` |
| 1 | `invalid_argument` |
| 2 | `out_of_range` |
| 3 | `invalid_state` |
| 4 | `unauthenticated` |
| 5 | `permission_denied` |
| 6 | `not_found` |
| 7 | `aborted` |
| 8 | `already_exists` |
| 9 | `resource_exhausted` |
| 10 | `internal` |
| 11 | `not_implemented` |
| 12 | `unavailable` |
-/

def errorCatalogFunctions : Array FuncDesc := #[
  errorCanonicalDesc,
  errorInvalidArgumentDesc,
  errorOutOfRangeDesc,
  errorInvalidStateDesc,
  errorUnauthenticatedDesc,
  errorPermissionDeniedDesc,
  errorNotFoundDesc,
  errorAbortedDesc,
  errorAlreadyExistsDesc,
  errorResourceExhaustedDesc,
  errorInternalDesc,
  errorNotImplementedDesc,
  errorUnavailableDesc
]

@[simp] theorem errorCatalogFunctions_size : errorCatalogFunctions.size = 13 := by native_decide

@[simp] theorem errorCatalogFunctions_0_numParams :
    (errorCatalogFunctions[0]'(by decide : 0 < 13)).numParams = 2 :=
  rfl

@[simp] theorem errorCatalogFunctions_0_numReturns :
    (errorCatalogFunctions[0]'(by decide : 0 < 13)).numReturns = 1 :=
  rfl

@[simp] theorem errorCatalogFunctions_1_numParams :
    (errorCatalogFunctions[1]'(by decide : 1 < 13)).numParams = 1 :=
  rfl

@[simp] theorem errorCatalogFunctions_1_numReturns :
    (errorCatalogFunctions[1]'(by decide : 1 < 13)).numReturns = 1 :=
  rfl

def errorCatalogModuleEnv : ModuleEnv :=
  { constants := #[], functions := errorCatalogFunctions }

@[simp] theorem errorCatalogModuleEnv_constants_size :
    errorCatalogModuleEnv.constants.size = 0 :=
  rfl

@[simp] theorem errorCatalogModuleEnv_functions_size :
    errorCatalogModuleEnv.functions.size = 13 :=
  rfl

end MovementFormal.MoveModel.ErrorCatalog
