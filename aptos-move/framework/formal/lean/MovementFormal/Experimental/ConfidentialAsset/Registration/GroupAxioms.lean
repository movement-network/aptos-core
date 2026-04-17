/-
Copyright (c) Move Industries.

# Ristretto group axioms — bridging `CryptoOracle` to algebraic structures

**Source:** `aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.move` (Move native surface for `verify_registration_proof` in `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`).

Packages the assumption that Move's `ristretto255` native operations implement
a correct prime-order Ristretto255 group with scalar multiplication satisfying
the `Module RistrettoScalar` laws.

These are **external obligations** (§6.2 of `REGISTRATION_VERIFY_REVIEW.md`).
Accepting them collapses all remaining oracle boundaries for
`verify_registration_proof`'s curve arithmetic layer. The **`challenge_eq_move`** field is what
`EndToEnd.registration_verification_iff_schnorr` uses to align Fiat–Shamir challenges with
`TranscriptAlignment.registrationChallengeScalarMove` on goldens.
-/

import MovementFormal.Experimental.ConfidentialAsset.Registration.VerifyMath
import MovementFormal.AptosStd.Crypto.Ristretto255

open MovementFormal.AptosStd.Crypto.Ristretto255
open RegistrationVerify

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.GroupAxioms

/--
Axiom bundle asserting that a `CryptoOracle`'s point operations form an
abelian group with a compatible `RistrettoScalar`-module action, and that
the challenge hash pipeline matches the Lean model.

**Not proved in Lean.** Justified by reviewing the Ristretto255 spec and
this branch's `ristretto255.move` native implementations (§6.2).
-/
structure RistrettoGroupAxioms {Point : Type}
    [AddCommGroup Point] [Module RistrettoScalar Point]
    (C : CryptoOracle Point) : Prop where
  /-- `ristretto255::point_mul(p, s)` implements scalar multiplication. -/
  mul_eq_smul : ∀ p s, C.pointMul p s = s • p
  /-- `ristretto255::point_add(a, b)` implements group addition. -/
  add_eq_add : ∀ a b, C.pointAdd a b = a + b
  /-- `ristretto255::point_equals(a, b)` is mathematical equality. -/
  eq_iff_eq : ∀ a b, C.pointEq a b ↔ a = b
  /-- `new_scalar_from_tagged_hash(DST, msg)` matches `registrationChallengeScalarMove`. -/
  challenge_eq_move : C.challengeScalarFromMsg = registrationChallengeScalarMove

end MovementFormal.Experimental.ConfidentialAsset.Registration.GroupAxioms
