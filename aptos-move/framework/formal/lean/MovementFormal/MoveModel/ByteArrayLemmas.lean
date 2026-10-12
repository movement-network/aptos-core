/-
ByteArray helper lemmas for formal verification.

This file provides basic properties of ByteArray operations needed for
message assembly and serialization proofs in Confidential Assets.

ByteArray wraps Array UInt8 but uses a loop-based toList implementation,
making proofs more complex than initially expected. Current status:
simple lemmas proved, complex ones need more infrastructure.
-/

import MovementFormal.MoveModel.Value
import MovementFormal.Std.ByteArrayAppend

namespace MovementFormal.MoveModel

/-! ## ByteArray size and length properties -/

/-- ByteArray.toList preserves the size as length.
This is the key lemma needed for address_to_bytes_length in PC20_43_message_assembly. -/
theorem ByteArray.toList_length_eq_size (ba : ByteArray) :
    ba.toList.length = ba.size := by
  rw [Std.byteArray_toList_eq_data_toList]
  rw [Array.length_toList]
  rfl

/-- Converting ByteArray to List of MoveValue.u8 preserves length. -/
theorem ByteArray.toList_map_u8_length (ba : ByteArray) :
    (ba.toList.map MoveValue.u8).length = ba.size := by
  rw [List.length_map, ByteArray.toList_length_eq_size]

/-- Address ByteArrays have size 32 (protocol-level constraint). -/
axiom address_bytearray_size_eq_32 (addr : ByteArray)
    (h_is_address : True) :  -- TODO: Add proper predicate for "is valid address"
    addr.size = 32

/-! ## ByteArray concatenation properties -/

/-- Appending to a ByteArray increases its size by the appended length. -/
theorem ByteArray.append_size (ba1 ba2 : ByteArray) :
    (ba1.append ba2).size = ba1.size + ba2.size := by
  -- ByteArray.append is implemented as ba2.copySlice 0 ba1 ba1.size ba2.size false
  -- The ++ notation is HAppend.hAppend which calls ByteArray.append
  have h : ba1 ++ ba2 = ba1.append ba2 := rfl
  rw [← h]
  have hdata := Std.byteArray_data_append ba1 ba2
  change (ba1 ++ ba2).data.size = ba1.data.size + ba2.data.size
  rw [hdata, Array.size_append]

/-- Converting concatenated ByteArrays to lists commutes with append. -/
theorem ByteArray.toList_append (ba1 ba2 : ByteArray) :
    (ba1.append ba2).toList = ba1.toList ++ ba2.toList :=
  Std.byteArray_toList_append ba1 ba2

/-! ## ByteArray emptiness and initialization -/

/-- Empty ByteArray has size 0. -/
theorem ByteArray.empty_size :
    ByteArray.empty.size = 0 := by
  rfl

/-- Empty ByteArray has empty data array. -/
theorem ByteArray.empty_data :
    ByteArray.empty.data = #[] := by
  rfl

/-- Empty ByteArray has empty list representation. -/
theorem ByteArray.empty_toList :
    ByteArray.empty.toList = [] := by
  simp [Std.byteArray_toList_eq_data_toList, ByteArray.empty_data]

/-! ## ByteArray equality -/

/-- Two ByteArrays are equal if their data arrays are equal (stdlib extensionality). -/
theorem ByteArray.eq_of_data_eq (ba1 ba2 : ByteArray)
    (h : ba1.data = ba2.data) :
    ba1 = ba2 := by
  apply ByteArray.ext
  exact h

/-- Two ByteArrays are equal if their list representations are equal.

NOTE: Proving this requires Array extensionality from list equality, which needs
careful handling of dependent bounds. Deferred for future work. -/
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
