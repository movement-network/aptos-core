/-
# Run Composition Lemmas

Infrastructure for composing sequential `run` executions. Essential for
building phase proofs from individual PC proofs.

## Key Lemmas

1. **run_succ**: Decompose run (n+1) into step + run n
2. **run_compose**: Compose run n + run m = run (n+m)
3. **run_split**: Split run (n+m) into run n + run m
4. **run_deterministic**: Same inputs → same outputs
5. **run_monotonic**: More fuel → same or more progress

## Applications

- Compose 67 PC proofs into single PC 4→70 proof
- Compose phase proofs: Phase1 (17) + Phase2 (23) + Phase3 (27) = 67
- Enable incremental proof construction

## Source

Fundamental infrastructure for proof composition.

-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.Native.Registration

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

-- Temporary: registrationModuleEnv would normally come from ModuleEnvProperties,
-- but that file currently has build errors. Declare as axiom for now.
axiom registrationModuleEnv : RegistrationNativeOracle → ModuleEnv

/-! ## Basic Run Decomposition -/

/-- Decompose run (n+1) into step followed by run n -/
theorem run_succ_decomposition
    (env : ModuleEnv)
    (n : Nat)
    (frame₀ : Frame) (stack₀ : List MoveValue) (ms₀ : MachineState)
    (frame' : Frame) (stack' : List MoveValue) (ms' : MachineState)
    (h : run env frame₀ [] stack₀ ms₀ (n + 1) = ExecResult.ok frame' [] stack' ms') :
    ∃ frame₁ stack₁ ms₁,
      step env frame₀ [] stack₀ ms₀ = ExecResult.ok frame₁ [] stack₁ ms₁ ∧
      run env frame₁ [] stack₁ ms₁ n = ExecResult.ok frame' [] stack' ms' := by
  sorry

/-- Compose step with run n -/
theorem step_then_run
    (env : ModuleEnv)
    (n : Nat)
    (frame₀ : Frame) (stack₀ : List MoveValue) (ms₀ : MachineState)
    (frame₁ : Frame) (stack₁ : List MoveValue) (ms₁ : MachineState)
    (frame' : Frame) (stack' : List MoveValue) (ms' : MachineState)
    (h_step : step env frame₀ [] stack₀ ms₀ = ExecResult.ok frame₁ [] stack₁ ms₁)
    (h_run : run env frame₁ [] stack₁ ms₁ n = ExecResult.ok frame' [] stack' ms') :
    run env frame₀ [] stack₀ ms₀ (n + 1) = ExecResult.ok frame' [] stack' ms' := by
  sorry

/-! ## Sequential Composition -/

/-- Compose two sequential runs -/
theorem run_sequential_compose
    (env : ModuleEnv)
    (n m : Nat)
    (frame₀ : Frame) (stack₀ : List MoveValue) (ms₀ : MachineState)
    (frame₁ : Frame) (stack₁ : List MoveValue) (ms₁ : MachineState)
    (frame₂ : Frame) (stack₂ : List MoveValue) (ms₂ : MachineState)
    (h₁ : run env frame₀ [] stack₀ ms₀ n = ExecResult.ok frame₁ [] stack₁ ms₁)
    (h₂ : run env frame₁ [] stack₁ ms₁ m = ExecResult.ok frame₂ [] stack₂ ms₂) :
    run env frame₀ [] stack₀ ms₀ (n + m) = ExecResult.ok frame₂ [] stack₂ ms₂ := by
  sorry

/-- Compose three sequential runs -/
theorem run_three_compose
    (env : ModuleEnv)
    (n₁ n₂ n₃ : Nat)
    (f₀ f₁ f₂ f₃ : Frame)
    (s₀ s₁ s₂ s₃ : List MoveValue)
    (m₀ m₁ m₂ m₃ : MachineState)
    (h₁ : run env f₀ [] s₀ m₀ n₁ = ExecResult.ok f₁ [] s₁ m₁)
    (h₂ : run env f₁ [] s₁ m₁ n₂ = ExecResult.ok f₂ [] s₂ m₂)
    (h₃ : run env f₂ [] s₂ m₂ n₃ = ExecResult.ok f₃ [] s₃ m₃) :
    run env f₀ [] s₀ m₀ (n₁ + n₂ + n₃) = ExecResult.ok f₃ [] s₃ m₃ := by
  -- Compose first two
  have h₁₂ := run_sequential_compose env n₁ n₂ f₀ s₀ m₀ f₁ s₁ m₁ f₂ s₂ m₂ h₁ h₂
  -- Compose result with third
  have h := run_sequential_compose env (n₁ + n₂) n₃ f₀ s₀ m₀ f₂ s₂ m₂ f₃ s₃ m₃ h₁₂ h₃
  -- Arithmetic: (n₁ + n₂) + n₃ = n₁ + n₂ + n₃ (both left-associate)
  exact h

/-! ## Run Splitting -/

/-- Split run (n+m) into two sequential runs -/
theorem run_split
    (env : ModuleEnv)
    (n m : Nat)
    (frame₀ : Frame) (stack₀ : List MoveValue) (ms₀ : MachineState)
    (frame₂ : Frame) (stack₂ : List MoveValue) (ms₂ : MachineState)
    (h : run env frame₀ [] stack₀ ms₀ (n + m) = ExecResult.ok frame₂ [] stack₂ ms₂) :
    ∃ frame₁ stack₁ ms₁,
      run env frame₀ [] stack₀ ms₀ n = ExecResult.ok frame₁ [] stack₁ ms₁ ∧
      run env frame₁ [] stack₁ ms₁ m = ExecResult.ok frame₂ [] stack₂ ms₂ := by
  sorry

/-! ## Determinism -/

/-- Run is deterministic: same inputs → same outputs -/
theorem run_deterministic
    (env : ModuleEnv)
    (n : Nat)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (frame₁ stack₁ ms₁ frame₂ stack₂ ms₂ : _)
    (h₁ : run env frame [] stack ms n = ExecResult.ok frame₁ [] stack₁ ms₁)
    (h₂ : run env frame [] stack ms n = ExecResult.ok frame₂ [] stack₂ ms₂) :
    frame₁ = frame₂ ∧ stack₁ = stack₂ ∧ ms₁ = ms₂ := by
  sorry

/-! ## Monotonicity -/

/-- More fuel gives same or more progress -/
theorem run_fuel_monotonic
    (env : ModuleEnv)
    (n m : Nat)
    (h_le : n ≤ m)
    (frame₀ : Frame) (stack₀ : List MoveValue) (ms₀ : MachineState)
    (frame_n stack_n ms_n : _)
    (h_n : run env frame₀ [] stack₀ ms₀ n = ExecResult.ok frame_n [] stack_n ms_n) :
    ∃ frame_m stack_m ms_m,
      run env frame₀ [] stack₀ ms₀ m = ExecResult.ok frame_m [] stack_m ms_m ∧
      frame_n.pc ≤ frame_m.pc := by
  sorry

/-! ## PC Progress -/

/-- Run n steps advances PC by exactly n (in straight-line code) -/
theorem run_pc_progress_straightline
    (env : ModuleEnv)
    (n : Nat)
    (pc_start : Nat)
    (frame₀ : Frame) (stack₀ : List MoveValue) (ms₀ : MachineState)
    (frame' : Frame) (stack' : List MoveValue) (ms' : MachineState)
    (h_pc : frame₀.pc = pc_start)
    (h_run : run env frame₀ [] stack₀ ms₀ n = ExecResult.ok frame' [] stack' ms')
    -- Assumes straight-line code (no branches)
    : frame'.pc = pc_start + n := by
  sorry

/-! ## Registration-Specific Instances -/

/-- Phase 1: 17 steps from PC 4 to PC 20 -/
theorem phase1_run_composition
    (o : RegistrationNativeOracle)
    (frame₄ : Frame) (ms₄ : MachineState)
    (frame₂₀ : Frame) (stack₂₀ : List MoveValue) (ms₂₀ : MachineState)
    (h : run (registrationModuleEnv o) frame₄ [] [] ms₄ 17 =
         ExecResult.ok frame₂₀ [] stack₂₀ ms₂₀) :
    frame₄.pc = 4 → frame₂₀.pc = 20 := by
  intro h_pc
  -- Apply straightline progress (Phase 1 has 2 branches but they're taken)
  sorry

/-- Phase 2: 23 steps from PC 20 to PC 43 -/
theorem phase2_run_composition
    (o : RegistrationNativeOracle)
    (frame₂₀ : Frame) (ms₂₀ : MachineState)
    (frame₄₃ : Frame) (stack₄₃ : List MoveValue) (ms₄₃ : MachineState)
    (h : run (registrationModuleEnv o) frame₂₀ [] [] ms₂₀ 23 =
         ExecResult.ok frame₄₃ [] stack₄₃ ms₄₃) :
    frame₂₀.pc = 20 → frame₄₃.pc = 43 := by
  sorry

/-- Phase 3: 27 steps from PC 43 to PC 70 -/
theorem phase3_run_composition
    (o : RegistrationNativeOracle)
    (frame₄₃ : Frame) (ms₄₃ : MachineState)
    (frame₇₀ : Frame) (stack₇₀ : List MoveValue) (ms₇₀ : MachineState)
    (h : run (registrationModuleEnv o) frame₄₃ [] [] ms₄₃ 27 =
         ExecResult.ok frame₇₀ [] stack₇₀ ms₇₀) :
    frame₄₃.pc = 43 → frame₇₀.pc = 70 := by
  sorry

/-- Complete execution: 67 steps from PC 4 to PC 70 -/
theorem complete_run_composition
    (o : RegistrationNativeOracle)
    (frame₄ : Frame) (ms₄ : MachineState)
    (frame₂₀ : Frame) (stack₂₀ : List MoveValue) (ms₂₀ : MachineState)
    (frame₄₃ : Frame) (stack₄₃ : List MoveValue) (ms₄₃ : MachineState)
    (frame₇₀ : Frame) (stack₇₀ : List MoveValue) (ms₇₀ : MachineState)
    (h₁ : run (registrationModuleEnv o) frame₄ [] [] ms₄ 17 =
          ExecResult.ok frame₂₀ [] stack₂₀ ms₂₀)
    (h₂ : run (registrationModuleEnv o) frame₂₀ [] stack₂₀ ms₂₀ 23 =
          ExecResult.ok frame₄₃ [] stack₄₃ ms₄₃)
    (h₃ : run (registrationModuleEnv o) frame₄₃ [] stack₄₃ ms₄₃ 27 =
          ExecResult.ok frame₇₀ [] stack₇₀ ms₇₀) :
    run (registrationModuleEnv o) frame₄ [] [] ms₄ 67 =
    ExecResult.ok frame₇₀ [] stack₇₀ ms₇₀ := by
  -- Use three-way composition
  have h := run_three_compose (registrationModuleEnv o) 17 23 27
    frame₄ frame₂₀ frame₄₃ frame₇₀
    [] stack₂₀ stack₄₃ stack₇₀
    ms₄ ms₂₀ ms₄₃ ms₇₀
    h₁ h₂ h₃
  -- 17 + 23 + 27 = 67
  simp only [show 17 + 23 + 27 = 67 from by omega] at h
  exact h

/-! ## Incremental Composition -/

/-- Build run (n+1) from run n and one step proof -/
theorem run_extend_by_one
    (env : ModuleEnv)
    (n : Nat)
    (pc : Nat)
    (frame₀ : Frame) (stack₀ : List MoveValue) (ms₀ : MachineState)
    (frame_n : Frame) (stack_n : List MoveValue) (ms_n : MachineState)
    (frame' : Frame) (stack' : List MoveValue) (ms' : MachineState)
    (h_run_n : run env frame₀ [] stack₀ ms₀ n = ExecResult.ok frame_n [] stack_n ms_n)
    (h_pc : frame_n.pc = pc)
    (h_step : step env frame_n [] stack_n ms_n = ExecResult.ok frame' [] stack' ms') :
    run env frame₀ [] stack₀ ms₀ (n + 1) = ExecResult.ok frame' [] stack' ms' := by
  -- Need to compose run n + step, but step_then_run gives step + run n
  -- Use run_split and determinism instead
  sorry

/-- Chain multiple single-step extensions -/
theorem run_chain_steps
    (env : ModuleEnv)
    (n : Nat)
    (frame₀ : Frame) (stack₀ : List MoveValue) (ms₀ : MachineState)
    (step_proofs : ∀ k, k < n →
      ∀ frame_k stack_k ms_k,
        run env frame₀ [] stack₀ ms₀ k = ExecResult.ok frame_k [] stack_k ms_k →
        ∃ frame_next stack_next ms_next,
          step env frame_k [] stack_k ms_k = ExecResult.ok frame_next [] stack_next ms_next) :
    ∃ frame' stack' ms',
      run env frame₀ [] stack₀ ms₀ n = ExecResult.ok frame' [] stack' ms' := by
  sorry

/-! ## Application to PC Proofs -/

/-- Compose 67 individual PC proofs into complete execution -/
theorem compose_all_pc_proofs
    (o : RegistrationNativeOracle)
    (pc_proofs : ∀ pc, 4 ≤ pc ∧ pc < 70 →
      ∀ frame stack ms,
        frame.pc = pc →
        ∃ frame' stack' ms',
          step (registrationModuleEnv o) frame [] stack ms =
          ExecResult.ok frame' [] stack' ms' ∧
          frame'.pc = pc + 1)
    (frame₄ : Frame) (ms₄ : MachineState)
    (h_pc : frame₄.pc = 4) :
    ∃ frame₇₀ stack₇₀ ms₇₀,
      run (registrationModuleEnv o) frame₄ [] [] ms₄ 67 =
      ExecResult.ok frame₇₀ [] stack₇₀ ms₇₀ ∧
      frame₇₀.pc = 70 := by
  sorry

end MovementFormal.Experimental.ConfidentialAsset.Registration
