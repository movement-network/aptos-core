/-
Copyright (c) Move Industries.

Kernel refinements: `optionOracleU64*` catalog natives (`MoveModel/Native/StdPrimitives`) match
`MovementFormal.Std.Option` on scratch-materialized `Option<u64>` values (`optionU64Wire`).

**Source:** `aptos-move/framework/move-stdlib/sources/option.move`; catalog `MovementFormal.MoveModel.OptionCatalog`.
-/

import MovementFormal.MoveModel.Native.StdPrimitives
import MovementFormal.MoveModel.OptionCatalog
import MovementFormal.MoveModel.Step
import MovementFormal.Std.Option

namespace MovementFormal.Refinement.Std.OptionCatalog

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.StdPrimitives
open MovementFormal.MoveModel.OptionCatalog
open MovementFormal.Std.Option

theorem option_catalog_native_is_none_none :
    optionOracleU64IsNone [.bool false, .u64 0] = some [.bool (isNone none')] := rfl

theorem option_catalog_native_is_some_some5 :
    optionOracleU64IsSome [.bool true, .u64 5] = some [.bool (isSome (some' (.u64 5)))] := rfl

theorem option_catalog_native_contains_some5_eq :
    optionOracleU64Contains [.bool true, .u64 5, .u64 5] = some [.bool true] := rfl

theorem option_catalog_native_get_with_default_none :
    optionOracleU64GetWithDefault [.bool false, .u64 0, .u64 99] = some [.u64 99] := rfl

theorem option_catalog_native_borrow_with_default_same_as_get_none :
    optionOracleU64BorrowWithDefault [.bool false, .u64 0, .u64 99] =
      optionOracleU64GetWithDefault [.bool false, .u64 0, .u64 99] := rfl

theorem option_catalog_native_destroy_with_default_same_as_get_some7 :
    optionOracleU64DestroyWithDefault [.bool true, .u64 7, .u64 0] =
      optionOracleU64GetWithDefault [.bool true, .u64 7, .u64 0] := rfl

theorem option_catalog_native_to_vec_none_empty :
    optionOracleU64ToVec [.bool false, .u64 0] = some [.vector .u64 []] := rfl

theorem option_catalog_native_to_vec_some7 :
    optionOracleU64ToVec [.bool true, .u64 7] = some [.vector .u64 [.u64 7]] := rfl

theorem option_catalog_native_from_vec_empty :
    optionOracleU64FromVec [.vector .u64 []] = some (.ok [optionStructValue .u64 none']) := rfl

theorem option_catalog_native_from_vec_singleton99 :
    optionOracleU64FromVec [.vector .u64 [.u64 99]] =
      some (.ok [optionStructValue .u64 (some' (.u64 99))]) := rfl

theorem option_catalog_native_from_vec_two_aborts :
    optionOracleU64FromVec [.vector .u64 [.u64 1, .u64 2]] =
      some (.error MovementFormal.Std.Option.EOPTION_VEC_TOO_LONG) := rfl

/-- Top-level `eval` on the catalog matches VM abort for `from_vec` when `length > 1`. -/
theorem option_catalog_eval_from_vec_abort :
    eval optionCatalogModuleEnv 14 [.vector .u64 [.u64 3, .u64 4]] 10 =
      .aborted EOPTION_VEC_TOO_LONG := rfl

theorem option_catalog_native_std_none :
    optionOracleU64StdNone [] = some [optionStructValue .u64 none'] := rfl

theorem option_catalog_native_std_some_5 :
    optionOracleU64StdSome [.u64 5] = some [optionStructValue .u64 (some' (.u64 5))] := rfl

theorem option_catalog_native_borrow_some42 :
    optionOracleU64Borrow [.bool true, .u64 42] = some (.ok [.u64 42]) := rfl

theorem option_catalog_native_borrow_none_aborts :
    optionOracleU64Borrow [.bool false, .u64 0] = some (.error EOPTION_NOT_SET) := rfl

theorem option_catalog_native_fill_none :
    optionOracleU64Fill [.bool false, .u64 0, .u64 77] = some (.ok []) := rfl

theorem option_catalog_native_fill_some_aborts :
    optionOracleU64Fill [.bool true, .u64 7, .u64 99] = some (.error EOPTION_IS_SET) := rfl

theorem option_catalog_native_extract_some9 :
    optionOracleU64Extract [.bool true, .u64 9] = some (.ok [.u64 9]) := rfl

theorem option_catalog_native_extract_none_aborts :
    optionOracleU64Extract [.bool false, .u64 0] = some (.error EOPTION_NOT_SET) := rfl

theorem option_catalog_native_swap_some10_50 :
    optionOracleU64Swap [.bool true, .u64 10, .u64 50] = some (.ok [.u64 10]) := rfl

theorem option_catalog_native_swap_none_aborts :
    optionOracleU64Swap [.bool false, .u64 0, .u64 50] = some (.error EOPTION_NOT_SET) := rfl

theorem option_catalog_native_swap_or_fill_none_then_some5 :
    optionOracleU64SwapOrFill [.bool false, .u64 0, .u64 5] =
      some [optionStructValue .u64 none'] := rfl

theorem option_catalog_native_swap_or_fill_some1_2 :
    optionOracleU64SwapOrFill [.bool true, .u64 1, .u64 2] =
      some [optionStructValue .u64 (some' (.u64 1))] := rfl

theorem option_catalog_native_destroy_none :
    optionOracleU64DestroyNone [.bool false, .u64 0] = some (.ok []) := rfl

theorem option_catalog_native_destroy_none_some_aborts :
    optionOracleU64DestroyNone [.bool true, .u64 42] = some (.error EOPTION_IS_SET) := rfl

theorem option_catalog_native_destroy_some88 :
    optionOracleU64DestroySome [.bool true, .u64 88] = some (.ok [.u64 88]) := rfl

theorem option_catalog_native_destroy_some_none_aborts :
    optionOracleU64DestroySome [.bool false, .u64 0] = some (.error EOPTION_NOT_SET) := rfl

end MovementFormal.Refinement.Std.OptionCatalog
