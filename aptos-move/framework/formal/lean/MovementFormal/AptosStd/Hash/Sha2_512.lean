/-
Copyright (c) Move Industries.

# Aptos `aptos_std::aptos_hash` — SHA2-512 model

Pure Lean SHA2-512 (FIPS 180-4, §6.4).  Matches the `sha2::Sha512` crate
used by `aptos_std::aptos_hash::sha2_512` in
`aptos-move/framework/aptos-stdlib/sources/hash.move`.

- NIST FIPS 180-4: <https://doi.org/10.6028/NIST.FIPS.180-4>
-/

import Batteries.Data.List.Basic

namespace MovementFormal.AptosStd.Hash.Sha2_512

def sha2_512_k : Array UInt64 := #[
  0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc,
  0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118,
  0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
  0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694,
  0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
  0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
  0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4,
  0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x06ca6351e003826f, 0x142929670a0e6e70,
  0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df,
  0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
  0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30,
  0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
  0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8,
  0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3,
  0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
  0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b,
  0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178,
  0x06f067aa72176fba, 0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
  0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c,
  0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817
]

def sha2_512_h0 : Array UInt64 := #[
  0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
  0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179
]

private def rotr64 (x : UInt64) (n : Nat) : UInt64 :=
  let r := UInt64.ofNat (n % 64)
  (x >>> r) ||| (x <<< UInt64.ofNat (64 - (n % 64)))

private def shr64 (x : UInt64) (n : Nat) : UInt64 :=
  x >>> UInt64.ofNat n

private def ch (x y z : UInt64) : UInt64 := (x &&& y) ^^^ (~~~x &&& z)
private def maj (x y z : UInt64) : UInt64 := (x &&& y) ^^^ (x &&& z) ^^^ (y &&& z)

private def bigSigma0 (x : UInt64) : UInt64 := rotr64 x 28 ^^^ rotr64 x 34 ^^^ rotr64 x 39
private def bigSigma1 (x : UInt64) : UInt64 := rotr64 x 14 ^^^ rotr64 x 18 ^^^ rotr64 x 41
private def smallSigma0 (x : UInt64) : UInt64 := rotr64 x 1 ^^^ rotr64 x 8 ^^^ shr64 x 7
private def smallSigma1 (x : UInt64) : UInt64 := rotr64 x 19 ^^^ rotr64 x 61 ^^^ shr64 x 6

private def readBE64 (ba : ByteArray) (off : Nat) : UInt64 :=
  let b (i : Nat) : UInt64 := UInt64.ofNat (ba.get! (off + i)).toNat
  (b 0 <<< 56) ||| (b 1 <<< 48) ||| (b 2 <<< 40) ||| (b 3 <<< 32) |||
  (b 4 <<< 24) ||| (b 5 <<< 16) ||| (b 6 <<< 8) ||| b 7

private def messageSchedule (block : ByteArray) : Array UInt64 :=
  let w0 := Array.range 16 |>.map fun i => readBE64 block (i * 8)
  let rec extend (w : Array UInt64) (t : Nat) : Array UInt64 :=
    if h : t ≥ 80 then w
    else
      let s1 := smallSigma1 (w[t - 2]!)
      let s0 := smallSigma0 (w[t - 15]!)
      let wt := s1 + w[t - 7]! + s0 + w[t - 16]!
      extend (w.push wt) (t + 1)
  termination_by 80 - t
  extend w0 16

private def compress (h : Array UInt64) (w : Array UInt64) : Array UInt64 :=
  let rec loop (a b c d e f g hh : UInt64) (t : Nat) : Array UInt64 :=
    if ht : t ≥ 80 then #[h[0]! + a, h[1]! + b, h[2]! + c, h[3]! + d,
                          h[4]! + e, h[5]! + f, h[6]! + g, h[7]! + hh]
    else
      let t1 := hh + bigSigma1 e + ch e f g + sha2_512_k[t]! + w[t]!
      let t2 := bigSigma0 a + maj a b c
      loop (t1 + t2) a b c (d + t1) e f g (t + 1)
  termination_by 80 - t
  loop h[0]! h[1]! h[2]! h[3]! h[4]! h[5]! h[6]! h[7]! 0

private def writeBE64 (v : UInt64) : ByteArray :=
  ByteArray.mk #[
    UInt8.ofNat ((v >>> 56).toNat % 256),
    UInt8.ofNat ((v >>> 48).toNat % 256),
    UInt8.ofNat ((v >>> 40).toNat % 256),
    UInt8.ofNat ((v >>> 32).toNat % 256),
    UInt8.ofNat ((v >>> 24).toNat % 256),
    UInt8.ofNat ((v >>> 16).toNat % 256),
    UInt8.ofNat ((v >>> 8).toNat % 256),
    UInt8.ofNat (v.toNat % 256)
  ]

private def pad (msg : ByteArray) : ByteArray :=
  let bitLen := msg.size * 8
  let afterOne := msg.size + 1
  let zeroBytes := (128 - (afterOne + 16) % 128) % 128
  let buf := msg.push 0x80 ++ ByteArray.mk (Array.replicate zeroBytes 0x00)
  buf ++ writeBE64 (UInt64.ofNat (bitLen / (2^64))) ++ writeBE64 (UInt64.ofNat (bitLen % (2^64)))

/-- SHA2-512 (FIPS 180-4); digest length 64 bytes. -/
def sha2_512 (msg : ByteArray) : ByteArray :=
  let padded := pad msg
  let nBlocks := padded.size / 128
  let rec processBlocks (h : Array UInt64) (i : Nat) : Array UInt64 :=
    if i ≥ nBlocks then h
    else
      let block := ByteArray.mk (padded.toList.drop (i * 128) |>.take 128 |>.toArray)
      let w := messageSchedule block
      let h' := compress h w
      processBlocks h' (i + 1)
  termination_by nBlocks - i
  let finalH := processBlocks sha2_512_h0 0
  finalH.foldl (fun acc v => acc ++ writeBE64 v) ByteArray.empty

/-!
## Sanity checks (FIPS 180-4 test vectors)
-/

def expectedSha2_512_empty : ByteArray :=
  ByteArray.mk #[
    0xcf, 0x83, 0xe1, 0x35, 0x7e, 0xef, 0xb8, 0xbd, 0xf1, 0x54, 0x28, 0x50, 0xd6, 0x6d, 0x80, 0x07,
    0xd6, 0x20, 0xe4, 0x05, 0x0b, 0x57, 0x15, 0xdc, 0x83, 0xf4, 0xa9, 0x21, 0xd3, 0x6c, 0xe9, 0xce,
    0x47, 0xd0, 0xd1, 0x3c, 0x5d, 0x85, 0xf2, 0xb0, 0xff, 0x83, 0x18, 0xd2, 0x87, 0x7e, 0xec, 0x2f,
    0x63, 0xb9, 0x31, 0xbd, 0x47, 0x41, 0x7a, 0x81, 0xa5, 0x38, 0x32, 0x7a, 0xf9, 0x27, 0xda, 0x3e
  ]

example : sha2_512 ByteArray.empty = expectedSha2_512_empty := by native_decide

def expectedSha2_512_abc : ByteArray :=
  ByteArray.mk #[
    0xdd, 0xaf, 0x35, 0xa1, 0x93, 0x61, 0x7a, 0xba, 0xcc, 0x41, 0x73, 0x49, 0xae, 0x20, 0x41, 0x31,
    0x12, 0xe6, 0xfa, 0x4e, 0x89, 0xa9, 0x7e, 0xa2, 0x0a, 0x9e, 0xee, 0xe6, 0x4b, 0x55, 0xd3, 0x9a,
    0x21, 0x92, 0x99, 0x2a, 0x27, 0x4f, 0xc1, 0xa8, 0x36, 0xba, 0x3c, 0x23, 0xa3, 0xfe, 0xeb, 0xbd,
    0x45, 0x4d, 0x44, 0x23, 0x64, 0x3c, 0xe8, 0x0e, 0x2a, 0x9a, 0xc9, 0x4f, 0xa5, 0x4c, 0xa4, 0x9f
  ]

example : sha2_512 (ByteArray.mk #[97, 98, 99]) = expectedSha2_512_abc := by native_decide

end MovementFormal.AptosStd.Hash.Sha2_512
