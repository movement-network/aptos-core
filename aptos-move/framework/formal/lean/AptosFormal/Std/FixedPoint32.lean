-- omega is a Lean 4 builtin tactic; no import needed

/-!
# Lean specification for `std::fixed_point32`
-/

namespace AptosFormal.Std.FixedPoint32

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

theorem floor_integer (n : UInt64) (h : n.toNat < 2^32) :
    (((create_from_u64 n).toOption.getD ⟨0⟩).value.shiftRight 32) = n := by
  sorry

@[simp] theorem is_zero_iff (fp : FixedPoint32) : is_zero fp = true ↔ fp.value = 0 := by
  simp [is_zero]

-- For min/max ordering, UInt64 is a linear order; use UInt64.le_antisymm and toNat bridge
private theorem u64_le_of_not_le {a b : UInt64} (h : ¬ a ≤ b) : b ≤ a := by
  -- ¬ (a ≤ b) means b < a (total order), so b ≤ a
  -- UInt64 LE reduces to Fin LE which reduces to Nat LE
  have ha : b.toNat ≤ a.toNat := by
    have hlt : a.toNat > b.toNat := by
      by_contra hc
      apply h
      rw [UInt64.le_iff_toNat_le]
      omega
    omega
  rwa [UInt64.le_iff_toNat_le]

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
  sorry

theorem ceil_eq_floor_of_exact (fp : FixedPoint32) (h : fracBits fp = 0) :
    ceil fp = floor fp := by
  simp [ceil, h]

theorem round_eq_floor_below_half (fp : FixedPoint32) (h : fracBits fp < 0x80000000) :
    round fp = floor fp := by
  simp [round, h]

end AptosFormal.Std.FixedPoint32
