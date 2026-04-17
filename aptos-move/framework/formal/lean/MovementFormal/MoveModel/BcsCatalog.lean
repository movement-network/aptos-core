/-
Copyright (c) Move Industries.

Closed catalog of `std::bcs` native behaviors used by `move-lean-difftest` (`bcs` suite) and
`Refinement/Std/Bcs.lean`. Indices **0–26** (`bcsCatalogNatives`).

**Source:** `aptos-move/framework/move-stdlib/sources/bcs.move` (serialization contract); byte layout `MovementFormal.Std.Bcs.Primitives`.
-/

import MovementFormal.MoveModel.State
import MovementFormal.Std.Bcs.Primitives
import MovementFormal.MoveModel.Native

namespace MovementFormal.MoveModel.BcsCatalog

open MovementFormal.MoveModel
open MovementFormal.Std.Bcs
open MovementFormal.MoveModel.Native

/-! ## Helpers -/

partial def vecU8ElemsToByteArrayAux (acc : Array UInt8) : List MoveValue → Option ByteArray
  | [] => some (ByteArray.mk acc)
  | .u8 b :: rest => vecU8ElemsToByteArrayAux (acc.push b) rest
  | _ :: _ => none

/-- Extract raw `vector<u8>` payload as `ByteArray` (for BCS catalog). -/
def vecU8ElemsToByteArray (elems : List MoveValue) : Option ByteArray :=
  vecU8ElemsToByteArrayAux #[] elems

/-! ## `bcs::to_bytes` -/

def bcsToBytes_vecU8 : List MoveValue → Option (List MoveValue)
  | [.vector .u8 elems] =>
    match vecU8ElemsToByteArray elems with
    | some ba => some [bytesToMoveVec (vectorU8Bcs ba)]
    | none => none
  | _ => none

def bcsToBytes_address : List MoveValue → Option (List MoveValue)
  | [.address bs] => some [bytesToMoveVec (addressBcs bs)]
  | _ => none

/-! ## `bcs::serialized_size` -/

def bcsSerializedSize_u8 : List MoveValue → Option (List MoveValue)
  | [.u8 x] => some [.u64 (UInt64.ofNat (serializedByteLen (u8Bytes x)))]
  | _ => none

def bcsSerializedSize_u64 : List MoveValue → Option (List MoveValue)
  | [.u64 x] => some [.u64 (UInt64.ofNat (serializedByteLen (u64Le x)))]
  | _ => none

def bcsSerializedSize_u128 : List MoveValue → Option (List MoveValue)
  | [.u128 x] => some [.u64 (UInt64.ofNat (serializedByteLen (u128LeNat x.val)))]
  | _ => none

def bcsSerializedSize_bool : List MoveValue → Option (List MoveValue)
  | [.bool b] => some [.u64 (UInt64.ofNat (serializedByteLen (boolBytes b)))]
  | _ => none

def bcsSerializedSize_vecU8 : List MoveValue → Option (List MoveValue)
  | [.vector .u8 elems] =>
    match vecU8ElemsToByteArray elems with
    | some ba => some [.u64 (UInt64.ofNat (serializedByteLen (vectorU8Bcs ba)))]
    | none => none
  | _ => none

def bcsSerializedSize_address : List MoveValue → Option (List MoveValue)
  | [.address bs] => some [.u64 (UInt64.ofNat (serializedByteLen (addressBcs bs)))]
  | _ => none

def bcsSerializedSize_u16 : List MoveValue → Option (List MoveValue)
  | [.u16 x] => some [.u64 (UInt64.ofNat (serializedByteLen (u16Le x)))]
  | _ => none

def bcsSerializedSize_u32 : List MoveValue → Option (List MoveValue)
  | [.u32 x] => some [.u64 (UInt64.ofNat (serializedByteLen (u32Le x)))]
  | _ => none

def bcsSerializedSize_u256 : List MoveValue → Option (List MoveValue)
  | [.u256 x] => some [.u64 (UInt64.ofNat (serializedByteLen (u256LeNat x.val)))]
  | _ => none

/-! ## `bcs::constant_serialized_size` (fixed-width types + vector<u8> sentinel) -/

def bcsConstantSize_u8 : List MoveValue → Option (List MoveValue)
  | [] =>
    match constantSerializedSizeU8 with
    | some n => some [.u64 (UInt64.ofNat n)]
    | none => none
  | _ => none

def bcsConstantSize_u64 : List MoveValue → Option (List MoveValue)
  | [] =>
    match constantSerializedSizeU64 with
    | some n => some [.u64 (UInt64.ofNat n)]
    | none => none
  | _ => none

def bcsConstantSize_u128 : List MoveValue → Option (List MoveValue)
  | [] =>
    match constantSerializedSizeU128 with
    | some n => some [.u64 (UInt64.ofNat n)]
    | none => none
  | _ => none

def bcsConstantSize_bool : List MoveValue → Option (List MoveValue)
  | [] =>
    match constantSerializedSizeBool with
    | some n => some [.u64 (UInt64.ofNat n)]
    | none => none
  | _ => none

def bcsConstantSize_address : List MoveValue → Option (List MoveValue)
  | [] =>
    match constantSerializedSizeAddress with
    | some n => some [.u64 (UInt64.ofNat n)]
    | none => none
  | _ => none

def bcsConstantSize_u16 : List MoveValue → Option (List MoveValue)
  | [] =>
    match constantSerializedSizeU16 with
    | some n => some [.u64 (UInt64.ofNat n)]
    | none => none
  | _ => none

def bcsConstantSize_u32 : List MoveValue → Option (List MoveValue)
  | [] =>
    match constantSerializedSizeU32 with
    | some n => some [.u64 (UInt64.ofNat n)]
    | none => none
  | _ => none

def bcsConstantSize_u256 : List MoveValue → Option (List MoveValue)
  | [] =>
    match constantSerializedSizeU256 with
    | some n => some [.u64 (UInt64.ofNat n)]
    | none => none
  | _ => none

/-- `option::is_none(bcs::constant_serialized_size<vector<u8>>())` — Lean mirrors VM (`none`). -/
def bcsConstantVecU8IsNone : List MoveValue → Option (List MoveValue)
  | [] =>
    match constantSerializedSizeVectorU8 with
    | none => some [.bool true]
    | some _ => some [.bool false]
  | _ => none

/-!
## Function table (indices 0–26)

| Idx | Role |
|-----|------|
| 0–3 | `bcs::to_bytes` for `u8`,`u64`,`u128`,`bool` (delegates to `Native`) |
| 4–5 | `to_bytes` for `vector<u8>`, `address` |
| 6–11 | `serialized_size` for the same six shapes |
| 12–16 | `constant_serialized_size` unwrap (`u8`…`address`) |
| 17 | `vector<u8>` has **no** constant width (`is_none` test) |
| 18–20 | `u16`: `to_bytes`, `serialized_size`, `constant_serialized_size` |
| 21–23 | `u32` |
| 24–26 | `u256` |
-/

def bcsCatalogNatives : Array FuncDesc := #[
  { numParams := 1, numReturns := 1, body := .native bcsToBytes_u8 },
  { numParams := 1, numReturns := 1, body := .native bcsToBytes_u64 },
  { numParams := 1, numReturns := 1, body := .native bcsToBytes_u128 },
  { numParams := 1, numReturns := 1, body := .native bcsToBytes_bool },
  { numParams := 1, numReturns := 1, body := .native bcsToBytes_vecU8 },
  { numParams := 1, numReturns := 1, body := .native bcsToBytes_address },
  { numParams := 1, numReturns := 1, body := .native bcsSerializedSize_u8 },
  { numParams := 1, numReturns := 1, body := .native bcsSerializedSize_u64 },
  { numParams := 1, numReturns := 1, body := .native bcsSerializedSize_u128 },
  { numParams := 1, numReturns := 1, body := .native bcsSerializedSize_bool },
  { numParams := 1, numReturns := 1, body := .native bcsSerializedSize_vecU8 },
  { numParams := 1, numReturns := 1, body := .native bcsSerializedSize_address },
  { numParams := 0, numReturns := 1, body := .native bcsConstantSize_u8 },
  { numParams := 0, numReturns := 1, body := .native bcsConstantSize_u64 },
  { numParams := 0, numReturns := 1, body := .native bcsConstantSize_u128 },
  { numParams := 0, numReturns := 1, body := .native bcsConstantSize_bool },
  { numParams := 0, numReturns := 1, body := .native bcsConstantSize_address },
  { numParams := 0, numReturns := 1, body := .native bcsConstantVecU8IsNone },
  { numParams := 1, numReturns := 1, body := .native bcsToBytes_u16 },
  { numParams := 1, numReturns := 1, body := .native bcsSerializedSize_u16 },
  { numParams := 0, numReturns := 1, body := .native bcsConstantSize_u16 },
  { numParams := 1, numReturns := 1, body := .native bcsToBytes_u32 },
  { numParams := 1, numReturns := 1, body := .native bcsSerializedSize_u32 },
  { numParams := 0, numReturns := 1, body := .native bcsConstantSize_u32 },
  { numParams := 1, numReturns := 1, body := .native bcsToBytes_u256 },
  { numParams := 1, numReturns := 1, body := .native bcsSerializedSize_u256 },
  { numParams := 0, numReturns := 1, body := .native bcsConstantSize_u256 }
]

@[simp] theorem bcsCatalogNatives_size : bcsCatalogNatives.size = 27 := by native_decide

def bcsCatalogModuleEnv : ModuleEnv :=
  { constants := #[], functions := bcsCatalogNatives }

end MovementFormal.MoveModel.BcsCatalog
