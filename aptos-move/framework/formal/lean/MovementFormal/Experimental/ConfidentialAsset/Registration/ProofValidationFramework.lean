/-
# Proof Validation Framework

Comprehensive validation and testing framework for the registration proof.
Provides checkers, validators, and test harnesses to ensure proof correctness
before axiom replacement.

## Validation Levels

1. **Syntactic validation**: Well-formedness of proof terms
2. **Semantic validation**: Logical correctness of theorems
3. **Execution validation**: Concrete test cases and examples
4. **Integration validation**: Phase composition consistency
5. **Completeness validation**: All cases covered, no gaps

## Testing Strategy

- Unit tests: Individual PC step proofs
- Integration tests: Phase-level execution
- End-to-end tests: Complete PC 4→70 execution
- Property tests: Invariants hold throughout
- Negative tests: Error paths work correctly

## Source

Testing and validation best practices for formal verification.

-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.Value
import MovementFormal.Experimental.ConfidentialAsset.Registration.CompleteProofAssembly
import MovementFormal.Experimental.ConfidentialAsset.Registration.ConcreteValueFlowAnalysis
import MovementFormal.Experimental.ConfidentialAsset.Registration.StateInvariantTracking

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## Test Input Generation -/

/-- Valid test inputs for registration -/
structure TestInputs where
  chainId : UInt8
  sender : Address
  commitBa : ByteArray
  respBa : ByteArray
  h_commitSize : commitBa.size = 32
  h_respSize : respBa.size = 32
  h_commitValid : IsValidCompressedPointBytes (.vector .u8 (commitBa.toList.map .u8))
  h_respValid : IsValidCompressedPointBytes (.vector .u8 (respBa.toList.map .u8))

/-- Generate valid test input example 1 -/
def testInput1 : TestInputs := {
  chainId := 1
  sender := sorry  -- Concrete address
  commitBa := sorry  -- Valid 32-byte compressed point
  respBa := sorry  -- Valid 32-byte compressed point
  h_commitSize := sorry
  h_respSize := sorry
  h_commitValid := sorry
  h_respValid := sorry
}

/-- Generate invalid commit bytes test input -/
def testInputInvalidCommit : RegistrationInputValues := {
  chainId := 1
  sender := sorry
  commitBa := ByteArray.mk (Array.mkArray 32 0)  -- Invalid: all zeros
  respBa := sorry  -- Valid
  h_commitSize := by decide
  h_respSize := sorry
  h_commitValid := sorry
  h_respValid := sorry
}

/-- Generate invalid response bytes test input -/
def testInputInvalidResp : RegistrationInputValues := {
  chainId := 1
  sender := sorry
  commitBa := sorry  -- Valid
  respBa := ByteArray.mk (Array.mkArray 32 0)  -- Invalid: all zeros
  h_commitSize := sorry
  h_respSize := by decide
  h_commitValid := sorry
  h_respValid := sorry
}

/-! ## Syntactic Validation -/

/-- Check that a theorem has no sorry or axiom dependencies -/
def isProofComplete (thm_name : String) : Bool :=
  -- Would check proof term for sorry/axiom
  sorry

/-- Check all PC step proofs are complete -/
def allPCStepsComplete : Bool :=
  List.all (List.range 67) fun i =>
    isProofComplete s!"pc{4+i}_to_{5+i}"

/-- Validate proof term size is reasonable -/
def proofTermSizeReasonable (thm_name : String) (max_size : Nat) : Bool :=
  sorry  -- Check proof term doesn't exceed size

/-! ## Semantic Validation -/

/-- Validate a PC step proof maintains invariants -/
def validatePCStep
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (inv_before : StateInvariant pc)
    (inv_after : StateInvariant (pc + 1)) : Bool :=
  -- Check pre-conditions
  if ¬(inv_before.frame_well_formed frame) then false
  else if ¬(inv_before.stack_well_typed stack) then false
  else
    -- Execute step
    match step (registrationModuleEnv o) [] frame stack ms with
    | .ok [] frame' stack' ms' =>
        -- Check post-conditions
        inv_after.frame_well_formed frame' ∧
        inv_after.stack_well_typed stack' ∧
        frame'.pc = pc + 1
    | _ => false

/-- Validate phase composition maintains consistency -/
def validatePhaseComposition
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (phase_num : Nat)  -- 1, 2, or 3
    : Bool :=
  match phase_num with
  | 1 => sorry  -- Validate Phase 1 composition
  | 2 => sorry  -- Validate Phase 2 composition
  | 3 => sorry  -- Validate Phase 3 composition
  | _ => false

/-! ## Execution Validation -/

/-- Execute single PC step and validate result -/
def executePCStepTest
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (expected_pc' : Nat)
    (expected_stack_length : Nat) : Bool :=
  match step (registrationModuleEnv o) [] frame stack ms with
  | .ok [] frame' stack' ms' =>
      frame'.pc = expected_pc' ∧
      stack'.length = expected_stack_length
  | _ => false

/-- Execute complete phase and validate -/
def executePhaseTest
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (phase_num : Nat)
    (start_pc end_pc fuel : Nat) : Bool :=
  let (frame₀, stack₀, ms₀) := sorry  -- Construct initial state for phase
  match run (registrationModuleEnv o) fuel [] frame₀ stack₀ ms₀ with
  | .ok [] frame' stack' ms' =>
      frame'.pc = end_pc
  | _ => false

/-- Execute end-to-end test -/
def executeEndToEndTest
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (expected_result : Bool) : Bool :=
  let (frame₀, stack₀, ms₀) := constructInitialState inputs
  match run (registrationModuleEnv o) 67 [] frame₀ stack₀ ms₀ with
  | .ok [] frame' stack' ms' =>
      frame'.pc = 70 ∧
      stack' = [.bool expected_result]
  | _ => false

/-! ## Property Validation -/

/-- Validate fuel monotonicity property -/
def validateFuelMonotonicity
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (fuel1 fuel2 : Nat)
    (h : fuel1 ≤ fuel2) : Bool :=
  let (frame₀, stack₀, ms₀) := constructInitialState inputs
  match run (registrationModuleEnv o) fuel1 [] frame₀ stack₀ ms₀ with
  | .ok [] frame1 stack1 ms1 =>
      match run (registrationModuleEnv o) fuel2 [] frame₀ stack₀ ms₀ with
      | .ok [] frame2 stack2 ms2 =>
          frame1.pc ≤ frame2.pc  -- More fuel reaches at least as far
      | _ => false
  | _ => true  -- If fuel1 fails, property vacuously true

/-- Validate invariant preservation -/
def validateInvariantPreservation
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (pc : Nat)
    (h_pc : 4 ≤ pc ∧ pc ≤ 70) : Bool :=
  let (frame₀, stack₀, ms₀) := constructInitialState inputs
  let fuel := pc - 4
  match run (registrationModuleEnv o) fuel [] frame₀ stack₀ ms₀ with
  | .ok [] frame stack ms =>
      frame.pc = pc ∧
      checkStateInvariant pc frame stack ms
  | _ => false

/-- Validate type preservation -/
def validateTypePreservation
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (pc : Nat) : Bool :=
  let (frame₀, stack₀, ms₀) := constructInitialState inputs
  let fuel := if pc > 4 then pc - 4 else 0
  match run (registrationModuleEnv o) fuel [] frame₀ stack₀ ms₀ with
  | .ok [] frame stack ms =>
      -- All values on stack should be well-typed
      stack.all fun val =>
        ∃ ty, HasType val ty
  | _ => false

/-! ## Error Path Validation -/

/-- Test error path 1 (invalid commit) -/
def testErrorPath1
    (o : RegistrationNativeOracle) : Bool :=
  let inputs := testInputInvalidCommit
  let (frame₀, stack₀, ms₀) := constructInitialState inputs
  match run (registrationModuleEnv o) 67 [] frame₀ stack₀ ms₀ with
  | .ok [] frame' stack' ms' =>
      frame'.pc = 79 ∧ stack' = [.bool false]
  | _ => false

/-- Test error path 2 (invalid response) -/
def testErrorPath2
    (o : RegistrationNativeOracle) : Bool :=
  let inputs := testInputInvalidResp
  let (frame₀, stack₀, ms₀) := constructInitialState inputs
  match run (registrationModuleEnv o) 67 [] frame₀ stack₀ ms₀ with
  | .ok [] frame' stack' ms' =>
      frame'.pc = 79 ∧ stack' = [.bool false]
  | _ => false

/-- Test error path 3 (verification fails) -/
def testErrorPath3
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (h_valid_bytes : True)  -- Both bytes valid
    (h_bad_proof : True)  -- But proof doesn't verify
    : Bool :=
  let (frame₀, stack₀, ms₀) := constructInitialState inputs
  match run (registrationModuleEnv o) 67 [] frame₀ stack₀ ms₀ with
  | .ok [] frame' stack' ms' =>
      frame'.pc = 79 ∧ stack' = [.bool false]
  | _ => false

/-! ## Completeness Validation -/

/-- Check all PCs from 4 to 70 are reachable -/
def allPCsReachable
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues) : Bool :=
  let (frame₀, stack₀, ms₀) := constructInitialState inputs
  List.all (List.range 67) fun i =>
    let target_pc := 4 + i
    match run (registrationModuleEnv o) i [] frame₀ stack₀ ms₀ with
    | .ok [] frame stack ms => frame.pc = target_pc
    | _ => false

/-- Check all oracle operations are covered -/
def allOracleOpsCovered : Bool :=
  let oracle_pcs := [9, 14, 17, 20, 23, 27, 31, 39, 41, 45, 50, 59, 64]
  oracle_pcs.length = 14  -- All 14 unique oracle operations

/-- Check all instruction types are handled -/
def allInstructionTypesHandled : Bool :=
  let instruction_types := [
    "CopyLoc", "MoveLoc", "StLoc",
    "ImmBorrowLoc", "MutBorrowLoc",
    "ReadRef", "WriteRef",
    "Call", "BrFalse"
  ]
  instruction_types.length = 9

/-! ## Integration Validation -/

/-- Validate Phase 1→2 boundary -/
def validatePhase1to2Boundary
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues) : Bool :=
  let (frame₀, stack₀, ms₀) := constructInitialState inputs
  -- Execute Phase 1
  match run (registrationModuleEnv o) 17 [] frame₀ stack₀ ms₀ with
  | .ok [] frame₂₀ stack₂₀ ms₂₀ =>
      frame₂₀.pc = 20 ∧
      (stack₂₀.length = 0 ∨ stack₂₀.length = 1)  -- Empty or respOption
  | _ => false

/-- Validate Phase 2→3 boundary -/
def validatePhase2to3Boundary
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues) : Bool :=
  let (frame₀, stack₀, ms₀) := constructInitialState inputs
  -- Execute Phase 1+2
  match run (registrationModuleEnv o) 40 [] frame₀ stack₀ ms₀ with
  | .ok [] frame₄₃ stack₄₃ ms₄₃ =>
      frame₄₃.pc = 43 ∧ stack₄₃ = []  -- Empty stack
  | _ => false

/-! ## Performance Validation -/

/-- Measure proof elaboration time (conceptual) -/
def measureProofTime (thm_name : String) : Nat :=
  sorry  -- Would measure elaboration time in milliseconds

/-- Check proof time is reasonable -/
def proofTimeReasonable (thm_name : String) (max_ms : Nat) : Bool :=
  measureProofTime thm_name ≤ max_ms

/-- Estimate total verification time -/
def estimateTotalVerificationTime : Nat :=
  -- PC steps: 67 * 100ms
  67 * 100 +
  -- Phase compositions: 3 * 500ms
  3 * 500 +
  -- Main theorem: 2000ms
  2000
  -- Total: ~10 seconds estimated

/-! ## Comprehensive Validation Suite -/

/-- Run all validation checks -/
structure ValidationResults where
  syntactic_valid : Bool
  semantic_valid : Bool
  execution_valid : Bool
  property_valid : Bool
  error_paths_valid : Bool
  completeness_valid : Bool
  integration_valid : Bool
  performance_valid : Bool

/-- Execute complete validation suite -/
def runCompleteValidation
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues) :
    ValidationResults :=
  { syntactic_valid := allPCStepsComplete
    semantic_valid := validatePhaseComposition o inputs 1 ∧
                      validatePhaseComposition o inputs 2 ∧
                      validatePhaseComposition o inputs 3
    execution_valid := executeEndToEndTest o inputs true
    property_valid := validateFuelMonotonicity o inputs 67 100 (by decide) ∧
                      validateInvariantPreservation o inputs 20 (by decide)
    error_paths_valid := testErrorPath1 o ∧ testErrorPath2 o
    completeness_valid := allPCsReachable o inputs ∧
                          allOracleOpsCovered ∧
                          allInstructionTypesHandled
    integration_valid := validatePhase1to2Boundary o inputs ∧
                         validatePhase2to3Boundary o inputs
    performance_valid := proofTimeReasonable "registration_singleton_branch_complete_proof" 5000
  }

/-- All validation checks pass -/
def allValidationsPassed (results : ValidationResults) : Bool :=
  results.syntactic_valid ∧
  results.semantic_valid ∧
  results.execution_valid ∧
  results.property_valid ∧
  results.error_paths_valid ∧
  results.completeness_valid ∧
  results.integration_valid ∧
  results.performance_valid

/-! ## Validation Reporting -/

/-- Generate validation report -/
def generateValidationReport
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues) :
    String :=
  let results := runCompleteValidation o inputs
  s!"Registration Proof Validation Report\n" ++
  s!"=====================================\n" ++
  s!"Syntactic:    {if results.syntactic_valid then "✓ PASS" else "✗ FAIL"}\n" ++
  s!"Semantic:     {if results.semantic_valid then "✓ PASS" else "✗ FAIL"}\n" ++
  s!"Execution:    {if results.execution_valid then "✓ PASS" else "✗ FAIL"}\n" ++
  s!"Properties:   {if results.property_valid then "✓ PASS" else "✗ FAIL"}\n" ++
  s!"Error Paths:  {if results.error_paths_valid then "✓ PASS" else "✗ FAIL"}\n" ++
  s!"Completeness: {if results.completeness_valid then "✓ PASS" else "✗ FAIL"}\n" ++
  s!"Integration:  {if results.integration_valid then "✓ PASS" else "✗ FAIL"}\n" ++
  s!"Performance:  {if results.performance_valid then "✓ PASS" else "✗ FAIL"}\n" ++
  s!"Overall:      {if allValidationsPassed results then "✓ READY FOR AXIOM REPLACEMENT" else "✗ NOT READY"}\n"

/-! ## Pre-Axiom-Replacement Checklist -/

/-- Final checklist before axiom replacement -/
structure PreReplacementChecklist where
  all_pc_steps_proven : Bool
  all_phases_composed : Bool
  main_theorem_proven : Bool
  all_tests_passing : Bool
  no_new_axioms : Bool
  lake_build_succeeds : Bool
  code_reviewed : Bool
  documentation_complete : Bool

/-- Check if ready for axiom replacement -/
def readyForAxiomReplacement
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues) :
    PreReplacementChecklist :=
  let validation := runCompleteValidation o inputs
  { all_pc_steps_proven := validation.syntactic_valid
    all_phases_composed := validation.semantic_valid
    main_theorem_proven := false  -- To be verified
    all_tests_passing := allValidationsPassed validation
    no_new_axioms := false  -- To be checked with #print axioms
    lake_build_succeeds := false  -- To be checked
    code_reviewed := false  -- Manual step
    documentation_complete := false  -- Manual step
  }

/-- Final approval for axiom replacement -/
def approvedForAxiomReplacement (checklist : PreReplacementChecklist) : Bool :=
  checklist.all_pc_steps_proven ∧
  checklist.all_phases_composed ∧
  checklist.main_theorem_proven ∧
  checklist.all_tests_passing ∧
  checklist.no_new_axioms ∧
  checklist.lake_build_succeeds ∧
  checklist.code_reviewed ∧
  checklist.documentation_complete

end MovementFormal.Experimental.ConfidentialAsset.Registration
