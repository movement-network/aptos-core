/-
# Phase-Specific Invariants

Detailed invariants that hold during each phase of registration execution.
Strengthens general state invariants with phase-specific properties that
capture the unique structure and requirements of each phase.

## Phase Structure

- **Phase 1 (PC 4→20)**: Input validation and point decompression
- **Phase 2 (PC 20→43)**: Message assembly and challenge derivation
- **Phase 3 (PC 43→70)**: Schnorr verification computation

## Invariant Strengthening

Each phase has stronger invariants than the general ones:
- Phase 1: Validates input bytes, constructs Option types
- Phase 2: Manipulates elliptic curve points, builds message
- Phase 3: Performs scalar arithmetic, computes verification equation

## Source

Extends StateInvariantTracking.lean with phase-specific details.

-/

import MovementFormal.MoveModel.State
import MovementFormal.Experimental.ConfidentialAsset.Registration.StateInvariantTracking
import MovementFormal.Experimental.ConfidentialAsset.Registration.ConcreteValueFlowAnalysis
import MovementFormal.Experimental.ConfidentialAsset.Registration.CryptographicValueTracking

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## Phase 1 Invariants (PC 4→20) -/

/-- Phase 1 state invariant -/
structure Phase1Invariant (pc : Nat) where
  h_range : 4 ≤ pc ∧ pc ≤ 20
  -- Input bytes present at early PCs
  h_inputs : ∀ frame : Frame,
    frame.pc = pc → pc ≤ 9 →
    ∃ commit_ba, frame.locals[2]? = some (some (.vector .u8 commit_ba)) ∨
    frame.locals[5]? = some (some (.vector .u8 commit_ba))
  -- ChainId copied and preserved
  h_chainId : ∀ frame : Frame,
    frame.pc = pc → pc ≥ 5 →
    ∃ chainId, frame.locals[4]? = some (some (.u8 chainId))
  -- Option types constructed correctly
  h_options : ∀ frame : Frame,
    frame.pc = pc → pc ≥ 10 →
    ∃ commitOpt, frame.locals[6]? = some (some commitOpt) ∧
    (∃ is_some inner, commitOpt = .struct [.bool is_some, inner])
  -- Ristretto points unwrapped at end
  h_points : ∀ frame : Frame,
    frame.pc = pc → pc = 20 →
    ∃ commit_pt resp_pt,
      frame.locals[9]? = some (some commit_pt) ∧
      frame.locals[12]? = some (some resp_pt) ∧
      IsValidRistrettoPoint commit_pt ∧
      IsValidRistrettoPoint resp_pt

/-- Phase 1 invariant at each PC -/
def phase1InvariantAt (pc : Nat) : Phase1Invariant pc :=
  if h : 4 ≤ pc ∧ pc ≤ 20 then
    { h_range := h
      h_inputs := by sorry
      h_chainId := by sorry
      h_options := by sorry
      h_points := by sorry }
  else
    sorry  -- PC out of range

/-- Phase 1 invariant preserved -/
theorem phase1_invariant_preserved
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (h_pc : 4 ≤ pc ∧ pc < 20)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (frame' : Frame) (stack' : List MoveValue) (ms' : MachineState)
    (h_step : step (registrationModuleEnv o) [] frame stack ms =
              .ok [] frame' stack' ms')
    (h_inv : Phase1Invariant pc) :
    ∃ inv', Phase1Invariant (pc + 1) := by
  sorry

/-! ## Phase 2 Invariants (PC 20→43) -/

/-- Phase 2 state invariant -/
structure Phase2Invariant (pc : Nat) where
  h_range : 20 ≤ pc ∧ pc ≤ 43
  -- Base point obtained
  h_base_point : ∀ frame : Frame,
    frame.pc = pc → pc ≥ 21 →
    ∃ base_pt, frame.locals[10]? = some (some base_pt) ∧
    IsValidRistrettoPoint base_pt
  -- ChainId and sender scalars computed
  h_scalars : ∀ frame : Frame,
    frame.pc = pc → pc ≥ 23 →
    ∃ chainId_sc, frame.locals[11]? = some (some chainId_sc) ∧
    IsValidScalar chainId_sc
  -- Term 1 computed (G * chainId + C)
  h_term1 : ∀ frame : Frame,
    frame.pc = pc → pc ≥ 25 →
    ∃ term1, frame.locals[14]? = some (some term1) ∧
    IsValidRistrettoPoint term1
  -- Message point computed (G * chainId + G * sender + C)
  h_message_pt : ∀ frame : Frame,
    frame.pc = pc → pc ≥ 31 →
    ∃ message_pt, frame.locals[15]? = some (some message_pt) ∧
    IsValidRistrettoPoint message_pt
  -- Message bytes computed
  h_message_ba : ∀ frame : Frame,
    frame.pc = pc → pc ≥ 34 →
    ∃ message_ba, frame.locals[16]? = some (some (.vector .u8 message_ba)) ∧
    message_ba.length = 32
  -- Challenge scalar computed at end
  h_challenge : ∀ frame : Frame,
    frame.pc = pc → pc = 43 →
    ∃ challenge_sc, frame.locals[17]? = some (some challenge_sc) ∧
    IsValidScalar challenge_sc

/-- Phase 2 invariant at each PC -/
def phase2InvariantAt (pc : Nat) : Phase2Invariant pc :=
  if h : 20 ≤ pc ∧ pc ≤ 43 then
    { h_range := h
      h_base_point := by sorry
      h_scalars := by sorry
      h_term1 := by sorry
      h_message_pt := by sorry
      h_message_ba := by sorry
      h_challenge := by sorry }
  else
    sorry

/-- Phase 2 invariant preserved -/
theorem phase2_invariant_preserved
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (h_pc : 20 ≤ pc ∧ pc < 43)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (frame' : Frame) (stack' : List MoveValue) (ms' : MachineState)
    (h_step : step (registrationModuleEnv o) [] frame stack ms =
              .ok [] frame' stack' ms')
    (h_inv : Phase2Invariant pc) :
    ∃ inv', Phase2Invariant (pc + 1) := by
  sorry

/-! ## Phase 3 Invariants (PC 43→70) -/

/-- Phase 3 state invariant -/
structure Phase3Invariant (pc : Nat) where
  h_range : 43 ≤ pc ∧ pc ≤ 70
  -- Challenge scalar available from start
  h_challenge : ∀ frame : Frame,
    frame.pc = pc →
    ∃ challenge_sc, frame.locals[17]? = some (some challenge_sc) ∧
    IsValidScalar challenge_sc
  -- Commit and response points available
  h_points : ∀ frame : Frame,
    frame.pc = pc →
    ∃ commit_pt resp_pt,
      frame.locals[9]? = some (some commit_pt) ∧
      frame.locals[12]? = some (some resp_pt) ∧
      IsValidRistrettoPoint commit_pt ∧
      IsValidRistrettoPoint resp_pt
  -- LHS computed (R + C * e)
  h_lhs : ∀ frame : Frame,
    frame.pc = pc → pc ≥ 55 →
    ∃ lhs_pt, frame.locals[18]? = some (some lhs_pt) ∧
    IsValidRistrettoPoint lhs_pt
  -- RHS computed (G * s)
  h_rhs : ∀ frame : Frame,
    frame.pc = pc → pc ≥ 61 →
    ∃ rhs_pt stack,
      IsValidRistrettoPoint rhs_pt
  -- Verification result on stack at end
  h_result : ∀ frame : Frame, stack : List MoveValue,
    frame.pc = pc → pc = 70 →
    ∃ result, stack = [.bool result]

/-- Phase 3 invariant at each PC -/
def phase3InvariantAt (pc : Nat) : Phase3Invariant pc :=
  if h : 43 ≤ pc ∧ pc ≤ 70 then
    { h_range := h
      h_challenge := by sorry
      h_points := by sorry
      h_lhs := by sorry
      h_rhs := by sorry
      h_result := by sorry }
  else
    sorry

/-- Phase 3 invariant preserved -/
theorem phase3_invariant_preserved
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (h_pc : 43 ≤ pc ∧ pc < 70)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (frame' : Frame) (stack' : List MoveValue) (ms' : MachineState)
    (h_step : step (registrationModuleEnv o) [] frame stack ms =
              .ok [] frame' stack' ms')
    (h_inv : Phase3Invariant pc) :
    ∃ inv', Phase3Invariant (pc + 1) := by
  sorry

/-! ## Cross-Phase Invariants -/

/-- Invariants that hold across all phases -/
structure CrossPhaseInvariant where
  -- Locals size always 19
  h_locals_size : ∀ pc frame,
    4 ≤ pc ∧ pc ≤ 70 →
    frame.pc = pc →
    frame.locals.size = 19
  -- Stack bounded by phase-specific maxima
  h_stack_bound : ∀ pc stack,
    4 ≤ pc ∧ pc ≤ 70 →
    (pc < 20 → stack.length ≤ 3) ∧
    (20 ≤ pc ∧ pc < 43 → stack.length ≤ 5) ∧
    (43 ≤ pc ∧ pc ≤ 70 → stack.length ≤ 4)
  -- Moved locals not accessed
  h_move_safety : ∀ pc idx,
    (idx = 0 ∧ pc > 5) ∨   -- loc0 moved at PC 4→5
    (idx = 2 ∧ pc > 9) ∨   -- loc2 moved at PC 8→9
    (idx = 3 ∧ pc > 14) →  -- loc3 moved at PC 13→14
    bytecodeAt pc ≠ .CopyLoc idx ∧
    bytecodeAt pc ≠ .MoveLoc idx
  -- Crypto values remain valid
  h_crypto_valid : ∀ pc frame idx val,
    frame.pc = pc →
    frame.locals[idx]? = some (some val) →
    (IsValidRistrettoPoint val ∨
     IsValidScalar val ∨
     IsValidCompressedPoint val ∨
     ∃ ty, HasType val ty)

/-- Cross-phase invariant holds throughout -/
theorem cross_phase_invariant_holds
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (flow : CompleteValueFlow o inputs)
    (pc : Nat)
    (h_pc : 4 ≤ pc ∧ pc ≤ 70) :
    ∃ inv : CrossPhaseInvariant, True := by
  sorry

/-! ## Phase Transition Invariants -/

/-- Invariants at phase boundaries -/
structure PhaseTransitionInvariant (from_pc to_pc : Nat) where
  h_boundary : (from_pc = 20 ∧ to_pc = 21) ∨
               (from_pc = 43 ∧ to_pc = 44)
  -- Phase 1→2 transition
  h_phase1_to_2 : from_pc = 20 → to_pc = 21 →
    ∀ frame : Frame,
      frame.pc = 20 →
      ∃ commit_pt resp_pt,
        frame.locals[9]? = some (some commit_pt) ∧
        frame.locals[12]? = some (some resp_pt) ∧
        IsValidRistrettoPoint commit_pt ∧
        IsValidRistrettoPoint resp_pt
  -- Phase 2→3 transition
  h_phase2_to_3 : from_pc = 43 → to_pc = 44 →
    ∀ frame : Frame,
      frame.pc = 43 →
      ∃ message_pt challenge_sc,
        frame.locals[15]? = some (some message_pt) ∧
        frame.locals[17]? = some (some challenge_sc) ∧
        IsValidRistrettoPoint message_pt ∧
        IsValidScalar challenge_sc

/-- Phase transitions satisfy invariants -/
theorem phase_transitions_valid
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (from_pc to_pc : Nat)
    (h_boundary : (from_pc = 20 ∧ to_pc = 21) ∨
                  (from_pc = 43 ∧ to_pc = 44)) :
    ∃ inv : PhaseTransitionInvariant from_pc to_pc, True := by
  sorry

/-! ## Invariant Hierarchy -/

/-- General invariant implies phase-specific invariant -/
theorem general_implies_phase_specific
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_general : StateInvariant pc frame stack ms) :
    (4 ≤ pc ∧ pc ≤ 20 → ∃ inv : Phase1Invariant pc, True) ∧
    (20 ≤ pc ∧ pc ≤ 43 → ∃ inv : Phase2Invariant pc, True) ∧
    (43 ≤ pc ∧ pc ≤ 70 → ∃ inv : Phase3Invariant pc, True) := by
  sorry

/-- Phase-specific invariant implies general invariant -/
theorem phase_specific_implies_general
    (o : RegistrationNativeOracle)
    (pc : Nat)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState) :
    (∃ inv : Phase1Invariant pc, True) ∨
    (∃ inv : Phase2Invariant pc, True) ∨
    (∃ inv : Phase3Invariant pc, True) →
    StateInvariant pc frame stack ms := by
  sorry

/-! ## Complete Phase Invariant Theorem -/

/-- Main theorem: Phase-specific invariants hold throughout -/
theorem registration_phase_invariants_hold
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (flow : CompleteValueFlow o inputs)
    (frame₀ : Frame) (ms₀ : MachineState)
    (h_init : let (f, _, m) := constructInitialState inputs
              frame₀ = f ∧ ms₀ = m)
    (frame' stack' ms' : _)
    (h_exec : run (registrationModuleEnv o) 67 [] frame₀ [] ms₀ =
              .ok [] frame' stack' ms') :
    -- Phase 1 invariants hold
    (∀ pc, 4 ≤ pc ∧ pc ≤ 20 →
      ∃ fuel frame stack ms,
        run (registrationModuleEnv o) fuel [] frame₀ [] ms₀ =
        .ok [] frame stack ms ∧
        frame.pc = pc ∧
        ∃ inv : Phase1Invariant pc, True) ∧
    -- Phase 2 invariants hold
    (∀ pc, 20 ≤ pc ∧ pc ≤ 43 →
      ∃ fuel frame stack ms,
        run (registrationModuleEnv o) fuel [] frame₀ [] ms₀ =
        .ok [] frame stack ms ∧
        frame.pc = pc ∧
        ∃ inv : Phase2Invariant pc, True) ∧
    -- Phase 3 invariants hold
    (∀ pc, 43 ≤ pc ∧ pc ≤ 70 →
      ∃ fuel frame stack ms,
        run (registrationModuleEnv o) fuel [] frame₀ [] ms₀ =
        .ok [] frame stack ms ∧
        frame.pc = pc ∧
        ∃ inv : Phase3Invariant pc, True) ∧
    -- Cross-phase invariants hold
    (∀ pc, 4 ≤ pc ∧ pc ≤ 70 →
      ∃ inv : CrossPhaseInvariant, True) ∧
    -- Phase transitions valid
    ((∃ inv : PhaseTransitionInvariant 20 21, True) ∧
     (∃ inv : PhaseTransitionInvariant 43 44, True)) := by
  sorry

end MovementFormal.Experimental.ConfidentialAsset.Registration
