/-
Copyright (c) Move Industries.

# Move `std::hash::sha2_256` model

**Source:** `aptos-move/framework/move-stdlib/sources/hash.move`; native `aptos-move/framework/move-stdlib/src/natives/hash.rs`.

Pure Lean SHA2-256 (FIPS 180-4, §6.2). Matches the `sha2::Sha256` crate used by
`aptos-move/framework/move-stdlib/src/natives/hash.rs`.

- NIST FIPS 180-4: <https://doi.org/10.6028/NIST.FIPS.180-4>
- Move tests: `aptos-move/framework/move-stdlib/tests/hash_tests.move`
-/

namespace MovementFormal.Std.Hash.Sha2_256

def sha2_256_k : Array UInt32 := #[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
]

def sha2_256_h0 : Array UInt32 := #[
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
]

private def rotr32 (x : UInt32) (n : Nat) : UInt32 :=
  let r := UInt32.ofNat (n % 32)
  (x >>> r) ||| (x <<< UInt32.ofNat (32 - (n % 32)))

private def shr32 (x : UInt32) (n : Nat) : UInt32 :=
  x >>> UInt32.ofNat n

private def ch32 (x y z : UInt32) : UInt32 := (x &&& y) ^^^ (~~~x &&& z)
private def maj32 (x y z : UInt32) : UInt32 := (x &&& y) ^^^ (x &&& z) ^^^ (y &&& z)

private def bigSigma0_32 (x : UInt32) : UInt32 :=
  rotr32 x 2 ^^^ rotr32 x 13 ^^^ rotr32 x 22

private def bigSigma1_32 (x : UInt32) : UInt32 :=
  rotr32 x 6 ^^^ rotr32 x 11 ^^^ rotr32 x 25

private def smallSigma0_32 (x : UInt32) : UInt32 :=
  rotr32 x 7 ^^^ rotr32 x 18 ^^^ shr32 x 3

private def smallSigma1_32 (x : UInt32) : UInt32 :=
  rotr32 x 17 ^^^ rotr32 x 19 ^^^ shr32 x 10

private def readBE32 (ba : ByteArray) (off : Nat) : UInt32 :=
  let b (i : Nat) : UInt32 := UInt32.ofNat (ba.get! (off + i)).toNat
  (b 0 <<< 24) ||| (b 1 <<< 16) ||| (b 2 <<< 8) ||| b 3

private def messageSchedule256 (block : ByteArray) : Array UInt32 :=
  let w0 := Array.range 16 |>.map fun i => readBE32 block (i * 4)
  let rec extend (w : Array UInt32) (t : Nat) : Array UInt32 :=
    if h : t ≥ 64 then w
    else
      let s1 := smallSigma1_32 (w[t - 2]!)
      let s0 := smallSigma0_32 (w[t - 15]!)
      let wt := s1 + w[t - 7]! + s0 + w[t - 16]!
      extend (w.push wt) (t + 1)
  termination_by 64 - t
  extend w0 16

private def compress256 (h : Array UInt32) (w : Array UInt32) : Array UInt32 :=
  let rec loop (a b c d e f g hh : UInt32) (t : Nat) : Array UInt32 :=
    if ht : t ≥ 64 then
      #[h[0]! + a, h[1]! + b, h[2]! + c, h[3]! + d, h[4]! + e, h[5]! + f, h[6]! + g, h[7]! + hh]
    else
      let t1 := hh + bigSigma1_32 e + ch32 e f g + sha2_256_k[t]! + w[t]!
      let t2 := bigSigma0_32 a + maj32 a b c
      loop (t1 + t2) a b c (d + t1) e f g (t + 1)
  termination_by 64 - t
  loop h[0]! h[1]! h[2]! h[3]! h[4]! h[5]! h[6]! h[7]! 0

private def writeBE32 (v : UInt32) : ByteArray :=
  ByteArray.mk #[
    UInt8.ofNat ((v >>> 24).toNat % 256),
    UInt8.ofNat ((v >>> 16).toNat % 256),
    UInt8.ofNat ((v >>> 8).toNat % 256),
    UInt8.ofNat (v.toNat % 256)
  ]

private def pad256 (msg : ByteArray) : ByteArray :=
  let bitLen := UInt64.ofNat (msg.size * 8)
  let afterOne := msg.size + 1
  let zeroBytes := (64 - (afterOne + 8) % 64) % 64
  let buf := msg.push 0x80 ++ ByteArray.mk (Array.replicate zeroBytes 0x00)
  let hi := UInt32.ofNat ((bitLen >>> 32).toNat % (2 ^ 32))
  let lo := UInt32.ofNat (bitLen.toNat % (2 ^ 32))
  buf ++ writeBE32 hi ++ writeBE32 lo

/-- SHA2-256 (FIPS 180-4); digest length 32 bytes. -/
def sha2_256 (msg : ByteArray) : ByteArray :=
  let padded := pad256 msg
  let nBlocks := padded.size / 64
  let rec processBlocks (h : Array UInt32) (i : Nat) : Array UInt32 :=
    if i ≥ nBlocks then h
    else
      let block := ByteArray.mk (padded.toList.drop (i * 64) |>.take 64 |>.toArray)
      let w := messageSchedule256 block
      let h' := compress256 h w
      processBlocks h' (i + 1)
  termination_by nBlocks - i
  let finalH := processBlocks sha2_256_h0 0
  finalH.foldl (fun acc v => acc ++ writeBE32 v) ByteArray.empty

/-!
## Sanity checks (`hash_tests.move`)
-/

def expectedSha2_256_abc : ByteArray :=
  ByteArray.mk #[
    0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea, 0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
    0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c, 0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad
  ]

example : sha2_256 (ByteArray.mk #[97, 98, 99]) = expectedSha2_256_abc := by native_decide

/-- NIST SHA2-256 of the empty string (one block, padding only). -/
def expectedSha2_256_empty : ByteArray :=
  ByteArray.mk #[
    0xe3, 0xb0, 0xc4, 0x42, 0x98, 0xfc, 0x1c, 0x14, 0x9a, 0xfb, 0xf4, 0xc8, 0x99, 0x6f, 0xb9, 0x24,
    0x27, 0xae, 0x41, 0xe4, 0x64, 0x9b, 0x93, 0x4c, 0xa4, 0x95, 0x99, 0x1b, 0x78, 0x52, 0xb8, 0x55
  ]

example : sha2_256 ByteArray.empty = expectedSha2_256_empty := by native_decide

end MovementFormal.Std.Hash.Sha2_256
