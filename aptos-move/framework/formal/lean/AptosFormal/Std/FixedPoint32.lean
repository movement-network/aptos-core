import Mathlib.Tactic.Omega

/-!
# Lean specification for `std::fixed_point32`

`FixedPoint32` wraps a `u64` with an implicit 2^32 scale factor.
Value semantics: `fp.value` represents the rational `fp.value / 2^32`.

**Source:** `aptos-move/framework/move-stdlib/sources/fixed_point32.move`

## Overflow notes
- `ceil` and `round` must compare the raw `UInt64` value rather than
  shifting `floor` back up (which can overflow for large values).
  The fractional bits are simply the low-32 bits of `fp.value`.
- All u128 intermediate arithmetic uses `Nat` casts via `.toNat` to stay
  within Lean's natural-number tower, converting back with `UInt64.ofNat?`.
-/

namespace AptosFormal.Std.FixedPoint32

-- ── Error codes (category × 2^16 + reason, matching std::error) ─────────────
def EDENOMINATOR        : UInt64 := 0x10001
def EDIVISION           : UInt64 := 0x20002
def EMULTIPLICATION     : UInt64 := 0x20003
def EDIVISION_BY_ZERO   : UInt64 := 0x10004
def ERATIO_OUT_OF_RANGE : UInt64 := 0x20005

-- MAX_U64 as UInt128 for overflow checks
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

/-- `create_from_rational(num, den)`:
    computes `num / den` as a FixedPoint32 (i.e. result = (num * 2^32) / den,
    stored as the u64 `result`). Uses Nat to avoid u128 overflow. -/
def create_from_rational (num den : UInt64) : Except UInt64 FixedPoint32 :=
  if den = 0 then .error EDENOMINATOR
  else
    -- Scale: (num * 2^64) / (den * 2^32) = (num * 2^32) / den
    let scaled := num.toNat * 2^32
    let q      := scaled / den.toNat
    -- Reject if quotient is 0 but numerator was nonzero (underflow)
    if q = 0 && num ≠ 0 then .error ERATIO_OUT_OF_RANGE
    -- Reject if quotient overflows u64
    else if q > MAX_U64_NAT then .error ERATIO_OUT_OF_RANGE
    else .ok ⟨q.toUInt64⟩

/-- `create_from_u64(val)`: convert integer to FixedPoint32 (multiply by 2^32). -/
def create_from_u64 (val : UInt64) : Except UInt64 FixedPoint32 :=
  let scaled := val.toNat * 2^32
  if scaled > MAX_U64_NAT then .error ERATIO_OUT_OF_RANGE
  else .ok ⟨scaled.toUInt64⟩

-- ── Arithmetic ───────────────────────────────────────────────────────────────

/-- `multiply_u64(val, mult)`: val × mult (result is a plain u64). -/
def multiply_u64 (val : UInt64) (mult : FixedPoint32) : Except UInt64 UInt64 :=
  let prod   := val.toNat * mult.value.toNat
  let result := prod / 2^32       -- right-shift by 32 to remove the implicit scale
  if result > MAX_U64_NAT then .error EMULTIPLICATION
  else .ok result.toUInt64

/-- `divide_u64(val, divisor)`: val ÷ divisor (both at FixedPoint32 scale). -/
def divide_u64 (val : UInt64) (divisor : FixedPoint32) : Except UInt64 UInt64 :=
  if divisor.value = 0 then .error EDIVISION_BY_ZERO
  else
    let scaled := val.toNat * 2^32
    let q      := scaled / divisor.value.toNat
    if q > MAX_U64_NAT then .error EDIVISION
    else .ok q.toUInt64

-- ── Simple accessors ─────────────────────────────────────────────────────────

def is_zero (fp : FixedPoint32) : Bool := fp.value = 0

@[simp] theorem is_zero_zero : is_zero ⟨0⟩ = true := rfl

def min (a b : FixedPoint32) : FixedPoint32 := if a.value ≤ b.value then a else b
def max (a b : FixedPoint32) : FixedPoint32 := if a.value ≥ b.value then a else b

-- ── Rounding ─────────────────────────────────────────────────────────────────

/-- Integer part: high 32 bits of `fp.value`. -/
def floor (fp : FixedPoint32) : UInt64 := fp.value >>> 32

@[simp] theorem floor_raw (fp : FixedPoint32) :
    floor fp = fp.value >>> 32 := rfl

/-- The fractional bits are the low 32 bits of `fp.value`.
    No overflow: we never reconstruct by shifting `floor` back up. -/
def fracBits (fp : FixedPoint32) : UInt64 :=
  fp.value &&& 0xFFFFFFFF  -- mask low 32 bits

/-- `ceil`: smallest integer ≥ fp. -/
def ceil (fp : FixedPoint32) : UInt64 :=
  let f := floor fp
  -- If there are any fractional bits, add 1
  if fracBits fp = 0 then f
  else
    -- Guard against overflow at the maximum representable value
    if f = 0xFFFFFFFFFFFFFFFF then f   -- saturate (unreachable in valid range)
    else f + 1

/-- `round`: nearest integer, rounding half up. -/
def round (fp : FixedPoint32) : UInt64 :=
  let f    := floor fp
  let frac := fracBits fp
  -- 2^31 is the midpoint of the fractional range [0, 2^32)
  if frac < 0x80000000 then f else ceil fp

-- ── Basic theorems ───────────────────────────────────────────────────────────

@[simp] theorem multiply_u64_zero (mult : FixedPoint32) :
    multiply_u64 0 mult = .ok 0 := by
  simp [multiply_u64, MAX_U64_NAT]

@[simp] theorem divide_u64_zero (d : FixedPoint32) (hd : d.value ≠ 0) :
    divide_u64 0 d = .ok 0 := by
  simp [divide_u64, hd]

@[simp] theorem create_from_u64_zero :
    create_from_u64 0 = .ok ⟨0⟩ := by
  simp [create_from_u64, MAX_U64_NAT]

@[simp] theorem floor_integer (n : UInt64) (h : n.toNat < 2^32) :
    floor (create_from_u64 n |>.toOption.getD ⟨0⟩) = n := by
  simp [create_from_u64, MAX_U64_NAT, floor]
  sorry  -- requires UInt64 bitshift arithmetic; flagged for later

@[simp] theorem is_zero_iff (fp : FixedPoint32) : is_zero fp = true ↔ fp.value = 0 := by
  simp [is_zero]

theorem min_le_left (a b : FixedPoint32) : (min a b).value ≤ a.value := by
  simp [min]; split_ifs with h <;> [exact h; exact Nat.le_refl _]

theorem min_le_right (a b : FixedPoint32) : (min a b).value ≤ b.value := by
  simp [min]; split_ifs with h
  · exact h
  · exact Nat.le_of_not_le h

theorem max_ge_left (a b : FixedPoint32) : a.value ≤ (max a b).value := by
  simp [max]; split_ifs with h <;> [exact h; exact Nat.le_refl _]

theorem floor_le_ceil (fp : FixedPoint32) : floor fp ≤ ceil fp := by
  simp [floor, ceil, fracBits]
  split_ifs <;> omega

theorem ceil_eq_floor_of_exact (fp : FixedPoint32) (h : fracBits fp = 0) :
    ceil fp = floor fp := by
  simp [ceil, h]

theorem round_eq_floor_below_half (fp : FixedPoint32) (h : fracBits fp < 0x80000000) :
    round fp = floor fp := by
  simp [round, h]

end AptosFormal.Std.FixedPoint32
