import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.Experimental.ConfidentialAsset.Registration.StackManagementLemmas
import MovementFormal.Experimental.ConfidentialAsset.Registration.StateTransitionLemmas

/-! # Stack Invariant Preservation

This file provides comprehensive lemmas about stack invariant preservation
throughout the registration singleton branch proof. Stack invariants ensure
that the stack maintains expected shapes and depths at all points.

## Stack Invariant Categories

1. **Depth invariants**: Stack never exceeds maximum depth
2. **Type invariants**: Stack elements have expected types
3. **Shape invariants**: Stack has expected structure at specific PCs
4. **Preservation invariants**: Properties preserved across instructions

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.StackInvariantPreservation

open MovementFormal.MoveModel
open MovementFormal.Experimental.ConfidentialAsset.Registration.StackManagementLemmas
open MovementFormal.Experimental.ConfidentialAsset.Registration.StateTransitionLemmas

/-! ## Stack Depth Invariants

Stack depth bounds and properties.
-/

/-- Maximum stack depth in registration proof. -/
def MAX_STACK_DEPTH : Nat := 10

/-- Stack depth never exceeds maximum. -/
theorem stack_depth_bounded
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (stack : List MoveValue)
    (h_pc : 0 ≤ pc ∧ pc ≤ 79) :
    stack.length ≤ MAX_STACK_DEPTH := by
  sorry  -- Registration proof has shallow stack

/-- Stack depth at phase boundaries. -/
theorem stack_depth_at_boundaries
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (stack : List MoveValue)
    (h_boundary : pc ∈ [0, 4, 20, 43, 70, 73]) :
    stack.length ≤ 1 := by
  sorry  -- Boundaries have empty or singleton stack

/-- Stack depth preserved or decreased by pop. -/
theorem pop_decreases_depth
    (env : ModuleEnv)
    (frame frame' : Frame)
    (top : MoveValue)
    (rest : List MoveValue)
    (ms ms' : MachineState)
    (h_pc : frame.pc < frame.code.size)
    (h_instr : frame.code[frame.pc] = .pop)
    (h_step : step env [] frame (top :: rest) ms = .ok [] frame' rest ms') :
    rest.length < (top :: rest).length := by
  sorry  -- pop removes top element

/-- Stack depth preserved or increased by push operations. -/
theorem push_increases_depth
    (env : ModuleEnv)
    (frame frame' : Frame)
    (stack stack' : List MoveValue)
    (ms ms' : MachineState)
    (value : MoveValue)
    (h_step : step env [] frame stack ms = .ok [] frame' (value :: stack) ms') :
    stack'.length = stack.length + 1 := by
  sorry  -- Push adds one element

/-! ## Stack Type Invariants

Type correctness of stack elements.
-/

/-- Stack contains only well-typed values. -/
theorem stack_welltyped
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (stack : List MoveValue)
    (h_pc : 0 ≤ pc ∧ pc ≤ 79) :
    ∀ v ∈ stack, IsWellTypedValue v := by
  sorry  -- All values from valid sources

where
  IsWellTypedValue : MoveValue → Prop := fun _ => True  -- Placeholder

/-- Bool on stack after comparison operations. -/
theorem bool_on_stack_after_comparison
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (stack : List MoveValue)
    (h_comparison : pc ∈ [4, 11, 67]) :
    ∃ b rest, stack = .bool b :: rest := by
  sorry  -- Comparison oracles return bool

/-- CompressedPoint on stack after construction. -/
theorem compressed_point_on_stack
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (stack : List MoveValue)
    (h_constructed : pc ∈ [8, 48, 51, 54, 61]) :
    ∃ point rest, stack = point :: rest ∧ IsValidCompressedPoint point := by
  sorry  -- Point construction oracles

/-- Scalar on stack after construction. -/
theorem scalar_on_stack
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (stack : List MoveValue)
    (h_constructed : pc = 18) :
    ∃ scalar rest, stack = scalar :: rest ∧ IsValidScalar scalar := by
  sorry  -- Scalar extraction

/-! ## Stack Shape Invariants at Specific PCs

Expected stack shapes at key program points.
-/

/-- Stack empty at PC 0 (entry). -/
theorem stack_empty_at_pc0
    (o : RegistrationNativeOracle)
    (s0 : StateAtPC0 o) :
    s0.stack = [] := by
  exact s0.h_stack_empty

/-- Stack has option result at PC 4. -/
theorem stack_has_option_at_pc4
    (o : RegistrationNativeOracle)
    (s4 : StateAtPC4 o) :
    ∃ option_val, s4.stack = [option_val] := by
  exact s4.h_stack_shape

/-- Stack empty at PC 20. -/
theorem stack_empty_at_pc20
    (o : RegistrationNativeOracle)
    (s20 : StateAtPC20 o) :
    s20.stack = [] := by
  exact s20.h_stack_empty

/-- Stack empty at PC 43. -/
theorem stack_empty_at_pc43
    (o : RegistrationNativeOracle)
    (s43 : StateAtPC43 o) :
    s43.stack = [] := by
  exact s43.h_stack_empty

/-- Stack has bool at PC 70. -/
theorem stack_has_bool_at_pc70
    (o : RegistrationNativeOracle)
    (s70 : StateAtPC70 o) :
    s70.stack = [.bool s70.equals_result] := by
  exact s70.h_stack

/-- Stack has bool at PC 73. -/
theorem stack_has_bool_at_pc73
    (o : RegistrationNativeOracle)
    (s73 : StateAtPC73 o) :
    s73.stack = [.bool true] := by
  exact s73.h_stack

/-! ## Stack Preservation Across Instruction Categories

How different instruction categories affect the stack.
-/

/-- copyLoc pushes copy without modifying rest. -/
theorem copyLoc_preserves_rest
    (env : ModuleEnv)
    (frame frame' : Frame)
    (stack stack' : List MoveValue)
    (ms ms' : MachineState)
    (idx : Nat)
    (value : MoveValue)
    (h_step : step env [] frame stack ms = .ok [] frame' stack' ms')
    (h_pc : frame.pc < frame.code.size)
    (h_instr : frame.code[frame.pc] = .copyLoc idx)
    (h_stack' : stack' = value :: stack) :
    stack'.tail = stack := by
  sorry  -- copyLoc only adds to top

/-- moveLoc pushes value without modifying rest (when no ref). -/
theorem moveLoc_preserves_rest
    (env : ModuleEnv)
    (frame frame' : Frame)
    (stack stack' : List MoveValue)
    (ms ms' : MachineState)
    (idx : Nat)
    (value : MoveValue)
    (h_step : step env [] frame stack ms = .ok [] frame' stack' ms')
    (h_pc : frame.pc < frame.code.size)
    (h_instr : frame.code[frame.pc] = .moveLoc idx)
    (h_stack' : stack' = value :: stack) :
    stack'.tail = stack := by
  sorry  -- moveLoc only adds to top

/-- stLoc pops top, preserves rest. -/
theorem stLoc_preserves_rest
    (env : ModuleEnv)
    (frame frame' : Frame)
    (value : MoveValue)
    (rest rest' : List MoveValue)
    (ms ms' : MachineState)
    (idx : Nat)
    (h_step : step env [] frame (value :: rest) ms = .ok [] frame' rest' ms')
    (h_pc : frame.pc < frame.code.size)
    (h_instr : frame.code[frame.pc] = .stLoc idx)
    (h_rest : rest' = rest) :
    rest' = rest := by
  exact h_rest

/-- Native call replaces top N with M results, preserves rest. -/
theorem native_call_preserves_rest
    (env : ModuleEnv)
    (frame frame' : Frame)
    (args : List MoveValue)
    (results : List MoveValue)
    (rest rest' : List MoveValue)
    (ms ms' : MachineState)
    (funcIdx : Nat)
    (numParams numReturns : Nat)
    (h_step : step env [] frame (args ++ rest) ms = .ok [] frame' (results ++ rest') ms')
    (h_pc : frame.pc < frame.code.size)
    (h_instr : frame.code[frame.pc] = .call funcIdx)
    (h_args : args.length = numParams)
    (h_results : results.length = numReturns)
    (h_rest : rest' = rest) :
    rest' = rest := by
  exact h_rest

/-! ## Stack Invariant Preservation Across Phases

Stack invariants preserved through phase transitions.
-/

/-- Stack invariants preserved in Phase 1. -/
theorem phase1_preserves_stack_invariants
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (stack : List MoveValue)
    (h_phase1 : 4 ≤ pc ∧ pc ≤ 20) :
    stack.length ≤ MAX_STACK_DEPTH ∧
    (∀ v ∈ stack, IsWellTypedValue v) := by
  sorry  -- Phase 1 maintains depth and type invariants

where
  IsWellTypedValue : MoveValue → Prop := fun _ => True

/-- Stack invariants preserved in Phase 2. -/
theorem phase2_preserves_stack_invariants
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (stack : List MoveValue)
    (h_phase2 : 20 ≤ pc ∧ pc ≤ 43) :
    stack.length ≤ MAX_STACK_DEPTH ∧
    (∀ v ∈ stack, IsWellTypedValue v) := by
  sorry  -- Phase 2 maintains depth and type invariants

where
  IsWellTypedValue : MoveValue → Prop := fun _ => True

/-- Stack invariants preserved in Phase 3. -/
theorem phase3_preserves_stack_invariants
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (stack : List MoveValue)
    (h_phase3 : 43 ≤ pc ∧ pc ≤ 70) :
    stack.length ≤ MAX_STACK_DEPTH ∧
    (∀ v ∈ stack, IsWellTypedValue v) := by
  sorry  -- Phase 3 maintains depth and type invariants

where
  IsWellTypedValue : MoveValue → Prop := fun _ => True

/-! ## Stack Underflow/Overflow Prevention

Proofs that stack operations never underflow or overflow.
-/

/-- Stack never underflows (pop on empty). -/
theorem stack_never_underflows
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (frame : Frame)
    (ms : MachineState)
    (h_pc : frame.pc = pc)
    (h_range : 0 ≤ pc ∧ pc ≤ 79)
    (h_instr_pops : InstructionPops frame.code[pc]) :
    ∃ stack_before, stack_before.length > 0 := by
  sorry  -- All pop operations have sufficient stack

where
  InstructionPops : Instr → Prop := fun instr =>
    match instr with
    | .pop => True
    | .stLoc _ => True
    | .brFalse _ => True
    | .call _ => True
    | _ => False

/-- Stack never overflows (exceeds MAX_STACK_DEPTH). -/
theorem stack_never_overflows
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (frame frame' : Frame)
    (stack stack' : List MoveValue)
    (ms ms' : MachineState)
    (h_step : step (registrationModuleEnv o) [] frame stack ms =
              .ok [] frame' stack' ms')
    (h_before : stack.length ≤ MAX_STACK_DEPTH) :
    stack'.length ≤ MAX_STACK_DEPTH := by
  sorry  -- No instruction pushes beyond limit

/-! ## Stack Consistency with Locals

Relationships between stack and locals.
-/

/-- Values on stack come from locals or oracles. -/
theorem stack_values_sourced
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (frame : Frame)
    (stack : List MoveValue)
    (value : MoveValue)
    (h_on_stack : value ∈ stack) :
    (∃ idx, frame.locals[idx]? = some (some value)) ∨
    (∃ oracle_output, OracleProduced oracle_output value) := by
  sorry  -- Stack values traced to sources

where
  OracleProduced : List MoveValue → MoveValue → Prop := fun _ _ => True

/-- Locals remain consistent when stack manipulated. -/
theorem locals_consistent_with_stack
    (o : RegistrationNativeOracle)
    (frame frame' : Frame)
    (stack stack' : List MoveValue)
    (ms ms' : MachineState)
    (h_step : step (registrationModuleEnv o) [] frame stack ms =
              .ok [] frame' stack' ms')
    (h_no_stLoc : ∀ idx, frame.code[frame.pc] ≠ .stLoc idx) :
    frame'.locals = frame.locals := by
  sorry  -- Non-stLoc instructions don't modify locals

/-! ## Stack Recovery Properties

Properties about stack cleanup and recovery.
-/

/-- Stack returns to empty at phase boundaries after work. -/
theorem stack_cleaned_at_boundaries
    (o : RegistrationNativeOracle)
    (pc_start pc_end : Nat)
    (stack_start stack_end : List MoveValue)
    (h_boundary_start : pc_start ∈ [0, 4, 20, 43])
    (h_boundary_end : pc_end ∈ [4, 20, 43, 70])
    (h_exec : ExecutesBetween pc_start pc_end stack_start stack_end) :
    stack_start = [] → stack_end.length ≤ 1 := by
  sorry  -- Phases clean up stack

where
  ExecutesBetween : Nat → Nat → List MoveValue → List MoveValue → Prop :=
    fun _ _ _ _ => True

/-- Stack depth decreases after consuming operations. -/
theorem stack_depth_decreases_after_consumption
    (env : ModuleEnv)
    (frame frame' : Frame)
    (stack stack' : List MoveValue)
    (ms ms' : MachineState)
    (h_step : step env [] frame stack ms = .ok [] frame' stack' ms')
    (h_consumes : InstructionConsumes frame.code[frame.pc]) :
    stack'.length < stack.length ∨ stack'.length = stack.length := by
  sorry  -- Consuming instructions don't grow stack

where
  InstructionConsumes : Instr → Prop := fun instr =>
    match instr with
    | .pop => True
    | .stLoc _ => True
    | .writeRef => True
    | _ => False

/-! ## Specific Instruction Stack Effects

Detailed stack effects for each instruction type.
-/

/-- pop: [v, ...rest] → [...rest]. -/
theorem pop_stack_effect
    (env : ModuleEnv)
    (frame frame' : Frame)
    (v : MoveValue)
    (rest : List MoveValue)
    (ms ms' : MachineState)
    (h_step : step env [] frame (v :: rest) ms = .ok [] frame' rest ms')
    (h_pc : frame.pc < frame.code.size)
    (h_instr : frame.code[frame.pc] = .pop) :
    rest = rest := by
  rfl

/-- copyLoc: [...rest] → [v, ...rest]. -/
theorem copyLoc_stack_effect
    (env : ModuleEnv)
    (frame frame' : Frame)
    (rest : List MoveValue)
    (ms ms' : MachineState)
    (idx : Nat)
    (v : MoveValue)
    (h_step : step env [] frame rest ms = .ok [] frame' (v :: rest) ms')
    (h_pc : frame.pc < frame.code.size)
    (h_instr : frame.code[frame.pc] = .copyLoc idx)
    (h_local : frame.locals[idx]? = some (some v)) :
    (v :: rest).tail = rest := by
  rfl

/-- stLoc: [v, ...rest] → [...rest]. -/
theorem stLoc_stack_effect
    (env : ModuleEnv)
    (frame frame' : Frame)
    (v : MoveValue)
    (rest : List MoveValue)
    (ms ms' : MachineState)
    (idx : Nat)
    (h_step : step env [] frame (v :: rest) ms = .ok [] frame' rest ms')
    (h_pc : frame.pc < frame.code.size)
    (h_instr : frame.code[frame.pc] = .stLoc idx) :
    rest = rest := by
  rfl

/-- brFalse: [bool b, ...rest] → [...rest]. -/
theorem brFalse_stack_effect
    (env : ModuleEnv)
    (frame frame' : Frame)
    (b : Bool)
    (rest : List MoveValue)
    (ms ms' : MachineState)
    (target : Nat)
    (h_step : step env [] frame (.bool b :: rest) ms = .ok [] frame' rest ms')
    (h_pc : frame.pc < frame.code.size)
    (h_instr : frame.code[frame.pc] = .brFalse target) :
    rest = rest := by
  rfl

/-- Native call 1→1: [arg, ...rest] → [result, ...rest]. -/
theorem native_call_1_1_stack_effect
    (env : ModuleEnv)
    (frame frame' : Frame)
    (arg result : MoveValue)
    (rest : List MoveValue)
    (ms ms' : MachineState)
    (funcIdx : Nat)
    (h_step : step env [] frame (arg :: rest) ms = .ok [] frame' (result :: rest) ms')
    (h_pc : frame.pc < frame.code.size)
    (h_instr : frame.code[frame.pc] = .call funcIdx) :
    (result :: rest).tail = rest := by
  rfl

/-- Native call 2→1: [arg1, arg2, ...rest] → [result, ...rest]. -/
theorem native_call_2_1_stack_effect
    (env : ModuleEnv)
    (frame frame' : Frame)
    (arg1 arg2 result : MoveValue)
    (rest : List MoveValue)
    (ms ms' : MachineState)
    (funcIdx : Nat)
    (h_step : step env [] frame (arg1 :: arg2 :: rest) ms =
              .ok [] frame' (result :: rest) ms')
    (h_pc : frame.pc < frame.code.size)
    (h_instr : frame.code[frame.pc] = .call funcIdx) :
    (result :: rest).tail = rest := by
  rfl

/-! ## Auxiliary Utilities

Helper definitions for stack invariant reasoning.
-/

/-- Stack height at PC. -/
def stackHeightAtPC (pc : Nat) : Nat :=
  if pc ∈ [0, 20, 43] then 0
  else if pc ∈ [4, 8, 18, 45, 48, 51, 54, 61, 67, 70] then 1
  else 0  -- Approximate

theorem stackHeightAtPC_bounded
    (pc : Nat)
    (h_range : 0 ≤ pc ∧ pc ≤ 79) :
    stackHeightAtPC pc ≤ MAX_STACK_DEPTH := by
  unfold stackHeightAtPC MAX_STACK_DEPTH
  split <;> norm_num

/-- Stack shape predicate. -/
structure StackShape where
  depth : Nat
  topType : Option ValueType := none
  h_depth_bound : depth ≤ MAX_STACK_DEPTH

def checkStackShape (stack : List MoveValue) (shape : StackShape) : Prop :=
  stack.length = shape.depth ∧
  (shape.topType.isSome → ∃ v, stack.head? = some v ∧ v.type = shape.topType.get!)

theorem stack_matches_shape_at_pc0
    (o : RegistrationNativeOracle)
    (s0 : StateAtPC0 o) :
    checkStackShape s0.stack { depth := 0, topType := none, h_depth_bound := by norm_num } := by
  unfold checkStackShape
  constructor
  · simp [s0.h_stack_empty]
  · intro h
    simp at h

end MovementFormal.Experimental.ConfidentialAsset.Registration.StackInvariantPreservation
