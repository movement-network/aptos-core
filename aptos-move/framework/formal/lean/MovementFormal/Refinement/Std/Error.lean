import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.ErrorCatalog
import MovementFormal.Std.Error

/-!
# Refinement: `errorCatalogModuleEnv` vs `MovementFormal.Std.Error`

**Source:** `aptos-move/framework/move-stdlib/sources/error.move`; catalog `MovementFormal.MoveModel.ErrorCatalog`.

The VM↔Lean `error` difftest uses `MoveModel.ErrorCatalog.errorCatalogModuleEnv` (indices **0–12**),
which contains the **same** `FuncDesc` values as `Refinement/Std/StdPrimitives` single-function envs,
but **without** the `stdNatives` prefix — function **0** is `error::canonical`, etc.

Each theorem is a schematic `rfl` proof (finite unrolling, no loops).
-/

namespace MovementFormal.Refinement.Std.Error

open MovementFormal.MoveModel
open MovementFormal.MoveModel.ErrorCatalog
open MovementFormal.MoveModel.Programs.StdPrimitives
open MovementFormal.Std.Error

private abbrev evalCat (idx : Nat) (args : List MoveValue) (fuel : Nat) :=
  eval errorCatalogModuleEnv idx args fuel

/-! ## `canonical` -/

theorem errorCatalog_canonical_refines (cat reason : UInt64) :
    evalCat 0 [.u64 cat, .u64 reason] 20 =
      .returned [.u64 (canonical cat reason)] MachineState.empty := by
  simp only [evalCat, errorCatalogModuleEnv, canonical, errorCatalogFunctions, errorCanonicalDesc,
    errorCanonicalCode]
  rfl

/-! ## Category wrappers -/

theorem errorCatalog_invalid_argument_refines (r : UInt64) :
    evalCat 1 [.u64 r] 20 = .returned [.u64 (invalid_argument r)] MachineState.empty := by
  simp only [evalCat, errorCatalogModuleEnv, invalid_argument, canonical, errorCatalogFunctions,
    errorInvalidArgumentDesc, mkErrDesc, mkErrCode]
  rfl

theorem errorCatalog_out_of_range_refines (r : UInt64) :
    evalCat 2 [.u64 r] 20 = .returned [.u64 (out_of_range r)] MachineState.empty := by
  simp only [evalCat, errorCatalogModuleEnv, out_of_range, canonical, errorCatalogFunctions,
    errorOutOfRangeDesc, mkErrDesc, mkErrCode]
  rfl

theorem errorCatalog_invalid_state_refines (r : UInt64) :
    evalCat 3 [.u64 r] 20 = .returned [.u64 (invalid_state r)] MachineState.empty := by
  simp only [evalCat, errorCatalogModuleEnv, invalid_state, canonical, errorCatalogFunctions,
    errorInvalidStateDesc, mkErrDesc, mkErrCode]
  rfl

theorem errorCatalog_unauthenticated_refines (r : UInt64) :
    evalCat 4 [.u64 r] 20 = .returned [.u64 (unauthenticated r)] MachineState.empty := by
  simp only [evalCat, errorCatalogModuleEnv, unauthenticated, canonical, errorCatalogFunctions,
    errorUnauthenticatedDesc, mkErrDesc, mkErrCode]
  rfl

theorem errorCatalog_permission_denied_refines (r : UInt64) :
    evalCat 5 [.u64 r] 20 = .returned [.u64 (permission_denied r)] MachineState.empty := by
  simp only [evalCat, errorCatalogModuleEnv, permission_denied, canonical, errorCatalogFunctions,
    errorPermissionDeniedDesc, mkErrDesc, mkErrCode]
  rfl

theorem errorCatalog_not_found_refines (r : UInt64) :
    evalCat 6 [.u64 r] 20 = .returned [.u64 (not_found r)] MachineState.empty := by
  simp only [evalCat, errorCatalogModuleEnv, not_found, canonical, errorCatalogFunctions,
    errorNotFoundDesc, mkErrDesc, mkErrCode]
  rfl

theorem errorCatalog_aborted_refines (r : UInt64) :
    evalCat 7 [.u64 r] 20 = .returned [.u64 (aborted r)] MachineState.empty := by
  simp only [evalCat, errorCatalogModuleEnv, aborted, canonical, errorCatalogFunctions,
    errorAbortedDesc, mkErrDesc, mkErrCode]
  rfl

theorem errorCatalog_already_exists_refines (r : UInt64) :
    evalCat 8 [.u64 r] 20 = .returned [.u64 (already_exists r)] MachineState.empty := by
  simp only [evalCat, errorCatalogModuleEnv, already_exists, canonical, errorCatalogFunctions,
    errorAlreadyExistsDesc, mkErrDesc, mkErrCode]
  rfl

theorem errorCatalog_resource_exhausted_refines (r : UInt64) :
    evalCat 9 [.u64 r] 20 = .returned [.u64 (resource_exhausted r)] MachineState.empty := by
  simp only [evalCat, errorCatalogModuleEnv, resource_exhausted, canonical, errorCatalogFunctions,
    errorResourceExhaustedDesc, mkErrDesc, mkErrCode]
  rfl

theorem errorCatalog_internal_refines (r : UInt64) :
    evalCat 10 [.u64 r] 20 = .returned [.u64 (internal r)] MachineState.empty := by
  simp only [evalCat, errorCatalogModuleEnv, internal, canonical, errorCatalogFunctions,
    errorInternalDesc, mkErrDesc, mkErrCode]
  rfl

theorem errorCatalog_not_implemented_refines (r : UInt64) :
    evalCat 11 [.u64 r] 20 = .returned [.u64 (not_implemented r)] MachineState.empty := by
  simp only [evalCat, errorCatalogModuleEnv, not_implemented, canonical, errorCatalogFunctions,
    errorNotImplementedDesc, mkErrDesc, mkErrCode]
  rfl

theorem errorCatalog_unavailable_refines (r : UInt64) :
    evalCat 12 [.u64 r] 20 = .returned [.u64 (unavailable r)] MachineState.empty := by
  simp only [evalCat, errorCatalogModuleEnv, unavailable, canonical, errorCatalogFunctions,
    errorUnavailableDesc, mkErrDesc, mkErrCode]
  rfl

end MovementFormal.Refinement.Std.Error
