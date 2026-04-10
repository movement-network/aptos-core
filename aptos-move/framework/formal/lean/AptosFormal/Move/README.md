# AptosFormal.Move — Move bytecode semantics in Lean

Formal model of Move bytecode execution, designed to compose with the existing
spec-level definitions in `AptosFormal.Std.*` and `AptosFormal.Experimental.*`.

**Build and run:** from `aptos-move/framework/formal/lean`, `lake build` (see
[`../../README.md`](../../README.md)). **Differential tests** (real Move VM vs Lean
evaluator): [`../../../difftest/README.md`](../../../difftest/README.md), or
`./aptos-move/framework/formal/difftest.sh` from the repo root.

## Directory relationships

```
AptosFormal/
├── Std/                  specs: what stdlib functions should compute
│   ├── Bcs/                  BCS serialization (u8, u64, u128, bool, vector)
│   ├── Hash/                 SHA3-256, SHA3-512, Keccak-f[1600]
│   ├── Crypto/               Ristretto255 scalar field, compressed points
│   └── MoveStdlibGoldens    byte-level golden checks
│
├── Experimental/         specs: what experimental functions should compute
│   └── ConfidentialAsset/Registration/
│       ├── Formal            FS transcript, abstract Schnorr equation
│       ├── VerifyMath         CryptoOracle, verifyRegistrationProofProp
│       ├── Operational        execVerifyRegistrationProof (Option Unit model)
│       ├── SchnorrCompleteness
│       ├── CryptoSecurity     special soundness, HVZK
│       ├── FiatShamirSymbolic symbolic Fiat-Shamir model
│       ├── GroupAxioms        RistrettoGroupAxioms
│       ├── EndToEnd           top-level verification ↔ Schnorr equation
│       └── TranscriptAlignment
│
├── Move/                 execution model: how Move bytecode runs  ← THIS DIRECTORY
│   ├── Value.lean            MoveValue, MoveType, RefId
│   ├── Instr.lean            MoveInstr bytecode instruction set
│   ├── State.lean            Frame, ContainerStore, ExecResult, ModuleEnv
│   ├── Step.lean             small-step evaluator (step/run/eval)
│   ├── Native.lean           native function bindings to Std.* specs
│   ├── Programs.lean         module env definitions (imports Core + Vector)
│   └── Programs/
│       ├── Core.lean         basic programs (add, max, bcs, refs)
│       └── Vector.lean       vector programs (hand-written + real compiler)
│
├── Refinement/           ∀-quantified proofs connecting execution to specs
│   ├── Core.lean             rfl proofs: addU64, bcsU64, readViaRef, etc.
│   └── Vector.lean           `vector::contains` refinement vs `Std.Vector.contains`
│
└── Tests/                concrete smoke tests (native_decide on fixed inputs)
    ├── Defs.lean             shared helpers (evalProg, returnValues, u64Vec)
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

### Phase 1: Values and types

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

### Phase 2: Instruction set

Define `MoveInstr` — a subset of Move bytecode instructions, starting with
pure operations (no resources, no global storage):

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

### Phase 3: Execution state and evaluator

Define the execution state and a small-step evaluator:

```lean
structure Frame where
  code : Array MoveInstr
  pc : Nat
  locals : Array (Option MoveValue)

structure ContainerStore where
  store : Array MoveValue

def step (env : ModuleEnv) (frame : Frame) (callStack : List Frame)
    (stack : List MoveValue) (containers : ContainerStore) : ExecResult := ...
```

`ModuleEnv` bundles the constant pool and function table. Native functions
are modeled as Lean functions (`List MoveValue → Option (List MoveValue)`),
allowing crypto operations (SHA3, Ristretto) to be plugged in from `Std.*`
definitions without modeling Rust internals. `ContainerStore` is the
pure-functional model of the VM's `Container` sharing mechanism
(`Rc<RefCell<Vec<ValueImpl>>>`).

Reference: `third_party/move/move-vm/runtime/src/interpreter.rs` for the
execution loop.

### Phase 4: Bytecode representations of specific functions

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

### Phase 6: Expand move-stdlib coverage

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
  universal refinement proof still open).
- `vector::contains` — loop with `VecImmBorrow` + `ReadRef` + `Eq`. Specs in
  `Std/Vector/Operations.lean`. Smoke tests: `Tests/Vector.lean` (`native_decide`).
  **Refinement:** `Refinement/Vector.lean` proves `vectorContains_returnValues` for
  the hand-written `vectorContainsCode` in `Programs/Vector.lean`, against
  `Std.Vector.contains`, with `xs.length < UInt64.size` so indices match `u64`
  comparisons (see theorem statement). Differential tests cover `vector::contains`
  in [`../../../difftest/README.md`](../../../difftest/README.md).
- `vector::index_of` — loop returning `(bool, u64)` (bytecode + smoke tests;
  universal refinement proof still open).

**6c–6e.** Remaining stdlib coverage (option, math, BCS) — same approach.

### Phase 7: Model fidelity testing

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

- **`vector::contains` (done for the formalized hand-written bytecode):**
  `Refinement/Vector.lean` — `vectorContains_returnValues` / `vectorContains_correct`
  (hypothesis `xs.length < UInt64.size`, adequate fuel). Proof is kernel-checked
  (no `sorry`). The proof targets the curated bytecode wired as stdlib function
  index 18 in `stdModuleEnv`, not a compiler-equality claim for every toolchain
  output.
- **`vector::reverse`:** universal refinement vs `List.reverse` — open.
- **`vector::index_of`:** universal refinement vs the spec in
  `Std/Vector/Operations.lean` — open.

These `∀`-theorems are checked by Lean's kernel for all inputs satisfying the
stated hypotheses, unlike difftest goldens alone.

### Phase 9: Composite stdlib and framework functions

Once the stdlib foundation is solid, prove correctness of higher-level
functions that compose multiple primitives:

- `string` operations (UTF-8 encoding, `string::append`, `string::length`)
- `simple_map` / `smart_table` lookups and insertions
- `coin::transfer`, `coin::merge`, `coin::extract`
- `account::create_account`, `account::exists_at`

These exercise the full model — references, structs, global storage, native
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
