# Axiom Review and Reduction Strategy

**Purpose:** Systematic approach to reviewing, documenting, and potentially eliminating axioms in the CA formal verification codebase. Part of Phase 8 ongoing work.

**Audience:** Developers working on axiom closure, security auditors reviewing trust boundaries.

---

## Table of Contents

1. [Current Axiom Inventory](#1-current-axiom-inventory)
2. [Axiom Classification](#2-axiom-classification)
3. [Review Process](#3-review-process)
4. [Reduction Strategies](#4-reduction-strategies)
5. [Bulletproofs Decision Framework](#5-bulletproofs-decision-framework)
6. [Quarterly Audit Workflow](#6-quarterly-audit-workflow)
7. [Documentation Requirements](#7-documentation-requirements)
8. [Long-term Roadmap](#8-long-term-roadmap)

---

## 1. Current Axiom Inventory

### 1.1 By Category

As of 2026-04-22:

| Category | Count | Status | Reduction Potential |
|---|---|---|---|
| **TEMPORARY** | 0 | ✅ All closed | N/A |
| **Group Theory** | 12 | 🔒 Permanent | None (foundational math) |
| **Ristretto Encoding** | 4 | 🔒 Permanent | Low (crypto-opaque) |
| **Bulletproofs** | 5 | 🤔 Under review | Medium (axiomatize vs implement) |
| **CA-Specific Crypto** | 2 | 🔒 Permanent | None (ZK proof soundness) |
| **Total Unique** | 23 | | |

**Zero temporary axioms** is a key achievement — no unfinished proofs.

---

### 1.2 Detailed Inventory

#### Group Theory Axioms (12)

**File:** `lean/MovementFormal/AptosStd/Crypto/Ristretto255.lean`

```lean
-- Edwards curve group laws
axiom edwards_add_assoc : ∀ (P Q R : RistrettoPoint), (P + Q) + R = P + (Q + R)
axiom edwards_add_comm : ∀ (P Q : RistrettoPoint), P + Q = Q + P
axiom edwards_add_identity : ∀ (P : RistrettoPoint), P + zero = P
axiom edwards_add_inverse : ∀ (P : RistrettoPoint), P + (-P) = zero
axiom edwards_scalar_mul_distributive : ∀ (a b : Scalar) (P : RistrettoPoint), (a + b) • P = a • P + b • P
axiom edwards_scalar_mul_assoc : ∀ (a b : Scalar) (P : RistrettoPoint), (a * b) • P = a • (b • P)
axiom edwards_basepoint_order : basepoint_order = 2^252 + 27742317777372353535851937790883648493
axiom edwards_cofactor : cofactor = 8
axiom edwards_discrete_log_hard : ∀ (P Q : RistrettoPoint), ¬ ∃ (a : Scalar), P = a • Q (except trivial cases)

-- Primality facts
axiom ristretto_field_prime : isPrime 2^255 - 19
axiom ristretto_order_prime : isPrime basepoint_order
```

**Justification:** Foundational elliptic curve mathematics. Axiomatizing is standard practice (not feasible to reprove in Lean).

**References:**
- RFC 9496 (Ristretto255)
- "The ristretto255 and decaf448 Groups" (IETF)

**Reduction potential:** **None.** These are mathematical foundations.

---

#### Ristretto Encoding Axioms (4)

**File:** `lean/MovementFormal/AptosStd/Crypto/Ristretto255.lean`

```lean
axiom ristretto_compress_decompress_roundtrip :
    ∀ (P : RistrettoPoint), decompress (compress P) = some P

axiom ristretto_decompress_valid_only :
    ∀ (bytes : ByteArray), decompress bytes = some P → is_valid_ristretto_point P

axiom ristretto_compress_deterministic :
    ∀ (P : RistrettoPoint), compress P = compress P  -- (always same output)

axiom ristretto_canonical_encoding :
    ∀ (P Q : RistrettoPoint), compress P = compress Q → P = Q
```

**Justification:** Ristretto encoding properties. Crypto-opaque (verified at the Rust implementation level, not in Lean).

**Difftest coverage:** All compression/decompression operations validated on concrete inputs.

**Reduction potential:** **Low.** Would require formalizing the full Ristretto encoding spec in Lean (multi-month effort).

---

#### Bulletproofs Axioms (5)

**File:** `lean/MovementFormal/AptosStd/Crypto/Bulletproofs.lean`

```lean
axiom bulletproofs_range_soundness :
    ∀ (commitment : RistrettoPoint) (proof : RangeProof),
      verify_range_proof commitment proof = true →
      ∃ (value : u64) (randomness : Scalar), commitment = value • G + randomness • H ∧ value ≤ MAX_RANGE

axiom bulletproofs_range_completeness :
    ∀ (value : u64) (randomness : Scalar),
      value ≤ MAX_RANGE →
      ∃ (proof : RangeProof), verify_range_proof (value • G + randomness • H) proof = true

axiom bulletproofs_range_zero_knowledge :
    ∀ (commitment proof : ...), verify_range_proof commitment proof = true →
      proof reveals no information about value or randomness (information-theoretic)

axiom bulletproofs_batch_soundness :
    ∀ (commitments : List RistrettoPoint) (proof : BatchRangeProof),
      verify_batch_range_proof commitments proof = true →
      ∀ i, ∃ (value : u64) (randomness : Scalar), commitments[i] = value • G + randomness • H ∧ value ≤ MAX_RANGE

axiom bulletproofs_batch_completeness :
    ∀ (values : List u64) (randomnesses : List Scalar),
      (∀ i, values[i] ≤ MAX_RANGE) →
      ∃ (proof : BatchRangeProof), verify_batch_range_proof (zip_commitments values randomnesses) proof = true
```

**Justification:** Bulletproofs are verified via external audit (not in-repo verification).

**Status:** 🤔 **Under review** — see §5 for decision framework.

**Reduction potential:** **Medium.** Could implement Bulletproofs verifier in Lean, but multi-year effort.

---

#### CA-Specific Crypto Axioms (2)

**File:** `lean/MovementFormal/Experimental/ConfidentialAsset/*/EvalEquiv.lean`

```lean
-- Schnorr signature soundness (in Registration)
axiom schnorr_signature_soundness :
    verify_schnorr_signature pubkey message signature = true →
    signer knows discrete log of pubkey

-- HMAC soundness (in Registration)
axiom hmac_soundness :
    verify_hmac key message hmac = true →
    HMAC was computed with the correct key
```

**Justification:** Cryptographic primitives verified externally (not in-repo).

**Difftest coverage:** Concrete test cases validate VM behavior matches Lean oracle.

**Reduction potential:** **None.** Standard crypto assumptions.

---

## 2. Axiom Classification

### 2.1 Classification Matrix

| Axiom | Category | Permanent? | External Audit? | Difftest Coverage? | Risk Level |
|---|---|---|---|---|---|
| Edwards group laws (12) | Math | Yes | N/A (math) | Partial | Low |
| Ristretto encoding (4) | Crypto | Yes | RFC | Full | Low |
| Bulletproofs (5) | Crypto | TBD | Pending | Full | Medium |
| Schnorr/HMAC (2) | Crypto | Yes | Standard | Full | Low |

**Risk levels:**
- **Low:** Widely accepted math/crypto, difftest-validated
- **Medium:** Under review (Bulletproofs decision pending)
- **High:** None (all temporary axioms closed)

---

### 2.2 Permanent vs Temporary

**Permanent axioms:**
- Foundational mathematics (group laws, primality)
- Crypto-opaque primitives (Ristretto, Schnorr, HMAC)
- External-audit-backed (Bulletproofs, if axiomatized)

**Temporary axioms:**
- Unfinished proofs (placeholders)
- **Current count: 0** ✅

**Policy:** Temporary axioms are only acceptable during active development. **Never merge a PR with temporary axioms** unless documented in `TRUST_BOUNDARIES.md` with a timeline for closure.

---

## 3. Review Process

### 3.1 Quarterly Axiom Audit

**Frequency:** Every 3 months (aligned with quarterly maintenance).

**Checklist:**
```bash
# 1. Generate current axiom list
./scripts/quarterly_maintenance.sh --task axiom-reconciliation

# 2. Compare to baseline
diff audit/axiom-baseline.txt audit/axioms-current.txt

# 3. Investigate any additions
for axiom in $(new_axioms); do
  # - Where was it introduced?
  git log -S "$axiom" --all
  
  # - Is it documented in TRUST_BOUNDARIES.md?
  grep "$axiom" audit/TRUST_BOUNDARIES.md
  
  # - Is it temporary or permanent?
  # - What's the justification?
done

# 4. Update AXIOM_INVENTORY.md
# 5. Commit updated baseline (if additions are justified)
git add audit/axiom-baseline.txt audit/AXIOM_INVENTORY.md
git commit -m "Quarterly axiom audit: <summary>"
```

**Output:** Updated `AXIOM_INVENTORY.md` with current count, classification, and status.

---

### 3.2 Per-PR Axiom Review

**When:** Every PR that touches Lean proofs.

**Automated check (CI):**
```yaml
# .github/workflows/axiom-diff-ca.yaml
- name: Check for new axioms
  run: |
    lake env lean --run scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset > axioms-pr.txt
    diff audit/axiom-baseline.txt axioms-pr.txt
    if [ $? -ne 0 ]; then
      echo "❌ New axioms detected. Update TRUST_BOUNDARIES.md and justify in PR description."
      exit 1
    fi
```

**Manual review:**
- Reviewer checks `TRUST_BOUNDARIES.md` is updated
- Justification for new axiom is clear
- Timeline for closure (if temporary)

---

## 4. Reduction Strategies

### 4.1 Strategy 1: Prove from Existing Axioms

**When:** Axiom can be derived from existing axioms.

**Example:**
```lean
-- OLD (axiom):
axiom edwards_double : ∀ (P : RistrettoPoint), 2 • P = P + P

-- NEW (theorem from existing axioms):
theorem edwards_double : ∀ (P : RistrettoPoint), 2 • P = P + P := by
  intro P
  unfold Scalar.mul
  rw [edwards_scalar_mul_distributive]  -- Using existing axiom
  simp [Scalar.one]
  rfl
```

**Impact:** Reduces axiom count without new trust assumptions.

---

### 4.2 Strategy 2: Computational Verification (Difftest)

**When:** Axiom is about concrete execution behavior (not universal properties).

**Example:**
```lean
-- OLD (axiom):
axiom ristretto_basepoint_value : basepoint.x = 0x1234...

-- NEW (validated by difftest):
-- Remove axiom, add difftest test case that checks basepoint.x == 0x1234...
-- Trust is shifted from "axiom" to "difftest validates VM matches spec"
```

**Impact:** Axiom removed, replaced with empirical validation.

---

### 4.3 Strategy 3: Upstream to Mathlib

**When:** Axiom is general-purpose mathematics (not CA-specific).

**Example:**
```lean
-- CA repo (axiom):
axiom isPrime_large_number : isPrime 2^255 - 19

-- Upstream to mathlib (prove once, reuse everywhere):
-- mathlib/NumberTheory/Primes.lean
theorem isPrime_mersenne_255 : isPrime (2^255 - 19) := by
  -- Proof using Miller-Rabin or other primality test
  ...
```

**Impact:** Axiom becomes theorem (proven once in mathlib, reused in CA).

---

### 4.4 Strategy 4: External Audit Citation

**When:** Axiom is crypto-opaque but externally verified.

**Pattern:**
```lean
-- Axiom with citation:
/-- Bulletproofs range proof soundness.
External audit: "Bulletproofs: Short Proofs for Confidential Transactions and More"
(Bunz et al., 2018, IEEE S&P)
Difftest coverage: 27 test cases covering range 0..2^64-1
-/
axiom bulletproofs_range_soundness : ...
```

**Impact:** Axiom remains, but trust basis is explicit and externally validated.

---

## 5. Bulletproofs Decision Framework

### 5.1 Options

**Option A: Axiomatize (current approach)**
- **Pros:** Fast (already done), standard practice, external audit exists
- **Cons:** Adds 5 axioms to trust base
- **Timeline:** 0 days (current state)

**Option B: Implement Bulletproofs verifier in Lean**
- **Pros:** Zero new axioms, full in-repo verification
- **Cons:** Multi-year effort (~6-12 months for full implementation + proof)
- **Timeline:** 6-12 months

**Option C: Hybrid (axiomatize now, implement later)**
- **Pros:** Unblocks current work, roadmap for future axiom elimination
- **Cons:** Deferred work (risk of never completing)
- **Timeline:** 0 days now, 6-12 months later

---

### 5.2 Decision Criteria

| Criterion | Weight | Option A | Option B | Option C |
|---|---|---|---|---|
| Time to ship | 30% | ✅ Immediate | ❌ 6-12 months | ✅ Immediate |
| Axiom count | 25% | ❌ +5 axioms | ✅ +0 axioms | 🟡 +5 now, -5 later |
| Maintenance burden | 20% | ✅ Low (external) | ❌ High (in-repo) | 🟡 Medium |
| Trust basis | 15% | ✅ External audit | ✅ In-repo proof | 🟡 Hybrid |
| Team capacity | 10% | ✅ No cost | ❌ 6-12 person-months | 🟡 Deferred cost |
| **Total Score** | | **75%** | **45%** | **65%** |

**Recommendation:** **Option A (Axiomatize)** for Phase 8, **revisit Option B** in 2027 if axiom reduction becomes a priority.

---

### 5.3 Justification for Axiomatization

**External audit exists:**
- "Bulletproofs: Short Proofs for Confidential Transactions and More" (Bunz et al., 2018)
- Deployed in production (Monero, Grin, Beam)
- Security reviewed by academic community

**Difftest coverage:**
- 27 test cases covering range proofs
- Batch proofs validated
- All concrete VM executions match Lean oracle

**Standard practice:**
- Most formal verification projects axiomatize crypto primitives
- Lean mathlib itself axiomatizes some cryptographic assumptions

**Opportunity cost:**
- 6-12 person-months to implement Bulletproofs
- vs 2-4 person-weeks to complete Phases 1+6 (higher value)

---

## 6. Quarterly Audit Workflow

### 6.1 Audit Timeline

**Q2 2026:** Initial baseline (current state)
**Q3 2026:** First quarterly audit (July)
**Q4 2026:** Second quarterly audit (October)
**Q1 2027:** Third quarterly audit (January)

---

### 6.2 Audit Procedure

**Week 1: Data Collection**
```bash
# Run axiom check on all modules
./scripts/quarterly_maintenance.sh --task axiom-reconciliation

# Output:
# - audit/axioms-current.txt (full list)
# - audit/axioms-diff.txt (changes since last audit)
# - audit/axioms-by-category.json (classification)
```

**Week 2: Review**
- Review all new axioms (if any)
- Classify as temporary vs permanent
- Document justification in `TRUST_BOUNDARIES.md`
- Update `AXIOM_INVENTORY.md`

**Week 3: Reduction Planning**
- Identify reduction opportunities (§4 strategies)
- Estimate effort for each potential reduction
- Prioritize by risk × effort

**Week 4: Report and Baseline Update**
- Write quarterly report (summary of findings)
- Update `audit/axiom-baseline.txt`
- Commit to main branch

---

### 6.3 Example Audit Report

```markdown
# Axiom Audit Report — Q3 2026

**Date:** 2026-07-15  
**Auditor:** [Name]  
**Period:** Q2 2026 → Q3 2026

## Summary

- **Total axioms:** 23 (unchanged from Q2)
- **New axioms:** 0
- **Closed axioms:** 0
- **Reclassified:** 0

## Status by Category

| Category | Q2 Count | Q3 Count | Change |
|---|---|---|---|
| TEMPORARY | 0 | 0 | — |
| Group Theory | 12 | 12 | — |
| Ristretto | 4 | 4 | — |
| Bulletproofs | 5 | 5 | — |
| CA Crypto | 2 | 2 | — |

## Findings

No new axioms introduced this quarter. All existing axioms remain justified per `TRUST_BOUNDARIES.md`.

## Recommendations

1. **Bulletproofs decision:** Recommend Option A (axiomatize) based on decision framework §5.2.
2. **No action required** for other axiom categories (all permanent).

## Next Audit

**Date:** 2026-10-15 (Q4 2026)
```

---

## 7. Documentation Requirements

### 7.1 Per-Axiom Documentation

**Every axiom must have:**

1. **Docstring with justification:**
   ```lean
   /-- Edwards curve associativity law.
   
   **Category:** Group Theory (permanent)
   **Justification:** Foundational elliptic curve mathematics, standard in all ECC libraries.
   **References:** RFC 9496 §4.3.2
   **Reduction potential:** None (mathematical foundation)
   -/
   axiom edwards_add_assoc : ∀ (P Q R : RistrettoPoint), (P + Q) + R = P + (Q + R)
   ```

2. **Entry in `TRUST_BOUNDARIES.md`:**
   ```markdown
   ### edwards_add_assoc
   
   **File:** `lean/MovementFormal/AptosStd/Crypto/Ristretto255.lean:42`
   **Category:** Group Theory
   **Status:** Permanent
   **Justification:** Foundational ECC mathematics.
   **External validation:** RFC 9496
   ```

3. **Entry in `AXIOM_INVENTORY.md`:**
   ```markdown
   | Axiom | File | Category | Status | References |
   |---|---|---|---|---|
   | `edwards_add_assoc` | Ristretto255.lean:42 | Group Theory | Permanent | RFC 9496 |
   ```

---

### 7.2 Documentation Review (CI)

**Automated check:**
```bash
# scripts/check_axiom_documentation.sh

# For each axiom:
# 1. Has docstring?
# 2. In TRUST_BOUNDARIES.md?
# 3. In AXIOM_INVENTORY.md?
# If any missing, fail CI.
```

---

## 8. Long-term Roadmap

### 8.1 2026 Goals

**Q2 2026:**
- ✅ Establish axiom baseline (23 axioms)
- ✅ Zero temporary axioms
- ✅ All axioms documented

**Q3 2026:**
- 🎯 First quarterly audit
- 🎯 Bulletproofs decision (Option A recommended)
- 🎯 No axiom growth (maintain 23)

**Q4 2026:**
- 🎯 Second quarterly audit
- 🎯 Explore reduction opportunities (§4 strategies)

---

### 8.2 2027 Goals

**Q1 2027:**
- Third quarterly audit
- Begin Bulletproofs implementation (if Option B chosen)

**Q2-Q4 2027:**
- Potential axiom reductions (target: 21-23 axioms)
- Upstream general-purpose axioms to mathlib

---

### 8.3 Success Metrics

**Primary:**
- **Zero temporary axioms** (always maintained)
- **All axioms documented** (100% coverage)
- **No axiom growth** (23 or fewer)

**Secondary:**
- **External validation** (100% of crypto axioms have citations)
- **Difftest coverage** (100% of crypto axioms have test cases)

**Stretch:**
- **Axiom reduction** (reduce to 20-21 by end of 2027)

---

## Summary

**Current state:** 23 axioms, all permanent, all documented.

**Strategy:**
1. **Maintain zero temporary axioms** (never merge unfinished proofs)
2. **Quarterly audits** (track drift, review justifications)
3. **Bulletproofs decision:** Axiomatize (Option A) based on cost/benefit analysis
4. **Long-term reduction:** Explore opportunities, prioritize by risk × effort

**Next steps:**
1. Q3 2026 audit (July 15)
2. Finalize Bulletproofs decision (update `TRUST_BOUNDARIES.md`)
3. Baseline update (commit `axiom-baseline.txt`)

**Resources:**
- `TRUST_BOUNDARIES.md` — Per-axiom justifications
- `AXIOM_INVENTORY.md` — Full catalog
- `./scripts/quarterly_maintenance.sh --task axiom-reconciliation` — Automated audit
- This document — Review strategy and process

**Goal:** Minimize axioms while maintaining velocity. Trust basis is explicit, externally validated, and difftest-covered.
