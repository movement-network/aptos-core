/-
ContainerStore API lemmas for formal verification.

This file provides properties of ContainerStore operations, particularly
around vector append operations needed for message assembly proofs in
Confidential Assets.

The ContainerStore manages mutable references and container operations
in the Move VM model. These lemmas enable reasoning about how vector
append operations affect container state.
-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.Native.Registration

namespace MovementFormal.MoveModel

open MovementFormal.MoveModel.Native.Registration

/-! ## Vector append properties -/

/-- Vector append through mutable reference preserves container equality for other references.

This is needed for message_assembly_preserves_containers in PC20_43_message_assembly.lean.

NOTE: Axiomatized because vectorAppendU8Ref is an opaque native oracle.
-/
axiom vectorAppendU8Ref_preserves_other_refs
    (containers containers' : ContainerStore)
    (rid_msg rid_other : RefId)
    (appended : MoveValue)
    (h_ne : rid_other ≠ rid_msg)
    (h_append : vectorAppendU8Ref containers [MoveValue.mutRef rid_msg, appended] =
                some ([], containers'))
    (v_other : MoveValue)
    (h_read : containers.read rid_other = some v_other) :
    containers'.read rid_other = some v_other

/-- Vector append increases the length of the vector at the target reference.

NOTE: Axiomatized because vectorAppendU8Ref is an opaque native oracle.
-/
axiom vectorAppendU8Ref_increases_length
    (containers containers' : ContainerStore)
    (rid : RefId)
    (existing : List MoveValue)
    (appended_data : List MoveValue)
    (h_read : containers.read rid = some (MoveValue.vector MoveType.u8 existing))
    (h_append : vectorAppendU8Ref containers [MoveValue.mutRef rid,
                                               MoveValue.vector MoveType.u8 appended_data] =
                some ([], containers')) :
    ∃ (result : List MoveValue),
      containers'.read rid = some (MoveValue.vector MoveType.u8 result) ∧
      result.length = existing.length + appended_data.length

/-- Vector append concatenates the appended data to the existing vector.

NOTE: Axiomatized because vectorAppendU8Ref is an opaque native oracle.
-/
axiom vectorAppendU8Ref_concatenates
    (containers containers' : ContainerStore)
    (rid : RefId)
    (existing : List MoveValue)
    (appended_data : List MoveValue)
    (h_read : containers.read rid = some (MoveValue.vector MoveType.u8 existing))
    (h_append : vectorAppendU8Ref containers [MoveValue.mutRef rid,
                                               MoveValue.vector MoveType.u8 appended_data] =
                some ([], containers')) :
    containers'.read rid = some (MoveValue.vector MoveType.u8 (existing ++ appended_data))

/-! ## Composing multiple vector appends -/

/-- Two consecutive vector appends compose as expected.

This is needed for vectorAppend_compose_two in PC20_43_message_assembly.lean.

NOTE: Axiomatized because vectorAppendU8Ref is an opaque native oracle.
-/
axiom vectorAppendU8Ref_compose_two
    (containers cs1 cs2 : ContainerStore)
    (rid : RefId)
    (part1 part2 : List MoveValue)
    (existing : List MoveValue)
    (h_read : containers.read rid = some (MoveValue.vector MoveType.u8 existing))
    (h_append1 : vectorAppendU8Ref containers [MoveValue.mutRef rid,
                                                MoveValue.vector MoveType.u8 part1] =
                 some ([], cs1))
    (h_append2 : vectorAppendU8Ref cs1 [MoveValue.mutRef rid,
                                         MoveValue.vector MoveType.u8 part2] =
                 some ([], cs2)) :
    cs2.read rid = some (MoveValue.vector MoveType.u8 (existing ++ part1 ++ part2))

/-- Three consecutive vector appends compose as expected.

NOTE: Axiomatized because vectorAppendU8Ref is an opaque native oracle.
-/
axiom vectorAppendU8Ref_compose_three
    (containers cs1 cs2 cs3 : ContainerStore)
    (rid : RefId)
    (part1 part2 part3 : List MoveValue)
    (existing : List MoveValue)
    (h_read : containers.read rid = some (MoveValue.vector MoveType.u8 existing))
    (h_append1 : vectorAppendU8Ref containers [MoveValue.mutRef rid,
                                                MoveValue.vector MoveType.u8 part1] =
                 some ([], cs1))
    (h_append2 : vectorAppendU8Ref cs1 [MoveValue.mutRef rid,
                                         MoveValue.vector MoveType.u8 part2] =
                 some ([], cs2))
    (h_append3 : vectorAppendU8Ref cs2 [MoveValue.mutRef rid,
                                         MoveValue.vector MoveType.u8 part3] =
                 some ([], cs3)) :
    cs3.read rid = some (MoveValue.vector MoveType.u8 (existing ++ part1 ++ part2 ++ part3))

/-! ## Address append properties -/

/-- Appending an address (as ByteArray) to a u8 vector increases length by 32.

NOTE: Axiomatized because vectorAppendU8Ref is an opaque native oracle.
-/
axiom vectorAppendU8Ref_address_length
    (containers containers' : ContainerStore)
    (rid : RefId)
    (addr : ByteArray)
    (existing : List MoveValue)
    (h_addr_size : addr.size = 32)
    (h_read : containers.read rid = some (MoveValue.vector MoveType.u8 existing))
    (h_append : vectorAppendU8Ref containers [MoveValue.mutRef rid,
                                               MoveValue.address addr] =
                some ([], containers')) :
    ∃ (result : List MoveValue),
      containers'.read rid = some (MoveValue.vector MoveType.u8 result) ∧
      result.length = existing.length + 32

/-! ## Single byte append properties -/

/-- Appending a single u8 to a vector increases length by 1.

NOTE: Axiomatized because vectorAppendU8Ref is an opaque native oracle.
-/
axiom vectorAppendU8Ref_u8_length
    (containers containers' : ContainerStore)
    (rid : RefId)
    (byte : UInt8)
    (existing : List MoveValue)
    (h_read : containers.read rid = some (MoveValue.vector MoveType.u8 existing))
    (h_append : vectorAppendU8Ref containers [MoveValue.mutRef rid,
                                               MoveValue.u8 byte] =
                some ([], containers')) :
    ∃ (result : List MoveValue),
      containers'.read rid = some (MoveValue.vector MoveType.u8 result) ∧
      result.length = existing.length + 1

/-! ## Container store write/read interaction -/

/-- Reading from a container after a write to a different reference returns the original value.

NOTE: Axiomatized because ContainerStore.write API may be opaque or not exposed.
-/
axiom ContainerStore.read_after_write_other
    (cs : ContainerStore)
    (rid1 rid2 : RefId)
    (v1 v2 : MoveValue)
    (h_ne : rid1 ≠ rid2)
    (cs' : ContainerStore)
    (h_write : cs' = cs.write rid1 v1)  -- Placeholder for actual write API
    (h_read : cs.read rid2 = some v2) :
    cs'.read rid2 = some v2

/-- Writing to a container and reading back returns the written value.

NOTE: Axiomatized because ContainerStore.write API may be opaque or not exposed.
-/
axiom ContainerStore.read_after_write_same
    (cs : ContainerStore)
    (rid : RefId)
    (v : MoveValue)
    (cs' : ContainerStore)
    (h_write : cs' = cs.write rid v) :  -- Placeholder for actual write API
    cs'.read rid = some v

end MovementFormal.MoveModel
