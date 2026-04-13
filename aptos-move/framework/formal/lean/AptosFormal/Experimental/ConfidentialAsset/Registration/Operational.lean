/-
Copyright (c) Move Industries.

Operational `Option Unit` runner ↔ `verifyRegistrationProofProp` (first machine-checked control-flow link).

Models `assert!` / `option` success vs abort at the same branching structure as the spec.

See **`execVerifyRegistrationProof_eq_some_iff_pointEqBool_of_parsed`** for the post-parse branch: success
iff `pointEqBool` on the Schnorr LHS vs decompressed `R`, and
**`execVerifyRegistrationProof_eq_none_of_pointEqBool_false_of_parsed`** for the matching **`none`** branch.
-/

import AptosFormal.Experimental.ConfidentialAsset.Registration.VerifyMath
import AptosFormal.AptosStd.Crypto.Ristretto255

open AptosFormal.Experimental.ConfidentialAsset.Registration.Formal
open AptosFormal.AptosStd.Crypto.Ristretto255
open RegistrationVerify

namespace AptosFormal.Experimental.ConfidentialAsset.Registration.Operational

variable {Point : Type}

structure CryptoOracleWithBoolEq (Point : Type) extends CryptoOracle Point where
  pointEqBool : Point → Point → Bool
  pointEq_bool_iff : ∀ a b, pointEqBool a b = true ↔ pointEq a b

def execVerifyRegistrationProof (C : CryptoOracleWithBoolEq Point)
    (i : RegistrationFiatShamirInputs) (responseBytes : ByteArray) : Option Unit :=
  match C.scalarFromBytes responseBytes,
    compressed32? i.commitmentRBytes,
    compressed32? i.ekBytes with
  | some s, some rComm, some ekComm =>
      match C.pointDecompress rComm, C.pubkeyToPoint ekComm,
        C.challengeScalarFromMsg (registrationFiatShamirMsg i) with
      | some rhs, some ek, some e =>
          let H := C.hashToPointBase
          let lhs := C.pointAdd (C.pointMul H s) (C.pointMul ek e)
          if C.pointEqBool lhs rhs then
            some ()
          else
            none
      | _, _, _ => none
  | _, _, _ => none

theorem execVerifyRegistrationProof_iff (C : CryptoOracleWithBoolEq Point)
    (i : RegistrationFiatShamirInputs) (responseBytes : ByteArray) :
    execVerifyRegistrationProof C i responseBytes = some () ↔
      verifyRegistrationProofProp C.toCryptoOracle i responseBytes := by
  classical
  refine ⟨?mp, ?mpr⟩
  · -- mp: `exec = some ()` ⇒ `verifyRegistrationProofProp`
    intro h
    unfold execVerifyRegistrationProof at h
    rcases hs : C.scalarFromBytes responseBytes with (_ | s)
    · simp [hs] at h
    rcases hr : compressed32? i.commitmentRBytes with (_ | rComm)
    · simp [hs, hr] at h
    rcases hek : compressed32? i.ekBytes with (_ | ekComm)
    · simp [hs, hr, hek] at h
    rcases hR : C.pointDecompress rComm with (_ | rhs)
    · simp [hs, hr, hek, hR] at h
    rcases hpk : C.pubkeyToPoint ekComm with (_ | ek)
    · simp [hs, hr, hek, hR, hpk] at h
    rcases he : C.challengeScalarFromMsg (registrationFiatShamirMsg i) with (_ | e)
    · simp [hs, hr, hek, hR, hpk, he] at h
    let lhs := C.pointAdd (C.pointMul C.hashToPointBase s) (C.pointMul ek e)
    cases hb : C.pointEqBool lhs rhs
    · -- `pointEqBool` false ⇒ `exec` is `none`, contradicts `h`
      simp [hb, hs, hr, hek, hR, hpk, he, lhs] at h ⊢
    · -- `pointEqBool` true ⇒ `pointEq`
      simp [verifyRegistrationProofProp, hs, hr, hek, hR, hpk, he]
      exact (C.pointEq_bool_iff lhs rhs).mp hb
  · -- mpr: `verifyRegistrationProofProp` ⇒ `exec = some ()`
    intro hp
    unfold verifyRegistrationProofProp at hp
    unfold execVerifyRegistrationProof
    rcases hs : C.scalarFromBytes responseBytes with (_ | s)
    · simp [hs] at hp
    rcases hr : compressed32? i.commitmentRBytes with (_ | rComm)
    · simp [hs, hr] at hp
    rcases hek : compressed32? i.ekBytes with (_ | ekComm)
    · simp [hs, hr, hek] at hp
    rcases hR : C.pointDecompress rComm with (_ | rhs)
    · simp [hs, hr, hek, hR] at hp
    rcases hpk : C.pubkeyToPoint ekComm with (_ | ek)
    · simp [hs, hr, hek, hR, hpk] at hp
    rcases he : C.challengeScalarFromMsg (registrationFiatShamirMsg i) with (_ | e)
    · simp [hs, hr, hek, hR, hpk, he] at hp
    let lhs := C.pointAdd (C.pointMul C.hashToPointBase s) (C.pointMul ek e)
    simp [hs, hr, hek, hR, hpk, he] at hp
    have hb : C.pointEqBool lhs rhs = true := (C.pointEq_bool_iff lhs rhs).2 hp
    simp [hR, hpk, hb, lhs]

/-! ## Branch decomposition (challenge + curve check) -/

/--
When parsing succeeds through the challenge step, `execVerifyRegistrationProof` returns `some ()`
iff the native boolean equality reports **`true`** on the Schnorr LHS vs decompressed **`R`**.
-/
theorem execVerifyRegistrationProof_eq_some_iff_pointEqBool_of_parsed
    (C : CryptoOracleWithBoolEq Point) (i : RegistrationFiatShamirInputs) (responseBytes : ByteArray)
    (s : RistrettoScalar) (rComm ekComm : CompressedRistretto32) (rhs ek : Point) (e : RistrettoScalar)
    (hs : C.scalarFromBytes responseBytes = some s)
    (hr : compressed32? i.commitmentRBytes = some rComm)
    (hek : compressed32? i.ekBytes = some ekComm)
    (hR : C.pointDecompress rComm = some rhs)
    (hpk : C.pubkeyToPoint ekComm = some ek)
    (he : C.challengeScalarFromMsg (registrationFiatShamirMsg i) = some e) :
    execVerifyRegistrationProof C i responseBytes = some () ↔
      C.pointEqBool (C.pointAdd (C.pointMul C.hashToPointBase s) (C.pointMul ek e)) rhs = true := by
  unfold execVerifyRegistrationProof
  simp [hs, hr, hek, hR, hpk, he]

/--
Same parsed prefix as **`execVerifyRegistrationProof_eq_some_iff_pointEqBool_of_parsed`**: when the native
point equality reports **`false`**, the runner returns **`none`** (rejected proof).
-/
theorem execVerifyRegistrationProof_eq_none_of_pointEqBool_false_of_parsed
    (C : CryptoOracleWithBoolEq Point) (i : RegistrationFiatShamirInputs) (responseBytes : ByteArray)
    (s : RistrettoScalar) (rComm ekComm : CompressedRistretto32) (rhs ek : Point) (e : RistrettoScalar)
    (hs : C.scalarFromBytes responseBytes = some s)
    (hr : compressed32? i.commitmentRBytes = some rComm)
    (hek : compressed32? i.ekBytes = some ekComm)
    (hR : C.pointDecompress rComm = some rhs)
    (hpk : C.pubkeyToPoint ekComm = some ek)
    (he : C.challengeScalarFromMsg (registrationFiatShamirMsg i) = some e)
    (hfalse :
      C.pointEqBool (C.pointAdd (C.pointMul C.hashToPointBase s) (C.pointMul ek e)) rhs = false) :
    execVerifyRegistrationProof C i responseBytes = none := by
  unfold execVerifyRegistrationProof
  simp [hs, hr, hek, hR, hpk, he, hfalse]

end AptosFormal.Experimental.ConfidentialAsset.Registration.Operational
