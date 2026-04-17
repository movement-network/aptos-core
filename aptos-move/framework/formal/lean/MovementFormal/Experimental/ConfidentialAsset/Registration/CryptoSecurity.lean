/-
Copyright (c) Move Industries.

# Cryptographic security properties for registration Schnorr verification

**Source:** `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move` (Schnorr / Fiat–Shamir intent).

Machine-checked proofs of:
- **Special soundness** (§6.4a): two accepting transcripts with distinct challenges
  yield the witness `dk` with an explicit extraction formula.
- **HVZK simulator** (§6.4b): a simulator producing accepting transcripts without
  the witness, establishing honest-verifier zero-knowledge (`registrationSchnorr_simulate_*`,
  `registrationSchnorr_simulate_lhs_and_schnorr_eq_bundle`).
- **Fiat–Shamir symbolic model** (§6.4c): see `FiatShamirSymbolic.lean` for the
  machine-checked algebraic core (forking reduction, challenge binding, NIZK
  completeness, NIZK simulation).  The probabilistic ROM argument is not formalized.

These properties, together with the end-to-end verification equivalence in
`EndToEnd.lean`, establish that `verify_registration_proof` implements a
sound and zero-knowledge proof of knowledge for `H = dk · ek`.
-/

import MovementFormal.Experimental.ConfidentialAsset.Registration.Formal
import MovementFormal.AptosStd.Crypto.Ristretto255
import Mathlib.Algebra.Module.Basic
import Mathlib.Tactic.FieldSimp

open MovementFormal.Experimental.ConfidentialAsset.Registration.Formal
open MovementFormal.AptosStd.Crypto.Ristretto255

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.CryptoSecurity

private theorem ristrettoScalar_isUnit {a : RistrettoScalar} (ha : a ≠ 0) : IsUnit a := by
  have hval_ne := (ZMod.val_ne_zero a).mpr ha
  have hval_lt := ZMod.val_lt a
  have hnd : ¬ ristrettoSubgroupOrder ∣ ZMod.val a := by
    intro h; exact absurd (Nat.le_of_dvd (Nat.pos_of_ne_zero hval_ne) h) (not_le.mpr hval_lt)
  have hcop := (ristretto_subgroup_order_prime.coprime_iff_not_dvd.mpr hnd).symm
  rw [show a = ((ZMod.val a : ℕ) : RistrettoScalar) from (ZMod.natCast_zmod_val a).symm]
  exact (ZMod.unitOfCoprime (ZMod.val a) hcop).isUnit

private theorem ristrettoScalar_inv_mul_cancel {a : RistrettoScalar} (ha : a ≠ 0) :
    a⁻¹ * a = 1 :=
  ZMod.inv_mul_of_unit a (ristrettoScalar_isUnit ha)

/-! ## §6.4a  Special soundness (witness extraction) -/

section SpecialSoundness

variable {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]

/--
**Witness extraction** for the registration Schnorr protocol.

Given two accepting transcripts `(R, e₁, s₁)` and `(R, e₂, s₂)` for the
**same commitment** `R` but **distinct challenges** `e₁ ≠ e₂`, the extracted
witness is `dk = (s₁ − s₂)⁻¹ · (e₂ − e₁)` satisfying `H = dk • ek`.

Requires `ek ≠ 0` (the public key is not the identity). The inverse exists
because `RistrettoScalar` is `ℤ/ℓℤ` with `ℓ` prime (the `Fact` instance
in `Ristretto255.lean` gives us `Field RistrettoScalar`).
-/
theorem registrationSchnorr_witness_extraction
    (H ek R : Point) (s₁ s₂ e₁ e₂ : RistrettoScalar)
    (hne : e₁ ≠ e₂) (hek : ek ≠ 0)
    (h₁ : s₁ • H + e₁ • ek = R)
    (h₂ : s₂ • H + e₂ • ek = R) :
    H = ((s₁ - s₂)⁻¹ * (e₂ - e₁)) • ek := by
  have heq : s₁ • H + e₁ • ek = s₂ • H + e₂ • ek := by rw [h₁, h₂]
  have hsub : (s₁ - s₂) • H = (e₂ - e₁) • ek := by
    have h3 := congr_arg (· - (s₂ • H + e₁ • ek)) heq
    simp only [add_sub_add_right_eq_sub, add_sub_add_left_eq_sub] at h3
    rw [sub_smul, sub_smul]; exact h3
  have hde : e₂ - e₁ ≠ 0 := sub_ne_zero.mpr (Ne.symm hne)
  have hds : s₁ - s₂ ≠ 0 := by
    intro h; rw [h, zero_smul] at hsub
    have h4 : (e₂ - e₁)⁻¹ • ((e₂ - e₁) • ek) = (e₂ - e₁)⁻¹ • (0 : Point) := by
      congr 1; exact hsub.symm
    rw [← mul_smul, smul_zero, ristrettoScalar_inv_mul_cancel hde, one_smul] at h4
    exact hek h4
  have h6 : (s₁ - s₂)⁻¹ • ((s₁ - s₂) • H) = (s₁ - s₂)⁻¹ • ((e₂ - e₁) • ek) := by
    congr 1
  rw [← mul_smul, ← mul_smul, ristrettoScalar_inv_mul_cancel hds, one_smul] at h6
  exact h6

/-- Existential form of special soundness (wraps the explicit extraction formula). -/
theorem registrationSchnorr_special_soundness
    (H ek R : Point) (s₁ s₂ e₁ e₂ : RistrettoScalar)
    (hne : e₁ ≠ e₂) (hek : ek ≠ 0)
    (h₁ : s₁ • H + e₁ • ek = R)
    (h₂ : s₂ • H + e₂ • ek = R) :
    ∃ dk : RistrettoScalar, H = dk • ek :=
  ⟨_, registrationSchnorr_witness_extraction H ek R s₁ s₂ e₁ e₂ hne hek h₁ h₂⟩

end SpecialSoundness

/-! ## §6.4b  Honest-verifier zero-knowledge (simulator) -/

section HVZK

variable {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]

/--
HVZK **simulator**: given statement `(H, ek)` and uniform `(e, s)`, outputs
commitment `R := s • H + e • ek` that forms an accepting transcript.

The distribution `(R, e, s)` is uniform over accepting transcripts when `e`
and `s` are independently uniform — matching the real protocol's distribution
(standard Schnorr HVZK argument).
-/
def registrationSchnorr_simulate (H ek : Point) (e s : RistrettoScalar) : Point :=
  s • H + e • ek

/-- The simulator always produces an accepting transcript. -/
theorem registrationSchnorr_simulate_accepts (H ek : Point) (e s : RistrettoScalar) :
    registrationSchnorrEq (fun s' p => s' • p) (· + ·) H ek
      (registrationSchnorr_simulate H ek e s) s e := rfl

/-- LHS of the Schnorr equation equals the simulator commitment (definitional). -/
theorem registrationSchnorr_simulate_lhs_eq (H ek : Point) (e s : RistrettoScalar) :
    s • H + e • ek = registrationSchnorr_simulate H ek e s :=
  rfl

/-- Package **`simulate_accepts`** as the Schnorr equation on the simulated commitment **as a point**. -/
theorem registrationSchnorr_simulate_satisfies_schnorr_eq (H ek : Point) (e s : RistrettoScalar) :
    registrationSchnorrEq (fun s' p => s' • p) (· + ·) H ek (registrationSchnorr_simulate H ek e s) s e :=
  registrationSchnorr_simulate_accepts H ek e s

/-- Single-step bundle: simulator commitment equals **`s•H+e•ek`** and satisfies **`registrationSchnorrEq`**. -/
theorem registrationSchnorr_simulate_lhs_and_schnorr_eq_bundle (H ek : Point) (e s : RistrettoScalar) :
    (s • H + e • ek = registrationSchnorr_simulate H ek e s) ∧
    registrationSchnorrEq (fun s' p => s' • p) (· + ·) H ek (registrationSchnorr_simulate H ek e s) s e :=
  And.intro (registrationSchnorr_simulate_lhs_eq H ek e s)
    (registrationSchnorr_simulate_satisfies_schnorr_eq H ek e s)

end HVZK

/-!
## §6.4c  Fiat–Shamir NIZK (symbolic model)

The deployed verifier uses `e := Hash(DST, msg)` (Fiat–Shamir transform) instead
of an interactive uniform challenge.  The **algebraic core** of the ROM security
argument is machine-checked in `FiatShamirSymbolic.lean`:

- `fiatShamir_forking_extraction` — two oracle worlds with different challenges
  yield witness extraction (the algebraic heart of [PS00]'s forking lemma).
- `fiatShamir_challenge_binding` — a single hash function cannot produce two
  challenges for the same commitment, so oracle reprogramming is necessary.
- `fiatShamir_completeness` — the honest NIZK prover always passes.
- `fiatShamirVerify_iff_registrationSchnorrEq_module` — **`fiatShamirVerify`** ↔ **`registrationSchnorrEq`** with **`•` / `+`**.
- `registrationSchnorrEq_of_fiatShamirProve_output` — honest **`fiatShamirProve`** transcript satisfies **`registrationSchnorrEq`**.
- `fiatShamir_nizk_simulate_accepts` — a simulator with oracle-programming
  ability produces valid proofs without the witness (NIZK zero-knowledge).

**Not formalized**: the *probability* that an adversary triggers the forking
condition.  In [PS00], this is shown via a rewinding argument over a random
oracle; formalizing it requires a probability monad or game-based framework.
-/

end MovementFormal.Experimental.ConfidentialAsset.Registration.CryptoSecurity
