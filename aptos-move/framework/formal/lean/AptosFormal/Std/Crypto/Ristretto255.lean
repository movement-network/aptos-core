/-
Copyright (c) Move Industries.

# Aptos `aptos_std::ristretto255` — scalar / wire scaffolding (stdlib-wide)

Ristretto255 wire-level and scalar-field definitions aligned with the Ristretto / Curve25519 specs.

This is **not** a full formalization of decoding, twist maps, or Montgomery arithmetic. It pins the
standard **prime-order subgroup** ℤ/ℓℤ used for Ristretto255 scalars (same reduction target as
`ristretto255::new_scalar_from_bytes` after range checks) and a **32-byte compressed point** carrier
matching **`aptos_std::ristretto255`** in this repo
(`aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.move`).

Full curve geometry belongs in a dedicated crypto library; here we keep point operations abstract
while fixing **scalar** and **encoding** types. Other framework packages (framework `aptos-framework`,
`aptos-experimental`, …) can depend on this module.
-/

import Mathlib.Data.ZMod.Basic

namespace AptosFormal.Std.Crypto.Ristretto255

/-- Curve25519 base field prime `2^255 - 19`. -/
def curve25519FieldPrime : ℕ :=
  2 ^ 255 - 19

/-- Ristretto255 prime subgroup order `ℓ = 2^252 + 27742317777372353535851937790883648493`. -/
def ristrettoSubgroupOrder : ℕ :=
  7237005577332262213973186563042994240857116359379907606001950938285454250989

/-- Subgroup order ℓ is prime (Ristretto / Curve25519 standard). -/
axiom ristretto_subgroup_order_prime : Nat.Prime ristrettoSubgroupOrder

/--
`Fact` instance making `Field RistrettoScalar` available via Mathlib's
`ZMod.instField`. Depends on the axiom above.

**§6.5 of `REGISTRATION_VERIFY_REVIEW.md`**: to remove the axiom, supply a
Pratt-style primality certificate for `ristrettoSubgroupOrder` and verify it
in Lean (the factorization of `ℓ − 1` is needed). For a 252-bit prime this
requires an external CAS to generate the certificate; trial division is not
feasible.
-/
instance ristrettoSubgroupOrderPrimeFact : Fact (Nat.Prime ristrettoSubgroupOrder) :=
  ⟨ristretto_subgroup_order_prime⟩

/-- Ristretto255 scalars as integers mod the prime subgroup order. -/
abbrev RistrettoScalar :=
  ZMod ristrettoSubgroupOrder

/-!
## 32-byte compressed encoding (Move `CompressedRistretto` bytes)
-/

structure CompressedRistretto32 where
  bytes : ByteArray
  size_eq : bytes.size = 32

namespace CompressedRistretto32

def zero : CompressedRistretto32 where
  bytes := ⟨(Array.replicate 32 (0 : UInt8))⟩
  size_eq := by native_decide

end CompressedRistretto32

def byteArrayLeNatAux (b : ByteArray) (i acc : ℕ) : ℕ :=
  if h : i < b.size then
    have : b.size - (i + 1) < b.size - i := Nat.sub_lt_sub_left h (Nat.lt_succ_of_le le_rfl)
    byteArrayLeNatAux b (i + 1) (acc + (b.get i h).toNat * 256 ^ i)
  else acc
termination_by b.size - i

def byteArrayLeNat (b : ByteArray) : ℕ :=
  byteArrayLeNatAux b 0 0

def scalarUniformFrom64Bytes (b : ByteArray) : Option RistrettoScalar :=
  if _hb : b.size = 64 then
    some (byteArrayLeNat b : RistrettoScalar)
  else
    none

def scalarReducedFrom32Bytes (b : ByteArray) : Option RistrettoScalar :=
  if _hb : b.size = 32 then
    some (byteArrayLeNat b : RistrettoScalar)
  else
    none

end AptosFormal.Std.Crypto.Ristretto255
