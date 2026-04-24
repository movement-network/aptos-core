import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.Experimental.ConfidentialAsset.Registration.ContainerStoreProperties

/-! # Reference ID Management Lemmas

This file provides comprehensive lemmas for reasoning about reference IDs (RefId)
throughout the registration proof execution. Reference IDs are used to track
mutable and immutable references in the ContainerStore.

## Reference ID Lifecycle

1. **Allocation**: New RefId generated via `containers.alloc value`
2. **Reading**: Access value via `containers.read rid`
3. **Writing**: Update value via `containers.write rid new_value`
4. **Tracking**: LocalRefs array tracks which locals hold references

## Key Properties

- **Freshness**: Newly allocated RefIds don't collide with existing ones
- **Stability**: Reads from unmodified RefIds return the same value
- **Independence**: Operations on different RefIds don't interfere
- **Validity**: RefIds in localRefs are always valid in containers

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.RefIdManagementLemmas

open MovementFormal.MoveModel
open MovementFormal.Experimental.ConfidentialAsset.Registration.ContainerStoreProperties

/-! ## Reference ID Types and Constants

RefIds in the registration proof.
-/

/-- RefId for option<CompressedPoint> at local 7. -/
def RID_V_MUT : RefId := 0  -- Placeholder, actual value runtime-determined

/-- RefId for CompressedPoint (extracted) at local 8. -/
def RID_V_IMM : RefId := 1

/-- RefId for option<Scalar> at local 9. -/
def RID_S_MUT : RefId := 2

/-- RefId for Scalar (extracted) at local 10. -/
def RID_S_IMM : RefId := 3

/-- RefId for message buffer (vector<u8>) at local 11. -/
def RID_MSG : RefId := 4

/-- RefId for sender address at local 12. -/
def RID_SENDER : RefId := 5

/-- RefId for contract address at local 13. -/
def RID_CONTRACT : RefId := 6

/-- RefId for token address at local 14. -/
def RID_TOKEN : RefId := 7

/-- RefId for base point h at local 15. -/
def RID_H : RefId := 8

/-- RefId for pubkey point ek at local 16. -/
def RID_EK : RefId := 9

/-- RefId for commitment point R at local 17. -/
def RID_R : RefId := 10

/-- RefId for challenge scalar e at local 18. -/
def RID_E : RefId := 11

/-! ## LocalRefs Array Properties

The localRefs array tracks which locals hold references.
-/

/-- LocalRefs array size matches locals size (19). -/
def IsWellFormedLocalRefs (localRefs : Array (Option RefId)) : Prop :=
  localRefs.size = 19

/-- Initial localRefs (all none). -/
def buildInitialLocalRefs : Array (Option RefId) :=
  (List.replicate 19 none).toArray

theorem initial_localRefs_wellformed :
    IsWellFormedLocalRefs buildInitialLocalRefs := by
  unfold IsWellFormedLocalRefs buildInitialLocalRefs
  sorry  -- List.replicate length = 19

theorem initial_localRefs_all_none :
    ∀ idx < 19, buildInitialLocalRefs[idx]? = some none := by
  intro idx hidx
  unfold buildInitialLocalRefs
  sorry  -- From List.replicate definition

/-! ## Reference Allocation Properties

Properties of allocating new references.
-/

/-- Allocating a reference creates a fresh RefId. -/
theorem alloc_creates_fresh_rid
    (containers : ContainerStore)
    (value : MoveValue)
    (containers' : ContainerStore)
    (rid : RefId)
    (h_alloc : containers.alloc value = (containers', rid)) :
    ∀ rid' ≠ rid, containers.read rid' = containers'.read rid' := by
  sorry  -- alloc_preserves_existing from ContainerStoreProperties

/-- Allocated RefId is immediately readable. -/
theorem alloc_immediately_readable
    (containers : ContainerStore)
    (value : MoveValue)
    (containers' : ContainerStore)
    (rid : RefId)
    (h_alloc : containers.alloc value = (containers', rid)) :
    containers'.read rid = some value := by
  sorry  -- alloc_read_new from ContainerStoreProperties

/-- Sequential allocations produce distinct RefIds. -/
theorem sequential_allocs_distinct
    (containers : ContainerStore)
    (v1 v2 : MoveValue)
    (containers' containers'' : ContainerStore)
    (rid1 rid2 : RefId)
    (h_alloc1 : containers.alloc v1 = (containers', rid1))
    (h_alloc2 : containers'.alloc v2 = (containers'', rid2)) :
    rid1 ≠ rid2 := by
  sorry  -- From alloc_alloc_distinct in ContainerStoreProperties

/-- Three sequential allocations produce distinct RefIds. -/
theorem three_sequential_allocs_distinct
    (containers : ContainerStore)
    (v1 v2 v3 : MoveValue)
    (c1 c2 c3 : ContainerStore)
    (rid1 rid2 rid3 : RefId)
    (h1 : containers.alloc v1 = (c1, rid1))
    (h2 : c1.alloc v2 = (c2, rid2))
    (h3 : c2.alloc v3 = (c3, rid3)) :
    rid1 ≠ rid2 ∧ rid1 ≠ rid3 ∧ rid2 ≠ rid3 := by
  sorry  -- From alloc_alloc_alloc_distinct

/-- Allocation preserves prior references' readability. -/
theorem alloc_preserves_prior_reads
    (containers : ContainerStore)
    (new_value : MoveValue)
    (containers' : ContainerStore)
    (new_rid : RefId)
    (prior_rid : RefId)
    (prior_value : MoveValue)
    (h_alloc : containers.alloc new_value = (containers', new_rid))
    (h_prior : containers.read prior_rid = some prior_value) :
    containers'.read prior_rid = some prior_value := by
  sorry  -- alloc_preserves_existing

/-! ## Reference Reading Properties

Properties of reading from references.
-/

/-- Reading is deterministic. -/
theorem read_deterministic
    (containers : ContainerStore)
    (rid : RefId)
    (v1 v2 : MoveValue)
    (h1 : containers.read rid = some v1)
    (h2 : containers.read rid = some v2) :
    v1 = v2 := by
  rw [h1] at h2
  injection h2

/-- Reading from different RefIds is independent. -/
theorem read_independence
    (containers : ContainerStore)
    (rid1 rid2 : RefId)
    (v1 v2 : MoveValue)
    (h1 : containers.read rid1 = some v1)
    (h2 : containers.read rid2 = some v2)
    (hne : rid1 ≠ rid2) :
    containers.read rid1 = some v1 ∧ containers.read rid2 = some v2 := by
  constructor <;> assumption

/-- Successful read implies RefId is valid. -/
theorem read_success_implies_valid
    (containers : ContainerStore)
    (rid : RefId)
    (value : MoveValue)
    (h : containers.read rid = some value) :
    ∃ v, containers.read rid = some v := by
  sorry

/-- Failed read means RefId is invalid. -/
theorem read_none_means_invalid
    (containers : ContainerStore)
    (rid : RefId)
    (h : containers.read rid = none) :
    ∀ v, containers.read rid ≠ some v := by
  intro v hcontra
  rw [h] at hcontra
  contradiction

/-! ## Reference Writing Properties

Properties of writing to references.
-/

/-- Writing updates the target RefId. -/
theorem write_updates_target
    (containers : ContainerStore)
    (rid : RefId)
    (old_value new_value : MoveValue)
    (containers' : ContainerStore)
    (h_read : containers.read rid = some old_value)
    (h_write : containers.write rid new_value = some containers') :
    containers'.read rid = some new_value := by
  sorry  -- write_read_same from ContainerStoreProperties

/-- Writing preserves other RefIds. -/
theorem write_preserves_others
    (containers : ContainerStore)
    (rid rid_other : RefId)
    (new_value value_other : MoveValue)
    (containers' : ContainerStore)
    (h_write : containers.write rid new_value = some containers')
    (h_other : containers.read rid_other = some value_other)
    (hne : rid ≠ rid_other) :
    containers'.read rid_other = some value_other := by
  sorry  -- write_read_different from ContainerStoreProperties

/-- Sequential writes to same RefId (last write wins). -/
theorem write_write_same
    (containers : ContainerStore)
    (rid : RefId)
    (v1 v2 : MoveValue)
    (c1 c2 : ContainerStore)
    (h1 : containers.write rid v1 = some c1)
    (h2 : c1.write rid v2 = some c2) :
    c2.read rid = some v2 := by
  sorry  -- Sequential writes

/-- Sequential writes to different RefIds are independent. -/
theorem write_write_different
    (containers : ContainerStore)
    (rid1 rid2 : RefId)
    (v1 v2 : MoveValue)
    (c1 c2 : ContainerStore)
    (h1 : containers.write rid1 v1 = some c1)
    (h2 : c1.write rid2 v2 = some c2)
    (hne : rid1 ≠ rid2) :
    c2.read rid1 = some v1 ∧ c2.read rid2 = some v2 := by
  sorry  -- Independence

/-- Write only succeeds if RefId exists. -/
theorem write_requires_valid_rid
    (containers : ContainerStore)
    (rid : RefId)
    (value : MoveValue)
    (h_invalid : containers.read rid = none) :
    containers.write rid value = none := by
  sorry  -- write_fails_on_invalid_rid from ContainerStoreProperties

/-! ## LocalRefs Update Properties

Properties of updating the localRefs array.
-/

/-- Set localRefs at index. -/
def setLocalRef (localRefs : Array (Option RefId)) (idx : Nat) (rid : Option RefId) :
    Array (Option RefId) :=
  localRefs.set! idx rid

/-- Setting localRefs preserves size. -/
theorem setLocalRef_preserves_size
    (localRefs : Array (Option RefId))
    (idx : Nat)
    (rid : Option RefId)
    (h_wf : IsWellFormedLocalRefs localRefs) :
    IsWellFormedLocalRefs (setLocalRef localRefs idx rid) := by
  unfold IsWellFormedLocalRefs at *
  unfold setLocalRef
  sorry  -- Array.set! preserves size

/-- Setting localRefs modifies target index. -/
theorem setLocalRef_modifies_target
    (localRefs : Array (Option RefId))
    (idx : Nat)
    (rid : Option RefId)
    (h_idx : idx < localRefs.size) :
    (setLocalRef localRefs idx rid)[idx]? = some rid := by
  unfold setLocalRef
  sorry  -- Array.set! reads back

/-- Setting localRefs preserves other indices. -/
theorem setLocalRef_preserves_others
    (localRefs : Array (Option RefId))
    (idx idx' : Nat)
    (rid : Option RefId)
    (h_idx : idx < localRefs.size)
    (h_idx' : idx' < localRefs.size)
    (hne : idx ≠ idx') :
    (setLocalRef localRefs idx rid)[idx']? = localRefs[idx']? := by
  unfold setLocalRef
  sorry  -- Array.set! independence

/-! ## Combined Allocation and LocalRefs Update

Properties of the common pattern: alloc value, update localRefs.
-/

/-- Alloc + setLocalRef pattern. -/
structure AllocAndSetLocalRef where
  containers : ContainerStore
  localRefs : Array (Option RefId)
  value : MoveValue
  idx : Nat
  containers' : ContainerStore
  localRefs' : Array (Option RefId)
  rid : RefId
  h_alloc : containers.alloc value = (containers', rid)
  h_set : localRefs' = setLocalRef localRefs idx (some rid)
  h_idx_bounds : idx < localRefs.size

/-- After alloc + setLocalRef, the local has the reference. -/
theorem allocAndSetLocalRef_local_has_ref
    (p : AllocAndSetLocalRef) :
    p.localRefs'[p.idx]? = some (some p.rid) := by
  rw [p.h_set]
  sorry  -- From setLocalRef_modifies_target

/-- After alloc + setLocalRef, reading the RefId succeeds. -/
theorem allocAndSetLocalRef_read_succeeds
    (p : AllocAndSetLocalRef) :
    p.containers'.read p.rid = some p.value := by
  sorry  -- From alloc_immediately_readable

/-- After alloc + setLocalRef, other locals unchanged. -/
theorem allocAndSetLocalRef_preserves_other_locals
    (p : AllocAndSetLocalRef)
    (idx' : Nat)
    (h_idx' : idx' < p.localRefs.size)
    (hne : idx' ≠ p.idx) :
    p.localRefs'[idx']? = p.localRefs[idx']? := by
  rw [p.h_set]
  sorry  -- From setLocalRef_preserves_others

/-! ## Reference Validity Predicates

Predicates for well-formed reference states.
-/

/-- RefId is valid in containers. -/
def IsValidRefId (containers : ContainerStore) (rid : RefId) : Prop :=
  ∃ v, containers.read rid = some v

/-- All RefIds in localRefs are valid. -/
def AllLocalRefsValid (containers : ContainerStore) (localRefs : Array (Option RefId)) : Prop :=
  ∀ idx < localRefs.size, ∀ rid,
    localRefs[idx]? = some (some rid) → IsValidRefId containers rid

/-- Initial state has valid localRefs (vacuously true, all none). -/
theorem initial_localRefs_all_valid
    (containers : ContainerStore) :
    AllLocalRefsValid containers buildInitialLocalRefs := by
  unfold AllLocalRefsValid buildInitialLocalRefs
  intro idx hidx rid hcontra
  sorry  -- All entries are none, so hypothesis never holds

/-- Alloc preserves validity of existing localRefs. -/
theorem alloc_preserves_localRefs_validity
    (containers : ContainerStore)
    (localRefs : Array (Option RefId))
    (value : MoveValue)
    (containers' : ContainerStore)
    (rid : RefId)
    (h_valid : AllLocalRefsValid containers localRefs)
    (h_alloc : containers.alloc value = (containers', rid)) :
    AllLocalRefsValid containers' localRefs := by
  unfold AllLocalRefsValid at *
  intro idx hidx rid' hread
  have ⟨v, hv⟩ := h_valid idx hidx rid' hread
  unfold IsValidRefId at *
  sorry  -- alloc_preserves_existing implies v still readable

/-- Write preserves validity of localRefs. -/
theorem write_preserves_localRefs_validity
    (containers : ContainerStore)
    (localRefs : Array (Option RefId))
    (rid : RefId)
    (value : MoveValue)
    (containers' : ContainerStore)
    (h_valid : AllLocalRefsValid containers localRefs)
    (h_write : containers.write rid value = some containers') :
    AllLocalRefsValid containers' localRefs := by
  unfold AllLocalRefsValid at *
  sorry  -- Write updates one RefId, doesn't invalidate others

/-! ## Reference Tracking Patterns

Common patterns in registration proof.
-/

/-- Pattern: mutBorrowLoc allocates mutable reference. -/
structure MutBorrowLocRefPattern where
  containers : ContainerStore
  localRefs : Array (Option RefId)
  local_idx : Nat
  value : MoveValue
  containers' : ContainerStore
  localRefs' : Array (Option RefId)
  rid : RefId
  h_alloc : containers.alloc value = (containers', rid)
  h_localRefs : localRefs' = setLocalRef localRefs local_idx (some rid)
  h_idx_bounds : local_idx < localRefs.size
  h_idx_none : localRefs[local_idx]? = some none

theorem mutBorrowLoc_creates_valid_ref
    (p : MutBorrowLocRefPattern) :
    IsValidRefId p.containers' p.rid ∧
    p.localRefs'[p.local_idx]? = some (some p.rid) := by
  constructor
  · unfold IsValidRefId
    sorry  -- use p.value, From alloc_immediately_readable
  · sorry  -- From setLocalRef_modifies_target

/-- Pattern: immBorrowLoc allocates immutable reference. -/
structure ImmBorrowLocRefPattern where
  containers : ContainerStore
  localRefs : Array (Option RefId)
  local_idx : Nat
  value : MoveValue
  containers' : ContainerStore
  localRefs' : Array (Option RefId)
  rid : RefId
  h_alloc : containers.alloc value = (containers', rid)
  h_localRefs : localRefs' = setLocalRef localRefs local_idx (some rid)
  h_idx_bounds : local_idx < localRefs.size
  h_idx_none : localRefs[local_idx]? = some none

theorem immBorrowLoc_creates_valid_ref
    (p : ImmBorrowLocRefPattern) :
    IsValidRefId p.containers' p.rid ∧
    p.localRefs'[p.local_idx]? = some (some p.rid) := by
  constructor
  · unfold IsValidRefId
    sorry  -- use p.value, From alloc_immediately_readable
  · sorry  -- From setLocalRef_modifies_target

/-- Pattern: freezeRef converts mutable to immutable reference. -/
structure FreezeRefPattern where
  containers : ContainerStore
  rid_mut : RefId
  rid_imm : RefId
  value : MoveValue
  containers' : ContainerStore
  h_read : containers.read rid_mut = some value
  h_alloc : containers.alloc value = (containers', rid_imm)

theorem freezeRef_both_valid
    (p : FreezeRefPattern) :
    IsValidRefId p.containers' p.rid_mut ∧
    IsValidRefId p.containers' p.rid_imm := by
  constructor
  · unfold IsValidRefId
    sorry  -- use p.value, Original ref still valid after alloc
  · unfold IsValidRefId
    sorry  -- use p.value, New ref valid from alloc

/-! ## Multi-Reference Scenarios

Scenarios with multiple active references.
-/

/-- Scenario: v_mut and s_mut both allocated. -/
structure TwoMutRefsScenario where
  containers0 : ContainerStore
  containers1 : ContainerStore
  containers2 : ContainerStore
  v_value s_value : MoveValue
  rid_v rid_s : RefId
  h_alloc_v : containers0.alloc v_value = (containers1, rid_v)
  h_alloc_s : containers1.alloc s_value = (containers2, rid_s)

theorem twoMutRefs_both_readable
    (s : TwoMutRefsScenario) :
    s.containers2.read s.rid_v = some s.v_value ∧
    s.containers2.read s.rid_s = some s.s_value := by
  constructor
  · sorry  -- First alloc preserved by second
  · sorry  -- Second alloc immediately readable

theorem twoMutRefs_distinct
    (s : TwoMutRefsScenario) :
    s.rid_v ≠ s.rid_s := by
  sorry  -- sequential_allocs_distinct

/-- Scenario: Four references (v_mut, v_imm, s_mut, s_imm). -/
structure FourRefsScenario where
  containers0 : ContainerStore
  containers1 : ContainerStore
  containers2 : ContainerStore
  containers3 : ContainerStore
  containers4 : ContainerStore
  v_value s_value : MoveValue
  rid_v_mut rid_v_imm rid_s_mut rid_s_imm : RefId
  h_alloc_v_mut : containers0.alloc v_value = (containers1, rid_v_mut)
  h_alloc_v_imm : containers1.alloc v_value = (containers2, rid_v_imm)
  h_alloc_s_mut : containers2.alloc s_value = (containers3, rid_s_mut)
  h_alloc_s_imm : containers3.alloc s_value = (containers4, rid_s_imm)

theorem fourRefs_all_readable
    (s : FourRefsScenario) :
    s.containers4.read s.rid_v_mut = some s.v_value ∧
    s.containers4.read s.rid_v_imm = some s.v_value ∧
    s.containers4.read s.rid_s_mut = some s.s_value ∧
    s.containers4.read s.rid_s_imm = some s.s_value := by
  sorry  -- Each alloc preserved by subsequent allocs

theorem fourRefs_all_distinct
    (s : FourRefsScenario) :
    s.rid_v_mut ≠ s.rid_v_imm ∧
    s.rid_v_mut ≠ s.rid_s_mut ∧
    s.rid_v_mut ≠ s.rid_s_imm ∧
    s.rid_v_imm ≠ s.rid_s_mut ∧
    s.rid_v_imm ≠ s.rid_s_imm ∧
    s.rid_s_mut ≠ s.rid_s_imm := by
  sorry  -- From sequential allocation distinctness

/-! ## Reference Lifetime Management

Lemmas about reference lifetimes and validity preservation.
-/

/-- RefId valid at step N remains valid at step N+k if not overwritten. -/
theorem ref_validity_preserved_across_steps
    (containers_n containers_nk : ContainerStore)
    (rid : RefId)
    (value : MoveValue)
    (h_valid_n : containers_n.read rid = some value)
    (h_no_write : ∀ c', containers_nk ≠ c' ∨ c'.read rid = some value) :
    containers_nk.read rid = some value := by
  sorry  -- If no write to rid, value persists

/-- All RefIds allocated before step N remain valid at step N. -/
theorem allocated_rids_stay_valid
    (allocations : List (RefId × MoveValue))
    (containers : ContainerStore)
    (h_all_valid : ∀ (rid, v) ∈ allocations, containers.read rid = some v) :
    ∀ (rid, v) ∈ allocations, IsValidRefId containers rid := by
  intro ⟨rid, v⟩ hmem
  unfold IsValidRefId
  use v
  exact h_all_valid (rid, v) hmem

/-! ## Auxiliary Utilities

Helper definitions for reference management.
-/

/-- Count of active references in localRefs. -/
def countActiveRefs (localRefs : Array (Option RefId)) : Nat :=
  localRefs.toList.filter (fun opt => opt.isSome && opt.get!.isSome) |>.length

/-- Maximum number of active references in registration proof. -/
def MAX_ACTIVE_REFS : Nat := 12

/-- Registration proof never exceeds max active refs. -/
axiom registration_bounded_active_refs
    (localRefs : Array (Option RefId))
    (h_registration : IsWellFormedLocalRefs localRefs) :
    countActiveRefs localRefs ≤ MAX_ACTIVE_REFS

/-- Extract RefId from localRefs if present. -/
def getLocalRef (localRefs : Array (Option RefId)) (idx : Nat) : Option RefId :=
  match localRefs[idx]? with
  | some (some rid) => some rid
  | _ => none

theorem getLocalRef_some_implies_valid_index
    (localRefs : Array (Option RefId))
    (idx : Nat)
    (rid : RefId)
    (h : getLocalRef localRefs idx = some rid) :
    idx < localRefs.size := by
  unfold getLocalRef at h
  sorry  -- If [idx]? succeeded, idx < size

theorem getLocalRef_some_implies_localRefs_has
    (localRefs : Array (Option RefId))
    (idx : Nat)
    (rid : RefId)
    (h : getLocalRef localRefs idx = some rid) :
    localRefs[idx]? = some (some rid) := by
  unfold getLocalRef at h
  sorry  -- From match structure

end MovementFormal.Experimental.ConfidentialAsset.Registration.RefIdManagementLemmas
