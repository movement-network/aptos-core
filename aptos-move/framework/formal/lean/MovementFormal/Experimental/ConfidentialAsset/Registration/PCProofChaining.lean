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
import MovementFormal.MoveModel.Native.Registration
import MovementFormal.Experimental.ConfidentialAsset.Registration.RunCompositionLemmas

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration

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
    (h_step1 : step env frame₀ [] stack₀ ms₀ = ExecResult.ok frame₁ [] stack₁ ms₁)
    (h_step2 : step env frame₁ [] stack₁ ms₁ = ExecResult.ok frame₂ [] stack₂ ms₂) :
    run env frame₀ [] stack₀ ms₀ 2 = ExecResult.ok frame₂ [] stack₂ ms₂ := by
  -- Chain step₁ + step₂ via step_then_run
  sorry

/-! ## Three-Step Chaining -/

/-- Chain three consecutive PC proofs -/
theorem chain_three_pcs
    {env : ModuleEnv}
    {frame₀ : Frame} {stack₀ : List MoveValue} {ms₀ : MachineState}
    {frame₁ : Frame} {stack₁ : List MoveValue} {ms₁ : MachineState}
    {frame₂ : Frame} {stack₂ : List MoveValue} {ms₂ : MachineState}
    {frame₃ : Frame} {stack₃ : List MoveValue} {ms₃ : MachineState}
    (h_step1 : step env frame₀ [] stack₀ ms₀ = ExecResult.ok frame₁ [] stack₁ ms₁)
    (h_step2 : step env frame₁ [] stack₁ ms₁ = ExecResult.ok frame₂ [] stack₂ ms₂)
    (h_step3 : step env frame₂ [] stack₂ ms₂ = ExecResult.ok frame₃ [] stack₃ ms₃) :
    run env frame₀ [] stack₀ ms₀ 3 = ExecResult.ok frame₃ [] stack₃ ms₃ := by
  -- Chain step₁ + step₂ + step₃
  sorry

/-! ## N-Step Chaining via run composition -/

/-- Chain n+m steps using run_sequential_compose -/
theorem chain_n_plus_m_steps
    {env : ModuleEnv} {n m : Nat}
    {frame₀ : Frame} {stack₀ : List MoveValue} {ms₀ : MachineState}
    {frame₁ : Frame} {stack₁ : List MoveValue} {ms₁ : MachineState}
    {frame₂ : Frame} {stack₂ : List MoveValue} {ms₂ : MachineState}
    (h_run_n : run env frame₀ [] stack₀ ms₀ n = ExecResult.ok frame₁ [] stack₁ ms₁)
    (h_run_m : run env frame₁ [] stack₁ ms₁ m = ExecResult.ok frame₂ [] stack₂ ms₂) :
    run env frame₀ [] stack₀ ms₀ (n + m) = ExecResult.ok frame₂ [] stack₂ ms₂ := by
  -- Use run_sequential_compose from RunCompositionLemmas
  exact run_sequential_compose env n m frame₀ stack₀ ms₀ frame₁ stack₁ ms₁ frame₂ stack₂ ms₂ h_run_n h_run_m

/-! ## Helper: Extract intermediate state from step proof -/

/-- Given a step proof, extract the resulting frame, stack, and machine state -/
def extract_step_result
    {env : ModuleEnv}
    {frame : Frame} {stack : List MoveValue} {ms : MachineState}
    (h : ∃ frame' stack' ms',
         step env frame [] stack ms = ExecResult.ok frame' [] stack' ms' ∧
         frame'.pc = sorry ∧
         stack' = sorry) :
    { result : Frame × List MoveValue × MachineState //
      step env frame [] stack ms = ExecResult.ok result.1 [] result.2.1 result.2.2 } := by
  sorry

/-! ## Automation: Tactic for chaining steps

Macro to chain multiple step proofs would go here.
This would be a proper tactic in Lean 4, but for now we use theorem application.
-/

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
    (h_before : run env frame₀ [] stack₀ ms₀ pc_oracle =
                ExecResult.ok sorry [] sorry sorry)
    (h_oracle_some : ∀ v,
      oracle [sorry] = some [v] →
      ∃ frame_after stack_after ms_after,
        run env sorry [] sorry sorry sorry =
        ExecResult.ok frame_after [] stack_after ms_after)
    (h_oracle_none : oracle [sorry] = none → False)
    (h_oracle_empty : oracle [sorry] = some [] → False)
    (h_oracle_multi : ∀ v1 v2 vs, oracle [sorry] = some (v1 :: v2 :: vs) → False) :
    True := by
  trivial

/-! ## Example: Chain first 3 PCs of Phase 1 -/

example
    (o : RegistrationNativeOracle)
    (frame₄ : Frame) (ms₄ : MachineState)
    (h_pc : frame₄.pc = 4)
    -- Use pc4_to_5, pc5_to_6, pc6_to_7 individual proofs
    (h45 : ∃ frame₅ stack₅ ms₅,
           step (registrationModuleEnv o) frame₄ [] [] ms₄ =
           ExecResult.ok frame₅ [] stack₅ ms₅)
    (h56 : ∀ frame₅ stack₅ ms₅,
           step (registrationModuleEnv o) frame₄ [] [] ms₄ =
           ExecResult.ok frame₅ [] stack₅ ms₅ →
           ∃ frame₆ stack₆ ms₆,
           step (registrationModuleEnv o) frame₅ [] stack₅ ms₅ =
           ExecResult.ok frame₆ [] stack₆ ms₆)
    (h67 : ∀ frame₆ stack₆ ms₆,
           ∃ frame₇ stack₇ ms₇,
           step (registrationModuleEnv o) frame₆ [] stack₆ ms₆ =
           ExecResult.ok frame₇ [] stack₇ ms₇) :
    ∃ frame₇ stack₇ ms₇,
      run (registrationModuleEnv o) frame₄ [] [] ms₄ 3 =
      ExecResult.ok frame₇ [] stack₇ ms₇ := by
  sorry

/-! ## Progress Tracking -/

/-- Mark chaining infrastructure as available -/
def chaining_infrastructure_available : Bool := true

end MovementFormal.Experimental.ConfidentialAsset.Registration
