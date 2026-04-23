/-
Example patterns demonstrating array proof irrelevance requirements.

These examples show WHY the array elaboration blocker occurs and what patterns
are needed to solve it. This module compiles successfully with simplified examples,
but the actual CA proofs hit the "free variable constraint" error.
-/

import MovementFormal.MoveModel.State

namespace MovementFormal.Examples.ArrayProofIrrelevancePatterns

open MovementFormal.MoveModel

/-! ## Pattern 1: Array access with different bound proofs -/

/-- Simplified example: accessing array elements with different bound proofs.
This works in isolation but fails when combined with dependent types and let-bindings. -/
example (arr : Array Nat) (i : Nat) (h1 : i < arr.size) (h2 : i < arr.size) :
    arr[i]'h1 = arr[i]'h2 := by
  rfl  -- Definitionally equal due to proof irrelevance

/-- More complex: using array access result in dependent context.
This still works because no free variables from match destructuring. -/
example (arr : Array Nat) (i : Nat) (h : i < arr.size) :
    let x := arr[i]'h
    x + 1 = arr[i]'h + 1 := by
  rfl

/-! ## Pattern 2: Let-destructuring with products -/

/-- Let-destructuring a pair works fine in simple contexts -/
example (p : Nat × Nat) :
    let (a, b) := p
    a + b = p.1 + p.2 := by
  rfl

/-- But becomes problematic when the pair comes from a function on arrays -/
def allocExample (arr : Array Nat) (h : 0 < arr.size) : Nat × Nat :=
  (arr[0]'h, arr[0]'h + 1)

example (arr : Array Nat) (h1 : 0 < arr.size) :
    let (a, b) := allocExample arr h1
    a = arr[0]'h1 := by
  rfl  -- Works: h1 is the same proof

/-- The problem: when the bound proof differs -/
example (arr : Array Nat) (h1 : 0 < arr.size) (h2 : 0 < arr.size) :
    let (a, b) := allocExample arr h1
    a = arr[0]'h2 := by
  -- This requires proof irrelevance to show arr[0]'h1 = arr[0]'h2
  sorry

/-! ## Pattern 3: The CA blocker pattern -/

/-- Simplified version of the CA blocker:
1. Let-destructure an allocation result
2. Try to match against an expression with different bound proof
-/
structure SimplifiedContainer where
  store : Array MoveValue
  deriving Inhabited

def SimplifiedContainer.alloc (cs : SimplifiedContainer) (v : MoveValue) :
    SimplifiedContainer × Nat :=
  ({ store := cs.store.push v }, cs.store.size)

example (cs : SimplifiedContainer) (proofFields : List MoveValue)
    (h1 : 0 < proofFields.length) (h2 : 0 < proofFields.length) :
    let (cs', fid) := cs.alloc (proofFields[0]'h1)
    cs' = (cs.alloc (proofFields[0]'h2)).fst := by
  -- Goal: show alloc with different bound proofs produces same result
  -- This is true (proof irrelevance) but not definitionally equal
  sorry

/-- What we need: a lemma stating this explicitly -/
axiom alloc_proof_irrel (cs : SimplifiedContainer) (proofFields : List MoveValue)
    (h1 : 0 < proofFields.length) (h2 : 0 < proofFields.length) :
    cs.alloc (proofFields[0]'h1) = cs.alloc (proofFields[0]'h2)

example (cs : SimplifiedContainer) (proofFields : List MoveValue)
    (h1 : 0 < proofFields.length) (h2 : 0 < proofFields.length) :
    let (cs', fid) := cs.alloc (proofFields[0]'h1)
    cs' = (cs.alloc (proofFields[0]'h2)).fst := by
  rw [alloc_proof_irrel]
  rfl

/-! ## Pattern 4: The "Expected type must not contain free variables" error -/

/-- This pattern triggers the error in actual CA proofs:

```lean
-- In theorem statement:
let (cs1, fid1) := initMs.containers.alloc (proofFields[0]'h_inferred)
-- where h_inferred is computed by omega in the let-binding context

-- Later in proof:
have : initMs.containers.alloc (proofFields[0]'h_explicit) = (cs1, fid1)
-- ERROR: Expected type must not contain free variables
--        cs1, fid1 are "free" because they come from match destructuring
```

The issue: Lean's elaborator sees cs1, fid1 as free variables that depend on
the specific bound proof h_inferred, but we're trying to equate them with a
different bound proof h_explicit.

**Solutions attempted:**
1. Proof irrelevance lemma (ArrayLemmas.containers_alloc_proof_irrel) - helps but doesn't solve the free variable issue
2. Term-mode construction - avoids tactic mode elaboration issues
3. Revert/intro patterns - clean up free variables before type-checking
4. Alternative proof architecture - avoid let-destructuring entirely
-/

/-! ## Pattern 5: Match on option with array access -/

/-- When matching on oracle results that depend on array access,
the bound proofs propagate through the match -/
def oracle_example (arr : Array Nat) (h : 0 < arr.size) : Option (Nat × Nat) :=
  some (arr[0]'h, arr[0]'h + 1)

example (arr : Array Nat) (h1 : 0 < arr.size) (h2 : 0 < arr.size) :
    oracle_example arr h1 = oracle_example arr h2 := by
  -- This should be true by proof irrelevance, but...
  sorry

/-! ## Working Patterns (no free variables) -/

/-- Pattern that DOES work: explicit witnesses without let-destructuring -/
example (cs : SimplifiedContainer) (proofFields : List MoveValue)
    (h : 0 < proofFields.length) :
    ∃ cs' fid, cs.alloc (proofFields[0]'h) = (cs', fid) := by
  exists (cs.alloc (proofFields[0]'h)).fst
  exists (cs.alloc (proofFields[0]'h)).snd
  rfl

/-- Pattern that DOES work: avoiding dependent types in goal -/
example (cs : SimplifiedContainer) (proofFields : List MoveValue)
    (h : 0 < proofFields.length) :
    (cs.alloc (proofFields[0]'h)).fst.store.size = cs.store.size + 1 := by
  rfl

/-! ## Recommended Solutions for CA Proofs

### Short-term (1-2 weeks):
1. **Revert/intro pattern:**
   ```lean
   revert cs1 fid1
   intro
   -- Now cs1, fid1 are not "free" in elaborator's view
   ```

2. **Term-mode construction:**
   ```lean
   show ... = match alloc_result with | (cs1, fid1) => ...
   -- where alloc_result := initMs.containers.alloc (proofFields[0]'...)
   ```

### Medium-term (2-4 weeks):
3. **Refactor proof architecture:**
   - Prove intermediate lemmas that don't require destructuring
   - Build composition from smaller pieces
   - See Registration/EvalEquivRebuild.lean for successful pattern

### Long-term (if others fail):
4. **Meta-programming:**
   - Custom elaborator for array literals in theorem statements
   - Requires deep Lean 4 knowledge
   - 2-3 weeks effort
-/

end MovementFormal.Examples.ArrayProofIrrelevancePatterns
