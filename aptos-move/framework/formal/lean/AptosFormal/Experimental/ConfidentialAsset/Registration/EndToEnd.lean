/-
Copyright (c) Move Industries.

# End-to-end registration verification — group axioms ↔ Schnorr equation

Ties together every Lean module in the registration proof stack:

1. **TranscriptAlignment** — FS message bytes match Move golden (`native_decide`).
2. **VerifyMath** — `verifyRegistrationProofProp` reduces to the curve equation.
3. **SchnorrCompleteness** — honest prover satisfies the equation.
4. **GroupAxioms** — Move's `ristretto255` operations satisfy group laws (external).

## Main results

- `registration_verification_iff_schnorr` — for **any** inputs (under group axioms),
  Move's `verify_registration_proof` succeeds iff `s·H + e·ek = R`.
- `registration_honest_prover_accepted` — honest prover always passes.
- `golden_challenge_exists` / `golden2_challenge_exists` — the challenge scalar is
  well-defined for both golden scenarios.
- `golden_registration_verification_iff_schnorr` — instantiation at golden inputs.
- `registration_challenge_deterministic` — Fiat–Shamir challenge is unique.

## Remaining external obligations

See §6 of `REGISTRATION_VERIFY_REVIEW.md`:
- §6.1 VM semantics (Move execution matches `verifyRegistrationProofProp`)
- §6.2 Native correctness (`RistrettoGroupAxioms` holds for this branch's natives)
- §6.3 BCS address encoding
- §6.4 Cryptographic security (soundness / knowledge-soundness / Fiat–Shamir in ROM)
- §6.5 Primality of ℓ (currently an axiom)
-/

import AptosFormal.Experimental.ConfidentialAsset.Registration.Formal
import AptosFormal.Experimental.ConfidentialAsset.Registration.VerifyMath
import AptosFormal.Experimental.ConfidentialAsset.Registration.SchnorrCompleteness
import AptosFormal.Experimental.ConfidentialAsset.Registration.GroupAxioms
import AptosFormal.Experimental.ConfidentialAsset.Registration.TranscriptAlignment
import AptosFormal.Std.Crypto.Ristretto255

open AptosFormal.Experimental.ConfidentialAsset.Registration.Formal
open AptosFormal.Experimental.ConfidentialAsset.Registration.SchnorrCompleteness
open AptosFormal.Experimental.ConfidentialAsset.Registration.GroupAxioms
open AptosFormal.Std.Crypto.Ristretto255
open RegistrationVerify
open RegistrationTranscriptAlignment

namespace AptosFormal.Experimental.ConfidentialAsset.Registration.EndToEnd

/-! ## General verification equivalence (any inputs) -/

section General

variable {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]

/--
For **any** registration inputs where all decompressions succeed and the
challenge scalar exists, `verifyRegistrationProofProp` is equivalent to the
mathematical Schnorr equation `s • H + e • ek = R`.

This is the core semantic bridge: Move's `assert!(point_equals(...))` holds
iff the group-level equation does.
-/
theorem registration_verification_iff_schnorr
    (C : CryptoOracle Point)
    (ax : RistrettoGroupAxioms C)
    (i : RegistrationFiatShamirInputs) (responseBytes : ByteArray)
    (s : RistrettoScalar) (rComm ekComm : CompressedRistretto32) (rhs ek : Point)
    (e : RistrettoScalar)
    (parse_s : C.scalarFromBytes responseBytes = some s)
    (parse_rComm : compressed32? i.commitmentRBytes = some rComm)
    (parse_ekComm : compressed32? i.ekBytes = some ekComm)
    (decompress_R : C.pointDecompress rComm = some rhs)
    (decompress_ek : C.pubkeyToPoint ekComm = some ek)
    (challenge_some : registrationChallengeScalarMove
      (registrationFiatShamirMsg i) = some e) :
    verifyRegistrationProofProp C i responseBytes ↔
      s • C.hashToPointBase + e • ek = rhs := by
  have hch : C.challengeScalarFromMsg (registrationFiatShamirMsg i) = some e := by
    rw [ax.challenge_eq_move]; exact challenge_some
  rw [verifyRegistrationProofProp_eq C i responseBytes s rComm ekComm rhs ek e
    parse_s parse_rComm parse_ekComm decompress_R decompress_ek hch]
  simp only [ax.mul_eq_smul, ax.add_eq_add, ax.eq_iff_eq]

/--
**Completeness** (general): an honest prover who knows `dk_inv` with
`ek = dk_inv • H` and commits `R = k • H` can always produce a response
`s = k − e · dk_inv` that passes verification.
-/
theorem registration_honest_prover_accepted
    (C : CryptoOracle Point)
    (ax : RistrettoGroupAxioms C)
    (i : RegistrationFiatShamirInputs) (responseBytes : ByteArray)
    (s : RistrettoScalar) (rComm ekComm : CompressedRistretto32) (rhs ek : Point)
    (e : RistrettoScalar)
    (parse_s : C.scalarFromBytes responseBytes = some s)
    (parse_rComm : compressed32? i.commitmentRBytes = some rComm)
    (parse_ekComm : compressed32? i.ekBytes = some ekComm)
    (decompress_R : C.pointDecompress rComm = some rhs)
    (decompress_ek : C.pubkeyToPoint ekComm = some ek)
    (challenge_some : registrationChallengeScalarMove
      (registrationFiatShamirMsg i) = some e)
    (k dk_inv : RistrettoScalar)
    (hR : rhs = k • C.hashToPointBase)
    (hek : ek = dk_inv • C.hashToPointBase)
    (hs : s = k - e * dk_inv) :
    verifyRegistrationProofProp C i responseBytes := by
  rw [registration_verification_iff_schnorr C ax i responseBytes s rComm ekComm rhs ek e
    parse_s parse_rComm parse_ekComm decompress_R decompress_ek challenge_some]
  exact registrationSchnorr_completeness C.hashToPointBase ek rhs k e dk_inv s hR hek hs

/-- The Fiat–Shamir challenge scalar is uniquely determined by the public inputs. -/
theorem registration_challenge_deterministic
    (i : RegistrationFiatShamirInputs) (e₁ e₂ : RistrettoScalar)
    (h₁ : registrationChallengeScalarMove (registrationFiatShamirMsg i) = some e₁)
    (h₂ : registrationChallengeScalarMove (registrationFiatShamirMsg i) = some e₂) :
    e₁ = e₂ := by
  rw [h₁] at h₂; exact Option.some.inj h₂

end General

/-! ## Golden-specific instantiation (chain_id=9, @0x1/@0x2/@0x3) -/

section Golden

variable {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]

/-- The challenge scalar exists for the first golden registration inputs
(follows from `TranscriptAlignment`). -/
theorem golden_challenge_exists :
    ∃ e, registrationChallengeScalarMove
      (registrationFiatShamirMsg goldenRegistrationInputs) = some e := by
  have hne : registrationChallengeScalarMove
      (registrationFiatShamirMsg goldenRegistrationInputs) ≠ none := by
    rw [registration_fiat_shamir_msg_matches_move_golden]
    exact registration_challenge_scalar_is_some
  generalize registrationChallengeScalarMove
    (registrationFiatShamirMsg goldenRegistrationInputs) = o at hne ⊢
  cases o with
  | none => exact absurd rfl hne
  | some e => exact ⟨e, rfl⟩

/--
**End-to-end theorem for the golden inputs.** Under the Ristretto group axioms,
`verify_registration_proof` on the golden scenario (`chain_id=9`,
`@0x1`/`@0x2`/`@0x3`, basepoint `ek`/`R`) accepts iff the Schnorr equation
holds, with challenge `e` uniquely determined by the Move tagged-hash pipeline.

This machine-checks the full chain:

- Transcript bytes match Move (`native_decide` in `TranscriptAlignment`)
- Tagged SHA3-512 hash produces a valid scalar (`native_decide`)
- Group equation is the mathematical Schnorr check (algebraic proof)
- Honest prover completeness (algebraic proof)

**Remaining external obligations**: §6.1–6.6 of `REGISTRATION_VERIFY_REVIEW.md`.
-/
theorem golden_registration_verification_iff_schnorr
    (C : CryptoOracle Point)
    (ax : RistrettoGroupAxioms C)
    (responseBytes : ByteArray)
    (s : RistrettoScalar) (rComm ekComm : CompressedRistretto32) (rhs ek : Point)
    (e : RistrettoScalar)
    (parse_s : C.scalarFromBytes responseBytes = some s)
    (parse_rComm : compressed32? goldenRegistrationInputs.commitmentRBytes = some rComm)
    (parse_ekComm : compressed32? goldenRegistrationInputs.ekBytes = some ekComm)
    (decompress_R : C.pointDecompress rComm = some rhs)
    (decompress_ek : C.pubkeyToPoint ekComm = some ek)
    (challenge_some : registrationChallengeScalarMove
      (registrationFiatShamirMsg goldenRegistrationInputs) = some e) :
    verifyRegistrationProofProp C goldenRegistrationInputs responseBytes ↔
      s • C.hashToPointBase + e • ek = rhs :=
  registration_verification_iff_schnorr C ax _ responseBytes s rComm ekComm rhs ek e
    parse_s parse_rComm parse_ekComm decompress_R decompress_ek challenge_some

/-- Honest prover always succeeds for the golden inputs. -/
theorem golden_registration_completeness
    (C : CryptoOracle Point)
    (ax : RistrettoGroupAxioms C)
    (responseBytes : ByteArray)
    (s : RistrettoScalar) (rComm ekComm : CompressedRistretto32) (rhs ek : Point)
    (e : RistrettoScalar)
    (parse_s : C.scalarFromBytes responseBytes = some s)
    (parse_rComm : compressed32? goldenRegistrationInputs.commitmentRBytes = some rComm)
    (parse_ekComm : compressed32? goldenRegistrationInputs.ekBytes = some ekComm)
    (decompress_R : C.pointDecompress rComm = some rhs)
    (decompress_ek : C.pubkeyToPoint ekComm = some ek)
    (challenge_some : registrationChallengeScalarMove
      (registrationFiatShamirMsg goldenRegistrationInputs) = some e)
    (k dk_inv : RistrettoScalar)
    (hR : rhs = k • C.hashToPointBase)
    (hek : ek = dk_inv • C.hashToPointBase)
    (hs : s = k - e * dk_inv) :
    verifyRegistrationProofProp C goldenRegistrationInputs responseBytes :=
  registration_honest_prover_accepted C ax _ responseBytes s rComm ekComm rhs ek e
    parse_s parse_rComm parse_ekComm decompress_R decompress_ek challenge_some k dk_inv hR hek hs

end Golden

/-! ## Second golden (chain_id=42, @0x10/@0x20/@0x30) -/

section Golden2

variable {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]

/-- The challenge scalar exists for the second golden registration inputs. -/
theorem golden2_challenge_exists :
    ∃ e, registrationChallengeScalarMove
      (registrationFiatShamirMsg goldenRegistrationInputs2) = some e := by
  have hne : registrationChallengeScalarMove
      (registrationFiatShamirMsg goldenRegistrationInputs2) ≠ none := by
    rw [registration_fiat_shamir_msg_matches_golden_2]
    exact registration_challenge_scalar_is_some_2
  generalize registrationChallengeScalarMove
    (registrationFiatShamirMsg goldenRegistrationInputs2) = o at hne ⊢
  cases o with
  | none => exact absurd rfl hne
  | some e => exact ⟨e, rfl⟩

/-- End-to-end theorem for the second golden inputs. -/
theorem golden2_registration_verification_iff_schnorr
    (C : CryptoOracle Point)
    (ax : RistrettoGroupAxioms C)
    (responseBytes : ByteArray)
    (s : RistrettoScalar) (rComm ekComm : CompressedRistretto32) (rhs ek : Point)
    (e : RistrettoScalar)
    (parse_s : C.scalarFromBytes responseBytes = some s)
    (parse_rComm : compressed32? goldenRegistrationInputs2.commitmentRBytes = some rComm)
    (parse_ekComm : compressed32? goldenRegistrationInputs2.ekBytes = some ekComm)
    (decompress_R : C.pointDecompress rComm = some rhs)
    (decompress_ek : C.pubkeyToPoint ekComm = some ek)
    (challenge_some : registrationChallengeScalarMove
      (registrationFiatShamirMsg goldenRegistrationInputs2) = some e) :
    verifyRegistrationProofProp C goldenRegistrationInputs2 responseBytes ↔
      s • C.hashToPointBase + e • ek = rhs :=
  registration_verification_iff_schnorr C ax _ responseBytes s rComm ekComm rhs ek e
    parse_s parse_rComm parse_ekComm decompress_R decompress_ek challenge_some

end Golden2

end AptosFormal.Experimental.ConfidentialAsset.Registration.EndToEnd
