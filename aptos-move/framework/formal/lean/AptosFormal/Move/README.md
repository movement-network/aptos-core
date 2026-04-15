# AptosFormal.Move — Move bytecode semantics in Lean

Formal model of Move bytecode execution, designed to compose with the existing
spec-level definitions in `AptosFormal.Std.*` and `AptosFormal.Experimental.*`.

**Build and run:** from `aptos-move/framework/formal/lean`, `lake build` (see
[`../../README.md`](../../README.md)). **Differential tests** (real Move VM vs Lean
evaluator): [`../../../difftest/README.md`](../../../difftest/README.md), or
`./aptos-move/framework/formal/difftest.sh` from the repo root. **Stub / bytecode /
globals policy** for the Lean column: [`../../../difftest/STUB_POLICY.md`](../../../difftest/STUB_POLICY.md).

## Directory relationships

```
AptosFormal/
├── Std/                  specs: what stdlib functions should compute
│   ├── Bcs/                  BCS serialization (u8, u64, u128, bool, vector)
│   ├── Hash/                 SHA3-256, SHA3-512, SHA2-512, Keccak-f[1600]
│   ├── Crypto/               Ristretto255 scalar field, compressed points
│   ├── MoveStdlibGoldens    byte-level golden checks
│   ├── Error.lean            std::error — canonical + 13 category wrappers
│   ├── Option.lean           std::option — swap_or_fill, is_some, extract, etc.
│   ├── Signer.lean           std::signer — borrow_address / address_of
│   ├── FixedPoint32.lean     std::fixed_point32 — create_from_rational, floor/ceil/round, min/max
│   └── BitVector.lean        std::bit_vector — new, set, unset, is_index_set, shift_left
│
├── Experimental/         specs: what experimental functions should compute
│   └── ConfidentialAsset/Registration/
│       ├── Formal            FS transcript, abstract Schnorr equation
│       ├── VerifyMath         CryptoOracle, verifyRegistrationProofProp
│       ├── Operational        execVerifyRegistrationProof (Option Unit model, L1)
│       ├── FunctionalSim     verifyRegistrationBytecodeResult (L1.5 functional sim)
│       ├── EvalEquiv          eval_eq_func_100 (L2≡L1.5), ExecResult.dropMs, fuel lemmas
│       ├── Refinement         L2≡L1.5≡L1↔L0 refinement chain (eval → prop)
│       ├── BytecodeSmoke      eval smoke: valid/invalid proof on golden inputs (ref args)
│       ├── BytecodeDifftestEval  native_decide: eval vs func on 4 oracle traces
│       ├── BytecodeDifftestBridge  L2→L0 concrete chain (dk=42/k=9999 trace)
│       ├── RegisterEntryStub  L4 register entry-point stub (verify+store)
│       ├── SchnorrCompleteness
│       ├── CryptoSecurity     special soundness, HVZK
│       ├── FiatShamirSymbolic symbolic Fiat-Shamir model
│       ├── GroupAxioms        RistrettoGroupAxioms
│       ├── EndToEnd           top-level verification ↔ Schnorr equation
│       └── TranscriptAlignment
│
├── Move/                 execution model: how Move bytecode runs  ← THIS DIRECTORY
│   ├── Value.lean            MoveValue, MoveType, RefId, GlobalResourceKey
│   ├── Instr.lean            MoveInstr bytecode instruction set
│   ├── State.lean            Frame, ContainerStore, MachineState, ExecResult, ModuleEnv
│   ├── Step.lean             small-step evaluator (step/run/eval)
│   ├── Native.lean           native function bindings to Std.* specs
│   ├── Programs.lean         module env definitions (imports Core + Vector)
│   ├── Native/
│   │   ├── Registration.lean oracle-parameterized natives (nativeRef + derefImm)
│   │   └── StdPrimitives.lean native models for signer, fixed_point32, bit_vector, option
│   └── Programs/
│       ├── Core.lean         basic programs (add, max, bcs, refs)
│       ├── GlobalSmoke.lean  minimal `globalExists` / `globalMoveTo` / `mutBorrowGlobal` smoke
│       ├── Registration.lean transcribed bytecode for verify_registration_proof (83 instrs)
│       ├── RegistrationDifftestOracle.lean  table oracle for difftest roundtrip
│       ├── StdPrimitives.lean bytecode for std::error (canonical + 13 wrappers) + bit_vector::length
│       └── Vector.lean       vector programs (hand-written + real compiler)
│
├── Refinement/           ∀-quantified proofs connecting execution to specs
│   ├── Core.lean             rfl proofs: addU64, bcsU64, readViaRef, etc.
│   ├── StdPrimitives.lean    rfl refinement: error functions + bit_vector::length
│   └── Vector.lean           vector::contains + vector::index_of refinement proofs
│
└── Tests/                concrete smoke tests (native_decide on fixed inputs)
    ├── Defs.lean             shared helpers (evalProg, returnValues, u64Vec)
    ├── StdPrimitives.lean    smoke tests for error, signer, fixed_point32, bit_vector, option
    └── Vector.lean           vector tests (hand-written + real compiler)
```

## How the directories compose

**Std.\* and Experimental.\*** define *what* Move functions should compute — pure
Lean functions mapping inputs to outputs. These are the **specifications**.

**Move.\*** defines *how* Move programs execute — a bytecode interpreter in Lean
that takes a sequence of instructions and a state, and produces a new state.
This is the **execution model**.

**Refinement.\*** proves that specific Move bytecode programs, when evaluated under
the execution model, produce results matching the specifications. These are the
**correctness proofs**.

Any file in `Move/` can `import AptosFormal.Std.Bcs.Primitives` and use `u64Le`
directly — they share the same Lake project and import system.

## Implementation plan

### Progress summary

| Phase | Area | Status |
|-------|------|--------|
| 1 | Values and types (`MoveValue`, `MoveType`) | **Done** |
| 2 | Instruction set (`MoveInstr`) | **Done** |
| 3 | Execution state and evaluator (`step`/`run`/`eval`) | **Done** (L4 gap: full `StructTag`, FA, `Object<Metadata>`) |
| 4 | Bytecode transcription (stdlib functions) | **Done** (stdlib vector, error, bit_vector) |
| 5 | Refinement proofs — Core (`rfl`) | **Done** |
| 6a | References in model | **Done** |
| 6b | Vector operations (`contains`, `index_of`, `reverse`) | **Done** (`contains`, `index_of`); `reverse` proof sketch only (`sorry`) |
| 6c | Stdlib primitives (error, signer, fixed_point32, bit_vector, option) | **Done** (specs + native models + refinement for error/bit_vector; 3 `sorry` on auxiliary lemmas in fixed_point32/bit_vector) |
| 6d–e | Remaining stdlib (math, string, BCS wrappers) | **Not started** |
| 7a | Real compiled bytecode | **Done** |
| 7b | Differential testing vs real VM | **Done** (227 cases, 0 failures) |
| 7c | Randomized / edge-case testing | **Not started** |
| 8 | Inductive refinement proofs | **Partial** — `contains` + `index_of` + `error` (14 fns) + `bit_vector::length` done; `reverse` open |
| 9 | Composite stdlib / framework functions | **Not started** |

### Phase 1: Values and types (done)

Define `MoveValue` — the runtime value type matching Move's bytecode-level values:

```lean
inductive MoveValue
  | u8 (n : UInt8)
  | u16 (n : UInt16)
  | u32 (n : UInt32)
  | u64 (n : UInt64)
  | u128 (n : Nat)
  | u256 (n : Nat)
  | bool (b : Bool)
  | address (bytes : ByteArray)
  | vector (elemType : MoveType) (elems : List MoveValue)
  | struct (fields : List MoveValue)
```

Reference: `third_party/move/move-binary-format/src/file_format.rs` for the
canonical value representation and `third_party/move/move-vm/types/src/values/`
for the runtime value types.

### Phase 2: Instruction set (done)

Define `MoveInstr` — a subset of Move bytecode instructions, starting with
pure operations. **Abstract** global ops (`globalExists` / `globalMoveTo` /
`globalMoveToSigned` / `mutBorrowGlobal`) model publishing keyed by
`GlobalResourceKey`; optional `StructTag` bytes live on the key (see `Value.lean`).
Full Aptos BCS / generic `StructTag`, **`Object<Metadata>`** layout, and VM-accurate
`BorrowGlobal` from metadata remain future work (see L4 gap below).

- Integer arithmetic: `Add`, `Sub`, `Mul`, `Div`, `Mod`
- Comparisons: `Lt`, `Gt`, `Le`, `Ge`, `Eq`, `Neq`
- Logic: `And`, `Or`, `Not`
- Stack: `LdConst`, `Pop`, `CopyLoc`, `MoveLoc`, `StLoc`
- Control: `Branch`, `BrTrue`, `BrFalse`, `Ret`
- Calls: `Call` (with a native function dispatch table)
- Casting: `CastU8`, `CastU64`, etc.
- Vector: `VecPack`, `VecLen`, `VecPushBack`, `VecPopBack`, `VecSwap`
- Abort: `Abort`

Reference: `Bytecode` enum in `third_party/move/move-binary-format/src/file_format.rs`.

### Phase 3: Execution state and evaluator (done — L4 gap remains)

Define the execution state and a small-step evaluator:

```lean
structure Frame where
  code : Array MoveInstr
  pc : Nat
  locals : Array (Option MoveValue)

structure ContainerStore where
  store : Array MoveValue

structure MachineState where
  containers : ContainerStore
  globals : List (GlobalResourceKey × RefId)
  faBalances : List ((UInt64 × UInt64) × UInt64) := []

def step (env : ModuleEnv) (frame : Frame) (callStack : List Frame)
    (stack : List MoveValue) (ms : MachineState) : ExecResult := ...
```

`ModuleEnv` bundles the constant pool and function table. Native functions
are modeled as Lean functions (`List MoveValue → Option (List MoveValue)`),
allowing crypto operations (SHA3, Ristretto) to be plugged in from `Std.*`
definitions without modeling Rust internals. `ContainerStore` is the
pure-functional model of the VM's `Container` sharing mechanism
(`Rc<RefCell<Vec<ValueImpl>>>`).

**`MachineState`:** pairs that heap with `globals`, a list mapping
`GlobalResourceKey` (publish `address` bytes + `structTagHash` + optional
`instanceNonce` + optional `StructTag` path bytes) to a `RefId` into the same store.
Additionally **`faBalances`** is a difftest-only stub map `(metadataId, ownerKey) ↦ u64`
(see `faReadBalance` / `faWriteBalance` in `Instr.lean` and Phase L5 in
[`../../../difftest/STUB_POLICY.md`](../../../difftest/STUB_POLICY.md)).
`MachineState.ofContainers` / coercion lifts a locals-only heap (`globals := []`,
`faBalances := []`).
Abstract instructions `globalExists`, `globalMoveTo`, `globalMoveToSigned`,
`mutBorrowGlobal`, and `ldSigner` live in `Instr.lean` (not the real
`file_format.rs` global opcodes yet). Smoke bytecode: `Programs/GlobalSmoke.lean`;
kernel-checked equalities: `Tests/GlobalSmoke.lean`.

**L4 gap (remaining):** we still do **not** model full Aptos **`StructTag`** BCS
(including generic type arguments), real **`Object<Metadata>`** /
**`primary_fungible_store`** layout, or VM-accurate **`BorrowGlobal`** keyed off
compiled metadata. `globalMoveToSigned` checks signer address bytes against
`GlobalResourceKey.address` only (no module publish rules). The `faBalances` stub
is for **narrow** oracle alignment only; extending keys + `step` + difftest
inventory rows remains the path for fuller FA. See
[`../../../difftest/STUB_POLICY.md`](../../../difftest/STUB_POLICY.md).

Reference: `third_party/move/move-vm/runtime/src/interpreter.rs` for the
execution loop.

### Phase 4: Bytecode representations of specific functions (done)

Translate specific Move functions to their bytecode representation as Lean
values of type `Array MoveInstr`. Start with simple stdlib functions:

- `bcs::to_bytes<u64>`
- `vector::reverse<u8>`
- `vector::length<u8>`

These can be obtained by compiling the Move source and inspecting the bytecode
output (`movement move disassemble`).

### Phase 5: Refinement proofs — Core (done)

Prove that bytecode programs, evaluated under `step`, produce results matching
the specs in `Std.*`. These Core proofs are `rfl` — Lean's kernel verifies the full
evaluation chain by definitional reduction, for all inputs (not just goldens).
(`vector::contains` is handled separately in `Refinement/Vector.lean`; see Phase 6b / 8.)

Completed theorems in `Refinement/Core.lean`:
- `addU64_correct` — `a + b` for all `UInt64`
- `isZeroU64_correct` — `n == 0` for all `UInt64`
- `bcsU64_correct` — bytecode wrapper matches `Std.Bcs.u64Le` spec for all `UInt64`
- `readViaRef_correct` — immutable borrow + read round-trips for all `UInt64`
- `incViaRef_correct` — mutable borrow → read → add → write → read for all `UInt64`
- `vecPushAndLen_correct` — reference-based vector push + length for all vectors

### Phase 6: Expand move-stdlib coverage (partially done)

Add references to the instruction set and execution model, then prove
correctness of fundamental stdlib functions:

**6a. Add references to the model (done):**
- `MoveInstr`: `readRef`, `writeRef`, `freezeRef`, `immBorrowLoc`, `mutBorrowLoc`,
  `immBorrowField`, `mutBorrowField`, plus reference-level vector ops
  (`vecLenRef`, `vecPushBackRef`, `vecPopBackRef`, `vecSwapRef`, etc.)
- `MoveValue`: `mutRef`/`immRef` constructors carrying a `RefId` index
- `ContainerStore`: pure-functional model of the VM's `Container` sharing
  (`Rc<RefCell<Vec<ValueImpl>>>`), threaded through `step`/`run`/`eval`
- Proved three reference programs correct via `rfl`: `readViaRef_correct`,
  `incViaRef_correct`, `vecPushAndLen_correct`

**6b. Stdlib vector operations:**
- `vector::reverse` — loop with `swap` via `VecSwapRef` (bytecode + smoke tests;
  universal refinement proof sketch in `Refinement/Vector.lean`, still uses `sorry`).
- `vector::contains` — loop with `VecImmBorrow` + `ReadRef` + `Eq`. Specs in
  `Std/Vector/Operations.lean`. Smoke tests: `Tests/Vector.lean` (`native_decide`).
  **Refinement (done):** `Refinement/Vector.lean` proves `vectorContains_returnValues` for
  the hand-written `vectorContainsCode` in `Programs/Vector.lean`, against
  `Std.Vector.contains`, with `xs.length < UInt64.size` so indices match `u64`
  comparisons (see theorem statement). Differential tests cover `vector::contains`
  in [`../../../difftest/README.md`](../../../difftest/README.md).
- `vector::index_of` — loop returning `(bool, u64)`. **Refinement (done):**
  `Refinement/Vector.lean` proves `vectorIndexOf_returnValues_found` and
  `vectorIndexOf_returnValues_notFound` for `vectorIndexOfCode` (bytecode index 19
  in `stdModuleEnv`), with `xs.length < UInt64.size`. Proof is kernel-checked
  (no `sorry`).

**6c. Stdlib primitive modules (done):**
- `std::error` — spec (`Std/Error.lean`), bytecode (`Programs/StdPrimitives.lean`),
  `rfl`-proved refinement (`Refinement/StdPrimitives.lean`) for `canonical` + all
  13 category wrappers. Smoke tests in `Tests/StdPrimitives.lean`.
- `std::signer` — spec (`Std/Signer.lean`), native model (`Native/StdPrimitives.lean`).
- `std::fixed_point32` — spec (`Std/FixedPoint32.lean`), native model. Two `sorry`
  remain on `UInt64` order lemmas.
- `std::bit_vector` — spec (`Std/BitVector.lean`), native model + bytecode for
  `length`. One `sorry` on `shift_left` inductive step.
- `std::option` — spec (`Std/Option.lean`), native model.

**6d–6e.** Remaining stdlib coverage (math, string, BCS wrappers) — same approach.

### Phase 7: Model fidelity testing (mostly done — 7c open)

The Lean evaluator (`Move.Step`) is a hand-written translation of the Rust
VM (`interpreter.rs`, `values_impl.rs`). Before proving universal theorems
about it, we need confidence that the translation is correct.

**7a. Use real compiled bytecode (done):**

Compiled `move-stdlib` with `movement move compile` and disassembled
`vector.mv` to extract the real bytecode for `contains`, `index_of`,
`reverse`, and `reverse_slice`. Transcribed these instruction-for-instruction
into `Programs.lean` as `realContainsCode`, `realIndexOfCode`,
`realReverseCode`, and `realReverseSliceCode`.

This immediately exposed two model fidelity bugs:

1. **`Eq`/`Neq` on references:** The real VM dereferences both sides before
   comparing (`ContainerRef::equals`, `IndexedRef::equals` in `values_impl.rs`).
   Our model was comparing `RefId` values, so two references to equal values
   at different container slots would compare as unequal. Fixed in `Step.lean`.

2. **Double-advance in `Ret`:** `Call` saves the caller frame at `pc + 1`,
   but `Ret` applied `advance` again, skipping the instruction after the call.
   This meant any program using inter-function calls (which all real compiler
   output does — `reverse` calls `reverse_slice`) would crash. Fixed by
   removing the redundant `advance` from `Ret`'s return-to-caller case.

Also documented: real bytecode uses *only* reference-level vector operations
(`VecLen`, `VecImmBorrow`, `VecSwap`, etc.) — never the value-level variants.
The compiler's `MoveLoc` + `Pop` cleanup pattern before `Ret` is faithfully
modeled. All 16 smoke tests pass (5 `contains`, 3 `index_of`, 5 `reverse`,
plus the existing hand-written tests).

**7b. Differential testing against the real VM:**
- Run shared test vectors through both the Rust Move VM and the Lean evaluator
- Compare outputs (return values, abort codes, error conditions)
- This validates that `step` faithfully models `execute_code_impl`
- Implemented: Rust `move-lean-difftest` + Lean `difftest` exe. **Run:** `./aptos-move/framework/formal/difftest.sh` from repo root, or see [`../../../difftest/README.md`](../../../difftest/README.md).

**7c. Expand test coverage:**
- Randomized inputs (property-based testing) for broader coverage
- Edge cases: empty vectors, max-length vectors, overflow, abort paths

Differential testing (7b) plus smoke tests give empirical confidence that the
model tracks the real VM; refinement proofs on top then connect that model to
stdlib-style specs in Lean.

### Phase 8: Inductive refinement proofs (partially done)

Universally quantified correctness for stdlib-style bytecode, using induction
and loop invariants where needed:

- **`vector::contains` (done):**
  `Refinement/Vector.lean` — `vectorContains_returnValues` / `vectorContains_correct`
  (hypothesis `xs.length < UInt64.size`, adequate fuel). Proof is kernel-checked
  (no `sorry`). The proof targets the curated bytecode wired as stdlib function
  index 18 in `stdModuleEnv`, not a compiler-equality claim for every toolchain
  output.
- **`vector::index_of` (done):**
  `Refinement/Vector.lean` — `vectorIndexOf_returnValues_found` /
  `vectorIndexOf_returnValues_notFound` (hypothesis `xs.length < UInt64.size`,
  adequate fuel). Proof is kernel-checked (no `sorry`). Uses `suffices` to
  generalize over `indexOf.go` offsets, and `contains_uint64_succ` / `contains_idx_u64_lt_len`
  lemmas shared with the `contains` proof.
- **`vector::reverse`:** universal refinement vs `List.reverse` — proof sketch
  present (`sorry`), full proof open.
- **`std::error` (done):** all 14 functions proved correct via `rfl` in
  `Refinement/StdPrimitives.lean`.
- **`std::bit_vector::length` (done):** proved correct via `rfl` in
  `Refinement/StdPrimitives.lean`.

These `∀`-theorems are checked by Lean's kernel for all inputs satisfying the
stated hypotheses, unlike difftest goldens alone.

### Phase 9: Composite stdlib and framework functions (not started)

Once the stdlib foundation is solid, prove correctness of higher-level
functions that compose multiple primitives:

- `string` operations (UTF-8 encoding, `string::append`, `string::length`)
- `simple_map` / `smart_table` lookups and insertions
- `coin::transfer`, `coin::merge`, `coin::extract`
- `account::create_account`, `account::exists_at`

These exercise the full model — references, structs, **abstract** global
publishing (`MachineState` / `GlobalResourceKey`; not yet FA-accurate), native
calls, and control flow — on the functions developers interact with most.

## Bytecode reference

The canonical Move bytecode definition lives at:

```
third_party/move/move-binary-format/src/file_format.rs  → Bytecode enum
third_party/move/move-vm/runtime/src/interpreter.rs      → execution loop
third_party/move/move-vm/types/src/values/               → runtime values
```

To inspect the bytecode of a compiled Move function:

```bash
movement move compile --package-dir <path>
movement move disassemble --bytecode-path <path-to-mv-file>
```
