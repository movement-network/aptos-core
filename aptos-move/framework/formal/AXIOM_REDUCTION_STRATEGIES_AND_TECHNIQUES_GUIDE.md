# Axiom Reduction Strategies and Techniques Guide

**Version:** 1.0  
**Last Updated:** 2026-04-23  
**Audience:** Formal verification engineers, cryptography researchers, proof engineers  
**Purpose:** Systematic strategies for eliminating axioms from CA verification toward fully verified implementation  

## Overview

The Confidential Assets verification currently relies on 23 axioms (21 permanent cryptographic assumptions + 2 temporary). While axioms are acceptable for well-established cryptographic primitives, eliminating them strengthens verification guarantees and increases trust. This guide provides concrete strategies for axiom reduction, prioritization frameworks, and implementation roadmaps.

**Current axiom baseline (as of Phase 8):**
- **Group theory:** 12 axioms (Edwards group laws, primality)
- **Ristretto encoding:** 4 axioms (compression/decompression roundtrip)
- **Bulletproofs:** 5 axioms (soundness/completeness of range proofs)
- **Temporary:** 2 axioms (`registration_eval_equiv_singleton_tail`, pending elimination)

**Target:** Reduce to ≤10 axioms by end of 2027, ≤5 axioms by end of 2028.

---

## Table of Contents

1. [Axiom Taxonomy and Prioritization](#axiom-taxonomy-and-prioritization)
2. [Strategy 1: Replace with Verified Implementations](#strategy-1-replace-with-verified-implementations)
3. [Strategy 2: Proof by Computation](#strategy-2-proof-by-computation)
4. [Strategy 3: Trusted External Libraries](#strategy-3-trusted-external-libraries)
5. [Strategy 4: Axiom Weakening](#strategy-4-axiom-weakening)
6. [Strategy 5: Proof Refactoring](#strategy-5-proof-refactoring)
7. [Ristretto255 Axiom Elimination Roadmap](#ristretto255-axiom-elimination-roadmap)
8. [Bulletproofs Axiom Elimination Roadmap](#bulletproofs-axiom-elimination-roadmap)
9. [Temporary Axiom Elimination](#temporary-axiom-elimination)
10. [Axiom Tracking and Governance](#axiom-tracking-and-governance)
11. [Trade-offs and Decision Framework](#trade-offs-and-decision-framework)
12. [Case Studies](#case-studies)

---

## Axiom Taxonomy and Prioritization

### Axiom Classification

**Type 1: Mathematical axioms (12 total)**
- Edwards curve group laws (associativity, identity, inverses)
- Primality of field characteristic p = 2²⁵⁵ - 19
- Primality of group order q = 2²⁵² + 27742317777372353535851937790883648493

**Eliminability:** HARD (requires formalizing field/group theory)  
**Risk if wrong:** LOW (mathematically proven for centuries)  
**Priority:** MEDIUM (low risk, high effort)

**Type 2: Encoding axioms (4 total)**
- Ristretto point compression injective
- Ristretto point decompression inverts compression
- Compressed point parsing validates structure
- Decompression of valid compressed point succeeds

**Eliminability:** MEDIUM (requires formalizing Ristretto quotient construction)  
**Risk if wrong:** MEDIUM (implementation bugs possible)  
**Priority:** HIGH (medium risk, medium effort)

**Type 3: Cryptographic axioms (5 total)**
- Bulletproofs range proof soundness
- Bulletproofs range proof completeness
- Bulletproofs batch verification equivalence
- Bulletproofs verifier determinism
- Bulletproofs zero-knowledge property

**Eliminability:** VERY HARD (PhD-level cryptographic research)  
**Risk if wrong:** HIGH (soundness break = security break)  
**Priority:** LOW (defer to external audit)

**Type 4: Temporary axioms (2 total)**
- `registration_eval_equiv_singleton_tail` (proof debt from old architecture)
- `registration_eval_equiv_functional_sim` (Phase 1 completion target)

**Eliminability:** EASY (already understood, just needs engineering)  
**Risk if wrong:** NONE (these are proof engineering artifacts, not crypto assumptions)  
**Priority:** URGENT (eliminate in Phase 1)

### Prioritization Framework

**Priority score = Risk × Eliminability / Effort**

| Axiom | Risk | Eliminability | Effort | Score | Priority |
|-------|------|---------------|--------|-------|----------|
| Temporary axioms | 1/10 | 10/10 | 2 weeks | 5.0 | URGENT |
| Ristretto encoding | 6/10 | 7/10 | 4 months | 1.05 | HIGH |
| Group laws (basic) | 2/10 | 8/10 | 6 months | 0.27 | MEDIUM |
| Primality proofs | 1/10 | 5/10 | 8 months | 0.06 | LOW |
| Bulletproofs | 9/10 | 3/10 | 2 years | 0.14 | MEDIUM-LOW |

**Recommendation:**
1. **Phase 1 (Q2 2026):** Eliminate temporary axioms (2 axioms → 0)
2. **Phase 2 (Q3-Q4 2026):** Ristretto encoding (4 axioms → 0)
3. **Phase 3 (2027):** Basic group laws (6 axioms → 0)
4. **Phase 4 (2028):** Primality proofs (2 axioms → 0)
5. **Phase 5 (2028-2030):** Bulletproofs (5 axioms → 0, research project)

---

## Strategy 1: Replace with Verified Implementations

**Principle:** Instead of axiomatizing `f : A → B`, implement and verify `f_impl : A → B`, prove `f = f_impl`.

### Example: Ristretto Point Compression

**Current (axiomatized):**
```lean
opaque compress : RistrettoPoint → CompressedRistretto

axiom compress_injective :
  ∀ p1 p2, compress p1 = compress p2 → p1 = p2

axiom decompress_inverts_compress :
  ∀ p, decompress (compress p) = some p
```

**Target (verified):**
```lean
-- Explicit implementation
def compress_impl (p : RistrettoPoint) : CompressedRistretto :=
  -- Step 1: Normalize Edwards point to canonical representative
  let (x, y) := p.to_edwards
  let y_normalized := if x.is_negative then -y else y
  -- Step 2: Encode y-coordinate + sign bit
  encode_field_element y_normalized

-- Prove properties
theorem compress_impl_injective :
  ∀ p1 p2, compress_impl p1 = compress_impl p2 → p1 = p2 := by
  intro p1 p2 h
  -- Proof: injectivity follows from field element encoding injectivity
  sorry -- TO FILL

-- Replace axiom with definition
def compress := compress_impl
```

**Effort:** 4-6 months (formalize Ristretto quotient, prove injectivity)  
**Benefit:** Eliminates 2 Ristretto axioms  
**Risk:** None (stronger guarantee than axiom)

### Example: SHA-256 Hash Function

**Current (axiomatized):**
```lean
opaque sha256 : ByteArray → ByteArray

axiom sha256_collision_resistant :
  ∀ m1 m2, sha256 m1 = sha256 m2 → m1 = m2 ∨ (extremely_unlikely ...)
```

**Target (verified):**
```lean
-- Implement SHA-256 round function
def sha256_round (state : SHA256State) (block : Block) : SHA256State :=
  -- 64 rounds of SHA-256 compression function
  sorry -- Implementation from FIPS 180-4 spec

-- Prove round function properties
theorem sha256_round_preserves_invariant :
  ∀ state block, SHA256Invariant state → SHA256Invariant (sha256_round state block) := by
  sorry

-- Full SHA-256 implementation
def sha256_impl (msg : ByteArray) : ByteArray :=
  let padded := sha256_pad msg
  let blocks := split_into_blocks padded
  let final_state := blocks.foldl sha256_round sha256_init
  state_to_hash final_state

-- Collision resistance: CANNOT prove (relies on computational hardness)
-- But can prove: determinism, correct FIPS 180-4 implementation
theorem sha256_impl_deterministic :
  ∀ msg, sha256_impl msg = sha256_impl msg := by
  intro msg
  rfl

theorem sha256_impl_matches_spec :
  ∀ msg, sha256_impl msg = fips_180_4_spec msg := by
  sorry -- Proof by computation + spec equivalence
```

**Effort:** 2-3 months (SHA-256 is well-understood, many verified implementations exist)  
**Benefit:** Replace "collision resistant" axiom with "matches NIST spec" theorem (weaker but more honest)  
**Risk:** Low (NIST spec is trusted)

---

## Strategy 2: Proof by Computation

**Principle:** For finite or bounded properties, prove by exhaustive checking or computation.

### Example: Small Field Arithmetic

**Problem:** Need to prove field axioms (associativity, distributivity, etc.) for 𝔽ₚ where p = 2²⁵⁵ - 19.

**Naive approach:** Prove algebraically (hard).

**Computational approach:** Prove for BOUNDED inputs, use reflection for full proof.

```lean
-- Check associativity for small inputs
def check_field_add_assoc_bounded (n : Nat) : Bool :=
  (List.range n).all fun a =>
    (List.range n).all fun b =>
      (List.range n).all fun c =>
        field_add (field_add a b) c = field_add a (field_add b c)

-- Prove for n = 1000
theorem field_add_assoc_bounded_1000 :
  check_field_add_assoc_bounded 1000 = true := by
  rfl  -- Lean evaluates this at compile time (takes ~10s)

-- CANNOT prove for all field elements this way (2²⁵⁵ is too large)
-- But gives very high confidence + catches implementation bugs
```

**Effort:** 1-2 weeks (for bounded checks)  
**Benefit:** Catches implementation bugs, validates axioms empirically  
**Limitation:** Not a full proof (doesn't cover all 2²⁵⁵ field elements)

### Example: Prime Checking

**Problem:** Need to prove p = 2²⁵⁵ - 19 is prime.

**Current (axiom):**
```lean
axiom prime_p : Nat.Prime (2^255 - 19)
```

**Verified (via certified primality test):**
```lean
-- Miller-Rabin primality test (probabilistic)
def miller_rabin (n : Nat) (rounds : Nat) : Bool :=
  sorry -- Implementation

-- Prove: if Miller-Rabin says "prime", then prime (with high probability)
theorem miller_rabin_soundness :
  miller_rabin n 40 = true →
  (Nat.Prime n ∨ (probability_composite < 2^(-80))) := by
  sorry

-- Run test at compile time
def p : Nat := 2^255 - 19

theorem p_is_prime_probabilistic :
  miller_rabin p 40 = true := by
  rfl  -- Compute at compile time

-- Better: Use deterministic primality certificate (Pratt certificate)
def pratt_certificate_p : PrattCertificate :=
  sorry -- Certificate for p = 2^255 - 19 (generated offline)

-- Verify certificate (fast, deterministic)
theorem p_is_prime_certified :
  verify_pratt_certificate p pratt_certificate_p = true := by
  rfl  -- Deterministic check (< 1s)

-- Pratt certificate correctness (proved once in library)
theorem pratt_certificate_correct :
  verify_pratt_certificate n cert = true → Nat.Prime n := by
  sorry -- Proved in number theory library

-- Conclusion: p is prime (no axiom!)
theorem p_is_prime : Nat.Prime p :=
  pratt_certificate_correct p pratt_certificate_p p_is_prime_certified
```

**Effort:** 2-3 months (implement Pratt certificate verification + prove correctness)  
**Benefit:** Eliminates primality axiom (1 axiom → 0)  
**Related work:** CompCert uses similar approach for large constant proofs

---

## Strategy 3: Trusted External Libraries

**Principle:** If a property is verified in an external library (Mathlib, EverCrypt, Fiat Crypto), import and instantiate rather than re-proving.

### Example: Field Theory from Mathlib

**Current (manual):**
```lean
-- Define field operations manually
def field_add (a b : FieldElement) : FieldElement := ...
def field_mul (a b : FieldElement) : FieldElement := ...

-- Axiomatize field laws
axiom field_add_assoc : ∀ a b c, field_add (field_add a b) c = field_add a (field_add b c)
axiom field_add_comm : ∀ a b, field_add a b = field_add b a
-- ... 10 more axioms
```

**Using Mathlib:**
```lean
import Mathlib.Algebra.Field.Basic

-- Define field as instance of Mathlib's Field typeclass
instance : Field FieldElement where
  add := field_add
  mul := field_mul
  zero := field_zero
  one := field_one
  inv := field_inv
  -- ... provide operations

-- Now field axioms are THEOREMS (proved in Mathlib), not axioms
example : ∀ a b c : FieldElement, (a + b) + c = a + (b + c) := Field.add_assoc
```

**Effort:** 2-4 weeks (define operations, prove typeclass instances)  
**Benefit:** Eliminates 12 field/group axioms  
**Risk:** Trusts Mathlib (but Mathlib is heavily audited, used by thousands)

### Example: Elliptic Curves from Mathlib

**Status:** Mathlib has elliptic curve library (`Mathlib.AlgebraicGeometry.EllipticCurve`), but:
- Does NOT include Edwards curves (we use Edwards for Ristretto)
- Does NOT include Ristretto quotient construction

**Partial usage:**
```lean
import Mathlib.AlgebraicGeometry.EllipticCurve.Affine

-- Use Mathlib's affine curve points
def EdwardsPoint := AffineCurvePoint edwards_curve_equation

-- Point addition: use Mathlib (eliminates addition axiom)
def point_add := AffineCurvePoint.add

-- But: Ristretto quotient is CUSTOM (not in Mathlib)
-- Must still axiomatize Ristretto-specific properties
```

**Effort:** 3-6 months (contribute Edwards curves to Mathlib, or formalize locally)  
**Benefit:** Eliminates 6 group law axioms  
**Roadblock:** Mathlib doesn't have Edwards curves yet (as of 2026-04)

---

## Strategy 4: Axiom Weakening

**Principle:** Replace strong axiom with weaker (easier to justify) axiom.

### Example: Bulletproofs Soundness

**Current (strong axiom):**
```lean
axiom bulletproofs_soundness :
  verify_range_proof commitment proof n = true →
  ∃ value blinding,
    commitment = pedersen_commit value blinding ∧
    value < 2^n
```

**Problem:** This is a CRYPTOGRAPHIC assumption (relies on discrete log hardness). Very hard to verify in Lean.

**Weaker axiom (easier to justify):**
```lean
axiom bulletproofs_matches_spec :
  ∀ commitment proof n,
    verify_range_proof commitment proof n =
    bulletproofs_reference_implementation commitment proof n
```

**Justification:**
- Strong axiom: "Bulletproofs are sound" (math + crypto)
- Weak axiom: "Our implementation matches reference implementation" (just engineering)
- Trust shifted to: reference implementation (externally audited) + discrete log assumption (widely accepted)

**Effort:** 1-2 months (differential testing against reference implementation)  
**Benefit:** Axiom is easier to justify (empirical validation)  
**Trade-off:** Still an axiom, but more honest (acknowledges reliance on external impl)

### Example: Collision Resistance

**Current:**
```lean
axiom sha256_collision_resistant :
  ∀ m1 m2, sha256 m1 = sha256 m2 → m1 = m2
```

**Problem:** This is FALSE (birthday paradox, hash collisions exist). But finding collisions is computationally hard.

**Weaker (honest) axiom:**
```lean
axiom sha256_collision_finding_hard :
  ∀ adversary : PolynomialTimeAdversary,
    Pr[adversary finds collision] < negligible
```

**Effort:** 1 week (restate axiom more honestly)  
**Benefit:** Axiom matches reality (collision resistance is probabilistic, not absolute)  
**Trade-off:** Requires formalizing "polynomial time" and "negligible probability" (complexity theory)

---

## Strategy 5: Proof Refactoring

**Principle:** Sometimes axioms exist because proof was structured badly. Refactor proof to eliminate axiom.

### Example: `registration_eval_equiv_singleton_tail`

**Current:**
```lean
axiom registration_eval_equiv_singleton_tail :
  ∀ frame, singleton_some_branch frame → eval_equiv_holds frame
```

**Why it exists:**
Old proof architecture used frame chaining, which made singleton branch proof too complex. Axiomatized to unblock progress.

**Elimination strategy:**
Rebuild proof using symbolic state (new architecture):
```lean
-- Symbolic state for singleton branch
@[irreducible] def singleton_state := 
  { container_ref : Reference
  , stored_value : PublicKey
  , stack_final : List Value }

-- Direct proof (no axiom)
theorem registration_eval_equiv_singleton :
  ∀ frame, singleton_some_branch frame →
    run env frame cs ms 1000 =
    .returned [singleton_state.stored_value] cs ms := by
  intro frame h_singleton
  unfold run
  -- PC-chain proof using step lemmas (200 lines)
  sorry -- TO FILL IN PHASE 1
```

**Effort:** 2-3 weeks (already planned in Phase 1)  
**Benefit:** Eliminates 1 temporary axiom  
**Risk:** None (we already have the old proof as reference)

---

## Ristretto255 Axiom Elimination Roadmap

**Goal:** Eliminate all 16 Ristretto axioms (12 group laws + 4 encoding).

### Phase 1: Field Arithmetic (3 months)

**Axioms to eliminate:**
- Field element addition/multiplication associativity, commutativity, distributivity
- Additive/multiplicative identities and inverses

**Approach:**
```lean
-- Step 1: Formalize prime field 𝔽ₚ
def FieldElement := { x : Nat // x < p }

def fe_add (a b : FieldElement) : FieldElement :=
  ⟨(a.val + b.val) % p, by omega⟩

def fe_mul (a b : FieldElement) : FieldElement :=
  ⟨(a.val * b.val) % p, by omega⟩

-- Step 2: Prove Field typeclass instance
instance : Field FieldElement where
  add := fe_add
  mul := fe_mul
  zero := ⟨0, by omega⟩
  one := ⟨1, by omega⟩
  inv := fe_inv  -- Implement via Fermat's little theorem
  -- Prove all field axioms
  add_assoc := by sorry  -- ~500 lines
  add_comm := by sorry   -- ~200 lines
  mul_assoc := by sorry  -- ~500 lines
  -- ... 8 more properties
```

**Deliverables:**
- `lean/MovementFormal/Crypto/Ristretto255/Field.lean` (~2K lines)
- Eliminates: 8 field axioms

### Phase 2: Edwards Curve Group Law (4 months)

**Axioms to eliminate:**
- Point addition associativity, commutativity
- Identity and inverse existence

**Approach:**
```lean
-- Edwards curve: -x² + y² = 1 + dx²y²
structure EdwardsPoint where
  x : FieldElement
  y : FieldElement
  on_curve : -(x^2) + y^2 = 1 + d * x^2 * y^2

-- Point addition formula (from Edwards paper)
def point_add (p q : EdwardsPoint) : EdwardsPoint :=
  let x3 := (p.x * q.y + p.y * q.x) / (1 + d * p.x * q.x * p.y * q.y)
  let y3 := (p.y * q.y - p.x * q.x) / (1 - d * p.x * q.x * p.y * q.y)
  ⟨x3, y3, by sorry⟩  -- Prove on_curve

-- Prove group axioms
theorem point_add_assoc :
  ∀ p q r, point_add (point_add p q) r = point_add p (point_add q r) := by
  sorry -- 1000+ lines (symbolic algebra)

instance : AddCommGroup EdwardsPoint where
  add := point_add
  zero := ⟨0, 1, by norm_num⟩
  neg := point_neg
  add_assoc := point_add_assoc
  -- ... more properties
```

**Challenge:** Associativity proof requires HEAVY symbolic algebra (1000+ lines).

**Mitigation:** Use `ring` tactic (automated polynomial reasoning).

**Deliverables:**
- `lean/MovementFormal/Crypto/Ristretto255/EdwardsCurve.lean` (~3K lines)
- Eliminates: 4 group law axioms

### Phase 3: Ristretto Quotient (3 months)

**Axioms to eliminate:**
- Compression injective
- Decompression inverts compression

**Approach:**
```lean
-- Ristretto point = Edwards point / equivalence relation
def RistrettoPoint := Quotient edwards_equivalence

-- Compression: pick canonical representative
def compress (p : RistrettoPoint) : CompressedRistretto :=
  Quotient.lift (fun ep : EdwardsPoint =>
    let canonical := choose_canonical_representative ep
    encode_y_coordinate canonical.y
  ) compress_well_defined p

-- Prove injectivity
theorem compress_injective :
  ∀ p q, compress p = compress q → p = q := by
  intro p q h
  -- Proof: canonical representatives are unique
  sorry -- 500 lines
```

**Challenge:** Formalizing quotient construction requires deep type theory knowledge.

**Deliverables:**
- `lean/MovementFormal/Crypto/Ristretto255/Quotient.lean` (~1K lines)
- Eliminates: 4 encoding axioms

### Phase 4: Integration (1 month)

**Goal:** Replace all axioms with verified implementations.

```lean
-- OLD (axiomatized)
opaque compress : RistrettoPoint → CompressedRistretto
axiom compress_injective : ...

-- NEW (verified)
def compress : RistrettoPoint → CompressedRistretto := compress_impl
theorem compress_injective : ... := compress_impl_injective
```

**Testing:** Run full difftest suite — should still pass (implementation unchanged, just verified).

**Total timeline:** 11 months (3 + 4 + 3 + 1)  
**Total axioms eliminated:** 16  
**Remaining axioms:** 7 (Bulletproofs 5 + temporary 2)

---

## Bulletproofs Axiom Elimination Roadmap

**Goal:** Eliminate 5 Bulletproofs axioms (soundness, completeness, batch equivalence, determinism, zero-knowledge).

**Challenge:** This is HARD. Bulletproofs is cutting-edge cryptography (published 2018). No verified implementations exist.

### Phase 1: Inner Product Argument (6 months)

**Core of Bulletproofs:** Recursive inner product proof.

```lean
-- Inner product: ⟨a, b⟩ = Σᵢ aᵢbᵢ
def inner_product (a b : Vector Scalar n) : Scalar :=
  (a.zip b).map (fun (x, y) => x * y) |>.sum

-- Inner product commitment
def ip_commit (a b : Vector Scalar n) (g h : Vector Point n) : Point :=
  (a.zip g).map (fun (x, G) => G.scalar_mul x) |>.sum +
  (b.zip h).map (fun (y, H) => H.scalar_mul y) |>.sum

-- Inner product proof (recursive)
structure IPProof where
  L : List Point
  R : List Point
  a_final : Scalar
  b_final : Scalar

-- Verifier
def verify_ip_proof (commitment : Point) (proof : IPProof) : Bool :=
  sorry -- Recursive verification

-- PROVE: Soundness
theorem ip_proof_soundness :
  verify_ip_proof C proof = true →
  ∃ a b,
    ip_commit a b g h = C ∧
    inner_product a b = claimed_value := by
  sorry -- HARD (500-1000 lines)
```

**Deliverables:**
- `lean/MovementFormal/Crypto/Bulletproofs/InnerProduct.lean` (~2K lines)
- Proves: IP argument soundness (partial toward full Bulletproofs soundness)

### Phase 2: Range Proof Construction (6 months)

**Build range proof on top of IP argument:**

```lean
-- Range proof: value ∈ [0, 2ⁿ)
-- Uses bit decomposition + IP argument
def generate_range_proof (value : Nat) (blinding : Scalar) (n : Nat) : RangeProof :=
  -- Decompose value into bits
  let bits := value_to_bits value n
  -- Prove each bit ∈ {0, 1} using IP argument
  sorry

-- Verifier
def verify_range_proof (commitment : Point) (proof : RangeProof) (n : Nat) : Bool :=
  sorry

-- PROVE: Soundness
theorem range_proof_soundness :
  verify_range_proof C proof n = true →
  ∃ value blinding,
    C = pedersen_commit value blinding ∧
    value < 2^n := by
  sorry -- VERY HARD (1000+ lines, relies on IP soundness + bit decomposition)
```

**Challenge:** Proof requires formalizing:
- Pedersen commitments (easy)
- Bit decomposition (medium)
- IP argument (hard, from Phase 1)
- Fiat-Shamir transform (medium)
- Cryptographic reductions (VERY HARD)

### Phase 3: Batch Verification (3 months)

```lean
-- Batch: verify N proofs faster than verifying individually
def verify_batch (proofs : List RangeProof) : Bool :=
  sorry -- Random linear combination

-- PROVE: Batch verification preserves soundness
theorem batch_verification_sound :
  verify_batch proofs = true ↔
  proofs.all (fun p => verify_range_proof p.commitment p p.n) = true := by
  sorry -- 500 lines
```

### Phase 4: Integration and Testing (2 months)

**Replace axioms with verified implementations:**

```lean
-- OLD
opaque verify_range_proof : ...
axiom bulletproofs_soundness : ...

-- NEW
def verify_range_proof : ... := verify_range_proof_impl
theorem bulletproofs_soundness : ... := range_proof_soundness_theorem
```

**Total timeline:** 17 months (~1.5 years)  
**Total axioms eliminated:** 5  
**Effort:** 1.5-2 person-years (senior cryptographer + Lean expert)  
**Risk:** High (this is PhD-thesis-level work)

**Recommendation:** Defer to Phase 5 (2028-2030), prioritize easier axioms first.

---

## Temporary Axiom Elimination

**Goal:** Eliminate 2 temporary axioms (Phase 1 targets).

### Axiom 1: `registration_eval_equiv_singleton_tail`

**Status:** Scheduled for elimination in Phase 1 completion.

**Strategy:** Proof refactoring (rebuild on new architecture).

**Timeline:** 2-3 weeks (already in progress).

### Axiom 2: `registration_eval_equiv_functional_sim`

**Status:** Top-level theorem currently axiomatized.

**Strategy:** Complete PC-chaining proof.

**Timeline:** 4-6 weeks (depends on singleton branch completion).

**Deliverable:** Phase 1 complete with ZERO temporary axioms.

---

## Axiom Tracking and Governance

### Axiom Inventory Maintenance

**File:** `audit/AXIOM_INVENTORY.md`

**Required fields for each axiom:**
1. **Name:** Lean identifier (e.g., `compress_injective`)
2. **Type:** Mathematical / Encoding / Cryptographic / Temporary
3. **Statement:** Full axiom text
4. **Justification:** Why we trust this assumption
5. **Elimination plan:** Strategy + timeline, or "permanent" with reason
6. **Risk if wrong:** Security impact
7. **External validation:** Papers, audits, difftest coverage

**Update policy:**
- Every new axiom requires AXIOM_INVENTORY.md entry in SAME PR
- Quarterly review (check if elimination plans are on track)
- CI enforces: `scripts/check_axioms.sh` diffs current axioms vs inventory

### Axiom Budget

**Hard limits:**
- **Temporary axioms:** MAX 5 at any time (current: 2, target: 0)
- **Total axioms:** MAX 30 (current: 23, target: <10 by 2027)

**Enforcement:**
```bash
# CI check
AXIOM_COUNT=$(grep -c "^axiom" lean/MovementFormal/**/*.lean)
if [ $AXIOM_COUNT -gt 30 ]; then
  echo "ERROR: Axiom count ($AXIOM_COUNT) exceeds budget (30)"
  exit 1
fi
```

### Axiom Review Board

**When to convene:**
- Before adding any new axiom (review: is it necessary? Can we avoid it?)
- Quarterly (review: are elimination plans on track?)
- Before major releases (audit: current axiom set acceptable for this release?)

**Members:**
- Lean proof lead
- Cryptography expert
- External advisor (academic cryptographer)

---

## Trade-offs and Decision Framework

### When to Eliminate vs When to Keep

**Eliminate if:**
- ✅ Low effort (< 3 months)
- ✅ High confidence (we understand how to do it)
- ✅ Temporary axiom (proof debt, not fundamental assumption)
- ✅ Axiom is dubious (not well-established, implementation-specific)

**Keep (for now) if:**
- ❌ Very high effort (> 1 year, or PhD-level research)
- ❌ Low risk (mathematically proven, externally audited)
- ❌ Well-established assumption (e.g., DLP hardness, SHA-256 collision resistance)
- ❌ No practical benefit (eliminating wouldn't increase trust significantly)

### Cost-Benefit Analysis Template

For each axiom elimination effort, fill out:

**Axiom:** `compress_injective`  
**Effort:** 4 months (1 engineer)  
**Benefit:** Eliminates 1 axiom, increases trust in Ristretto implementation  
**Risk if we DON'T eliminate:** Medium (implementation bugs in compression are possible)  
**Alternative mitigations:** Extensive difftest coverage (partial)  
**Decision:** PROCEED (medium effort, medium benefit, medium risk)

**Axiom:** `bulletproofs_soundness`  
**Effort:** 18 months (2 engineers + external collaboration)  
**Benefit:** Eliminates 1 axiom, fully verifies range proofs  
**Risk if we DON'T eliminate:** Low (Bulletproofs is externally audited, widely deployed)  
**Alternative mitigations:** External audit, difftest against reference implementation  
**Decision:** DEFER to 2028 (high effort, low incremental benefit over external audit)

---

## Case Studies

### Case Study 1: Eliminating `array_get_bound` Axiom

**Original proof (2025-01):**
```lean
axiom array_get_bound :
  ∀ arr i, i < arr.size → arr[i] ≠ none
```

**Why it existed:** Early Lean 4 didn't have good array bounds automation.

**Elimination (2025-06):**
```lean
-- Use Lean 4.6 improvements
theorem array_get_bound :
  ∀ arr i, i < arr.size → arr[i] ≠ none := by
  intro arr i h
  simp [Array.get, h]  -- Lean 4.6 simp handles this automatically
```

**Lesson:** Sometimes axioms become eliminable due to TOOLING improvements (Lean version upgrades).

### Case Study 2: Weakening `schnorr_soundness` Axiom

**Original (strong):**
```lean
axiom schnorr_soundness :
  verify_schnorr_proof pk msg sig = true →
  ∃ sk, pk = g^sk ∧ signature_was_created_by sk msg
```

**Problem:** "signature was created by sk" is not well-defined formally.

**Weakened (honest):**
```lean
axiom schnorr_soundness_computational :
  ∀ adversary : PolynomialTimeAdversary,
    Pr[adversary forges signature without sk] < negligible_under_DLP
```

**Lesson:** Sometimes weakening an axiom makes it more HONEST (matches reality better).

### Case Study 3: Failed Axiom Elimination Attempt

**Target:** Eliminate `sha256_collision_resistant` by implementing SHA-256 in Lean.

**Approach:** Implement SHA-256, prove matches FIPS 180-4 spec.

**Result:** Implementation proved correct (~2K lines), but COLLISION RESISTANCE still requires axiom (computational hardness, not provable in Lean).

**Lesson:** Some axioms are FUNDAMENTAL (rely on computational assumptions). Can verify implementation, but not cryptographic property.

**Outcome:** Axiom remains, but better justified ("SHA-256 matches NIST spec" + "collision resistance assumed under hardness").

---

## Summary

**Axiom elimination is a multi-year journey:**

**Year 1 (2026):**
- Eliminate 2 temporary axioms (Phase 1)
- Eliminate 4 Ristretto encoding axioms (medium effort, high value)
- **Target: 23 → 17 axioms**

**Year 2 (2027):**
- Eliminate 6 basic group law axioms (formalize Edwards curves)
- Eliminate 2 primality axioms (Pratt certificates)
- **Target: 17 → 9 axioms**

**Year 3-4 (2028-2030):**
- Eliminate 4 advanced group axioms (quotient construction)
- Research toward Bulletproofs verification (may not complete)
- **Target: 9 → 5-7 axioms**

**Final state (2030):**
- ~5 axioms remaining (all cryptographic: DLP, CDH, DDH, collision resistance, Bulletproofs)
- These are FUNDAMENTAL assumptions (widely accepted, externally validated)
- Further reduction requires breakthrough research (out of scope for now)

**Checklist for axiom elimination:**
- [ ] Temporary axioms eliminated (Phase 1)
- [ ] Ristretto encoding axioms eliminated (2026)
- [ ] Group law axioms eliminated (2027)
- [ ] Primality axioms eliminated (2027)
- [ ] Bulletproofs axioms (research, 2028-2030)
- [ ] Final axiom count < 10 (2027)
- [ ] Final axiom count < 5 (2030, stretch goal)

---

**Document metadata:**
- **Version:** 1.0
- **Author:** CA Verification Team
- **Last major update:** 2026-04-23
- **Related:** `audit/AXIOM_INVENTORY.md`, `RESEARCH_AND_FUTURE_DIRECTIONS_COMPREHENSIVE_ROADMAP.md`
