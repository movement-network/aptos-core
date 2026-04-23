import Batteries.Data.Array.Basic

/-!
# Array manipulation lemmas for PC-chaining proofs

Utility lemmas for reasoning about Array operations in bytecode proofs.
These lemmas help track locals state through sequences of moveLoc/copyLoc operations.

This module provides simp-friendly lemmas for common array patterns in Move bytecode proofs,
particularly for 7-element locals arrays which are standard in many verifier functions.
-/

namespace MovementFormal.MoveModel.StepLemmas.Arrays

/-! ## Literal array construction -/

/-- Size of a 7-element array literal -/
@[simp]
theorem size_array7 {α : Type u} (a b c d e f g : α) :
    #[a, b, c, d, e, f, g].size = 7 := by
  rfl

/-! ## Array element access for 7-element arrays -/

@[simp]
theorem get_array7_0 {α : Type u} (a b c d e f g : α) (h : 0 < 7) :
    #[a, b, c, d, e, f, g][0]'h = a := by rfl

@[simp]
theorem get_array7_1 {α : Type u} (a b c d e f g : α) (h : 1 < 7) :
    #[a, b, c, d, e, f, g][1]'h = b := by rfl

@[simp]
theorem get_array7_2 {α : Type u} (a b c d e f g : α) (h : 2 < 7) :
    #[a, b, c, d, e, f, g][2]'h = c := by rfl

@[simp]
theorem get_array7_3 {α : Type u} (a b c d e f g : α) (h : 3 < 7) :
    #[a, b, c, d, e, f, g][3]'h = d := by rfl

@[simp]
theorem get_array7_4 {α : Type u} (a b c d e f g : α) (h : 4 < 7) :
    #[a, b, c, d, e, f, g][4]'h = e := by rfl

@[simp]
theorem get_array7_5 {α : Type u} (a b c d e f g : α) (h : 5 < 7) :
    #[a, b, c, d, e, f, g][5]'h = f := by rfl

@[simp]
theorem get_array7_6 {α : Type u} (a b c d e f g : α) (h : 6 < 7) :
    #[a, b, c, d, e, f, g][6]'h = g := by rfl

/-! ## Array set operations

General lemmas for tracking state through `Array.set` chains, useful for following locals
updates through multiple moveLoc/stLoc operations.

Note: These are thin wrappers around standard library lemmas, added here for discoverability
in PC-chaining proof contexts. -/

@[simp]
theorem set_preserves_size {α : Type u} (arr : Array α) (i : Nat) (v : α) (h : i < arr.size) :
    (arr.set i v h).size = arr.size := by
  simp

end MovementFormal.MoveModel.StepLemmas.Arrays
