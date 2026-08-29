-- omega is a Lean 4 builtin tactic; no import needed

/-!
# Lean specification for `std::fixed_point32`

**Source:** `aptos-move/framework/move-stdlib/sources/fixed_point32.move`.
-/

namespace MovementFormal.Std.FixedPoint32

def EDENOMINATOR        : UInt64 := 0x10001
def EDIVISION           : UInt64 := 0x20002
def EMULTIPLICATION     : UInt64 := 0x20003
def EDIVISION_BY_ZERO   : UInt64 := 0x10004
def ERATIO_OUT_OF_RANGE : UInt64 := 0x20005

def MAX_U64_NAT : Nat := 2^64 - 1

structure FixedPoint32 where
  value : UInt64
deriving Repr, DecidableEq

def create_from_raw_value (v : UInt64) : FixedPoint32 := ⟨v⟩

@[simp] theorem create_from_raw_value_val (v : UInt64) :
    (create_from_raw_value v).value = v := rfl

def get_raw_value (fp : FixedPoint32) : UInt64 := fp.value

@[simp] theorem get_raw_create (v : UInt64) :
    get_raw_value (create_from_raw_value v) = v := rfl

def create_from_rational (num den : UInt64) : Except UInt64 FixedPoint32 :=
  if den = 0 then .error EDENOMINATOR
  else
    let scaled := num.toNat * 2^32
    let q      := scaled / den.toNat
    if q = 0 && num ≠ 0 then .error ERATIO_OUT_OF_RANGE
    else if q > MAX_U64_NAT then .error ERATIO_OUT_OF_RANGE
    else .ok ⟨q.toUInt64⟩

def create_from_u64 (val : UInt64) : Except UInt64 FixedPoint32 :=
  let scaled := val.toNat * 2^32
  if scaled > MAX_U64_NAT then .error ERATIO_OUT_OF_RANGE
  else .ok ⟨scaled.toUInt64⟩

def multiply_u64 (val : UInt64) (mult : FixedPoint32) : Except UInt64 UInt64 :=
  let prod   := val.toNat * mult.value.toNat
  let result := prod / 2^32
  if result > MAX_U64_NAT then .error EMULTIPLICATION
  else .ok result.toUInt64

def divide_u64 (val : UInt64) (divisor : FixedPoint32) : Except UInt64 UInt64 :=
  if divisor.value = 0 then .error EDIVISION_BY_ZERO
  else
    let scaled := val.toNat * 2^32
    let q      := scaled / divisor.value.toNat
    if q > MAX_U64_NAT then .error EDIVISION
    else .ok q.toUInt64

def is_zero (fp : FixedPoint32) : Bool := fp.value = 0

@[simp] theorem is_zero_zero : is_zero ⟨0⟩ = true := rfl

def min (a b : FixedPoint32) : FixedPoint32 := if a.value ≤ b.value then a else b
def max (a b : FixedPoint32) : FixedPoint32 := if a.value ≥ b.value then a else b

def floor (fp : FixedPoint32) : UInt64 := fp.value >>> 32

@[simp] theorem floor_raw (fp : FixedPoint32) : floor fp = fp.value >>> 32 := rfl

def fracBits (fp : FixedPoint32) : UInt64 := fp.value &&& 0xFFFFFFFF

def ceil (fp : FixedPoint32) : UInt64 :=
  let f := floor fp
  if fracBits fp = 0 then f
  else if f = 0xFFFFFFFFFFFFFFFF then f
  else f + 1

def round (fp : FixedPoint32) : UInt64 :=
  let f    := floor fp
  let frac := fracBits fp
  if frac < 0x80000000 then f else ceil fp

@[simp] theorem multiply_u64_zero (mult : FixedPoint32) :
    multiply_u64 0 mult = .ok 0 := by
  simp [multiply_u64, MAX_U64_NAT]

@[simp] theorem divide_u64_zero (d : FixedPoint32) (hd : d.value ≠ 0) :
    divide_u64 0 d = .ok 0 := by
  simp [divide_u64, hd]

@[simp] theorem create_from_u64_zero :
    create_from_u64 0 = .ok ⟨0⟩ := by
  simp [create_from_u64, MAX_U64_NAT]

@[simp] theorem is_zero_iff (fp : FixedPoint32) : is_zero fp = true ↔ fp.value = 0 := by
  simp [is_zero]

-- For min/max ordering, UInt64 is a linear order; use UInt64.le_antisymm and toNat bridge
private theorem u64_le_of_not_le {a b : UInt64} (h : ¬ a ≤ b) : b ≤ a := by
  -- ¬ (a ≤ b) → b < a (UInt64 total order) → b ≤ a
  -- Strategy: convert h to Nat, use omega, convert back
  rw [UInt64.le_iff_toNat_le] at h
  -- h : ¬ a.toNat ≤ b.toNat   (i.e. b.toNat < a.toNat)
  rw [UInt64.le_iff_toNat_le]
  -- goal : b.toNat ≤ a.toNat
  omega

theorem min_le_left (a b : FixedPoint32) : (min a b).value ≤ a.value := by
  show (if a.value ≤ b.value then a else b).value ≤ a.value
  by_cases h : a.value ≤ b.value
  · simp only [if_pos h]
    rw [UInt64.le_iff_toNat_le]; omega
  · simp only [if_neg h]
    exact u64_le_of_not_le h

theorem min_le_right (a b : FixedPoint32) : (min a b).value ≤ b.value := by
  show (if a.value ≤ b.value then a else b).value ≤ b.value
  by_cases h : a.value ≤ b.value
  · simp only [if_pos h]; exact h
  · simp only [if_neg h]
    rw [UInt64.le_iff_toNat_le]
    -- goal: b.value.toNat ≤ b.value.toNat
    omega

theorem max_ge_left (a b : FixedPoint32) : a.value ≤ (max a b).value := by
  show a.value ≤ (if a.value ≥ b.value then a else b).value
  by_cases h : a.value ≥ b.value
  · simp only [if_pos h]
    rw [UInt64.le_iff_toNat_le]; omega
  · simp only [if_neg h]
    exact u64_le_of_not_le (by rwa [ge_iff_le] at h)

theorem floor_le_ceil (fp : FixedPoint32) : floor fp ≤ ceil fp := by
  unfold ceil
  by_cases hf : fracBits fp = 0
  · rw [if_pos hf]; rw [UInt64.le_iff_toNat_le]; omega
  · rw [if_neg hf]
    by_cases hm : floor fp = 0xffffffffffffffff
    · rw [if_pos hm]; rw [UInt64.le_iff_toNat_le]; omega
    · rw [if_neg hm]
      have hmaxnat :
          (0xffffffffffffffff : UInt64).toNat = UInt64.size - 1 := by
        rw [UInt64.toNat_ofNat_of_lt (by decide : 18446744073709551615 < UInt64.size)]
        rfl
      have hne : (floor fp).toNat ≠ UInt64.size - 1 := by
        intro hnat
        apply hm
        apply UInt64.toNat.inj
        rw [hmaxnat, hnat]
      rw [UInt64.le_iff_toNat_le]
      have hlt1 : (floor fp).toNat + 1 < UInt64.size := by
        have hlt : (floor fp).toNat < UInt64.size := UInt64.toNat_lt_size _
        have hle : (floor fp).toNat + 1 ≤ UInt64.size - 1 := by
          unfold UInt64.size at hlt hne ⊢
          omega
        have hsz1 : UInt64.size - 1 < UInt64.size := by
          unfold UInt64.size
          decide
        exact Nat.lt_of_le_of_lt hle hsz1
      have hadd : ((floor fp) + 1).toNat = (floor fp).toNat + 1 := by
        rw [UInt64.toNat_add]
        simp only [UInt64.toNat_one]
        exact Nat.mod_eq_of_lt hlt1
      rw [hadd]
      exact Nat.le_succ _

theorem ceil_eq_floor_of_exact (fp : FixedPoint32) (h : fracBits fp = 0) :
    ceil fp = floor fp := by
  simp [ceil, h]

theorem round_eq_floor_below_half (fp : FixedPoint32) (h : fracBits fp < 0x80000000) :
    round fp = floor fp := by
  simp [round, h]

end MovementFormal.Std.FixedPoint32
