/-
# PC Range Proofs

Proofs for executing specific PC ranges in the registration singleton branch.
Provides lemmas for proving execution over ranges like PC 4→10, PC 10→20, etc.

## Range Categories

1. **Micro ranges**: 2-5 instructions (common patterns)
2. **Mini ranges**: 5-10 instructions (sub-phase segments)
3. **Phase ranges**: Complete phases (17, 23, 27 instructions)
4. **Complete range**: Full execution PC 4→70

## Range Composition

Ranges compose: PC 4→10 ∘ PC 10→20 = PC 4→20

## Source

Extends PCChainProofs.lean with range-based reasoning.

-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.Experimental.ConfidentialAsset.Registration.PCChainProofs
import MovementFormal.Experimental.ConfidentialAsset.Registration.ProofCompositionComplete

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## Range Specifications -/

/-- PC range specification -/
structure PCRange where
  start_pc : Nat
  end_pc : Nat
  fuel : Nat
  h_range : start_pc < end_pc
  h_in_bounds : 4 ≤ start_pc ∧ end_pc ≤ 70

/-- Execute PC range -/
def executeRange
    (o : RegistrationNativeOracle)
    (range : PCRange)
    (frame₀ : Frame) (stack₀ : List MoveValue) (ms₀ : MachineState)
    (h_pc : frame₀.pc = range.start_pc) :
    Option (Frame × List MoveValue × MachineState) :=
  match run (registrationModuleEnv o) range.fuel [] frame₀ stack₀ ms₀ with
  | .ok [] frame' stack' ms' =>
      if frame'.pc = range.end_pc then
        some (frame', stack', ms')
      else
        none
  | _ => none

/-! ## Micro Range Proofs (2-5 instructions) -/

/-- PC 4→6: CopyLoc chainId, StLoc -/
theorem pc4_to_6
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame₀ : Frame) (ms₀ : MachineState)
    (h_init : let (f, _, m) := constructInitialState inputs
              frame₀ = f ∧ ms₀ = m) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 2 [] frame₀ [] ms₀ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 6 ∧
      frame'.locals[4]? = some (some (.u8 inputs.chainId)) := by
  sorry

/-- PC 8→11: CopyLoc commit_ba, newCompressedPointFromBytes, StLoc -/
theorem pc8_to_11
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame₈ : Frame) (stack₈ : List MoveValue) (ms₈ : MachineState)
    (h_pc : frame₈.pc = 8)
    (h_local : frame₈.locals[5]? = some (some (.vector .u8 inputs.commitBa.data))) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 3 [] frame₈ stack₈ ms₈ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 11 ∧
      ∃ commitOpt, frame'.locals[6]? = some (some commitOpt) := by
  sorry

/-- PC 16→20: unwrap, StLoc, BrFalse (success path) -/
theorem pc16_to_20
    (o : RegistrationNativeOracle)
    (frame₁₆ : Frame) (stack₁₆ : List MoveValue) (ms₁₆ : MachineState)
    (h_pc : frame₁₆.pc = 16)
    (respOpt : MoveValue)
    (h_opt : respOpt = .struct [.bool true, sorry])
    (h_stack : stack₁₆ = [respOpt]) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 4 [] frame₁₆ stack₁₆ ms₁₆ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 20 := by
  sorry

/-! ## Mini Range Proofs (5-10 instructions) -/

/-- PC 4→11: Input setup through commit validation -/
theorem pc4_to_11
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame₀ : Frame) (ms₀ : MachineState)
    (h_init : let (f, _, m) := constructInitialState inputs
              frame₀ = f ∧ ms₀ = m) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 7 [] frame₀ [] ms₀ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 11 ∧
      ∃ commitOpt, frame'.locals[6]? = some (some commitOpt) := by
  sorry

/-- PC 11→20: Commit validation through Phase 1 completion -/
theorem pc11_to_20
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame₁₁ : Frame) (stack₁₁ : List MoveValue) (ms₁₁ : MachineState)
    (h_pc : frame₁₁.pc = 11)
    (commitOpt : MoveValue)
    (h_commit : frame₁₁.locals[6]? = some (some commitOpt))
    (h_valid : commitOpt = .struct [.bool true, sorry]) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 9 [] frame₁₁ stack₁₁ ms₁₁ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 20 := by
  sorry

/-- PC 20→30: Message assembly start -/
theorem pc20_to_30
    (o : RegistrationNativeOracle)
    (frame₂₀ : Frame) (stack₂₀ : List MoveValue) (ms₂₀ : MachineState)
    (h_pc : frame₂₀.pc = 20) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 10 [] frame₂₀ stack₂₀ ms₂₀ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 30 ∧
      ∃ term1, frame'.locals[14]? = some (some term1) := by
  sorry

/-- PC 30→40: Message assembly completion -/
theorem pc30_to_40
    (o : RegistrationNativeOracle)
    (frame₃₀ : Frame) (stack₃₀ : List MoveValue) (ms₃₀ : MachineState)
    (h_pc : frame₃₀.pc = 30) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 10 [] frame₃₀ stack₃₀ ms₃₀ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 40 ∧
      ∃ message_hash, frame'.locals[16]? = some (some message_hash) := by
  sorry

/-- PC 43→53: Schnorr computation start -/
theorem pc43_to_53
    (o : RegistrationNativeOracle)
    (frame₄₃ : Frame) (stack₄₃ : List MoveValue) (ms₄₃ : MachineState)
    (h_pc : frame₄₃.pc = 43) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 10 [] frame₄₃ stack₄₃ ms₄₃ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 53 := by
  sorry

/-- PC 60→70: Final verification -/
theorem pc60_to_70
    (o : RegistrationNativeOracle)
    (frame₆₀ : Frame) (stack₆₀ : List MoveValue) (ms₆₀ : MachineState)
    (h_pc : frame₆₀.pc = 60) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 10 [] frame₆₀ stack₆₀ ms₆₀ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 70 ∧
      ∃ result : Bool, stack' = [.bool result] := by
  sorry

/-! ## Sub-Phase Range Proofs -/

/-- Phase 1a: Input validation (PC 4→11) -/
theorem phase1a_input_validation
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues) :
    ∃ frame₀ ms₀ frame' stack' ms',
      let (f, _, m) := constructInitialState inputs
      frame₀ = f ∧ ms₀ = m ∧
      run (registrationModuleEnv o) 7 [] frame₀ [] ms₀ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 11 := by
  sorry

/-- Phase 1b: Validation completion (PC 11→20) -/
theorem phase1b_validation_complete
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame₁₁ : Frame) (stack₁₁ : List MoveValue) (ms₁₁ : MachineState)
    (h_pc : frame₁₁.pc = 11) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 9 [] frame₁₁ stack₁₁ ms₁₁ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 20 := by
  sorry

/-- Phase 2a: Message assembly (PC 20→35) -/
theorem phase2a_message_assembly
    (o : RegistrationNativeOracle)
    (frame₂₀ : Frame) (stack₂₀ : List MoveValue) (ms₂₀ : MachineState)
    (h_pc : frame₂₀.pc = 20) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 15 [] frame₂₀ stack₂₀ ms₂₀ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 35 ∧
      ∃ message_pt, frame'.locals[15]? = some (some message_pt) := by
  sorry

/-- Phase 2b: Challenge derivation (PC 35→43) -/
theorem phase2b_challenge_derivation
    (o : RegistrationNativeOracle)
    (frame₃₅ : Frame) (stack₃₅ : List MoveValue) (ms₃₅ : MachineState)
    (h_pc : frame₃₅.pc = 35) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 8 [] frame₃₅ stack₃₅ ms₃₅ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 43 ∧
      ∃ challenge_sc, frame'.locals[17]? = some (some challenge_sc) := by
  sorry

/-- Phase 3a: LHS computation (PC 43→56) -/
theorem phase3a_lhs_computation
    (o : RegistrationNativeOracle)
    (frame₄₃ : Frame) (stack₄₃ : List MoveValue) (ms₄₃ : MachineState)
    (h_pc : frame₄₃.pc = 43) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 13 [] frame₄₃ stack₄₃ ms₄₃ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 56 ∧
      ∃ lhs_pt, frame'.locals[18]? = some (some lhs_pt) := by
  sorry

/-- Phase 3b: RHS computation and verification (PC 56→70) -/
theorem phase3b_rhs_and_verify
    (o : RegistrationNativeOracle)
    (frame₅₆ : Frame) (stack₅₆ : List MoveValue) (ms₅₆ : MachineState)
    (h_pc : frame₅₆.pc = 56) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 14 [] frame₅₆ stack₅₆ ms₅₆ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 70 ∧
      ∃ result : Bool, stack' = [.bool result] := by
  sorry

/-! ## Range Composition Lemmas -/

/-- Compose Phase 1 sub-ranges -/
theorem compose_phase1_ranges
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (h_1a : phase1a_input_validation o inputs)
    (h_1b : ∀ frame₁₁ stack₁₁ ms₁₁,
      frame₁₁.pc = 11 →
      phase1b_validation_complete o inputs frame₁₁ stack₁₁ ms₁₁) :
    ∃ frame₀ ms₀ frame' stack' ms',
      let (f, _, m) := constructInitialState inputs
      frame₀ = f ∧ ms₀ = m ∧
      run (registrationModuleEnv o) 17 [] frame₀ [] ms₀ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 20 := by
  sorry

/-- Compose Phase 2 sub-ranges -/
theorem compose_phase2_ranges
    (o : RegistrationNativeOracle)
    (frame₂₀ : Frame) (stack₂₀ : List MoveValue) (ms₂₀ : MachineState)
    (h_pc : frame₂₀.pc = 20)
    (h_2a : phase2a_message_assembly o frame₂₀ stack₂₀ ms₂₀)
    (h_2b : ∀ frame₃₅ stack₃₅ ms₃₅,
      frame₃₅.pc = 35 →
      phase2b_challenge_derivation o frame₃₅ stack₃₅ ms₃₅) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 23 [] frame₂₀ stack₂₀ ms₂₀ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 43 := by
  sorry

/-- Compose Phase 3 sub-ranges -/
theorem compose_phase3_ranges
    (o : RegistrationNativeOracle)
    (frame₄₃ : Frame) (stack₄₃ : List MoveValue) (ms₄₃ : MachineState)
    (h_pc : frame₄₃.pc = 43)
    (h_3a : phase3a_lhs_computation o frame₄₃ stack₄₃ ms₄₃)
    (h_3b : ∀ frame₅₆ stack₅₆ ms₅₆,
      frame₅₆.pc = 56 →
      phase3b_rhs_and_verify o frame₅₆ stack₅₆ ms₅₆) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 27 [] frame₄₃ stack₄₃ ms₄₃ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 70 := by
  sorry

/-! ## Range Invariants -/

/-- Invariants preserved over ranges -/
theorem range_preserves_invariants
    (o : RegistrationNativeOracle)
    (range : PCRange)
    (inv : Nat → Frame → List MoveValue → MachineState → Prop)
    (frame₀ : Frame) (stack₀ : List MoveValue) (ms₀ : MachineState)
    (frame' : Frame) (stack' : List MoveValue) (ms' : MachineState)
    (h_exec : executeRange o range frame₀ stack₀ ms₀ sorry = some (frame', stack', ms'))
    (h_inv_start : inv range.start_pc frame₀ stack₀ ms₀)
    (h_preserve : ∀ pc frame stack ms frame' stack' ms',
      range.start_pc ≤ pc ∧ pc < range.end_pc →
      inv pc frame stack ms →
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' →
      inv (pc + 1) frame' stack' ms') :
    inv range.end_pc frame' stack' ms' := by
  sorry

/-! ## Complete Range Theorem -/

/-- Main theorem: Complete execution as range composition -/
theorem complete_execution_by_ranges
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (h_phase1 : phase1a_input_validation o inputs ∧
                ∀ f s m, phase1b_validation_complete o inputs f s m)
    (h_phase2 : ∀ f s m, phase2a_message_assembly o f s m ∧
                          phase2b_challenge_derivation o f s m)
    (h_phase3 : ∀ f s m, phase3a_lhs_computation o f s m ∧
                          phase3b_rhs_and_verify o f s m) :
    ∃ frame₀ ms₀ frame' stack' ms',
      let (f, _, m) := constructInitialState inputs
      frame₀ = f ∧ ms₀ = m ∧
      run (registrationModuleEnv o) 67 [] frame₀ [] ms₀ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 70 := by
  sorry

end MovementFormal.Experimental.ConfidentialAsset.Registration
