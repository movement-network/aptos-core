import MovementFormal.Std.Error
import Init.Data.UInt.Lemmas
import Init.Data.Nat.Bitwise.Lemmas
import Mathlib.Data.Nat.Bitwise

/-!
# Canonical error-code arithmetic

Reason **injectivity** for `std::error` when reasons occupy the low **16 bits** (per Move docs).

**Source:** `aptos-move/framework/move-stdlib/sources/error.move` (same encoding as `MovementFormal.Std.Error`).
-/

namespace MovementFormal.Std.Error

open Nat

private theorem testBit_of_lt_pow16_of_mod {L : Nat} (hL : L % (2 ^ 16) = 0) {i : Nat}
    (hi : i < 16) : L.testBit i = false := by
  have := Nat.testBit_mod_two_pow L 16 i
  rw [hL, Nat.zero_testBit] at this
  simpa [decide_eq_true hi] using this.symm

/-- Low 16 bits of `L ||| r` equal `r` when `L` is a multiple of `2^16` and `r < 2^16`. -/
private theorem nat_lor_mod_pow16_eq {L r : Nat} (hL : L % (2 ^ 16) = 0) (hr : r < 2 ^ 16) :
    (L ||| r) % (2 ^ 16) = r := by
  refine Nat.eq_of_testBit_eq fun i => ?_
  by_cases hi16 : i < 16
  · show Nat.testBit ((L ||| r) % (2 ^ 16)) i = Nat.testBit r i
    rw [Nat.testBit_mod_two_pow, decide_eq_true hi16, Bool.true_and, Nat.testBit_lor,
      testBit_of_lt_pow16_of_mod hL hi16, Bool.false_or]
  · have hi16' : 16 ≤ i := Nat.le_of_not_gt hi16
    have hpow : 2 ^ 16 ≤ 2 ^ i := Nat.pow_le_pow_right (by decide : 0 < 2) hi16'
    have hrbit : r.testBit i = false := Nat.testBit_lt_two_pow (Nat.lt_of_lt_of_le hr hpow)
    show Nat.testBit ((L ||| r) % (2 ^ 16)) i = Nat.testBit r i
    rw [Nat.testBit_mod_two_pow]
    have hd : decide (i < 16) = false := decide_eq_false hi16
    simp [hd, Bool.false_and, hrbit]

/-- Same-category canonical codes determine the reason when reasons and category are 16-bit. -/
theorem canonical_inj_reason {cat r1 r2 : UInt64}
    (hr1 : r1.toNat < 2 ^ 16) (hr2 : r2.toNat < 2 ^ 16)
    (hcat : cat.toNat < 2 ^ 16)
    (h : canonical cat r1 = canonical cat r2) :
    r1 = r2 := by
  apply UInt64.toNat.inj
  have hNat := congrArg UInt64.toNat h
  simp only [canonical, UInt64.toNat_or] at hNat
  have hmul : cat.toNat * 2 ^ 16 < UInt64.size := by
    have hc : cat.toNat ≤ 2 ^ 16 - 1 := Nat.le_sub_one_of_lt hcat
    have hprod : cat.toNat * 2 ^ 16 ≤ (2 ^ 16 - 1) * 2 ^ 16 := Nat.mul_le_mul_right _ hc
    have hbound : (2 ^ 16 - 1) * 2 ^ 16 < UInt64.size := by native_decide
    exact Nat.lt_of_le_of_lt hprod hbound
  have hshift : (cat <<< (16 : UInt64)).toNat = cat.toNat * 2 ^ 16 := by
    rw [UInt64.toNat_shiftLeft]
    simp [UInt64.toNat_ofNat]
    rw [Nat.shiftLeft_eq]
    rw [Nat.mod_eq_of_lt hmul]
    rfl
  have hL : (cat <<< (16 : UInt64)).toNat % (2 ^ 16) = 0 := by
    rw [hshift]
    exact Nat.mul_mod_left cat.toNat (2 ^ 16)
  have hmod := congrArg (fun n : Nat => n % (2 ^ 16)) hNat
  simp_rw [nat_lor_mod_pow16_eq hL hr1, nat_lor_mod_pow16_eq hL hr2] at hmod
  exact hmod

end MovementFormal.Std.Error
