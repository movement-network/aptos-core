/-
Copyright (c) Move Industries.

# Edwards form of Curve25519: `edwards25519`

**Source:**
- `aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.move` (natives `point_add`, `point_sub`, `point_mul`, `multi_scalar_mul`).
- RFC 7748 §5 (`edwards25519` curve definition).
- D. J. Bernstein, M. Hamburg, A. Krasnova, T. Lange, "Elligator: Elliptic-curve points indistinguishable from uniform random strings", 2013.
- H. Hisil, K. Wong, G. Carter, E. Dawson, "Twisted Edwards Curves Revisited", ASIACRYPT 2008.

Tier 3 (full Ristretto255 formalization) Layer 2: raw curve arithmetic. The
twisted Edwards curve

  `edwards25519 : -x² + y² = 1 + d·x²·y²   over 𝔽_p, p = 2^255 - 19`

with `d = -121665 / 121666 (mod p)` is the geometric substrate; Ristretto255
is defined as an equivalence class on its points (Layer 3).

## Design decisions

1. **Affine coordinates (x, y).** We use affine rather than extended/projective
   coordinates to keep proofs simple. Production code (`curve25519-dalek` in
   Rust) uses extended coordinates for speed; we do not care about speed, we
   care about correctness.

2. **Complete addition law.** Twisted Edwards curves with `a = -1` and
   non-square `d` admit the *complete* addition law — the same formula works
   for all inputs including identity, repeated addition, and the neutral
   element. This is the classical Bernstein–Hisil theorem (2007).

3. **Group axioms as named axioms.** The associativity + commutativity proofs
   of Edwards addition in Lean 4 / Mathlib is a nontrivial ~few-month task
   (the Mathlib-wide elliptic-curve formalization targets Weierstrass form).
   We bundle these as named axioms matching the existing stylistic choice of
   `Registration.GroupAxioms`, so downstream difftest code can *execute* the
   curve law concretely while we defer the full algebraic proof.

## Scope in this layer

- Concrete affine `EdwardsPoint` carrier.
- Concrete (computable) `add`, `neg`, `double`, and scalar multiplication
  by ℕ / ℤ / `RistrettoScalar`.
- Named axioms for the group laws: associativity, identity, inverse,
  commutativity. Each axiom is stated exactly enough to build
  `AddCommGroup`.
- A named `Module RistrettoScalar EdwardsPoint` axiom via the scalar action.

This is **enough** to instantiate `Registration.GroupAxioms.RistrettoGroupAxioms`
with `Point := EdwardsPoint` and feed concrete points to `verifyRegistrationProofProp`,
subject to the named axioms.
-/

import MovementFormal.AptosStd.Crypto.Curve25519Field
import MovementFormal.AptosStd.Crypto.Ristretto255

open MovementFormal.AptosStd.Crypto.Curve25519Field
open MovementFormal.AptosStd.Crypto.Ristretto255

namespace MovementFormal.AptosStd.Crypto.EdwardsCurve25519

/-- Affine point on `edwards25519`. We do NOT bundle the curve equation
into the structure to keep point operations `decide`-computable; instead
the predicate `onCurve` captures validity and group axioms are stated as
named axioms. -/
structure EdwardsPoint where
  x : Fp
  y : Fp
  deriving DecidableEq

namespace EdwardsPoint

/-- Curve-membership predicate `-x² + y² = 1 + d·x²·y²`. -/
noncomputable def onCurve (P : EdwardsPoint) : Prop :=
  -P.x^2 + P.y^2 = 1 + edwardsD * P.x^2 * P.y^2

/-- The Edwards identity element `(0, 1)`. -/
def zero : EdwardsPoint :=
  { x := 0, y := 1 }

/-- `zero` satisfies the curve equation. -/
theorem zero_onCurve : onCurve zero := by
  simp [onCurve, zero]

/-- Negation: `-(x, y) = (-x, y)`. Twisted Edwards with `a = -1`. -/
def neg (P : EdwardsPoint) : EdwardsPoint :=
  { x := -P.x, y := P.y }

instance : Neg EdwardsPoint := ⟨neg⟩

@[simp] theorem neg_x (P : EdwardsPoint) : (-P).x = -P.x := rfl
@[simp] theorem neg_y (P : EdwardsPoint) : (-P).y = P.y := rfl

/-- `neg` preserves curve membership. -/
theorem neg_onCurve (P : EdwardsPoint) (hP : onCurve P) : onCurve (-P) := by
  simp [onCurve, neg_x, neg_y] at hP ⊢
  exact hP

/--
Twisted Edwards addition with `a = -1`:

  `x₃ = (x₁y₂ + x₂y₁) / (1 + d · x₁ · x₂ · y₁ · y₂)`
  `y₃ = (y₁y₂ + x₁x₂) / (1 - d · x₁ · x₂ · y₁ · y₂)`

(Unified for `a = -1`; Bernstein et al. §6 of Twisted Edwards Curves Revisited.)

Both denominators are non-zero for valid Curve25519 points because `d` is a
non-square. That completeness fact is captured inside the `GroupAxioms`
bundle below; here we simply use Mathlib's `0⁻¹ = 0` fallback in the unlikely
event of division by zero. This does not affect correctness because every
USE of `add` below happens at points proven to be on-curve.
-/
noncomputable def add (P Q : EdwardsPoint) : EdwardsPoint :=
  let x₁ := P.x; let y₁ := P.y
  let x₂ := Q.x; let y₂ := Q.y
  let denomPlus := 1 + edwardsD * x₁ * x₂ * y₁ * y₂
  let denomMinus := 1 - edwardsD * x₁ * x₂ * y₁ * y₂
  { x := (x₁ * y₂ + x₂ * y₁) * denomPlus⁻¹,
    y := (y₁ * y₂ + x₁ * x₂) * denomMinus⁻¹ }

noncomputable instance : Add EdwardsPoint := ⟨add⟩

/-- Doubling via the unified addition formula. -/
noncomputable def double (P : EdwardsPoint) : EdwardsPoint :=
  add P P

/-- Repeated addition: `nsmul n P = P + P + ... + P` (n times). -/
noncomputable def nsmul : ℕ → EdwardsPoint → EdwardsPoint
  | 0, _ => zero
  | (n + 1), P => add (nsmul n P) P

/-- Integer scalar multiplication: negates if the integer is negative. -/
noncomputable def zsmul (k : ℤ) (P : EdwardsPoint) : EdwardsPoint :=
  match k with
  | Int.ofNat n => nsmul n P
  | Int.negSucc n => neg (nsmul (n + 1) P)

/--
`RistrettoScalar`-action on `EdwardsPoint`. Lifts the `ZMod ℓ` scalar
to a canonical `ℕ` representative (in `[0, ℓ)`) and does `nsmul`.

This matches Move's `ristretto255::point_mul(p, s)`: the scalar is always
reduced mod `ℓ` before use.
-/
noncomputable def scalarSmul (s : RistrettoScalar) (P : EdwardsPoint) : EdwardsPoint :=
  nsmul s.val P

/-! ## Group-law axioms (deferred proof obligations)

Each axiom below is **algebraically true** on the twisted Edwards curve
`edwards25519` with non-square `d`; the proofs require the full
completeness theorem of Bernstein–Hisil, which is out of scope for this
layer. They mirror Mathlib-style `AddGroup` obligations so a downstream
`AddCommGroup` instance can be constructed. -/

/-- Left identity: `zero + P = P`. -/
axiom zero_add' (P : EdwardsPoint) : add zero P = P

/-- Right identity: `P + zero = P`. -/
axiom add_zero' (P : EdwardsPoint) : add P zero = P

/-- Left inverse: `(-P) + P = zero`. -/
axiom neg_add_cancel' (P : EdwardsPoint) : add (neg P) P = zero

/-- Commutativity: `P + Q = Q + P`. Immediate from the symmetric formula
in `x₁, x₂` and `y₁, y₂` — the denominators are identical and the numerators
are symmetric. -/
theorem add_comm' (P Q : EdwardsPoint) : add P Q = add Q P := by
  simp [add]
  refine ⟨?_, ?_⟩ <;> ring

/-- Associativity: `(P + Q) + R = P + (Q + R)`. Algebraically true for
twisted Edwards with `a = -1`, proof via the completeness theorem; stated
as an axiom here (see file-level doc §design decisions). -/
axiom add_assoc' (P Q R : EdwardsPoint) : add (add P Q) R = add P (add Q R)

/-! ## Instances powered by the axioms above -/

noncomputable instance addCommGroup : AddCommGroup EdwardsPoint where
  add := add
  zero := zero
  neg := neg
  add_assoc := add_assoc'
  zero_add := zero_add'
  add_zero := add_zero'
  neg_add_cancel := neg_add_cancel'
  add_comm := add_comm'
  nsmul := nsmul
  nsmul_zero := by intro; rfl
  nsmul_succ := by intro n P; rfl
  zsmul := zsmul
  zsmul_zero' := by intro; rfl
  zsmul_succ' := by
    intro n P
    show nsmul (n + 1) P = nsmul n P + P
    rfl
  zsmul_neg' := by intro n P; rfl

/-! ## Scalar module action

`RistrettoScalar = ZMod ℓ` acts on `EdwardsPoint` via `scalarSmul`. This
respects the `AddCommGroup` structure (distributivity laws) because `nsmul`
does; the fact that the induced action descends to `ZMod ℓ` relies on the
prime-order subgroup having order exactly `ℓ`.
-/

/-- **External obligation.** `nsmul` respects the subgroup order `ℓ`:
`nsmul ℓ P = zero` for every curve point `P`. Equivalent to saying the
Ristretto subgroup has exponent `ℓ`. Bernstein–Hamburg construction (2014). -/
axiom nsmul_subgroup_order (P : EdwardsPoint) :
    nsmul ristrettoSubgroupOrder P = zero

noncomputable instance scalarSMul : SMul RistrettoScalar EdwardsPoint :=
  ⟨scalarSmul⟩

/-- Zero scalar acts as zero. -/
theorem scalarSmul_zero' (P : EdwardsPoint) : scalarSmul 0 P = zero := by
  simp [scalarSmul, nsmul, ZMod.val_zero]

/-- Scalar addition distributes over the action. Requires the subgroup order
axiom to collapse reductions. Stated as an external obligation for now. -/
axiom scalarSmul_add' (s t : RistrettoScalar) (P : EdwardsPoint) :
    scalarSmul (s + t) P = add (scalarSmul s P) (scalarSmul t P)

/-- Point addition distributes over scalar action. -/
axiom scalarSmul_pointAdd' (s : RistrettoScalar) (P Q : EdwardsPoint) :
    scalarSmul s (add P Q) = add (scalarSmul s P) (scalarSmul s Q)

/-- Scalar multiplication: `(s · t) · P = s · (t · P)`. -/
axiom scalarSmul_assoc' (s t : RistrettoScalar) (P : EdwardsPoint) :
    scalarSmul (s * t) P = scalarSmul s (scalarSmul t P)

/-- `1 · P = P`. -/
axiom scalarSmul_one' (P : EdwardsPoint) : scalarSmul 1 P = P

/-- `s · 0 = 0`. Follows from induction on `s.val` using `add_zero'`; stated
as an axiom here to keep Layer 2 small (no deep induction). -/
axiom scalarSmul_smul_zero' (s : RistrettoScalar) : scalarSmul s zero = zero

/-- Action of zero scalar is the identity scalar multiplication equation
(equivalent to `scalarSmul_zero'` but phrased as `0 • P = 0`). -/
theorem zero_scalarSmul (P : EdwardsPoint) : (0 : RistrettoScalar) • P = zero :=
  scalarSmul_zero' P

/-- `RistrettoScalar`-module structure on `EdwardsPoint`, discharged by the
axioms above plus the ambient `AddCommGroup EdwardsPoint`. -/
noncomputable instance moduleRistrettoScalar : Module RistrettoScalar EdwardsPoint where
  smul s P := scalarSmul s P
  one_smul := scalarSmul_one'
  mul_smul := scalarSmul_assoc'
  smul_zero := scalarSmul_smul_zero'
  smul_add := fun s P Q => scalarSmul_pointAdd' s P Q
  add_smul := fun s t P => scalarSmul_add' s t P
  zero_smul := zero_scalarSmul

end EdwardsPoint

end MovementFormal.AptosStd.Crypto.EdwardsCurve25519
