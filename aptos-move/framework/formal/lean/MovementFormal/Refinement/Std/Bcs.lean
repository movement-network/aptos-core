/-
Copyright (c) Move Industries.

Kernel refinements: **`MovementFormal.Std.Bcs`** serializers match the catalog natives in
`MovementFormal.MoveModel.BcsCatalog` (same definitions as `MoveModel.Native` for primitives).

**Source:** `aptos-move/framework/move-stdlib/sources/bcs.move`; spec `MovementFormal.Std.Bcs.Primitives`.
-/

import MovementFormal.MoveModel.BcsCatalog
import MovementFormal.MoveModel.Native

namespace MovementFormal.Refinement.Std.Bcs

open MovementFormal.MoveModel
open MovementFormal.Std.Bcs

/-! ## `bcs::to_bytes` vs catalog natives -/

theorem bcsNative_u8_matches (x : UInt8) :
    Native.bcsToBytes_u8 [.u8 x] = some [Native.bytesToMoveVec (u8Bytes x)] := rfl

theorem bcsNative_u64_matches (x : UInt64) :
    Native.bcsToBytes_u64 [.u64 x] = some [Native.bytesToMoveVec (u64Le x)] := rfl

theorem bcsNative_u128_matches (x : U128) :
    Native.bcsToBytes_u128 [.u128 x] = some [Native.bytesToMoveVec (u128LeNat x.val)] := rfl

theorem bcsNative_u16_matches (x : UInt16) :
    Native.bcsToBytes_u16 [.u16 x] = some [Native.bytesToMoveVec (u16Le x)] := rfl

theorem bcsNative_u32_matches (x : UInt32) :
    Native.bcsToBytes_u32 [.u32 x] = some [Native.bytesToMoveVec (u32Le x)] := rfl

theorem bcsNative_u256_matches (x : U256) :
    Native.bcsToBytes_u256 [.u256 x] = some [Native.bytesToMoveVec (u256LeNat x.val)] := rfl

theorem bcsNative_bool_matches (b : Bool) :
    Native.bcsToBytes_bool [.bool b] = some [Native.bytesToMoveVec (boolBytes b)] := rfl

theorem bcsNative_vec_u8_def (elems : List MoveValue) :
    BcsCatalog.bcsToBytes_vecU8 [.vector .u8 elems] =
      (match BcsCatalog.vecU8ElemsToByteArray elems with
        | some ba => some [Native.bytesToMoveVec (vectorU8Bcs ba)]
        | none => none) := by
  rfl

theorem bcsNative_address_matches (bs : ByteArray) :
    BcsCatalog.bcsToBytes_address [.address bs] = some [Native.bytesToMoveVec (addressBcs bs)] := rfl

/-! ## `serialized_size` equals byte length of the BCS encoding -/

theorem serialized_size_u8_eq (x : UInt8) :
    BcsCatalog.bcsSerializedSize_u8 [.u8 x] =
      some [.u64 (UInt64.ofNat (serializedByteLen (u8Bytes x)))] := rfl

theorem serialized_size_u64_eq (x : UInt64) :
    BcsCatalog.bcsSerializedSize_u64 [.u64 x] =
      some [.u64 (UInt64.ofNat (serializedByteLen (u64Le x)))] := rfl

theorem serialized_size_bool_eq (b : Bool) :
    BcsCatalog.bcsSerializedSize_bool [.bool b] =
      some [.u64 (UInt64.ofNat (serializedByteLen (boolBytes b)))] := rfl

theorem serialized_size_u128_eq (x : U128) :
    BcsCatalog.bcsSerializedSize_u128 [.u128 x] =
      some [.u64 (UInt64.ofNat (serializedByteLen (u128LeNat x.val)))] := rfl

theorem serialized_size_u16_eq (x : UInt16) :
    BcsCatalog.bcsSerializedSize_u16 [.u16 x] =
      some [.u64 (UInt64.ofNat (serializedByteLen (u16Le x)))] := rfl

theorem serialized_size_u32_eq (x : UInt32) :
    BcsCatalog.bcsSerializedSize_u32 [.u32 x] =
      some [.u64 (UInt64.ofNat (serializedByteLen (u32Le x)))] := rfl

theorem serialized_size_u256_eq (x : U256) :
    BcsCatalog.bcsSerializedSize_u256 [.u256 x] =
      some [.u64 (UInt64.ofNat (serializedByteLen (u256LeNat x.val)))] := rfl

theorem serialized_size_vec_u8_eq_elems (elems : List MoveValue) (ba : ByteArray)
    (hvec : BcsCatalog.vecU8ElemsToByteArray elems = some ba) :
    BcsCatalog.bcsSerializedSize_vecU8 [.vector .u8 elems] =
      some [.u64 (UInt64.ofNat (serializedByteLen (vectorU8Bcs ba)))] := by
  simp [BcsCatalog.bcsSerializedSize_vecU8, hvec]

theorem serialized_size_address_eq (bs : ByteArray) :
    BcsCatalog.bcsSerializedSize_address [.address bs] =
      some [.u64 (UInt64.ofNat (serializedByteLen (addressBcs bs)))] := rfl

/-! ## `constant_serialized_size` vs `Std.Bcs` constants -/

theorem constant_size_u8_is_one :
    BcsCatalog.bcsConstantSize_u8 [] = some [.u64 1] := rfl

theorem constant_size_u64_is_eight :
    BcsCatalog.bcsConstantSize_u64 [] = some [.u64 8] := rfl

theorem constant_size_u128_is_sixteen :
    BcsCatalog.bcsConstantSize_u128 [] = some [.u64 16] := rfl

theorem constant_size_u16_is_two :
    BcsCatalog.bcsConstantSize_u16 [] = some [.u64 2] := rfl

theorem constant_size_u32_is_four :
    BcsCatalog.bcsConstantSize_u32 [] = some [.u64 4] := rfl

theorem constant_size_u256_is_thirtytwo :
    BcsCatalog.bcsConstantSize_u256 [] = some [.u64 32] := rfl

theorem constant_size_bool_is_one :
    BcsCatalog.bcsConstantSize_bool [] = some [.u64 1] := rfl

theorem constant_size_address_is_thirtytwo :
    BcsCatalog.bcsConstantSize_address [] = some [.u64 32] := rfl

theorem constant_vec_u8_is_none :
    BcsCatalog.bcsConstantVecU8IsNone [] = some [.bool true] := rfl

/-! ## Fixed widths agree with `serializedByteLen` of canonical zero-sized encodings -/

theorem constantSerializedSizeU8_eq_byteLen_u8_zero :
    constantSerializedSizeU8 = some (serializedByteLen (u8Bytes 0)) := rfl

theorem constantSerializedSizeU64_eq_byteLen_u64_zero :
    constantSerializedSizeU64 = some (serializedByteLen (u64Le 0)) := rfl

theorem constantSerializedSizeU128_eq_byteLen_u128_zero :
    constantSerializedSizeU128 = some (serializedByteLen (u128LeNat 0)) := rfl

theorem constantSerializedSizeU16_eq_byteLen_u16_zero :
    constantSerializedSizeU16 = some (serializedByteLen (u16Le 0)) := rfl

theorem constantSerializedSizeU32_eq_byteLen_u32_zero :
    constantSerializedSizeU32 = some (serializedByteLen (u32Le 0)) := rfl

theorem constantSerializedSizeU256_eq_byteLen_u256_zero :
    constantSerializedSizeU256 = some (serializedByteLen (u256LeNat 0)) := rfl

theorem constantSerializedSizeBool_eq_byteLen_false :
    constantSerializedSizeBool = some (serializedByteLen (boolBytes false)) := rfl

theorem constantSerializedSizeAddress_eq_byteLen_address (bs : ByteArray) (h : bs.size = 32) :
    constantSerializedSizeAddress = some (serializedByteLen (addressBcs bs)) := by
  simp [constantSerializedSizeAddress, serializedByteLen, addressBcs, h]

end MovementFormal.Refinement.Std.Bcs
