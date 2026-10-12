/-
Copyright (c) Move Industries.

# Move `std::hash::sha3_256` model

**Source:** `aptos-move/framework/move-stdlib/sources/hash.move`; native `aptos-move/framework/move-stdlib/src/natives/hash.rs`.

Pure Lean SHA3-256 (FIPS 202), rate `136` bytes (`200 - 256/4`), matching `tiny-keccak` /
RustCrypto `sha3::Sha3_256` as used by `aptos-move/framework/move-stdlib/src/natives/hash.rs`.

- NIST FIPS 202: <https://doi.org/10.6028/NIST.FIPS.202>
- Move native: `aptos-move/framework/move-stdlib/src/natives/hash.rs`
- Goldens: `aptos-move/framework/move-stdlib/tests/hash_tests.move`
-/

import MovementFormal.Std.Hash.Keccak

namespace MovementFormal.Std.Hash.Sha3_256

open MovementFormal.Std.Hash.Keccak

/-- NIST SHA3-256; digest length 32 bytes. -/
def sha3_256 (msg : ByteArray) : ByteArray :=
  sha3Sponge 136 32 msg (by decide)

/-- `hash_tests.move`: `sha3_256(x"616263")`. -/
def expectedSha3_256_abc : ByteArray :=
  ByteArray.mk #[
    0x3a, 0x98, 0x5d, 0xa7, 0x4f, 0xe2, 0x25, 0xb2, 0x04, 0x5c, 0x17, 0x2d, 0x6b, 0xd3, 0x90, 0xbd,
    0x85, 0x5f, 0x08, 0x6e, 0x3e, 0x9d, 0x52, 0x5b, 0x46, 0xbf, 0xe2, 0x45, 0x11, 0x43, 0x15, 0x32
  ]

example : sha3_256 (ByteArray.mk #[97, 98, 99]) = expectedSha3_256_abc := by native_decide

/-- NIST SHA3-256 of the empty string. -/
def expectedSha3_256_empty : ByteArray :=
  ByteArray.mk #[
    0xa7, 0xff, 0xc6, 0xf8, 0xbf, 0x1e, 0xd7, 0x66, 0x51, 0xc1, 0x47, 0x56, 0xa0, 0x61, 0xd6, 0x62,
    0xf5, 0x80, 0xff, 0x4d, 0xe4, 0x3b, 0x49, 0xfa, 0x82, 0xd8, 0x0a, 0x4b, 0x80, 0xf8, 0x43, 0x4a
  ]

example : sha3_256 ByteArray.empty = expectedSha3_256_empty := by native_decide

end MovementFormal.Std.Hash.Sha3_256
