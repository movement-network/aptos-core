/-
Copyright (c) Move Industries.

Kernel refinements: catalog natives `bitVector*` match `MovementFormal.Std.BitVector` on concrete
`MvBitVector` wires (`mvBitVectorToMoveValue`).

**Source:** `aptos-move/framework/move-stdlib/sources/bit_vector.move`; catalog `MovementFormal.MoveModel.BitVectorCatalog`.
-/

import MovementFormal.MoveModel.Native.StdPrimitives
import MovementFormal.Std.BitVector

namespace MovementFormal.Refinement.Std.BitVectorCatalog

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.StdPrimitives
open MovementFormal.Std.BitVector

theorem bitVectorNew_8_matches_std :
    bitVectorNew [.u64 8] =
      match new 8 with
      | .ok bv => some [mvBitVectorToMoveValue bv]
      | .error _ => none := rfl

theorem bitVectorNew_16_matches_std :
    bitVectorNew [.u64 16] =
      match new 16 with
      | .ok bv => some [mvBitVectorToMoveValue bv]
      | .error _ => none := rfl

theorem bitVectorSet_index0_on_new8 :
    bitVectorSet [.struct_ [.u64 8, .vector .bool (List.replicate 8 (MoveValue.bool false))], .u64 0] =
      match new 8 with
      | .ok bv =>
        match set bv 0 with
        | .ok bv' => some [mvBitVectorToMoveValue bv']
        | .error _ => none
      | .error _ => none := rfl

theorem bitVectorUnset_index1_on_preset :
    bitVectorUnset [
        .struct_ [.u64 5, .vector .bool [MoveValue.bool true, .bool false, .bool false, .bool false, .bool false]],
        .u64 0] =
      match new 5 with
      | .ok bv =>
        match set bv 0 with
        | .ok bv1 =>
          match unset bv1 0 with
          | .ok bv2 => some [mvBitVectorToMoveValue bv2]
          | .error _ => none
        | .error _ => none
      | .error _ => none := rfl

theorem bitVectorIsIndexSet_query_unset_bit :
    bitVectorIsIndexSet [.struct_ [.u64 6, .vector .bool (List.replicate 6 (MoveValue.bool false))], .u64 3] =
      match new 6 with
      | .ok bv => match is_index_set bv 3 with | .ok b => some [.bool b] | .error _ => none
      | .error _ => none := rfl

theorem bitVectorShiftLeft_len8_amt2 :
    bitVectorShiftLeft [.struct_ [.u64 8, .vector .bool (List.replicate 8 (MoveValue.bool false))], .u64 2] =
      match new 8 with
      | .ok bv => some [mvBitVectorToMoveValue (shift_left bv 2)]
      | .error _ => none := rfl

end MovementFormal.Refinement.Std.BitVectorCatalog
