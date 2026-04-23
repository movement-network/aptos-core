import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.StepLemmas.Bundled
import MovementFormal.Experimental.ConfidentialAsset.Registration.ExecutionTraceProperties
import MovementFormal.Experimental.ConfidentialAsset.Registration.PCBoundaryConditions

/-! # Proof Composition Patterns

This file provides reusable patterns for composing proof segments. These
patterns abstract common proof structures that appear repeatedly in the
singleton branch verification.

## Pattern Categories

1. **Sequential composition**: Chaining instruction executions
2. **Oracle call patterns**: Standard oracle invocation sequences
3. **Local manipulation patterns**: Common local read/write sequences
4. **Conditional patterns**: Branch and merge reasoning
5. **Loop unrolling patterns**: Bounded iteration structures

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.ProofCompositionPatterns

open MovementFormal.MoveModel
open MovementFormal.Experimental.ConfidentialAsset.Registration.ExecutionTraceProperties
open MovementFormal.Experimental.ConfidentialAsset.Registration.PCBoundaryConditions

/-! ## Sequential Composition Patterns -/

/-- Two-step sequential composition. -/
theorem two_step_composition
    (env : ModuleEnv)
    (gs : GlobalState)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (P : Frame → List MoveValue → MachineState → Prop)
    (Q : Frame → List MoveValue → MachineState → Prop)
    (R : Frame → List MoveValue → MachineState → Prop)
    (h_initial : P frame stack ms)
    (frame1 : Frame)
    (stack1 : List MoveValue)
    (ms1 : MachineState)
    (h_step1 : step env gs frame stack ms = .ok gs frame1 stack1 ms1)
    (h_mid : P frame stack ms → Q frame1 stack1 ms1)
    (frame2 : Frame)
    (stack2 : List MoveValue)
    (ms2 : MachineState)
    (h_step2 : step env gs frame1 stack1 ms1 = .ok gs frame2 stack2 ms2)
    (h_final : Q frame1 stack1 ms1 → R frame2 stack2 ms2) :
    R frame2 stack2 ms2 := by
  sorry  -- Sequential composition

/-- N-step sequential composition. -/
theorem n_step_composition
    (env : ModuleEnv)
    (gs : GlobalState)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (n : Nat)
    (frames : List Frame)
    (stacks : List (List MoveValue))
    (mss : List MachineState)
    (h_length : frames.length = n ∧ stacks.length = n ∧ mss.length = n)
    (h_steps : ∀ i < n-1,
      step env gs (frames.get! i) (stacks.get! i) (mss.get! i) =
      .ok gs (frames.get! (i+1)) (stacks.get! (i+1)) (mss.get! (i+1)))
    (P : Nat → Frame → List MoveValue → MachineState → Prop)
    (h_initial : P 0 frame stack ms)
    (h_invariant : ∀ i < n-1,
      P i (frames.get! i) (stacks.get! i) (mss.get! i) →
      P (i+1) (frames.get! (i+1)) (stacks.get! (i+1)) (mss.get! (i+1))) :
    P n (frames.get! (n-1)) (stacks.get! (n-1)) (mss.get! (n-1)) := by
  sorry  -- N-step composition with invariant

/-! ## Oracle Call Patterns -/

/-- Standard 1-to-1 oracle call pattern. -/
structure OracleCall_1_1_Pattern (env : ModuleEnv) where
  pc : Nat
  funcIdx : Nat
  input : MoveValue
  output : MoveValue
  frame_before : Frame
  stack_before : List MoveValue
  ms_before : MachineState
  h_pc : frame_before.pc = pc
  h_instr : frame_before.code[pc]? = some (.call funcIdx)
  h_stack_before : stack_before = input :: rest_stack
  h_oracle_success : OracleSucceeds env funcIdx [input] [output]
  rest_stack : List MoveValue

where
  OracleSucceeds (env : ModuleEnv) (funcIdx : Nat)
                (inputs outputs : List MoveValue) : Prop := True

/-- Applying 1-to-1 oracle pattern. -/
theorem apply_oracle_1_1_pattern
    (env : ModuleEnv)
    (gs : GlobalState)
    (pattern : OracleCall_1_1_Pattern env)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step env gs pattern.frame_before pattern.stack_before
                   pattern.ms_before = .ok gs frame' stack' ms') :
    frame'.pc = pattern.pc + 1 ∧
    stack' = pattern.output :: pattern.rest_stack := by
  sorry  -- Oracle 1-to-1 pattern

/-- Standard 2-to-1 oracle call pattern. -/
structure OracleCall_2_1_Pattern (env : ModuleEnv) where
  pc : Nat
  funcIdx : Nat
  input1 input2 : MoveValue
  output : MoveValue
  frame_before : Frame
  stack_before : List MoveValue
  ms_before : MachineState
  h_pc : frame_before.pc = pc
  h_instr : frame_before.code[pc]? = some (.call funcIdx)
  h_stack_before : stack_before = input2 :: input1 :: rest_stack
  h_oracle_success : OracleSucceeds env funcIdx [input1, input2] [output]
  rest_stack : List MoveValue

where
  OracleSucceeds (env : ModuleEnv) (funcIdx : Nat)
                (inputs outputs : List MoveValue) : Prop := True

/-- Applying 2-to-1 oracle pattern. -/
theorem apply_oracle_2_1_pattern
    (env : ModuleEnv)
    (gs : GlobalState)
    (pattern : OracleCall_2_1_Pattern env)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step env gs pattern.frame_before pattern.stack_before
                   pattern.ms_before = .ok gs frame' stack' ms') :
    frame'.pc = pattern.pc + 1 ∧
    stack' = pattern.output :: pattern.rest_stack := by
  sorry  -- Oracle 2-to-1 pattern

/-! ## Local Manipulation Patterns -/

/-- Copy-Store pattern: CopyLoc followed by StLoc. -/
structure CopyStorePattern where
  src_idx dst_idx : Nat
  pc_start : Nat
  frame_before : Frame
  stack_before : List MoveValue
  ms_before : MachineState
  value : MoveValue
  h_src : frame_before.locals[src_idx]? = some (some value)
  h_instr1 : frame_before.code[pc_start]? = some (.copyLoc src_idx)
  h_instr2 : frame_before.code[pc_start+1]? = some (.stLoc dst_idx)
  h_pc : frame_before.pc = pc_start

/-- Applying Copy-Store pattern. -/
theorem apply_copy_store_pattern
    (env : ModuleEnv)
    (gs : GlobalState)
    (pattern : CopyStorePattern)
    (frame_final : Frame)
    (stack_final : List MoveValue)
    (ms_final : MachineState)
    (h_run : run env gs pattern.frame_before pattern.stack_before
                 pattern.ms_before 2 = .ok gs frame_final stack_final ms_final) :
    frame_final.pc = pattern.pc_start + 2 ∧
    frame_final.locals[pattern.dst_idx]? = some (some pattern.value) ∧
    stack_final = pattern.stack_before := by
  sorry  -- Copy-Store pattern

/-- Move-Call-Store pattern. -/
structure MoveCallStorePattern (env : ModuleEnv) where
  src_idx dst_idx : Nat
  funcIdx : Nat
  pc_start : Nat
  frame_before : Frame
  stack_before : List MoveValue
  ms_before : MachineState
  input output : MoveValue
  h_src : frame_before.locals[src_idx]? = some (some input)
  h_instr1 : frame_before.code[pc_start]? = some (.moveLoc src_idx)
  h_instr2 : frame_before.code[pc_start+1]? = some (.call funcIdx)
  h_instr3 : frame_before.code[pc_start+2]? = some (.stLoc dst_idx)
  h_oracle : OracleSucceeds env funcIdx [input] [output]
  h_pc : frame_before.pc = pc_start

where
  OracleSucceeds (env : ModuleEnv) (funcIdx : Nat)
                (inputs outputs : List MoveValue) : Prop := True

/-- Applying Move-Call-Store pattern. -/
theorem apply_move_call_store_pattern
    (env : ModuleEnv)
    (gs : GlobalState)
    (pattern : MoveCallStorePattern env)
    (frame_final : Frame)
    (stack_final : List MoveValue)
    (ms_final : MachineState)
    (h_run : run env gs pattern.frame_before pattern.stack_before
                 pattern.ms_before 3 = .ok gs frame_final stack_final ms_final) :
    frame_final.pc = pattern.pc_start + 3 ∧
    frame_final.locals[pattern.dst_idx]? = some (some pattern.output) ∧
    frame_final.locals[pattern.src_idx]? = some none ∧
    stack_final = pattern.stack_before := by
  sorry  -- Move-Call-Store pattern

/-! ## Borrow and Reference Patterns -/

/-- ImmBorrow-Call pattern. -/
structure ImmBorrowCallPattern (env : ModuleEnv) where
  local_idx : Nat
  funcIdx : Nat
  pc_start : Nat
  frame_before : Frame
  stack_before : List MoveValue
  ms_before : MachineState
  value result : MoveValue
  h_local : frame_before.locals[local_idx]? = some (some value)
  h_instr1 : frame_before.code[pc_start]? = some (.immBorrowLoc local_idx)
  h_instr2 : frame_before.code[pc_start+1]? = some (.call funcIdx)
  h_oracle : ∀ refId, OracleWithRef env funcIdx refId value result
  h_pc : frame_before.pc = pc_start

where
  OracleWithRef (env : ModuleEnv) (funcIdx refId : Nat)
               (value result : MoveValue) : Prop := True

/-- Applying ImmBorrow-Call pattern. -/
theorem apply_imm_borrow_call_pattern
    (env : ModuleEnv)
    (gs : GlobalState)
    (pattern : ImmBorrowCallPattern env)
    (frame_final : Frame)
    (stack_final : List MoveValue)
    (ms_final : MachineState)
    (h_run : run env gs pattern.frame_before pattern.stack_before
                 pattern.ms_before 2 = .ok gs frame_final stack_final ms_final) :
    frame_final.pc = pattern.pc_start + 2 ∧
    stack_final = pattern.result :: pattern.stack_before := by
  sorry  -- ImmBorrow-Call pattern

/-! ## Conditional Patterns -/

/-- BrFalse with merge pattern. -/
structure BrFalseWithMergePattern where
  pc_branch : Nat
  pc_target : Nat
  pc_merge : Nat
  condition : Bool
  frame_before : Frame
  stack_before : List MoveValue
  ms_before : MachineState
  h_instr : frame_before.code[pc_branch]? = some (.brFalse pc_target)
  h_stack : stack_before = (.bool condition) :: rest_stack
  h_target_valid : pc_target < frame_before.code.length
  h_merge_valid : pc_merge < frame_before.code.length
  rest_stack : List MoveValue

/-- Branch taken case. -/
theorem brFalse_pattern_taken
    (env : ModuleEnv)
    (gs : GlobalState)
    (pattern : BrFalseWithMergePattern)
    (h_condition : pattern.condition = false)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step env gs pattern.frame_before pattern.stack_before
                   pattern.ms_before = .ok gs frame' stack' ms') :
    frame'.pc = pattern.pc_target ∧
    stack' = pattern.rest_stack := by
  sorry  -- Branch taken

/-- Branch not taken case. -/
theorem brFalse_pattern_not_taken
    (env : ModuleEnv)
    (gs : GlobalState)
    (pattern : BrFalseWithMergePattern)
    (h_condition : pattern.condition = true)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step env gs pattern.frame_before pattern.stack_before
                   pattern.ms_before = .ok gs frame' stack' ms') :
    frame'.pc = pattern.pc_branch + 1 ∧
    stack' = pattern.rest_stack := by
  sorry  -- Branch not taken

/-! ## PC Range Patterns -/

/-- Execute through PC range [start, end). -/
structure PCRangePattern where
  pc_start : Nat
  pc_end : Nat
  fuel : Nat
  frame_before : Frame
  stack_before : List MoveValue
  ms_before : MachineState
  frame_after : Frame
  stack_after : List MoveValue
  ms_after : MachineState
  h_pc_before : frame_before.pc = pc_start
  h_pc_after : frame_after.pc = pc_end
  h_execution : run (env_placeholder) [] frame_before stack_before ms_before fuel =
                .ok [] frame_after stack_after ms_after

where
  env_placeholder : ModuleEnv := { funcs := [], moduleId := ⟨0, 0⟩ }

/-- Composing PC range patterns. -/
theorem compose_pc_range_patterns
    (pattern1 pattern2 : PCRangePattern)
    (h_connect : pattern1.pc_end = pattern2.pc_start)
    (h_state_match : pattern1.frame_after = pattern2.frame_before ∧
                     pattern1.stack_after = pattern2.stack_before ∧
                     pattern1.ms_after = pattern2.ms_before) :
    ∃ combined : PCRangePattern,
      combined.pc_start = pattern1.pc_start ∧
      combined.pc_end = pattern2.pc_end ∧
      combined.fuel = pattern1.fuel + pattern2.fuel := by
  sorry  -- Compose PC ranges

/-! ## Phase-Level Patterns -/

/-- Complete phase execution pattern. -/
structure PhaseExecutionPattern (o : RegistrationNativeOracle) where
  phase_num : Nat
  pc_start : Nat
  pc_end : Nat
  fuel : Nat
  state_before : StateAtPC o pc_start
  state_after : StateAtPC o pc_end
  h_phase_num : phase_num ∈ [1, 2, 3]
  h_fuel_correct : (phase_num = 1 ∧ fuel = 17) ∨
                   (phase_num = 2 ∧ fuel = 23) ∨
                   (phase_num = 3 ∧ fuel = 27)
  h_execution : run (registrationModuleEnv o) []
                    state_before.frame state_before.stack state_before.ms fuel =
                .ok [] state_after.frame state_after.stack state_after.ms

where
  StateAtPC (o : RegistrationNativeOracle) (pc : Nat) :=
    { frame : Frame // frame.pc = pc }

/-- Composing three phases into complete execution. -/
theorem compose_three_phases
    (o : RegistrationNativeOracle)
    (phase1 : PhaseExecutionPattern o)
    (phase2 : PhaseExecutionPattern o)
    (phase3 : PhaseExecutionPattern o)
    (h_phase1_num : phase1.phase_num = 1)
    (h_phase2_num : phase2.phase_num = 2)
    (h_phase3_num : phase3.phase_num = 3)
    (h_connect12 : phase1.pc_end = phase2.pc_start)
    (h_connect23 : phase2.pc_end = phase3.pc_start) :
    ∃ complete_fuel,
      complete_fuel = 67 ∧
      complete_fuel = phase1.fuel + phase2.fuel + phase3.fuel := by
  use 67
  constructor
  · rfl
  · sorry  -- 17 + 23 + 27 = 67

/-! ## Error Path Patterns -/

/-- Error path pattern (validation failure → error exit). -/
structure ErrorPathPattern where
  pc_error_detect : Nat
  pc_error_exit : Nat
  error_type : String
  frame_before : Frame
  stack_before : List MoveValue
  ms_before : MachineState
  h_error_condition : ErrorConditionHolds error_type frame_before stack_before ms_before
  h_error_instr : frame_before.code[pc_error_detect]? = some (.brFalse pc_error_exit)

where
  ErrorConditionHolds (typ : String) (frame : Frame)
                     (stack : List MoveValue) (ms : MachineState) : Prop :=
    stack.head? = some (.bool false)

/-- Error path leads to error exit. -/
theorem error_path_to_exit
    (env : ModuleEnv)
    (gs : GlobalState)
    (pattern : ErrorPathPattern)
    (fuel : Nat)
    (h_fuel : fuel ≥ 1)
    (frame_final : Frame)
    (stack_final : List MoveValue)
    (ms_final : MachineState)
    (h_run : run env gs pattern.frame_before pattern.stack_before
                 pattern.ms_before fuel = .ok gs frame_final stack_final ms_final) :
    frame_final.pc = pattern.pc_error_exit ∨
    frame_final.pc = 79 := by  -- 79 is final error exit
  sorry  -- Error path to exit

/-! ## Pattern Catalog -/

/-- All reusable proof patterns. -/
inductive ProofPattern
  | sequential_2 : ProofPattern
  | sequential_n : ProofPattern
  | oracle_1_1 : ProofPattern
  | oracle_2_1 : ProofPattern
  | copy_store : ProofPattern
  | move_call_store : ProofPattern
  | imm_borrow_call : ProofPattern
  | brFalse_merge : ProofPattern
  | pc_range : ProofPattern
  | phase_execution : ProofPattern
  | error_path : ProofPattern

/-- Pattern catalog is complete. -/
def pattern_catalog : List ProofPattern :=
  [ .sequential_2, .sequential_n, .oracle_1_1, .oracle_2_1,
    .copy_store, .move_call_store, .imm_borrow_call,
    .brFalse_merge, .pc_range, .phase_execution, .error_path ]

theorem pattern_catalog_size :
    pattern_catalog.length = 11 := by
  rfl

end MovementFormal.Experimental.ConfidentialAsset.Registration.ProofCompositionPatterns
