import MovementFormal.SmokeTests.Defs

/-!
# Vector smoke tests

**Source:** `aptos-move/framework/move-stdlib/sources/vector.move`; programs `MovementFormal.MoveModel.Programs.Vector`.

Concrete input/output tests for vector bytecode programs using `native_decide`.
Covers both hand-written (self-contained) and real compiler-output programs.
-/

namespace MovementFormal.SmokeTests.Vector

open MovementFormal.MoveModel
open MovementFormal.SmokeTests.Defs

/-! -------------------------------------------------------------------
## Hand-written programs
--------------------------------------------------------------------- -/

/-! ### reverse (index 17 in stdModuleEnv) -/

theorem reverse_empty :
    returnValues (evalProg 17 [u64Vec []] 50) == some [u64Vec []] := by
  native_decide

theorem reverse_singleton :
    returnValues (evalProg 17 [u64Vec [1]] 50) == some [u64Vec [1]] := by
  native_decide

theorem reverse_pair :
    returnValues (evalProg 17 [u64Vec [1, 2]] 50) == some [u64Vec [2, 1]] := by
  native_decide

theorem reverse_triple :
    returnValues (evalProg 17 [u64Vec [1, 2, 3]] 60) ==
      some [u64Vec [3, 2, 1]] := by
  native_decide

theorem reverse_five :
    returnValues (evalProg 17 [u64Vec [10, 20, 30, 40, 50]] 100) ==
      some [u64Vec [50, 40, 30, 20, 10]] := by
  native_decide

/-! ### contains (index 18 in stdModuleEnv) -/

theorem contains_found :
    returnValues (evalProg 18 [u64Vec [10, 20, 30], .u64 20] 100) ==
      some [MoveValue.bool true] := by
  native_decide

theorem contains_not_found :
    returnValues (evalProg 18 [u64Vec [10, 20, 30], .u64 99] 100) ==
      some [MoveValue.bool false] := by
  native_decide

theorem contains_empty :
    returnValues (evalProg 18 [u64Vec [], .u64 1] 30) ==
      some [MoveValue.bool false] := by
  native_decide

theorem contains_first :
    returnValues (evalProg 18 [u64Vec [42, 10, 20], .u64 42] 60) ==
      some [MoveValue.bool true] := by
  native_decide

/-! ### index_of (index 19 in stdModuleEnv) -/

theorem index_of_found :
    returnValues (evalProg 19 [u64Vec [10, 20, 30], .u64 20] 100) ==
      some [MoveValue.bool true, MoveValue.u64 1] := by
  native_decide

theorem index_of_not_found :
    returnValues (evalProg 19 [u64Vec [10, 20, 30], .u64 99] 100) ==
      some [MoveValue.bool false, MoveValue.u64 0] := by
  native_decide

theorem index_of_first :
    returnValues (evalProg 19 [u64Vec [42, 10, 20], .u64 42] 60) ==
      some [MoveValue.bool true, MoveValue.u64 0] := by
  native_decide

/-! -------------------------------------------------------------------
## Real compiler output
--------------------------------------------------------------------- -/

/-! ### real contains (via test wrapper at index 27 in realModuleEnv) -/

theorem real_contains_found :
    returnValues (evalReal 27 [u64Vec [10, 20, 30], .u64 20] 200) ==
      some [MoveValue.bool true] := by
  native_decide

theorem real_contains_not_found :
    returnValues (evalReal 27 [u64Vec [10, 20, 30], .u64 99] 200) ==
      some [MoveValue.bool false] := by
  native_decide

theorem real_contains_empty :
    returnValues (evalReal 27 [u64Vec [], .u64 1] 50) ==
      some [MoveValue.bool false] := by
  native_decide

theorem real_contains_first :
    returnValues (evalReal 27 [u64Vec [42, 10, 20], .u64 42] 100) ==
      some [MoveValue.bool true] := by
  native_decide

/-! ### real index_of (via test wrapper at index 28 in realModuleEnv)

Real compiler pushes `(LdTrue, MoveLoc i)`, so the stack-as-list is `[i, true]`.
The hand-written version pushes in the opposite order. -/

theorem real_index_of_found :
    returnValues (evalReal 28 [u64Vec [10, 20, 30], .u64 20] 200) ==
      some [MoveValue.u64 1, MoveValue.bool true] := by
  native_decide

theorem real_index_of_not_found :
    returnValues (evalReal 28 [u64Vec [10, 20, 30], .u64 99] 200) ==
      some [MoveValue.u64 0, MoveValue.bool false] := by
  native_decide

theorem real_index_of_first :
    returnValues (evalReal 28 [u64Vec [42, 10, 20], .u64 42] 100) ==
      some [MoveValue.u64 0, MoveValue.bool true] := by
  native_decide

/-! ### real reverse (via test wrapper at index 29 in realModuleEnv) -/

theorem real_reverse_empty :
    returnValues (evalReal 29 [u64Vec []] 100) ==
      some [u64Vec []] := by
  native_decide

theorem real_reverse_singleton :
    returnValues (evalReal 29 [u64Vec [1]] 100) ==
      some [u64Vec [1]] := by
  native_decide

theorem real_reverse_pair :
    returnValues (evalReal 29 [u64Vec [1, 2]] 100) ==
      some [u64Vec [2, 1]] := by
  native_decide

theorem real_reverse_triple :
    returnValues (evalReal 29 [u64Vec [1, 2, 3]] 150) ==
      some [u64Vec [3, 2, 1]] := by
  native_decide

theorem real_reverse_five :
    returnValues (evalReal 29 [u64Vec [10, 20, 30, 40, 50]] 300) ==
      some [u64Vec [50, 40, 30, 20, 10]] := by
  native_decide

end MovementFormal.SmokeTests.Vector
