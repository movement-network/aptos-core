/-
Copyright (c) Move Industries.

Pure `Init` lemmas about `ByteArray.append` at the `Array UInt8` level.

**Why this file exists.** `ByteArray.toList` is implemented via an `@[irreducible]`
auxiliary (`ByteArray.toList.loop` in Lean 4.24).  This module locally marks that
loop `semireducible` **only while checking these proofs**, then shows
`byteArray_toList_eq_data_toList` and (with `byteArray_data_append`) full
`toList`/`append`/`mk_singleton` facts with **no** `sorry` and **no** axioms beyond
`Init`.

The underlying byte storage also satisfies **`data`** characterization
`(a ++ b).data = a.data ++ b.data`, provable from `ByteArray.copySlice` /
`ByteArray.append` in `Init`.
-/

import Init

attribute [local semireducible] ByteArray.toList.loop

namespace MovementFormal.Std

theorem byteArray_data_append (a b : ByteArray) : (a ++ b).data = a.data ++ b.data := by
  -- `a ++ b` is `ByteArray.append`, which is `b.copySlice 0 a a.size b.size false`
  change (ByteArray.append a b).data = a.data ++ b.data
  dsimp [ByteArray.append, ByteArray.copySlice]
  have ha : a.size = a.data.size := rfl
  have hb : b.size = b.data.size := rfl
  rw [ha, hb, Nat.zero_add]
  rw [@Array.extract_size UInt8 a.data, @Array.extract_size UInt8 b.data]
  have hm : min b.data.size b.data.size = b.data.size := Nat.min_eq_left (Nat.le_refl _)
  rw [hm]
  have htail :
      a.data.extract (a.data.size + b.data.size) a.data.size = #[] := by
    rw [Array.extract_eq_empty_iff]
    omega
  rw [htail, Array.append_empty]

/-! ### `ByteArray.toList` vs `Array.toList` on `data` -/

private theorem byteArray_toList_loop_eq (bs : ByteArray) (i : Nat) (r : List UInt8)
    (hi : i ≤ bs.size) :
    ByteArray.toList.loop bs i r = List.reverse r ++ bs.data.toList.drop i := by
  have hsz : bs.size = bs.data.size := rfl
  have hi_data : i ≤ bs.data.size := by simpa [hsz] using hi
  induction h : (bs.data.size - i) generalizing i r hi with
  | zero =>
    have ie : i = bs.data.size := by
      have : bs.data.size ≤ i := Nat.sub_eq_zero_iff_le.mp h
      exact Nat.le_antisymm hi_data this
    subst ie
    have hnot : ¬ bs.data.size < bs.size := by
      rw [hsz]
      exact Nat.lt_irrefl _
    rw [ByteArray.toList.loop, if_neg hnot]
    have hz : List.drop bs.data.size bs.data.toList = [] := by
      simp [← Array.length_toList, List.drop_length]
    rw [hz, List.append_nil]
  | succ n ih =>
    have hi_lt : i < bs.data.size := by
      have pos : 0 < bs.data.size - i := h.symm ▸ Nat.zero_lt_succ n
      exact Nat.lt_of_sub_pos pos
    have hi' : i + 1 ≤ bs.data.size := Nat.succ_le_of_lt hi_lt
    have hi'_bs : i + 1 ≤ bs.size := by simpa [hsz] using hi'
    have hif : i < bs.size := by simpa [hsz] using hi_lt
    have hlen : i < bs.data.toList.length := by simpa [Array.length_toList] using hi_lt
    have hdrop : bs.data.toList.drop i = bs.data.toList[i] :: bs.data.toList.drop (i + 1) :=
      List.drop_eq_getElem_cons hlen
    have hget : bs.get! i = bs.data[i] := by
      cases bs with
      | mk data =>
        simp only [ByteArray.get!, hi_lt, getElem!_pos]
    rw [ByteArray.toList.loop, if_pos hif, hget]
    have hrec : bs.data.size - (i + 1) = n := by omega
    rw [ih (i + 1) (bs.data[i] :: r) hi'_bs hi' hrec]
    simp only [List.reverse_cons, List.append_assoc, hdrop, List.singleton_append,
      Array.getElem_toList hi_lt]

/-- `ByteArray.toList` agrees with `Array.toList` on the packed `data` array. -/
theorem byteArray_toList_eq_data_toList (b : ByteArray) : b.toList = b.data.toList := by
  unfold ByteArray.toList
  rw [byteArray_toList_loop_eq b 0 [] (Nat.zero_le _)]
  simp only [List.reverse_nil, List.nil_append, List.drop_zero]

theorem byteArray_toList_append (a b : ByteArray) :
    (a ++ b).toList = a.toList ++ b.toList := by
  rw [byteArray_toList_eq_data_toList, byteArray_toList_eq_data_toList a,
    byteArray_toList_eq_data_toList b, byteArray_data_append, Array.toList_append]

theorem byteArray_toList_mk_singleton (x : UInt8) : (ByteArray.mk #[x]).toList = [x] := by
  simp [byteArray_toList_eq_data_toList]

end MovementFormal.Std
