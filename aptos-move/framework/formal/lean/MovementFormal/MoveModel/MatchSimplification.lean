/-
Lemmas for simplifying complex match expressions in functional simulations.

CA verification involves deeply nested match trees over oracle outcomes.
These lemmas help reduce match expressions to their result values by:
1. Unfolding let-bindings
2. Proving equality of bound variables to expanded expressions
3. Rewriting with oracle hypotheses
4. Applying structural reflexivity

Common pattern: functional sim has `let cs2 = cs1.alloc x in match oracle cs2 ... with`
Goal has: `match oracle (cs1.alloc x).fst ... with`
Need to show: `cs2 = (cs1.alloc x).fst` to make the match expressions equal.
-/

import MovementFormal.MoveModel.State

namespace MovementFormal.MoveModel.MatchSimplification

open MovementFormal.MoveModel

/-! ## Let-binding unfolding lemmas -/

/-- When functional sim uses `let (cs2, fid) = cs1.alloc x in ...`,
show that `cs2 = (cs1.alloc x).fst` and `fid = (cs1.alloc x).snd`. -/
theorem alloc_let_unfold
    (cs1 : ContainerStore)
    (x : MoveValue) :
    let (cs2, fid) := cs1.alloc x
    cs2 = (cs1.alloc x).fst ∧ fid = (cs1.alloc x).snd :=
  ⟨rfl, rfl⟩

/-- Triple allocation pattern: three nested let-bindings. -/
theorem triple_alloc_let_unfold
    (cs0 : ContainerStore)
    (x y z : MoveValue) :
    let (cs1, fid1) := cs0.alloc x
    let (cs2, fid2) := cs1.alloc y
    let (cs3, fid3) := cs2.alloc z
    cs1 = (cs0.alloc x).fst ∧ fid1 = (cs0.alloc x).snd ∧
    cs2 = ((cs0.alloc x).fst.alloc y).fst ∧ fid2 = ((cs0.alloc x).fst.alloc y).snd ∧
    cs3 = (((cs0.alloc x).fst.alloc y).fst.alloc z).fst ∧
    fid3 = (((cs0.alloc x).fst.alloc y).fst.alloc z).snd :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

/-! ## Oracle match reduction -/

/-- When oracle hypothesis says `oracle cs args = none`,
rewrite match to none branch. -/
theorem oracle_none_reduces {α β : Type}
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs : ContainerStore)
    (args : List MoveValue)
    (none_branch : α)
    (some_branch : List MoveValue → ContainerStore → α)
    (h : oracle cs args = none) :
    (match oracle cs args with
     | none => none_branch
     | some (retVals, cs') => some_branch retVals cs') = none_branch := by
  rw [h]

/-- When oracle hypothesis says `oracle cs args = some ([], cs')`,
rewrite match to empty-list branch. -/
theorem oracle_some_empty_reduces {α β : Type}
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs cs' : ContainerStore)
    (args : List MoveValue)
    (empty_branch : ContainerStore → α)
    (nonempty_branch : List MoveValue → ContainerStore → α)
    (h : oracle cs args = some ([], cs')) :
    (match oracle cs args with
     | none => empty_branch cs  -- default, won't match
     | some ([], cs'') => empty_branch cs''
     | some (head :: tail, cs'') => nonempty_branch (head :: tail) cs'') =
    empty_branch cs' := by
  rw [h]

/-! ## Container store threading -/

/-- After allocation, MachineState container field updated correctly. -/
theorem machine_state_after_alloc
    (ms : MachineState)
    (x : MoveValue) :
    let (cs', fid) := ms.containers.alloc x
    { ms with containers := cs' }.containers = cs' :=
  rfl

/-- Two allocations thread containers correctly. -/
theorem machine_state_after_double_alloc
    (ms : MachineState)
    (x y : MoveValue) :
    let (cs1, fid1) := ms.containers.alloc x
    let (cs2, fid2) := cs1.alloc y
    { ms with containers := cs2 }.containers = cs2 :=
  rfl

/-! ## Struct equality after match reduction -/

/-- When all branches of match produce same constructor, factor it out. -/
theorem match_option_same_result {α β : Type}
    (opt : Option α)
    (f : α → β)
    (default : β) :
    (match opt with
     | none => default
     | some x => default) = default := by
  cases opt <;> rfl

/-- MachineState equality: if containers and other fields match, states are equal. -/
theorem machine_state_eq_of_containers_eq
    (ms1 ms2 : MachineState)
    (hc : ms1.containers = ms2.containers)
    (hg : ms1.globals = ms2.globals)
    (hf : ms1.faBalances = ms2.faBalances) :
    ms1 = ms2 := by
  cases ms1; cases ms2
  simp_all

/-! ## Proof-of-concept: withdrawal range failure simplification -/

/-- Pattern from Withdrawal line 844: unfold let-binding to enable rewrite.

The challenge: hypothesis `hrange : oracle cs3 rangeArgs = none` where
`cs3` and `rangeArgs` are let-bound, but goal has expanded expressions.

Solution: prove `cs3 = (cs2.alloc x).fst` and `rangeArgs = [a, b]`,
then rewrite to match hypothesis. -/
theorem withdrawal_range_pattern
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs2 : ContainerStore)
    (x a b : MoveValue)
    (hrange : oracle (cs2.alloc x).fst [a, b] = none) :
    let cs3 := (cs2.alloc x).fst
    let rangeArgs := [a, b]
    oracle cs3 rangeArgs = none :=
  hrange

example
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs2 : ContainerStore)
    (proofFields : List MoveValue)
    (newBalRef : MoveValue)
    (hFieldCount : 1 < proofFields.length)
    (hrange : oracle (cs2.alloc (proofFields[1]'hFieldCount)).fst
                      [newBalRef, .immRef (cs2.alloc (proofFields[1]'hFieldCount)).snd] = none) :
    let cs3 := (cs2.alloc (proofFields[1]'hFieldCount)).fst
    let zkrpFid := (cs2.alloc (proofFields[1]'hFieldCount)).snd
    let rangeArgs := [newBalRef, .immRef zkrpFid]
    (match oracle cs3 rangeArgs with
     | none => ExecResult.error
     | some _ => ExecResult.error) = ExecResult.error := by
  intro cs3 zkrpFid rangeArgs
  rw [hrange]

/-! ## Notes for CA verification

### Usage pattern for Withdrawal line 844:

```lean
-- Goal: show functional sim reduces to .error
-- Have: hrange : o.verifyRangeProof cs3 rangeArgs = none
-- where cs3, rangeArgs are let-bound in functional sim

-- Step 1: unfold let bindings
intro cs3 zkrpFid rangeArgs

-- Step 2: prove let-bound variables equal expanded expressions
have hcs3 : cs3 = (cs2.alloc proofFields[1]).fst := by rfl
have hrangeArgs : rangeArgs = [newBalRef, .immRef zkrpFid] := by rfl

-- Step 3: rewrite hypothesis with expanded expressions
have : o.verifyRangeProof (cs2.alloc proofFields[1]).fst
         [newBalRef, .immRef (cs2.alloc proofFields[1]).snd] = none := by
  rw [←hcs3, ←hrangeArgs]; exact hrange

-- Step 4: apply oracle_none_reduces
rw [oracle_none_reduces _ _ _ _ _ this]
rfl
```

### For Transfer line 718 (triple allocation):

Use `triple_alloc_let_unfold` to unfold all three let-bindings,
then apply oracle rewrites sequentially.
-/

end MovementFormal.MoveModel.MatchSimplification
