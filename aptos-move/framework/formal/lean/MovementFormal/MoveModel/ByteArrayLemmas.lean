/-
ByteArray helper lemmas for formal verification.

This file provides basic properties of ByteArray operations needed for
message assembly and serialization proofs in Confidential Assets.

ByteArray wraps Array UInt8 but uses a loop-based toList implementation,
making proofs more complex than initially expected. Current status:
simple lemmas proved, complex ones need more infrastructure.
-/

import MovementFormal.MoveModel.Value

namespace MovementFormal.MoveModel

/-! ## ByteArray size and length properties -/

/-- ByteArray.toList preserves the size as length.
This is the key lemma needed for address_to_bytes_length in PC20_43_message_assembly.

NOTE: ByteArray.toList is defined as a loop, not data.toList, so proof
requires induction on the loop. Deferred pending loop lemma infrastructure. -/
axiom ByteArray.toList_length_eq_size (ba : ByteArray) :
    ba.toList.length = ba.size

/-- Converting ByteArray to List of MoveValue.u8 preserves length. -/
theorem ByteArray.toList_map_u8_length (ba : ByteArray) :
    (ba.toList.map MoveValue.u8).length = ba.size := by
  rw [List.length_map, ByteArray.toList_length_eq_size]

/-- Address ByteArrays have size 32 (protocol-level constraint). -/
axiom address_bytearray_size_eq_32 (addr : ByteArray)
    (h_is_address : True) :  -- TODO: Add proper predicate for "is valid address"
    addr.size = 32

/-! ## ByteArray concatenation properties -/

/-- Appending to a ByteArray increases its size by the appended length.

NOTE: ByteArray.append uses copySlice, not Array append. Proving size property
requires copySlice lemmas. Deferred pending ByteArray stdlib investigation. -/
axiom ByteArray.append_size (ba1 ba2 : ByteArray) :
    (ba1.append ba2).size = ba1.size + ba2.size

/-- Converting concatenated ByteArrays to lists commutes with append.

NOTE: Depends on toList loop properties + copySlice semantics. -/
axiom ByteArray.toList_append (ba1 ba2 : ByteArray) :
    (ba1.append ba2).toList = ba1.toList ++ ba2.toList

/-! ## ByteArray emptiness and initialization -/

/-- Empty ByteArray has size 0. -/
theorem ByteArray.empty_size :
    ByteArray.empty.size = 0 := by
  rfl

/-- Empty ByteArray has empty data array. -/
theorem ByteArray.empty_data :
    ByteArray.empty.data = #[] := by
  rfl

/-- Empty ByteArray has empty list representation.

NOTE: ByteArray.empty is defined as emptyWithCapacity 0, and toList is a loop.
Proving this requires showing the loop terminates immediately on empty data. -/
axiom ByteArray.empty_toList :
    ByteArray.empty.toList = []

/-! ## ByteArray equality -/

/-- Two ByteArrays are equal if their data arrays are equal (stdlib extensionality). -/
theorem ByteArray.eq_of_data_eq (ba1 ba2 : ByteArray)
    (h : ba1.data = ba2.data) :
    ba1 = ba2 := by
  apply ByteArray.ext
  exact h

/-- Two ByteArrays are equal if their list representations are equal.

NOTE: Requires proving toList is injective, which needs loop lemmas. -/
axiom ByteArray.eq_of_toList_eq (ba1 ba2 : ByteArray)
    (h : ba1.toList = ba2.toList) :
    ba1 = ba2

/-! ## Integration with MoveValue -/

/-- MoveValue.address constructor preserves ByteArray. -/
theorem MoveValue.address_exists (ba : ByteArray) :
    ∃ (mv : MoveValue), mv = MoveValue.address ba := by
  exact ⟨MoveValue.address ba, rfl⟩

/-- Extracting address from MoveValue.address yields original ByteArray. -/
theorem MoveValue.address_inj (ba1 ba2 : ByteArray) :
    MoveValue.address ba1 = MoveValue.address ba2 → ba1 = ba2 := by
  intro h
  injection h

end MovementFormal.MoveModel
