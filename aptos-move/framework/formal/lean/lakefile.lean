import Lake
open Lake DSL

/-!
Lake package **`MovementFormal`**: Movement Move framework formalization (Lean 4).

**Source:** This file only lists Lake roots; provenance for formalized behavior is in each `MovementFormal` module’s own **Source** line. High-level Move anchor directories: `aptos-move/framework/move-stdlib/`, `third_party/move/move-stdlib/`, `aptos-move/framework/aptos-stdlib/`, `aptos-move/framework/aptos-experimental/` (see `README.md` in this directory).

- **`MovementFormal.Std.*`** — specs for **`move-stdlib`** (`third_party/move/move-stdlib/`): BCS, SHA3-256,
  vector operations, Keccak sponge, **UTF-8 predicate** (`String.fromUTF8?`), **`type_name`** accessors.
- **`MovementFormal.MoveModel.*`** — Move **bytecode** semantics (`Value`, `Instr`, `Step`, `Programs`, natives).
- **`MovementFormal.MoveModel.BcsCatalog`** — closed `std::bcs` native table for VM↔Lean difftest (indices 0–26).
- **`MovementFormal.MoveModel.HashCatalog`** — closed `std::hash` native table (`sha2_256`, `sha3_256`; indices 0–1).
- **`MovementFormal.MoveModel.SignerCatalog`** — closed `std::signer` table (`borrow_address`, `address_of`; indices 0–1).
- **`MovementFormal.MoveModel.FixedPoint32Catalog`** — closed `std::fixed_point32` difftest oracle table (indices 0–11; `fp32Oracle*` wrappers in `Native/StdPrimitives`).
- **`MovementFormal.MoveModel.OptionCatalog`** — closed `std::option` (`Option<u64>`) difftest oracle table (indices 0–16; `optionOracleU64*` in `Native/StdPrimitives`).
- **`MovementFormal.MoveModel.BitVectorCatalog`** — closed `std::bit_vector` difftest oracle table (indices 0–4; `bitVector*` in `Native/StdPrimitives`).
- **`MovementFormal.MoveModel.AclCatalog`** — closed `std::acl` difftest oracle table (indices 0–4; `aclOracle*` in `Native/StdPrimitives`).
- **`MovementFormal.MoveModel.StringCatalog`** — closed `std::string` UTF-8 native table (indices 0–3; `stringOracle*` in `Native/StdPrimitives`).
- **`MovementFormal.MoveModel.CmpCatalog`** — closed `std::cmp` on fixed scalars incl. `u256` (indices 0–47; `cmpOracle*` in `Native/StdPrimitives`).
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
    `MovementFormal.Std.Hash.Sha2_256,
    `MovementFormal.Std.Hash.Sha3_256,
    `MovementFormal.AptosStd.Hash.Sha3_512,
    `MovementFormal.AptosStd.Hash.Sha2_512,
    `MovementFormal.Std.Bcs.Primitives,
    `MovementFormal.Std.ByteArrayAppend,
    `MovementFormal.Std.MoveStdlibGoldens,
    `MovementFormal.AptosStd.Crypto.Ristretto255,
    `MovementFormal.AptosStd.Crypto.Curve25519Field,
    `MovementFormal.AptosStd.Crypto.EdwardsCurve25519,
    `MovementFormal.AptosStd.Crypto.EdwardsOracle,
    `MovementFormal.AptosStd.Crypto.RistrettoEncoding,
    `MovementFormal.AptosStd.Crypto.Bulletproofs,
    `MovementFormal.Experimental.ConfidentialAsset.SigmaVerifiers,
    `MovementFormal.Experimental.ConfidentialAsset.SigmaVerifiersGoldens,
    `MovementFormal.Std.Vector.Operations,
    `MovementFormal.Std.Option,
    `MovementFormal.Std.Signer,
    `MovementFormal.Std.Error,
    `MovementFormal.Std.ErrorCanonicalMath,
    `MovementFormal.Std.FixedPoint32,
    `MovementFormal.Std.BitVector,
    `MovementFormal.Std.Acl,
    `MovementFormal.Std.String,
    `MovementFormal.Std.Cmp,
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
    `MovementFormal.MoveModel.ExecResultDropMs,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.EvalFuelMonotonicity,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeDifftestEval,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeDifftestBridge,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.RegisterEntryStub,
    `MovementFormal.MoveModel.BcsCatalog,
    `MovementFormal.MoveModel.ErrorCatalog,
    `MovementFormal.MoveModel.HashCatalog,
    `MovementFormal.MoveModel.SignerCatalog,
    `MovementFormal.MoveModel.FixedPoint32Catalog,
    `MovementFormal.MoveModel.OptionCatalog,
    `MovementFormal.MoveModel.BitVectorCatalog,
    `MovementFormal.MoveModel.AclCatalog,
    `MovementFormal.MoveModel.StringCatalog,
    `MovementFormal.MoveModel.CmpCatalog,
    `MovementFormal.MoveModel.Value,
    `MovementFormal.MoveModel.Instr,
    `MovementFormal.MoveModel.State,
    `MovementFormal.MoveModel.Step,
    `MovementFormal.MoveModel.OpaqueFrames,
    `MovementFormal.MoveModel.FrameInvariants,
    `MovementFormal.MoveModel.StackManagement,
    `MovementFormal.MoveModel.StepLemmas.Basic,
    `MovementFormal.MoveModel.StepLemmas.Locals,
    `MovementFormal.MoveModel.StepLemmas.Refs,
    `MovementFormal.MoveModel.StepLemmas.Casts,
    `MovementFormal.MoveModel.StepLemmas.Structs,
    `MovementFormal.MoveModel.StepLemmas.Calls,
    `MovementFormal.MoveModel.StepLemmas.Globals,
    `MovementFormal.MoveModel.StepLemmas.Run,
    `MovementFormal.MoveModel.StepLemmas.Arrays,
    `MovementFormal.MoveModel.StepLemmas.Bundled,
    `MovementFormal.MoveModel.StepLemmas.OraclePatterns,
    `MovementFormal.MoveModel.StepLemmas.PCChainHelpers,
    `MovementFormal.MoveModel.StepLemmas.ProvenChains,
    `MovementFormal.MoveModel.StepLemmas.MoveLocChains,
    `MovementFormal.MoveModel.StepLemmas.CopyLocChains,
    `MovementFormal.MoveModel.StepLemmas.BorrowFieldChains,
    `MovementFormal.MoveModel.StepLemmas.NativeCallPatterns,
    `MovementFormal.MoveModel.StepLemmas.PCChaining,
    `MovementFormal.MoveModel.StepLemmas.CompositionGuide,
    `MovementFormal.MoveModel.StepLemmas.Example,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.PC4_20_concrete_helper,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.PC20_43_message_assembly,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.PC43_70_sigma_verification,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.SingletonBranchIntegration,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.ValidationLemmas,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.OracleSemantics,
    `MovementFormal.Experimental.ConfidentialAsset.Registration.Phase6Composition,
    `MovementFormal.MoveModel.Programs.Withdrawal,
    `MovementFormal.MoveModel.Programs.Transfer,
    `MovementFormal.MoveModel.Programs.Normalization,
    `MovementFormal.MoveModel.Programs.Rotation,
    `MovementFormal.Experimental.ConfidentialAsset.Withdrawal.FunctionalSim,
    `MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv,
    `MovementFormal.Experimental.ConfidentialAsset.Withdrawal.ConcreteHelpers,
    `MovementFormal.Experimental.ConfidentialAsset.Withdrawal.Phase6Composition,
    `MovementFormal.Experimental.ConfidentialAsset.Transfer.FunctionalSim,
    `MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv,
    `MovementFormal.Experimental.ConfidentialAsset.Transfer.ConcreteHelpers,
    `MovementFormal.Experimental.ConfidentialAsset.Transfer.Phase6Composition,
    `MovementFormal.Experimental.ConfidentialAsset.Normalization.FunctionalSim,
    `MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv,
    `MovementFormal.Experimental.ConfidentialAsset.Normalization.ConcreteHelpers,
    `MovementFormal.Experimental.ConfidentialAsset.Normalization.Phase6Composition,
    `MovementFormal.Experimental.ConfidentialAsset.Rotation.FunctionalSim,
    `MovementFormal.Experimental.ConfidentialAsset.Rotation.EvalEquiv,
    `MovementFormal.Experimental.ConfidentialAsset.Rotation.ConcreteHelpers,
    `MovementFormal.Experimental.ConfidentialAsset.Rotation.Phase6Composition,
    `MovementFormal.Experimental.ConfidentialAsset.Helpers.ArgumentMarshaling,
    `MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleComposition,
    `MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleCaseSplitting,
    `MovementFormal.Experimental.ConfidentialAsset.Helpers.FunctionalSimBridge,
    `MovementFormal.MoveModel.Native,
    `MovementFormal.MoveModel.Programs,
    `MovementFormal.MoveModel.Native.Registration,
    `MovementFormal.MoveModel.Programs.Registration,
    `MovementFormal.MoveModel.Programs.RegistrationDifftestOracle,
    `MovementFormal.MoveModel.Programs.Confidential,
    `MovementFormal.Refinement.Std.Core,
    `MovementFormal.Refinement.Std.StdPrimitives,
    `MovementFormal.Refinement.Std.Vector,
    `MovementFormal.Refinement.Std.Error,
    `MovementFormal.Refinement.Std.Hash,
    `MovementFormal.Refinement.Std.Signer,
    `MovementFormal.Refinement.Std.FixedPoint32Catalog,
    `MovementFormal.Refinement.Std.OptionCatalog,
    `MovementFormal.Refinement.Std.BitVectorCatalog,
    `MovementFormal.Refinement.Std.AclCatalog,
    `MovementFormal.Refinement.Std.StringCatalog,
    `MovementFormal.Refinement.Std.CmpCatalog,
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
