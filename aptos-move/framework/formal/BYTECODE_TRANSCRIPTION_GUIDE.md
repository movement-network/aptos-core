# Bytecode transcription guide — Phase 4 prerequisites

**Scope:** how to go from a Move source `public fun verify_<op>_proof(...)` to the Lean
`verify<Op>ProofCode : Array MoveInstr` constant that the rebuilt Phase 4 proofs consume.

Registration's transcription already exists at
[`lean/MovementFormal/MoveModel/Programs/Registration.lean`](lean/MovementFormal/MoveModel/Programs/Registration.lean)
— treat it as the canonical reference when transcribing the other four verifiers.

---

## Step 1: compile the Move package

```bash
cd aptos-move/framework/aptos-experimental
movement move compile \
  --skip-fetch-latest-git-deps \
  --named-addresses aptos_experimental=0x7
```

Output: `build/AptosExperimental/bytecode_modules/confidential_proof.mv`.

## Step 2: disassemble

```bash
movement move disassemble \
  --package-path aptos-move/framework/aptos-experimental \
  --named-addresses aptos_experimental=0x7 \
  --name confidential_proof \
  --bytecode-path build/AptosExperimental/bytecode_modules/confidential_proof.mv
```

The output prints per-function bytecode listings. Scroll to the target function, e.g.
`public fun verify_withdrawal_proof`. Each line is formatted roughly as:

```
  <pc>: <opcode> [<operands>]       // <comment if available>
```

## Step 3: identify the function's module-env slot

Each `Call` opcode references a function-handle index **local to the compiled module's
function-table**. That index maps 1:1 to the Lean `ModuleEnv.functions` array slot.

For the confidential_proof module, the slot assignment you build out will mirror
`Registration.lean`'s `registrationModuleEnv`:

```lean
def <op>ModuleEnv (o : <Op>NativeOracle) : ModuleEnv :=
  { constants := <op>ConstPool
    functions := #[
      { numParams := 1, numReturns := 1, body := .native o.newCompressedPointFromBytes },  -- 0
      optionIsSomeRefDesc,                                                                  -- 1
      optionExtractRefDesc,                                                                 -- 2
      …
    ] }
```

Look for the `movement move disassemble` lines that start with `function_handles:` or
`FunctionHandle:` — that's your assignment table. Each handle entry has a name and its
function-handle index.

## Step 4: transcribe instructions

For each disassembled PC, emit one `MoveInstr` constructor call in the Lean array. Mapping:

| Disassembly | Lean `MoveInstr` |
|---|---|
| `MoveLoc(N)` | `.moveLoc N` |
| `CopyLoc(N)` | `.copyLoc N` |
| `StLoc(N)` | `.stLoc N` |
| `ImmBorrowLoc(N)` | `.immBorrowLoc N` |
| `MutBorrowLoc(N)` | `.mutBorrowLoc N` |
| `Call(K)` | `.call K` |
| `BrFalse(offset)` | `.brFalse offset` |
| `BrTrue(offset)` | `.brTrue offset` |
| `Branch(offset)` | `.branch offset` |
| `LdU64(v)` | `.ldU64 v` |
| `LdConst(idx)` | `.ldConst idx` |
| `Ret` | `.ret` |
| `Abort` | `.abort_` |
| `Pop` | `.pop` |
| `VecPack(T, n)` | `.vecPack T n` |
| `VecImmBorrow(T)` | `.vecImmBorrow T` |
| `VecMutBorrow(T)` | `.vecMutBorrow T` |
| `VecLen(T)` / `VecLenRef(T)` | `.vecLen T` / `.vecLenRef T` |

When in doubt, `Step.lean` is the authoritative enumeration.

## Step 5: pin the constant pool

`LdConst(idx)` references a slot in the module's constant-pool table. Extract each constant
value (byte literal) and build it as a Lean `ConstPoolEntry` in the module-specific
const-pool definition:

```lean
def <op>ConstPool : Array ConstPoolEntry := #[
  -- 0: <description>
  { tag := .vectorU8, value := .vector .u8 [.u8 0xab, .u8 0xcd, …] },
  …
]
```

The DST (domain-separation tag) for Fiat-Shamir will be one of the pool entries — match it to
the `fiatShamir<Op>DstValue` constant that `FunctionalSim.lean` uses.

## Step 6: set the function index

```lean
def verify<Op>ProofIdx : Nat := <N>  -- the index of the function in <op>ModuleEnv.functions
```

For Registration this is 17 (the 18th entry, last slot); other verifiers may be placed at
different indices in their respective modules.

## Step 7: build + sanity

```bash
cd aptos-move/framework/formal/lean
lake build MovementFormal.MoveModel.Programs.<Op>
```

Should build in under a second once transcription is correct.

## Pitfalls

- **Reference calling conventions differ from value-level**: `movement v7.4+` passes many
  arguments as `&T` / `&mut T`. When transcribing a `Call(K)` where K is a function like
  `ristretto255::point_mul`, check whether the disassembly shows the op preceded by
  `ImmBorrowLoc` / `MutBorrowLoc` (reference pattern) or a direct stack value (value
  pattern). The Lean module-env slot must match: use `wrapOracleImmRef1/2` wrappers for
  reference-calling-convention oracles.
- **Jump offsets are absolute PCs, not relative**: `BrFalse(79)` means "go to PC 79," not "skip
  79 instructions." Double-check against the disassembly's PC column.
- **LdConst indices shift after recompile**: if the const-pool structure changes upstream, `.ldConst N`
  needs to re-map; prefer to keep const-pool entries in a stable order.
- **SHA2 vs SHA3**: current CA uses SHA2-512 for Fiat-Shamir (`newScalarFromSha2_512`), NOT
  SHA3. An older version of the Move source used `new_scalar_from_tagged_hash` with SHA3-512 —
  make sure you're transcribing the current source.

## Current status

| Verifier | Bytecode transcription | Notes |
|---|---|---|
| `verify_registration_proof` | ✅ `Programs/Registration.lean` | 84 instructions, 19 locals, fn index 17 |
| `verify_withdrawal_proof` | 🟡 placeholder (empty `#[]` array) | `Programs/Withdrawal.lean` |
| `verify_transfer_proof` | 🟡 placeholder | `Programs/Transfer.lean` |
| `verify_normalization_proof` | 🟡 placeholder | `Programs/Normalization.lean` |
| `verify_rotation_proof` | 🟡 placeholder | `Programs/Rotation.lean` |
