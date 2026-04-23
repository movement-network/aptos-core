# Bytecode Transcription Workflow Guide

**Purpose:** Systematic workflow for transcribing Move bytecode to Lean 4 symbolic execution model.

**Audience:** Formal verification engineers working on Lean proofs for Confidential Assets operations.

**Scope:** Complete end-to-end workflow from `.mv` bytecode to verified Lean `operationState` definitions.

**Status:** Production-ready workflow (Phase 1 singleton-some branch, Phase 6 PC-chaining)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Transcription Workflow](#3-transcription-workflow)
4. [Bytecode Analysis](#4-bytecode-analysis)
5. [Lean State Construction](#5-lean-state-construction)
6. [Verification Patterns](#6-verification-patterns)
7. [Common Pitfalls](#7-common-pitfalls)
8. [Quality Checklist](#8-quality-checklist)
9. [Examples](#9-examples)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Overview

### 1.1 What is Bytecode Transcription?

**Bytecode transcription** is the process of converting compiled Move bytecode (`.mv` files) into Lean 4 symbolic state definitions that can be formally verified.

**Why transcribe bytecode instead of Move source?**
- Verification target is the **deployed bytecode**, not source code
- Source-level invariants may not survive compilation
- Bytecode is the ground truth for VM execution
- Catches compiler bugs and optimization issues

**What we transcribe:**
```
Move Source (.move)
    ↓ [Movement compiler]
Move Bytecode (.mv)
    ↓ [Manual transcription] ← This guide
Lean Symbolic State (*.lean)
    ↓ [Formal proof]
Verified Equivalence to Oracle
```

### 1.2 Transcription Accuracy Requirements

**Critical:** Bytecode transcription must be **100% faithful** to the compiled `.mv` file. Any deviation invalidates the proof.

**Accuracy guarantees:**
- Instruction sequence matches bytecode exactly
- PC values match bytecode offsets
- Local variable indices match bytecode
- Type signatures match bytecode
- Constants match bytecode

**Verification:**
- Difftest validates transcription accuracy
- MSL specs provide independent check
- Axiom-free proof rules out semantic drift

### 1.3 Architecture Integration

**Bytecode transcription fits into the larger architecture:**

```
┌─────────────────────────────────────────────┐
│ Move Source (confidential_asset.move)       │
└─────────────┬───────────────────────────────┘
              ↓ movement move build
┌─────────────────────────────────────────────┐
│ Move Bytecode (.mv)                         │ ← Verification target
└─────────────┬───────────────────────────────┘
              ↓ Manual transcription (this guide)
┌─────────────────────────────────────────────┐
│ Lean State Definitions (Registration.lean)  │
│ - operationCode : Code                      │
│ - operationState : Nat → ... → Frame       │
└─────────────┬───────────────────────────────┘
              ↓ Formal proof
┌─────────────────────────────────────────────┐
│ Verified Theorems (EvalEquiv.lean)          │
│ - operation_eval_equiv_functional_sim       │
└─────────────────────────────────────────────┘
```

---

## 2. Prerequisites

### 2.1 Required Tools

**Install these before starting:**

```bash
# Move compiler (for generating bytecode)
movement move build

# Bytecode disassembler
movement move disassemble --bytecode-path <path>

# Hex viewer (for inspecting .mv files)
hexdump -C <file.mv>

# Lean 4 (for testing transcriptions)
lake build MovementFormal
```

### 2.2 Required Knowledge

**Must understand:**
- Move bytecode format (instruction encoding, local variables, stack operations)
- Lean 4 symbolic state model (`Frame`, `StackFrame`, `eval`)
- CA operation semantics (what each operation does cryptographically)
- Difftest framework (for validating transcriptions)

**Recommended reading:**
- `LEAN_ARCHITECTURE_DEEP_DIVE.md` (symbolic state model)
- `PHASE_1_SINGLETON_SOME_BRANCH_COMPLETION_GUIDE.md` (Registration example)
- `PHASE_6_PC_CHAINING_COMPLETE_GUIDE.md` (composition patterns)
- Move VM specification (bytecode format)

### 2.3 Workspace Setup

**Organize your workspace:**

```bash
# Working directory structure
aptos-move/framework/formal/
├── lean/
│   └── MovementFormal/
│       ├── MoveModel/           # Symbolic state model
│       │   ├── Native/          # Native function models
│       │   └── StepLemmas/      # Step lemmas for each instruction
│       └── Experimental/
│           └── ConfidentialAsset/
│               ├── Registration/ # Operation-specific proofs
│               │   ├── Registration.lean      # State definitions ← Transcription output
│               │   └── EvalEquivRebuild.lean  # Proofs using transcription
│               ├── Transfer/
│               ├── Withdrawal/
│               ├── Rotation/
│               └── Normalization/
├── bytecode/                    # Compiled .mv files (create this)
│   ├── registration.mv
│   ├── transfer.mv
│   └── ...
└── scripts/
    └── disassemble_all.sh       # Batch disassembly script
```

---

## 3. Transcription Workflow

### 3.1 End-to-End Workflow

**Complete workflow (3-6 hours per operation):**

```
Step 1: Compile Move Source (10 min)
    ↓
Step 2: Disassemble Bytecode (10 min)
    ↓
Step 3: Analyze Instruction Sequence (30-60 min)
    ↓
Step 4: Transcribe to Lean Code Definition (30-60 min)
    ↓
Step 5: Create Symbolic State Constructor (30-60 min)
    ↓
Step 6: Write Step Lemmas (60-120 min)
    ↓
Step 7: Validate with Difftest (15 min)
    ↓
Step 8: Write Composition Proof (60-120 min)
```

**Total time budget:** 3-6 hours per operation (depending on complexity)

### 3.2 Step 1: Compile Move Source

**Goal:** Generate the `.mv` bytecode file that will be transcribed.

**Process:**

```bash
# Navigate to the Move package
cd aptos-move/framework/aptos-experimental

# Clean build (ensures fresh bytecode)
movement move clean
movement move build

# Locate the compiled bytecode
find build -name "*.mv" | grep confidential

# Example output:
# build/AptosExperimental/bytecode_modules/confidential_asset.mv
```

**Copy bytecode to workspace:**

```bash
# Create bytecode directory
mkdir -p ../formal/bytecode

# Copy relevant .mv files
cp build/AptosExperimental/bytecode_modules/confidential_asset.mv \
   ../formal/bytecode/registration.mv

# Note: You may need to extract specific functions from the module
# The .mv file contains the entire module; we focus on one operation at a time
```

**Verification:**

```bash
# Check file size (should be a few KB for CA operations)
ls -lh ../formal/bytecode/registration.mv

# Verify it's a valid bytecode file (starts with magic bytes)
hexdump -C ../formal/bytecode/registration.mv | head -n 5

# Should see Move bytecode header
```

### 3.3 Step 2: Disassemble Bytecode

**Goal:** Convert binary bytecode to human-readable disassembly.

**Process:**

```bash
# Disassemble the bytecode
movement move disassemble \
  --bytecode-path ../formal/bytecode/registration.mv \
  > ../formal/bytecode/registration.dis

# View the disassembly
less ../formal/bytecode/registration.dis
```

**Disassembly format:**

```
// Function: verify_registration_proof_internal
public verify_registration_proof_internal(Arg0: &signer, Arg1: vector<u8>): u64 {
B0:
    0: CopyLoc[0](Arg0: &signer)
    1: Call ristretto255_point_clone(&RistrettoPoint): RistrettoPoint
    2: StLoc[2](local2: RistrettoPoint)
    3: CopyLoc[1](Arg1: vector<u8>)
    4: Call deserialize_registration_proof(vector<u8>): RegistrationProof
    5: StLoc[3](local3: RegistrationProof)
    ...
}
```

**Key information to extract:**
- **PC values** (0, 1, 2, 3, ...) — these become Lean state PC values
- **Instruction names** (CopyLoc, Call, StLoc, ...) — these map to Lean step lemmas
- **Operand indices** ([0], [1], [2], ...) — local variable slots
- **Type signatures** (RistrettoPoint, vector<u8>, ...) — used in Lean types

### 3.4 Step 3: Analyze Instruction Sequence

**Goal:** Understand the control flow and data dependencies.

**Analysis checklist:**

**Control flow:**
- [ ] Identify basic blocks (sequences without branches)
- [ ] Identify branch instructions (BrTrue, BrFalse, Branch)
- [ ] Identify return points (Ret, Abort)
- [ ] Map PC values to Lean state indices

**Data flow:**
- [ ] Track local variable usage (which locals are read/written when)
- [ ] Track stack operations (push/pop patterns)
- [ ] Identify native calls (these need oracle modeling)
- [ ] Identify constants (these need exact transcription)

**Example analysis (Registration):**

```
PC 0-5: Setup phase
  - Copy proof reference from signer
  - Deserialize registration proof from bytes
  - Extract proof components

PC 6-15: Verification phase
  - Call verify_registration_proof_internal native
  - Branch on verification result
  - Handle success/failure cases

PC 16-20: Cleanup phase
  - Store result
  - Return or abort
```

**Create control flow graph (on paper or tool):**

```
    [PC 0-5: Setup]
          ↓
    [PC 6: Native call]
          ↓
    [PC 7: Branch]
       ↙     ↘
  [Success]  [Failure]
    PC 8-12   PC 13-15
       ↓         ↓
    [Ret]     [Abort]
```

### 3.5 Step 4: Transcribe to Lean Code Definition

**Goal:** Create the `operationCode : Code` definition in Lean.

**Template:**

```lean
-- File: MovementFormal/Experimental/ConfidentialAsset/Registration/Registration.lean

import MovementFormal.MoveModel.Instruction

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-- Bytecode for verify_registration_proof_internal.
    Transcribed from confidential_asset.mv (built YYYY-MM-DD).
    
    Function signature:
    public verify_registration_proof_internal(
      proof_ref: &signer,
      proof_bytes: vector<u8>
    ): u64
-/
def verifyRegistrationProofCode : Code := [
  -- PC 0: CopyLoc[0] (proof_ref)
  .CopyLoc 0,
  
  -- PC 1: Call ristretto255_point_clone
  .Call «confidential_asset::ristretto255_point_clone»,
  
  -- PC 2: StLoc[2] (store cloned point)
  .StLoc 2,
  
  -- PC 3: CopyLoc[1] (proof_bytes)
  .CopyLoc 1,
  
  -- PC 4: Call deserialize_registration_proof
  .Call «confidential_asset::deserialize_registration_proof»,
  
  -- PC 5: StLoc[3] (store deserialized proof)
  .StLoc 3,
  
  -- ... (continue for all instructions)
  
  -- PC N: Ret (return result)
  .Ret
]

end MovementFormal.Experimental.ConfidentialAsset.Registration
```

**Transcription rules:**

**1. PC values must match bytecode exactly:**
```lean
-- If disassembly shows:
--   7: BrTrue 15
-- Then Lean must have instruction at index 7 that branches to PC 15
```

**2. Local variable indices must match:**
```lean
-- If disassembly shows:
--   StLoc[3]
-- Then Lean must have:
.StLoc 3
```

**3. Instruction names must map correctly:**

| Bytecode Instruction | Lean Instruction | Notes |
|----------------------|------------------|-------|
| `CopyLoc[N]` | `.CopyLoc N` | Copy local variable to stack |
| `MoveLoc[N]` | `.MoveLoc N` | Move local variable to stack |
| `StLoc[N]` | `.StLoc N` | Store top of stack to local |
| `Call F` | `.Call «F»` | Call function (use guillemets for names with special chars) |
| `BrTrue PC` | `.BrTrue PC` | Branch if true to PC |
| `BrFalse PC` | `.BrFalse PC` | Branch if false to PC |
| `Branch PC` | `.Branch PC` | Unconditional branch to PC |
| `Ret` | `.Ret` | Return from function |
| `Abort` | `.Abort` | Abort execution |
| `LdU64 N` | `.LdU64 N` | Load u64 constant |
| `LdTrue` | `.LdTrue` | Load boolean true |
| `LdFalse` | `.LdFalse` | Load boolean false |

**4. Constants must be exact:**
```lean
-- If bytecode has:
--   LdU64 65537
-- Then Lean must have:
.LdU64 65537  -- Not 65536 or 65538!
```

**5. Function names need guillemets:**
```lean
-- For names with :: or special characters:
.Call «confidential_asset::verify_proof»

-- Simple names can omit:
.Call simple_function  -- OK if no special chars
```

### 3.6 Step 5: Create Symbolic State Constructor

**Goal:** Create the `operationState` function that constructs symbolic frames.

**Template:**

```lean
/-- Symbolic state for verify_registration_proof_internal at PC `pc`.
    
    @param pc Program counter (instruction index)
    @param proofRef Address of proof reference
    @param locals Local variable state at this PC
-/
@[irreducible]
def registrationState (pc : Nat) (proofRef : Address) (locals : Locals) : Frame :=
  { code := verifyRegistrationProofCode,
    pc := pc,
    locals := locals,
    operandStack := [],
    frameId := ⟨0, by omega⟩,
    typeArgs := [],
    -- Initial locals configuration
    initialLocals := [
      .reference proofRef,        -- Arg0: &signer (proof reference)
      .vectorU8 #[],              -- Arg1: vector<u8> (proof bytes)
      .some (.ristrettoPoint default),  -- local2: RistrettoPoint
      .some (.registrationProof default) -- local3: RegistrationProof
      -- ... (all locals used by the function)
    ]
  }

-- Performance-critical simp lemmas (O(1) unfolding)
@[simp]
theorem registrationState_pc (pc : Nat) (ref : Address) (locals : Locals) :
    (registrationState pc ref locals).pc = pc := by
  unfold registrationState; rfl

@[simp]
theorem registrationState_code (pc : Nat) (ref : Address) (locals : Locals) :
    (registrationState pc ref locals).code = verifyRegistrationProofCode := by
  unfold registrationState; rfl

@[simp]
theorem registrationState_locals (pc : Nat) (ref : Address) (locals : Locals) :
    (registrationState pc ref locals).locals = locals := by
  unfold registrationState; rfl
```

**Key patterns:**

**1. Use `@[irreducible]` for performance:**
```lean
@[irreducible]
def operationState := ...
-- Prevents Lean from unfolding the entire structure during type checking
-- 600× speedup compared to naive definitions
```

**2. Provide `@[simp]` lemmas for field access:**
```lean
@[simp]
theorem operationState_pc : (operationState pc ...).pc = pc := by
  unfold operationState; rfl
-- Allows `simp` to extract PC without unfolding entire structure
```

**3. Model all local variables:**
```lean
initialLocals := [
  .reference arg0,              -- Arguments come first
  .vectorU8 arg1,
  .some (.ristrettoPoint default),  -- Uninitialized locals use .some default
  .none                         -- Or .none if explicitly not initialized
]
```

### 3.7 Step 6: Write Step Lemmas

**Goal:** Prove each instruction step matches the symbolic semantics.

**Step lemma pattern:**

```lean
/-- Step lemma for PC 0 → PC 1: CopyLoc[0] -/
theorem registrationStep_0_to_1
    (env : Environment)
    (proofRef : Address)
    (locals : Locals)
    (h_locals : locals.length = 10)  -- Adjust to actual local count
    : step env (registrationState 0 proofRef locals) =
        .inProgress (registrationState 1 proofRef locals') := by
  unfold step
  rw [registrationState_code, registrationState_pc]
  simp [verifyRegistrationProofCode]
  -- Use step lemma from StepLemmas library
  apply step_copyLoc
  · exact h_locals
  · simp [locals']
  done

/-- Step lemma for PC 1 → PC 2: Call native function -/
theorem registrationStep_1_to_2
    (env : Environment)
    (proofRef : Address)
    (locals : Locals)
    (h_call : env.nativeFunctions «ristretto255_point_clone» = some ...)
    : step env (registrationState 1 proofRef locals) =
        .inProgress (registrationState 2 proofRef locals') := by
  unfold step
  rw [registrationState_code, registrationState_pc]
  simp [verifyRegistrationProofCode]
  apply step_call_native
  · exact h_call
  · simp [locals']
  done
```

**Step lemma library usage:**

| Instruction | Step Lemma | Key hypotheses |
|-------------|------------|----------------|
| `CopyLoc N` | `step_copyLoc` | Locals length, index in bounds |
| `MoveLoc N` | `step_moveLoc` | Locals length, index in bounds |
| `StLoc N` | `step_stLoc` | Stack non-empty, index in bounds |
| `Call F` | `step_call_native` | Native function exists in env |
| `BrTrue PC` | `step_brTrue` | Stack top is boolean true |
| `BrFalse PC` | `step_brFalse` | Stack top is boolean false |
| `Ret` | `step_ret` | Stack has expected return value |
| `Abort` | `step_abort` | Stack has error code |

**See:** `MovementFormal/MoveModel/StepLemmas/` for complete library.

### 3.8 Step 7: Validate with Difftest

**Goal:** Ensure transcription matches actual VM execution.

**Validation process:**

```bash
# Run difftest for the operation
cd difftest
cargo test test_register_happy_path --release -- --nocapture

# Check that abort codes match
cargo test test_register_proof_invalid --release -- --nocapture

# Expected output:
# test test_register_happy_path ... ok
# test test_register_proof_invalid ... ok (abort code: 65537)

# If difftest fails, transcription is incorrect!
```

**Common difftest failures:**

| Failure | Cause | Fix |
|---------|-------|-----|
| "PC mismatch at step 5" | Wrong instruction sequence | Re-check disassembly |
| "Abort code mismatch" | Wrong constant in LdU64 | Fix constant value |
| "Local index out of bounds" | Wrong local variable count | Adjust initialLocals length |
| "Stack underflow" | Missing instruction | Add missing instruction |

### 3.9 Step 8: Write Composition Proof

**Goal:** Prove the complete operation using step lemmas.

**Composition pattern (Phase 6 PC-chaining):**

```lean
theorem registration_eval_equiv_functional_sim
    (proofRef : Address)
    (addr : Address)
    (h_oracle : oracleResult = ...)
    : eval env (registrationState 0 proofRef addr) cs ms =
        match oracleResult with
        | .success => .returned [] ms
        | .verifyFailed => .aborted 65537 ms
        | .error => .error ms
  := by
  unfold eval
  rw [eval_registration_eq_run]
  cases oracleResult with
  | success =>
    rw [registration_functional_sim_success_shape env proofRef addr rfl]
    -- PC chaining: 0 → 1 → 2 → ... → N
    rw [registrationStep_0_to_1]
    rw [registrationStep_1_to_2]
    rw [registrationStep_2_to_3]
    -- ... (all steps)
    rw [registrationStep_N_ret]
    rfl
  | verifyFailed =>
    -- Similar chaining for failure case
    sorry  -- Complete in Phase 6
  | error =>
    sorry
```

**See:** `PHASE_6_PC_CHAINING_COMPLETE_GUIDE.md` for complete composition workflow.

---

## 4. Bytecode Analysis

### 4.1 Reading Move Bytecode Disassembly

**Disassembly anatomy:**

```
public verify_registration_proof_internal(Arg0: &signer, Arg1: vector<u8>): u64 {
^^^^^  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^  ^^^^           ^^^^            ^^^
  |              |                        |               |              |
Visibility   Function name            Argument 0      Argument 1    Return type

B0:
^^
Basic block 0

    0: CopyLoc[0](Arg0: &signer)
    ^  ^^^^^^^^  ^^^^
    |     |       |
   PC   Instruction  Operand (local variable index)

    1: Call ristretto255_point_clone(&RistrettoPoint): RistrettoPoint
    ^  ^^^^  ^^^^^^^^^^^^^^^^^^^^^^^ ^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^
    |   |              |                   |                  |
   PC  Instruction  Function name     Argument type      Return type
}
```

**Key elements:**

**PC (Program Counter):**
- Instruction index within the function
- Starts at 0
- Increments by 1 for each instruction
- Branches reference PC values

**Instruction name:**
- Opcode for the instruction
- Examples: CopyLoc, StLoc, Call, BrTrue, Ret, Abort

**Operands:**
- Arguments to the instruction
- Often local variable indices `[N]`
- Or function names for `Call`
- Or PC values for branches

**Type annotations:**
- Show the types of arguments and returns
- Helpful for understanding data flow
- Must match Lean type signatures

### 4.2 Mapping Instructions to Lean

**Direct mappings:**

```
Bytecode          →  Lean
─────────────────────────────────────────
CopyLoc[N]        →  .CopyLoc N
MoveLoc[N]        →  .MoveLoc N
StLoc[N]          →  .StLoc N
LdU64 K           →  .LdU64 K
LdTrue            →  .LdTrue
LdFalse           →  .LdFalse
Call F            →  .Call «F»
BrTrue PC         →  .BrTrue PC
BrFalse PC        →  .BrFalse PC
Branch PC         →  .Branch PC
Ret               →  .Ret
Abort             →  .Abort
```

**Example mapping:**

```
Bytecode disassembly:
    5: CopyLoc[1](Arg1: vector<u8>)
    6: Call deserialize_proof(vector<u8>): Proof
    7: StLoc[3](local3: Proof)

Lean transcription:
def code : Code := [
  ...
  .CopyLoc 1,                                      -- PC 5
  .Call «confidential_asset::deserialize_proof»,   -- PC 6
  .StLoc 3,                                        -- PC 7
  ...
]
```

### 4.3 Handling Native Calls

**Native calls** are functions implemented outside Move (in Rust).

**In bytecode:**
```
10: Call verify_registration_proof_internal(Proof): bool
```

**In Lean:**
```lean
-- Model as oracle (black box)
.Call «confidential_asset::verify_registration_proof_internal»

-- Step lemma uses oracle result
theorem step_10_to_11
    (h_oracle : env.oracle «verify_registration_proof_internal» proof = result)
    : step env (state 10 ...) = ... := by
  apply step_call_native
  exact h_oracle
  done
```

**Oracle modeling strategy:**
- Native crypto functions → modeled as opaque oracles
- Oracle results are axiomatized (21 permanent crypto axioms)
- Difftest validates oracle behavior matches actual implementation

**See:** `audit/AXIOM_INVENTORY.md` for complete oracle list.

### 4.4 Handling Branches

**Branch instructions** change control flow.

**Types of branches:**

**1. BrTrue (conditional branch if true):**
```
Bytecode:
    7: BrTrue 15

Lean:
.BrTrue 15

Step lemma:
theorem step_7_brTrue
    (h_stack_top : stack.top = .bool true)
    : step env (state 7 ...) = .inProgress (state 15 ...) := by
  apply step_brTrue
  exact h_stack_top
```

**2. BrFalse (conditional branch if false):**
```
Bytecode:
    8: BrFalse 20

Lean:
.BrFalse 20

Step lemma:
theorem step_8_brFalse
    (h_stack_top : stack.top = .bool false)
    : step env (state 8 ...) = .inProgress (state 20 ...) := by
  apply step_brFalse
  exact h_stack_top
```

**3. Branch (unconditional):**
```
Bytecode:
    12: Branch 25

Lean:
.Branch 25

Step lemma:
theorem step_12_branch
    : step env (state 12 ...) = .inProgress (state 25 ...) := by
  apply step_branch
  rfl
```

**Control flow graph:**

```
PC 0-6: Linear sequence
   ↓
PC 7: BrTrue 15
   ↓ false    ↓ true
PC 8          PC 15
   ↓            ↓
PC 9          PC 16
  ...         ...
```

**Proof strategy:**
- Prove one path at a time (success path, failure path)
- Use `cases` on oracle result to split proof
- Chain step lemmas for each path

### 4.5 Tracking Local Variables

**Local variables** store intermediate values.

**In bytecode:**
```
Arguments:
  Arg0: &signer           (local 0)
  Arg1: vector<u8>        (local 1)

Locals:
  local2: RistrettoPoint
  local3: Proof
  local4: bool
  ...
```

**In Lean:**
```lean
initialLocals := [
  .reference proofRef,                    -- local 0 (Arg0)
  .vectorU8 proofBytes,                   -- local 1 (Arg1)
  .some (.ristrettoPoint default),        -- local 2
  .some (.registrationProof default),     -- local 3
  .some (.bool false),                    -- local 4
  ...
]
```

**Tracking changes:**

```
PC 0: CopyLoc[0]
  → Stack: [ref]
  → Locals: unchanged

PC 1: Call clone
  → Stack: [cloned_ref]
  → Locals: unchanged

PC 2: StLoc[2]
  → Stack: []
  → Locals: [ref, bytes, cloned_ref, proof_default, ...]
                         ^^^^^^^^^^^
                         local 2 updated
```

**Locals state updates:**

```lean
-- After StLoc[2], locals updated:
locals' = locals.update 2 (.ristrettoPoint clonedRef)

-- Step lemma:
theorem step_2_stLoc
    (h_stack : stack = [.ristrettoPoint clonedRef])
    : step env (state 2 locals stack) =
        .inProgress (state 3 locals' []) := by
  unfold locals'
  apply step_stLoc
  · exact h_stack
  · rfl
```

---

## 5. Lean State Construction

### 5.1 Frame Structure

**The `Frame` type** represents a single function call frame.

**Definition:**

```lean
structure Frame where
  code : Code                    -- Bytecode instruction sequence
  pc : Nat                       -- Program counter (current instruction)
  locals : Locals                -- Local variable storage
  operandStack : OperandStack    -- Evaluation stack
  frameId : FrameId              -- Unique frame identifier
  typeArgs : List TypeTag        -- Type arguments (for generics)
  initialLocals : Locals         -- Initial locals (for frame reconstruction)
```

**Example frame for Registration:**

```lean
def registrationFrame (pc : Nat) (proofRef : Address) (locals : Locals) : Frame :=
  { code := verifyRegistrationProofCode,         -- Transcribed bytecode
    pc := pc,                                    -- Current PC
    locals := locals,                            -- Current locals state
    operandStack := [],                          -- Initially empty stack
    frameId := ⟨0, by omega⟩,                    -- Main frame ID
    typeArgs := [],                              -- No type parameters
    initialLocals := [                           -- Starting locals
      .reference proofRef,
      .vectorU8 #[],
      .some (.ristrettoPoint default),
      .some (.registrationProof default),
      ...
    ]
  }
```

### 5.2 Code Definition

**The `Code` type** is a list of instructions.

**Pattern:**

```lean
def operationCode : Code := [
  .Instruction1,
  .Instruction2,
  .Instruction3,
  ...
  .Ret
]

-- Must match bytecode exactly!
-- PC 0 = first instruction
-- PC 1 = second instruction
-- etc.
```

**Verification:**

```lean
-- Check code length matches bytecode
#eval operationCode.length  -- Should match disassembly line count

-- Check specific instruction
#eval operationCode[5]  -- Should match disassembly PC 5
```

### 5.3 Locals Initialization

**Locals encoding:**

**Option types:**
```lean
-- Uninitialized local (has not been written yet)
.none

-- Initialized local (has been written or is an argument)
.some value
```

**Value types:**
```lean
-- Primitive types
.some (.u64 42)
.some (.bool true)
.some (.address addr)

-- Complex types
.some (.vectorU8 #[1, 2, 3])
.some (.ristrettoPoint point)
.some (.registrationProof proof)

-- Reference types
.reference addr
```

**Example initialization:**

```lean
initialLocals := [
  .reference proofRef,                    -- Arg0: always initialized
  .vectorU8 proofBytes,                   -- Arg1: always initialized
  .some (.ristrettoPoint default),        -- local2: initialized to default
  .none,                                  -- local3: uninitialized
  .none,                                  -- local4: uninitialized
]

-- As execution proceeds, .none locals become .some values via StLoc
```

### 5.4 Symbolic State Constructors

**Pattern for operation states:**

```lean
@[irreducible]
def operationState (pc : Nat) (arg0 : Type0) (arg1 : Type1) ... (locals : Locals) : Frame :=
  { code := operationCode,
    pc := pc,
    locals := locals,
    operandStack := [],
    frameId := ⟨0, by omega⟩,
    typeArgs := [],
    initialLocals := [
      encode arg0,
      encode arg1,
      ...
    ]
  }

-- Always provide these simp lemmas:
@[simp]
theorem operationState_pc : (operationState pc ...).pc = pc := by
  unfold operationState; rfl

@[simp]
theorem operationState_code : (operationState pc ...).code = operationCode := by
  unfold operationState; rfl

@[simp]
theorem operationState_locals : (operationState pc ... locals).locals = locals := by
  unfold operationState; rfl
```

**Performance note:** Always use `@[irreducible]` + `@[simp]` lemmas. This pattern gives 600× speedup by preventing Lean from unfolding the entire frame structure during type checking.

### 5.5 Stack Operations

**The operand stack** stores intermediate values.

**Initially empty:**
```lean
{ operandStack := [], ... }
```

**After CopyLoc[0]:**
```lean
{ operandStack := [.reference proofRef], ... }
```

**After Call (pushes return value):**
```lean
{ operandStack := [.ristrettoPoint clonedPoint], ... }
```

**After StLoc[2] (pops from stack):**
```lean
{ operandStack := [], ... }  -- Value moved to locals[2]
```

**Tracking stack in proofs:**

```lean
-- Specify stack state in step lemmas
theorem step_N_to_N1
    (h_stack : frame.operandStack = [value1, value2])
    : step env frame = .inProgress frame' := by
  -- Stack hypothesis used in proof
  apply step_instruction
  exact h_stack
```

---

## 6. Verification Patterns

### 6.1 Step-by-Step Verification

**Verification strategy:** Prove one step at a time, then compose.

**Pattern:**

```lean
-- Step 0 → 1
theorem step_0_to_1 : step env (state 0 ...) = .inProgress (state 1 ...) := by
  apply step_copyLoc; simp; done

-- Step 1 → 2
theorem step_1_to_2 : step env (state 1 ...) = .inProgress (state 2 ...) := by
  apply step_call_native; simp; done

-- Step 2 → 3
theorem step_2_to_3 : step env (state 2 ...) = .inProgress (state 3 ...) := by
  apply step_stLoc; simp; done

-- Compose: 0 → 1 → 2 → 3
theorem steps_0_to_3 : run env (state 0 ...) 3 = .inProgress (state 3 ...) := by
  rw [run_succ, step_0_to_1]
  rw [run_succ, step_1_to_2]
  rw [run_succ, step_2_to_3]
  rw [run_zero]
  rfl
```

### 6.2 Handling Oracle Results

**Native functions** are modeled as oracles.

**Pattern:**

```lean
-- Oracle hypothesis in theorem statement
theorem operation_eval_equiv
    (h_oracle : env.oracle «verify_proof» proof = oracleResult)
    : eval env (state 0 ...) = ... := by
  cases oracleResult with
  | success =>
    -- Proof for success case
    rw [step_call_native]
    · exact h_oracle
    · simp [oracle_success_semantics]
  | failure =>
    -- Proof for failure case
    rw [step_call_native]
    · exact h_oracle
    · simp [oracle_failure_semantics]
```

**Oracle axioms:**

```lean
-- Axiom: Oracle result determines branch outcome
axiom oracle_determines_branch
    (h_oracle : env.oracle «verify_proof» proof = .success)
    : verify_proof_result proof = true

-- Use in proofs:
theorem step_branch_true
    (h_oracle : env.oracle «verify_proof» proof = .success)
    : step env (state N ...) = .inProgress (state M ...) := by
  have h_result : verify_proof_result proof = true :=
    oracle_determines_branch h_oracle
  rw [step_brTrue]
  exact h_result
```

**See:** `audit/AXIOM_INVENTORY.md` for all 21 permanent axioms.

### 6.3 Proving Abort Conditions

**Abort codes** must match across all three stacks.

**Pattern:**

```lean
theorem operation_aborts_on_invalid_proof
    (h_oracle : env.oracle «verify_proof» proof = .verifyFailed)
    : eval env (state 0 ...) = .aborted 65537 := by
  unfold eval
  rw [eval_operation_eq_run]
  -- PC chain leading to abort
  rw [step_0_to_1]
  rw [step_1_to_2]
  rw [step_2_call_oracle]
  · -- Oracle returns false
    rw [step_3_brFalse]  -- Branch to abort path
    rw [step_15_ldU64]   -- Load abort code 65537
    rw [step_16_abort]   -- Execute abort
    rfl
  · exact h_oracle
```

**Abort code constants:**

| Operation | Abort Code | Constant Name |
|-----------|------------|---------------|
| Registration | 65537 | `EVERIFY_FAILED` |
| Transfer | 65537 | `EVERIFY_FAILED` |
| Withdrawal | 65537 | `EVERIFY_FAILED` |
| Rotation | 65537 | `EVERIFY_FAILED` |

**Validation:**
- Lean proof shows abort code `65537`
- MSL spec: `aborts_if !verify(...) with 65537`
- Difftest: `assert_eq!(error_code, 65537)`

All three must match!

### 6.4 Composition via PC Chaining

**PC chaining** connects individual step lemmas into a complete proof.

**Pattern (Phase 6):**

```lean
theorem operation_eval_equiv
    (h_oracle : oracleResult = ...)
    : eval env (state 0 ...) =
        match oracleResult with
        | .success => .returned [] ms
        | .verifyFailed => .aborted 65537 ms
        | .error => .error ms
  := by
  unfold eval
  rw [eval_operation_eq_run]
  cases oracleResult with
  | success =>
    -- Success path: PC 0 → 1 → 2 → ... → N → Ret
    rw [step_0_to_1]
    rw [step_1_to_2]
    rw [step_2_to_3]
    -- ... (all steps on success path)
    rw [step_N_ret]
    rfl
  | verifyFailed =>
    -- Failure path: PC 0 → 1 → ... → M → Abort
    rw [step_0_to_1]
    rw [step_1_to_2]
    -- ... (steps leading to abort)
    rw [step_M_abort]
    rfl
  | error =>
    -- Error path (if applicable)
    sorry
```

**Effort estimate:** 9-12 hours for Transfer (longest), 4-6 hours for simpler operations.

**See:** `PHASE_6_PC_CHAINING_COMPLETE_GUIDE.md` for complete workflow.

---

## 7. Common Pitfalls

### 7.1 PC Misalignment

**Problem:** Lean PC values don't match bytecode disassembly.

**Symptoms:**
- Step lemmas fail with "instruction mismatch"
- Difftest fails with "PC mismatch at step N"
- Proofs get stuck at unexpected instructions

**Cause:**
- Missed an instruction during transcription
- Added an extra instruction
- Wrong instruction order

**Fix:**

```bash
# Compare Lean code length to bytecode
lean_count=$(grep -c "^\s*\." Registration.lean)
bytecode_count=$(grep -c "^\s*[0-9]:" registration.dis)

echo "Lean instructions: $lean_count"
echo "Bytecode instructions: $bytecode_count"

# Should match!

# If mismatch, diff side-by-side:
# Lean code              Bytecode disassembly
# .CopyLoc 0    ←→    0: CopyLoc[0]
# .Call «F»     ←→    1: Call F
# .StLoc 2      ←→    2: StLoc[2]
# ...
```

**Prevention:**
- Transcribe in small batches (5-10 instructions at a time)
- Check PC alignment frequently
- Run difftest after each batch

### 7.2 Local Variable Index Errors

**Problem:** Wrong local variable index in instruction operand.

**Symptoms:**
- "Local index out of bounds" in Lean
- Difftest fails with "unexpected value in local N"
- Proof gets stuck on local access

**Cause:**
- Typo in index (e.g., `[3]` instead of `[2]`)
- Wrong local count in `initialLocals`
- Off-by-one error

**Fix:**

```lean
-- Check local count matches bytecode
-- If bytecode shows locals 0-9, need 10 locals
initialLocals := List.range 10 |>.map (fun _ => .none)  -- Temporarily, for debugging

-- Check specific index usage
-- If disassembly shows:
--   5: CopyLoc[3]
-- Then Lean must have:
  .CopyLoc 3  -- Not 2 or 4!
```

**Prevention:**
- Count locals carefully in disassembly
- Use comments to label locals
- Test with difftest frequently

### 7.3 Constant Value Errors

**Problem:** Wrong constant value in `LdU64`, `LdTrue`, `LdFalse`.

**Symptoms:**
- Difftest fails with "abort code mismatch"
- Proof gets stuck on constant comparison
- MSL spec inconsistency

**Cause:**
- Typo in constant (e.g., `65536` instead of `65537`)
- Wrong constant transcription from disassembly
- Confusion between similar constants

**Fix:**

```lean
-- If bytecode shows:
--   15: LdU64 65537
-- Then Lean must have:
  .LdU64 65537  -- Exact match!

-- Common abort codes:
-- 65537 = EVERIFY_FAILED
-- 524289 = EINVALID_PROOF_FORMAT
-- etc.

-- Double-check against MSL:
-- MSL: aborts_if !verify(...) with 65537
-- Lean: .LdU64 65537
-- Difftest: assert_eq!(error_code, 65537)
```

**Prevention:**
- Copy-paste constants from disassembly (don't retype)
- Cross-reference with MSL spec
- Validate with difftest

### 7.4 Instruction Mapping Errors

**Problem:** Wrong Lean instruction for bytecode opcode.

**Symptoms:**
- Step lemma fails with "instruction type mismatch"
- Proof gets stuck on instruction semantics
- Difftest fails with "unexpected operation"

**Cause:**
- Confused similar instructions (e.g., `CopyLoc` vs `MoveLoc`)
- Wrong instruction name transcription
- Missed instruction variant (e.g., `BrTrue` vs `BrFalse`)

**Fix:**

```lean
-- Check instruction mapping:
-- Bytecode: CopyLoc[N]  →  Lean: .CopyLoc N  (copy local to stack, local remains)
-- Bytecode: MoveLoc[N]  →  Lean: .MoveLoc N  (move local to stack, local becomes .none)

-- CopyLoc: local stays, value copied to stack
-- MoveLoc: local cleared, value moved to stack

-- Double-check disassembly:
--   7: BrTrue 15   →  .BrTrue 15   (branch if true)
--   8: BrFalse 20  →  .BrFalse 20  (branch if false)
```

**Prevention:**
- Refer to instruction mapping table (§4.2)
- Use step lemma library for validation
- Test each instruction with difftest

### 7.5 Branch Target Errors

**Problem:** Branch instruction references wrong PC.

**Symptoms:**
- Control flow proof fails
- Difftest execution diverges
- Wrong abort code reached

**Cause:**
- Typo in branch target (e.g., `15` instead of `16`)
- PC misalignment affecting branch calculation
- Confusion between relative and absolute PC

**Fix:**

```lean
-- Bytecode shows:
--   7: BrTrue 15
-- Means: if true, jump to PC 15 (absolute)

-- Lean must have:
  .BrTrue 15  -- Absolute PC, not relative offset!

-- Check control flow graph:
--   PC 7: BrTrue 15
--     ↓ false  ↓ true
--   PC 8      PC 15
--     ↓         ↓
--   ...       ...
```

**Prevention:**
- Draw control flow graph from disassembly
- Verify all branch targets in graph
- Test both true and false paths with difftest

### 7.6 Missing `@[irreducible]` Annotation

**Problem:** Forgot `@[irreducible]` on state definition.

**Symptoms:**
- Lean type checking extremely slow (>10 minutes per file)
- Out of memory during elaboration
- Proofs work but build is unusable

**Cause:**
- Omitted `@[irreducible]` annotation
- Lean unfolds entire frame structure repeatedly
- O(N²) elaboration time

**Fix:**

```lean
-- WRONG (slow):
def operationState ... : Frame :=
  { code := ..., pc := ..., ... }

-- CORRECT (fast):
@[irreducible]
def operationState ... : Frame :=
  { code := ..., pc := ..., ... }

-- Always add simp lemmas:
@[simp]
theorem operationState_pc : (operationState pc ...).pc = pc := by
  unfold operationState; rfl
```

**Prevention:**
- Always use `@[irreducible]` for state definitions
- Always provide `@[simp]` lemmas for field access
- Test build time (should be <180s per file)

### 7.7 Wrong Function Signature

**Problem:** Transcribed function signature doesn't match bytecode.

**Symptoms:**
- Type errors in step lemmas
- Difftest type mismatches
- Proof gets stuck on type coercion

**Cause:**
- Wrong argument types
- Wrong return type
- Missing arguments
- Wrong argument order

**Fix:**

```lean
-- Check disassembly function signature:
-- public verify_registration_proof_internal(
--   Arg0: &signer,
--   Arg1: vector<u8>
-- ): u64

-- Lean state must match:
def registrationState
    (pc : Nat)
    (proofRef : Address)        -- Arg0: &signer
    (proofBytes : ByteVector)   -- Arg1: vector<u8>
    (locals : Locals)
    : Frame :=
  { initialLocals := [
      .reference proofRef,      -- &signer
      .vectorU8 proofBytes,     -- vector<u8>
      ...
    ],
    ...
  }

-- Return type: u64
-- Ret instruction pushes u64 to stack
```

**Prevention:**
- Copy function signature from disassembly
- Verify argument types match bytecode
- Check return type in Ret instruction

---

## 8. Quality Checklist

### 8.1 Transcription Completeness

**Before considering transcription done, verify:**

- [ ] All instructions transcribed (count matches disassembly)
- [ ] All PC values aligned (Lean index N = bytecode PC N)
- [ ] All local variable indices correct
- [ ] All constants exact (no typos)
- [ ] All function names correct (with guillemets if needed)
- [ ] All branch targets correct
- [ ] Function signature matches bytecode
- [ ] Return type matches bytecode

**Automated check:**

```bash
# Count instructions
lean_count=$(grep -c "^\s*\." Registration.lean)
bytecode_count=$(grep -c "^\s*[0-9]:" registration.dis)
if [ "$lean_count" -ne "$bytecode_count" ]; then
  echo "ERROR: Instruction count mismatch!"
  exit 1
fi
```

### 8.2 Step Lemma Coverage

**For each instruction, verify:**

- [ ] Step lemma exists (`step_N_to_M`)
- [ ] Step lemma uses correct step library function
- [ ] Step lemma hypotheses are sufficient
- [ ] Step lemma compiles without errors
- [ ] Step lemma proven (no `sorry`)

**Coverage check:**

```bash
# Count step lemmas
step_count=$(grep -c "^theorem.*step_" EvalEquiv.lean)
if [ "$step_count" -lt "$bytecode_count" ]; then
  echo "WARNING: Missing step lemmas!"
fi
```

### 8.3 Difftest Validation

**Run all difftest scenarios:**

- [ ] Happy path test passes
- [ ] Invalid proof test passes (correct abort code)
- [ ] Edge case tests pass
- [ ] No flaky failures (run 10× to confirm)

**Validation:**

```bash
# Run all tests 10 times
for i in {1..10}; do
  cargo test --release test_register_ || exit 1
done
echo "All tests passed 10× ✓"
```

### 8.4 Performance Validation

**Check build time:**

- [ ] Lean file builds in <180s (per-file budget)
- [ ] No `set_option maxHeartbeats` overrides needed
- [ ] No out-of-memory during elaboration

**Benchmark:**

```bash
time lake build MovementFormal.Experimental.ConfidentialAsset.Registration.Registration
# Should complete in <180s

# If >180s, check for missing @[irreducible]
```

### 8.5 Cross-Stack Consistency

**Verify consistency across all three stacks:**

- [ ] Abort codes match (Lean, MSL, Difftest)
- [ ] Function signatures match (Lean, MSL, Move)
- [ ] Operation semantics match (Lean theorem, MSL spec, Difftest behavior)
- [ ] Oracle results match (Lean axiom, MSL pragma, Difftest mock)

**Consistency check:**

```bash
# Check abort code consistency
lean_abort=$(grep "aborted.*65537" Registration.lean)
msl_abort=$(grep "aborts_if.*65537" confidential_asset.spec.move)
difftest_abort=$(grep "assert.*65537" test_registration.rs)

if [ -z "$lean_abort" ] || [ -z "$msl_abort" ] || [ -z "$difftest_abort" ]; then
  echo "ERROR: Abort code mismatch!"
fi
```

### 8.6 Documentation

**Document the transcription:**

- [ ] File header comment with source bytecode path and build date
- [ ] Function signature comment
- [ ] Comments on complex instruction sequences
- [ ] References to related proofs
- [ ] Known limitations or assumptions

**Template:**

```lean
/-- Bytecode for verify_registration_proof_internal.
    
    Source: aptos-experimental/sources/confidential_asset/confidential_asset.move
    Bytecode: build/AptosExperimental/bytecode_modules/confidential_asset.mv
    Built: 2026-04-15
    
    Function signature:
    public verify_registration_proof_internal(
      proof_ref: &signer,
      proof_bytes: vector<u8>
    ): u64
    
    Returns: 0 on success, 65537 on verification failure
    
    See: EvalEquivRebuild.lean for complete proof
-/
def verifyRegistrationProofCode : Code := [
  ...
]
```

---

## 9. Examples

### 9.1 Complete Example: Registration (Simplified)

**Bytecode disassembly:**

```
public verify_registration_proof_internal(Arg0: &signer, Arg1: vector<u8>): u64 {
B0:
    0: CopyLoc[0](Arg0: &signer)
    1: Call ristretto255_point_clone(&RistrettoPoint): RistrettoPoint
    2: StLoc[2](local2: RistrettoPoint)
    3: CopyLoc[1](Arg1: vector<u8>)
    4: Call deserialize_registration_proof(vector<u8>): RegistrationProof
    5: StLoc[3](local3: RegistrationProof)
    6: CopyLoc[3](local3: RegistrationProof)
    7: Call verify_registration_proof_native(RegistrationProof): bool
    8: BrFalse 12
    9: LdU64 0
   10: Ret
   11: LdU64 65537
   12: Abort
}
```

**Lean transcription:**

```lean
-- File: MovementFormal/Experimental/ConfidentialAsset/Registration/Registration.lean

import MovementFormal.MoveModel.Instruction

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-- Bytecode for verify_registration_proof_internal (simplified).
    Built: 2026-04-15
-/
def verifyRegistrationProofCode : Code := [
  .CopyLoc 0,                                               -- PC 0
  .Call «confidential_asset::ristretto255_point_clone»,     -- PC 1
  .StLoc 2,                                                 -- PC 2
  .CopyLoc 1,                                               -- PC 3
  .Call «confidential_asset::deserialize_registration_proof», -- PC 4
  .StLoc 3,                                                 -- PC 5
  .CopyLoc 3,                                               -- PC 6
  .Call «confidential_asset::verify_registration_proof_native», -- PC 7
  .BrFalse 12,                                              -- PC 8
  .LdU64 0,                                                 -- PC 9
  .Ret,                                                     -- PC 10
  .LdU64 65537,                                             -- PC 11
  .Abort                                                    -- PC 12
]

@[irreducible]
def registrationState (pc : Nat) (proofRef : Address) (locals : Locals) : Frame :=
  { code := verifyRegistrationProofCode,
    pc := pc,
    locals := locals,
    operandStack := [],
    frameId := ⟨0, by omega⟩,
    typeArgs := [],
    initialLocals := [
      .reference proofRef,              -- Arg0
      .vectorU8 #[],                    -- Arg1
      .some (.ristrettoPoint default),  -- local2
      .some (.registrationProof default) -- local3
    ]
  }

@[simp]
theorem registrationState_pc : (registrationState pc ref locals).pc = pc := by
  unfold registrationState; rfl

@[simp]
theorem registrationState_code : (registrationState pc ref locals).code =
    verifyRegistrationProofCode := by
  unfold registrationState; rfl

end MovementFormal.Experimental.ConfidentialAsset.Registration
```

**Step lemmas (selected):**

```lean
-- File: EvalEquivRebuild.lean

theorem registrationStep_0_to_1
    (env : Environment)
    (proofRef : Address)
    (locals : Locals)
    : step env (registrationState 0 proofRef locals) =
        .inProgress (registrationState 1 proofRef locals') := by
  unfold step
  rw [registrationState_code, registrationState_pc]
  simp [verifyRegistrationProofCode]
  apply step_copyLoc
  · simp [locals']  -- locals' = locals (unchanged by CopyLoc)
  done

theorem registrationStep_7_to_8
    (env : Environment)
    (proofRef : Address)
    (locals : Locals)
    (h_oracle : env.oracle «verify_registration_proof_native» proof = result)
    : step env (registrationState 7 proofRef locals) =
        .inProgress (registrationState 8 proofRef locals') := by
  unfold step
  rw [registrationState_code, registrationState_pc]
  simp [verifyRegistrationProofCode]
  apply step_call_native
  · exact h_oracle
  · simp [locals', result]
  done

theorem registrationStep_8_to_9_success
    (h_stack : stack.top = .bool true)
    : step env (registrationState 8 proofRef (stack :: locals)) =
        .inProgress (registrationState 9 proofRef locals) := by
  apply step_brFalse_skip  -- BrFalse doesn't branch when true
  exact h_stack
  done

theorem registrationStep_8_to_12_failure
    (h_stack : stack.top = .bool false)
    : step env (registrationState 8 proofRef (stack :: locals)) =
        .inProgress (registrationState 12 proofRef locals) := by
  apply step_brFalse_take  -- BrFalse branches when false
  exact h_stack
  done

theorem registrationStep_9_to_10
    : step env (registrationState 9 proofRef locals) =
        .inProgress (registrationState 10 proofRef ([.u64 0] :: locals)) := by
  apply step_ldU64
  rfl

theorem registrationStep_10_ret
    (h_stack : stack = [.u64 0])
    : step env (registrationState 10 proofRef (stack :: locals)) =
        .returned stack := by
  apply step_ret
  exact h_stack
  done

theorem registrationStep_11_to_12
    : step env (registrationState 11 proofRef locals) =
        .inProgress (registrationState 12 proofRef ([.u64 65537] :: locals)) := by
  apply step_ldU64
  rfl

theorem registrationStep_12_abort
    (h_stack : stack = [.u64 65537])
    : step env (registrationState 12 proofRef (stack :: locals)) =
        .aborted 65537 := by
  apply step_abort
  exact h_stack
  done
```

**Composition theorem:**

```lean
theorem registration_eval_equiv_functional_sim
    (proofRef : Address)
    (addr : Address)
    (h_oracle : oracleResult = env.oracle «verify_registration_proof_native» proof)
    : eval env (registrationState 0 proofRef addr) cs ms =
        match oracleResult with
        | .success => .returned [.u64 0] ms
        | .verifyFailed => .aborted 65537 ms
  := by
  unfold eval
  rw [eval_registration_eq_run]
  cases oracleResult with
  | success =>
    -- Success path: 0 → 1 → ... → 10 → Ret
    rw [registrationStep_0_to_1]
    rw [registrationStep_1_to_2]
    rw [registrationStep_2_to_3]
    rw [registrationStep_3_to_4]
    rw [registrationStep_4_to_5]
    rw [registrationStep_5_to_6]
    rw [registrationStep_6_to_7]
    rw [registrationStep_7_to_8 (h_oracle := h_oracle)]
    rw [registrationStep_8_to_9_success (h_stack := rfl)]
    rw [registrationStep_9_to_10]
    rw [registrationStep_10_ret (h_stack := rfl)]
    rfl
  | verifyFailed =>
    -- Failure path: 0 → 1 → ... → 8 → 12 → Abort
    rw [registrationStep_0_to_1]
    rw [registrationStep_1_to_2]
    rw [registrationStep_2_to_3]
    rw [registrationStep_3_to_4]
    rw [registrationStep_4_to_5]
    rw [registrationStep_5_to_6]
    rw [registrationStep_6_to_7]
    rw [registrationStep_7_to_8 (h_oracle := h_oracle)]
    rw [registrationStep_8_to_12_failure (h_stack := rfl)]
    rw [registrationStep_11_to_12]
    rw [registrationStep_12_abort (h_stack := rfl)]
    rfl
```

### 9.2 Example: Transfer Operation (Partial)

**Bytecode excerpt (Transfer has ~120 instructions):**

```
public confidential_transfer_internal(...): u64 {
B0:
    0: CopyLoc[0](sender: &signer)
    1: Call get_sender_address(&signer): address
    2: StLoc[4](sender_addr: address)
    3: CopyLoc[1](receiver: &signer)
    4: Call get_receiver_address(&signer): address
    5: StLoc[5](receiver_addr: address)
    ...
   15: CopyLoc[3](proof: TransferProof)
   16: Call verify_transfer_proof_native(TransferProof): bool
   17: BrFalse 100
    ...
  100: LdU64 65537
  101: Abort
}
```

**Lean transcription (partial):**

```lean
def verifyTransferCode : Code := [
  .CopyLoc 0,                                       -- PC 0
  .Call «confidential_asset::get_sender_address»,   -- PC 1
  .StLoc 4,                                         -- PC 2
  .CopyLoc 1,                                       -- PC 3
  .Call «confidential_asset::get_receiver_address», -- PC 4
  .StLoc 5,                                         -- PC 5
  -- ... (90 more instructions)
  .CopyLoc 3,                                       -- PC 15
  .Call «confidential_asset::verify_transfer_proof_native», -- PC 16
  .BrFalse 100,                                     -- PC 17
  -- ... (success path)
  .LdU64 65537,                                     -- PC 100
  .Abort                                            -- PC 101
]

-- State constructor similar to Registration
@[irreducible]
def transferState (pc : Nat) (sender : Address) (receiver : Address) ... : Frame :=
  { code := verifyTransferCode,
    pc := pc,
    locals := ...,
    ...
  }
```

**Note:** Transfer is significantly more complex (120 instructions vs 13 for Registration). Estimated transcription time: 4-6 hours.

---

## 10. Troubleshooting

### 10.1 Build Errors

**Error: `unknown identifier 'operationCode'`**

**Cause:** Typo in code definition name.

**Fix:** Check definition name matches usage:
```lean
def verifyRegistrationProofCode : Code := [...]  -- Definition

-- Usage must match:
{ code := verifyRegistrationProofCode, ... }  -- Match exactly
```

---

**Error: `type mismatch, expected Code, got List Instruction`**

**Cause:** Missing type annotation.

**Fix:** Add explicit type:
```lean
def operationCode : Code := [...]  -- Add `: Code`
```

---

**Error: `unknown constant 'EVERIFY_FAILED'`**

**Cause:** Using symbolic name instead of numeric constant.

**Fix:** Use numeric value:
```lean
.LdU64 65537  -- Not .LdU64 EVERIFY_FAILED
```

---

### 10.2 Proof Errors

**Error: `step lemma fails with 'instruction mismatch'`**

**Cause:** PC misalignment or wrong instruction.

**Fix:**
```bash
# Check instruction at PC N in both:
# Lean:
grep -A 1 "def verifyRegistrationProofCode" Registration.lean | head -n 20

# Bytecode:
grep "^    $N:" registration.dis
```

---

**Error: `sorry placeholder`**

**Cause:** Proof not completed.

**Fix:** Complete the proof or file issue if stuck.

---

**Error: `maximum heartbeats exceeded`**

**Cause:** Missing `@[irreducible]` or inefficient proof.

**Fix:**
```lean
-- Add @[irreducible]:
@[irreducible]
def operationState := ...

-- If already present, optimize proof (use simp lemmas)
```

---

### 10.3 Difftest Failures

**Error: `difftest: PC mismatch at step 5`**

**Cause:** Transcription diverged from actual bytecode.

**Fix:**
```bash
# Run difftest with debug output
cargo test test_register_happy_path -- --nocapture

# Check PC 5 in both Lean and bytecode
# Ensure instruction at PC 5 matches exactly
```

---

**Error: `difftest: abort code mismatch (expected 65537, got 0)`**

**Cause:** Wrong abort path or missing abort.

**Fix:** Check abort code constant:
```lean
.LdU64 65537  -- Ensure exact value
.Abort
```

---

**Error: `difftest: local index out of bounds`**

**Cause:** Wrong local count in `initialLocals`.

**Fix:**
```lean
-- Count locals in bytecode disassembly
-- Ensure initialLocals has same count
initialLocals := [
  .reference arg0,
  .vectorU8 arg1,
  .none,  -- Add missing locals
  .none,
  ...
]
```

---

### 10.4 Performance Issues

**Problem: File takes >10 minutes to build**

**Cause:** Missing `@[irreducible]` or inefficient proof tactics.

**Fix:**
```lean
-- Add @[irreducible] to all state definitions
@[irreducible]
def operationState := ...

-- Replace `simp` with specific simp lemmas:
simp only [operationState_pc, operationState_code]  -- Instead of bare `simp`
```

---

**Problem: Out of memory during elaboration**

**Cause:** Lean unfolding large structures.

**Fix:** Use `@[irreducible]` + `@[simp]` pattern:
```lean
@[irreducible]
def state := { large structure }

@[simp]
theorem state_field : state.field = value := by
  unfold state; rfl  -- Controlled unfolding
```

---

### 10.5 Getting Help

**If stuck:**

1. **Check existing examples:**
   - `Registration.lean` (simplest, complete)
   - `Transfer.lean` (complex, in progress)

2. **Review step lemma library:**
   - `MovementFormal/MoveModel/StepLemmas/`

3. **Run difftest in debug mode:**
   ```bash
   cargo test test_operation_name -- --nocapture
   ```

4. **Consult related guides:**
   - `PHASE_1_SINGLETON_SOME_BRANCH_COMPLETION_GUIDE.md` (Registration details)
   - `PHASE_6_PC_CHAINING_COMPLETE_GUIDE.md` (Composition workflow)
   - `LEAN_ARCHITECTURE_DEEP_DIVE.md` (Architecture patterns)

5. **File an issue:**
   - Include: bytecode disassembly, Lean code, error message
   - Tag: `verification`, `lean`, `bytecode-transcription`

---

**END OF GUIDE**

**Key takeaways:**

1. **Transcription must be 100% faithful** to bytecode — any deviation invalidates the proof
2. **Use `@[irreducible]` + `@[simp]` pattern** for 600× speedup
3. **Validate with difftest** frequently (after every 5-10 instructions)
4. **PC alignment is critical** — check often
5. **Constants must be exact** — no typos in abort codes
6. **Follow the workflow** — compile → disassemble → analyze → transcribe → verify
7. **Budget 3-6 hours per operation** (depending on complexity)

**Next steps:**

- Apply this workflow to complete Phase 1 Registration (final 5%)
- Use for Phase 6 PC-chaining proofs (4 operations)
- Expand to future CA operations as needed

**Questions?** See `DEVELOPER_WORKFLOW_GUIDE.md` or file an issue.
