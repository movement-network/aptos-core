/-
Copyright (c) Move Industries.

Refinement lemmas for `MovementFormal.Std.Cmp` on representative scalar pairs including `u128`, `u16`, `u32`, `u256`
(aligned with the `cmp` difftest suite).

**Source:** `aptos-move/framework/move-stdlib/sources/cmp.move`; catalog `MovementFormal.MoveModel.CmpCatalog`.
-/

import MovementFormal.MoveModel.Value
import MovementFormal.Std.Cmp

namespace MovementFormal.Refinement.Std.CmpCatalog

open MovementFormal.Std.Cmp
open MovementFormal.MoveModel (U128 U256)

private def a1 : UInt64 := UInt64.ofNat 1
private def a2 : UInt64 := UInt64.ofNat 2
private def a3 : UInt64 := UInt64.ofNat 3
private def a5 : UInt64 := UInt64.ofNat 5
private def a9 : UInt64 := UInt64.ofNat 9
private def a0 : UInt64 := UInt64.ofNat 0
private def aMax : UInt64 := UInt64.ofNat (2 ^ 64 - 1)

theorem cmp_lt_1_2 : isLt (compareU64 a1 a2) = true := rfl
theorem cmp_eq_5_5 : isEq (compareU64 a5 a5) = true := rfl
theorem cmp_gt_9_3 : isGt (compareU64 a9 a3) = true := rfl
theorem cmp_eq_0_0 : isEq (compareU64 a0 a0) = true := rfl
theorem cmp_lt_0_max : isLt (compareU64 a0 aMax) = true := rfl
theorem cmp_gt_max_0 : isGt (compareU64 aMax a0) = true := rfl

theorem cmp_is_ne_1_2 : isNe (compareU64 a1 a2) = true := rfl
theorem cmp_is_le_1_2 : isLe (compareU64 a1 a2) = true := rfl
theorem cmp_is_ge_5_5 : isGe (compareU64 a5 a5) = true := rfl

theorem cmp_bool_lt_ft : isLt (compareBool false true) = true := rfl
theorem cmp_bool_eq_ff : isEq (compareBool false false) = true := rfl
theorem cmp_bool_gt_tf : isGt (compareBool true false) = true := rfl

private def u8_0 : UInt8 := UInt8.ofNat 0
private def u8_1 : UInt8 := UInt8.ofNat 1
private def u8_5 : UInt8 := UInt8.ofNat 5
private def u8_200 : UInt8 := UInt8.ofNat 200
private def u8_255 : UInt8 := UInt8.ofNat 255

theorem cmp_u8_lt_0_1 : isLt (compareU8 u8_0 u8_1) = true := rfl
theorem cmp_u8_eq_5_5 : isEq (compareU8 u8_5 u8_5) = true := rfl
theorem cmp_u8_gt_200_3 : isGt (compareU8 u8_200 (UInt8.ofNat 3)) = true := rfl
theorem cmp_u8_gt_255_0 : isGt (compareU8 u8_255 u8_0) = true := rfl

private def addrAllZero : ByteArray :=
  ByteArray.mk (Array.replicate 32 (UInt8.ofNat 0))

private def addrLastByte1 : ByteArray :=
  ByteArray.mk ((List.replicate 31 (UInt8.ofNat 0) ++ [UInt8.ofNat 1]).toArray)

private def addrFirstByte1 : ByteArray :=
  ByteArray.mk (([UInt8.ofNat 1] ++ List.replicate 31 (UInt8.ofNat 0)).toArray)

theorem cmp_addr_eq_zero : isEq (compareAddress addrAllZero addrAllZero) = true := by native_decide

theorem cmp_addr_lt_zero_last : isLt (compareAddress addrAllZero addrLastByte1) = true := by native_decide

theorem cmp_addr_gt_first_zero : isGt (compareAddress addrFirstByte1 addrAllZero) = true := by native_decide

theorem cmp_addr_lt_last_first : isLt (compareAddress addrLastByte1 addrFirstByte1) = true := by native_decide

theorem cmp_addr_eq_first : isEq (compareAddress addrFirstByte1 addrFirstByte1) = true := by native_decide

private def u16_0 : UInt16 := UInt16.ofNat 0
private def u16_1 : UInt16 := UInt16.ofNat 1
private def u16_100 : UInt16 := UInt16.ofNat 100
private def u16_50 : UInt16 := UInt16.ofNat 50

theorem cmp_u16_lt_0_1 : isLt (compareU16 u16_0 u16_1) = true := rfl
theorem cmp_u16_eq_100_100 : isEq (compareU16 u16_100 u16_100) = true := rfl
theorem cmp_u16_gt_100_50 : isGt (compareU16 u16_100 u16_50) = true := rfl

private def u32_0 : UInt32 := UInt32.ofNat 0
private def u32_1 : UInt32 := UInt32.ofNat 1
private def u32_9 : UInt32 := UInt32.ofNat 9
private def u32_3 : UInt32 := UInt32.ofNat 3

theorem cmp_u32_lt_0_1 : isLt (compareU32 u32_0 u32_1) = true := rfl
theorem cmp_u32_eq_5_5 : isEq (compareU32 (UInt32.ofNat 5) (UInt32.ofNat 5)) = true := rfl
theorem cmp_u32_gt_9_3 : isGt (compareU32 u32_9 u32_3) = true := rfl

private def u128_0 : U128 := ⟨0, by omega⟩
private def u128_1 : U128 := ⟨1, by omega⟩
private def u128_5a : U128 := ⟨5, by omega⟩
private def u128_big : U128 := ⟨12345678901234567890, by native_decide⟩

theorem cmp_u128_lt_0_1 : isLt (compareU128 u128_0 u128_1) = true := by native_decide

theorem cmp_u128_eq_5_5 : isEq (compareU128 u128_5a u128_5a) = true := by native_decide

theorem cmp_u128_gt_big_0 : isGt (compareU128 u128_big u128_0) = true := by native_decide

private def u256_0 : U256 := ⟨0, by omega⟩
private def u256_1 : U256 := ⟨1, by omega⟩
private def u256_5a : U256 := ⟨5, by omega⟩

private def u256_big : U256 :=
  ⟨123456789012345678901234567890123456789012345678901234567890, by native_decide⟩

theorem cmp_u256_lt_0_1 : isLt (compareU256 u256_0 u256_1) = true := by native_decide

theorem cmp_u256_eq_5_5 : isEq (compareU256 u256_5a u256_5a) = true := by native_decide

theorem cmp_u256_gt_big_0 : isGt (compareU256 u256_big u256_0) = true := by native_decide

end MovementFormal.Refinement.Std.CmpCatalog
