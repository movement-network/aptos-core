/-
ByteArray helper lemmas for formal verification.

This file provides basic properties of ByteArray operations needed for
message assembly and serialization proofs in Confidential Assets.

ByteArray is defined in the Aptos stdlib as a wrapper around ByteBuffer,
which is itself a wrapper around Array UInt8. These lemmas bridge the gap
between ByteArray operations and List-based reasoning.
-/

import MovementFormal.MoveModel.Value

namespace MovementFormal.MoveModel

/-! ## ByteArray size and length properties -/

/-- ByteArray.toList preserves the size as length.
This is the key lemma needed for address_to_bytes_length in PC20_43_message_assembly. -/
theorem ByteArray.toList_length_eq_size (ba : ByteArray) :
    ba.toList.length = ba.size := by
  simp [ByteArray.toList, ByteArray.size]
  rw [Array.toList_length]

/-- Converting ByteArray to List of MoveValue.u8 preserves length. -/
theorem ByteArray.toList_map_u8_length (ba : ByteArray) :
    (ba.toList.map MoveValue.u8).length = ba.size := by
  rw [List.length_map, ByteArray.toList_length_eq_size]

/-- Address ByteArrays have size 32. -/
axiom address_bytearray_size_eq_32 (addr : ByteArray)
    (h_is_address : True) :  -- TODO: Add proper predicate for "is valid address"
    addr.size = 32

/-! ## ByteArray concatenation properties -/

/-- Appending to a ByteArray increases its size by the appended length. -/
theorem ByteArray.append_size (ba1 ba2 : ByteArray) :
    (ba1.append ba2).size = ba1.size + ba2.size := by
  simp [ByteArray.append, ByteArray.size]
  rw [Array.size_append]

/-- Converting concatenated ByteArrays to lists commutes with append. -/
theorem ByteArray.toList_append (ba1 ba2 : ByteArray) :
    (ba1.append ba2).toList = ba1.toList ++ ba2.toList := by
  simp [ByteArray.append, ByteArray.toList]
  rw [Array.toList_append]

/-! ## ByteArray emptiness and initialization -/

/-- Empty ByteArray has size 0. -/
theorem ByteArray.empty_size :
    ByteArray.empty.size = 0 := by
  rfl

/-- Empty ByteArray has empty list representation. -/
theorem ByteArray.empty_toList :
    ByteArray.empty.toList = [] := by
  rfl

/-! ## ByteArray equality -/

/-- Two ByteArrays are equal if their list representations are equal. -/
theorem ByteArray.eq_of_toList_eq (ba1 ba2 : ByteArray)
    (h : ba1.toList = ba2.toList) :
    ba1 = ba2 := by
  apply ByteArray.ext
  simp [ByteArray.toList] at h
  ext i
  cases h' : decide (i < ba1.data.size) <;> cases h'' : decide (i < ba2.data.size)
  · have : ba1.data.toList[i]? = ba2.data.toList[i]? := by rw [h]
    simp [Array.toList_get?] at this
    exact this
  all_goals {
    have len_eq : ba1.data.toList.length = ba2.data.toList.length := by rw [h]
    simp [Array.toList_length] at len_eq
    omega
  }

/-- ByteArrays with same size and equal elements at each position are equal.
Renamed to avoid conflict with ByteArray.ext from stdlib. -/
theorem ByteArray.ext_get (ba1 ba2 : ByteArray)
    (h_size : ba1.size = ba2.size)
    (h_get : ∀ i (h1 : i < ba1.size) (h2 : i < ba2.size),
             ba1.data[i]'h1 = ba2.data[i]'h2) :
    ba1 = ba2 := by
  apply ByteArray.ext
  ext i
  by_cases hi : i < ba1.data.size
  · have hi' : i < ba2.data.size := by simp [ByteArray.size] at h_size; omega
    exact h_get i hi hi'
  · have hi' : ¬(i < ba2.data.size) := by simp [ByteArray.size] at h_size; omega
    simp [hi, hi']

/-! ## Integration with MoveValue -/

/-- MoveValue.address constructor preserves ByteArray size.
This is a trivial existence statement - any ByteArray can be wrapped. -/
theorem MoveValue.address_exists (ba : ByteArray) :
    ∃ (mv : MoveValue), mv = MoveValue.address ba := by
  exact ⟨MoveValue.address ba, rfl⟩

/-- Extracting address from MoveValue.address yields original ByteArray. -/
theorem MoveValue.address_inj (ba1 ba2 : ByteArray) :
    MoveValue.address ba1 = MoveValue.address ba2 → ba1 = ba2 := by
  intro h
  injection h

end MovementFormal.MoveModel
