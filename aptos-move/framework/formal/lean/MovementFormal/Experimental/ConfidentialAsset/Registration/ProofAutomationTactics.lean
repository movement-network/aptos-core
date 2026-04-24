/-
# Proof Automation Tactics

Lean 4 tactics for automating PC proof construction. Provides
high-level automation for repetitive proof patterns.

## Tactics

1. **pc_copy_loc**: Automate CopyLoc proofs
2. **pc_st_loc**: Automate StLoc proofs
3. **pc_move_loc**: Automate MoveLoc proofs
4. **pc_oracle_call**: Automate native call proofs
5. **pc_branch**: Automate branch proofs
6. **pc_chain**: Chain multiple PC proofs

## Usage

```lean
theorem pc4_to_5 ... := by
  pc_copy_loc
  · -- Prove instruction is CopyLoc 0
  · -- Prove PC increment
```

## Source

Tactical infrastructure for proof automation.

-/

import Lean
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.Experimental.ConfidentialAsset.Registration.ConcretePCStepTemplates

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

open Lean Meta Elab Tactic

/-! ## Basic Tactic Infrastructure -/

/-- Extract PC value from hypothesis h_pc : frame.pc = n -/
def extractPC (h : Expr) : TacticM Nat := do
  let type ← inferType h
  -- Match pattern: frame.pc = n
  match type with
  | .app (.app (.const ``Eq _) _) (.lit (.natVal n)) => return n
  | _ => throwError "Expected hypothesis of form frame.pc = n"

/-- Check if instruction at PC is CopyLoc -/
def isCopyLocInstruction (env : ModuleEnv) (pc : Nat) (idx : Nat) : Bool :=
  match env.getInstruction pc with
  | some (.copyLoc i) => i == idx
  | _ => false

/-! ## CopyLoc Tactic -/

/-- Automate CopyLoc proof -/
syntax "pc_copy_loc" : tactic

/-- Implementation of pc_copy_loc tactic -/
elab_rules : tactic
  | `(tactic| pc_copy_loc) => do
    -- Goal should be: ∃ frame' stack' ms', step ... = .ok ... ∧ frame'.pc = ... ∧ stack' = [val]
    let goal ← getMainGoal
    let goalType ← goal.getType

    -- Apply copy_loc_step_template
    evalTactic (← `(tactic| apply copy_loc_step_template))

    -- Now we have subgoals for the hypotheses
    -- Try to close some with assumptions
    allGoals (try (evalTactic (← `(tactic| assumption))))

/-! ## StLoc Tactic -/

/-- Automate StLoc proof -/
syntax "pc_st_loc" : tactic

elab_rules : tactic
  | `(tactic| pc_st_loc) => do
    evalTactic (← `(tactic| apply st_loc_step_template))
    allGoals (try (evalTactic (← `(tactic| assumption))))

/-! ## MoveLoc Tactic -/

/-- Automate MoveLoc proof -/
syntax "pc_move_loc" : tactic

elab_rules : tactic
  | `(tactic| pc_move_loc) => do
    evalTactic (← `(tactic| apply move_loc_step_template))
    allGoals (try (evalTactic (← `(tactic| assumption))))

/-! ## Oracle Call Tactic -/

/-- Automate oracle call proof -/
syntax "pc_oracle_call" : tactic

elab_rules : tactic
  | `(tactic| pc_oracle_call) => do
    evalTactic (← `(tactic| apply native_call_step_template))
    allGoals (try (evalTactic (← `(tactic| assumption))))

/-! ## Branch Tactic -/

/-- Automate branch proof -/
syntax "pc_branch" : tactic

elab_rules : tactic
  | `(tactic| pc_branch) => do
    evalTactic (← `(tactic| apply branch_step_template))
    allGoals (try (evalTactic (← `(tactic| assumption))))

/-! ## Chaining Tactic -/

/-- Chain multiple PC proofs together -/
syntax "pc_chain" num : tactic

elab_rules : tactic
  | `(tactic| pc_chain $n:num) => do
    -- Apply run composition n times
    let count := n.getNat
    for _ in [0:count] do
      evalTactic (← `(tactic| apply step_then_run))
      allGoals (try (evalTactic (← `(tactic| assumption))))

/-! ## Smart Tactics -/

/-- Automatically choose the right tactic based on instruction -/
syntax "pc_auto" : tactic

elab_rules : tactic
  | `(tactic| pc_auto) => do
    -- Try each tactic in order until one works
    let tactics := [
      `(tactic| pc_copy_loc),
      `(tactic| pc_st_loc),
      `(tactic| pc_move_loc),
      `(tactic| pc_oracle_call),
      `(tactic| pc_branch)
    ]

    for tac in tactics do
      try
        evalTactic tac
        return
      catch _ =>
        continue

    -- If nothing worked, fail
    throwError "No tactic applicable"

/-! ## Batch Tactics -/

/-- Prove multiple consecutive simple steps -/
syntax "pc_batch" num : tactic

elab_rules : tactic
  | `(tactic| pc_batch $n:num) => do
    let count := n.getNat
    for _ in [0:count] do
      evalTactic (← `(tactic| pc_auto))

/-! ## Example Usage Documentation -/

/-- Example: CopyLoc proof using tactic -/
example
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
  pc_copy_loc
  sorry -- Remaining subgoals about instruction encoding

/-- Example: StLoc proof using tactic -/
example
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
  pc_st_loc
  sorry

/-! ## Tactic Combinators -/

/-- Repeat tactic until it fails -/
syntax "pc_repeat" tactic : tactic

elab_rules : tactic
  | `(tactic| pc_repeat $t:tactic) => do
    repeat do
      try
        evalTactic t
      catch _ =>
        break

/-- Try tactic, don't fail if it doesn't work -/
syntax "pc_try" tactic : tactic

elab_rules : tactic
  | `(tactic| pc_try $t:tactic) => do
    try
      evalTactic t
    catch _ =>
      return

/-! ## Verification Tactics -/

/-- Verify PC bounds -/
syntax "verify_pc_bounds" : tactic

elab_rules : tactic
  | `(tactic| verify_pc_bounds) => do
    -- Check that PC is in range [4, 70]
    evalTactic (← `(tactic| omega))

/-- Verify local index bounds -/
syntax "verify_local_bounds" : tactic

elab_rules : tactic
  | `(tactic| verify_local_bounds) => do
    -- Check that local index is in range [0, 18]
    evalTactic (← `(tactic| omega))

/-! ## Phase-Specific Tactics -/

/-- Automate Phase 1 proof pattern -/
syntax "phase1_step" num : tactic

elab_rules : tactic
  | `(tactic| phase1_step $n:num) => do
    -- Phase 1 has specific patterns: CopyLoc, Call, Branch, MoveLoc, Call, StLoc
    let pc := n.getNat
    match pc with
    | 4 | 10 | 16 | 18 => evalTactic (← `(tactic| pc_copy_loc))
    | 5 | 11 => evalTactic (← `(tactic| pc_oracle_call))  -- isSome
    | 8 | 14 => evalTactic (← `(tactic| pc_oracle_call))  -- unwrap
    | 6 | 12 => evalTactic (← `(tactic| pc_branch))
    | 7 | 13 => evalTactic (← `(tactic| pc_move_loc))
    | 9 | 15 | 17 | 19 => evalTactic (← `(tactic| pc_st_loc))
    | _ => throwError s!"Unknown Phase 1 PC: {pc}"

/-- Automate Phase 2 proof pattern -/
syntax "phase2_step" num : tactic

elab_rules : tactic
  | `(tactic| phase2_step $n:num) => do
    -- Phase 2 is more complex, use pc_auto
    evalTactic (← `(tactic| pc_auto))

/-- Automate Phase 3 proof pattern -/
syntax "phase3_step" num : tactic

elab_rules : tactic
  | `(tactic| phase3_step $n:num) => do
    evalTactic (← `(tactic| pc_auto))

end MovementFormal.Experimental.ConfidentialAsset.Registration
