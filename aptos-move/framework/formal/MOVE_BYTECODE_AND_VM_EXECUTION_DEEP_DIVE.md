# Move Bytecode and VM Execution Deep Dive for Formal Verification

**Version**: 1.0  
**Last Updated**: 2026-04-22  
**Status**: Production  
**Audience**: Verification engineers, VM developers, bytecode analysts  
**Estimated Read Time**: 95 minutes  
**Prerequisites**: Understanding of Move language, basic VM concepts  

---

## Table of Contents

1. [Overview](#overview)
2. [Move Bytecode Structure](#move-bytecode-structure)
3. [VM Execution Model](#vm-execution-model)
4. [Stack-Based Execution](#stack-based-execution)
5. [Local Variables and Frames](#local-variables-and-frames)
6. [Control Flow Instructions](#control-flow-instructions)
7. [Native Function Calls](#native-function-calls)
8. [Resource Operations](#resource-operations)
9. [Gas Metering](#gas-metering)
10. [Bytecode Verification Rules](#bytecode-verification-rules)
11. [Modeling Bytecode in Lean](#modeling-bytecode-in-lean)
12. [Bytecode Analysis Tools](#bytecode-analysis-tools)

---

## Overview

### Purpose

This guide provides a deep technical understanding of Move bytecode and VM execution, specifically tailored for formal verification work on Confidential Assets. Understanding bytecode execution is essential for:

1. **Lean proof development**: Modeling symbolic execution accurately
2. **Bytecode transcription**: Mapping compiled code to Lean representations
3. **Debugging**: Understanding why proofs fail or VM behaves unexpectedly
4. **Optimization**: Identifying performance bottlenecks in verification

### Move VM Architecture

**High-Level View:**
```
┌─────────────────────────────────────────────┐
│           Move Source Code                  │
│  public fun transfer(sender, receiver, ...) │
└──────────────┬──────────────────────────────┘
               │ Compilation
               ▼
┌─────────────────────────────────────────────┐
│           Move Bytecode                     │
│  0: LdU64(100)                             │
│  1: StLoc(0)                               │
│  2: Call(verify_proof)                     │
└──────────────┬──────────────────────────────┘
               │ Execution
               ▼
┌─────────────────────────────────────────────┐
│           Move VM                           │
│  - Stack-based execution                    │
│  - Gas metering                             │
│  - Resource safety                          │
└─────────────────────────────────────────────┘
```

**Key Components:**
- **Bytecode**: Binary representation of Move programs
- **Stack**: Temporary storage for computation
- **Locals**: Function-scoped variables
- **Global Storage**: Account resources (struct instances)
- **Gas Meter**: Tracks and enforces computation limits

---

## Move Bytecode Structure

### Binary Format

**File Structure:**
```
Move Bytecode File (.mv):
┌────────────────────────────┐
│ Magic Number (0xA11CEB0B)  │
├────────────────────────────┤
│ Version (major, minor)     │
├────────────────────────────┤
│ Module Handle Table        │
│  - Dependencies            │
├────────────────────────────┤
│ Struct Handle Table        │
│  - Type definitions        │
├────────────────────────────┤
│ Function Handle Table      │
│  - Signatures              │
├────────────────────────────┤
│ Constant Pool              │
│  - u64, u128, addresses    │
├────────────────────────────┤
│ Bytecode                   │
│  - Instruction sequences   │
└────────────────────────────┘
```

### Instruction Set Architecture

**Categories:**

**1. Stack Operations:**
```
LdU64(value)        // Push u64 constant
LdU128(value)       // Push u128 constant
LdConst(idx)        // Push constant from pool
LdTrue              // Push true
LdFalse             // Push false
```

**2. Local Operations:**
```
CopyLoc(idx)        // Copy local to stack
MoveLoc(idx)        // Move local to stack (invalidates local)
StLoc(idx)          // Store stack top to local
```

**3. Arithmetic:**
```
Add                 // Pop two, push sum
Sub                 // Pop two, push difference
Mul                 // Pop two, push product
Div                 // Pop two, push quotient
Mod                 // Pop two, push remainder
```

**4. Comparison:**
```
Lt                  // Less than
Le                  // Less or equal
Gt                  // Greater than
Ge                  // Greater or equal
Eq                  // Equal
Neq                 // Not equal
```

**5. Control Flow:**
```
Branch(offset)      // Unconditional jump
BrTrue(offset)      // Jump if stack top is true
BrFalse(offset)     // Jump if stack top is false
Ret                 // Return from function
Abort               // Abort execution
```

**6. Function Calls:**
```
Call(idx)           // Call function by index
CallGeneric(idx)    // Call generic function
```

**7. Resource Operations:**
```
MoveTo(idx)         // Move resource to account
MoveFrom(idx)       // Move resource from account
BorrowGlobal(idx)   // Borrow global resource
Exists(idx)         // Check if resource exists
```

### Example: Transfer Function Bytecode

**Move Source:**
```move
public fun transfer(sender: &signer, receiver: address, amount: u64) {
    let sender_balance = borrow_global_mut<Balance>(signer::address_of(sender));
    sender_balance.value = sender_balance.value - amount;
    
    let receiver_balance = borrow_global_mut<Balance>(receiver);
    receiver_balance.value = receiver_balance.value + amount;
}
```

**Compiled Bytecode:**
```
// Bytecode representation (simplified)
0:  CopyLoc[0]              // sender
1:  Call(signer::address_of)
2:  BorrowGlobalMut(Balance)
3:  StLoc[3]                // sender_balance

4:  CopyLoc[3]              // sender_balance
5:  ImmBorrowField(value)
6:  ReadRef
7:  CopyLoc[2]              // amount
8:  Sub
9:  CopyLoc[3]
10: MutBorrowField(value)
11: WriteRef

12: CopyLoc[1]              // receiver
13: BorrowGlobalMut(Balance)
14: StLoc[4]                // receiver_balance

15: CopyLoc[4]              // receiver_balance
16: ImmBorrowField(value)
17: ReadRef
18: CopyLoc[2]              // amount
19: Add
20: CopyLoc[4]
21: MutBorrowField(value)
22: WriteRef

23: Ret
```

**Lean Model:**
```lean
def transferBytecode : List Instruction :=
  [ Instruction.CopyLoc 0
  , Instruction.Call signerAddressOf
  , Instruction.BorrowGlobalMut balanceType
  , Instruction.StLoc 3
  , Instruction.CopyLoc 3
  , Instruction.ImmBorrowField valueField
  , Instruction.ReadRef
  , Instruction.CopyLoc 2
  , Instruction.Sub
  , Instruction.CopyLoc 3
  , Instruction.MutBorrowField valueField
  , Instruction.WriteRef
  -- ... (rest)
  , Instruction.Ret
  ]
```

---

## VM Execution Model

### Execution State

**Frame Structure:**
```lean
structure Frame where
  pc : Nat                    -- Program counter
  locals : List Value         -- Local variables
  stack : List Value          -- Operand stack
  gas : Nat                   -- Remaining gas
  h_pc_bound : pc < bytecode.length
  h_locals_length : locals.length = expected_locals
```

**Value Types:**
```lean
inductive Value
  | U64 : Nat → Value
  | U128 : Nat → Value
  | Bool : Bool → Value
  | Address : Address → Value
  | Vector : List Value → Value
  | Struct : List (String × Value) → Value
  | Reference : Address → FieldPath → Value
```

### Execution Loop

**Pseudo-code:**
```rust
fn execute(mut frame: Frame, bytecode: &[Instruction]) -> Result<Frame> {
    while frame.pc < bytecode.len() {
        let instruction = &bytecode[frame.pc];
        
        // Charge gas
        frame.gas = frame.gas.checked_sub(instruction.gas_cost())?;
        
        // Execute instruction
        match instruction {
            Instruction::LdU64(val) => {
                frame.stack.push(Value::U64(*val));
                frame.pc += 1;
            }
            Instruction::Add => {
                let rhs = frame.stack.pop()?;
                let lhs = frame.stack.pop()?;
                let sum = lhs.checked_add(rhs)?;
                frame.stack.push(sum);
                frame.pc += 1;
            }
            Instruction::BrTrue(offset) => {
                let cond = frame.stack.pop()?;
                if cond.as_bool()? {
                    frame.pc = frame.pc.wrapping_add(*offset);
                } else {
                    frame.pc += 1;
                }
            }
            // ... (other instructions)
        }
    }
    Ok(frame)
}
```

**Lean Model:**
```lean
def step (frame : Frame) : Option Frame :=
  if h : frame.pc < bytecode.length then
    let instruction := bytecode[frame.pc]
    match instruction with
    | Instruction.LdU64 val =>
      some { frame with
        stack := Value.U64 val :: frame.stack
        pc := frame.pc + 1
      }
    | Instruction.Add =>
      match frame.stack with
      | Value.U64 rhs :: Value.U64 lhs :: rest =>
        some { frame with
          stack := Value.U64 (lhs + rhs) :: rest
          pc := frame.pc + 1
        }
      | _ => none  -- Type error or stack underflow
    | Instruction.BrTrue offset =>
      match frame.stack with
      | Value.Bool true :: rest =>
        some { frame with
          stack := rest
          pc := frame.pc + offset
        }
      | Value.Bool false :: rest =>
        some { frame with
          stack := rest
          pc := frame.pc + 1
        }
      | _ => none
    -- ... (other instructions)
  else
    none  -- PC out of bounds

-- Multi-step execution
def run (fuel : Nat) (frame : Frame) : Option Frame :=
  match fuel with
  | 0 => some frame
  | n + 1 =>
    match step frame with
    | some frame' => run n frame'
    | none => none
```

---

## Stack-Based Execution

### Stack Discipline

**Stack Invariants:**
```lean
-- Every instruction maintains stack discipline
axiom stack_discipline :
  ∀ instruction frame frame',
    step frame = some frame' →
    frame'.stack.length = frame.stack.length + stack_effect(instruction)

-- stack_effect returns the net change in stack size
def stack_effect : Instruction → Int
  | Instruction.LdU64 _ => 1        -- Push 1
  | Instruction.Add => -1           -- Pop 2, push 1
  | Instruction.Eq => -1            -- Pop 2, push 1
  | Instruction.BrTrue _ => -1      -- Pop 1
  | Instruction.CopyLoc _ => 1      -- Push 1
  | Instruction.StLoc _ => -1       -- Pop 1
  | Instruction.Ret => -(locals + stack)  -- Clear everything
  -- ...
```

### Stack Safety

**Type Safety:**
```lean
-- Instructions only operate on correctly-typed values
axiom type_safety :
  ∀ frame frame',
    well_typed frame →
    step frame = some frame' →
    well_typed frame'

-- Well-typed frames have correctly-typed stack/locals
def well_typed (frame : Frame) : Prop :=
  ∀ i val, frame.stack[i] = some val →
    type_of val = expected_type_at_stack_position i
```

**Example: Type Error Detection:**
```lean
-- This would fail type checking
theorem add_requires_numbers :
    frame.stack = [Value.Bool true, Value.U64 5] →
    step { frame with instruction := Instruction.Add } = none := by
  -- Type mismatch: Bool is not U64
  simp [step]
  -- Proof that Add requires two U64 values
```

### Stack Operations in Practice

**Example: Computing `(a + b) * c`**

**Move Source:**
```move
let result = (a + b) * c;
```

**Bytecode:**
```
0: CopyLoc[0]     // Stack: [a]
1: CopyLoc[1]     // Stack: [b, a]
2: Add            // Stack: [a+b]
3: CopyLoc[2]     // Stack: [c, a+b]
4: Mul            // Stack: [(a+b)*c]
5: StLoc[3]       // Stack: []
```

**Lean Proof:**
```lean
theorem compute_expression :
    let initial := { pc := 0, locals := [a, b, c, 0], stack := [], ... }
    let final := run 6 initial
    final.stack = [] ∧ final.locals[3] = (a + b) * c := by
  unfold run
  -- Step 0: CopyLoc[0]
  rw [step]
  simp
  -- Step 1: CopyLoc[1]
  rw [step]
  simp
  -- Step 2: Add
  rw [step]
  simp [add_def]
  -- Step 3: CopyLoc[2]
  rw [step]
  simp
  -- Step 4: Mul
  rw [step]
  simp [mul_def]
  -- Step 5: StLoc[3]
  rw [step]
  simp
  -- Final state
  rfl
```

---

## Local Variables and Frames

### Local Variable Semantics

**Move-vs-Copy:**
```move
// Copy: value remains in local
let x = 5;
let y = x;  // x is still valid (u64 is Copy)

// Move: value moved out of local
let balance = Balance { value: 100 };
let b = balance;  // balance is now invalid (Balance is not Copy)
```

**Bytecode:**
```
// Copy
0: CopyLoc[0]   // x still valid after

// Move
0: MoveLoc[0]   // x invalid after
```

**Lean Model:**
```lean
structure Locals where
  values : List (Option Value)  -- None = moved/uninitialized

def copyLocal (locals : Locals) (idx : Nat) : Option (Locals × Value) :=
  match locals.values[idx] with
  | some (some val) => some (locals, val)  -- Value still in local
  | _ => none  -- Uninitialized or moved

def moveLocal (locals : Locals) (idx : Nat) : Option (Locals × Value) :=
  match locals.values[idx] with
  | some (some val) =>
    let locals' := { locals with values := locals.values.set idx none }
    some (locals', val)  -- Value removed from local
  | _ => none

-- Safety: Can't use moved local
theorem cant_use_moved_local :
    moveLocal locals 0 = some (locals', val) →
    copyLocal locals' 0 = none := by
  intro h_move
  unfold moveLocal at h_move
  unfold copyLocal
  simp [h_move]
  -- locals'[0] = none, so copy fails
```

### Function Call Frames

**Frame Creation:**
```lean
def createFrame (args : List Value) (num_locals : Nat) : Frame :=
  { pc := 0
  , locals := args ++ List.replicate (num_locals - args.length) none
  , stack := []
  , gas := initial_gas
  , h_pc_bound := ...
  , h_locals_length := ...
  }
```

**Example: Function Call**
```move
public fun add(a: u64, b: u64): u64 {
    a + b
}

public fun caller() {
    let result = add(5, 10);
}
```

**Bytecode (caller):**
```
0: LdU64(5)
1: LdU64(10)
2: Call(add)
3: StLoc[0]    // result
```

**Frame Transition:**
```lean
-- Before Call(add):
caller_frame = {
  pc := 2,
  locals := [],
  stack := [10, 5],  -- Arguments on stack
  ...
}

-- After Call(add) - new frame created:
add_frame = {
  pc := 0,
  locals := [5, 10],  -- Arguments become locals
  stack := [],
  ...
}

-- After add returns:
caller_frame' = {
  pc := 3,
  locals := [],
  stack := [15],  -- Return value on stack
  ...
}
```

---

## Control Flow Instructions

### Branching

**Conditional Branch:**
```move
if (balance >= amount) {
    withdraw(amount);
} else {
    abort(INSUFFICIENT_BALANCE);
}
```

**Bytecode:**
```
0:  CopyLoc[0]      // balance
1:  CopyLoc[1]      // amount
2:  Ge              // balance >= amount
3:  BrFalse(7)      // If false, jump to PC 10
4:  CopyLoc[1]      // amount
5:  Call(withdraw)
6:  Branch(3)       // Jump to PC 10 (skip else)
7:  LdU64(1)        // INSUFFICIENT_BALANCE code
8:  Abort
9:  Ret
```

**Lean Model:**
```lean
theorem branch_behavior :
    frame.pc = 3 →
    frame.stack = [Value.Bool cond] →
    (cond = true → (step frame).pc = 4) ∧
    (cond = false → (step frame).pc = 10) := by
  intro h_pc h_stack
  constructor
  · intro h_cond
    unfold step
    simp [h_pc, h_stack, h_cond]
    -- BrFalse doesn't branch when cond = true
  · intro h_cond
    unfold step
    simp [h_pc, h_stack, h_cond]
    -- BrFalse branches to PC 3 + 7 = 10
```

### Loop Patterns

**While Loop:**
```move
while (i < n) {
    i = i + 1;
}
```

**Bytecode:**
```
// Loop header (PC 0)
0:  CopyLoc[0]      // i
1:  CopyLoc[1]      // n
2:  Lt
3:  BrFalse(6)      // Exit loop if i >= n

// Loop body (PC 4-6)
4:  CopyLoc[0]      // i
5:  LdU64(1)
6:  Add
7:  StLoc[0]        // i := i + 1

// Back edge (PC 8)
8:  Branch(-8)      // Jump back to PC 0

// Loop exit (PC 9)
9:  Ret
```

**Lean Verification Challenge:**
```lean
-- Loops require induction on fuel or iteration count
theorem loop_terminates (n : Nat) :
    ∃ fuel, run fuel initial_frame = some final_frame ∧
            final_frame.locals[0] = n := by
  -- Use induction on n
  induction n with
  | zero =>
    -- Base case: loop never executes
    exists 4
    simp [run, step]
  | succ n ih =>
    -- Inductive case: one more iteration
    obtain ⟨fuel', h_fuel'⟩ := ih
    exists fuel' + 9
    -- Prove loop executes n+1 times
    sorry  -- Complex induction
```

---

## Native Function Calls

### Native Function Interface

**Declaration in Move:**
```move
native fun verify_schnorr_proof(
    proof: SchnorrProof,
    public_key: PublicKey
): Option<Witness>;
```

**Bytecode:**
```
0:  CopyLoc[0]      // proof
1:  CopyLoc[1]      // public_key
2:  CallNative(verify_schnorr_proof)
3:  StLoc[2]        // result
```

**Rust Implementation:**
```rust
pub fn verify_schnorr_proof(
    proof: SchnorrProof,
    public_key: PublicKey,
    _context: &mut NativeContext
) -> NativeResult<Option<Witness>> {
    // Call into curve25519-dalek
    let commitment = proof.commitment;
    let challenge = proof.challenge;
    let response = proof.response;
    
    // Verify: g^response == commitment * pubkey^challenge
    if scalar_mult_base(response) == commitment + scalar_mult(public_key, challenge) {
        Ok(Some(Witness { /* ... */ }))
    } else {
        Ok(None)
    }
}
```

**Lean Axiomatization:**
```lean
-- Native functions are opaque
axiom verifySchnorrProof : SchnorrProof → PublicKey → Option Witness

-- Properties specified axiomatically
axiom verifySchnorrProof_sound :
  ∀ proof pk witness,
    verifySchnorrProof proof pk = some witness →
    SchnorrRelation proof pk witness

axiom verifySchnorrProof_complete :
  ∀ proof pk witness,
    SchnorrRelation proof pk witness →
    ∃ w, verifySchnorrProof proof pk = some w
```

### Gas Costs for Native Calls

**Gas Table:**
```lean
def nativeGasCost : NativeFunction → Nat
  | NativeFunction.VerifySchnorrProof => 1000
  | NativeFunction.SHA512 => 500
  | NativeFunction.Ristretto255Add => 100
  | NativeFunction.Ristretto255ScalarMult => 300
```

**Gas Accounting:**
```lean
theorem native_call_charges_gas :
    frame.gas = initial_gas →
    step frame = some frame' →
    frame.instruction = CallNative fn →
    frame'.gas = initial_gas - nativeGasCost fn := by
  intro h_gas h_step h_inst
  unfold step at h_step
  simp [h_inst, h_gas] at h_step
  -- Extract gas charge from step definition
```

---

## Resource Operations

### Global Storage Model

**Storage Structure:**
```lean
structure GlobalStorage where
  resources : Address → Type → Option Value
  h_type_safety : ∀ addr ty val,
    resources addr ty = some val →
    type_of val = ty
```

**Resource Operations:**
```lean
-- MoveTo: Store resource at address
def moveTo (storage : GlobalStorage) (addr : Address) (val : Value) :
    Option GlobalStorage :=
  if storage.resources addr (type_of val) = none then
    some { storage with
      resources := storage.resources.insert (addr, type_of val) val
    }
  else
    none  -- Resource already exists

-- MoveFrom: Remove resource from address
def moveFrom (storage : GlobalStorage) (addr : Address) (ty : Type) :
    Option (GlobalStorage × Value) :=
  match storage.resources addr ty with
  | some val =>
    let storage' := { storage with
      resources := storage.resources.remove (addr, ty)
    }
    some (storage', val)
  | none => none  -- Resource doesn't exist

-- BorrowGlobal: Create reference to resource
def borrowGlobal (storage : GlobalStorage) (addr : Address) (ty : Type) :
    Option Reference :=
  if storage.resources addr ty = some _ then
    some (Reference.Global addr ty [])
  else
    none
```

### Resource Safety

**Invariants:**
```lean
-- Each account has at most one instance of each type
axiom resource_uniqueness :
  ∀ storage addr ty val₁ val₂,
    storage.resources addr ty = some val₁ →
    storage.resources addr ty = some val₂ →
    val₁ = val₂

-- Resources can't be duplicated
theorem no_resource_duplication :
    moveFrom storage addr ty = some (storage', val) →
    storage'.resources addr ty = none := by
  intro h_move
  unfold moveFrom at h_move
  cases h : storage.resources addr ty
  · simp [h] at h_move
  · simp [h] at h_move
    obtain ⟨h_storage', h_val⟩ := h_move
    simp [h_storage']
```

---

## Gas Metering

### Gas Cost Model

**Base Costs:**
```lean
def instructionGasCost : Instruction → Nat
  | Instruction.LdU64 _ => 1
  | Instruction.LdU128 _ => 1
  | Instruction.Add => 1
  | Instruction.Mul => 1
  | Instruction.Div => 10          -- More expensive
  | Instruction.Call _ => 100      -- Function call overhead
  | Instruction.BorrowGlobal _ => 50
  | Instruction.MoveFrom _ => 100
  | Instruction.MoveTo _ => 100
```

**Dynamic Costs:**
```lean
-- Some operations have size-dependent costs
def vectorCost (op : VectorOp) (size : Nat) : Nat :=
  match op with
  | VectorOp.Push => 5 + size / 100       -- Amortized cost
  | VectorOp.Pop => 3
  | VectorOp.Swap => 1
  | VectorOp.Length => 1
```

### Gas Exhaustion

**Out of Gas:**
```lean
theorem out_of_gas_aborts :
    frame.gas < instructionGasCost instruction →
    step frame = none := by
  intro h_insufficient
  unfold step
  -- VM checks gas before executing
  simp [h_insufficient]
```

**Gas Limit Proof:**
```lean
-- Total gas consumed is bounded by initial gas
theorem gas_bounded :
    run fuel initial_frame = some final_frame →
    total_gas_consumed ≤ initial_frame.gas := by
  intro h_run
  induction fuel with
  | zero =>
    simp [run] at h_run
    -- No steps taken, no gas consumed
  | succ n ih =>
    simp [run] at h_run
    obtain ⟨frame', h_step, h_run'⟩ := h_run
    -- Gas decreases at each step
    have h_gas := step_consumes_gas h_step
    have h_ih := ih h_run'
    omega  -- Arithmetic
```

---

## Bytecode Verification Rules

### Type Safety Verification

**Bytecode Verifier Checks:**

1. **Stack Type Safety:**
   ```
   At each PC, verify:
   - Stack has expected types
   - Operations consume correct types
   - Operations produce correct types
   ```

2. **Local Type Safety:**
   ```
   At each PC, verify:
   - Locals are initialized before use
   - Locals have consistent types
   ```

3. **Control Flow Safety:**
   ```
   Verify:
   - Branch targets are valid PCs
   - All paths return or abort
   - No fall-through past last instruction
   ```

4. **Resource Safety:**
   ```
   Verify:
   - Resources not duplicated
   - References don't outlive referents
   - No dangling references
   ```

**Example: Type Checking `Add`**
```lean
-- Add requires two U64 values on stack
def typeCheckAdd (stack_types : List Type) : Bool :=
  match stack_types with
  | Type.U64 :: Type.U64 :: rest => true
  | _ => false

theorem add_type_check :
    typeCheckAdd frame.stack_types = true →
    ∃ frame', step { frame with instruction := Instruction.Add } = some frame' := by
  intro h_check
  unfold typeCheckAdd at h_check
  cases frame.stack_types
  · simp at h_check
  · cases frame.stack_types.tail
    · simp at h_check
    · cases frame.stack_types.head
      cases frame.stack_types.tail.head
      -- Both are U64
      exists new_frame
      unfold step
      simp
```

---

## Modeling Bytecode in Lean

### Instruction Representation

**Lean Encoding:**
```lean
inductive Instruction
  | LdU64 : Nat → Instruction
  | LdU128 : Nat → Instruction
  | CopyLoc : Nat → Instruction
  | MoveLoc : Nat → Instruction
  | StLoc : Nat → Instruction
  | Add : Instruction
  | Sub : Instruction
  | Mul : Instruction
  | Div : Instruction
  | Mod : Instruction
  | Eq : Instruction
  | Lt : Instruction
  | Gt : Instruction
  | BrTrue : Int → Instruction     -- Offset (can be negative)
  | BrFalse : Int → Instruction
  | Branch : Int → Instruction
  | Call : FunctionHandle → Instruction
  | CallNative : NativeFunction → Instruction
  | Ret : Instruction
  | Abort : Instruction
  -- ... (more instructions)

-- Function handle references another function
structure FunctionHandle where
  module : ModuleId
  name : String
  type_params : List Type
```

### Step Function Implementation

**Complete Step Function:**
```lean
def step (frame : Frame) : Option Frame :=
  if h : frame.pc < bytecode.length then
    let instruction := bytecode[frame.pc]
    
    -- Check gas
    if frame.gas < instructionGasCost instruction then
      none  -- Out of gas
    else
      let gas' := frame.gas - instructionGasCost instruction
      
      match instruction with
      | Instruction.LdU64 val =>
        some { frame with
          stack := Value.U64 val :: frame.stack,
          pc := frame.pc + 1,
          gas := gas'
        }
      
      | Instruction.Add =>
        match frame.stack with
        | Value.U64 rhs :: Value.U64 lhs :: rest =>
          if h : lhs + rhs < 2^64 then  -- Overflow check
            some { frame with
              stack := Value.U64 (lhs + rhs) :: rest,
              pc := frame.pc + 1,
              gas := gas'
            }
          else
            none  -- Arithmetic overflow
        | _ => none  -- Type error
      
      | Instruction.BrTrue offset =>
        match frame.stack with
        | Value.Bool true :: rest =>
          some { frame with
            stack := rest,
            pc := (frame.pc + offset).toNat,  -- Jump
            gas := gas'
          }
        | Value.Bool false :: rest =>
          some { frame with
            stack := rest,
            pc := frame.pc + 1,  -- Fall through
            gas := gas'
          }
        | _ => none  -- Type error
      
      | Instruction.CopyLoc idx =>
        match frame.locals[idx] with
        | some val =>
          some { frame with
            stack := val :: frame.stack,
            pc := frame.pc + 1,
            gas := gas'
          }
        | none => none  -- Uninitialized local
      
      | Instruction.CallNative fn =>
        -- Call native function (axiomatized)
        let (result, gas_native) := callNative fn frame.stack
        some { frame with
          stack := result :: drop_args frame.stack,
          pc := frame.pc + 1,
          gas := gas' - gas_native
        }
      
      -- ... (other instructions)
      
      | _ => sorry  -- TODO: implement remaining
  else
    none  -- PC out of bounds
```

### Bytecode Properties

**Determinism:**
```lean
theorem step_deterministic :
    step frame = some frame₁ →
    step frame = some frame₂ →
    frame₁ = frame₂ := by
  intro h₁ h₂
  rw [h₁] at h₂
  injection h₂
```

**Progress or Error:**
```lean
-- Execution either makes progress or errors deterministically
theorem step_total :
    ∀ frame, (∃ frame', step frame = some frame') ∨ step frame = none := by
  intro frame
  unfold step
  split
  · -- PC in bounds: analyze instruction
    cases bytecode[frame.pc]
    all_goals { simp; tauto }
  · -- PC out of bounds
    right
    rfl
```

---

## Bytecode Analysis Tools

### Disassembler

**Tool:**
```bash
# Disassemble compiled bytecode
aptos move disassemble --bytecode transfer.mv > transfer.disasm
```

**Output:**
```
public transfer(Arg0: &signer, Arg1: address, Arg2: u64) {
B0:
    0: CopyLoc[0](Arg0: &signer)
    1: Call signer::address_of(&signer): address
    2: BorrowGlobalMut[0](Balance)
    3: StLoc[3](sender_balance: &mut Balance)
    4: CopyLoc[3](sender_balance: &mut Balance)
    5: ImmBorrowField[0](Balance.value: u64)
    6: ReadRef
    7: CopyLoc[2](Arg2: u64)
    8: Sub
    9: CopyLoc[3](sender_balance: &mut Balance)
    10: MutBorrowField[0](Balance.value: u64)
    11: WriteRef
    ... (rest)
    23: Ret
}
```

### Bytecode Analyzer

**Script:**
```python
# analyze_bytecode.py

from move_binary import MoveBytecode

def analyze_control_flow(bytecode):
    """Build control flow graph"""
    cfg = {}
    for pc, instruction in enumerate(bytecode):
        successors = []
        
        if instruction.opcode in ['BrTrue', 'BrFalse']:
            # Branch: two successors
            successors = [pc + 1, pc + instruction.offset]
        elif instruction.opcode == 'Branch':
            # Unconditional: one successor
            successors = [pc + instruction.offset]
        elif instruction.opcode in ['Ret', 'Abort']:
            # Terminal: no successors
            successors = []
        else:
            # Fall-through: next instruction
            successors = [pc + 1]
        
        cfg[pc] = successors
    
    return cfg

def find_loops(cfg):
    """Detect loops in bytecode"""
    loops = []
    for pc, successors in cfg.items():
        for succ in successors:
            if succ <= pc:  # Back edge
                loops.append((succ, pc))
    return loops

def analyze_stack_depth(bytecode):
    """Compute maximum stack depth"""
    max_depth = 0
    current_depth = 0
    
    for instruction in bytecode:
        effect = stack_effect(instruction)
        current_depth += effect
        max_depth = max(max_depth, current_depth)
    
    return max_depth

# Usage
bytecode = MoveBytecode.from_file("transfer.mv")
cfg = analyze_control_flow(bytecode.functions['transfer'])
loops = find_loops(cfg)
stack_depth = analyze_stack_depth(bytecode.functions['transfer'])

print(f"Control Flow Graph: {cfg}")
print(f"Loops detected: {loops}")
print(f"Maximum stack depth: {stack_depth}")
```

### Bytecode-to-Lean Translator

**Automated Translation:**
```python
# bytecode_to_lean.py

def translate_instruction(pc, instruction):
    """Translate single instruction to Lean"""
    match instruction.opcode:
        case 'LdU64':
            return f"  , Instruction.LdU64 {instruction.value}"
        case 'Add':
            return f"  , Instruction.Add"
        case 'CopyLoc':
            return f"  , Instruction.CopyLoc {instruction.index}"
        case 'BrTrue':
            return f"  , Instruction.BrTrue {instruction.offset}"
        # ... (all opcodes)
    
def translate_function(function_bytecode):
    """Translate entire function to Lean"""
    lean_code = "def transferBytecode : List Instruction := [\n"
    
    for pc, instruction in enumerate(function_bytecode):
        lean_code += translate_instruction(pc, instruction) + "\n"
    
    lean_code += "  ]"
    return lean_code

# Generate Lean code
bytecode = MoveBytecode.from_file("transfer.mv")
lean_code = translate_function(bytecode.functions['transfer'])

with open("Transfer/Bytecode.lean", "w") as f:
    f.write(lean_code)

print("Lean bytecode model generated successfully")
```

---

## Cross-References

### Related Documentation

**Verification:**
- `PHASE_6_PC_CHAINING_DETAILED_TUTORIAL.md` - Using bytecode model in proofs
- `ADVANCED_LEAN_PROOF_TECHNIQUES_GUIDE.md` - Proof patterns for bytecode
- `BYTECODE_TRANSCRIPTION_GUIDE.md` - Manual transcription procedures

**Implementation:**
- `MSL_SPECIFICATION_PATTERNS_GUIDE.md` - High-level specifications
- `INTEGRATION_TESTING_AND_CROSS_LAYER_VALIDATION_GUIDE.md` - VM testing

**Performance:**
- `GAS_OPTIMIZATION_AND_COST_ANALYSIS.md` - Gas cost optimization
- `LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md` - Proof performance

### External Resources

**Move VM:**
- [Move Language Book](https://move-language.github.io/move/) - Official docs
- [Move VM Source](https://github.com/move-language/move/tree/main/language/move-vm) - Implementation
- [Bytecode Specification](https://github.com/move-language/move/blob/main/language/move-binary-format/src/file_format.rs)

**Verification:**
- [Isabelle/HOL Move Semantics](https://github.com/move-language/move/tree/main/language/move-prover) - Alternative formalization

---

## Maintenance

### Document Ownership

- **Author**: Verification team
- **Reviewers**: VM experts, Verification engineers
- **Approver**: Tech lead
- **Last Review**: 2026-04-22
- **Next Review**: 2026-07-22 (quarterly)

### Feedback

Questions about bytecode or VM execution?
- **VM questions**: vm-team@movementlabs.xyz
- **Verification questions**: verification-team@movementlabs.xyz
- **Lean modeling**: See ADVANCED_LEAN_PROOF_TECHNIQUES_GUIDE.md

---

**End of Guide**

Total pages: ~42 (~31K characters)
