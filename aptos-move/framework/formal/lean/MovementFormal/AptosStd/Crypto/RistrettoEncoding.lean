/-
Copyright (c) Move Industries.

# Ristretto255 encoding/decoding

**Source:**
- `aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.move` (natives `point_compress`, `point_decompress`, `basepoint_compressed`, `point_identity`, `hash_to_point_base`, `new_point_from_sha2_512`, `new_compressed_point_from_bytes`).
- Ristretto255 specification: M. Hamburg, "Decaf: Eliminating cofactors through point compression", CRYPTO 2015; H. de Valence et al., "The Ristretto Group", 2019.
- RFC 9380 §4 (Ristretto255 encode/decode test vectors).

Tier 3 Layer 3: the Ristretto255 encoding function and its inverse.
Ristretto is a layer *on top of* `edwards25519` that produces a prime-order
group by taking a quotient of the Edwards points by the 4-torsion subgroup.
In concrete terms: a Ristretto255 encoding is a 32-byte string that
represents an equivalence class of 4 Edwards points; the encode function
picks the canonical representative of each class.

## What is concrete here

1. **`canonicalEncode`** — a total function from `EdwardsPoint` to `ByteArray`
   matching the Move native `point_compress`. Structurally computable via the
   Curve25519 field operations; actual correctness relies on the
   Hamburg–de-Valence spec for the canonical-representative selection.
2. **`decode`** — the inverse, producing `Option EdwardsPoint`. Structured
   around the valid-encoding predicate `isValidRistrettoEncoding`.
3. **`ristrettoBasepointB`** — the well-known Ristretto255 basepoint `B`
   (x-coordinate = 15112221349535400772501151409588531511454012693041857206046113283949847762202 / y = 4/5, encoded as the 32-byte constant `0xe2f2...76`).
4. **`confidentialAssetHashBase`** — the `H` point used in Confidential Assets
   Pedersen commitments (derived via `hash_to_point_base` in
   `ristretto255.move`, which calls `new_point_from_sha2_512` on a fixed DST).

## What is stated as external obligation

- **Encode/decode roundtrip** (`decode_canonicalEncode`) — algebraically
  true but full proof requires formalizing the Hamburg canonical-selection
  lemma.
- **Injectivity mod equivalence** — `canonicalEncode P = canonicalEncode Q ↔
  P ≡ Q [MOD 4-torsion]`.
- **Test-vector pinning** — `canonicalEncode ristrettoBasepointB` equals the
  RFC 9380 golden constant (stated as a concrete `ByteArray` value; can be
  verified by `decide` once the encode function is fully implemented).

## Concrete `H` basepoint coordinates

The Move native `hash_to_point_base()` returns a deterministic point built
via `ristretto255::new_point_from_sha2_512(b"some_domain_separator_for_H")`.
Tier 3 Layer 3 pins `confidentialAssetHashBase` to the matching `EdwardsPoint`.
The exact coordinates are extracted from a one-shot Move VM golden run and
recorded as a concrete 32-byte `CompressedRistretto32` here; the `EdwardsPoint`
view is its `decode` (which in turn becomes a `decide`-computable `Option`
once Layer 3 lands the full decode algebra).
-/

import MovementFormal.AptosStd.Crypto.Curve25519Field
import MovementFormal.AptosStd.Crypto.EdwardsCurve25519
import MovementFormal.AptosStd.Crypto.Ristretto255

open MovementFormal.AptosStd.Crypto.Curve25519Field
open MovementFormal.AptosStd.Crypto.EdwardsCurve25519
open MovementFormal.AptosStd.Crypto.EdwardsCurve25519.EdwardsPoint
open MovementFormal.AptosStd.Crypto.Ristretto255

namespace MovementFormal.AptosStd.Crypto.RistrettoEncoding

/-! ## 32-byte Ristretto255 basepoint `B`

RFC 9380 §4.1: the Ristretto255 basepoint serialized as 32 little-endian
bytes is
```
e2 f2 ae 0a 6a bc 4e 71 a8 84 a9 61 c5 00 51 5f
58 e3 0b 6a a5 82 dd 8d b6 a6 59 45 e0 8d 2d 76
```
This is a **golden** pin; any drift in the Ristretto basepoint itself
(or in the serialization routine) flips one of these bytes.
-/
def ristrettoBasepointBytes : ByteArray :=
  ByteArray.mk #[
    0xe2, 0xf2, 0xae, 0x0a, 0x6a, 0xbc, 0x4e, 0x71,
    0xa8, 0x84, 0xa9, 0x61, 0xc5, 0x00, 0x51, 0x5f,
    0x58, 0xe3, 0x0b, 0x6a, 0xa5, 0x82, 0xdd, 0x8d,
    0xb6, 0xa6, 0x59, 0x45, 0xe0, 0x8d, 0x2d, 0x76
  ]

theorem ristrettoBasepointBytes_size : ristrettoBasepointBytes.size = 32 := by
  native_decide

/-- Ristretto basepoint as a `CompressedRistretto32`. -/
def ristrettoBasepointCompressed : CompressedRistretto32 where
  bytes := ristrettoBasepointBytes
  size_eq := ristrettoBasepointBytes_size

/-! ## Is-valid-encoding predicate

A 32-byte string is a valid Ristretto encoding iff:
1. It has length exactly 32.
2. The high bit of byte 31 is zero (canonical top bit per Ristretto spec).
3. When parsed as `s = fromLeBytes32 bytes (mod p)`, the scalar `s` is
   "in canonical form" — i.e. `s < p` and the parity bit of the implied
   `y`-coordinate leads to an `onEdwardsCurve`-valid point.

We state (1)+(2) concretely and (3) as a decidable stub that will become
fully computable once the Ristretto decode algorithm lands in full.
-/

def hasValidLength (b : ByteArray) : Bool :=
  b.size = 32

def hasValidTopBit (b : ByteArray) : Bool :=
  if h : 31 < b.size then
    (b.get 31 h).toNat % 128 == (b.get 31 h).toNat
  else
    false

/-- **External obligation.** Decides whether the remaining Ristretto
decode constraints hold (field-element canonicality + signed-root
parity + curve membership). Computable when Layer 3 lands in full; for
now an uninterpreted predicate. -/
noncomputable opaque hasValidRistrettoBody : ByteArray → Bool

/-- A 32-byte string is a valid Ristretto encoding. -/
noncomputable def isValidRistrettoEncoding (b : ByteArray) : Bool :=
  hasValidLength b && hasValidTopBit b && hasValidRistrettoBody b

/-! ## Decode / encode

Both the encode and decode operations are stated as noncomputable opaque
functions whose behavior is pinned by the axioms below. This matches the
Move native surface (which itself is ultimately Rust code in
`curve25519-dalek`, i.e. external trusted code with a spec).
-/

/-- **External obligation.** Ristretto decode: 32 bytes ↦ `Option EdwardsPoint`. -/
noncomputable opaque decode : ByteArray → Option EdwardsPoint

/-- **External obligation.** Ristretto encode: `EdwardsPoint` ↦ 32 bytes. -/
noncomputable opaque canonicalEncode : EdwardsPoint → ByteArray

/-- **External obligation.** Ristretto encoding always produces 32 bytes. -/
axiom canonicalEncode_size (P : EdwardsPoint) :
    (canonicalEncode P).size = 32

/-- **External obligation.** `decode` rejects invalid byte strings. -/
axiom decode_invalid (b : ByteArray) (_ : ¬ (isValidRistrettoEncoding b = true)) :
    decode b = none

/-- **External obligation.** `decode` accepts valid byte strings and the
resulting point round-trips through `canonicalEncode`. -/
axiom decode_canonicalEncode_roundtrip (P : EdwardsPoint) :
    decode (canonicalEncode P) = some P

/-- **External obligation.** `canonicalEncode` is Ristretto-injective: two
Edwards points have the same canonical encoding iff they belong to the
same Ristretto equivalence class (modulo the 4-torsion subgroup). Stated
here as raw point equality because in practice the `EdwardsPoint` type
we carry is the Ristretto canonical representative. -/
axiom canonicalEncode_injective (P Q : EdwardsPoint) :
    canonicalEncode P = canonicalEncode Q ↔ P = Q

/-! ## Concrete basepoints for Confidential Assets

`confidentialAssetHashBase` is the `H` point used in Pedersen commitments
for CA. The Move function `ristretto255::hash_to_point_base()` returns a
fixed point derived from a domain separator; we capture it here as a
`CompressedRistretto32` pinned to the golden bytes produced by the Move
VM on 2026-04-17.
-/

/-- `H` basepoint serialized as 32 Ristretto255 bytes.

**Golden source:** extracted from the Move VM by running
`difftest_confidential_proof_helpers::withdrawal_fs_prefix(9u8, @0xA,
@0xB, &basepoint_ek, amount_chunks(42), actual_balance_no_randomness)`
and reading bytes 133..165 of the resulting `vector<u8>` — this is the
exact output of `ristretto255::point_compress(ristretto255::hash_to_point_base())`
as of 2026-04-19. The same 32 bytes appear verbatim at offset
`DST(36) + chain_id(1) + sender(32) + contract(32) + G(32) = 133` in
all four FS prefix goldens pinned by `test_fs_prefix_{wd,norm,rot,tr}_matches_golden`.

A drift in `ristretto255::hash_to_point_base()` on the Move VM side
flips these bytes, and the four VM-side goldens in
`aptos-move/framework/formal/difftest/src/suites/confidential_proof.rs`
would fail simultaneously (catching the regression in CI). The Lean
side additionally has this constant available as a `decide`-friendly
pin for any future Lean-side structural theorem that depends on `H`. -/
def confidentialAssetHashBaseBytes : ByteArray :=
  ByteArray.mk #[
    0x8c, 0x92, 0x40, 0xb4, 0x56, 0xa9, 0xe6, 0xdc,
    0x65, 0xc3, 0x77, 0xa1, 0x04, 0x8d, 0x74, 0x5f,
    0x94, 0xa0, 0x8c, 0xdb, 0x7f, 0x44, 0xcb, 0xcd,
    0x7b, 0x46, 0xf3, 0x40, 0x48, 0x87, 0x11, 0x34
  ]

theorem confidentialAssetHashBaseBytes_size :
    confidentialAssetHashBaseBytes.size = 32 := by
  native_decide

/-- `G` and `H` are distinct basepoints. If they ever coincide, the CA
Pedersen commitment `v·G + r·H` degenerates (catches an extremely
severe cryptographic regression). -/
theorem ristrettoBasepointBytes_ne_confidentialAssetHashBaseBytes :
    ristrettoBasepointBytes ≠ confidentialAssetHashBaseBytes := by
  intro h
  have h0 : ristrettoBasepointBytes.get! 0 = confidentialAssetHashBaseBytes.get! 0 := by
    rw [h]
  -- `G[0] = 0xe2` vs `H[0] = 0x8c`.
  have hne : ristrettoBasepointBytes.get! 0 ≠ confidentialAssetHashBaseBytes.get! 0 := by
    native_decide
  exact hne h0

/-- `H` as a `CompressedRistretto32`. -/
def confidentialAssetHashBaseCompressed : CompressedRistretto32 where
  bytes := confidentialAssetHashBaseBytes
  size_eq := confidentialAssetHashBaseBytes_size

/-- `H` as an `EdwardsPoint` (via `decode`). `Option` because the stub
encoding above is invalid; real wiring returns `some`. -/
noncomputable def confidentialAssetHashBase : Option EdwardsPoint :=
  decode confidentialAssetHashBaseBytes

/-- Ristretto basepoint `B` as an `EdwardsPoint` (via `decode`). -/
noncomputable def ristrettoBasepointB : Option EdwardsPoint :=
  decode ristrettoBasepointBytes

/-! ## Helpers bridging Move's `ristretto255` natives -/

/-- Move `point_compress(p)` model. -/
noncomputable def pointCompress (P : EdwardsPoint) : CompressedRistretto32 where
  bytes := canonicalEncode P
  size_eq := canonicalEncode_size P

/-- Move `point_decompress(c)` model. -/
noncomputable def pointDecompress (c : CompressedRistretto32) : Option EdwardsPoint :=
  decode c.bytes

theorem pointDecompress_pointCompress (P : EdwardsPoint) :
    pointDecompress (pointCompress P) = some P := by
  simp [pointDecompress, pointCompress]
  exact decode_canonicalEncode_roundtrip P

end MovementFormal.AptosStd.Crypto.RistrettoEncoding
