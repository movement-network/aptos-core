import Lake
open Lake DSL

/-!
Lake package **`MovementFormal`**: Aptos Move framework formalization (Lean 4).

- **`MovementFormal.Std.*`** — specs for **`move-stdlib`** (`third_party/move/move-stdlib/`): BCS, SHA3-256,
  vector operations, Keccak sponge, **UTF-8 predicate** (`String.fromUTF8?`), **`type_name`** accessors.
- **`MovementFormal.MoveModel.*`** — Move **bytecode** semantics (`Value`, `Instr`, `Step`, `Programs`, natives).
- **`MovementFormal.MoveModel.BcsCatalog`** — closed `std::bcs` native table for VM↔Lean difftest (indices 0–17).
- **`MovementFormal.AptosStd.*`** — specs for **`aptos-stdlib`** (`aptos-move/framework/aptos-stdlib/`):
  SHA3-512, Ristretto255 scalar/wire scaffolding.
- **`MovementFormal.Experimental.ConfidentialAsset.Registration.*`** — registration proof verifier spec
  (`confidential_proof.move` `verify_registration_proof` in this repo).

Open this directory as the Lean project root (`lake build`). Primary Move anchor:  
`aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`.
-/

package «MovementFormal» where

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @ "v4.24.0"

@[default_target]
lean_lib «MovementFormal» where
  roots := #[
    `MovementFormal.Std.Hash.Keccak,
    `MovementFormal.Std.Hash.Sha3_256,
    `MovementFormal.AptosStd.Hash.Sha3_512,
    `MovementFormal.AptosStd.Hash.Sha2_512,
    `MovementFormal.Std.Bcs.Primitives,
    `MovementFormal.Std.MoveStdlibGoldens,
    `MovementFormal.AptosStd.Crypto.Ristretto255,
    `MovementFormal.Std.Vector.Operations,
    `MovementFormal.Std.Option,
    `MovementFormal.Std.Signer,
    `MovementFormal.Std.Error,
    `MovementFormal.Std.FixedPoint32,
    `MovementFormal.Std.BitVector,
    `MovementFormal.Std.String,
    `MovementFormal.Std.TypeName,
    `MovementFormal.Refinement.Std.Bcs,
    `MovementFormal.SmokeTests.String,
    `MovementFormal.SmokeTests.TypeName,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.Formal,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.VerifyMath,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.Refinement,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.SchnorrCompleteness,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.Operational,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.TranscriptAlignment,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.GroupAxioms,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.EndToEnd,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.CryptoSecurity,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.FiatShamirSymbolic,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeSmoke,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeDifftestEval,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeDifftestBridge,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.RegisterEntryStub,
    `MovementFormal.MoveModel.BcsCatalog,
    `MovementFormal.MoveModel.Value,
    `MovementFormal.MoveModel.Instr,
    `MovementFormal.MoveModel.State,
    `MovementFormal.MoveModel.Step,
    `MovementFormal.MoveModel.Native,
    `MovementFormal.MoveModel.Programs,
    `MovementFormal.MoveModel.Native.Registration,
    `MovementFormal.MoveModel.Programs.Registration,
    `MovementFormal.MoveModel.Programs.RegistrationDifftestOracle,
    `MovementFormal.MoveModel.Programs.Confidential,
    `MovementFormal.Refinement.Std.Core,
    `MovementFormal.Refinement.Std.StdPrimitives,
    `MovementFormal.Refinement.Std.Vector,
    `MovementFormal.Refinement.AptosExperimental.Confidential,
    `MovementFormal.SmokeTests.Defs,
    `MovementFormal.SmokeTests.Vector,
    `MovementFormal.SmokeTests.GlobalSmoke,
    `MovementFormal.SmokeTests.Confidential,
    `MovementFormal.DiffTest.JsonParser,
    `MovementFormal.DiffTest.RunnerFuncMappingAux,
    `MovementFormal.DiffTest.Runner
  ]

lean_exe «difftest» where
  root := `MovementFormal.DiffTest.Runner
