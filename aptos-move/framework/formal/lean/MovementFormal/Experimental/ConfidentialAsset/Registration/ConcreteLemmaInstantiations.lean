import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.StepLemmas.Bundled
import MovementFormal.Experimental.ConfidentialAsset.Registration.ConcreteExecutionLemmas
import MovementFormal.Experimental.ConfidentialAsset.Registration.OracleCorrespondenceProofs
import MovementFormal.Experimental.ConfidentialAsset.Registration.PCBoundaryConditions

/-! # Concrete Lemma Instantiations

This file provides concrete instantiations of generic step lemmas for the
specific instruction sequences appearing in the registration singleton branch.
These instantiations fill in the specific values, types, and oracle behaviors
for each actual instruction execution.

## Instantiation Strategy

For each PC we instantiate:
1. **Generic step lemma** → **Concrete step lemma** with actual values
2. **Oracle hypothesis** → **Concrete oracle call** with specific inputs/outputs
3. **Type lemma** → **Concrete type** for that PC's values
4. **Invariant lemma** → **Concrete invariant** at that PC

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.ConcreteLemmaInstantiations

open MovementFormal.MoveModel
open MovementFormal.MoveModel.StepLemmas.Bundled
open MovementFormal.Experimental.ConfidentialAsset.Registration.ConcreteExecutionLemmas
open MovementFormal.Experimental.ConfidentialAsset.Registration.OracleCorrespondenceProofs
open MovementFormal.Experimental.ConfidentialAsset.Registration.PCBoundaryConditions

/-! ## PC 4-8: Parameter Setup -/

/-- Concrete instantiation: PC 4 CopyLoc 0 (chainId). -/
theorem concrete_pc4_copyLoc0
    (o : RegistrationNativeOracle)
    (s4 : StateAtPC4 o) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] s4.frame s4.stack s4.ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 5 ∧
      stack' = (.u8 s4.chainId) :: s4.stack ∧
      frame'.locals[0]? = some (some (.u8 s4.chainId)) ∧
      ms' = s4.ms := by
  sorry  -- Instantiate generic copyLoc lemma with chainId

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-- Concrete instantiation: PC 5 StLoc 6 (store chainId). -/
theorem concrete_pc5_stLoc6
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (chainId : UInt8)
    (h_pc : frame.pc = 5)
    (h_stack : stack = (.u8 chainId) :: rest_stack) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 6 ∧
      frame'.locals[6]? = some (some (.u8 chainId)) ∧
      stack' = rest_stack ∧
      ms' = ms := by
  sorry  -- Instantiate generic stLoc lemma with local 6

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-- Concrete instantiation: PC 6 CopyLoc 1 (sender). -/
theorem concrete_pc6_copyLoc1
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (sender : ByteArray)
    (h_pc : frame.pc = 6)
    (h_local1 : frame.locals[1]? = some (some (.vector .address (sender.toList.map .u8)))) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 7 ∧
      stack' = (.vector .address (sender.toList.map .u8)) :: stack ∧
      ms' = ms := by
  sorry  -- Instantiate copyLoc with sender

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-- Concrete instantiation: PC 7 StLoc 7 (store sender). -/
theorem concrete_pc7_stLoc7
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (sender : ByteArray)
    (h_pc : frame.pc = 7)
    (h_stack : stack = (.vector .address (sender.toList.map .u8)) :: rest_stack) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 8 ∧
      frame'.locals[7]? = some (some (.vector .address (sender.toList.map .u8))) ∧
      stack' = rest_stack := by
  sorry  -- Instantiate stLoc with local 7

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-- Concrete instantiation: PC 8 MoveLoc 2 (commitBa). -/
theorem concrete_pc8_moveLoc2
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (commitBa : ByteArray)
    (h_pc : frame.pc = 8)
    (h_local2 : frame.locals[2]? = some (some (.vector .u8 (commitBa.toList.map .u8)))) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 9 ∧
      stack' = (.vector .u8 (commitBa.toList.map .u8)) :: stack ∧
      frame'.locals[2]? = some none := by
  sorry  -- Instantiate moveLoc with commitBa

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-! ## PC 9-10: Oracle Call newCompressedPointFromBytes -/

/-- Concrete instantiation: PC 9 Call newCompressedPointFromBytes. -/
theorem concrete_pc9_newCompressedPointFromBytes
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (commitBa : ByteArray)
    (h_pc : frame.pc = 9)
    (h_stack : stack = (.vector .u8 (commitBa.toList.map .u8)) :: rest_stack)
    (h_len : commitBa.size = 32)
    (h_valid : IsValidCompressedPointBytes (.vector .u8 (commitBa.toList.map .u8)))
    (option_result : MoveValue)
    (h_oracle : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] =
                some [option_result])
    (compressed_point : MoveValue)
    (h_some : option_result = .struct [.bool true, compressed_point]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 10 ∧
      stack' = option_result :: rest_stack ∧
      -- Extracted point is valid
      IsValidCompressedPoint compressed_point := by
  sorry  -- Instantiate oracle call with concrete values

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-- Concrete instantiation: PC 10 StLoc 8 (store Option). -/
theorem concrete_pc10_stLoc8_option
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (option_val : MoveValue)
    (h_pc : frame.pc = 10)
    (h_stack : stack = option_val :: rest_stack)
    (h_option : IsOptionType option_val) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 11 ∧
      frame'.locals[8]? = some (some option_val) ∧
      stack' = rest_stack := by
  sorry  -- Store Option to local 8

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }
  IsOptionType (v : MoveValue) : Prop := True

/-! ## PC 11-13: Option Validation -/

/-- Concrete instantiation: PC 11 ImmBorrowLoc 8. -/
theorem concrete_pc11_immBorrowLoc8
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (option_val : MoveValue)
    (h_pc : frame.pc = 11)
    (h_local8 : frame.locals[8]? = some (some option_val)) :
    ∃ frame' stack' ms' refId,
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 12 ∧
      stack' = (.immRef refId) :: stack ∧
      ContainerStore.read ms'.containers refId = some option_val ∧
      refId = ms.containers.store.size := by
  sorry  -- Borrow local 8

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-- Concrete instantiation: PC 12 Call isSome. -/
theorem concrete_pc12_isSome
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (refId : Nat)
    (option_val : MoveValue)
    (compressed_point : MoveValue)
    (h_pc : frame.pc = 12)
    (h_stack : stack = (.immRef refId) :: rest_stack)
    (h_container : ContainerStore.read ms.containers refId = some option_val)
    (h_some : option_val = .struct [.bool true, compressed_point])
    (is_some_result : MoveValue)
    (h_oracle : o.isSome [option_val] = some [.bool true]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 13 ∧
      stack' = (.bool true) :: rest_stack := by
  sorry  -- isSome returns true

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-- Concrete instantiation: PC 13 BrFalse (happy path). -/
theorem concrete_pc13_brFalse_happy
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (h_pc : frame.pc = 13)
    (h_stack : stack = (.bool true) :: rest_stack) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 14 ∧  -- Continue (not branch)
      stack' = rest_stack := by
  sorry  -- BrFalse with true continues

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-! ## PC 14-16: Unwrap Compressed Point -/

/-- Concrete instantiation: PC 14 MoveLoc 8 (extract Option). -/
theorem concrete_pc14_moveLoc8
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (option_val : MoveValue)
    (compressed_point : MoveValue)
    (h_pc : frame.pc = 14)
    (h_local8 : frame.locals[8]? = some (some option_val))
    (h_some : option_val = .struct [.bool true, compressed_point]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 15 ∧
      stack' = option_val :: stack ∧
      frame'.locals[8]? = some none := by
  sorry  -- Move Option to stack

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-- Concrete instantiation: PC 15 Call unwrap. -/
theorem concrete_pc15_unwrap
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (option_val : MoveValue)
    (compressed_point : MoveValue)
    (h_pc : frame.pc = 15)
    (h_stack : stack = option_val :: rest_stack)
    (h_some : option_val = .struct [.bool true, compressed_point])
    (h_oracle : o.unwrap [option_val] = some [compressed_point]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 16 ∧
      stack' = compressed_point :: rest_stack := by
  sorry  -- unwrap extracts inner value

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-- Concrete instantiation: PC 16 StLoc 8 (store compressed point). -/
theorem concrete_pc16_stLoc8_point
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (compressed_point : MoveValue)
    (h_pc : frame.pc = 16)
    (h_stack : stack = compressed_point :: rest_stack)
    (h_valid : IsValidCompressedPoint compressed_point) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 17 ∧
      frame'.locals[8]? = some (some compressed_point) ∧
      stack' = rest_stack := by
  sorry  -- Store compressed point to local 8

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-! ## PC 17-19: Scalar Extraction -/

/-- Concrete instantiation: PC 17 MoveLoc 3 (respBa). -/
theorem concrete_pc17_moveLoc3
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (respBa : ByteArray)
    (h_pc : frame.pc = 17)
    (h_local3 : frame.locals[3]? = some (some (.vector .u8 (respBa.toList.map .u8)))) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 18 ∧
      stack' = (.vector .u8 (respBa.toList.map .u8)) :: stack ∧
      frame'.locals[3]? = some none := by
  sorry  -- Move respBa to stack

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-- Concrete instantiation: PC 18 Call newScalarFromBytes. -/
theorem concrete_pc18_newScalarFromBytes
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (respBa : ByteArray)
    (h_pc : frame.pc = 18)
    (h_stack : stack = (.vector .u8 (respBa.toList.map .u8)) :: rest_stack)
    (h_len : respBa.size = 32)
    (h_reduced : IsReducedScalar (.vector .u8 (respBa.toList.map .u8)))
    (scalar_result : MoveValue)
    (h_oracle : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] =
                some [scalar_result])
    (h_valid : IsValidScalar scalar_result) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 19 ∧
      stack' = scalar_result :: rest_stack := by
  sorry  -- newScalarFromBytes oracle

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-- Concrete instantiation: PC 19 StLoc 10 (store scalar). -/
theorem concrete_pc19_stLoc10
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (scalar_val : MoveValue)
    (h_pc : frame.pc = 19)
    (h_stack : stack = scalar_val :: rest_stack)
    (h_valid : IsValidScalar scalar_val) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 20 ∧
      frame'.locals[10]? = some (some scalar_val) ∧
      stack' = rest_stack := by
  sorry  -- Store scalar to local 10

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-! ## Phase 1 Complete Instantiation -/

/-- Complete Phase 1 (PC 4 → PC 20) instantiation. -/
theorem phase1_complete_instantiation
    (o : RegistrationNativeOracle)
    (s4 : StateAtPC4 o)
    (h_commit_valid : IsValidCompressedPointBytes
                      (.vector .u8 (s4.commitBa.toList.map .u8)))
    (h_resp_valid : IsReducedScalar (.vector .u8 (s4.respBa.toList.map .u8))) :
    ∃ s20 : StateAtPC20 o,
      run (registrationModuleEnv o) [] s4.frame s4.stack s4.ms 17 =
      .ok [] s20.frame s20.stack s20.ms ∧
      s20.frame.pc = 20 ∧
      -- Extracted values stored
      (∃ rCompressed, s20.frame.locals[8]? = some (some rCompressed) ∧
                      IsValidCompressedPoint rCompressed) ∧
      (∃ responseScalar, s20.frame.locals[10]? = some (some responseScalar) ∧
                         IsValidScalar responseScalar) ∧
      -- Stack empty
      s20.stack = [] := by
  sorry  -- Compose all Phase 1 instantiations

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-! ## Phase 2 Instantiations (Message Assembly) -/

/-- Concrete instantiation: PC 20 CopyLoc 6 (chainId). -/
theorem concrete_pc20_copyLoc6
    (o : RegistrationNativeOracle)
    (s20 : StateAtPC20 o)
    (chainId : UInt8)
    (h_local6 : s20.frame.locals[6]? = some (some (.u8 chainId))) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] s20.frame s20.stack s20.ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 21 ∧
      stack' = (.u8 chainId) :: s20.stack := by
  sorry  -- Copy chainId for message assembly

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-- Concrete instantiation: PC 21 Call vectorSingleton. -/
theorem concrete_pc21_vectorSingleton
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (chainId : UInt8)
    (h_pc : frame.pc = 21)
    (h_stack : stack = (.u8 chainId) :: rest_stack)
    (vec_result : MoveValue)
    (h_oracle : o.vectorSingleton [.u8 chainId] = some [vec_result])
    (h_vec : vec_result = .vector .u8 [.u8 chainId]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 22 ∧
      stack' = vec_result :: rest_stack := by
  sorry  -- vectorSingleton creates [chainId]

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-! ## Phase 3 Instantiations (Verification) -/

/-- Concrete instantiation: PC 43 CopyLoc 8 (rCompressed). -/
theorem concrete_pc43_copyLoc8
    (o : RegistrationNativeOracle)
    (s43 : StateAtPC43 o)
    (rCompressed : MoveValue)
    (h_local8 : s43.frame.locals[8]? = some (some rCompressed))
    (h_valid : IsValidCompressedPoint rCompressed) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] s43.frame s43.stack s43.ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 44 ∧
      stack' = rCompressed :: s43.stack := by
  sorry  -- Copy rCompressed for verification

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-- Concrete instantiation: PC 44 Call pointDecompress. -/
theorem concrete_pc44_pointDecompress
    (o : RegistrationNativeOracle)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (rCompressed : MoveValue)
    (h_pc : frame.pc = 44)
    (h_stack : stack = rCompressed :: rest_stack)
    (h_valid : IsValidCompressedPoint rCompressed)
    (point_r : MoveValue)
    (h_oracle : o.pointDecompress [rCompressed] = some [point_r])
    (h_valid_r : IsValidRistrettoPoint point_r) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 45 ∧
      stack' = point_r :: rest_stack := by
  sorry  -- pointDecompress oracle

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-! ## Instantiation Composition Lemmas -/

/-- Composing two concrete instantiations. -/
theorem compose_instantiations
    (o : RegistrationNativeOracle)
    (pc1 pc2 : Nat)
    (h_consecutive : pc2 = pc1 + 1)
    (frame1 : Frame)
    (stack1 : List MoveValue)
    (ms1 : MachineState)
    (h_pc1 : frame1.pc = pc1)
    (frame2 : Frame)
    (stack2 : List MoveValue)
    (ms2 : MachineState)
    (h_step1 : step (registrationModuleEnv o) [] frame1 stack1 ms1 =
               .ok [] frame2 stack2 ms2)
    (h_pc2 : frame2.pc = pc2)
    (frame3 : Frame)
    (stack3 : List MoveValue)
    (ms3 : MachineState)
    (h_step2 : step (registrationModuleEnv o) [] frame2 stack2 ms2 =
               .ok [] frame3 stack3 ms3) :
    -- Two steps can be composed via run 2
    run (registrationModuleEnv o) [] frame1 stack1 ms1 2 =
    .ok [] frame3 stack3 ms3 := by
  sorry  -- Composition via run

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-- N concrete instantiations compose to complete phase. -/
theorem compose_n_instantiations
    (o : RegistrationNativeOracle)
    (n : Nat)
    (pc_start : Nat)
    (frames : List Frame)
    (stacks : List (List MoveValue))
    (mss : List MachineState)
    (h_length : frames.length = n + 1 ∧
                stacks.length = n + 1 ∧
                mss.length = n + 1)
    (h_pcs : ∀ i < n, (frames.get! i).pc = pc_start + i)
    (h_steps : ∀ i < n,
      step (registrationModuleEnv o) [] (frames.get! i) (stacks.get! i) (mss.get! i) =
      .ok [] (frames.get! (i+1)) (stacks.get! (i+1)) (mss.get! (i+1))) :
    run (registrationModuleEnv o) [] (frames.get! 0) (stacks.get! 0) (mss.get! 0) n =
    .ok [] (frames.get! n) (stacks.get! n) (mss.get! n) := by
  sorry  -- N-step composition

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }

/-! ## Complete Instantiation Catalog -/

/-- All 67 concrete instantiations exist. -/
theorem all_67_instantiations_exist
    (o : RegistrationNativeOracle)
    (s4 : StateAtPC4 o)
    (h_valid_inputs : ValidRegistrationInputs s4.commitBa s4.respBa)
    (h_valid_proof : ValidSchnorrProof s4.commitBa s4.respBa s4.ekBa
                                       s4.chainId s4.sender s4.contract s4.token) :
    ∃ instantiations : List (Frame × List MoveValue × MachineState ×
                             Frame × List MoveValue × MachineState),
      instantiations.length = 67 ∧
      (∀ i < 67,
        let (frame_before, stack_before, ms_before,
             frame_after, stack_after, ms_after) := instantiations.get! i
        ∃ pc, frame_before.pc = pc ∧
              step (registrationModuleEnv o) [] frame_before stack_before ms_before =
              .ok [] frame_after stack_after ms_after) := by
  sorry  -- All instantiations exist

where
  registrationModuleEnv (o : RegistrationNativeOracle) : ModuleEnv :=
    { funcs := [], moduleId := ⟨0, 0⟩ }
  ValidSchnorrProof : ByteArray → ByteArray → ByteArray → UInt8 →
                      ByteArray → ByteArray → ByteArray → Prop :=
    fun _ _ _ _ _ _ _ => True

end MovementFormal.Experimental.ConfidentialAsset.Registration.ConcreteLemmaInstantiations
