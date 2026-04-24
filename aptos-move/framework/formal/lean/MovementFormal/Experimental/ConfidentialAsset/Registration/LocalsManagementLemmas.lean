import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State

/-! # Locals Management Lemmas

This file provides comprehensive lemmas for reasoning about the locals array in
the registration proof. The locals array stores local variables and is fundamental
to frame state management.

## Locals Array Structure

The registration proof uses a fixed 19-element locals array (indices 0-18):
- Size is constant throughout execution (never resized)
- Elements are `Option MoveValue` (none = uninitialized, some = has value)
- Operations: get, set (via stLoc), clear (via moveLoc)

## Common Patterns

1. **Initialization**: All parameters start as `some value`, locals as `none`
2. **Store**: `stLoc idx` sets `locals[idx] := some value`
3. **Move**: `moveLoc idx` pushes `locals[idx]`, then sets `locals[idx] := none`
4. **Preservation**: Most instructions don't modify locals

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.LocalsManagementLemmas

open MovementFormal.MoveModel

/-! ## Basic Locals Properties

Fundamental properties of locals arrays.
-/

/-- Locals array size is 19. -/
def LOCALS_SIZE : Nat := 19

/-- Well-formed locals has correct size. -/
def IsWellFormedLocals (locals : Array (Option MoveValue)) : Prop :=
  locals.size = LOCALS_SIZE

/-- Initial locals (parameters populated, rest none). -/
def buildInitialLocals
    (chainId : UInt8)
    (sender contract token : ByteArray)
    (ekBa commitBa respBa : ByteArray) :
    Array (Option MoveValue) :=
  #[
    some (.u8 chainId),
    some (.address sender),
    some (.address contract),
    some (.address token),
    some (.vector .u8 (ekBa.toList.map .u8)),
    some (.vector .u8 (commitBa.toList.map .u8)),
    some (.vector .u8 (respBa.toList.map .u8)),
    none, none, none, none, none, none, none, none, none, none, none, none
  ]

theorem initial_locals_wellformed
    (chainId : UInt8)
    (sender contract token ekBa commitBa respBa : ByteArray) :
    IsWellFormedLocals (buildInitialLocals chainId sender contract token ekBa commitBa respBa) := by
  unfold IsWellFormedLocals LOCALS_SIZE buildInitialLocals
  rfl

/-! ## Get Operations

Lemmas for reading from locals.
-/

/-- In-bounds get succeeds. -/
theorem get_inbounds_exists
    (locals : Array (Option MoveValue))
    (idx : Nat)
    (h : idx < locals.size) :
    ∃ v, locals[idx]? = some v := by
  sorry  -- Array.get? inbounds

/-- Out-of-bounds get returns none. -/
theorem get_outofbounds_none
    (locals : Array (Option MoveValue))
    (idx : Nat)
    (h : idx ≥ locals.size) :
    locals[idx]? = none := by
  sorry  -- Array.get? out of bounds

/-- Get is deterministic. -/
theorem get_deterministic
    (locals : Array (Option MoveValue))
    (idx : Nat)
    (v1 v2 : Option MoveValue)
    (h1 : locals[idx]? = some v1)
    (h2 : locals[idx]? = some v2) :
    v1 = v2 := by
  rw [h1] at h2
  injection h2

/-- Getting from initial locals (parameters). -/
theorem get_initial_param
    (chainId : UInt8)
    (sender contract token ekBa commitBa respBa : ByteArray)
    (idx : Nat)
    (h : idx < 7) :
    ∃ v, (buildInitialLocals chainId sender contract token ekBa commitBa respBa)[idx]? = some (some v) := by
  sorry  -- From buildInitialLocals definition

/-- Getting from initial locals (uninit). -/
theorem get_initial_uninit
    (chainId : UInt8)
    (sender contract token ekBa commitBa respBa : ByteArray)
    (idx : Nat)
    (h : 7 ≤ idx ∧ idx < 19) :
    (buildInitialLocals chainId sender contract token ekBa commitBa respBa)[idx]? = some none := by
  sorry  -- From buildInitialLocals definition

/-! ## Set Operations

Lemmas for writing to locals (stLoc).
-/

/-- Set preserves size. -/
theorem set_preserves_size
    (locals : Array (Option MoveValue))
    (idx : Nat)
    (v : Option MoveValue)
    (h : idx < locals.size) :
    (locals.set idx v h).size = locals.size := by
  sorry  -- Array.set size preservation

/-- Set modifies target index. -/
theorem set_modifies_target
    (locals : Array (Option MoveValue))
    (idx : Nat)
    (v : Option MoveValue)
    (h : idx < locals.size) :
    (locals.set idx v h)[idx]'(by sorry) = v := by
  sorry  -- Array.set reads back the written value

/-- Set preserves other indices. -/
theorem set_preserves_others
    (locals : Array (Option MoveValue))
    (idx idx' : Nat)
    (v : Option MoveValue)
    (h : idx < locals.size)
    (h' : idx' < locals.size)
    (hne : idx ≠ idx') :
    (locals.set idx v h)[idx']'(by sorry) = locals[idx']'h' := by
  sorry  -- Array.set independence

/-- set! preserves size (unsafe version). -/
theorem set_bang_preserves_size
    (locals : Array (Option MoveValue))
    (idx : Nat)
    (v : Option MoveValue) :
    (locals.set! idx v).size = locals.size := by
  sorry  -- Array.set! size preservation

/-- set! modifies target (when in bounds). -/
theorem set_bang_modifies_target_inbounds
    (locals : Array (Option MoveValue))
    (idx : Nat)
    (v : Option MoveValue)
    (h : idx < locals.size) :
    (locals.set! idx v)[idx]? = some v := by
  sorry  -- Array.set! reads back when in bounds

/-! ## Sequential Updates

Lemmas for multiple sequential set operations.
-/

/-- Two sequential sets to different indices. -/
theorem set_set_different
    (locals : Array (Option MoveValue))
    (idx1 idx2 : Nat)
    (v1 v2 : Option MoveValue)
    (h1 : idx1 < locals.size)
    (h2 : idx2 < locals.size)
    (hne : idx1 ≠ idx2) :
    ((locals.set idx1 v1 h1).set idx2 v2 (by sorry))[idx1]'(by sorry) = v1 ∧
    ((locals.set idx1 v1 h1).set idx2 v2 (by sorry))[idx2]'(by sorry) = v2 := by
  sorry  -- Both values written independently

/-- Two sequential sets to same index (second overwrites). -/
theorem set_set_same
    (locals : Array (Option MoveValue))
    (idx : Nat)
    (v1 v2 : Option MoveValue)
    (h : idx < locals.size) :
    ((locals.set idx v1 h).set idx v2 (by sorry))[idx]'(by sorry) = v2 := by
  sorry  -- Second set overwrites first

/-- Three sequential sets. -/
theorem set_set_set
    (locals : Array (Option MoveValue))
    (idx1 idx2 idx3 : Nat)
    (v1 v2 v3 : Option MoveValue)
    (h1 : idx1 < locals.size)
    (h2 : idx2 < locals.size)
    (h3 : idx3 < locals.size)
    (h12 : idx1 ≠ idx2)
    (h13 : idx1 ≠ idx3)
    (h23 : idx2 ≠ idx3) :
    (((locals.set idx1 v1 h1).set idx2 v2 (by sorry)).set idx3 v3 (by sorry))[idx1]'(by sorry) = v1 := by
  sorry  -- Independence of three sets

/-! ## Locals Comparison

Lemmas for comparing locals arrays.
-/

/-- Locals equality is reflexive. -/
theorem locals_eq_refl
    (locals : Array (Option MoveValue)) :
    locals = locals := by
  rfl

/-- Locals equality is symmetric. -/
theorem locals_eq_symm
    (l1 l2 : Array (Option MoveValue))
    (h : l1 = l2) :
    l2 = l1 := by
  exact h.symm

/-- Locals equality is transitive. -/
theorem locals_eq_trans
    (l1 l2 l3 : Array (Option MoveValue))
    (h1 : l1 = l2)
    (h2 : l2 = l3) :
    l1 = l3 := by
  exact Eq.trans h1 h2

/-- Locals are equal iff all indices are equal. -/
theorem locals_eq_iff_pointwise
    (l1 l2 : Array (Option MoveValue))
    (h_size : l1.size = l2.size) :
    l1 = l2 ↔ ∀ idx < l1.size, l1[idx]'(by sorry) = l2[idx]'(by sorry) := by
  sorry  -- Array extensionality

/-! ## Locals Initialization Patterns

Lemmas for common initialization sequences.
-/

/-- Storing v in local 7 (first local variable). -/
def storeInLocal7
    (chainId : UInt8)
    (sender contract token ekBa commitBa respBa : ByteArray)
    (v : MoveValue) :
    Array (Option MoveValue) :=
  (buildInitialLocals chainId sender contract token ekBa commitBa respBa).set! 7 (some v)

theorem storeInLocal7_preserves_params
    (chainId : UInt8)
    (sender contract token ekBa commitBa respBa : ByteArray)
    (v : MoveValue)
    (idx : Nat)
    (h : idx < 7) :
    (storeInLocal7 chainId sender contract token ekBa commitBa respBa v)[idx]? =
    (buildInitialLocals chainId sender contract token ekBa commitBa respBa)[idx]? := by
  sorry  -- set! at index 7 doesn't affect indices < 7

theorem storeInLocal7_sets_7
    (chainId : UInt8)
    (sender contract token ekBa commitBa respBa : ByteArray)
    (v : MoveValue) :
    (storeInLocal7 chainId sender contract token ekBa commitBa respBa v)[7]? = some (some v) := by
  sorry  -- set! at index 7 sets that index

/-- Storing in multiple locals (7, 8, 9). -/
def storeInLocals789
    (chainId : UInt8)
    (sender contract token ekBa commitBa respBa : ByteArray)
    (v7 v8 v9 : MoveValue) :
    Array (Option MoveValue) :=
  (((buildInitialLocals chainId sender contract token ekBa commitBa respBa).set! 7 (some v7)).set! 8 (some v8)).set! 9 (some v9)

theorem storeInLocals789_all_set
    (chainId : UInt8)
    (sender contract token ekBa commitBa respBa : ByteArray)
    (v7 v8 v9 : MoveValue) :
    (storeInLocals789 chainId sender contract token ekBa commitBa respBa v7 v8 v9)[7]? = some (some v7) ∧
    (storeInLocals789 chainId sender contract token ekBa commitBa respBa v7 v8 v9)[8]? = some (some v8) ∧
    (storeInLocals789 chainId sender contract token ekBa commitBa respBa v7 v8 v9)[9]? = some (some v9) := by
  sorry  -- All three indices set correctly

/-! ## Locals Move Patterns

Lemmas for moveLoc (consuming a local).
-/

/-- Moving a local sets it to none. -/
def moveLocal
    (locals : Array (Option MoveValue))
    (idx : Nat) :
    Array (Option MoveValue) :=
  locals.set! idx none

theorem moveLocal_clears_index
    (locals : Array (Option MoveValue))
    (idx : Nat)
    (h : idx < locals.size) :
    (moveLocal locals idx)[idx]? = some none := by
  sorry  -- set! to none

theorem moveLocal_preserves_others
    (locals : Array (Option MoveValue))
    (idx idx' : Nat)
    (h : idx < locals.size)
    (h' : idx' < locals.size)
    (hne : idx ≠ idx') :
    (moveLocal locals idx)[idx']? = locals[idx']? := by
  sorry  -- Independence

/-! ## Locals Validity Predicates

Predicates for well-formed locals states.
-/

/-- Local has a value (not none). -/
def HasValue (locals : Array (Option MoveValue)) (idx : Nat) : Prop :=
  idx < locals.size ∧ ∃ v, locals[idx]? = some (some v)

/-- Local is uninitialized (is none). -/
def IsUninit (locals : Array (Option MoveValue)) (idx : Nat) : Prop :=
  idx < locals.size ∧ locals[idx]? = some none

/-- Parameters (indices 0-6) always have values. -/
theorem params_always_have_values
    (chainId : UInt8)
    (sender contract token ekBa commitBa respBa : ByteArray)
    (idx : Nat)
    (h : idx < 7) :
    HasValue (buildInitialLocals chainId sender contract token ekBa commitBa respBa) idx := by
  unfold HasValue
  constructor
  · sorry  -- idx < 19
  · sorry  -- From buildInitialLocals

/-- Local variables (indices 7-18) start uninitialized. -/
theorem locals_start_uninit
    (chainId : UInt8)
    (sender contract token ekBa commitBa respBa : ByteArray)
    (idx : Nat)
    (h : 7 ≤ idx ∧ idx < 19) :
    IsUninit (buildInitialLocals chainId sender contract token ekBa commitBa respBa) idx := by
  unfold IsUninit
  constructor
  · sorry  -- idx < 19
  · sorry  -- From buildInitialLocals

/-! ## Locals Update Invariants

Properties preserved across locals updates.
-/

/-- stLoc preserves well-formedness. -/
theorem stLoc_preserves_wellformed
    (locals : Array (Option MoveValue))
    (idx : Nat)
    (v : MoveValue)
    (h_wf : IsWellFormedLocals locals)
    (h_idx : idx < locals.size) :
    IsWellFormedLocals (locals.set! idx (some v)) := by
  unfold IsWellFormedLocals at *
  exact set_bang_preserves_size locals idx (some v) ▸ h_wf

/-- moveLoc preserves well-formedness. -/
theorem moveLoc_preserves_wellformed
    (locals : Array (Option MoveValue))
    (idx : Nat)
    (h_wf : IsWellFormedLocals locals)
    (h_idx : idx < locals.size) :
    IsWellFormedLocals (moveLocal locals idx) := by
  unfold IsWellFormedLocals at *
  unfold moveLocal
  exact set_bang_preserves_size locals idx none ▸ h_wf

/-! ## Auxiliary Lemmas

Helper lemmas for locals reasoning.
-/

/-- Locals with all parameters, no local variables. -/
def onlyParamsLocals
    (chainId : UInt8)
    (sender contract token ekBa commitBa respBa : ByteArray) :
    Array (Option MoveValue) :=
  buildInitialLocals chainId sender contract token ekBa commitBa respBa

/-- Updating local doesn't affect parameters. -/
theorem update_local_preserves_params
    (chainId : UInt8)
    (sender contract token ekBa commitBa respBa : ByteArray)
    (local_idx : Nat)
    (v : MoveValue)
    (param_idx : Nat)
    (h_local : 7 ≤ local_idx ∧ local_idx < 19)
    (h_param : param_idx < 7) :
    ((onlyParamsLocals chainId sender contract token ekBa commitBa respBa).set! local_idx (some v))[param_idx]? =
    (onlyParamsLocals chainId sender contract token ekBa commitBa respBa)[param_idx]? := by
  sorry  -- set! at local_idx ≥ 7 doesn't affect param_idx < 7

/-- Reading parameter is always successful. -/
theorem read_param_always_succeeds
    (chainId : UInt8)
    (sender contract token ekBa commitBa respBa : ByteArray)
    (idx : Nat)
    (h : idx < 7) :
    ∃ v, (buildInitialLocals chainId sender contract token ekBa commitBa respBa)[idx]? = some (some v) := by
  sorry  -- From buildInitialLocals

end MovementFormal.Experimental.ConfidentialAsset.Registration.LocalsManagementLemmas
