import Lake
open Lake DSL

/-!
Lake package **`AptosFormal`**: Aptos Move framework formalization (Lean 4).

- **`AptosFormal.Std.*`** — specs for **`move-stdlib`** (`third_party/move/move-stdlib/`): BCS, SHA3-256,
  vector operations, Keccak sponge.
- **`AptosFormal.AptosStd.*`** — specs for **`aptos-stdlib`** (`aptos-move/framework/aptos-stdlib/`):
  SHA3-512, Ristretto255 scalar/wire scaffolding.
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
    `AptosFormal.AptosStd.Hash.Sha3_512,
    `AptosFormal.Std.Bcs.Primitives,
    `AptosFormal.Std.MoveStdlibGoldens,
    `AptosFormal.AptosStd.Crypto.Ristretto255,
    `AptosFormal.Std.Vector.Operations,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.Formal,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.VerifyMath,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.Refinement,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.SchnorrCompleteness,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.Operational,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.TranscriptAlignment,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.GroupAxioms,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.EndToEnd,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.CryptoSecurity,
    `AptosFormal.Experimental.ConfidentialAsset.Registration.FiatShamirSymbolic,
    `AptosFormal.Move.Value,
    `AptosFormal.Move.Instr,
    `AptosFormal.Move.State,
    `AptosFormal.Move.Step,
    `AptosFormal.Move.Native,
    `AptosFormal.Move.Programs,
    `AptosFormal.Move.Programs.RegistrationDifftestOracle,
    `AptosFormal.Move.Programs.Confidential,
    `AptosFormal.Refinement.Core,
    `AptosFormal.Refinement.Vector,
    `AptosFormal.Refinement.Confidential,
    `AptosFormal.Tests.Defs,
    `AptosFormal.Tests.Vector,
    `AptosFormal.Tests.GlobalSmoke,
    `AptosFormal.Tests.Confidential,
    `AptosFormal.DiffTest.JsonParser,
    `AptosFormal.DiffTest.RunnerFuncMappingAux,
    `AptosFormal.DiffTest.Runner
  ]

lean_exe «difftest» where
  root := `AptosFormal.DiffTest.Runner
