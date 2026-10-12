/-
Copyright (c) Move Industries.

# Curve25519 base field `𝔽_p` where `p = 2^255 - 19`

**Source:**
- `aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.move`
- Curve25519 paper: D. J. Bernstein, 2006, <https://cr.yp.to/ecdh.html>
- RFC 7748, §4.1 (Curve25519 coordinate field).

Tier 3 (full Ristretto255 formalization) Layer 1: the scalar field `𝔽_p` is
where all curve arithmetic takes place. Every `ristretto255::scalar_*`
native (`scalar_mul`, `scalar_sub`, `scalar_invert`, `scalar_to_bytes`,
`new_scalar_from_bytes`) reduces to an operation in this field (when the
operand is a curve coordinate) or in `ZMod ℓ` (when the operand is a
Ristretto255 scalar — `RistrettoScalar` in `Ristretto255.lean`).

We rely on Mathlib's `ZMod p` for the underlying `CommRing` + `Field`
instances; the only non-trivial obligation is primality of `p = 2^255 - 19`.
Since `p` is 255-bit, trial division in Lean is infeasible; we state
primality as an axiom here, matching the pattern already used for the
subgroup order `ℓ` in `Ristretto255.lean`. The axiom is discharged by
Bernstein's published Pratt certificate for `p` (see §6.5 of the
registration-verifier review); a future pass can supply the certificate
and remove the axiom.
-/

import Mathlib.Data.ZMod.Basic
import Mathlib.FieldTheory.Finite.Basic
import MovementFormal.AptosStd.Crypto.Ristretto255

open MovementFormal.AptosStd.Crypto.Ristretto255

namespace MovementFormal.AptosStd.Crypto.Curve25519Field

/--
Curve25519 base-field prime `p = 2^255 - 19`.

Exact value:
`57896044618658097711785492504343953926634992332820282019728792003956564819949`.
-/
def p : ℕ :=
  2 ^ 255 - 19

/-- Positivity pin on `p`. Cheap bound: `2 ^ 255 > 19` so the subtraction is non-trivial. -/
theorem p_pos : 0 < p := by
  unfold p
  have : 19 < 2 ^ 255 := by
    have : (2 : ℕ) ^ 255 ≥ 2 ^ 5 := by
      exact Nat.pow_le_pow_right (by decide) (by decide)
    omega
  omega

/--
Curve25519 base-field prime is prime.

**Not proved in Lean.** Justified by Bernstein's published Pratt certificate
for `p = 2^255 - 19` (Curve25519, 2006). Matches the existing axiom style
used in `Ristretto255.lean` for the subgroup order `ℓ`.

**§6.5 of `REGISTRATION_VERIFY_REVIEW.md`:** to remove this axiom, supply
the Pratt certificate (factorization of `p - 1 = 2^1 · 3^1 · 65147 · q` for
a specific 235-bit prime `q`) and verify it in Lean. Requires an external
CAS to generate the certificate.
-/
axiom p_prime : Nat.Prime p

/-- `Fact` instance making `Field Fp` available via Mathlib's `ZMod.instField`. -/
instance pPrimeFact : Fact (Nat.Prime p) := ⟨p_prime⟩

/-- The Curve25519 base field `𝔽_p`. `CommRing` + `Field` instances follow
automatically from `ZMod p` + `pPrimeFact`. -/
abbrev Fp :=
  ZMod p

/--
The Edwards curve parameter `d = -121665 / 121666 (mod p)`.

From RFC 7748 §5 (edwards25519). Bernstein et al., "High-speed high-security
signatures", §3. Exact value:
`37095705934669439343138083508754565189542113879843219016388785533085940283555`.
-/
noncomputable def edwardsD : Fp :=
  (-(121665 : Fp)) * (121666 : Fp)⁻¹

/-- Small positive naturals strictly less than `p` are non-zero in `Fp`. Used
repeatedly below for concrete Curve25519 constants like `121665`, `121666`. -/
theorem natCast_ne_zero_of_lt (n : ℕ) (hn_pos : 0 < n) (hn_lt : n < p) :
    (n : Fp) ≠ 0 := by
  rw [Ne, ZMod.natCast_eq_zero_iff]
  intro hdvd
  have hp_le : p ≤ n := Nat.le_of_dvd hn_pos hdvd
  omega

/-- `d` is non-zero. -/
theorem edwardsD_ne_zero : edwardsD ≠ 0 := by
  unfold edwardsD
  have h121665 : (121665 : Fp) ≠ 0 :=
    natCast_ne_zero_of_lt 121665 (by decide) (by decide)
  have h121666 : (121666 : Fp) ≠ 0 :=
    natCast_ne_zero_of_lt 121666 (by decide) (by decide)
  exact mul_ne_zero (neg_ne_zero.mpr h121665) (inv_ne_zero h121666)

/--
Edwards curve equation `-x² + y² = 1 + d·x²·y²` over `Fp`.

This is `edwards25519` (RFC 7748 §5). Not a Ristretto-level construction —
Ristretto adds an equivalence class on top of this raw curve to get a
prime-order group.
-/
def onEdwardsCurve (x y : Fp) : Prop :=
  -x^2 + y^2 = 1 + edwardsD * x^2 * y^2

/-! ## Byte ↔ field element conversions

These mirror the Move natives `scalar_to_bytes` / `new_scalar_from_bytes`
restricted to the BASE FIELD (as opposed to the scalar field `ZMod ℓ`
used by `Ristretto255.lean`). Used by point encodings.

We use little-endian 32-byte encoding, same as Curve25519/Ristretto255
convention.
-/

/-- Convert 32 little-endian bytes to a natural number. Returns 0 if the
input is not exactly 32 bytes long. Delegates to the shared
`byteArrayLeNat` already used for scalar decoding. -/
def fromLeBytes32 (b : ByteArray) : ℕ :=
  if b.size = 32 then byteArrayLeNat b else 0

/-- Reduce a natural number to `Fp`. -/
def natToFp (n : ℕ) : Fp :=
  (n : Fp)

/--
Canonicality mask: Ristretto255 requires the high bit of byte 31 to be `0`
in a canonical encoding (top bit reserved; the 255-bit field fits in 255
bits, leaving 1 bit in the 256-bit representation). The Move native
`point_is_canonical_internal` returns `false` when this top bit is set.

Captured here as a predicate on the raw 32-byte encoding.
-/
def hasCanonicalTopBit (b : ByteArray) : Prop :=
  ∃ h : 31 < b.size, (b.get 31 h).toNat % 128 = (b.get 31 h).toNat

end MovementFormal.AptosStd.Crypto.Curve25519Field
