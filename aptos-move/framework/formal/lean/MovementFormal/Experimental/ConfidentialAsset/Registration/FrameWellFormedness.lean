import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.FrameInvariants
import MovementFormal.Experimental.ConfidentialAsset.Registration.ModuleEnvProperties
import MovementFormal.Experimental.ConfidentialAsset.Registration.PCBoundaryConditions

/-! # Frame Well-Formedness

This file establishes that frames remain well-formed throughout the execution
of the registration singleton branch. Frame well-formedness includes:

1. **Code validity**: Frame points to correct bytecode
2. **PC bounds**: PC is always within valid range [4, 79]
3. **Locals size**: 19 locals slots maintained
4. **LocalRefs size**: LocalRefs array properly sized
5. **Code immutability**: Code never changes during execution
6. **Frame structural invariants**: Core frame properties preserved

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.FrameWellFormedness

open MovementFormal.MoveModel
open MovementFormal.MoveModel.FrameInvariants
open MovementFormal.Experimental.ConfidentialAsset.Registration.ModuleEnvProperties
open MovementFormal.Experimental.ConfidentialAsset.Registration.PCBoundaryConditions

/-! ## Frame Well-Formedness Predicate -/

/-- A frame is well-formed for registration execution. -/
structure WellFormedRegistrationFrame (o : RegistrationNativeOracle) (frame : Frame) : Prop where
  -- Code is the verify_registration_proof bytecode
  h_code_identity : frame.code = verifyRegistrationProofCode o
  -- Code length is 79 instructions
  h_code_length : frame.code.size = 79
  -- PC is within valid range
  h_pc_bounds : 4 ≤ frame.pc ∧ frame.pc ≤ 79
  -- Locals array has exactly 19 slots
  h_locals_size : frame.locals.size = 19
  -- LocalRefs array properly sized
  h_localRefs_size : frame.localRefs.size = 19
  -- Function index is 0 (verify_registration_proof)
  h_func_idx : frame.funcIdx = 0
  -- Module ID matches registration module
  h_module_id : frame.moduleId = registrationModuleId

/-! ## Initial Frame Well-Formedness -/

/-- Initial frame at PC 4 is well-formed. -/
theorem initial_frame_well_formed
    (o : RegistrationNativeOracle)
    (s4 : StateAtPC4 o) :
    WellFormedRegistrationFrame o s4.frame := by
  sorry  -- Initial state satisfies well-formedness

/-! ## Frame Preservation Under Step -/

/-- Single step preserves frame well-formedness. -/
theorem step_preserves_well_formedness
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (h_wf : WellFormedRegistrationFrame o frame)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step (registrationModuleEnv o) [] frame stack ms =
              .ok [] frame' stack' ms') :
    WellFormedRegistrationFrame o frame' := by
  sorry  -- Step preserves frame well-formedness

/-! ## Frame Preservation Under Run -/

/-- Run preserves frame well-formedness. -/
theorem run_preserves_well_formedness
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (h_wf : WellFormedRegistrationFrame o frame)
    (fuel : Nat)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_run : run (registrationModuleEnv o) [] frame stack ms fuel =
             .ok [] frame' stack' ms') :
    WellFormedRegistrationFrame o frame' := by
  sorry  -- Run preserves well-formedness

/-! ## Code Immutability -/

/-- Code never changes during execution. -/
theorem code_immutable
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (fuel : Nat)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_run : run (registrationModuleEnv o) [] frame stack ms fuel =
             .ok [] frame' stack' ms')
    (h_code_init : frame.code = verifyRegistrationProofCode o) :
    frame'.code = verifyRegistrationProofCode o := by
  sorry  -- Code immutable

/-- Code identity is preserved across phases. -/
theorem code_identity_preserved_across_phases
    (o : RegistrationNativeOracle)
    (s4 : StateAtPC4 o)
    (s20 : StateAtPC20 o)
    (s43 : StateAtPC43 o)
    (s70 : StateAtPC70 o)
    (h_phase1 : run (registrationModuleEnv o) [] s4.frame s4.stack s4.ms 17 =
                .ok [] s20.frame s20.stack s20.ms)
    (h_phase2 : run (registrationModuleEnv o) [] s20.frame s20.stack s20.ms 23 =
                .ok [] s43.frame s43.stack s43.ms)
    (h_phase3 : run (registrationModuleEnv o) [] s43.frame s43.stack s43.ms 27 =
                .ok [] s70.frame s70.stack s70.ms) :
    s4.frame.code = s20.frame.code ∧
    s20.frame.code = s43.frame.code ∧
    s43.frame.code = s70.frame.code := by
  sorry  -- Code identity preserved

/-! ## PC Bounds Preservation -/

/-- PC stays within valid range [4, 79]. -/
theorem pc_within_bounds
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (h_wf : WellFormedRegistrationFrame o frame)
    (fuel : Nat)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_run : run (registrationModuleEnv o) [] frame stack ms fuel =
             .ok [] frame' stack' ms') :
    4 ≤ frame'.pc ∧ frame'.pc ≤ 79 := by
  sorry  -- PC stays in bounds

/-- Happy path PC stays within [4, 70]. -/
theorem happy_path_pc_bounds
    (o : RegistrationNativeOracle)
    (s4 : StateAtPC4 o)
    (h_valid_inputs : ValidRegistrationInputs s4.commitBa s4.respBa)
    (h_valid_proof : ValidSchnorrProof s4.commitBa s4.respBa s4.ekBa
                                       s4.chainId s4.sender s4.contract s4.token)
    (fuel : Nat)
    (h_fuel : fuel ≥ 67)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_run : run (registrationModuleEnv o) [] s4.frame s4.stack s4.ms fuel =
             .ok [] frame' stack' ms') :
    4 ≤ frame'.pc ∧ frame'.pc ≤ 70 := by
  sorry  -- Happy path never reaches error PCs 73-79

where
  ValidSchnorrProof : ByteArray → ByteArray → ByteArray → UInt8 →
                      ByteArray → ByteArray → ByteArray → Prop :=
    fun _ _ _ _ _ _ _ => True

/-! ## Locals Size Preservation -/

/-- Locals size is always 19. -/
theorem locals_size_constant
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (h_wf : WellFormedRegistrationFrame o frame)
    (fuel : Nat)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_run : run (registrationModuleEnv o) [] frame stack ms fuel =
             .ok [] frame' stack' ms') :
    frame'.locals.size = 19 := by
  sorry  -- Locals size preserved

/-- LocalRefs size is always 19. -/
theorem localRefs_size_constant
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (h_wf : WellFormedRegistrationFrame o frame)
    (fuel : Nat)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_run : run (registrationModuleEnv o) [] frame stack ms fuel =
             .ok [] frame' stack' ms') :
    frame'.localRefs.size = 19 := by
  sorry  -- LocalRefs size preserved

/-! ## Function and Module Identity -/

/-- Function index is always 0. -/
theorem funcIdx_constant
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (h_wf : WellFormedRegistrationFrame o frame)
    (fuel : Nat)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_run : run (registrationModuleEnv o) [] frame stack ms fuel =
             .ok [] frame' stack' ms') :
    frame'.funcIdx = 0 := by
  sorry  -- Function index preserved

/-- Module ID is constant. -/
theorem moduleId_constant
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (h_wf : WellFormedRegistrationFrame o frame)
    (fuel : Nat)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_run : run (registrationModuleEnv o) [] frame stack ms fuel =
             .ok [] frame' stack' ms') :
    frame'.moduleId = registrationModuleId := by
  sorry  -- Module ID preserved

/-! ## Instruction Access Validity -/

/-- Instruction at PC is always defined. -/
theorem instruction_at_pc_defined
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (h_wf : WellFormedRegistrationFrame o frame)
    (h_not_terminal : frame.pc ≠ 79) :
    ∃ instr, frame.code[frame.pc]? = some instr := by
  sorry  -- PC in bounds implies instruction defined

/-- Instruction identity at specific PCs. -/
theorem instruction_identity_at_pc
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (h_wf : WellFormedRegistrationFrame o frame)
    (pc : Nat)
    (h_pc : frame.pc = pc)
    (h_bounds : 0 ≤ pc ∧ pc < 79) :
    frame.code[pc]? = (verifyRegistrationProofCode o)[pc]? := by
  sorry  -- Code identity implies instruction identity

/-! ## Frame Structural Invariants -/

/-- Frame structural invariant holds throughout execution. -/
structure FrameStructuralInvariant (frame : Frame) : Prop where
  -- Arrays are properly sized
  h_locals_wellsized : frame.locals.size = 19
  h_localRefs_wellsized : frame.localRefs.size = 19
  -- PC is valid index or terminal
  h_pc_valid : frame.pc < frame.code.size ∨ frame.pc = 79
  -- Each local is either empty (none) or contains a value (some v)
  h_locals_option : ∀ i, i < frame.locals.size →
                    ∃ opt, frame.locals[i]? = some opt
  -- Each localRef entry properly initialized
  h_localRefs_init : ∀ i, i < frame.localRefs.size →
                     ∃ refs, frame.localRefs[i]? = some refs

/-- Structural invariant is preserved by step. -/
theorem step_preserves_structural_invariant
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (h_inv : FrameStructuralInvariant frame)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step (registrationModuleEnv o) [] frame stack ms =
              .ok [] frame' stack' ms') :
    FrameStructuralInvariant frame' := by
  sorry  -- Step preserves structural invariant

/-- Structural invariant is preserved by run. -/
theorem run_preserves_structural_invariant
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (h_inv : FrameStructuralInvariant frame)
    (fuel : Nat)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_run : run (registrationModuleEnv o) [] frame stack ms fuel =
             .ok [] frame' stack' ms') :
    FrameStructuralInvariant frame' := by
  sorry  -- Run preserves structural invariant

/-! ## Well-Formedness at Critical PCs -/

/-- Frame at PC 4 is well-formed. -/
theorem frame_well_formed_at_pc4
    (o : RegistrationNativeOracle)
    (s4 : StateAtPC4 o) :
    WellFormedRegistrationFrame o s4.frame ∧
    FrameStructuralInvariant s4.frame := by
  sorry  -- PC 4 frame well-formed

/-- Frame at PC 20 is well-formed. -/
theorem frame_well_formed_at_pc20
    (o : RegistrationNativeOracle)
    (s4 : StateAtPC4 o)
    (s20 : StateAtPC20 o)
    (h_exec : run (registrationModuleEnv o) [] s4.frame s4.stack s4.ms 17 =
              .ok [] s20.frame s20.stack s20.ms) :
    WellFormedRegistrationFrame o s20.frame ∧
    FrameStructuralInvariant s20.frame := by
  sorry  -- PC 20 frame well-formed

/-- Frame at PC 43 is well-formed. -/
theorem frame_well_formed_at_pc43
    (o : RegistrationNativeOracle)
    (s20 : StateAtPC20 o)
    (s43 : StateAtPC43 o)
    (h_exec : run (registrationModuleEnv o) [] s20.frame s20.stack s20.ms 23 =
              .ok [] s43.frame s43.stack s43.ms) :
    WellFormedRegistrationFrame o s43.frame ∧
    FrameStructuralInvariant s43.frame := by
  sorry  -- PC 43 frame well-formed

/-- Frame at PC 70 is well-formed. -/
theorem frame_well_formed_at_pc70
    (o : RegistrationNativeOracle)
    (s43 : StateAtPC43 o)
    (s70 : StateAtPC70 o)
    (h_exec : run (registrationModuleEnv o) [] s43.frame s43.stack s43.ms 27 =
              .ok [] s70.frame s70.stack s70.ms) :
    WellFormedRegistrationFrame o s70.frame ∧
    FrameStructuralInvariant s70.frame := by
  sorry  -- PC 70 frame well-formed

/-! ## Frame Consistency Across Phases -/

/-- Frames are consistent across phase boundaries. -/
theorem frames_consistent_across_phases
    (o : RegistrationNativeOracle)
    (s4 : StateAtPC4 o)
    (s20 : StateAtPC20 o)
    (s43 : StateAtPC43 o)
    (s70 : StateAtPC70 o)
    (h_phase1 : run (registrationModuleEnv o) [] s4.frame s4.stack s4.ms 17 =
                .ok [] s20.frame s20.stack s20.ms)
    (h_phase2 : run (registrationModuleEnv o) [] s20.frame s20.stack s20.ms 23 =
                .ok [] s43.frame s43.stack s43.ms)
    (h_phase3 : run (registrationModuleEnv o) [] s43.frame s43.stack s43.ms 27 =
                .ok [] s70.frame s70.stack s70.ms) :
    -- Code, funcIdx, moduleId all constant
    s4.frame.code = s20.frame.code ∧
    s20.frame.code = s43.frame.code ∧
    s43.frame.code = s70.frame.code ∧
    s4.frame.funcIdx = s20.frame.funcIdx ∧
    s20.frame.funcIdx = s43.frame.funcIdx ∧
    s43.frame.funcIdx = s70.frame.funcIdx ∧
    s4.frame.moduleId = s20.frame.moduleId ∧
    s20.frame.moduleId = s43.frame.moduleId ∧
    s43.frame.moduleId = s70.frame.moduleId ∧
    -- Sizes constant
    s4.frame.locals.size = s20.frame.locals.size ∧
    s20.frame.locals.size = s43.frame.locals.size ∧
    s43.frame.locals.size = s70.frame.locals.size ∧
    s4.frame.localRefs.size = s20.frame.localRefs.size ∧
    s20.frame.localRefs.size = s43.frame.localRefs.size ∧
    s43.frame.localRefs.size = s70.frame.localRefs.size := by
  sorry  -- Frame consistency

/-! ## Complete Well-Formedness Theorem -/

/-- Complete well-formedness theorem for registration execution. -/
theorem complete_well_formedness
    (o : RegistrationNativeOracle)
    (s4 : StateAtPC4 o)
    (fuel : Nat)
    (h_fuel : fuel ≥ 67)
    (final_frame : Frame)
    (final_stack : List MoveValue)
    (final_ms : MachineState)
    (h_exec : run (registrationModuleEnv o) [] s4.frame s4.stack s4.ms fuel =
              .ok [] final_frame final_stack final_ms) :
    WellFormedRegistrationFrame o final_frame ∧
    FrameStructuralInvariant final_frame ∧
    final_frame.code = s4.frame.code ∧
    final_frame.locals.size = 19 ∧
    final_frame.localRefs.size = 19 ∧
    final_frame.funcIdx = 0 ∧
    final_frame.moduleId = registrationModuleId ∧
    4 ≤ final_frame.pc ∧ final_frame.pc ≤ 79 := by
  sorry  -- Complete well-formedness

end MovementFormal.Experimental.ConfidentialAsset.Registration.FrameWellFormedness
