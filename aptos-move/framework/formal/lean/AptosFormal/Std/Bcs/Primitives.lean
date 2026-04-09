/-
Copyright (c) Move Industries.

Minimal BCS serializers matching Move `std::bcs::to_bytes` for a few primitive shapes.
Vectors use unsigned LEB128 length prefixes (values `< 128` are a single byte).

- BCS spec: <https://github.com/diem/bcs>
- Move module: `aptos-move/framework/move-stdlib/sources/bcs.move`
- Goldens: `aptos-move/framework/move-stdlib/tests/bcs_tests.move`
-/

import Init.Data.List.Basic

namespace AptosFormal.Std.Bcs

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

/-- BCS `vector<u8>`: `uleb128(len)` then raw bytes (`len < 128`). -/
def vectorU8Short (data : ByteArray) (_h : data.size < 128) : ByteArray :=
  (ByteArray.mk #[UInt8.ofNat data.size]) ++ data

end AptosFormal.Std.Bcs
