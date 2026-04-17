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

def errorCatalogModuleEnv : ModuleEnv :=
  { constants := #[], functions := errorCatalogFunctions }

end MovementFormal.MoveModel.ErrorCatalog
