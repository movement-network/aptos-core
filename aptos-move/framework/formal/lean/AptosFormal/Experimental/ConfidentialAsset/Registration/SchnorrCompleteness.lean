/-
Copyright (c) Move Industries.

Machine-checked **completeness** for registration Schnorr verification
(`confidential_proof.move` — honest prover vs verifier).

Imports **`AptosFormal.Std.Crypto.Ristretto255`** for scalars and **`Registration.Formal`** for the abstract spec.
-/

import AptosFormal.Experimental.ConfidentialAsset.Registration.Formal
import AptosFormal.Experimental.ConfidentialAsset.Registration.VerifyMath
import AptosFormal.Std.Crypto.Ristretto255
import Mathlib.Algebra.Module.Basic

open AptosFormal.Experimental.ConfidentialAsset.Registration.Formal
open AptosFormal.Std.Crypto.Ristretto255

namespace AptosFormal.Experimental.ConfidentialAsset.Registration.SchnorrCompleteness

section ModuleAction

variable {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]

abbrev movePointMul (s : RistrettoScalar) (p : Point) : Point :=
  s • p

theorem registrationSchnorrEq_module_iff (H ek R : Point) (s e : RistrettoScalar) :
    registrationSchnorrEq movePointMul (· + ·) H ek R s e ↔ s • H + e • ek = R := by
  rfl

theorem registrationSchnorr_completeness (H ek R : Point) (k e dk_inv s : RistrettoScalar)
    (hR : R = k • H) (hek : ek = dk_inv • H) (hs : s = k - e * dk_inv) :
    registrationSchnorrEq movePointMul (· + ·) H ek R s e := by
  simp only [registrationSchnorrEq, movePointMul]
  rw [hs, hek, hR]
  rw [sub_smul]
  rw [← smul_smul e dk_inv H]
  rw [sub_add_cancel]

theorem registrationVerifySpec_completeness (taggedHash : ByteArray → RistrettoScalar)
    (i : RegistrationFiatShamirInputs) (H ek R : Point) (k e dk_inv s : RistrettoScalar)
    (he : e = taggedHash (registrationFiatShamirMsg i)) (hR : R = k • H) (hek : ek = dk_inv • H)
    (hs : s = k - e * dk_inv) :
    registrationVerifySpec movePointMul (· + ·) taggedHash i H ek R s := by
  simp only [registrationVerifySpec, registrationSchnorrEq, movePointMul]
  have hch : registrationChallenge taggedHash i = e := by
    simp [registrationChallenge_eq, he]
  rw [hch]
  exact registrationSchnorr_completeness H ek R k e dk_inv s hR hek hs

end ModuleAction

section IdealOracleBridge

open RegistrationVerify

variable {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]

theorem verifyRegistrationProofProp_iff_registrationVerifySpec
    (C : CryptoOracle Point) (taggedHash : ByteArray → RistrettoScalar)
    (i : RegistrationFiatShamirInputs) (responseBytes : ByteArray) (H : Point) (s e : RistrettoScalar)
    (rComm ekComm : CompressedRistretto32) (rhs ek : Point)
    (hs : C.scalarFromBytes responseBytes = some s)
    (hr : compressed32? i.commitmentRBytes = some rComm)
    (hek : compressed32? i.ekBytes = some ekComm)
    (hR : C.pointDecompress rComm = some rhs)
    (hek2 : C.pubkeyToPoint ekComm = some ek)
    (hch : C.challengeScalarFromMsg (registrationFiatShamirMsg i) = some e)
    (heHash : e = taggedHash (registrationFiatShamirMsg i)) (hH : C.hashToPointBase = H)
    (hmul : ∀ p s', C.pointMul p s' = s' • p) (hadd : ∀ a b, C.pointAdd a b = a + b)
    (hEq : ∀ a b, C.pointEq a b ↔ a = b) :
    verifyRegistrationProofProp C i responseBytes ↔
      registrationVerifySpec movePointMul (· + ·) taggedHash i H ek rhs s := by
  have lhs' :
      C.pointAdd (C.pointMul C.hashToPointBase s) (C.pointMul ek e) = s • H + e • ek := by
    rw [hH, hmul, hmul, hadd]
  have challenge_e : registrationChallenge taggedHash i = e := by
    simp [registrationChallenge_eq, heHash]
  rw [verifyRegistrationProofProp_eq C i responseBytes s rComm ekComm rhs ek e hs hr hek hR hek2 hch, hEq,
    lhs', registrationVerifySpec, registrationSchnorrEq, challenge_e]

end IdealOracleBridge

end AptosFormal.Experimental.ConfidentialAsset.Registration.SchnorrCompleteness
