/-
Copyright (c) Move Industries.

Minimal BCS serializers matching Move `std::bcs::to_bytes` for a few primitive shapes.
Vectors use unsigned LEB128 length prefixes (values `< 128` are a single byte).

- BCS spec: <https://github.com/diem/bcs>
- Move module: `aptos-move/framework/move-stdlib/sources/bcs.move`
- Goldens: `aptos-move/framework/move-stdlib/tests/bcs_tests.move`
-/

import Init.Data.List.Basic

namespace MovementFormal.Std.Bcs

/-- BCS `u8`: the single raw byte. -/
def u8Bytes (x : UInt8) : ByteArray :=
  ByteArray.mk #[x]

/-- Little-endian `u64` (8 bytes). -/
def u64Le (x : UInt64) : ByteArray :=
  (List.range 8).foldl (fun acc i =>
    acc.push ((x >>> UInt64.ofNat (8 * i)).toUInt8)) ByteArray.empty

/-- Little-endian `u128` as 16 bytes from a `Nat` (for small constants used in goldens). -/
def u128LeNat (n : Nat) : ByteArray :=
  (List.range 16).foldl (fun acc i =>
    acc.push (UInt8.ofNat ((n >>> (8 * i)) % 256))) ByteArray.empty

/-- BCS `bool`: `0x00` false, `0x01` true. -/
def boolBytes (b : Bool) : ByteArray :=
  if b then ByteArray.mk #[1] else ByteArray.mk #[0]

/-- Unsigned LEB128 (BCS length prefix for vectors): least-significant 7 bits first. -/
partial def uleb128BytesAux (n : Nat) : List UInt8 :=
  if n < 128 then [UInt8.ofNat n]
  else UInt8.ofNat ((n % 128) + 128) :: uleb128BytesAux (n / 128)

def uleb128Bytes (n : Nat) : ByteArray :=
  ByteArray.mk (uleb128BytesAux n).toArray

/-- BCS `vector<u8>`: `uleb128(len)` then raw payload (any length). -/
def vectorU8Bcs (data : ByteArray) : ByteArray :=
  uleb128Bytes data.size ++ data

/-- Legacy helper: when `len < 128`, `uleb128(len)` is one byte — matches `vectorU8Bcs`. -/
def vectorU8Short (data : ByteArray) (_h : data.size < 128) : ByteArray :=
  vectorU8Bcs data -- proof documents the `bcs_tests` / goldens regime; encoding is general-length

/-- Aptos `address` BCS: **32 raw account bytes** (no outer length prefix). -/
def addressBcs (bytes32 : ByteArray) : ByteArray :=
  bytes32

/-- Total serialized byte length for a value already encoded as `ByteArray`. -/
def serializedByteLen (b : ByteArray) : Nat :=
  b.size

/-- `std::bcs::constant_serialized_size<T>()` when it is `some(n)` for fixed-width scalars. -/
def constantSerializedSizeU8 : Option Nat := some 1
def constantSerializedSizeU64 : Option Nat := some 8
def constantSerializedSizeU128 : Option Nat := some 16
def constantSerializedSizeBool : Option Nat := some 1
def constantSerializedSizeAddress : Option Nat := some 32
def constantSerializedSizeVectorU8 : Option Nat := none

end MovementFormal.Std.Bcs
