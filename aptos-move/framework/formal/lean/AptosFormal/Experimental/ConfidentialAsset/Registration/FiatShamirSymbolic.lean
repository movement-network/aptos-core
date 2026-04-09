/-
Copyright (c) Move Industries.

# Symbolic Fiat–Shamir model for registration Schnorr

Machine-checked proofs that the Fiat–Shamir transform of the registration
Schnorr protocol inherits the interactive protocol's security properties
under a symbolic (abstract function) hash model.

## Results

| Theorem | Property |
|---------|----------|
| `fiatShamir_forking_extraction` | Two oracle worlds → witness extraction |
| `fiatShamir_forking_explicit` | Explicit extraction formula `dk = (s₁−s₂)⁻¹(e₂−e₁)` |
| `fiatShamir_challenge_binding` | Fixed oracle → no forking possible |
| `fiatShamir_completeness` | Honest NIZK prover always passes |
| `fiatShamir_nizk_simulate_accepts` | Simulator produces valid proofs without witness |

## What this captures

The Fiat–Shamir transform replaces the verifier's random challenge with
`e := taggedHash(fsMsg)`.  We model `taggedHash` as an abstract function
`ByteArray → RistrettoScalar` and prove:

- **Forking reduction**: if an adversary's proof passes under *two different*
  hash functions that disagree on the FS message, the witness `dk` can be
  extracted.  This is the algebraic core of the ROM forking lemma [PS00].
- **Challenge binding**: for a *single* hash function, two proofs with the
  same commitment `R` must share the same challenge — so forking requires
  oracle reprogramming.
- **Completeness** and **NIZK zero-knowledge** (simulation with programmed oracle).

## Remaining gap

The **probability** that an adversary triggers the forking condition is not
formalized.  In [PS00], this is shown via a rewinding argument over a random
oracle; formalizing it requires a probability monad or game-based framework
and is out of scope.

## Connection to Move

`fiatShamirVerify` is the abstract form of the Schnorr equation `s•H + e•ek = R`
on the RHS of `registration_verification_iff_schnorr` in `EndToEnd.lean`.  The
symbolic security theorems here apply to `verifyRegistrationProofProp` via that
bridge: every `verifyRegistrationProofProp` instance that passes also satisfies
`fiatShamirVerify` (with `e = taggedHash(fsMsg)`, `H = hashToPointBase`).
-/

import AptosFormal.Experimental.ConfidentialAsset.Registration.CryptoSecurity

open AptosFormal.Experimental.ConfidentialAsset.Registration.CryptoSecurity
open AptosFormal.Std.Crypto.Ristretto255

namespace AptosFormal.Experimental.ConfidentialAsset.Registration.FiatShamirSymbolic

/-! ## Definitions -/

/-- Fiat–Shamir NIZK verification: challenge derived from `taggedHash(fsMsg)`. -/
def fiatShamirVerify {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]
    (taggedHash : ByteArray → RistrettoScalar)
    (H ek R : Point) (s : RistrettoScalar) (fsMsg : ByteArray) : Prop :=
  s • H + (taggedHash fsMsg) • ek = R

/--
Fiat–Shamir honest prover: returns `(R, s)` where `R = k • H` and
`s = k − e · dk_inv` with `e = taggedHash(fsMsg)`.
-/
def fiatShamirProve {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]
    (taggedHash : ByteArray → RistrettoScalar)
    (H : Point) (dk_inv k : RistrettoScalar)
    (fsMsg : ByteArray) : Point × RistrettoScalar :=
  (k • H, k - taggedHash fsMsg * dk_inv)

/-- Programmed oracle returning a fixed challenge (used by the simulator). -/
def programmedOracle (e : RistrettoScalar) : ByteArray → RistrettoScalar :=
  fun _ => e

/-! ## §6.4c-i  Forking reduction (algebraic core of ROM proof [PS00]) -/

section Forking

variable {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]

/--
**Forking reduction** (existential form).

Two valid NIZK proofs in "oracle worlds" assigning different challenges to
the same FS message yield witness extraction: `∃ dk, H = dk • ek`.

In the full ROM proof [PS00], one argues that a successful adversary can be
rewound with a reprogrammed oracle to produce exactly this two-world
scenario; here we prove the algebraic consequence.
-/
theorem fiatShamir_forking_extraction
    (taggedHash₁ taggedHash₂ : ByteArray → RistrettoScalar)
    (H ek R : Point) (s₁ s₂ : RistrettoScalar) (fsMsg : ByteArray)
    (hne : taggedHash₁ fsMsg ≠ taggedHash₂ fsMsg) (hek : ek ≠ 0)
    (h₁ : fiatShamirVerify taggedHash₁ H ek R s₁ fsMsg)
    (h₂ : fiatShamirVerify taggedHash₂ H ek R s₂ fsMsg) :
    ∃ dk : RistrettoScalar, H = dk • ek :=
  registrationSchnorr_special_soundness H ek R s₁ s₂
    (taggedHash₁ fsMsg) (taggedHash₂ fsMsg) hne hek h₁ h₂

/--
**Forking reduction** (explicit extraction formula).

The extracted witness is `dk = (s₁ − s₂)⁻¹ · (e₂ − e₁)` where
`eᵢ = taggedHashᵢ(fsMsg)`.
-/
theorem fiatShamir_forking_explicit
    (taggedHash₁ taggedHash₂ : ByteArray → RistrettoScalar)
    (H ek R : Point) (s₁ s₂ : RistrettoScalar) (fsMsg : ByteArray)
    (hne : taggedHash₁ fsMsg ≠ taggedHash₂ fsMsg) (hek : ek ≠ 0)
    (h₁ : fiatShamirVerify taggedHash₁ H ek R s₁ fsMsg)
    (h₂ : fiatShamirVerify taggedHash₂ H ek R s₂ fsMsg) :
    H = ((s₁ - s₂)⁻¹ * ((taggedHash₂ fsMsg) - (taggedHash₁ fsMsg))) • ek :=
  registrationSchnorr_witness_extraction H ek R s₁ s₂
    (taggedHash₁ fsMsg) (taggedHash₂ fsMsg) hne hek h₁ h₂

end Forking

/-! ## §6.4c-ii  Challenge binding (single-oracle non-forkability) -/

section Binding

variable {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]

/--
**Challenge binding**: for a fixed hash function and fixed FS message, two
valid proofs targeting the same commitment `R` must satisfy `s₁ • H = s₂ • H`
(since both use the identical deterministic challenge `e = taggedHash(fsMsg)`).

A single-oracle adversary therefore cannot produce the two-world forking
scenario.  This is why the ROM — which allows oracle reprogramming between
the two worlds — is needed for the full knowledge-soundness argument.
-/
theorem fiatShamir_challenge_binding
    (taggedHash : ByteArray → RistrettoScalar)
    (H ek R : Point) (s₁ s₂ : RistrettoScalar) (fsMsg : ByteArray)
    (h₁ : fiatShamirVerify taggedHash H ek R s₁ fsMsg)
    (h₂ : fiatShamirVerify taggedHash H ek R s₂ fsMsg) :
    s₁ • H = s₂ • H := by
  simp only [fiatShamirVerify] at h₁ h₂
  exact add_right_cancel (h₁.trans h₂.symm)

end Binding

/-! ## §6.4c-iii  NIZK completeness -/

section Completeness

variable {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]

/--
**NIZK completeness**: the honest Fiat–Shamir prover (who knows `dk_inv`
with `ek = dk_inv • H`) always produces a valid proof.

The proof output is `R = k • H`, `s = k − taggedHash(fsMsg) · dk_inv` —
exactly the output of `fiatShamirProve`.
-/
theorem fiatShamir_completeness
    (taggedHash : ByteArray → RistrettoScalar)
    (H : Point) (dk_inv k : RistrettoScalar)
    (ek : Point) (hek : ek = dk_inv • H)
    (fsMsg : ByteArray) :
    fiatShamirVerify taggedHash H ek (k • H) (k - taggedHash fsMsg * dk_inv) fsMsg := by
  simp only [fiatShamirVerify]
  rw [hek, sub_smul, ← smul_smul (taggedHash fsMsg) dk_inv H, sub_add_cancel]

end Completeness

/-! ## §6.4c-iv  NIZK zero-knowledge (simulation with programmed oracle) -/

section ZeroKnowledge

variable {Point : Type} [AddCommGroup Point] [Module RistrettoScalar Point]

/--
**NIZK simulator**: given statement `(H, ek)` and uniform `(e, s)`, define
`R := s • H + e • ek` and program the oracle to return `e`.  The resulting
`(R, s)` is a valid proof under the programmed oracle — no witness needed.

This shows the Fiat–Shamir transform preserves honest-verifier zero-knowledge
when the simulator can program the random oracle [PS00, §4].
-/
theorem fiatShamir_nizk_simulate_accepts
    (H ek : Point) (e s : RistrettoScalar) (fsMsg : ByteArray) :
    fiatShamirVerify (programmedOracle e) H ek (s • H + e • ek) s fsMsg := by
  simp [fiatShamirVerify, programmedOracle]

end ZeroKnowledge

end AptosFormal.Experimental.ConfidentialAsset.Registration.FiatShamirSymbolic
