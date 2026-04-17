/-
Copyright (c) Move Industries.

Shared Keccak-f[1600] sponge used by SHA3-256 and SHA3-512 models in `MovementFormal`.
Layout matches `tiny-keccak` / RustCrypto `sha3` (delimiter `0x06` for SHA3).

- NIST FIPS 202: <https://doi.org/10.6028/NIST.FIPS.202>
- Keccak reference: <https://keccak.team/keccak.html>
-/

import Batteries.Data.List.Basic
import Init.Data.Nat.Lemmas

namespace MovementFormal.Std.Hash.Keccak

/-- Circular left shift on 64 bits (`u64::rotate_left` in Rust; amount reduced mod 64). -/
def u64RotateLeft (x : UInt64) (n : Nat) : UInt64 :=
  let r := UInt64.ofNat (n % 64)
  (x <<< r) ||| (x >>> UInt64.ofNat (64 - (n % 64)))

def rho : List Nat :=
  [1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, 27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44]

def piIdx : List Nat :=
  [10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1]

def keccakRC : Array UInt64 :=
  #[0x1, 0x8082, 0x800000000000808a, 0x8000000080008000, 0x808b, 0x80000001,
    0x8000000080008081, 0x8000000000008009, 0x8a, 0x88, 0x80008009, 0x8000000a,
    0x8000808b, 0x800000000000008b, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x800a, 0x800000008000000a,
    0x8000000080008081, 0x8000000000008080, 0x80000001, 0x8000000080008008]

/-- One Keccak-f round (tiny-keccak `keccak_function!`). -/
def keccakOneRound (a : Array UInt64) (rc : UInt64) : Array UInt64 := Id.run do
  let mut a := a
  let mut arr : Array UInt64 := Array.replicate 5 0
  for x in List.range 5 do
    let mut v : UInt64 := 0
    for yc in List.range 5 do
      let y := yc * 5
      v := v ^^^ a[x + y]!
    arr := arr.set! x v
  for x in List.range 5 do
    for yc in List.range 5 do
      let y := yc * 5
      let t := arr[(x + 4) % 5]! ^^^ u64RotateLeft (arr[(x + 1) % 5]!) 1
      a := a.set! (y + x) (a[y + x]! ^^^ t)
  let mut last := a[1]!
  for x in List.range 24 do
    let p := piIdx[x]!
    let tmp := a[p]!
    let rr : Nat := rho[x]!
    a := a.set! p (u64RotateLeft last rr)
    last := tmp
  for y_step in List.range 5 do
    let y := y_step * 5
    let mut c := Array.replicate 5 (0 : UInt64)
    for x in List.range 5 do
      c := c.set! x a[y + x]!
    for x in List.range 5 do
      let nx := c[x]! ^^^ ((~~~ c[(x + 1) % 5]!) &&& c[(x + 2) % 5]!)
      a := a.set! (y + x) nx
  a := a.set! 0 (a[0]! ^^^ rc)
  return a

def keccakF (a : Array UInt64) : Array UInt64 :=
  (List.range 24).foldl (fun acc round => keccakOneRound acc (keccakRC[round]!)) a

/-- 200 state bytes → 25 lanes, little-endian per lane (`tiny-keccak` LE layout). -/
def bytes200ToWords (b : ByteArray) : Array UInt64 :=
  (List.range 25).foldl (fun acc i =>
    let base := i * 8
    let w :=
      UInt64.ofNat (b[base]!.toNat) +
      u64RotateLeft (UInt64.ofNat (b[base + 1]!.toNat)) 8 +
      u64RotateLeft (UInt64.ofNat (b[base + 2]!.toNat)) 16 +
      u64RotateLeft (UInt64.ofNat (b[base + 3]!.toNat)) 24 +
      u64RotateLeft (UInt64.ofNat (b[base + 4]!.toNat)) 32 +
      u64RotateLeft (UInt64.ofNat (b[base + 5]!.toNat)) 40 +
      u64RotateLeft (UInt64.ofNat (b[base + 6]!.toNat)) 48 +
      u64RotateLeft (UInt64.ofNat (b[base + 7]!.toNat)) 56
    acc.push w) #[]

/-- 25 lanes → 200 bytes, little-endian per lane. -/
def wordsToBytes200 (a : Array UInt64) : ByteArray :=
  (List.range 25).foldl (fun acc i =>
    let w := (a : Array UInt64)[i]!
    acc.push w.toUInt8
      |>.push (w >>> UInt64.ofNat 8).toUInt8
      |>.push (w >>> UInt64.ofNat 16).toUInt8
      |>.push (w >>> UInt64.ofNat 24).toUInt8
      |>.push (w >>> UInt64.ofNat 32).toUInt8
      |>.push (w >>> UInt64.ofNat 40).toUInt8
      |>.push (w >>> UInt64.ofNat 48).toUInt8
      |>.push (w >>> UInt64.ofNat 56).toUInt8) ByteArray.empty

def keccakPermute (buf : ByteArray) : ByteArray :=
  wordsToBytes200 (keccakF (bytes200ToWords buf))

/-- XOR `input[inputOff .. inputOff+len)` into `buf[bufOff ..)`. -/
def xorInto (buf : ByteArray) (bufOff : Nat) (input : ByteArray) (inputOff len : Nat) : ByteArray :=
  (List.range len).foldl (fun acc i =>
    acc.set! (bufOff + i) (acc[bufOff + i]! ^^^ input[inputOff + i]!)) buf

def emptyState200 : ByteArray :=
  ⟨(Array.replicate 200 (0 : UInt8))⟩

/-- Keccak absorb for a fixed `rate` (bytes XORed per permutation). -/
def absorbAt (rate : Nat) (msg : ByteArray) (h : 0 < rate) : ByteArray × Nat :=
  let rec go (buf : ByteArray) (offset ip l : Nat)
      (_inv : ip + l = msg.size) (ho : offset < rate) : ByteArray × Nat :=
    let avail := rate - offset
    if hlt : avail ≤ l then
      have hav : 0 < avail := Nat.sub_pos_of_lt ho
      have _hl : l - avail < l := Nat.sub_lt_of_pos_le hav hlt
      let buf1 := xorInto buf offset msg ip avail
      let buf2 := keccakPermute buf1
      go buf2 0 (ip + avail) (l - avail) (by omega) h
    else
      (xorInto buf offset msg ip l, offset + l)
  termination_by l
  go emptyState200 0 0 msg.size (Nat.zero_add _) h

/-- SHA3 domain byte (FIPS 202 / `tiny_keccak::Sha3::DELIM`). -/
def sha3Delim : UInt8 := 0x06

/-- NIST SHA3 sponge: absorb with `rate`, pad, permute, take first `outBytes` of state. -/
def sha3Sponge (rate outBytes : Nat) (msg : ByteArray) (hr : 0 < rate) : ByteArray :=
  let (buf, off) := absorbAt rate msg hr
  let buf1 := buf.set! off (buf[off]! ^^^ sha3Delim)
  let buf2 := buf1.set! (rate - 1) (buf1[rate - 1]! ^^^ 0x80)
  let buf3 := keccakPermute buf2
  buf3.extract 0 outBytes

end MovementFormal.Std.Hash.Keccak
