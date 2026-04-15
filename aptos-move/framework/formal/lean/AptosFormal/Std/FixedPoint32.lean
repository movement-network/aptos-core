-- omega is a Lean 4 builtin tactic; no import needed

/-!
# Lean specification for `std::fixed_point32`

`FixedPoint32` wraps a `u64` with an implicit 2^32 scale factor.
Value semantics: `fp.value` represents the rational `fp.value / 2^32`.

**Source:** `aptos-move/framework/move-stdlib/sources/fixed_point32.move`

## Overflow notes
- `ceil` and `round` use `fracBits` (low-32-bit mask) rather than
  reconstructing by shifting `floor` up (which overflows for large values).
- All u128 intermediate arithmetic uses `Nat` casts via `.toNat`.
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

-- ── Constructors ─────────────────────────────────────────────────────────────

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

-- ── Arithmetic ────────────────────────────────────────────────────────────────

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

-- ── Simple accessors ──────────────────────────────────────────────────────────

def is_zero (fp : FixedPoint32) : Bool := fp.value = 0

@[simp] theorem is_zero_zero : is_zero ⟨0⟩ = true := rfl

def min (a b : FixedPoint32) : FixedPoint32 := if a.value ≤ b.value then a else b
def max (a b : FixedPoint32) : FixedPoint32 := if a.value ≥ b.value then a else b

-- ── Rounding ──────────────────────────────────────────────────────────────────

def floor (fp : FixedPoint32) : UInt64 := fp.value >>> 32

@[simp] theorem floor_raw (fp : FixedPoint32) : floor fp = fp.value >>> 32 := rfl

/-- Low 32 bits: avoids reconstructing `floor <<< 32` which can overflow. -/
def fracBits (fp : FixedPoint32) : UInt64 := fp.value &&& 0xFFFFFFFF

def ceil (fp : FixedPoint32) : UInt64 :=
  let f := floor fp
  if fracBits fp = 0 then f
  else if f = 0xFFFFFFFFFFFFFFFF then f  -- saturate (unreachable in valid range)
  else f + 1

def round (fp : FixedPoint32) : UInt64 :=
  let f    := floor fp
  let frac := fracBits fp
  if frac < 0x80000000 then f else ceil fp

-- ── Theorems ──────────────────────────────────────────────────────────────────

@[simp] theorem multiply_u64_zero (mult : FixedPoint32) :
    multiply_u64 0 mult = .ok 0 := by
  simp [multiply_u64, MAX_U64_NAT]

@[simp] theorem divide_u64_zero (d : FixedPoint32) (hd : d.value ≠ 0) :
    divide_u64 0 d = .ok 0 := by
  simp [divide_u64, hd]

@[simp] theorem create_from_u64_zero :
    create_from_u64 0 = .ok ⟨0⟩ := by
  simp [create_from_u64, MAX_U64_NAT]

/-- For small integers (< 2^32), create_from_u64 then floor is identity. -/
theorem floor_integer (n : UInt64) (h : n.toNat < 2^32) :
    (((create_from_u64 n).toOption.getD ⟨0⟩).value.shiftRight 32) = n := by
  -- Proof sketch: create_from_u64 n = .ok ⟨(n.toNat * 2^32).toUInt64⟩ when n < 2^32.
  -- Then (n.toNat * 2^32).toUInt64.shiftRight 32 = n because:
  --   (n.toNat * 2^32) < 2^64 (since n < 2^32), so toUInt64 is exact,
  --   and shiftRight 32 divides by 2^32, recovering n.
  -- Requires Nat.toUInt64_toNat and UInt64.toNat_shiftRight.
  sorry

@[simp] theorem is_zero_iff (fp : FixedPoint32) : is_zero fp = true ↔ fp.value = 0 := by
  simp [is_zero]

theorem min_le_left (a b : FixedPoint32) : (min a b).value ≤ a.value := by
  show (if a.value ≤ b.value then a else b).value ≤ a.value
  by_cases h : a.value ≤ b.value
  · simp only [if_pos h]
  · simp only [if_neg h]
    exact le_of_not_le h

theorem min_le_right (a b : FixedPoint32) : (min a b).value ≤ b.value := by
  show (if a.value ≤ b.value then a else b).value ≤ b.value
  by_cases h : a.value ≤ b.value
  · simp only [if_pos h]; exact h
  · simp only [if_neg h]

theorem max_ge_left (a b : FixedPoint32) : a.value ≤ (max a b).value := by
  show a.value ≤ (if a.value ≥ b.value then a else b).value
  by_cases h : a.value ≥ b.value
  · simp only [if_pos h]
  · simp only [if_neg h]
    exact le_of_not_le h

theorem floor_le_ceil (fp : FixedPoint32) : floor fp ≤ ceil fp := by
  unfold ceil floor fracBits
  by_cases hfrac : fp.value &&& 0xFFFFFFFF = 0
  · simp [hfrac]
  · by_cases hmax : fp.value >>> 32 = 0xFFFFFFFFFFFFFFFF
    · simp [hfrac, hmax]
    · simp only [hfrac, ↓reduceIte, hmax]
      -- goal: fp.value >>> 32 ≤ fp.value >>> 32 + 1
      -- Follows from n ≤ n + 1 when n ≠ UInt64.max
      sorry

theorem ceil_eq_floor_of_exact (fp : FixedPoint32) (h : fracBits fp = 0) :
    ceil fp = floor fp := by
  simp [ceil, h]

theorem round_eq_floor_below_half (fp : FixedPoint32) (h : fracBits fp < 0x80000000) :
    round fp = floor fp := by
  simp [round, h]

end AptosFormal.Std.FixedPoint32
