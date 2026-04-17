/-
Copyright (c) Move Industries.

Kernel refinements: **`MovementFormal.Std.Bcs`** serializers match the catalog natives in
`MovementFormal.MoveModel.BcsCatalog` (same definitions as `MoveModel.Native` for primitives).
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

/-! ## `constant_serialized_size` catalog -/

theorem constant_size_u64_is_eight :
    BcsCatalog.bcsConstantSize_u64 [] = some [.u64 8] := rfl

theorem constant_vec_u8_is_none :
    BcsCatalog.bcsConstantVecU8IsNone [] = some [.bool true] := rfl

end MovementFormal.Refinement.Std.Bcs
