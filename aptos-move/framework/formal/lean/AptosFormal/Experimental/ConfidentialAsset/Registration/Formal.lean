/-
Copyright (c) Move Industries.

# Registration Schnorr + Fiat–Shamir (experimental confidential asset)

Lean **does not** execute Move. This module formalizes the *mathematical intent* of:

`aptos_experimental::confidential_proof::verify_registration_proof`

**Source of truth:** this repository’s Move —  
`aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`

**Layout:** lives under `AptosFormal.Experimental.ConfidentialAsset.Registration` because the verifier
is in `aptos-experimental`; shared crypto primitives are under `AptosFormal.Std.*` for reuse across
the framework formalization.

Progress: `registrationFiatShamirMsg` → `registrationChallenge` → `registrationVerifySpec`.
-/

namespace AptosFormal.Experimental.ConfidentialAsset.Registration.Formal

/-!
## Fiat–Shamir transcript for registration (spec alignment)

Matches `verify_registration_proof`: the byte vector `msg` built immediately before
`new_scalar_from_tagged_hash(FIAT_SHAMIR_REGISTRATION_SIGMA_DST, msg)`.

Move reference: `confidential_proof.move` lines 223–229.

Each `senderBcs` / `contractBcs` / `tokenBcs` field is an arbitrary `ByteArray` standing in for
`std::bcs::to_bytes(&address)`. For **fixed** small addresses (`@0x1` …) and the Ristretto basepoint,
see `TranscriptAlignment.lean`, which proves `registrationFiatShamirMsg` matches Move’s
`registration_fs_message_for_test` golden bytes.
-/

/-- Public inputs hashed for the registration FS challenge (**no** response scalar `s`). -/
structure RegistrationFiatShamirInputs where
  chainId : UInt8
  senderBcs : ByteArray
  contractBcs : ByteArray
  tokenBcs : ByteArray
  ekBytes : ByteArray
  commitmentRBytes : ByteArray

/-- Concatenation order matches Move `msg.append` sequence (singleton byte, then each chunk). -/
def registrationFiatShamirMsg (i : RegistrationFiatShamirInputs) : ByteArray :=
  ByteArray.mk #[i.chainId] ++ i.senderBcs ++ i.contractBcs ++ i.tokenBcs ++ i.ekBytes
    ++ i.commitmentRBytes

theorem registrationFiatShamirMsg_congr {a b : RegistrationFiatShamirInputs} (h : a = b) :
    registrationFiatShamirMsg a = registrationFiatShamirMsg b := by
  rw [h]

section RegistrationChallenge

variable {Scalar : Type}

def registrationChallenge (taggedHash : ByteArray → Scalar) (i : RegistrationFiatShamirInputs) : Scalar :=
  taggedHash (registrationFiatShamirMsg i)

@[simp] theorem registrationChallenge_eq (taggedHash : ByteArray → Scalar)
    (i : RegistrationFiatShamirInputs) :
    registrationChallenge taggedHash i = taggedHash (registrationFiatShamirMsg i) :=
  rfl

theorem registrationChallenge_input_congr (taggedHash : ByteArray → Scalar) {i j : RegistrationFiatShamirInputs}
    (h : i = j) : registrationChallenge taggedHash i = registrationChallenge taggedHash j := by
  rw [h]

theorem registrationChallenge_hash_agree (i : RegistrationFiatShamirInputs) {f g : ByteArray → Scalar}
    (hfg : f (registrationFiatShamirMsg i) = g (registrationFiatShamirMsg i)) :
    registrationChallenge f i = registrationChallenge g i := by
  simp [registrationChallenge, hfg]

theorem registrationChallenge_msg_congr {Scalar : Type} (taggedHash : ByteArray → Scalar)
    {i j : RegistrationFiatShamirInputs} (h : registrationFiatShamirMsg i = registrationFiatShamirMsg j) :
    registrationChallenge taggedHash i = registrationChallenge taggedHash j := by
  simp [registrationChallenge, h]

theorem registrationFiatShamirMsg_eq_of_injective_challenge_eq {Scalar : Type} (taggedHash : ByteArray → Scalar)
    {i j : RegistrationFiatShamirInputs} (hinj : Function.Injective taggedHash)
    (h : registrationChallenge taggedHash i = registrationChallenge taggedHash j) :
    registrationFiatShamirMsg i = registrationFiatShamirMsg j := by
  have hbytes : taggedHash (registrationFiatShamirMsg i) = taggedHash (registrationFiatShamirMsg j) := by
    simpa [registrationChallenge_eq] using h
  exact hinj hbytes

end RegistrationChallenge

section RegistrationSchnorr

variable {Point Scalar : Type}

def registrationSchnorrEq (smul : Scalar → Point → Point) (add : Point → Point → Point)
    (H ek R : Point) (s e : Scalar) : Prop :=
  add (smul s H) (smul e ek) = R

def registrationVerifySpec (smul : Scalar → Point → Point) (add : Point → Point → Point)
    (taggedHash : ByteArray → Scalar)
    (i : RegistrationFiatShamirInputs) (H ek R : Point) (s : Scalar) : Prop :=
  registrationSchnorrEq smul add H ek R s (registrationChallenge taggedHash i)

theorem registrationVerifySpec_eq (smul : Scalar → Point → Point) (add : Point → Point → Point)
    (taggedHash : ByteArray → Scalar)
    (i : RegistrationFiatShamirInputs) (H ek R : Point) (s : Scalar) :
    registrationVerifySpec smul add taggedHash i H ek R s ↔
      registrationSchnorrEq smul add H ek R s (taggedHash (registrationFiatShamirMsg i)) := by
  rfl

theorem registrationVerifySpec_input_congr (smul : Scalar → Point → Point) (add : Point → Point → Point)
    (taggedHash : ByteArray → Scalar) {i j : RegistrationFiatShamirInputs} (H ek R : Point) (s : Scalar)
    (h : i = j) :
    registrationVerifySpec smul add taggedHash i H ek R s ↔
      registrationVerifySpec smul add taggedHash j H ek R s := by
  cases h
  rfl

theorem registrationVerifySpec_hash_agree (smul : Scalar → Point → Point) (add : Point → Point → Point)
    (i : RegistrationFiatShamirInputs) (H ek R : Point) (s : Scalar) {f g : ByteArray → Scalar}
    (hfg : f (registrationFiatShamirMsg i) = g (registrationFiatShamirMsg i)) :
    registrationVerifySpec smul add f i H ek R s ↔ registrationVerifySpec smul add g i H ek R s := by
  simp [registrationVerifySpec, registrationSchnorrEq, registrationChallenge, hfg]

end RegistrationSchnorr

def registrationFormalRoot : String :=
  "AptosFormal.Experimental.ConfidentialAsset.Registration / verify_registration_proof (spec alignment)"

def regMsgTiny : RegistrationFiatShamirInputs where
  chainId := 7
  senderBcs := ByteArray.empty
  contractBcs := ByteArray.empty
  tokenBcs := ByteArray.empty
  ekBytes := ByteArray.empty
  commitmentRBytes := ByteArray.empty

example : registrationFiatShamirMsg regMsgTiny = ByteArray.mk #[7] := rfl

example :
    registrationFiatShamirMsg
        { chainId := 3
          senderBcs := ByteArray.mk #[10, 11]
          contractBcs := ByteArray.empty
          tokenBcs := ByteArray.empty
          ekBytes := ByteArray.empty
          commitmentRBytes := ByteArray.empty } =
      ByteArray.mk #[3, 10, 11] := rfl

end AptosFormal.Experimental.ConfidentialAsset.Registration.Formal
