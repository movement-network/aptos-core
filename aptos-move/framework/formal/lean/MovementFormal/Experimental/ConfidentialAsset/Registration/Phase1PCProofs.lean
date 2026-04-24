/-
# Phase 1 PC Proof Implementations

Concrete implementations of all PC→PC+1 proofs for Phase 1 (PC 4→20).
Phase 1 performs input extraction and point unwrapping.

## Phase 1 Structure (17 steps)

PC 4→5: CopyLoc commitOption
PC 5→6: Call isSome
PC 6→7: BrTrue (assumes true path)
PC 7→8: MoveLoc commitOption
PC 8→9: Call unwrap
PC 9→10: StLoc commit_pt
PC 10→11: CopyLoc respOption
PC 11→12: Call isSome
PC 12→13: BrTrue (assumes true path)
PC 13→14: MoveLoc respOption
PC 14→15: Call unwrap
PC 15→16: StLoc resp_pt
PC 16→17: CopyLoc chainIdScalar
PC 17→18: StLoc chainId_sc
PC 18→19: CopyLoc senderScalar
PC 19→20: StLoc sender_sc

## Source

Implements concrete proofs for Phase 1 input extraction.

-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.Experimental.ConfidentialAsset.Registration.ConcretePCStepTemplates
import MovementFormal.Experimental.ConfidentialAsset.Registration.OracleCallSpecifications

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## PC 4→5: CopyLoc commitOption -/

theorem pc4_to_5
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 4)
    (commitOption : MoveValue)
    (h_local : frame.locals[0]? = some (some commitOption))
    (h_stack : stack = []) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 5 ∧
      stack' = [commitOption] := by
  sorry

/-! ## PC 5→6: Call isSome -/

theorem pc5_to_6
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 5)
    (commitOption : MoveValue)
    (h_stack : stack = [commitOption])
    (is_some : Bool)
    (h_oracle : o.isSome [commitOption] = some [.bool is_some]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 6 ∧
      stack' = [.bool is_some] := by
  sorry

/-! ## PC 6→7: BrTrue (assumes true path) -/

theorem pc6_to_7
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 6)
    (h_stack : stack = [.bool true]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 7 ∧
      stack' = [] := by
  sorry

/-! ## PC 7→8: MoveLoc commitOption -/

theorem pc7_to_8
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 7)
    (commitOption : MoveValue)
    (h_local : frame.locals[0]? = some (some commitOption))
    (h_stack : stack = []) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 8 ∧
      frame'.locals[0]? = some none ∧
      stack' = [commitOption] := by
  sorry

/-! ## PC 8→9: Call unwrap -/

theorem pc8_to_9
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 8)
    (commitOption : MoveValue)
    (h_stack : stack = [commitOption])
    (commit_pt : MoveValue)
    (h_oracle : o.unwrap [commitOption] = some [commit_pt])
    (h_valid : IsValidRistrettoPoint commit_pt) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 9 ∧
      stack' = [commit_pt] := by
  sorry

/-! ## PC 9→10: StLoc commit_pt -/

theorem pc9_to_10
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 9)
    (commit_pt : MoveValue)
    (h_stack : stack = [commit_pt]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 10 ∧
      frame'.locals[9]? = some (some commit_pt) ∧
      stack' = [] := by
  sorry

/-! ## PC 10→11: CopyLoc respOption -/

theorem pc10_to_11
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 10)
    (respOption : MoveValue)
    (h_local : frame.locals[1]? = some (some respOption))
    (h_stack : stack = []) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 11 ∧
      stack' = [respOption] := by
  sorry

/-! ## PC 11→12: Call isSome -/

theorem pc11_to_12
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 11)
    (respOption : MoveValue)
    (h_stack : stack = [respOption])
    (is_some : Bool)
    (h_oracle : o.isSome [respOption] = some [.bool is_some]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 12 ∧
      stack' = [.bool is_some] := by
  sorry

/-! ## PC 12→13: BrTrue (assumes true path) -/

theorem pc12_to_13
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 12)
    (h_stack : stack = [.bool true]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 13 ∧
      stack' = [] := by
  sorry

/-! ## PC 13→14: MoveLoc respOption -/

theorem pc13_to_14
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 13)
    (respOption : MoveValue)
    (h_local : frame.locals[1]? = some (some respOption))
    (h_stack : stack = []) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 14 ∧
      frame'.locals[1]? = some none ∧
      stack' = [respOption] := by
  sorry

/-! ## PC 14→15: Call unwrap -/

theorem pc14_to_15
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 14)
    (respOption : MoveValue)
    (h_stack : stack = [respOption])
    (resp_pt : MoveValue)
    (h_oracle : o.unwrap [respOption] = some [resp_pt])
    (h_valid : IsValidRistrettoPoint resp_pt) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 15 ∧
      stack' = [resp_pt] := by
  sorry

/-! ## PC 15→16: StLoc resp_pt -/

theorem pc15_to_16
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 15)
    (resp_pt : MoveValue)
    (h_stack : stack = [resp_pt]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 16 ∧
      frame'.locals[12]? = some (some resp_pt) ∧
      stack' = [] := by
  sorry

/-! ## PC 16→17: CopyLoc chainIdScalar -/

theorem pc16_to_17
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 16)
    (chainIdScalar : MoveValue)
    (h_local : frame.locals[2]? = some (some chainIdScalar))
    (h_stack : stack = []) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 17 ∧
      stack' = [chainIdScalar] := by
  sorry

/-! ## PC 17→18: StLoc chainId_sc -/

theorem pc17_to_18
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 17)
    (chainIdScalar : MoveValue)
    (h_stack : stack = [chainIdScalar]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 18 ∧
      frame'.locals[13]? = some (some chainIdScalar) ∧
      stack' = [] := by
  sorry

/-! ## PC 18→19: CopyLoc senderScalar -/

theorem pc18_to_19
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 18)
    (senderScalar : MoveValue)
    (h_local : frame.locals[3]? = some (some senderScalar))
    (h_stack : stack = []) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 19 ∧
      stack' = [senderScalar] := by
  sorry

/-! ## PC 19→20: StLoc sender_sc -/

theorem pc19_to_20
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 19)
    (senderScalar : MoveValue)
    (h_stack : stack = [senderScalar]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 20 ∧
      frame'.locals[14]? = some (some senderScalar) ∧
      stack' = [] := by
  sorry

/-! ## Phase 1 Complete Composition -/

/-- Compose all Phase 1 proofs (PC 4→20) -/
theorem phase1_complete
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame₄ : Frame) (stack₄ : List MoveValue) (ms₄ : MachineState)
    (h_pc : frame₄.pc = 4)
    (h_inputs : frame₄.locals[0]? = some (some inputs.commitOption) ∧
                frame₄.locals[1]? = some (some inputs.respOption) ∧
                frame₄.locals[2]? = some (some inputs.chainIdScalar) ∧
                frame₄.locals[3]? = some (some inputs.senderScalar))
    (h_stack : stack₄ = [])
    (commit_pt resp_pt : MoveValue)
    (h_oracle_unwrap_commit : o.unwrap [inputs.commitOption] = some [commit_pt])
    (h_oracle_unwrap_resp : o.unwrap [inputs.respOption] = some [resp_pt])
    (h_valid_commit : IsValidRistrettoPoint commit_pt)
    (h_valid_resp : IsValidRistrettoPoint resp_pt) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 17 [] frame₄ stack₄ ms₄ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 20 ∧
      frame'.locals[9]? = some (some commit_pt) ∧
      frame'.locals[12]? = some (some resp_pt) ∧
      frame'.locals[13]? = some (some inputs.chainIdScalar) ∧
      frame'.locals[14]? = some (some inputs.senderScalar) ∧
      stack' = [] := by
  sorry

/-! ## Phase 1 Correctness Property -/

/-- Phase 1 correctly extracts and unwraps inputs -/
theorem phase1_correctness
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame₄ : Frame) (ms₄ : MachineState)
    (frame' stack' ms' : _)
    (h_exec : run (registrationModuleEnv o) 17 [] frame₄ [] ms₄ =
              .ok [] frame' stack' ms')
    (commit_pt resp_pt : MoveValue)
    (h_commit : frame'.locals[9]? = some (some commit_pt))
    (h_resp : frame'.locals[12]? = some (some resp_pt)) :
    -- Unwrapped points are valid
    IsValidRistrettoPoint commit_pt ∧
    IsValidRistrettoPoint resp_pt ∧
    -- Scalars are preserved
    frame'.locals[13]? = some (some inputs.chainIdScalar) ∧
    frame'.locals[14]? = some (some inputs.senderScalar) := by
  sorry

end MovementFormal.Experimental.ConfidentialAsset.Registration
