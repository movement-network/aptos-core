/-
Copyright (c) Move Industries.

Refinement notes: Lean `Prop` vs this repo’s Move `verify_registration_proof`
(`aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`).

See `REGISTRATION_VERIFY_REVIEW.md` (under `aptos-move/framework/formal/`) for obligations §6.
-/

import AptosFormal.Experimental.ConfidentialAsset.Registration.VerifyMath

open AptosFormal.Experimental.ConfidentialAsset.Registration.Formal
open RegistrationVerify

namespace RegistrationRefinement

def verifyRegistrationProofPropMove {Point : Type} (rest : CryptoOracle Point)
    (i : RegistrationFiatShamirInputs) (rb : ByteArray) : Prop :=
  verifyRegistrationProofProp
    { rest with challengeScalarFromMsg := registrationChallengeScalarMove } i rb

end RegistrationRefinement
