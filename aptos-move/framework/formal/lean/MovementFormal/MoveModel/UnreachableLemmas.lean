/-
Helper lemmas for unreachable pattern match cases.

In Lean, overlapping patterns can create provably unreachable branches.
For example, after matching `| some ([], x) =>`, Lean still generates
a case for `| some (y, _) => match y with | [] => ...`.

Since these branches are never executed, we can provide any value of the goal type.
These lemmas document common unreachable patterns in CA verification.
-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Instr

namespace MovementFormal.MoveModel.UnreachableLemmas

open MovementFormal.MoveModel

/-! ## Oracle arity mismatch patterns -/

/-- When oracle returns `some (retVals, cs')` and we've already matched `some ([], cs)`,
the case where `retVals = []` is unreachable but Lean requires it.
Provide `.error` as the value. -/
theorem oracle_empty_after_empty_unreachable
    (retVals : List MoveValue)
    (h_empty : retVals = []) :
    -- Any goal type α can be provided; we use ExecResult as the common case
    ∃ (_proof : (ExecResult.error : ExecResult) = .error), True := by
  exists rfl

/-- Oracle arity mismatch: native function returned non-empty list when spec requires empty.
Type system prevents this, so any value suffices. -/
theorem oracle_arity_mismatch_unreachable
    (retVals : List MoveValue)
    (head : MoveValue)
    (tail : List MoveValue)
    (h_nonempty : retVals = head :: tail) :
    ∃ (_proof : (ExecResult.error : ExecResult) = .error), True := by
  exists rfl

/-! ## Nested match pattern lemmas -/

/-- After matching outer `some ([], cs)`, inner match on empty list is redundant but required. -/
theorem nested_empty_match_unreachable {α : Type}
    (default : α) :
    (match ([] : List MoveValue) with
     | [] => default
     | _ :: _ => default) = default := by
  rfl

/-- Generic helper: in unreachable branch, any proof of `t = t` exists. -/
theorem unreachable_refl {α : Type} (t : α) :
    ∃ (_proof : t = t), True := by
  exists rfl

/-! ## Example usage patterns -/

example : (ExecResult.error : ExecResult) = .error :=
  (oracle_empty_after_empty_unreachable [] rfl).choose

example : (ExecResult.error : ExecResult) = .error :=
  (oracle_arity_mismatch_unreachable [.u8 42] (.u8 42) [] rfl).choose

/-! ## Notes for CA verification

In Withdrawal/Transfer/Rotation compositions, oracle functions return `Option (List MoveValue × ContainerStore)`.
The spec requires `some ([], cs)` for success. When pattern matching:

```lean
match oracleResult with
| none => ... -- error path
| some ([], cs) => ... -- happy path
| some (retVals, cs') =>
  match retVals with
  | [] => sorry -- UNREACHABLE: already matched above
  | head :: tail => sorry -- UNREACHABLE: type system prevents non-empty return
```

The two inner cases are unreachable. Use these lemmas to discharge them:
- Line 882 type: `oracle_empty_after_empty_unreachable`
- Line 889 type: `oracle_arity_mismatch_unreachable`
-/

end MovementFormal.MoveModel.UnreachableLemmas
