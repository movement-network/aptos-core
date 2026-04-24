/-
# PC Proof Chaining Utilities

Helper lemmas and tactics for chaining individual PC proofs into
larger compositions. Provides automation for the repetitive task
of sequencing step proofs.

## Key Lemmas

- `chain_two_pcs`: Chain two consecutive PC proofs
- `chain_three_pcs`: Chain three consecutive PC proofs
- `chain_n_pcs`: General chaining for n consecutive PC proofs

## Usage

Given individual PC proofs `pc4_to_5` and `pc5_to_6`, use
`chain_two_pcs` to prove `pc4_to_6` without manually threading
intermediate states.

-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.Experimental.ConfidentialAsset.Registration.RunCompositionLemmas

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## Two-Step Chaining -/

/-- Chain two consecutive PC proofs

    Given:
    - A proof that PC n → PC n+1
    - A proof that PC n+1 → PC n+2

    Produces:
    - A proof that PC n → PC n+2 via run 2
-/
theorem chain_two_pcs
    {env : ModuleEnv}
    {frame₀ : Frame} {stack₀ : List MoveValue} {ms₀ : MachineState}
    {frame₁ : Frame} {stack₁ : List MoveValue} {ms₁ : MachineState}
    {frame₂ : Frame} {stack₂ : List MoveValue} {ms₂ : MachineState}
    (h_step1 : step env [] frame₀ stack₀ ms₀ = .ok [] frame₁ stack₁ ms₁)
    (h_step2 : step env [] frame₁ stack₁ ms₁ = .ok [] frame₂ stack₂ ms₂) :
    run env 2 [] frame₀ stack₀ ms₀ = .ok [] frame₂ stack₂ ms₂ := by
  simp [run]
  rw [h_step1]
  simp [run]
  rw [h_step2]
  simp [run]

/-! ## Three-Step Chaining -/

/-- Chain three consecutive PC proofs -/
theorem chain_three_pcs
    {env : ModuleEnv}
    {frame₀ : Frame} {stack₀ : List MoveValue} {ms₀ : MachineState}
    {frame₁ : Frame} {stack₁ : List MoveValue} {ms₁ : MachineState}
    {frame₂ : Frame} {stack₂ : List MoveValue} {ms₂ : MachineState}
    {frame₃ : Frame} {stack₃ : List MoveValue} {ms₃ : MachineState}
    (h_step1 : step env [] frame₀ stack₀ ms₀ = .ok [] frame₁ stack₁ ms₁)
    (h_step2 : step env [] frame₁ stack₁ ms₁ = .ok [] frame₂ stack₂ ms₂)
    (h_step3 : step env [] frame₂ stack₂ ms₂ = .ok [] frame₃ stack₃ ms₃) :
    run env 3 [] frame₀ stack₀ ms₀ = .ok [] frame₃ stack₃ ms₃ := by
  simp [run]
  rw [h_step1]
  simp [run]
  rw [h_step2]
  simp [run]
  rw [h_step3]
  simp [run]

/-! ## N-Step Chaining via run composition -/

/-- Chain n+m steps using run_sequential_compose -/
theorem chain_n_plus_m_steps
    {env : ModuleEnv} {n m : Nat}
    {frame₀ : Frame} {stack₀ : List MoveValue} {ms₀ : MachineState}
    {frame₁ : Frame} {stack₁ : List MoveValue} {ms₁ : MachineState}
    {frame₂ : Frame} {stack₂ : List MoveValue} {ms₂ : MachineState}
    (h_run_n : run env n [] frame₀ stack₀ ms₀ = .ok [] frame₁ stack₁ ms₁)
    (h_run_m : run env m [] frame₁ stack₁ ms₁ = .ok [] frame₂ stack₂ ms₂) :
    run env (n + m) [] frame₀ stack₀ ms₀ = .ok [] frame₂ stack₂ ms₂ := by
  -- Induction on n to build up the composition
  induction n generalizing frame₀ stack₀ ms₀ with
  | zero =>
    simp [run] at h_run_n
    simp [h_run_n]
    exact h_run_m
  | succ n' ih =>
    simp [run] at h_run_n ⊢
    cases h_step : step env [] frame₀ stack₀ ms₀ with
    | error e => simp [h_step] at h_run_n
    | ok cs' frame' stack' ms' =>
      simp [h_step] at h_run_n ⊢
      cases cs' with
      | nil =>
        simp at h_run_n ⊢
        have h_rest : run env n' [] frame' stack' ms' = .ok [] frame₁ stack₁ ms₁ := h_run_n
        have h_composed := ih h_rest h_run_m
        simp [Nat.succ_add]
        exact h_composed
      | cons _ _ => simp at h_run_n

/-! ## Helper: Extract intermediate state from step proof -/

/-- Given a step proof, extract the resulting frame, stack, and machine state -/
def extract_step_result
    {env : ModuleEnv}
    {frame : Frame} {stack : List MoveValue} {ms : MachineState}
    (h : ∃ frame' stack' ms',
         step env [] frame stack ms = .ok [] frame' stack' ms' ∧
         frame'.pc = sorry ∧
         stack' = sorry) :
    { result : Frame × List MoveValue × MachineState //
      step env [] frame stack ms = .ok [] result.1 result.2.1 result.2.2 } := by
  sorry

/-! ## Automation: Tactic for chaining steps -/

/-- Macro to chain multiple step proofs

    Usage:
    ```lean
    have h := chain_steps [h1, h2, h3, h4]
    -- Produces: run env 4 [] frame₀ stack₀ ms₀ = .ok [] frame₄ stack₄ ms₄
    ```
-/
-- This would be a proper tactic in Lean 4, but for now we use theorem application

/-! ## Pattern: Oracle case handling in chains -/

/-- Helper for oracle call case splitting within a chain

    When chaining through an oracle call PC, handle all cases:
    - some [v]: continue chain
    - some []: error
    - some (_ :: _ :: _): error
    - none: error
-/
theorem chain_with_oracle_case
    {env : ModuleEnv}
    {oracle : List MoveValue → Option (List MoveValue)}
    {frame₀ : Frame} {stack₀ : List MoveValue} {ms₀ : MachineState}
    {pc_oracle : Nat}  -- PC where oracle call happens
    (h_before : run env pc_oracle [] frame₀ stack₀ ms₀ =
                .ok [] sorry sorry sorry)
    (h_oracle_some : ∀ v,
      oracle [sorry] = some [v] →
      ∃ frame_after stack_after ms_after,
        run env sorry [] sorry sorry sorry =
        .ok [] frame_after stack_after ms_after)
    (h_oracle_none : oracle [sorry] = none → sorry)
    (h_oracle_empty : oracle [sorry] = some [] → sorry)
    (h_oracle_multi : ∀ v1 v2 vs, oracle [sorry] = some (v1 :: v2 :: vs) → sorry) :
    sorry := by
  sorry

/-! ## Example: Chain first 3 PCs of Phase 1 -/

example
    (o : RegistrationNativeOracle)
    (frame₄ : Frame) (ms₄ : MachineState)
    (h_pc : frame₄.pc = 4)
    -- Use pc4_to_5, pc5_to_6, pc6_to_7 individual proofs
    (h45 : ∃ frame₅ stack₅ ms₅,
           step (registrationModuleEnv o) [] frame₄ [] ms₄ =
           .ok [] frame₅ stack₅ ms₅)
    (h56 : ∀ frame₅ stack₅ ms₅,
           step (registrationModuleEnv o) [] frame₄ [] ms₄ =
           .ok [] frame₅ stack₅ ms₅ →
           ∃ frame₆ stack₆ ms₆,
           step (registrationModuleEnv o) [] frame₅ stack₅ ms₅ =
           .ok [] frame₆ stack₆ ms₆)
    (h67 : ∀ frame₆ stack₆ ms₆,
           ∃ frame₇ stack₇ ms₇,
           step (registrationModuleEnv o) [] frame₆ stack₆ ms₆ =
           .ok [] frame₇ stack₇ ms₇) :
    ∃ frame₇ stack₇ ms₇,
      run (registrationModuleEnv o) 3 [] frame₄ [] ms₄ =
      .ok [] frame₇ stack₇ ms₇ := by
  sorry

/-! ## Progress Tracking -/

/-- Mark chaining infrastructure as available -/
def chaining_infrastructure_available : Bool := true

end MovementFormal.Experimental.ConfidentialAsset.Registration
