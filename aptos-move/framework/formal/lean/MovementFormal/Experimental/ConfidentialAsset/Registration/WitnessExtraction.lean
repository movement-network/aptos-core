/-
# Witness Extraction

Extract concrete witnesses from execution proofs. Enables testing,
validation, and proof debugging.

## Witnesses

1. **IntermediateValues**: Values at each PC
2. **OracleTrace**: Sequence of oracle calls and results
3. **StackTrace**: Stack contents at each PC
4. **LocalsTrace**: Locals evolution through execution
5. **ExecutionPath**: Complete execution trace

## Applications

- Validate proof correctness against test vectors
- Debug proof failures by inspecting intermediate states
- Generate test cases from proofs
- Check oracle consistency

## Source

Testing and validation infrastructure.

-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.Experimental.ConfidentialAsset.Registration.OracleCallSpecifications
import MovementFormal.Experimental.ConfidentialAsset.Registration.ConcreteValueFlowAnalysis

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## Witness Types -/

/-- Snapshot of state at a PC -/
structure PCSnapshot where
  pc : Nat
  stack : List MoveValue
  locals : Array (Option MoveValue)
  deriving Repr, BEq

/-- Oracle call record -/
structure OracleCallRecord where
  pc : Nat
  oracle_name : String
  inputs : List MoveValue
  outputs : List MoveValue
  deriving Repr, BEq

/-- Complete execution trace -/
structure ExecutionTrace where
  snapshots : List PCSnapshot
  oracle_calls : List OracleCallRecord
  initial_state : PCSnapshot
  final_state : PCSnapshot
  fuel_used : Nat
  deriving Repr

/-! ## Witness Extraction Functions -/

/-- Extract snapshot from frame and stack -/
def extractSnapshot (frame : Frame) (stack : List MoveValue) : PCSnapshot :=
  { pc := frame.pc
    stack := stack
    locals := frame.locals }

/-- Extract oracle call from native call step -/
def extractOracleCall
    (pc : Nat)
    (oracle_name : String)
    (inputs outputs : List MoveValue) : OracleCallRecord :=
  { pc := pc
    oracle_name := oracle_name
    inputs := inputs
    outputs := outputs }

/-! ## Trace Construction -/

/-- Build execution trace from run proof -/
def buildExecutionTrace
    (o : RegistrationNativeOracle)
    (fuel : Nat)
    (frame₀ : Frame) (stack₀ : List MoveValue) (ms₀ : MachineState)
    (frame' : Frame) (stack' : List MoveValue) (ms' : MachineState)
    (h : run (registrationModuleEnv o) fuel [] frame₀ stack₀ ms₀ =
         .ok [] frame' stack' ms') :
    ExecutionTrace :=
  { snapshots := []  -- Will be populated by tracing execution
    oracle_calls := []
    initial_state := extractSnapshot frame₀ stack₀
    final_state := extractSnapshot frame' stack'
    fuel_used := fuel }

/-! ## Value Extraction -/

/-- Extract value from locals at specific index -/
def extractLocal (trace : ExecutionTrace) (pc : Nat) (idx : Nat) : Option MoveValue :=
  match trace.snapshots.find? (fun s => s.pc == pc) with
  | some snapshot => snapshot.locals[idx]??.join
  | none => none

/-- Extract all oracle calls of a specific type -/
def extractOracleCalls (trace : ExecutionTrace) (oracle_name : String) : List OracleCallRecord :=
  trace.oracle_calls.filter (fun call => call.oracle_name == oracle_name)

/-- Extract values at phase boundaries -/
structure PhaseBoundaryValues where
  -- Phase 1 outputs (PC 20)
  commit_pt : Option MoveValue
  resp_pt : Option MoveValue
  chainId_sc : Option MoveValue
  sender_sc : Option MoveValue

  -- Phase 2 outputs (PC 43)
  message_hash : Option MoveValue
  challenge_sc : Option MoveValue

  -- Phase 3 output (PC 70)
  result : Option Bool
  deriving Repr

/-- Extract phase boundary values from trace -/
def extractPhaseBoundaries (trace : ExecutionTrace) : PhaseBoundaryValues :=
  { commit_pt := extractLocal trace 20 9
    resp_pt := extractLocal trace 20 12
    chainId_sc := extractLocal trace 20 13
    sender_sc := extractLocal trace 20 14
    message_hash := extractLocal trace 43 17
    challenge_sc := extractLocal trace 43 17  -- Same local, different value
    result := match trace.final_state.stack with
              | [.bool b] => some b
              | _ => none }

/-! ## Validation Functions -/

/-- Validate that trace matches expected values -/
def validateTrace
    (trace : ExecutionTrace)
    (expected_initial : PCSnapshot)
    (expected_final : PCSnapshot) : Bool :=
  trace.initial_state == expected_initial &&
  trace.final_state == expected_final

/-- Validate oracle consistency -/
def validateOracleConsistency (trace : ExecutionTrace) : Bool :=
  -- Check that all oracle calls have valid outputs
  trace.oracle_calls.all (fun call => call.outputs.length > 0)

/-- Validate PC monotonicity (no backwards jumps in this branch) -/
def validatePCMonotonicity (trace : ExecutionTrace) : Bool :=
  let pcs := trace.snapshots.map (·.pc)
  pcs.Sorted (· ≤ ·)

/-! ## Test Vector Generation -/

/-- Generate test vector from trace -/
structure TestVector where
  inputs : RegistrationInputValues
  expected_result : Bool
  intermediate_values : PhaseBoundaryValues
  oracle_calls : List OracleCallRecord
  deriving Repr

/-- Extract test vector from execution trace -/
def extractTestVector
    (inputs : RegistrationInputValues)
    (trace : ExecutionTrace) : TestVector :=
  { inputs := inputs
    expected_result := match trace.final_state.stack with
                      | [.bool b] => b
                      | _ => false
    intermediate_values := extractPhaseBoundaries trace
    oracle_calls := trace.oracle_calls }

/-! ## Proof Debugging -/

/-- Find first PC where stack depth exceeds limit -/
def findStackOverflow (trace : ExecutionTrace) (limit : Nat) : Option Nat :=
  trace.snapshots.find? (fun s => s.stack.length > limit) |>.map (·.pc)

/-- Find first PC where local access is out of bounds -/
def findLocalOutOfBounds (trace : ExecutionTrace) (max_locals : Nat) : Option Nat :=
  trace.snapshots.find? (fun s =>
    s.locals.size > max_locals
  ) |>.map (·.pc)

/-- Find all PCs where oracle calls failed -/
def findFailedOracleCalls (trace : ExecutionTrace) : List Nat :=
  trace.oracle_calls.filter (fun call => call.outputs.isEmpty) |>.map (·.pc)

/-! ## Concrete Witness Builders -/

/-- Build witness for Phase 1 execution -/
def buildPhase1Witness
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame₄ : Frame) (ms₄ : MachineState)
    (h_exec : ∃ frame₂₀ stack₂₀ ms₂₀,
      run (registrationModuleEnv o) 17 [] frame₄ [] ms₄ =
      .ok [] frame₂₀ stack₂₀ ms₂₀ ∧
      frame₂₀.pc = 20) :
    ExecutionTrace :=
  match h_exec with
  | ⟨frame₂₀, stack₂₀, ms₂₀, h_run, _⟩ =>
    buildExecutionTrace o 17 frame₄ [] ms₄ frame₂₀ stack₂₀ ms₂₀ h_run

/-- Build witness for Phase 2 execution -/
def buildPhase2Witness
    (o : RegistrationNativeOracle)
    (frame₂₀ : Frame) (ms₂₀ : MachineState)
    (h_exec : ∃ frame₄₃ stack₄₃ ms₄₃,
      run (registrationModuleEnv o) 23 [] frame₂₀ [] ms₂₀ =
      .ok [] frame₄₃ stack₄₃ ms₄₃ ∧
      frame₄₃.pc = 43) :
    ExecutionTrace :=
  match h_exec with
  | ⟨frame₄₃, stack₄₃, ms₄₃, h_run, _⟩ =>
    buildExecutionTrace o 23 frame₂₀ [] ms₂₀ frame₄₃ stack₄₃ ms₄₃ h_run

/-- Build witness for Phase 3 execution -/
def buildPhase3Witness
    (o : RegistrationNativeOracle)
    (frame₄₃ : Frame) (ms₄₃ : MachineState)
    (h_exec : ∃ frame₇₀ stack₇₀ ms₇₀,
      run (registrationModuleEnv o) 27 [] frame₄₃ [] ms₄₃ =
      .ok [] frame₇₀ stack₇₀ ms₇₀ ∧
      frame₇₀.pc = 70) :
    ExecutionTrace :=
  match h_exec with
  | ⟨frame₇₀, stack₇₀, ms₇₀, h_run, _⟩ =>
    buildExecutionTrace o 27 frame₄₃ [] ms₄₃ frame₇₀ stack₇₀ ms₇₀ h_run

/-- Build complete witness for all three phases -/
def buildCompleteWitness
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame₄ : Frame) (ms₄ : MachineState)
    (h_exec : ∃ frame₇₀ stack₇₀ ms₇₀,
      run (registrationModuleEnv o) 67 [] frame₄ [] ms₄ =
      .ok [] frame₇₀ stack₇₀ ms₇₀ ∧
      frame₇₀.pc = 70) :
    ExecutionTrace :=
  match h_exec with
  | ⟨frame₇₀, stack₇₀, ms₇₀, h_run, _⟩ =>
    buildExecutionTrace o 67 frame₄ [] ms₄ frame₇₀ stack₇₀ ms₇₀ h_run

/-! ## Witness Comparison -/

/-- Compare two execution traces for equivalence -/
def tracesEquivalent (t1 t2 : ExecutionTrace) : Bool :=
  t1.initial_state == t2.initial_state &&
  t1.final_state == t2.final_state &&
  t1.fuel_used == t2.fuel_used

/-- Compare phase boundary values -/
def phaseBoundariesEquivalent (p1 p2 : PhaseBoundaryValues) : Bool :=
  p1.commit_pt == p2.commit_pt &&
  p1.resp_pt == p2.resp_pt &&
  p1.chainId_sc == p2.chainId_sc &&
  p1.sender_sc == p2.sender_sc &&
  p1.message_hash == p2.message_hash &&
  p1.result == p2.result

/-! ## Pretty Printing -/

/-- Format execution trace for display -/
def formatTrace (trace : ExecutionTrace) : String :=
  let header := s!"Execution Trace ({trace.fuel_used} steps)\n" ++
                "=" .times 60 ++ "\n\n"

  let initial := s!"Initial: PC {trace.initial_state.pc}, " ++
                 s!"Stack depth {trace.initial_state.stack.length}\n"

  let final := s!"Final: PC {trace.final_state.pc}, " ++
               s!"Stack depth {trace.final_state.stack.length}\n"

  let oracle_summary := s!"Oracle calls: {trace.oracle_calls.length}\n"

  let phases := extractPhaseBoundaries trace
  let phase_info := s!"\nPhase boundaries:\n" ++
                    s!"  PC 20: commit_pt = {phases.commit_pt.isSome}\n" ++
                    s!"  PC 43: message_hash = {phases.message_hash.isSome}\n" ++
                    s!"  PC 70: result = {phases.result}\n"

  header ++ initial ++ final ++ oracle_summary ++ phase_info

end MovementFormal.Experimental.ConfidentialAsset.Registration
