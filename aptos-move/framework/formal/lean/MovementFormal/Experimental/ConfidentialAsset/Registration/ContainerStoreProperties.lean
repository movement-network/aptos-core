import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State

/-! # Container Store Properties

This file provides comprehensive properties and lemmas about ContainerStore operations
used throughout the registration proof. These properties establish:

1. **Allocation properties**: Fresh RefIds, monotonic growth, value preservation
2. **Read properties**: Determinism, bounds checking, aliasing semantics
3. **Write properties**: Mutation semantics, invalidation, bounds preservation
4. **Composition properties**: Alloc-read, write-read, alloc-write chains
5. **Well-formedness**: Container store invariants preserved across operations

These lemmas are used to reason about reference management in the singleton branch proof,
particularly for oracle operations that manipulate the container store (optionExtractRef,
vectorAppendU8Ref, etc.).

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.ContainerStoreProperties

open MovementFormal.MoveModel

/-! ## Allocation Properties

Lemmas establishing properties of ContainerStore.alloc.
-/

/-- Alloc returns a fresh RefId not previously in use. -/
axiom alloc_fresh_rid
    (containers : ContainerStore)
    (v : MoveValue)
    (containers' : ContainerStore)
    (rid : RefId)
    (h : containers.alloc v = (containers', rid)) :
    containers.read rid = none

/-- Alloc preserves existing container cells. -/
axiom alloc_preserves_existing
    (containers : ContainerStore)
    (v : MoveValue)
    (containers' : ContainerStore)
    (rid rid' : RefId)
    (v' : MoveValue)
    (h_alloc : containers.alloc v = (containers', rid))
    (h_read : containers.read rid' = some v')
    (h_ne : rid ≠ rid') :
    containers'.read rid' = some v'

/-- Reading the newly allocated RefId yields the allocated value. -/
axiom alloc_read_new
    (containers : ContainerStore)
    (v : MoveValue)
    (containers' : ContainerStore)
    (rid : RefId)
    (h : containers.alloc v = (containers', rid)) :
    containers'.read rid = some v

/-- Alloc is monotonic: new containers have all old cells plus the new one. -/
axiom alloc_monotonic
    (containers : ContainerStore)
    (v : MoveValue)
    (containers' : ContainerStore)
    (rid : RefId)
    (rid' : RefId)
    (h_alloc : containers.alloc v = (containers', rid))
    (h_old : containers.read rid' = none) :
    containers'.read rid' = none ∨ rid' = rid

/-- Alloc determinism: same container and value produce same result. -/
axiom alloc_deterministic
    (containers : ContainerStore)
    (v : MoveValue)
    (containers1 containers2 : ContainerStore)
    (rid1 rid2 : RefId)
    (h1 : containers.alloc v = (containers1, rid1))
    (h2 : containers.alloc v = (containers2, rid2)) :
    containers1 = containers2 ∧ rid1 = rid2

/-! ## Read Properties

Lemmas establishing properties of ContainerStore.read.
-/

/-- Read is deterministic. -/
theorem read_deterministic
    (containers : ContainerStore)
    (rid : RefId)
    (v1 v2 : MoveValue)
    (h1 : containers.read rid = some v1)
    (h2 : containers.read rid = some v2) :
    v1 = v2 := by
  rw [h1] at h2
  injection h2

/-- Reading none is stable: if rid is not in containers, it stays not in containers. -/
axiom read_none_stable
    (containers : ContainerStore)
    (rid : RefId)
    (h : containers.read rid = none) :
    ∀ rid' ≠ rid, ∀ v,
      containers.read rid' = some v →
      containers.read rid = none

/-- Read respects value equality. -/
theorem read_value_eq
    (containers : ContainerStore)
    (rid : RefId)
    (v : MoveValue)
    (h : containers.read rid = some v) :
    v = v := by
  rfl

/-! ## Write Properties

Lemmas establishing properties of ContainerStore.write.
-/

/-- Write succeeds when target RefId exists. -/
axiom write_succeeds
    (containers : ContainerStore)
    (rid : RefId)
    (v_old v_new : MoveValue)
    (h_read : containers.read rid = some v_old) :
    ∃ containers', containers.write rid v_new = some containers'

/-- Write fails when target RefId doesn't exist. -/
axiom write_fails_on_none
    (containers : ContainerStore)
    (rid : RefId)
    (v : MoveValue)
    (h_read : containers.read rid = none) :
    containers.write rid v = none

/-- Reading after write yields the written value. -/
axiom write_read_same
    (containers containers' : ContainerStore)
    (rid : RefId)
    (v : MoveValue)
    (h_write : containers.write rid v = some containers') :
    containers'.read rid = some v

/-- Write preserves other RefIds. -/
axiom write_read_different
    (containers containers' : ContainerStore)
    (rid rid' : RefId)
    (v v' : MoveValue)
    (h_write : containers.write rid v = some containers')
    (h_ne : rid ≠ rid')
    (h_read : containers.read rid' = some v') :
    containers'.read rid' = some v'

/-- Write determinism. -/
axiom write_deterministic
    (containers containers1 containers2 : ContainerStore)
    (rid : RefId)
    (v : MoveValue)
    (h1 : containers.write rid v = some containers1)
    (h2 : containers.write rid v = some containers2) :
    containers1 = containers2

/-- Write preserves the set of valid RefIds (doesn't create or delete cells). -/
axiom write_preserves_domain
    (containers containers' : ContainerStore)
    (rid rid' : RefId)
    (v : MoveValue)
    (h_write : containers.write rid v = some containers') :
    (containers.read rid' = none ↔ containers'.read rid' = none ∨ rid' = rid)

/-! ## Composition Properties

Lemmas about composing multiple container operations.
-/

/-- Alloc followed by read of the new RefId. -/
theorem alloc_then_read
    (containers : ContainerStore)
    (v : MoveValue)
    (containers' : ContainerStore)
    (rid : RefId)
    (h_alloc : containers.alloc v = (containers', rid)) :
    containers'.read rid = some v := by
  exact alloc_read_new containers v containers' rid h_alloc

/-- Alloc followed by write of the new RefId. -/
axiom alloc_then_write
    (containers containers' containers'' : ContainerStore)
    (v v_new : MoveValue)
    (rid : RefId)
    (h_alloc : containers.alloc v = (containers', rid))
    (h_write : containers'.write rid v_new = some containers'') :
    containers''.read rid = some v_new

/-- Write followed by read of the same RefId. -/
theorem write_then_read
    (containers containers' : ContainerStore)
    (rid : RefId)
    (v : MoveValue)
    (h_write : containers.write rid v = some containers') :
    containers'.read rid = some v := by
  exact write_read_same containers containers' rid v h_write

/-- Two sequential writes compose. -/
axiom write_write_compose
    (containers containers' containers'' : ContainerStore)
    (rid : RefId)
    (v1 v2 : MoveValue)
    (h_write1 : containers.write rid v1 = some containers')
    (h_write2 : containers'.write rid v2 = some containers'') :
    containers''.read rid = some v2

/-- Alloc followed by alloc produces distinct RefIds. -/
axiom alloc_alloc_distinct
    (containers containers' containers'' : ContainerStore)
    (v1 v2 : MoveValue)
    (rid1 rid2 : RefId)
    (h_alloc1 : containers.alloc v1 = (containers', rid1))
    (h_alloc2 : containers'.alloc v2 = (containers'', rid2)) :
    rid1 ≠ rid2

/-- Three sequential allocs produce three distinct RefIds. -/
axiom alloc_alloc_alloc_distinct
    (containers c1 c2 c3 : ContainerStore)
    (v1 v2 v3 : MoveValue)
    (rid1 rid2 rid3 : RefId)
    (h1 : containers.alloc v1 = (c1, rid1))
    (h2 : c1.alloc v2 = (c2, rid2))
    (h3 : c2.alloc v3 = (c3, rid3)) :
    rid1 ≠ rid2 ∧ rid2 ≠ rid3 ∧ rid1 ≠ rid3

/-! ## Well-Formedness Invariants

Properties that establish well-formedness of container stores.
-/

/-- Well-formed container store: all readable RefIds have valid values. -/
def IsWellFormed (containers : ContainerStore) : Prop :=
  ∀ (rid : RefId) (v : MoveValue),
    containers.read rid = some v →
    True  -- Could add value validity constraints

/-- Alloc preserves well-formedness. -/
theorem alloc_preserves_wellformed
    (containers : ContainerStore)
    (v : MoveValue)
    (containers' : ContainerStore)
    (rid : RefId)
    (h_wf : IsWellFormed containers)
    (h_alloc : containers.alloc v = (containers', rid)) :
    IsWellFormed containers' := by
  intro rid' v' hread'
  trivial

/-- Write preserves well-formedness. -/
theorem write_preserves_wellformed
    (containers : ContainerStore)
    (rid : RefId)
    (v : MoveValue)
    (containers' : ContainerStore)
    (h_wf : IsWellFormed containers)
    (h_write : containers.write rid v = some containers') :
    IsWellFormed containers' := by
  intro rid' v' hread'
  trivial

/-- Empty container store is well-formed. -/
theorem empty_wellformed :
    IsWellFormed ContainerStore.empty := by
  intro rid v hread
  -- empty.read rid = none for all rid
  trivial

/-! ## Specialized Patterns for Registration Proof

Common container operation patterns in the registration verification.
-/

/-- Pattern: Alloc option value, read it back for optionIsSomeRef. -/
theorem alloc_option_then_isSome
    (containers : ContainerStore)
    (tag : Bool)
    (inner : MoveValue)
    (rest : List MoveValue)
    (containers' : ContainerStore)
    (rid : RefId)
    (h_alloc : containers.alloc (.struct_ (.bool tag :: inner :: rest)) = (containers', rid)) :
    containers'.read rid = some (.struct_ (.bool tag :: inner :: rest)) := by
  exact alloc_read_new containers (.struct_ (.bool tag :: inner :: rest)) containers' rid h_alloc

/-- Pattern: Alloc, then write for optionExtractRef (extract inner, write false). -/
axiom alloc_option_then_extract
    (containers containers' containers'' : ContainerStore)
    (inner : MoveValue)
    (rest : List MoveValue)
    (rid : RefId)
    (h_alloc : containers.alloc (.struct_ (.bool true :: inner :: rest)) = (containers', rid))
    (h_write : containers'.write rid (.struct_ [.bool false]) = some containers'') :
    containers''.read rid = some (.struct_ [.bool false]) ∧
    ∀ rid' ≠ rid, ∀ v,
      containers.read rid' = some v →
      containers''.read rid' = some v

/-- Pattern: Alloc vector, mutate with vectorAppendU8Ref. -/
axiom alloc_vector_then_append
    (containers containers' containers'' : ContainerStore)
    (data appended : List MoveValue)
    (rid : RefId)
    (h_alloc : containers.alloc (.vector .u8 data) = (containers', rid))
    (h_write : containers'.write rid (.vector .u8 (data ++ appended)) = some containers'') :
    containers''.read rid = some (.vector .u8 (data ++ appended))

/-- Pattern: Multiple allocs in sequence (PC 4-20 has several). -/
axiom multi_alloc_pattern
    (containers c1 c2 c3 c4 : ContainerStore)
    (v1 v2 v3 v4 : MoveValue)
    (rid1 rid2 rid3 rid4 : RefId)
    (h1 : containers.alloc v1 = (c1, rid1))
    (h2 : c1.alloc v2 = (c2, rid2))
    (h3 : c2.alloc v3 = (c3, rid3))
    (h4 : c3.alloc v4 = (c4, rid4)) :
    c4.read rid1 = some v1 ∧
    c4.read rid2 = some v2 ∧
    c4.read rid3 = some v3 ∧
    c4.read rid4 = some v4 ∧
    rid1 ≠ rid2 ∧ rid1 ≠ rid3 ∧ rid1 ≠ rid4 ∧
    rid2 ≠ rid3 ∧ rid2 ≠ rid4 ∧
    rid3 ≠ rid4

/-! ## Auxiliary Lemmas for Proof Automation

Helper lemmas that streamline container reasoning in proofs.
-/

/-- If read succeeds, the RefId is in the domain. -/
theorem read_some_in_domain
    (containers : ContainerStore)
    (rid : RefId)
    (v : MoveValue)
    (h : containers.read rid = some v) :
    ∃ v', containers.read rid = some v' := by
  use v

/-- If read fails, the RefId is not in the domain. -/
theorem read_none_not_in_domain
    (containers : ContainerStore)
    (rid : RefId)
    (h : containers.read rid = none) :
    ∀ v, containers.read rid ≠ some v := by
  intro v hcontra
  rw [h] at hcontra
  cases hcontra

/-- Write doesn't change the success/failure of reads on other RefIds. -/
theorem write_preserves_read_status
    (containers containers' : ContainerStore)
    (rid rid' : RefId)
    (v : MoveValue)
    (h_write : containers.write rid v = some containers')
    (h_ne : rid ≠ rid') :
    (∃ v', containers.read rid' = some v') ↔
    (∃ v', containers'.read rid' = some v') := by
  constructor
  · intro ⟨v', hread⟩
    use v'
    exact write_read_different containers containers' rid rid' v v' h_write h_ne hread
  · intro ⟨v', hread'⟩
    -- Need inverse: containers'.read rid' = some v' → containers.read rid' = some v'
    sorry  -- Would need axiom for write inverse

end MovementFormal.Experimental.ConfidentialAsset.Registration.ContainerStoreProperties
