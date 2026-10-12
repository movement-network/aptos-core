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

Open this directory as the Lean project root (`lake build`).
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
    `MovementFormal.MoveModel.ExecResultDropMs,
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
    `MovementFormal.MoveModel.ByteArrayLemmas,
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
    `MovementFormal.MoveModel.Native,
    `MovementFormal.MoveModel.Programs,
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
    `MovementFormal.SmokeTests.Defs,
    `MovementFormal.SmokeTests.Vector,
    `MovementFormal.SmokeTests.GlobalSmoke,
    `MovementFormal.DiffTest.JsonParser,
    `MovementFormal.DiffTest.RunnerFuncMappingAux,
    `MovementFormal.DiffTest.Runner,
  ]


lean_exe «difftest» where
  root := `MovementFormal.DiffTest.Runner
