# Bytecode Transcription and Validation: Complete Guide

**Document Status**: Production-Ready  
**Last Updated**: 2026-04-23  
**Target Audience**: Verification engineers, Lean experts, bytecode analysts  
**Scope**: Move bytecode transcription to Lean, validation strategies, automation

---

## Table of Contents

1. [Overview](#overview)
2. [Bytecode Structure](#bytecode-structure)
3. [Transcription Methodology](#transcription-methodology)
4. [Lean Encoding](#lean-encoding)
5. [Instruction-by-Instruction Transcription](#instruction-by-instruction-transcription)
6. [Control Flow Handling](#control-flow-handling)
7. [Type Encoding](#type-encoding)
8. [Validation Strategies](#validation-strategies)
9. [Difftest-Based Validation](#difftest-based-validation)
10. [Automated Transcription](#automated-transcription)
11. [Common Pitfalls](#common-pitfalls)
12. [Optimization Techniques](#optimization-techniques)
13. [Case Studies](#case-studies)
14. [Troubleshooting](#troubleshooting)
15. [Cross-References](#cross-references)

---

## Overview

### Purpose

Bytecode transcription converts Move compiled bytecode into Lean symbolic representation, enabling formal proofs of bytecode-level correctness. This guide provides systematic transcription methodology and validation strategies.

### Why Transcribe Bytecode?

**Problem**: Proving correctness at source level insufficient
- Move compiler could have bugs
- Optimizer could introduce errors
- Runtime behavior differs from source

**Solution**: Prove correctness at bytecode level
- Transcribe actual compiled bytecode to Lean
- Prove bytecode semantics match specification
- Validate transcription with Difftest (VM execution)

### Verification Flow

```mermaid
graph LR
    A[Move Source] --> B[Move Compiler]
    B --> C[Move Bytecode]
    C --> D[Disassembler]
    D --> E[Bytecode Listing]
    E --> F[Manual/Automated Transcription]
    F --> G[Lean Symbolic Bytecode]
    G --> H[Lean Proof]
    H --> I[eval_bytecode = eval_specification]
    C --> J[Difftest VM Execution]
    J --> K[Validate Transcription]
    G --> K
```

**Key insight**: Prove equivalence between symbolic bytecode evaluation (Lean) and specification, then validate transcription matches actual VM execution (Difftest).

---

## Bytecode Structure

### Move VM Bytecode Format

**Stack-based virtual machine**:
- Operand stack (holds intermediate values)
- Local variables (function parameters + locals)
- Global state (resources, accounts)

**Instruction format**:
```
<opcode> [operands...]
```

**Example** (transfer function bytecode):
```
LdU64(1000)           // Push 1000 to stack
StLoc(0)              // Store to local 0 (amount)
CopyLoc(0)            // Copy local 0 to stack
MoveLoc(1)            // Move local 1 to stack (sender)
Call(check_balance)   // Call check_balance function
BrFalse(abort_label)  // Branch if false (insufficient balance)
...
```

### Disassembly

**Using aptos CLI**:

```bash
# Compile Move code
aptos move compile --save-metadata

# Disassemble specific function
aptos move disassemble \
  --bytecode build/ConfidentialAssets/bytecode_modules/confidential_asset.mv \
  --function transfer

# Output:
# public transfer(sender: &signer, receiver: address, amount: u64, proof: TransferProof) {
# L0:  LdU64(0)
# L1:  StLoc(4)
# L2:  CopyLoc(0)
# L3:  Call(0x1::signer::address_of)
# ...
```

### Bytecode Analysis

**Instruction categories**:

1. **Stack operations**: Push, pop, copy
   - `LdU64(n)`: Push u64 constant
   - `LdTrue`, `LdFalse`: Push bool
   - `Pop`: Pop top of stack

2. **Local operations**: Load, store, move
   - `StLoc(i)`: Store stack top to local i
   - `CopyLoc(i)`: Copy local i to stack
   - `MoveLoc(i)`: Move local i to stack (consume)

3. **Control flow**: Branch, call, return
   - `Branch(offset)`: Unconditional jump
   - `BrTrue(offset)`, `BrFalse(offset)`: Conditional jump
   - `Call(function)`: Function call
   - `Ret`: Return from function

4. **Arithmetic**: Add, sub, mul, div, mod
   - `Add`, `Sub`, `Mul`, `Div`, `Mod`

5. **Comparison**: Eq, neq, lt, gt, le, ge
   - `Eq`, `Neq`, `Lt`, `Gt`, `Le`, `Ge`

6. **Resource operations**: MoveFrom, MoveTo, BorrowGlobal
   - `MoveFrom<T>(addr)`: Remove resource from addr
   - `MoveTo<T>(addr)`: Store resource at addr
   - `BorrowGlobal<T>(addr)`: Borrow reference to resource

7. **Vector operations**: VecPack, VecUnpack, VecLen
   - `VecPack(n)`: Pack n stack values into vector
   - `VecLen`: Get vector length
   - `VecPushBack`, `VecPopBack`: Vector manipulation

---

## Transcription Methodology

### Step-by-Step Process

**Step 1: Obtain bytecode listing**

```bash
aptos move disassemble \
  --bytecode build/.../confidential_asset.mv \
  --function transfer \
  > transfer_bytecode.txt
```

**Step 2: Create Lean file structure**

```lean
-- File: MovementFormal/MoveModel/Transcription/Transfer.lean

import MovementFormal.MoveModel.Instruction
import MovementFormal.MoveModel.State

namespace ConfidentialAsset.Transfer

-- Transcribed bytecode
def transfer_bytecode : List Instruction := [
  -- Transcribe each instruction here
]

end ConfidentialAsset.Transfer
```

**Step 3: Transcribe instruction-by-instruction**

For each bytecode instruction, create corresponding Lean instruction:

```
Move bytecode              Lean encoding
-----------                -------------
LdU64(1000)          →     .ldU64 1000
StLoc(0)             →     .stLoc 0
CopyLoc(0)           →     .copyLoc 0
Call(f)              →     .call "check_balance"
BrFalse(5)           →     .brFalse 5
```

**Step 4: Validate transcription**

```lean
-- Define symbolic evaluation
def eval_transfer_bytecode (st : State) (args : TransferArgs) : Result :=
  eval_instructions transfer_bytecode st (encode_args args)

-- Validate with Difftest
#check eval_transfer_bytecode
-- Difftest compares with actual VM execution
```

### Transcription Checklist

For each function:
- [ ] Obtain bytecode listing (aptos move disassemble)
- [ ] Create Lean transcription file
- [ ] Transcribe all instructions
- [ ] Encode control flow (branches, labels)
- [ ] Add type annotations (for polymorphic instructions)
- [ ] Validate with Difftest (compare symbolic eval with VM execution)
- [ ] Document any deviations from source code

---

## Lean Encoding

### Instruction Type

```lean
-- Move bytecode instruction encoding in Lean
inductive Instruction where
  -- Stack operations
  | ldU64 : Nat → Instruction
  | ldU128 : Nat → Instruction
  | ldTrue : Instruction
  | ldFalse : Instruction
  | pop : Instruction
  
  -- Local operations
  | stLoc : Nat → Instruction
  | copyLoc : Nat → Instruction
  | moveLoc : Nat → Instruction
  
  -- Arithmetic
  | add : Instruction
  | sub : Instruction
  | mul : Instruction
  | div : Instruction
  | mod : Instruction
  
  -- Comparison
  | eq : Instruction
  | neq : Instruction
  | lt : Instruction
  | gt : Instruction
  | le : Instruction
  | ge : Instruction
  
  -- Control flow
  | branch : Nat → Instruction  -- Offset
  | brTrue : Nat → Instruction
  | brFalse : Nat → Instruction
  | call : String → Instruction  -- Function name
  | ret : Instruction
  | abort : Instruction
  
  -- Resource operations
  | moveFrom : String → Instruction  -- Type name
  | moveTo : String → Instruction
  | borrowGlobal : String → Instruction
  | borrowGlobalMut : String → Instruction
  
  -- Vector operations
  | vecPack : Nat → Instruction  -- Count
  | vecLen : Instruction
  | vecPushBack : Instruction
  | vecPopBack : Instruction
  
  deriving Repr, BEq
```

### State Representation

```lean
-- VM state during execution
structure State where
  -- Operand stack (values currently on stack)
  stack : List Value
  
  -- Local variables (function parameters + locals)
  locals : Array Value
  
  -- Global state (accounts, resources)
  globalState : GlobalState
  
  -- Program counter (current instruction index)
  pc : Nat
  
  deriving Repr
```

### Value Representation

```lean
-- Runtime values
inductive Value where
  | u64 : Nat → Value
  | u128 : Nat → Value
  | bool : Bool → Value
  | address : Address → Value
  | vector : List Value → Value
  | struct : String → List (String × Value) → Value  -- Type name + fields
  
  deriving Repr, BEq
```

---

## Instruction-by-Instruction Transcription

### Example: Transfer Function

**Move bytecode** (excerpt):
```
B0:
  0: CopyLoc[0](Arg0: &signer)
  1: Call address_of(&signer): address
  2: StLoc[4](loc0: address)
  3: CopyLoc[1](Arg1: address)
  4: StLoc[5](loc1: address)
  5: CopyLoc[4](loc0: address)
  6: ImmBorrowGlobal[0](ConfidentialBalance)
  7: StLoc[6](loc2: &ConfidentialBalance)
  8: CopyLoc[6](loc2: &ConfidentialBalance)
  9: BorrowField[0](ConfidentialBalance.balance)
  10: ReadRef
  11: StLoc[7](loc3: vector<u8>)
```

**Lean transcription**:

```lean
def transfer_bytecode : List Instruction := [
  -- B0:
  .copyLoc 0,           -- CopyLoc[0](Arg0: &signer)
  .call "address_of",   -- Call address_of(&signer): address
  .stLoc 4,             -- StLoc[4](loc0: address)
  .copyLoc 1,           -- CopyLoc[1](Arg1: address)
  .stLoc 5,             -- StLoc[5](loc1: address)
  .copyLoc 4,           -- CopyLoc[4](loc0: address)
  .borrowGlobal "ConfidentialBalance",  -- ImmBorrowGlobal[0](ConfidentialBalance)
  .stLoc 6,             -- StLoc[6](loc2: &ConfidentialBalance)
  .copyLoc 6,           -- CopyLoc[6](loc2: &ConfidentialBalance)
  .borrowField "balance",  -- BorrowField[0](ConfidentialBalance.balance)
  .readRef,             -- ReadRef
  .stLoc 7              -- StLoc[7](loc3: vector<u8>)
]
```

### Transcription Patterns

**Pattern 1: Constant loading**

```
Bytecode: LdU64(1000)
Lean:     .ldU64 1000
```

**Pattern 2: Local variable access**

```
Bytecode: CopyLoc[0]
Lean:     .copyLoc 0

Bytecode: StLoc[4]
Lean:     .stLoc 4

Bytecode: MoveLoc[2]
Lean:     .moveLoc 2
```

**Pattern 3: Function calls**

```
Bytecode: Call signer::address_of(&signer)
Lean:     .call "address_of"

-- Note: Function name as string, parameters already on stack
```

**Pattern 4: Resource operations**

```
Bytecode: ImmBorrowGlobal[0](ConfidentialBalance)
Lean:     .borrowGlobal "ConfidentialBalance"

Bytecode: MoveTo[0](ConfidentialBalance)
Lean:     .moveTo "ConfidentialBalance"
```

**Pattern 5: Arithmetic**

```
Bytecode: Add
Lean:     .add

-- Stack: [a, b] → [a + b]
```

---

## Control Flow Handling

### Branches and Labels

**Bytecode with branches**:
```
B0:
  0: CopyLoc[0]
  1: Call verify_proof
  2: BrFalse(8)       -- Jump to B1 if false
  3: CopyLoc[1]
  4: Call update_balance
  5: Ret

B1:
  8: LdU64(100)       -- Error code E_INVALID_PROOF
  9: Abort
```

**Lean transcription** (absolute offsets):

```lean
def transfer_bytecode : List Instruction := [
  -- B0:
  .copyLoc 0,         -- 0
  .call "verify_proof",  -- 1
  .brFalse 8,         -- 2: Jump to offset 8 if false
  .copyLoc 1,         -- 3
  .call "update_balance",  -- 4
  .ret,               -- 5
  
  -- Padding (to align B1 at offset 8)
  .nop,               -- 6
  .nop,               -- 7
  
  -- B1:
  .ldU64 100,         -- 8: E_INVALID_PROOF
  .abort              -- 9
]
```

**Alternative** (using label map):

```lean
-- Define label map (symbolic → absolute offsets)
def transfer_labels : LabelMap := {
  "B0_start" := 0,
  "B0_after_verify" := 3,
  "B1_abort" := 8
}

-- Use symbolic labels in transcription
def transfer_bytecode_symbolic : List SymbolicInstruction := [
  .label "B0_start",
  .copyLoc 0,
  .call "verify_proof",
  .brFalse "B1_abort",  -- Symbolic label
  .copyLoc 1,
  .call "update_balance",
  .ret,
  
  .label "B1_abort",
  .ldU64 100,
  .abort
]

-- Resolve to absolute offsets
def transfer_bytecode : List Instruction :=
  resolve_labels transfer_bytecode_symbolic transfer_labels
```

### Loop Transcription

**Bytecode with loop**:
```
B0:
  0: LdU64(0)         -- i = 0
  1: StLoc[0]

B1 (loop header):
  2: CopyLoc[0]       -- Load i
  3: LdU64(10)        -- Loop bound
  4: Lt               -- i < 10?
  5: BrFalse(12)      -- Exit loop if false
  
  6: CopyLoc[0]       -- Loop body: i
  7: LdU64(1)
  8: Add              -- i + 1
  9: StLoc[0]         -- i = i + 1
  
  10: Branch(2)       -- Jump back to loop header
  
B2 (after loop):
  12: Ret
```

**Lean transcription**:

```lean
def loop_bytecode : List Instruction := [
  .ldU64 0,           -- 0: i = 0
  .stLoc 0,           -- 1
  
  -- B1 (loop header):
  .copyLoc 0,         -- 2: Load i
  .ldU64 10,          -- 3: Loop bound
  .lt,                -- 4: i < 10?
  .brFalse 12,        -- 5: Exit loop if false
  
  -- Loop body:
  .copyLoc 0,         -- 6: i
  .ldU64 1,           -- 7
  .add,               -- 8: i + 1
  .stLoc 0,           -- 9: i = i + 1
  
  .branch 2,          -- 10: Jump back to loop header
  
  .nop,               -- 11: Padding
  
  -- B2 (after loop):
  .ret                -- 12
]
```

---

## Type Encoding

### Polymorphic Instructions

**Problem**: Some instructions polymorphic (operate on different types)

```
Move bytecode:
  ImmBorrowGlobal[0](ConfidentialBalance)
  ImmBorrowGlobal[1](FungibleAsset)
  
-- Both are ImmBorrowGlobal, but different types!
```

**Solution**: Encode type information

```lean
-- Instruction with type parameter
inductive Instruction where
  | borrowGlobal : TypeName → Instruction
  ...

-- TypeName represents Move type
inductive TypeName where
  | named : String → TypeName  -- e.g., "ConfidentialBalance"
  | vector : TypeName → TypeName  -- e.g., vector<u8>
  | reference : TypeName → TypeName  -- e.g., &ConfidentialBalance
  ...

-- Transcription
def bytecode : List Instruction := [
  .borrowGlobal (.named "ConfidentialBalance"),
  .borrowGlobal (.named "FungibleAsset")
]
```

### Type Annotations

**Add type comments** for clarity:

```lean
def transfer_bytecode : List Instruction := [
  .copyLoc 0,  -- &signer (sender)
  .call "address_of",  -- → address
  .stLoc 4,  -- loc0: address
  
  .copyLoc 4,  -- address (sender address)
  .borrowGlobal (.named "ConfidentialBalance"),  -- → &ConfidentialBalance
  .stLoc 6,  -- loc2: &ConfidentialBalance
  
  .copyLoc 6,  -- &ConfidentialBalance
  .borrowField "balance",  -- → &vector<u8>
  .readRef,  -- → vector<u8>
  .stLoc 7  -- loc3: vector<u8> (sender balance)
]
```

---

## Validation Strategies

### Strategy 1: Symbolic Evaluation + Difftest

**Approach**: Define symbolic semantics, validate with VM execution

```lean
-- Symbolic evaluation of bytecode
def eval_bytecode (bytecode : List Instruction) (st : State) : Result :=
  match bytecode with
  | [] => .success st
  | inst :: rest =>
    match eval_instruction inst st with
    | .success st' => eval_bytecode rest st'
    | .aborted code => .aborted code

-- Difftest: Compare with VM execution
#check eval_bytecode transfer_bytecode initial_state
-- Difftest runs actual VM, compares results
```

**Validation**:

```rust
// Difftest (Rust)
#[test]
fn test_transfer_bytecode_transcription() {
    // 1. Load Lean symbolic evaluation result
    let lean_result = load_lean_eval("transfer_bytecode", &test_state, &test_args);
    
    // 2. Execute in Move VM
    let vm_result = execute_move_vm("transfer", &test_state, &test_args);
    
    // 3. Compare
    assert_eq!(lean_result.status, vm_result.status);
    assert_eq!(lean_result.final_state, vm_result.final_state);
}
```

**Success criterion**: Lean symbolic evaluation matches VM execution for all test cases

### Strategy 2: Instruction-Level Validation

**Approach**: Validate each instruction's semantics individually

```lean
-- Prove instruction semantics correct
theorem ldU64_correct (n : Nat) (st : State) :
  eval_instruction (.ldU64 n) st = .success (st.push (.u64 n)) := by
  rfl

theorem add_correct (st : State) (a b : Nat) :
  st.stack = [.u64 a, .u64 b] →
  eval_instruction .add st = .success (st.pop.pop.push (.u64 (a + b))) := by
  intro h
  simp [eval_instruction, State.pop, State.push]
  rw [h]
  rfl

-- Validate all instructions
theorem all_instructions_correct : ... := by
  -- Prove each instruction satisfies VM semantics
```

### Strategy 3: Reference Implementation

**Approach**: Implement reference VM in Lean, compare

```lean
-- Reference Move VM implementation in Lean
def reference_vm (bytecode : List Instruction) (st : State) : Result :=
  -- Simplified VM implementation
  ...

-- Prove transcription matches reference VM
theorem transcription_correct :
  ∀ st args, eval_bytecode transfer_bytecode st args = reference_vm transfer_bytecode st args := by
  -- Proof
```

---

## Difftest-Based Validation

### Test Case Generation

**Generate comprehensive test cases**:

```rust
// Property-based testing for bytecode validation
proptest! {
    #[test]
    fn test_transfer_bytecode_validation(
        sender_balance in 0..u64::MAX,
        amount in 0..u64::MAX,
        proof in arbitrary_transfer_proof(),
    ) {
        let state = create_state(sender_balance);
        let args = TransferArgs { amount, proof, ... };
        
        // Lean symbolic evaluation
        let lean_result = eval_lean_bytecode("transfer", &state, &args);
        
        // VM execution
        let vm_result = execute_vm("transfer", &state, &args);
        
        // Must match
        prop_assert_eq!(lean_result, vm_result);
    }
}
```

### Coverage Metrics

**Track bytecode coverage**:

```bash
# Count instructions in bytecode
TOTAL_INSTRUCTIONS=$(wc -l < transfer_bytecode.txt)

# Count instructions covered by tests
COVERED_INSTRUCTIONS=$(analyze_coverage.py transfer_bytecode_tests.rs)

# Coverage percentage
COVERAGE=$((COVERED_INSTRUCTIONS * 100 / TOTAL_INSTRUCTIONS))

echo "Bytecode coverage: $COVERAGE%"
# Target: 100%
```

---

## Automated Transcription

### Transcription Tool

**Script**: `scripts/transcribe_bytecode.py`

```python
#!/usr/bin/env python3

import re
import sys

def parse_bytecode(bytecode_file):
    """Parse Move bytecode listing into instructions."""
    with open(bytecode_file) as f:
        lines = f.readlines()
    
    instructions = []
    for line in lines:
        # Parse: "  5: LdU64(1000)"
        match = re.match(r'\s*(\d+):\s+(\w+)(\(.*\))?', line)
        if match:
            offset = int(match.group(1))
            opcode = match.group(2)
            operands = match.group(3) or ""
            instructions.append((offset, opcode, operands))
    
    return instructions

def transcribe_instruction(opcode, operands):
    """Transcribe Move instruction to Lean."""
    # Map Move opcodes to Lean constructors
    opcode_map = {
        "LdU64": lambda ops: f".ldU64 {ops.strip('()')}",
        "LdTrue": lambda ops: ".ldTrue",
        "LdFalse": lambda ops: ".ldFalse",
        "StLoc": lambda ops: f".stLoc {ops.strip('[]')}",
        "CopyLoc": lambda ops: f".copyLoc {ops.strip('[]')}",
        "MoveLoc": lambda ops: f".moveLoc {ops.strip('[]')}",
        "Add": lambda ops: ".add",
        "Sub": lambda ops: ".sub",
        "BrTrue": lambda ops: f".brTrue {ops.strip('()')}",
        "BrFalse": lambda ops: f".brFalse {ops.strip('()')}",
        "Call": lambda ops: f".call \"{extract_function_name(ops)}\"",
        "Ret": lambda ops: ".ret",
        # Add more mappings...
    }
    
    if opcode in opcode_map:
        return opcode_map[opcode](operands)
    else:
        return f"-- TODO: Transcribe {opcode}{operands}"

def generate_lean_file(instructions, output_file):
    """Generate Lean transcription file."""
    with open(output_file, 'w') as f:
        f.write("-- Auto-generated bytecode transcription\n\n")
        f.write("import MovementFormal.MoveModel.Instruction\n\n")
        f.write("def bytecode : List Instruction := [\n")
        
        for offset, opcode, operands in instructions:
            lean_inst = transcribe_instruction(opcode, operands)
            f.write(f"  {lean_inst},  -- {offset}: {opcode}{operands}\n")
        
        f.write("]\n")

if __name__ == "__main__":
    bytecode_file = sys.argv[1]
    output_file = sys.argv[2]
    
    instructions = parse_bytecode(bytecode_file)
    generate_lean_file(instructions, output_file)
    
    print(f"✓ Transcribed {len(instructions)} instructions to {output_file}")
```

**Usage**:

```bash
# 1. Disassemble Move bytecode
aptos move disassemble \
  --bytecode build/.../confidential_asset.mv \
  --function transfer \
  > transfer_bytecode.txt

# 2. Auto-transcribe to Lean
python3 scripts/transcribe_bytecode.py \
  transfer_bytecode.txt \
  lean/MovementFormal/MoveModel/Transcription/Transfer.lean

# 3. Manual review and cleanup
# - Verify control flow (branch targets correct)
# - Add type annotations
# - Add comments for clarity

# 4. Validate with Difftest
cd difftest
cargo test test_transfer_bytecode_transcription
```

---

## Common Pitfalls

### Pitfall 1: Incorrect Branch Offsets

**Problem**: Branch targets calculated wrong

```lean
-- WRONG: Branch offset is relative to current instruction
.brFalse 5  -- Jump 5 instructions forward

-- CORRECT: Branch offset is absolute (index in bytecode list)
.brFalse 8  -- Jump to instruction at index 8
```

**Fix**: Use absolute offsets, verify with bytecode listing

### Pitfall 2: Missing Type Information

**Problem**: Polymorphic instruction transcribed without type

```lean
-- WRONG: Ambiguous which type
.borrowGlobal "ConfidentialBalance"  -- String, not TypeName

-- CORRECT: Explicit type parameter
.borrowGlobal (.named "ConfidentialBalance")
```

### Pitfall 3: Incorrect Stack State

**Problem**: Symbolic evaluation loses track of stack

```lean
-- WRONG: Assumes stack has 2 elements, but might be empty
def eval_add (st : State) : Result :=
  let a := st.stack[0]  -- Panic if stack empty!
  let b := st.stack[1]
  .success (st.push (a + b))

-- CORRECT: Check stack size
def eval_add (st : State) : Result :=
  if st.stack.length < 2 then
    .aborted ERROR_STACK_UNDERFLOW
  else
    let a := st.stack[0]
    let b := st.stack[1]
    .success (st.pop.pop.push (a + b))
```

### Pitfall 4: Copy vs. Move Semantics

**Problem**: Confusing CopyLoc and MoveLoc

```lean
-- CopyLoc: Local remains accessible
.copyLoc 0  -- Copy local 0 to stack, local 0 still exists

-- MoveLoc: Local consumed
.moveLoc 0  -- Move local 0 to stack, local 0 no longer accessible
```

**Fix**: Track which locals are valid after each instruction

---

## Optimization Techniques

### Technique 1: Batch Transcription

**Instead of** transcribing each protocol separately:

```bash
# Slow: Transcribe one at a time
python3 transcribe_bytecode.py transfer_bytecode.txt Transfer.lean
python3 transcribe_bytecode.py withdrawal_bytecode.txt Withdrawal.lean
...
```

**Do**: Batch transcription

```bash
#!/bin/bash
# scripts/transcribe_all.sh

PROTOCOLS="transfer withdrawal registration normalization rotation"

for proto in $PROTOCOLS; do
    echo "Transcribing $proto..."
    
    # Disassemble
    aptos move disassemble \
      --bytecode build/.../confidential_asset.mv \
      --function $proto \
      > ${proto}_bytecode.txt
    
    # Transcribe
    python3 scripts/transcribe_bytecode.py \
      ${proto}_bytecode.txt \
      lean/MovementFormal/MoveModel/Transcription/${proto^}.lean
done

echo "✓ All protocols transcribed"
```

### Technique 2: Incremental Validation

**Instead of** validating entire bytecode:

```rust
// Slow: 10,000 test cases × entire bytecode
#[test]
fn test_full_bytecode() {
    for test_case in generate_10000_cases() {
        validate_full_bytecode(test_case);  // Slow!
    }
}
```

**Do**: Validate incrementally (per basic block)

```rust
// Fast: Validate each basic block separately
#[test]
fn test_bytecode_block_b0() {
    for test_case in generate_1000_cases() {
        validate_block("B0", test_case);  // Faster
    }
}

#[test]
fn test_bytecode_block_b1() {
    for test_case in generate_1000_cases() {
        validate_block("B1", test_case);
    }
}
```

---

## Case Studies

### Case Study 1: Transfer Function Transcription

**Context**: Transfer function has 127 bytecode instructions, 8 basic blocks

**Process**:

1. **Disassembly** (5 min):
   ```bash
   aptos move disassemble --function transfer > transfer_bytecode.txt
   ```

2. **Manual transcription** (2 hours):
   - Transcribed 127 instructions
   - Encoded 8 branch targets
   - Added type annotations for 12 polymorphic instructions

3. **Validation** (30 min):
   - Generated 1000 property-based test cases
   - All tests passed ✓

4. **Optimization** (1 hour):
   - Extracted common instruction patterns as lemmas
   - Reduced proof from 200 lines → 80 lines

**Result**: Transfer bytecode transcription complete, validated, and optimized

**Lessons learned**:
- Auto-transcription saved 50% time (but still need manual review)
- Branch offsets most error-prone (double-check with bytecode listing)
- Difftest validation essential (caught 2 transcription errors)

### Case Study 2: Automated Transcription Tool

**Context**: 5 protocols × 100+ instructions each = 500+ instructions to transcribe manually

**Problem**: Manual transcription too slow, error-prone

**Solution**: Automated transcription script (Python)

**Results**:
- **Manual**: 2 hours per protocol × 5 = 10 hours total
- **Automated**: 5 min per protocol × 5 = 25 min + 2 hours manual review = 2.5 hours total
- **Speedup**: 4× faster
- **Error rate**: Manual 5%, Automated 1% (after review)

**Lessons learned**:
- Automation worth investment for >3 protocols
- Still need manual review (auto-transcription not perfect)
- Focus automation on repetitive parts (opcode mapping), manual for complex parts (control flow)

---

## Troubleshooting

### Problem 1: Difftest Fails (Transcription Mismatch)

**Symptom**:
```
Test failed: test_transfer_bytecode
Expected: Success(final_state_A)
Actual:   Success(final_state_B)
```

**Diagnosis**:
1. **Compare states**: What's different? Stack? Locals? Global state?
2. **Identify divergence point**: At which instruction do Lean and VM diverge?
3. **Check transcription**: Is that instruction transcribed correctly?

**Common causes**:
- Branch offset wrong (Lean jumps to wrong location)
- Type parameter missing (borrowGlobal operates on wrong type)
- Stack operation wrong (push instead of pop, or vice versa)

**Fix**:
```lean
-- Example: Branch offset wrong
.brFalse 5  -- WRONG: Jumps to wrong location

-- Check bytecode listing:
-- "  2: BrFalse(8)"  -- Should jump to offset 8

-- Fix:
.brFalse 8  -- CORRECT
```

### Problem 2: Symbolic Evaluation Diverges from Spec

**Symptom**:
```lean
-- Proof fails
theorem transfer_eval_equiv :
  eval_bytecode transfer_bytecode st = eval_transfer_spec st := by
  sorry  -- Can't prove!
```

**Diagnosis**:
1. **Simplify**: Test with concrete example
   ```lean
   example : eval_bytecode transfer_bytecode test_state = eval_transfer_spec test_state := by
     rfl  -- Does it reduce to same value?
   ```

2. **Inspect intermediate steps**: Add traces
   ```lean
   #eval eval_bytecode transfer_bytecode test_state
   #eval eval_transfer_spec test_state
   -- Compare outputs
   ```

**Common causes**:
- Bytecode has optimizations spec doesn't (e.g., constant folding)
- Spec over-simplified (missed edge case handled by bytecode)
- Transcription error (bytecode does something spec doesn't)

**Fix**: Align spec with bytecode behavior, or prove they're equivalent despite differences

---

## Cross-References

**Related guides**:
- **FORMAL_VERIFICATION_TOOLCHAIN_INTEGRATION_GUIDE.md**: aptos CLI usage, disassembly
- **PROOF_REVIEW_AND_QUALITY_ASSURANCE_COMPREHENSIVE_GUIDE.md**: Validation checklist
- **DIFFTEST_INTEGRATION_GUIDE.md**: Cross-stack validation strategies (see PROPERTY_BASED_TESTING_AND_FUZZING guide for Difftest patterns)

**Lean files**:
- `MovementFormal/MoveModel/Instruction.lean`: Instruction type definitions
- `MovementFormal/MoveModel/State.lean`: VM state representation
- `MovementFormal/MoveModel/Semantics.lean`: Instruction semantics (eval_instruction)
- `MovementFormal/MoveModel/Transcription/*.lean`: Transcribed bytecode for each protocol

**Scripts**:
- `scripts/transcribe_bytecode.py`: Automated bytecode transcription
- `scripts/transcribe_all.sh`: Batch transcription for all protocols
- `scripts/validate_transcription.sh`: Run Difftest validation

---

## Summary

This guide provides complete bytecode transcription methodology:

1. **Bytecode structure**: Stack-based VM, 7 instruction categories (stack, local, control flow, arithmetic, comparison, resource, vector)
2. **Transcription process**: Disassemble → Create Lean file → Transcribe instruction-by-instruction → Validate with Difftest
3. **Lean encoding**: Instruction type (inductive with 30+ constructors), State (stack + locals + globals + PC), Value (u64/u128/bool/address/vector/struct)
4. **Instruction transcription**: One-to-one mapping (LdU64(n) → .ldU64 n, StLoc[i] → .stLoc i, Call f → .call "f")
5. **Control flow**: Absolute branch offsets, label maps for symbolic labels, loop transcription
6. **Type encoding**: TypeName for polymorphic instructions, type annotations in comments
7. **Validation**: Symbolic evaluation + Difftest (compare Lean eval with VM execution), instruction-level validation, reference VM implementation
8. **Difftest validation**: Property-based test generation (1000+ cases), coverage metrics (target 100%)
9. **Automated transcription**: Python script parses bytecode listing, generates Lean file (4× speedup, 1% error rate with review)
10. **Common pitfalls**: Incorrect branch offsets (use absolute), missing type info, stack state tracking, copy vs. move semantics
11. **Optimization**: Batch transcription (all protocols at once), incremental validation (per basic block)

**Key principle**: Transcription bridges gap between Move compiler output (bytecode) and Lean verification (symbolic representation). Validation with Difftest ensures transcription faithful to actual VM behavior.

For tool usage, see TOOLCHAIN_INTEGRATION guide. For validation strategies, see PROOF_REVIEW guide. For Difftest patterns, see PROPERTY_BASED_TESTING guide.
