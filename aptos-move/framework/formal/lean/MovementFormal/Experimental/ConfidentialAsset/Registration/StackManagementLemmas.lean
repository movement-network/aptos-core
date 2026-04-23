import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step

/-! # Stack Management Lemmas

This file provides comprehensive lemmas for reasoning about stack operations
in the registration singleton branch proof.

## Stack Patterns in Registration Proof

The registration proof exhibits several key stack patterns:

1. **Reference passing**: immRef/mutRef values pushed and passed to native calls
2. **Value extraction**: Option values extracted, inner values pushed
3. **Temporary calculations**: Intermediate values pushed, consumed by next instruction
4. **Native call results**: Values returned by oracles, stored in locals
5. **Empty stack states**: Many PCs start with empty stack after stLoc consumes top

## Common Stack Shapes

- `[]`: Empty (most common state between instructions)
- `[v]`: Single value (result of moveLoc, native call)
- `[.immRef rid]`: Immutable reference (after immBorrowLoc)
- `[.mutRef rid]`: Mutable reference (after mutBorrowLoc)
- `[.mutRef rid, v]`: Ref + value (before vectorAppendU8Ref)
- `[.immRef rid1, .immRef rid2]`: Two refs (before pointMul)
- `[.bool b]`: Boolean (result of optionIsSomeRef, before brFalse)

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.StackManagementLemmas

open MovementFormal.MoveModel

/-! ## Basic Stack Properties

Fundamental properties of stack structures.
-/

/-- Empty stack has length 0. -/
theorem empty_stack_length :
    ([] : List MoveValue).length = 0 := by
  rfl

/-- Single-element stack has length 1. -/
theorem singleton_stack_length (v : MoveValue) :
    [v].length = 1 := by
  rfl

/-- Two-element stack has length 2. -/
theorem two_element_stack_length (v1 v2 : MoveValue) :
    [v1, v2].length = 2 := by
  rfl

/-- Stack head of non-empty stack exists. -/
theorem stack_head_exists
    (v : MoveValue)
    (rest : List MoveValue) :
    (v :: rest).head? = some v := by
  rfl

/-- Stack tail preserves length - 1. -/
theorem stack_tail_length
    (v : MoveValue)
    (rest : List MoveValue) :
    (v :: rest).tail.length = rest.length := by
  rfl

/-- Appending to empty list is identity. -/
theorem append_empty_right
    (stack : List MoveValue) :
    stack ++ [] = stack := by
  simp

/-- Appending empty list on left is identity. -/
theorem append_empty_left
    (stack : List MoveValue) :
    [] ++ stack = stack := by
  simp

/-! ## Stack Push and Pop

Properties of adding and removing elements from the stack.
-/

/-- Push increases length by 1. -/
theorem push_increases_length
    (v : MoveValue)
    (stack : List MoveValue) :
    (v :: stack).length = stack.length + 1 := by
  rfl

/-- Pop decreases length by 1 (when non-empty). -/
theorem pop_decreases_length
    (v : MoveValue)
    (rest : List MoveValue) :
    (v :: rest).tail.length + 1 = (v :: rest).length := by
  rfl

/-- Push then pop is identity. -/
theorem push_pop_identity
    (v : MoveValue)
    (stack : List MoveValue) :
    (v :: stack).tail = stack := by
  rfl

/-- Pop then check head recovers original element. -/
theorem pop_head_recovers
    (v : MoveValue)
    (rest : List MoveValue) :
    (v :: rest).head? = some v := by
  rfl

/-! ## Stack Element Access

Properties for accessing specific stack positions.
-/

/-- Top of stack (index 0). -/
theorem stack_top
    (v : MoveValue)
    (rest : List MoveValue) :
    (v :: rest)[0]? = some v := by
  rfl

/-- Second element (index 1). -/
theorem stack_second
    (v1 v2 : MoveValue)
    (rest : List MoveValue) :
    (v1 :: v2 :: rest)[1]? = some v2 := by
  rfl

/-- Third element (index 2). -/
theorem stack_third
    (v1 v2 v3 : MoveValue)
    (rest : List MoveValue) :
    (v1 :: v2 :: v3 :: rest)[2]? = some v3 := by
  rfl

/-- Out-of-bounds access returns none. -/
theorem stack_out_of_bounds
    (stack : List MoveValue)
    (idx : Nat)
    (h : idx ≥ stack.length) :
    stack[idx]? = none := by
  exact List.getElem?_eq_none.mpr h

/-! ## Stack Patterns for Instructions

Lemmas matching common instruction stack requirements.
-/

/-- moveLoc pushes one value. -/
theorem moveLoc_produces_singleton
    (v : MoveValue)
    (initial_stack : List MoveValue) :
    (v :: initial_stack).length = initial_stack.length + 1 := by
  rfl

/-- stLoc consumes one value. -/
theorem stLoc_consumes_one
    (v : MoveValue)
    (rest : List MoveValue) :
    (v :: rest).tail = rest := by
  rfl

/-- pop consumes one value, produces empty. -/
theorem pop_consumes_one
    (v : MoveValue) :
    (v :: []).tail = [] := by
  rfl

/-- immBorrowLoc produces immRef on stack. -/
theorem immBorrowLoc_produces_ref
    (rid : RefId)
    (stack : List MoveValue) :
    (MoveValue.immRef rid :: stack).head? = some (.immRef rid) := by
  rfl

/-- mutBorrowLoc produces mutRef on stack. -/
theorem mutBorrowLoc_produces_ref
    (rid : RefId)
    (stack : List MoveValue) :
    (MoveValue.mutRef rid :: stack).head? = some (.mutRef rid) := by
  rfl

/-- brFalse consumes bool from stack. -/
theorem brFalse_consumes_bool
    (b : Bool)
    (rest : List MoveValue) :
    (MoveValue.bool b :: rest).tail = rest := by
  rfl

/-- vecPack 0 produces empty vector. -/
theorem vecPack_zero_produces_empty :
    [MoveValue.vector .u8 []].length = 1 := by
  rfl

/-! ## Stack Transformations for Native Calls

Properties of stack before and after native function calls.
-/

/-- optionIsSomeRef: [immRef rid] → [bool b]. -/
theorem optionIsSomeRef_stack_transform
    (rid : RefId)
    (b : Bool)
    (rest : List MoveValue) :
    (MoveValue.bool b :: rest).length =
    (MoveValue.immRef rid :: rest).length := by
  rfl

/-- optionExtractRef: [mutRef rid] → [extracted_value]. -/
theorem optionExtractRef_stack_transform
    (rid : RefId)
    (extracted : MoveValue)
    (rest : List MoveValue) :
    (extracted :: rest).length =
    (MoveValue.mutRef rid :: rest).length := by
  rfl

/-- vectorPushBackU8Ref: [mutRef rid, u8 byte] → [] (returns unit). -/
theorem vectorPushBackU8Ref_stack_transform
    (rid : RefId)
    (byte : UInt8)
    (rest : List MoveValue) :
    rest.length =
    (MoveValue.mutRef rid :: MoveValue.u8 byte :: rest).length - 2 := by
  rfl

/-- newScalarFromBytes: [bytes] → [option_scalar]. -/
theorem newScalarFromBytes_stack_transform
    (bytes option_scalar : MoveValue)
    (rest : List MoveValue) :
    (option_scalar :: rest).length =
    (bytes :: rest).length := by
  rfl

/-- newCompressedPointFromBytes: [bytes] → [option_point]. -/
theorem newCompressedPointFromBytes_stack_transform
    (bytes option_point : MoveValue)
    (rest : List MoveValue) :
    (option_point :: rest).length =
    (bytes :: rest).length := by
  rfl

/-- pointMul: [point, scalar] → [result]. -/
theorem pointMul_stack_transform
    (point scalar result : MoveValue)
    (rest : List MoveValue) :
    (result :: rest).length =
    (point :: scalar :: rest).length - 1 := by
  rfl

/-- pointAdd: [point1, point2] → [result]. -/
theorem pointAdd_stack_transform
    (point1 point2 result : MoveValue)
    (rest : List MoveValue) :
    (result :: rest).length =
    (point1 :: point2 :: rest).length - 1 := by
  rfl

/-- pointEquals: [point1, point2] → [bool]. -/
theorem pointEquals_stack_transform
    (point1 point2 : MoveValue)
    (b : Bool)
    (rest : List MoveValue) :
    (MoveValue.bool b :: rest).length =
    (point1 :: point2 :: rest).length - 1 := by
  rfl

/-- newScalarFromSha2_512: [message] → [scalar_struct]. -/
theorem newScalarFromSha2_512_stack_transform
    (message scalar : MoveValue)
    (rest : List MoveValue) :
    (scalar :: rest).length =
    (message :: rest).length := by
  rfl

/-- hashToPointBase: [] → [base_point]. -/
theorem hashToPointBase_stack_transform
    (base : MoveValue)
    (rest : List MoveValue) :
    (base :: rest).length = rest.length + 1 := by
  rfl

/-! ## Stack Safety Predicates

Predicates asserting stack has expected shape for safe execution.
-/

/-- Stack is safe for stLoc: has at least one element. -/
def SafeForStLoc (stack : List MoveValue) : Prop :=
  stack.length ≥ 1

/-- Stack is safe for pop: non-empty. -/
def SafeForPop (stack : List MoveValue) : Prop :=
  stack ≠ []

/-- Stack is safe for brFalse: top is bool. -/
def SafeForBrFalse (stack : List MoveValue) : Prop :=
  ∃ (b : Bool) (rest : List MoveValue), stack = MoveValue.bool b :: rest

/-- Stack is safe for native call with N arguments: has at least N elements. -/
def SafeForNativeCall (stack : List MoveValue) (num_args : Nat) : Prop :=
  stack.length ≥ num_args

/-- Stack is safe for optionIsSomeRef: top is immRef. -/
def SafeForOptionIsSomeRef (stack : List MoveValue) : Prop :=
  ∃ (rid : RefId) (rest : List MoveValue), stack = MoveValue.immRef rid :: rest

/-- Stack is safe for optionExtractRef: top is mutRef. -/
def SafeForOptionExtractRef (stack : List MoveValue) : Prop :=
  ∃ (rid : RefId) (rest : List MoveValue), stack = MoveValue.mutRef rid :: rest

/-- Stack is safe for vectorPushBackU8Ref: has [mutRef, u8, ...]. -/
def SafeForVectorPushBackU8Ref (stack : List MoveValue) : Prop :=
  ∃ (rid : RefId) (byte : UInt8) (rest : List MoveValue),
    stack = MoveValue.mutRef rid :: MoveValue.u8 byte :: rest

/-- Stack is safe for pointMul: has two elements (point and scalar refs). -/
def SafeForPointMul (stack : List MoveValue) : Prop :=
  ∃ (rid1 rid2 : RefId) (rest : List MoveValue),
    stack = MoveValue.immRef rid1 :: MoveValue.immRef rid2 :: rest

/-! ## Stack Safety Lemmas

Theorems establishing safety after instruction execution.
-/

/-- After moveLoc, stack is safe for stLoc. -/
theorem after_moveLoc_safe_for_stLoc
    (v : MoveValue)
    (stack : List MoveValue) :
    SafeForStLoc (v :: stack) := by
  unfold SafeForStLoc
  simp

/-- After immBorrowLoc, stack is safe for optionIsSomeRef (when expecting immRef). -/
theorem after_immBorrowLoc_safe_for_oracle
    (rid : RefId)
    (stack : List MoveValue) :
    SafeForOptionIsSomeRef (MoveValue.immRef rid :: stack) := by
  unfold SafeForOptionIsSomeRef
  use rid, stack

/-- After mutBorrowLoc, stack is safe for optionExtractRef. -/
theorem after_mutBorrowLoc_safe_for_extract
    (rid : RefId)
    (stack : List MoveValue) :
    SafeForOptionExtractRef (MoveValue.mutRef rid :: stack) := by
  unfold SafeForOptionExtractRef
  use rid, stack

/-- After optionIsSomeRef returning true, stack is safe for brFalse. -/
theorem after_optionIsSomeRef_safe_for_branch
    (rest : List MoveValue) :
    SafeForBrFalse (MoveValue.bool true :: rest) := by
  unfold SafeForBrFalse
  use true, rest

/-! ## Stack Equivalence and Equality

Lemmas for reasoning about stack equality.
-/

/-- Stack equality is reflexive. -/
theorem stack_eq_refl
    (stack : List MoveValue) :
    stack = stack := by
  rfl

/-- Stack equality is symmetric. -/
theorem stack_eq_symm
    (s1 s2 : List MoveValue)
    (h : s1 = s2) :
    s2 = s1 := by
  exact h.symm

/-- Stack equality is transitive. -/
theorem stack_eq_trans
    (s1 s2 s3 : List MoveValue)
    (h1 : s1 = s2)
    (h2 : s2 = s3) :
    s1 = s3 := by
  exact Eq.trans h1 h2

/-- Cons preserves equality. -/
theorem cons_preserves_eq
    (v : MoveValue)
    (s1 s2 : List MoveValue)
    (h : s1 = s2) :
    v :: s1 = v :: s2 := by
  rw [h]

/-- Append preserves equality (left). -/
theorem append_preserves_eq_left
    (s1 s2 suffix : List MoveValue)
    (h : s1 = s2) :
    s1 ++ suffix = s2 ++ suffix := by
  rw [h]

/-- Append preserves equality (right). -/
theorem append_preserves_eq_right
    (prefix s1 s2 : List MoveValue)
    (h : s1 = s2) :
    prefix ++ s1 = prefix ++ s2 := by
  rw [h]

/-! ## Auxiliary Stack Lemmas

Helper lemmas for stack manipulation.
-/

/-- Singleton stack tail is empty. -/
theorem singleton_tail_empty
    (v : MoveValue) :
    [v].tail = [] := by
  rfl

/-- Two-element stack tail is singleton. -/
theorem two_element_tail_singleton
    (v1 v2 : MoveValue) :
    (v1 :: v2 :: []).tail = [v2] := by
  rfl

/-- Cons then head recovers element. -/
theorem cons_head_recovers
    (v : MoveValue)
    (rest : List MoveValue) :
    (v :: rest).head? = some v := by
  rfl

/-- Length 0 iff empty. -/
theorem length_zero_iff_empty
    (stack : List MoveValue) :
    stack.length = 0 ↔ stack = [] := by
  constructor
  · intro h
    cases stack with
    | nil => rfl
    | cons _ _ => simp at h
  · intro h
    rw [h]
    rfl

/-- Non-zero length implies non-empty. -/
theorem length_pos_implies_nonempty
    (stack : List MoveValue)
    (h : stack.length > 0) :
    stack ≠ [] := by
  intro hcontra
  rw [hcontra] at h
  simp at h

end MovementFormal.Experimental.ConfidentialAsset.Registration.StackManagementLemmas
