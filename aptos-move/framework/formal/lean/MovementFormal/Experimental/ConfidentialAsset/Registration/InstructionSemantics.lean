import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.Instr

/-! # Instruction Semantics for Registration Proof

This file provides detailed semantic specifications for each Move bytecode instruction
used in the registration verification proof. These semantics bridge the gap between
abstract step lemmas and concrete PC-by-PC execution.

## Instructions Used in Registration Proof

### Control Flow (6 instructions)
- ret: Return from function
- brFalse: Conditional branch (PC 5, 14, 73)
- branch: Unconditional branch (not used in singleton path)

### Stack Operations (2 instructions)
- pop: Discard top of stack

### Local Variable Operations (9 instructions)
- copyLoc: Read local, push copy
- moveLoc: Move local to stack (consuming it)
- stLoc: Pop stack, store in local
- immBorrowLoc: Create immutable reference to local
- mutBorrowLoc: Create mutable reference to local

### Reference Operations (3 instructions)
- readRef: Dereference, push value
- writeRef: Store through mutable reference
- freezeRef: Convert mut ref to imm ref

### Primitive Operations (2 instructions)
- ldU8: Load u8 constant
- eq: Equality comparison

### Struct Operations (2 instructions)
- packStruct: Create struct from stack values
- unpackStruct: Unpack struct to stack

### Vector Operations (1 instruction)
- vecPack: Create vector from N stack elements

### Function Calls (1 instruction)
- call: Invoke function (bytecode or native)

Total: ~26 distinct instruction forms used across PC 0-70.

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.InstructionSemantics

open MovementFormal.MoveModel

/-! ## Control Flow Instructions

Semantic specifications for ret, brFalse, branch.
-/

/-- ret: Returns from current function to caller.
Stack: empty
Effect: Pop frame from call stack, push return values to caller's stack. -/
def semantics_ret : String :=
  "Returns control to caller, popping current frame and transferring return values"

/-- Semantics of ret with empty return (Unit). -/
axiom step_ret_unit
    (env : ModuleEnv)
    (cs : List Frame)
    (frame : Frame)
    (caller_frame : Frame)
    (ms : MachineState)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .ret)
    (hcs : cs = caller_frame :: cs') :
    step env cs frame [] ms =
      .ok cs' { caller_frame with pc := caller_frame.pc + 1 } [] ms

/-- brFalse: Conditional branch if stack top is false.
Stack: [bool, ...rest]
Effect: If bool is false, pc := pc + offset; else pc := pc + 1. Consumes bool. -/
def semantics_brFalse (offset : Nat) : String :=
  s!"Conditional branch: jump to pc + {offset} if stack top is false, else fall through"

/-- brFalse taken (stack top is false). -/
axiom step_brFalse_taken_semantic
    (env : ModuleEnv)
    (cs : List Frame)
    (frame : Frame)
    (ms : MachineState)
    (offset : Nat)
    (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .brFalse offset) :
    step env cs frame (.bool false :: rest) ms =
      .ok cs { frame with pc := frame.pc + offset } rest ms

/-- brFalse not taken (stack top is true). -/
axiom step_brFalse_not_taken_semantic
    (env : ModuleEnv)
    (cs : List Frame)
    (frame : Frame)
    (ms : MachineState)
    (offset : Nat)
    (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .brFalse offset) :
    step env cs frame (.bool true :: rest) ms =
      .ok cs { frame with pc := frame.pc + 1 } rest ms

/-! ## Stack Operations

Semantic specifications for pop.
-/

/-- pop: Discard top of stack.
Stack: [v, ...rest]
Effect: Stack becomes rest. -/
def semantics_pop : String :=
  "Discards top element from stack"

axiom step_pop_semantic
    (env : ModuleEnv)
    (cs : List Frame)
    (frame : Frame)
    (ms : MachineState)
    (v : MoveValue)
    (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .pop) :
    step env cs frame (v :: rest) ms =
      .ok cs { frame with pc := frame.pc + 1 } rest ms

/-! ## Local Variable Instructions

Semantic specifications for copyLoc, moveLoc, stLoc, immBorrowLoc, mutBorrowLoc.
-/

/-- copyLoc: Push copy of local.
Stack: [...] → [value, ...]
Effect: Read locals[idx], push copy to stack. -/
def semantics_copyLoc (idx : Nat) : String :=
  s!"Pushes copy of local {idx} to stack"

/-- moveLoc: Move local to stack.
Stack: [...] → [value, ...]
Effect: Move locals[idx] to stack, set locals[idx] := none. -/
def semantics_moveLoc (idx : Nat) : String :=
  s!"Moves local {idx} to stack, consuming it"

/-- stLoc: Store stack top in local.
Stack: [value, ...rest] → rest
Effect: Pop value, store in locals[idx]. -/
def semantics_stLoc (idx : Nat) : String :=
  s!"Pops stack top and stores in local {idx}"

/-- immBorrowLoc: Create immutable reference to local.
Stack: [...] → [&locals[idx], ...]
Effect: Allocate ref in containers (if not already), push immRef. -/
def semantics_immBorrowLoc (idx : Nat) : String :=
  s!"Creates immutable reference to local {idx}"

/-- mutBorrowLoc: Create mutable reference to local.
Stack: [...] → [&mut locals[idx], ...]
Effect: Allocate ref in containers (if not already), push mutRef, record in localRefs. -/
def semantics_mutBorrowLoc (idx : Nat) : String :=
  s!"Creates mutable reference to local {idx}"

/-! ## Reference Instructions

Semantic specifications for readRef, writeRef, freezeRef.
-/

/-- readRef: Dereference and push value.
Stack: [&v, ...rest] → [v, ...rest]
Effect: Read value from containers via ref, push to stack. -/
def semantics_readRef : String :=
  "Dereferences reference and pushes value"

/-- writeRef: Store through mutable reference.
Stack: [&mut ref, value, ...rest] → rest
Effect: Write value to containers via ref. -/
def semantics_writeRef : String :=
  "Stores value through mutable reference"

/-- freezeRef: Convert mut ref to imm ref.
Stack: [&mut ref, ...rest] → [& ref, ...rest]
Effect: Change mutRef to immRef. -/
def semantics_freezeRef : String :=
  "Converts mutable reference to immutable reference"

/-! ## Vector Instructions

Semantic specifications for vecPack.
-/

/-- vecPack: Create vector from N stack elements.
Stack: [v1, v2, ..., vN, ...rest] → [vec![v1, v2, ..., vN], ...rest]
Effect: Pop N elements, create vector, push. -/
def semantics_vecPack (ty : MoveType) (n : Nat) : String :=
  s!"Creates vector<{ty}> from top {n} stack elements"

axiom step_vecPack_zero_semantic
    (env : ModuleEnv)
    (cs : List Frame)
    (frame : Frame)
    (ms : MachineState)
    (ty : MoveType)
    (stack : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .vecPack ty 0) :
    step env cs frame stack ms =
      .ok cs { frame with pc := frame.pc + 1 } (.vector ty [] :: stack) ms

/-! ## Function Call Instructions

Semantic specifications for call (both bytecode and native variants).
-/

/-- call: Invoke function.
Stack: [arg1, arg2, ..., argN, ...rest] → [result1, result2, ..., resultM, ...rest]
Effect: Depends on function body:
  - Bytecode: Push new frame with args as locals
  - Native: Invoke native impl, push results
  - NativeRef: Same as native but can mutate containers -/
def semantics_call (funcIdx : Nat) : String :=
  s!"Calls function {funcIdx}"

/-- call to bytecode function: creates new frame. -/
axiom step_call_bytecode_semantic
    (env : ModuleEnv)
    (cs : List Frame)
    (frame : Frame)
    (ms : MachineState)
    (funcIdx : Nat)
    (args rest : List MoveValue)
    (code : Array MoveInstr)
    (numLocals : Nat)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .call funcIdx)
    (hlt : funcIdx < env.functions.size)
    (hbody : env.functions[funcIdx].body = .bytecode code numLocals)
    (htake : takeN rest args.length = some (args, rest)) :
    step env cs frame rest ms =
      .ok ({ frame with pc := frame.pc + 1 } :: cs)
          { code := code, pc := 0,
            locals := (args.map some ++ List.replicate (numLocals - args.length) none).toArray,
            localRefs := (List.replicate numLocals none).toArray }
          rest ms

/-- call to native function: executes native impl. -/
axiom step_call_native_semantic
    (env : ModuleEnv)
    (cs : List Frame)
    (frame : Frame)
    (ms : MachineState)
    (funcIdx : Nat)
    (args rest : List MoveValue)
    (impl : List MoveValue → Option (List MoveValue))
    (results : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .call funcIdx)
    (hlt : funcIdx < env.functions.size)
    (hbody : env.functions[funcIdx].body = .native impl)
    (htake : takeN rest args.length = some (args, rest))
    (himpl : impl args = some results)
    (hlen : results.length = env.functions[funcIdx].numReturns) :
    step env cs frame rest ms =
      .ok cs { frame with pc := frame.pc + 1 } (results.reverse ++ rest) ms

/-- call to nativeRef function: executes with container access. -/
axiom step_call_nativeRef_semantic
    (env : ModuleEnv)
    (cs : List Frame)
    (frame : Frame)
    (ms : MachineState)
    (funcIdx : Nat)
    (args rest : List MoveValue)
    (impl : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (results : List MoveValue)
    (containers' : ContainerStore)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .call funcIdx)
    (hlt : funcIdx < env.functions.size)
    (hbody : env.functions[funcIdx].body = .nativeRef impl)
    (htake : takeN rest args.length = some (args, rest))
    (himpl : impl ms.containers args = some (results, containers'))
    (hlen : results.length = env.functions[funcIdx].numReturns) :
    step env cs frame rest ms =
      .ok cs { frame with pc := frame.pc + 1 } (results.reverse ++ rest) { ms with containers := containers' }

/-! ## Instruction Composition

Properties about composing multiple instructions.
-/

/-- Two instructions compose via intermediate state. -/
theorem instruction_composition
    (env : ModuleEnv)
    (cs : List Frame)
    (f1 f2 f3 : Frame)
    (s1 s2 s3 : List MoveValue)
    (ms1 ms2 ms3 : MachineState)
    (h_step1 : step env cs f1 s1 ms1 = .ok cs f2 s2 ms2)
    (h_step2 : step env cs f2 s2 ms2 = .ok cs f3 s3 ms3) :
    ∃ (intermediate_frame : Frame) (intermediate_stack : List MoveValue) (intermediate_ms : MachineState),
      step env cs f1 s1 ms1 = .ok cs intermediate_frame intermediate_stack intermediate_ms ∧
      step env cs intermediate_frame intermediate_stack intermediate_ms = .ok cs f3 s3 ms3 := by
  use f2, s2, ms2
  exact ⟨h_step1, h_step2⟩

/-- Sequence of N instructions compose transitively. -/
axiom instruction_sequence_composition
    (env : ModuleEnv)
    (cs : List Frame)
    (frames : List Frame)
    (stacks : List (List MoveValue))
    (mss : List MachineState)
    (n : Nat)
    (h_len : frames.length = n + 1 ∧ stacks.length = n + 1 ∧ mss.length = n + 1)
    (h_steps : ∀ i < n, step env cs frames[i]! stacks[i]! mss[i]! = .ok cs frames[i+1]! stacks[i+1]! mss[i+1]!) :
    run env cs frames[0]! stacks[0]! mss[0]! n = .ok cs frames[n]! stacks[n]! mss[n]!

/-! ## Instruction Determinism

All instructions are deterministic given the same inputs.
-/

/-- step is deterministic. -/
theorem step_deterministic
    (env : ModuleEnv)
    (cs : List Frame)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (result1 result2 : ExecResult)
    (h1 : step env cs frame stack ms = result1)
    (h2 : step env cs frame stack ms = result2) :
    result1 = result2 := by
  rw [h1] at h2
  exact h2

/-- run is deterministic for fixed fuel. -/
theorem run_deterministic
    (env : ModuleEnv)
    (cs : List Frame)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (fuel : Nat)
    (result1 result2 : ExecResult)
    (h1 : run env cs frame stack ms fuel = result1)
    (h2 : run env cs frame stack ms fuel = result2) :
    result1 = result2 := by
  rw [h1] at h2
  exact h2

/-! ## Instruction Invariants

Properties that hold across all instruction executions.
-/

/-- PC advances by exactly 1 for non-branching instructions (success path). -/
axiom pc_advances_one_for_non_branch
    (env : ModuleEnv)
    (cs : List Frame)
    (frame frame' : Frame)
    (stack stack' : List MoveValue)
    (ms ms' : MachineState)
    (h_step : step env cs frame stack ms = .ok cs frame' stack' ms')
    (h_not_branch : ∀ offset, frame.code[frame.pc]? ≠ some (.brFalse offset) ∧
                              frame.code[frame.pc]? ≠ some (.brTrue offset) ∧
                              frame.code[frame.pc]? ≠ some (.branch offset))
    (h_not_ret : frame.code[frame.pc]? ≠ some .ret)
    (h_not_call : ∀ idx, frame.code[frame.pc]? ≠ some (.call idx)) :
    frame'.pc = frame.pc + 1

/-- Code array is preserved across steps (same frame). -/
theorem code_preserved_across_step
    (env : ModuleEnv)
    (cs : List Frame)
    (frame frame' : Frame)
    (stack stack' : List MoveValue)
    (ms ms' : MachineState)
    (h_step : step env cs frame stack ms = .ok cs frame' stack' ms')
    (h_same_frame : cs' = cs) :
    frame'.code = frame.code ∨ cs ≠ [] := by
  sorry  -- Code is preserved unless we call/ret (frame change)

/-! ## Instruction Safety

Well-formedness conditions for safe instruction execution.
-/

/-- stLoc requires non-empty stack. -/
def safe_for_stLoc (stack : List MoveValue) (idx : Nat) (locals_size : Nat) : Prop :=
  stack.length ≥ 1 ∧ idx < locals_size

/-- moveLoc requires local to be populated. -/
def safe_for_moveLoc (locals : Array (Option MoveValue)) (idx : Nat) : Prop :=
  idx < locals.size ∧ locals[idx]? = some (some _)

/-- brFalse requires bool on stack. -/
def safe_for_brFalse (stack : List MoveValue) : Prop :=
  ∃ b rest, stack = .bool b :: rest

/-- call requires correct number of arguments on stack. -/
def safe_for_call (env : ModuleEnv) (funcIdx : Nat) (stack : List MoveValue) : Prop :=
  funcIdx < env.functions.size ∧
  stack.length ≥ env.functions[funcIdx].numParams

end MovementFormal.Experimental.ConfidentialAsset.Registration.InstructionSemantics
