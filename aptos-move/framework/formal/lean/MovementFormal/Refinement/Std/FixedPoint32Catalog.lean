/-
Copyright (c) Move Industries.

Kernel refinements for FP32 catalog natives (selected `rfl` identities).

**Source:** `aptos-move/framework/move-stdlib/sources/fixed_point32.move`; oracles `MovementFormal.MoveModel.Native.StdPrimitives` (`fp32Oracle*`).
-/

import MovementFormal.MoveModel.Native.StdPrimitives
import MovementFormal.Std.FixedPoint32

namespace MovementFormal.Refinement.Std.FixedPoint32Catalog

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.StdPrimitives
open MovementFormal.Std.FixedPoint32

theorem fp32_native_create_from_raw_u42 :
    fp32CreateFromRaw [.u64 42] = some [fp32ToMoveValue (create_from_raw_value 42)] := rfl

theorem fp32_native_get_raw_u99 :
    fp32GetRawValue [fp32ToMoveValue (create_from_raw_value 99)] = some [.u64 99] := rfl

theorem fp32_native_is_zero_true :
    fp32IsZero [fp32ToMoveValue (create_from_raw_value 0)] = some [.bool true] := rfl

/-- `FixedPoint32` with raw value `2^32` represents `1.0`; `10 * 1.0 = 10`. -/
theorem fp32_native_multiply_ten_by_one :
    fp32MultiplyU64 [.u64 10, fp32ToMoveValue (create_from_raw_value (UInt64.ofNat (2 ^ 32)))] =
      some [.u64 10] := rfl

theorem fp32_native_min_3_5 :
    fp32Min [fp32ToMoveValue (create_from_raw_value 3), fp32ToMoveValue (create_from_raw_value 5)] =
      some [fp32ToMoveValue (create_from_raw_value 3)] := rfl

end MovementFormal.Refinement.Std.FixedPoint32Catalog
