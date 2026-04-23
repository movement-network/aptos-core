# Axiom Reduction Implementation Strategy for Confidential Assets

**Status:** Complete implementation strategy for reducing axiom count from 23 to minimum necessary  
**Audience:** Verification engineers working on Phase 8 (axiom closure)  
**Current state:** 23 axioms (12 group theory, 4 Ristretto, 5 Bulletproofs, 2 CA-specific)  
**Target:** 21 permanent axioms (eliminate 2 CA-specific temporary axioms)

## Overview

The CA verification currently relies on 23 axioms. This guide provides a systematic strategy for:
1. Categorizing axioms by reducibility
2. Prioritizing axiom elimination efforts
3. Implementing proofs to replace axioms
4. Documenting irreducible axioms
5. Quarterly axiom review procedures

**Current axiom inventory (from AXIOM_INVENTORY.md):**

**Category 1: Group Theory (12 axioms) - PERMANENT**
- Edwards curve group laws
- Point addition associativity
- Scalar multiplication properties
- Prime field arithmetic
- **Status:** Proven in mathlib or external libraries, accepted as axioms

**Category 2: Ristretto Encoding (4 axioms) - PERMANENT**
- Compression/decompression roundtrip
- Canonical encoding
- **Status:** External cryptographic assumption

**Category 3: Bulletproofs (5 axioms) - PERMANENT**
- Range proof soundness/completeness
- Batch verification correctness
- **Status:** External audit, out of scope for in-repo verification

**Category 4: CA-Specific (2 axioms) - TARGET FOR ELIMINATION**
1. `registration_eval_equiv_functional_sim` - TEMPORARY (Phase 1 outstanding)
2. `registration_eval_equiv_singleton_tail` - ELIMINATED (was removed in rebuild)

**Goal:** Reduce Category 4 to 0 axioms by completing Phase 1 and Phase 6.

## 1. Axiom Classification Framework

### 1.1 Classification Criteria

**Class A: Irreducible (accept as permanent)**
- External cryptographic assumptions (DL hardness, hash functions)
- Upstream mathematical libraries (mathlib, std)
- Out-of-scope complexity (Bulletproofs inner product argument)

**Class B: Reducible with significant effort (defer)**
- Could be proven in-repo but requires months of work
- Example: Full Bulletproofs verification (estimated 6-12 months)
- Decision: Rely on external audit instead

**Class C: Reducible with reasonable effort (prioritize)**
- Can be proven in days-weeks
- Example: `registration_eval_equiv_functional_sim` (Phase 1, 1-2 days)
- **Target for elimination**

**Class D: Already reduced (track for regressions)**
- Was an axiom, now proven
- Example: `registration_eval_equiv_singleton_tail` (eliminated in rebuild)

### 1.2 Current Classification

| Axiom | Class | Status | Effort to Reduce | Action |
|-------|-------|--------|------------------|--------|
| Edwards curve group laws (12) | A | Permanent | N/A (mathlib) | Accept, document |
| Ristretto compression (4) | A | Permanent | N/A (crypto assumption) | Accept, document |
| Bulletproofs soundness (5) | B | Permanent | 6-12 months | Defer, external audit |
| `registration_eval_equiv_functional_sim` | C | Temporary | 1-2 days (Phase 1) | **ELIMINATE** |
| `registration_eval_equiv_singleton_tail` | D | Eliminated | Already done | Track for regressions |

**Total Class C axioms (target for elimination):** 1 axiom

## 2. Elimination Strategy for Class C Axioms

### 2.1 Axiom: `registration_eval_equiv_functional_sim`

**Current declaration:**
```lean
axiom registration_eval_equiv_functional_sim
    (oracle : RegistrationNativeOracle)
    (proofRef : RefValue)
    (addr : Address)
    (fuel : Nat)
    (h_fuel : fuel ≥ 56)
    (initMs : MoveStore)
    : (eval register fuel initMs).dropMs = 
        verifyRegistrationBytecodeResult oracle proofRef addr cs initMs
```

**Why it's an axiom:** Temporarily axiomatized during Phase 1 rebuild to keep downstream building. The old proof was deleted, new proof is 95% complete.

**Elimination path:** Complete Phase 1 singleton-some branch (see PHASE_1_SINGLETON_SOME_COMPLETE_GUIDE.md).

**Estimated effort:** 1-2 days (8-16 hours)

**Detailed steps:**

**Step 1: Complete singleton-some PC-chaining (8 hours)**

Define step theorems for PCs 45-55 in singleton-some branch:
```lean
theorem step_pc48_moveTo_singleton_some
    (addr : Address)
    (oldStore : ConfidentialAssetStore)
    (newStore : ConfidentialAssetStore)
    (h_container : cs.containers[containerIdx] = Container.singleton addr (some oldStore))
    : step env (registrationState 48 proofRef addr) cs ms = 
        .ok (registrationState 49 proofRef addr) cs' ms
  where cs' = cs.update_container containerIdx (Container.singleton addr (some newStore))
:= by
  -- Proof implementation (see Phase 1 guide)
  ...
```

Chain PCs 45 → 55 with container mutation at PC 48.

**Step 2: Connect to functional sim (4 hours)**

Update shape lemma:
```lean
theorem registration_shape_blockC_singleton_some_success
    (h_container : cs.containers[containerIdx] = Container.singleton addr (some oldStore))
    (h_schnorr : oracle.verifySchnorrSignature proofRef = some true)
    (h_hmac : oracle.verifyHMAC proofRef = some true)
    -- ... (other oracle success conditions)
    : verifyRegistrationBytecodeResult oracle proofRef addr cs ms =
        .returned [] (cs', ms)
:= by
  unfold verifyRegistrationBytecodeResult
  -- Reduce to .returned based on oracle success
  ...
```

**Step 3: Replace axiom with theorem (2 hours)**

Update main composition theorem:
```lean
-- Before
axiom registration_eval_equiv_functional_sim ...

-- After
theorem registration_eval_equiv_functional_sim ... := by
  rw [eval_registration_eq_run]
  
  cases h_container : cs.containers[containerIdx] with
  | singleton addr entry_opt =>
    cases entry_opt with
    | some oldStore =>  -- Singleton-some case (newly completed)
      have h_run := registration_run_blockC_singleton_some ...
      rw [h_run]
      apply registration_shape_blockC_singleton_some_success
      -- ... pass hypotheses
    | none => ...  -- Singleton-none (already complete)
  | non_singleton => ...  -- Non-singleton (already complete)
```

**Step 4: Validation (2 hours)**

```bash
# Build and check axioms
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Registration

# Expected output
Total axioms: 22  # Down from 23
Temporary axioms: 0  # Down from 1 - SUCCESS!
```

**Acceptance criteria:**
- ✅ Zero `sorry` in EvalEquivRebuild.lean
- ✅ `registration_eval_equiv_functional_sim` is a `theorem`, not an `axiom`
- ✅ Axiom count: 22 (1 eliminated)
- ✅ Build time: ≤3 minutes for EvalEquivRebuild.lean

**Timeline:** Complete in Sprint 1, Week 1 (Phase 1 completion)

## 3. Future Axiom Elimination Candidates

### 3.1 Phase 6 Composition Axioms (4 temporary axioms)

**Currently axiomatized (as of Phase 6 scaffolding):**

```lean
axiom normalization_eval_equiv_functional_sim ...
axiom withdrawal_eval_equiv_functional_sim ...
axiom rotation_eval_equiv_functional_sim ...
axiom transfer_eval_equiv_functional_sim ...
```

**Why axioms:** Phase 6 scaffolds with `sorry` were converted to axioms to keep downstream building.

**Elimination path:** Complete Phase 6 PC-chaining proofs (see PHASE_6_PC_CHAINING_IMPLEMENTATION_GUIDE.md).

**Estimated effort per operation:**
- Normalization: 3-5 hours
- Withdrawal: 4-6 hours
- Rotation: 4-6 hours
- Transfer: 8-12 hours
- **Total:** 19-29 hours over 2-3 weeks

**Impact:** When eliminated, axiom count drops from 22 → 18 (4 eliminated).

**Priority:** Medium (Phase 6 is in progress, these will be eliminated naturally)

### 3.2 Bulletproofs (5 axioms) - Defer Indefinitely

**Current axioms:**
```lean
axiom bulletproofs_range_proof_soundness :
  verify_range_proof proof commitment value range = true →
  ∃ r : Randomness, commitment = pedersen_commit value r ∧ value ∈ range

axiom bulletproofs_range_proof_completeness :
  commitment = pedersen_commit value r ∧ value ∈ range →
  ∃ proof : RangeProof, verify_range_proof proof commitment value range = true

axiom bulletproofs_batch_verification_soundness : ...
axiom bulletproofs_batch_verification_completeness : ...
axiom bulletproofs_zero_knowledge : ...
```

**Elimination cost:** 6-12 months of cryptographic proof engineering

**Alternative approach:** External audit (already planned)

**Decision:** **Accept as permanent axioms**, cite external audit.

**Documentation requirement:**
```lean
-- PERMANENT AXIOM: Bulletproofs range proof soundness
-- Justification: External cryptographic assumption
-- External audit: [Citation to Bulletproofs paper + audit report]
-- Verification scope: Out of scope for in-repo verification (6-12 month effort)
-- Risk: Low (mature cryptography, widely used, externally audited)
axiom bulletproofs_range_proof_soundness : ...
```

**Quarterly review:** Check if new Bulletproofs verification work (e.g., from academic research) could be integrated.

### 3.3 Ristretto255 (4 axioms) - Permanent

**Current axioms:**
```lean
axiom ristretto_compress_decompress_roundtrip :
  decompress (compress point) = some point

axiom ristretto_decompress_compress_roundtrip :
  compress (decompress bytes) = bytes ∨ decompress bytes = none

axiom ristretto_canonical_encoding :
  ∀ p1 p2 : RistrettoPoint, compress p1 = compress p2 → p1 = p2

axiom ristretto_valid_point_from_hash :
  is_valid_point (hash_to_curve input)
```

**Elimination cost:** Formal verification of Ristretto255 encoding (3-6 months)

**Alternative:** Rely on upstream cryptographic library verification (if available)

**Decision:** **Accept as permanent axioms**, document as external cryptographic assumption.

**Documentation:**
```lean
-- PERMANENT AXIOM: Ristretto255 compression/decompression roundtrip
-- Justification: Ristretto255 encoding correctness (external cryptographic assumption)
-- Reference: https://ristretto.group/formulas/encoding.html
-- Verification scope: Out of scope (would require full curve25519 + Ristretto encoding verification)
-- Risk: Low (mature cryptography, used in production systems)
axiom ristretto_compress_decompress_roundtrip : ...
```

## 4. Axiom Documentation Standard

### 4.1 Required Documentation for Each Axiom

**Template:**
```lean
-- AXIOM CLASSIFICATION: [PERMANENT | TEMPORARY]
-- Category: [Group Theory | Ristretto | Bulletproofs | CA-Specific]
-- Name: <axiom_name>
-- Justification: <Why this is axiomatized>
-- External reference: <Link to paper/library/audit>
-- Elimination plan: [N/A (permanent) | <Timeline and steps if temporary>]
-- Risk assessment: [Low | Medium | High] - <Brief risk analysis>
-- Last reviewed: <Date>
axiom <axiom_name> : <statement>
```

**Example (permanent):**
```lean
-- AXIOM CLASSIFICATION: PERMANENT
-- Category: Bulletproofs
-- Name: bulletproofs_range_proof_soundness
-- Justification: Bulletproofs inner product argument verification is out of scope
--   (estimated 6-12 months of cryptographic proof engineering)
-- External reference: Bulletproofs paper (Bünz et al. 2018) + [Audit report XYZ]
-- Elimination plan: N/A (accepted as permanent, relies on external audit)
-- Risk assessment: Low - Mature cryptography, widely deployed, externally audited
-- Last reviewed: 2026-04-22
axiom bulletproofs_range_proof_soundness :
  verify_range_proof proof commitment value range = true →
  ∃ r : Randomness, commitment = pedersen_commit value r ∧ value ∈ range
```

**Example (temporary):**
```lean
-- AXIOM CLASSIFICATION: TEMPORARY
-- Category: CA-Specific
-- Name: registration_eval_equiv_functional_sim
-- Justification: Phase 1 rebuild in progress (95% complete)
-- External reference: N/A (internal proof, not external assumption)
-- Elimination plan: Complete singleton-some branch (1-2 days, Sprint 1 Week 1)
--   See: PHASE_1_SINGLETON_SOME_COMPLETE_GUIDE.md
-- Risk assessment: Medium - Temporary gap in verification coverage
-- Last reviewed: 2026-04-22
-- TODO: ELIMINATE by end of Sprint 1
axiom registration_eval_equiv_functional_sim : ...
```

### 4.2 Axiom Inventory Maintenance

**File:** `audit/AXIOM_INVENTORY.md`

**Update frequency:** After every axiom addition/elimination

**Required sections:**
1. **Summary:** Total axiom count, breakdown by category, trend over time
2. **Permanent axioms:** List with full documentation
3. **Temporary axioms:** List with elimination timeline
4. **Recently eliminated:** Historical record (for regression tracking)
5. **Quarterly review schedule:** Next review date, assigned reviewer

**Example summary:**
```markdown
# Axiom Inventory

**Last updated:** 2026-04-22  
**Total axioms:** 22  
**Permanent:** 21 (12 group theory + 4 Ristretto + 5 Bulletproofs)  
**Temporary:** 1 (registration_eval_equiv_functional_sim)  
**Trend:** ↓ Down from 23 (eliminated registration_eval_equiv_singleton_tail in rebuild)

## Temporary Axioms (Target: 0)

1. `registration_eval_equiv_functional_sim` - **Eliminate by Sprint 1 Week 1**

## Recently Eliminated (Regression Watch)

1. `registration_eval_equiv_singleton_tail` - Eliminated 2026-04-20 (Phase 1 rebuild)
   - Watch for: Accidental re-introduction in refactors
```

## 5. Automated Axiom Tracking

### 5.1 Axiom Count CI Check

**GitHub Actions job:**
```yaml
axiom-count-guard:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3
    
    - name: Check axiom count
      run: |
        CURRENT_AXIOMS=$(./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset | grep "Total axioms:" | awk '{print $3}')
        BASELINE_AXIOMS=$(cat audit/axiom-baseline.txt)
        
        if [[ $CURRENT_AXIOMS -gt $BASELINE_AXIOMS ]]; then
          echo "❌ Axiom count increased: $CURRENT_AXIOMS > $BASELINE_AXIOMS"
          echo "New axioms introduced! Review required."
          exit 1
        elif [[ $CURRENT_AXIOMS -lt $BASELINE_AXIOMS ]]; then
          echo "✅ Axiom count decreased: $CURRENT_AXIOMS < $BASELINE_AXIOMS"
          echo "Axioms eliminated! Update baseline:"
          echo "  echo $CURRENT_AXIOMS > audit/axiom-baseline.txt"
        else
          echo "✅ Axiom count unchanged: $CURRENT_AXIOMS"
        fi
    
    - name: Check for temporary axioms
      run: |
        TEMP_AXIOMS=$(./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset | grep "Temporary axioms:" | awk '{print $3}')
        
        if [[ $TEMP_AXIOMS -gt 0 ]]; then
          echo "⚠️  Warning: $TEMP_AXIOMS temporary axioms remaining"
          echo "Target: 0 temporary axioms"
          ./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset | grep -A 10 "Temporary axioms:"
        else
          echo "✅ No temporary axioms"
        fi
```

### 5.2 Axiom Diff Tool

**Script:** `scripts/axiom_diff.sh`

**Purpose:** Show axiom changes between commits

**Usage:**
```bash
./scripts/axiom_diff.sh HEAD~1 HEAD
```

**Output:**
```
Axiom Diff: HEAD~1 → HEAD
===========================

Added axioms (0):
  (none)

Removed axioms (1):
  - registration_eval_equiv_singleton_tail

Changed axioms (0):
  (none)

Total axiom count: 23 → 22 (↓1)
Temporary axioms: 2 → 1 (↓1)

Summary: ✅ Axiom count decreased (improvement)
```

### 5.3 Axiom Trend Tracking

**Script:** `scripts/track_axiom_trend.sh`

**Purpose:** Record axiom count over time, generate trend graph

**Data file:** `metrics/axiom_trend.csv`

**Format:**
```csv
date,commit,total_axioms,temp_axioms,permanent_axioms
2026-04-15,abc123,24,3,21
2026-04-18,def456,23,2,21
2026-04-22,e9f7b2,22,1,21
```

**Trend graph:** Generated via gnuplot or similar, shows axiom count decreasing over time.

## 6. Quarterly Axiom Review Process

### 6.1 Review Schedule

**Frequency:** Every 3 months (quarterly)

**Duration:** 2-4 hours per review

**Participants:** 2-3 verification engineers

**Deliverable:** Updated AXIOM_INVENTORY.md + action items for next quarter

### 6.2 Review Checklist

**Quarter: Q2 2026 (Apr-Jun)**
**Review date:** 2026-06-30
**Reviewers:** [Names]

**Checklist:**

- [ ] **Count verification:** Run `check_axioms.sh` on all CA modules, compare to inventory
- [ ] **Temporary axiom status:** Update elimination timeline for each temporary axiom
  - [ ] `registration_eval_equiv_functional_sim` - Target: Eliminate by end Q2
- [ ] **Recent eliminations:** Verify eliminated axioms haven't been reintroduced (regression check)
- [ ] **Documentation review:** Ensure all axioms have required documentation (template in §4.1)
- [ ] **External references:** Check if external audit reports or papers updated (Bulletproofs, Ristretto)
- [ ] **New research:** Search for recent academic work on Bulletproofs verification, Ristretto verification
  - If found, assess feasibility of integrating (could reduce Bulletproofs axioms from 5 → 3, etc.)
- [ ] **Trend analysis:** Review `axiom_trend.csv`, ensure count is decreasing or stable (not increasing)
- [ ] **Risk assessment:** Re-assess risk level for each axiom (Low/Medium/High)
  - Has usage changed? (e.g., Bulletproofs now used more heavily → higher risk if unverified)
- [ ] **Baseline update:** If axioms eliminated, update `audit/axiom-baseline.txt`
- [ ] **Next quarter goals:** Set target axiom count for next quarter
  - Q3 2026 target: 18 axioms (eliminate 4 Phase 6 temporary axioms)

**Output:** Meeting notes + updated AXIOM_INVENTORY.md committed to repo

### 6.3 Escalation Criteria

**Escalate to team lead if:**
1. Axiom count increased (new axioms introduced without justification)
2. Temporary axiom stuck >6 months (elimination stalled)
3. External dependency changed (e.g., external audit invalidated, new vulnerability found)
4. Risk assessment changed from Low → Medium/High

## 7. Axiom Elimination Roadmap

### 7.1 Short-term (Q2 2026, Apr-Jun)

**Goal:** Eliminate 1 temporary axiom (Registration)

| Axiom | Status | Effort | Assignee | Target Date |
|-------|--------|--------|----------|-------------|
| `registration_eval_equiv_functional_sim` | Temporary | 1-2 days | TBD | 2026-04-30 (Sprint 1 Week 1) |

**Acceptance:** Axiom count: 23 → 22, Temporary: 1 → 0

### 7.2 Medium-term (Q3 2026, Jul-Sep)

**Goal:** Eliminate 4 temporary axioms (Phase 6 composition)

| Axiom | Status | Effort | Assignee | Target Date |
|-------|--------|--------|----------|-------------|
| `normalization_eval_equiv_functional_sim` | Phase 6 | 3-5 hours | TBD | 2026-07-15 |
| `withdrawal_eval_equiv_functional_sim` | Phase 6 | 4-6 hours | TBD | 2026-07-30 |
| `rotation_eval_equiv_functional_sim` | Phase 6 | 4-6 hours | TBD | 2026-08-15 |
| `transfer_eval_equiv_functional_sim` | Phase 6 | 8-12 hours | TBD | 2026-08-31 |

**Acceptance:** Axiom count: 22 → 18, Temporary: 0 → 0

### 7.3 Long-term (2027+)

**Goal:** Investigate reducing permanent axioms (Bulletproofs, Ristretto)

**Opportunities:**

1. **Bulletproofs verification research:** Monitor academic literature for new verification techniques
   - If feasible proof found (e.g., using proof assistants): 6-12 month project to integrate
   - Potential reduction: 5 axioms → 0-2 axioms

2. **Ristretto255 formal verification:** Check if upstream libraries (e.g., fiat-crypto) have verified Ristretto
   - If available: Import upstream proofs (1-2 month integration)
   - Potential reduction: 4 axioms → 1-2 axioms

3. **Group theory from mathlib:** Some Edwards curve axioms might be provable from mathlib + curve25519 specs
   - Effort: 2-4 months per axiom
   - Potential reduction: 12 axioms → 8-10 axioms

**Decision:** Defer to 2027+ (after Phase 1-7 complete, axiom count stabilized at ~18)

### 7.4 Steady State Target

**Target axiom count (by end 2026):** 18 axioms

**Breakdown:**
- Group theory: 12 (permanent, mathlib)
- Ristretto: 4 (permanent, crypto assumption)
- Bulletproofs: 2 (reduced from 5 if feasible, else 5 permanent)
- CA-specific: 0 (all temporary axioms eliminated)

**Acceptance criteria for "done":**
- Zero temporary axioms
- All permanent axioms documented with external references
- Quarterly review process established
- Axiom count stable or decreasing (not increasing)

## 8. Risk Management

### 8.1 Risks of Accepting Axioms

**Risk 1: Axiom is unsound (introduces contradiction)**

**Likelihood:** Low (for well-documented crypto axioms), Medium (for temporary CA-specific axioms)

**Mitigation:**
- Require external references for permanent axioms (papers, audits)
- Time-box temporary axioms (eliminate within 1-2 sprints)
- Quarterly review to catch unsound axioms early

**Example:** If Bulletproofs axiom is unsound, entire CA security compromised.

**Mitigation:** External audit validates Bulletproofs implementation against paper.

---

**Risk 2: Axiom is too strong (over-constrains, makes valid code unverifiable)**

**Likelihood:** Medium

**Example:** Axiom claims `all_transfers_preserve_balance` but doesn't account for fees.

**Mitigation:**
- Write axioms as weak as possible (existential, not universal)
- Validate axioms against difftest (concrete cases must satisfy axioms)

---

**Risk 3: Axiom count grows over time (verification coverage decreases)**

**Likelihood:** Medium (without discipline)

**Mitigation:**
- CI check: Fail if axiom count increases
- Quarterly review: Track trend, investigate increases
- Require justification for every new axiom (documented in PR)

### 8.2 Risks of Eliminating Axioms

**Risk 1: Elimination introduces bugs (proof is wrong)**

**Likelihood:** Low (if properly tested)

**Mitigation:**
- After eliminating axiom, run full test suite (Lean build + difftest + MSL)
- Regression testing on downstream theorems
- Code review by 2+ engineers

**Example:** Eliminated `registration_eval_equiv_singleton_tail`, but new proof has a `sorry` → builds fail.

**Mitigation:** CI catches `sorry` before merge.

---

**Risk 2: Elimination effort exceeds budget (never finishes)**

**Likelihood:** Medium (for complex axioms like Bulletproofs)

**Mitigation:**
- Classify axioms by effort (Class A/B/C)
- Only attempt Class C (reasonable effort) axioms
- Accept Class A/B as permanent (don't waste months on infeasible eliminations)

## 9. Communication and Documentation

### 9.1 Axiom Status Dashboard

**Location:** `audit/AXIOM_STATUS.md` (auto-generated from inventory)

**Contents:**
```markdown
# CA Verification Axiom Status

**Last updated:** 2026-04-22 (auto-generated)

## Summary

Total axioms: **22**  
Permanent: **21** (91%)  
Temporary: **1** (9%)  

Target: **18** by end 2026 (eliminate 4 Phase 6 axioms)

## Temporary Axioms (Action Required)

| Axiom | Status | Assignee | Target Date | Days Overdue |
|-------|--------|----------|-------------|--------------|
| `registration_eval_equiv_functional_sim` | In Progress | TBD | 2026-04-30 | 0 |

## Recent Changes

- 2026-04-20: Eliminated `registration_eval_equiv_singleton_tail` (Phase 1 rebuild)
- 2026-04-15: Documented all permanent axioms with external references

## Trend

Axiom count over last 6 months:
- 2026-01: 25 axioms
- 2026-02: 24 axioms (eliminated 1)
- 2026-03: 24 axioms (no change)
- 2026-04: 22 axioms (eliminated 2) ← current

Trend: ↓ Decreasing (good)
```

### 9.2 PR Template for Axiom Changes

**When PR adds/removes axioms:**

```markdown
## Axiom Changes

- [ ] Axiom count changed: [Before → After]
- [ ] Justification: [Why new axiom needed OR how axiom was eliminated]
- [ ] Classification: [PERMANENT / TEMPORARY]
- [ ] Documentation: [Link to documentation added to AXIOM_INVENTORY.md]
- [ ] External reference: [Paper/audit/library citation if permanent]
- [ ] Elimination plan: [Timeline if temporary, N/A if permanent]
- [ ] Baseline updated: [Updated audit/axiom-baseline.txt if count decreased]
- [ ] Reviewers: [2+ engineers reviewed axiom change]

### Axiom Details

**Added axioms (X):**
1. `axiom_name` - [Justification]

**Removed axioms (Y):**
1. `axiom_name` - [Elimination method]

**Net change:** [+X -Y = Z]
```

## 10. Success Metrics

### 10.1 Key Performance Indicators (KPIs)

**KPI 1: Total axiom count**
- Current: 22
- Target (Q2 2026): 22 (maintain, eliminate 1 but add 0)
- Target (Q3 2026): 18 (eliminate 4 Phase 6 axioms)
- Target (End 2026): 18 (steady state)

**KPI 2: Temporary axiom count**
- Current: 1
- Target (Q2 2026): 0
- Target (Q3 2026): 0 (maintain)
- Target (End 2026): 0 (steady state)

**KPI 3: Axiom documentation coverage**
- Current: 100% (all 22 axioms documented)
- Target: 100% (maintain)

**KPI 4: Quarterly review adherence**
- Current: 100% (Q1 2026 completed on time)
- Target: 100% (complete every quarterly review on schedule)

### 10.2 Success Criteria (Phase 8 Complete)

- ✅ Zero temporary axioms
- ✅ All permanent axioms documented with external references
- ✅ Axiom count ≤18
- ✅ Quarterly review process established and adhered to
- ✅ CI axiom count guard in place (fails on increase)
- ✅ Trend: Decreasing or stable (not increasing)

## Summary

**Current state:** 22 axioms (21 permanent, 1 temporary)

**Short-term goal (Q2 2026):** Eliminate 1 temporary axiom (Registration) → 22 axioms (21 permanent, 0 temporary)

**Medium-term goal (Q3 2026):** Eliminate 4 temporary axioms (Phase 6) → 18 axioms (18 permanent, 0 temporary)

**Long-term goal (2027+):** Investigate reducing permanent axioms (Bulletproofs, Ristretto) if feasible research emerges

**Key actions:**
1. Complete Phase 1 singleton-some branch (1-2 days) → eliminate `registration_eval_equiv_functional_sim`
2. Complete Phase 6 PC-chaining proofs (3-4 weeks) → eliminate 4 composition axioms
3. Maintain quarterly review process → prevent axiom count growth
4. Document all axioms with external references → transparency for auditors

**Acceptance:** Phase 8 complete when temporary axiom count = 0 and process established.
