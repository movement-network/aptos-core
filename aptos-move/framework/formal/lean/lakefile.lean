import Lake
open Lake DSL

/-!
Lake package **`AptosFormal`**: Aptos Move framework formalization (Lean 4).

- **`AptosFormal.Std.*`** — primitives aligned with **`aptos-stdlib`** / shared framework (e.g. SHA3-512,
  Ristretto scalar scaffolding). Intended for reuse when formalizing **`aptos_framework`** and beyond.
- **`AptosFormal.Experimental.ConfidentialAsset.Registration.*`** — registration proof verifier spec
  (`confidential_proof.move` `verify_registration_proof` in this repo).

Open this directory as the Lean project root (`lake build`). Primary Move anchor:  
`aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`.
-/

package «AptosFormal» where

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.24.0"

@[default_target]
lean_lib «AptosFormal» where
  roots := #[
    `AptosFormal.Std.Hash.Keccak,
    `AptosFormal.Std.Hash.Sha3_256,
    `AptosFormal.Std.Hash.Sha3_512,
    `AptosFormal.Std.Bcs.Primitives,
    `AptosFormal.Std.MoveStdlibGoldens,
    `AptosFormal.Std.Crypto.Ristretto255,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.Formal,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.VerifyMath,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.Refinement,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.SchnorrCompleteness,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.Operational,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.TranscriptAlignment,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.GroupAxioms,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.EndToEnd,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.CryptoSecurity
  ]
