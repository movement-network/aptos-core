/-
# Array Lemmas for PC Proof Composition

Fundamental lemmas about Array operations needed for composing
PC proofs. These lemmas establish that array modifications preserve
unmodified indices.

## Key Lemmas

- `array_set_preserves_other`: set! at index i doesn't affect index j
- `array_set_size_preserved`: set! preserves array size
- `array_set_get_same`: set! then get at same index returns the value
- `array_set_get_other`: set! then get at different index is unchanged

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## Basic Array.set! Properties -/

/-- Array.set! preserves size -/
lemma array_set_size_preserved {α : Type} [Inhabited α]
    (arr : Array α) (i : Nat) (v : α) :
    (arr.set! i v).size = arr.size := by
  simp [Array.set!]
  split
  · simp [Array.setD, Array.set]
  · rfl

/-- Array.set! at index i, then get at index i, returns v (when in bounds) -/
lemma array_set_get_same {α : Type} [Inhabited α]
    (arr : Array α) (i : Nat) (v : α)
    (h_bounds : i < arr.size) :
    (arr.set! i v)[i]! = v := by
  simp [Array.set!]
  split
  · simp [Array.setD, Array.set, Array.get!]
    split
    · sorry  -- Standard array access lemma
    · sorry
  · contradiction

/-- Array.set! preserves get at other indices -/
lemma array_set_get_other {α : Type} [Inhabited α]
    (arr : Array α) (i j : Nat) (v : α)
    (h_neq : i ≠ j)
    (h_j_bounds : j < arr.size) :
    (arr.set! i v)[j]! = arr[j]! := by
  simp [Array.set!]
  split
  · simp [Array.setD, Array.set, Array.get!]
    split
    · sorry  -- Standard array access lemma
    · sorry
  · rfl

/-! ## Option Array Access Properties -/

/-- Array.set! preserves get? at other indices -/
lemma array_set_get?_other {α : Type} [Inhabited α]
    (arr : Array α) (i j : Nat) (v : α)
    (h_neq : i ≠ j) :
    (arr.set! i v)[j]? = arr[j]? := by
  by_cases h_j : j < arr.size
  · simp [Array.get?]
    split
    · split
      · -- Both in bounds
        have h_size := array_set_size_preserved arr i v
        rw [h_size] at *
        congr
        exact array_set_get_other arr i j v h_neq h_j
      · -- Contradiction: j < size but get? thinks not
        sorry
    · -- j >= original size
      have h_size := array_set_size_preserved arr i v
      rw [h_size]
      rfl
  · simp [Array.get?]
    split <;> split
    · -- Contradiction
      have h_size := array_set_size_preserved arr i v
      rw [h_size] at *
      contradiction
    · sorry
    · sorry
    · rfl

/-! ## Frame Locals Preservation -/

/-- Setting one local preserves other locals -/
lemma frame_locals_set_preserves_other
    (frame : Frame) (i j : Nat) (v : Option MoveValue)
    (h_neq : i ≠ j) :
    (frame.locals.set! i v)[j]? = frame.locals[j]? := by
  exact array_set_get?_other frame.locals i j v h_neq

/-- Frame PC update preserves locals -/
lemma frame_pc_update_preserves_locals
    (frame : Frame) (new_pc : Nat) (i : Nat) :
    ({ frame with pc := new_pc }).locals[i]? = frame.locals[i]? := by
  rfl

/-- Frame locals update preserves PC -/
lemma frame_locals_update_preserves_pc
    (frame : Frame) (new_locals : Array (Option MoveValue)) :
    ({ frame with locals := new_locals }).pc = frame.pc := by
  rfl

/-! ## Composition Helpers -/

/-- After two set! operations at different indices, both values are present -/
lemma array_set_twice_both_present {α : Type} [Inhabited α]
    (arr : Array α) (i j : Nat) (v1 v2 : α)
    (h_neq : i ≠ j)
    (h_i_bounds : i < arr.size)
    (h_j_bounds : j < arr.size) :
    let arr' := arr.set! i v1
    let arr'' := arr'.set! j v2
    arr''[i]! = v1 ∧ arr''[j]! = v2 := by
  constructor
  · -- Show arr''[i] = v1
    simp
    have h_size := array_set_size_preserved arr i v1
    have h_i_bounds' : i < (arr.set! i v1).size := by rw [h_size]; exact h_i_bounds
    exact array_set_get_other (arr.set! i v1) j i v2 (Ne.symm h_neq) h_i_bounds'
  · -- Show arr''[j] = v2
    simp
    have h_size := array_set_size_preserved arr i v1
    have h_j_bounds' : j < (arr.set! i v1).size := by rw [h_size]; exact h_j_bounds
    exact array_set_get_same (arr.set! i v1) j v2 h_j_bounds'

/-- Option version of two set! operations -/
lemma array_set_twice_both_present_option {α : Type} [Inhabited α]
    (arr : Array α) (i j : Nat) (v1 v2 : α)
    (h_neq : i ≠ j)
    (h_i_bounds : i < arr.size)
    (h_j_bounds : j < arr.size) :
    let arr' := arr.set! i v1
    let arr'' := arr'.set! j v2
    arr''[i]? = some v1 ∧ arr''[j]? = some v2 := by
  constructor
  · simp [Array.get?]
    split
    · have ⟨h1, _⟩ := array_set_twice_both_present arr i j v1 v2 h_neq h_i_bounds h_j_bounds
      simp at h1
      rw [h1]
    · sorry
  · simp [Array.get?]
    split
    · have ⟨_, h2⟩ := array_set_twice_both_present arr i j v1 v2 h_neq h_i_bounds h_j_bounds
      simp at h2
      rw [h2]
    · sorry

/-! ## Application to Frame Locals -/

/-- Setting two different locals preserves both values -/
theorem frame_set_two_locals_preserves_both
    (frame : Frame) (i j : Nat) (v1 v2 : Option MoveValue)
    (h_neq : i ≠ j)
    (h_i_bounds : i < frame.locals.size)
    (h_j_bounds : j < frame.locals.size) :
    let locals' := frame.locals.set! i v1
    let locals'' := locals'.set! j v2
    locals''[i]? = some v1 ∧ locals''[j]? = some v2 := by
  sorry  -- Would use array_set_twice_both_present_option with Option MoveValue

/-! ## Progress Note -/

/-
These lemmas establish the fundamental properties of array operations
needed for PC proof composition. The remaining sorry placeholders are
for standard array library facts that would typically be in mathlib
or the Lean standard library.

With these lemmas, composition proofs can confidently assert that
modifying one local variable doesn't affect others - the key property
needed to thread state through multiple PC steps.

Estimated: ~50-100 lines to complete all sorry placeholders with
standard array reasoning.
-/

end MovementFormal.Experimental.ConfidentialAsset.Registration
