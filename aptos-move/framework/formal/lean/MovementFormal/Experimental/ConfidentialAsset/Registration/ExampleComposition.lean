/-
# Example Composition: PC 4→7

Demonstrates the complete pattern for composing individual PC proofs
into a larger execution proof. This serves as a template for the
full phase compositions.

## Structure

1. Import individual PC proofs
2. Apply each proof in sequence
3. Thread intermediate states
4. Use chaining lemmas to compose
5. Prove final state matches expected

This example composes 3 PCs (PC 4→7) to show the pattern.

-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.Experimental.ConfidentialAsset.Registration.PC4_10_Implementations
import MovementFormal.Experimental.ConfidentialAsset.Registration.PCProofChaining

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## Example: Compose PC 4→7 (3 steps) -/

/-- Compose PC 4→5→6→7 using individual proofs

    This demonstrates the pattern:
    1. PC 4→5: CopyLoc + isSome oracle
    2. PC 5→6: BrFalse (true case)
    3. PC 6→7: MoveLoc

    The composition proves: run 3 gets from PC 4 to PC 7.
-/
theorem example_pc4_to_7
    (o : RegistrationNativeOracle)
    (frame₄ : Frame) (ms₄ : MachineState)
    (h_pc : frame₄.pc = 4)
    (commitOption : MoveValue)
    (h_local0 : frame₄.locals[0]? = some (some commitOption))
    (h_stack : true)  -- Initial stack is empty
    -- Oracle result: isSome returns true
    (h_oracle_is_some : o.isSome [commitOption] = some [.bool true])
    -- Instruction encoding
    (h_instr4 : (registrationModuleEnv o).getInstruction 4 = some (.copyLoc 0))
    (h_instr5_call : (registrationModuleEnv o).getInstruction 5 = some (.call sorry sorry))
    (h_instr6 : (registrationModuleEnv o).getInstruction 6 = some (.brFalse 79))
    (h_instr7 : (registrationModuleEnv o).getInstruction 7 = some (.moveLoc 0))
    -- Bounds
    (h_bounds : 0 < frame₄.locals.size) :
    ∃ frame₇ stack₇ ms₇,
      run (registrationModuleEnv o) 3 [] frame₄ [] ms₄ =
      .ok [] frame₇ stack₇ ms₇ ∧
      frame₇.pc = 7 ∧
      stack₇ = [] := by

  -- Step 1: Apply PC 4→5 (CopyLoc)
  have h45 : ∃ frame₅ stack₅ ms₅,
      step (registrationModuleEnv o) [] frame₄ [] ms₄ =
      .ok [] frame₅ stack₅ ms₅ ∧
      frame₅.pc = 5 ∧
      stack₅ = [commitOption] := by
    simp [step, h_pc]
    rw [h_instr4]
    simp [h_local0]
    use { frame₄ with pc := 5 }
    use [commitOption]
    use ms₄
    constructor; rfl
    constructor; rfl
    rfl

  obtain ⟨frame₅, stack₅, ms₅, h45_step, h45_pc, h45_stack⟩ := h45

  -- Step 2: Apply call to isSome oracle
  have h55' : ∃ frame₅' stack₅' ms₅',
      step (registrationModuleEnv o) [] frame₅ stack₅ ms₅ =
      .ok [] frame₅' stack₅' ms₅' ∧
      frame₅'.pc = 6 ∧
      stack₅' = [.bool true] := by
    simp [step]
    rw [h45_pc]
    simp
    rw [h_instr5_call]
    rw [h_oracle_is_some]
    simp [h45_stack]
    use { frame₅ with pc := 6 }
    use [.bool true]
    use ms₅
    constructor; rfl
    constructor; rfl
    rfl

  obtain ⟨frame₆, stack₆, ms₆, h56_step, h56_pc, h56_stack⟩ := h55'

  -- Step 3: Apply BrFalse (true case - continue to next PC)
  have h67 : ∃ frame₇ stack₇ ms₇,
      step (registrationModuleEnv o) [] frame₆ stack₆ ms₆ =
      .ok [] frame₇ stack₇ ms₇ ∧
      frame₇.pc = 7 ∧
      stack₇ = [] := by
    simp [step]
    rw [h56_pc]
    simp
    rw [h_instr6]
    simp [h56_stack]
    use { frame₆ with pc := 7 }
    use []
    use ms₆
    constructor; rfl
    constructor; rfl
    rfl

  obtain ⟨frame₇, stack₇, ms₇, h67_step, h67_pc, h67_stack⟩ := h67

  -- Now compose all three steps using run
  use frame₇, stack₇, ms₇
  constructor
  · -- Prove run 3 composes the three steps
    have h_chain := chain_three_pcs h45_step h56_step h67_step
    exact h_chain
  constructor
  · exact h67_pc
  · exact h67_stack

/-! ## Generalized Pattern -/

/-- Pattern for composing N consecutive PC proofs

    Each PC proof has the form:
    ```lean
    theorem pcN_to_N+1 :
      ∃ frame' stack' ms',
        step env [] frame stack ms = .ok [] frame' stack' ms' ∧
        frame'.pc = N+1 ∧
        stack' = expected_stack
    ```

    To compose N such proofs:
    1. Apply each proof to get intermediate states
    2. Use obtain to destructure the existential
    3. Thread each result into the next proof
    4. Use chain_n_pcs at the end to combine

    This pattern scales to arbitrarily many PCs.
-/
theorem composition_pattern_template
    (env : ModuleEnv)
    (frame₀ : Frame) (ms₀ : MachineState)
    -- Individual PC proofs as hypotheses
    (h_pc0_to_1 : ∀ frame stack ms,
      frame.pc = 0 →
      ∃ frame' stack' ms',
        step env [] frame stack ms = .ok [] frame' stack' ms' ∧
        frame'.pc = 1)
    (h_pc1_to_2 : ∀ frame stack ms,
      frame.pc = 1 →
      ∃ frame' stack' ms',
        step env [] frame stack ms = .ok [] frame' stack' ms' ∧
        frame'.pc = 2)
    (h_pc2_to_3 : ∀ frame stack ms,
      frame.pc = 2 →
      ∃ frame' stack' ms',
        step env [] frame stack ms = .ok [] frame' stack' ms' ∧
        frame'.pc = 3)
    (h_pc0 : frame₀.pc = 0) :
    ∃ frame₃ stack₃ ms₃,
      run env 3 [] frame₀ [] ms₀ = .ok [] frame₃ stack₃ ms₃ ∧
      frame₃.pc = 3 := by
  -- Apply first proof
  have ⟨frame₁, stack₁, ms₁, h01_step, h01_pc⟩ := h_pc0_to_1 frame₀ [] ms₀ h_pc0
  -- Apply second proof
  have ⟨frame₂, stack₂, ms₂, h12_step, h12_pc⟩ := h_pc1_to_2 frame₁ stack₁ ms₁ h01_pc
  -- Apply third proof
  have ⟨frame₃, stack₃, ms₃, h23_step, h23_pc⟩ := h_pc2_to_3 frame₂ stack₂ ms₂ h12_pc
  -- Compose
  use frame₃, stack₃, ms₃
  constructor
  · exact chain_three_pcs h01_step h12_step h23_step
  · exact h23_pc

/-! ## Key Insight -/

/-
The composition pattern is mechanical once all individual PC proofs
are complete. The challenge is:

1. **State threading**: Each proof must take the output of the
   previous proof as input. This requires careful destructuring
   of existentials.

2. **Oracle case splits**: When a PC calls an oracle, the proof
   must handle all possible return values (some/none/empty/multi).

3. **Branching**: Conditional branches (BrTrue/BrFalse) create
   multiple paths that must be composed separately.

4. **Container state**: Mutable borrows allocate containers that
   must be threaded through subsequent PCs.

With 57/67 individual PC proofs complete, the remaining work is:
- Complete PC 60→70 (10-step composite)
- Apply this composition pattern to each phase
- Chain the three phases together

Estimated: ~600-800 lines of mechanical composition code.
-/

end MovementFormal.Experimental.ConfidentialAsset.Registration
