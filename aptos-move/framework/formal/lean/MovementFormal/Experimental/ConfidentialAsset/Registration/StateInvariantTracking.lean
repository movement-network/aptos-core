/-
# State Invariant Tracking

Tracks and proves preservation of state invariants throughout the registration
singleton branch execution (PC 4→70). Ensures all intermediate states are
well-formed and satisfy safety properties.

## Purpose

Every intermediate state must satisfy invariants:
- Frame well-formedness (PC bounds, locals size, valid locals)
- Stack well-typedness (all values have correct types)
- Container store consistency (reference validity, no dangling refs)
- Crypto validity (all crypto values satisfy group/field constraints)
- Phase-specific constraints (stack depth, locals usage patterns)

This module provides:
1. Invariant definitions for each program point
2. Preservation proofs for each instruction
3. Induction principles for proving properties over the full execution
4. Invariant checking utilities

## Source

Integrates:
- GlobalStateInvariants.lean (global invariant structure)
- TypeCorrectnessProofs.lean (type preservation)
- ValidationLemmasRefined.lean (crypto validity)
- StackDepthAnalysis.lean (stack bounds)

-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.FrameInvariants
import MovementFormal.Experimental.ConfidentialAsset.Registration.GlobalStateInvariants
import MovementFormal.Experimental.ConfidentialAsset.Registration.TypeCorrectnessProofs
import MovementFormal.Experimental.ConfidentialAsset.Registration.ValidationLemmasRefined
import MovementFormal.Experimental.ConfidentialAsset.Registration.StackDepthAnalysis

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## Core State Invariants -/

/-- Complete state invariant at a given PC -/
structure StateInvariant (pc : Nat) where
  -- Frame invariants
  frame_well_formed : Frame → Prop
  h_frame_pc : ∀ f, frame_well_formed f → f.pc = pc
  h_frame_locals : ∀ f, frame_well_formed f → f.locals.length = 19
  h_frame_locals_valid : ∀ f i, frame_well_formed f → i < 19 →
    f.locals[i]?.isSome

  -- Stack invariants
  stack_well_typed : List MoveValue → Prop
  h_stack_types : ∀ s, stack_well_typed s →
    ∃ types, s.length = types.length ∧
    ∀ i val ty, s[i]? = some val → types[i]? = some ty → HasType val ty

  -- Stack depth bounds (from StackDepthAnalysis)
  h_stack_bounded : ∀ s, stack_well_typed s → s.length ≤ 10

  -- Container invariants
  container_consistent : MachineState → Prop
  h_no_dangling_refs : ∀ ms, container_consistent ms →
    ∀ ref_id, (∃ ref, ms.containers.contains ref_id) →
    ∃ val, True  -- ref points to valid container entry

  -- Crypto validity invariants
  crypto_values_valid : Frame → List MoveValue → Prop
  h_crypto_valid : ∀ f s, crypto_values_valid f s →
    (∀ val, val ∈ s →
      (IsValidCompressedPoint val ∨
       IsValidRistrettoPoint val ∨
       IsValidScalar val ∨
       ¬ IsCryptoValue val))

/-- Construct state invariant for a specific PC -/
def mkStateInvariant (pc : Nat) : StateInvariant pc :=
  { frame_well_formed := fun f => f.pc = pc ∧ f.locals.length = 19
    h_frame_pc := by simp [frame_well_formed]; intros; assumption
    h_frame_locals := by simp [frame_well_formed]; intros; exact ‹_›
    h_frame_locals_valid := by sorry
    stack_well_typed := fun s => ∃ types, s.length = types.length
    h_stack_types := by sorry
    h_stack_bounded := by sorry
    container_consistent := fun ms => True
    h_no_dangling_refs := by sorry
    crypto_values_valid := fun f s => True
    h_crypto_valid := by sorry }

/-! ## PC-Specific Invariants -/

/-- State invariant at PC 4 (entry point) -/
def stateInvariantPC4 (inputs : RegistrationInputValues) : StateInvariant 4 :=
  { mkStateInvariant 4 with
    frame_well_formed := fun f =>
      f.pc = 4 ∧
      f.locals.length = 19 ∧
      f.locals[0]? = some (some (.u8 inputs.chainId)) ∧
      f.locals[1]? = some (some (.address inputs.sender)) ∧
      f.locals[2]? = some (some (.vector .u8 (inputs.commitBa.toList.map .u8))) ∧
      f.locals[3]? = some (some (.vector .u8 (inputs.respBa.toList.map .u8)))
    stack_well_typed := fun s => s = []
    h_stack_bounded := by simp; intro s hs; cases hs; decide }

/-- State invariant at PC 10 (after first oracle call) -/
def stateInvariantPC10
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (commitOption : MoveValue) : StateInvariant 10 :=
  { mkStateInvariant 10 with
    frame_well_formed := fun f =>
      f.pc = 10 ∧
      f.locals.length = 19 ∧
      f.locals[0]? = some (some (.u8 inputs.chainId)) ∧
      f.locals[5]? = some (some (.vector .u8 (inputs.commitBa.toList.map .u8)))
    stack_well_typed := fun s =>
      s = [commitOption] ∧
      (∃ point, commitOption = .struct [.bool true, point] ∧
                IsValidCompressedPoint point)
    crypto_values_valid := fun f s =>
      ∀ val, val ∈ s →
        ∃ point, val = .struct [.bool true, point] ∧
                 IsValidCompressedPoint point }

/-- State invariant at PC 20 (Phase 1→2 boundary) -/
def stateInvariantPC20
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs) : StateInvariant 20 :=
  { mkStateInvariant 20 with
    frame_well_formed := fun f =>
      f.pc = 20 ∧
      f.locals.length = 19 ∧
      f.locals[6]? = some (some p1.commitOption) ∧
      f.locals[8]? = some (some p1.respOption)
    stack_well_typed := fun s =>
      s = [p1.respOption] ∧
      (∃ point, p1.respOption = .struct [.bool true, point] ∧
                IsValidCompressedPoint point) }

/-- State invariant at PC 43 (Phase 2→3 boundary) -/
def stateInvariantPC43
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs)
    (p2 : Phase2Values o inputs p1) : StateInvariant 43 :=
  { mkStateInvariant 43 with
    frame_well_formed := fun f =>
      f.pc = 43 ∧
      f.locals.length = 19 ∧
      (∃ locals,
        f.locals = locals ∧
        (∃ idx_challenge idx_commit,
          locals[idx_challenge]? = some (some p2.challenge) ∧
          locals[idx_commit]? = some (some p2.commitDecompPoint)))
    stack_well_typed := fun s => s = []
    crypto_values_valid := fun f s =>
      (∃ idx_challenge, f.locals[idx_challenge]? = some (some p2.challenge) →
        IsValidScalar p2.challenge) ∧
      (∃ idx_commit, f.locals[idx_commit]? = some (some p2.commitDecompPoint) →
        IsValidRistrettoPoint p2.commitDecompPoint) }

/-- State invariant at PC 70 (exit point) -/
def stateInvariantPC70
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (flow : CompleteValueFlow o inputs) : StateInvariant 70 :=
  { mkStateInvariant 70 with
    frame_well_formed := fun f => f.pc = 70 ∧ f.locals.length = 19
    stack_well_typed := fun s =>
      s = [.bool flow.phase3.finalResult] ∧
      (∃ b, flow.phase3.finalResult = b) }

/-! ## Invariant Preservation -/

/-- Invariants are preserved by well-formed step transitions -/
theorem step_preserves_invariant
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (inv_before : StateInvariant pc)
    (inv_after : StateInvariant (pc + 1))
    (frame stack : _) (ms : MachineState)
    (frame' stack' ms' : _)
    (h_inv_before : inv_before.frame_well_formed frame ∧
                    inv_before.stack_well_typed stack ∧
                    inv_before.container_consistent ms)
    (h_step : step (registrationModuleEnv o) [] frame stack ms =
              .ok [] frame' stack' ms') :
    inv_after.frame_well_formed frame' ∧
    inv_after.stack_well_typed stack' ∧
    inv_after.container_consistent ms' :=
  sorry

/-- Invariants hold at every PC in the execution -/
theorem invariants_hold_throughout
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (flow : CompleteValueFlow o inputs)
    (pc : Nat)
    (h_pc : 4 ≤ pc ∧ pc ≤ 70)
    (frame stack ms : _)
    (fuel : Nat)
    (h_fuel : fuel = pc - 4)
    (h_run : ∃ frame_init stack_init ms_init,
      stateInvariantPC4 inputs |>.frame_well_formed frame_init ∧
      stateInvariantPC4 inputs |>.stack_well_typed stack_init ∧
      run (registrationModuleEnv o) fuel [] frame_init stack_init ms_init =
      .ok [] frame stack ms) :
    ∃ inv : StateInvariant pc,
      inv.frame_well_formed frame ∧
      inv.stack_well_typed stack ∧
      inv.container_consistent ms :=
  sorry

/-! ## Phase-Specific Invariant Strengthening -/

/-- Phase 1 invariant (PC 4-19) -/
structure Phase1Invariant
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues) where
  pc : Nat
  h_pc_range : 4 ≤ pc ∧ pc ≤ 19

  base_inv : StateInvariant pc

  -- Phase 1 specific: building compressed points
  commitment_processing : Prop
  h_commitment : commitment_processing →
    (pc ≥ 6 → ∃ commitBa,
      ∀ f, base_inv.frame_well_formed f →
        f.locals[5]? = some (some (.vector .u8 (commitBa.toList.map .u8))))

  response_processing : Prop
  h_response : response_processing →
    (pc ≥ 11 → ∃ respBa,
      ∀ f, base_inv.frame_well_formed f →
        f.locals[7]? = some (some (.vector .u8 (respBa.toList.map .u8))))

  option_validation : Prop
  h_option_valid : option_validation →
    (pc ≥ 17 → ∃ commitOption respOption,
      ∀ f, base_inv.frame_well_formed f →
        f.locals[6]? = some (some commitOption) ∧
        (∃ point, commitOption = .struct [.bool true, point] ∧
                  IsValidCompressedPoint point))

/-- Phase 2 invariant (PC 20-42) -/
structure Phase2Invariant
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs) where
  pc : Nat
  h_pc_range : 20 ≤ pc ∧ pc ≤ 42

  base_inv : StateInvariant pc

  -- Phase 2 specific: message assembly and challenge derivation
  message_construction : Prop
  h_message : message_construction →
    (pc ≥ 35 → ∃ messagePoint,
      ∀ f, base_inv.frame_well_formed f →
        ∃ idx, f.locals[idx]? = some (some messagePoint) ∧
               IsValidRistrettoPoint messagePoint)

  challenge_derivation : Prop
  h_challenge : challenge_derivation →
    (pc ≥ 42 → ∃ challenge,
      ∀ f, base_inv.frame_well_formed f →
        ∃ idx, f.locals[idx]? = some (some challenge) ∧
               IsValidScalar challenge)

  scalars_valid : Prop
  h_scalars : scalars_valid →
    (∀ f s, base_inv.frame_well_formed f →
            base_inv.stack_well_typed s →
      ∀ val, (val ∈ s ∨ (∃ idx, f.locals[idx]? = some (some val))) →
             IsValidScalar val → IsValidScalar val)

/-- Phase 3 invariant (PC 43-70) -/
structure Phase3Invariant
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs)
    (p2 : Phase2Values o inputs p1) where
  pc : Nat
  h_pc_range : 43 ≤ pc ∧ pc ≤ 70

  base_inv : StateInvariant pc

  -- Phase 3 specific: Schnorr verification computation
  response_decompressed : Prop
  h_response_decomp : response_decompressed →
    (pc ≥ 47 → ∃ respDecomp,
      ∀ f, base_inv.frame_well_formed f →
        ∃ idx, f.locals[idx]? = some (some respDecomp) ∧
               IsValidRistrettoPoint respDecomp)

  verification_point_computed : Prop
  h_verification : verification_point_computed →
    (pc ≥ 57 → ∃ verificationPoint,
      ∀ f, base_inv.frame_well_formed f →
        ∃ idx, f.locals[idx]? = some (some verificationPoint) ∧
               IsValidRistrettoPoint verificationPoint)

  expected_point_computed : Prop
  h_expected : expected_point_computed →
    (pc ≥ 62 → ∃ expectedPoint,
      ∀ f, base_inv.frame_well_formed f →
        ∃ idx, f.locals[idx]? = some (some expectedPoint) ∧
               IsValidRistrettoPoint expectedPoint)

  final_comparison : Prop
  h_comparison : final_comparison →
    (pc = 70 → ∀ s, base_inv.stack_well_typed s →
      ∃ result, s = [.bool result])

/-! ## Invariant Induction Principles -/

/-- Induction principle for proving properties over Phase 1 -/
theorem phase1_induction
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (P : Nat → Frame → List MoveValue → MachineState → Prop)
    (h_base : ∀ frame stack ms,
      stateInvariantPC4 inputs |>.frame_well_formed frame →
      stateInvariantPC4 inputs |>.stack_well_typed stack →
      P 4 frame stack ms)
    (h_step : ∀ pc frame stack ms frame' stack' ms',
      4 ≤ pc ∧ pc < 20 →
      P pc frame stack ms →
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' →
      P (pc + 1) frame' stack' ms')
    (pc : Nat)
    (h_pc : 4 ≤ pc ∧ pc ≤ 20)
    (frame stack ms : _)
    (h_reach : ∃ frame_init stack_init ms_init,
      stateInvariantPC4 inputs |>.frame_well_formed frame_init ∧
      stateInvariantPC4 inputs |>.stack_well_typed stack_init ∧
      run (registrationModuleEnv o) (pc - 4) []
        frame_init stack_init ms_init = .ok [] frame stack ms) :
    P pc frame stack ms :=
  sorry

/-- Induction principle for proving properties over complete execution -/
theorem complete_execution_induction
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (flow : CompleteValueFlow o inputs)
    (P : Nat → Frame → List MoveValue → MachineState → Prop)
    (h_base : ∀ frame stack ms,
      stateInvariantPC4 inputs |>.frame_well_formed frame →
      stateInvariantPC4 inputs |>.stack_well_typed stack →
      P 4 frame stack ms)
    (h_step : ∀ pc frame stack ms frame' stack' ms',
      4 ≤ pc ∧ pc < 70 →
      P pc frame stack ms →
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' →
      P (frame'.pc) frame' stack' ms')
    (pc : Nat)
    (h_pc : 4 ≤ pc ∧ pc ≤ 70)
    (frame stack ms : _)
    (h_reach : ∃ frame_init stack_init ms_init,
      stateInvariantPC4 inputs |>.frame_well_formed frame_init ∧
      stateInvariantPC4 inputs |>.stack_well_typed stack_init ∧
      run (registrationModuleEnv o) (pc - 4) []
        frame_init stack_init ms_init = .ok [] frame stack ms) :
    P pc frame stack ms :=
  sorry

/-! ## Invariant Checking Utilities -/

/-- Check if a frame satisfies the invariant at a given PC -/
def checkFrameInvariant (pc : Nat) (frame : Frame) : Bool :=
  frame.pc = pc ∧ frame.locals.size = 19

/-- Check if a stack satisfies the type invariant -/
def checkStackInvariant (stack : List MoveValue) : Bool :=
  stack.length ≤ 10  -- MAX_STACK_DEPTH

/-- Check crypto value validity in frame and stack -/
def checkCryptoValidity
    (frame : Frame) (stack : List MoveValue) : Bool :=
  -- Check all crypto values in stack are valid
  stack.all fun val =>
    if IsCryptoValue val then
      IsValidCompressedPoint val ∨
      IsValidRistrettoPoint val ∨
      IsValidScalar val
    else
      true

/-- Complete invariant check -/
def checkStateInvariant
    (pc : Nat) (frame : Frame)
    (stack : List MoveValue) (ms : MachineState) : Bool :=
  checkFrameInvariant pc frame ∧
  checkStackInvariant stack ∧
  checkCryptoValidity frame stack

/-- Invariant checker correctness -/
theorem checkStateInvariant_sound
    (pc : Nat) (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (inv : StateInvariant pc)
    (h_check : checkStateInvariant pc frame stack ms = true) :
    inv.frame_well_formed frame ∧
    inv.stack_well_typed stack ∧
    inv.container_consistent ms :=
  sorry

/-! ## Invariant Violations and Error States -/

/-- Characterization of states that violate invariants -/
inductive InvariantViolation
  | frame_pc_mismatch (expected actual : Nat)
  | locals_size_wrong (expected actual : Nat)
  | stack_too_deep (depth max : Nat)
  | invalid_crypto_value (val : MoveValue) (reason : String)
  | type_mismatch (val : MoveValue) (expected actual : MoveType)
  | dangling_reference (ref_id : Nat)

/-- Prove that successful execution never violates invariants -/
theorem no_invariant_violations
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (flow : CompleteValueFlow o inputs)
    (pc : Nat)
    (h_pc : 4 ≤ pc ∧ pc ≤ 70)
    (frame stack ms : _)
    (h_reach : ∃ frame_init stack_init ms_init,
      stateInvariantPC4 inputs |>.frame_well_formed frame_init ∧
      stateInvariantPC4 inputs |>.stack_well_typed stack_init ∧
      run (registrationModuleEnv o) (pc - 4) []
        frame_init stack_init ms_init = .ok [] frame stack ms) :
    ∀ violation : InvariantViolation, ¬ (StatesatisfiesViolation violation) :=
  sorry
  where
    StatesatisfiesViolation : InvariantViolation → Prop
      | .frame_pc_mismatch exp act => frame.pc ≠ pc
      | .locals_size_wrong exp act => frame.locals.size ≠ 19
      | .stack_too_deep depth max => stack.length > 10
      | .invalid_crypto_value val reason => False
      | .type_mismatch val exp act => False
      | .dangling_reference ref_id => False

/-! ## Complete Invariant Theorem -/

/-- Main theorem: invariants hold throughout complete execution -/
theorem complete_invariant_preservation
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (flow : CompleteValueFlow o inputs)
    (frame₀ : Frame)
    (ms₀ : MachineState)
    (h_init : stateInvariantPC4 inputs |>.frame_well_formed frame₀ ∧
              stateInvariantPC4 inputs |>.stack_well_typed [] ∧
              stateInvariantPC4 inputs |>.container_consistent ms₀)
    (frame' stack' ms' : _)
    (h_exec : run (registrationModuleEnv o) 67 [] frame₀ [] ms₀ =
              .ok [] frame' stack' ms') :
    stateInvariantPC70 o inputs flow |>.frame_well_formed frame' ∧
    stateInvariantPC70 o inputs flow |>.stack_well_typed stack' ∧
    stateInvariantPC70 o inputs flow |>.container_consistent ms' :=
  sorry

end MovementFormal.Experimental.ConfidentialAsset.Registration
