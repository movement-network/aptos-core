# Sorry Categorization - Confidential Assets Phase 6

**Generated:** 2026-04-23  
**Purpose:** Systematic categorization of all `sorry` placeholders to guide completion work

## Summary Statistics

| Operation | Total Sorries | Array Blocked | Match Simplify | Unreachable |
|-----------|---------------|---------------|----------------|-------------|
| Normalization | 3 | 2 | 1 | 0 |
| Withdrawal | 5 | 2 | 1 | 2 |
| Rotation | 1 | 1 | 0 | 0 |
| Transfer | 2 | 1 | 1 | 0 |
| **TOTAL** | **11** | **6** | **3** | **2** |

## Blocker Type Definitions

### 1. Array Elaboration (HARD BLOCKER)
**Count:** 6  
**Symptom:** "Expected type must not contain free variables"  
**Root Cause:** Passing arrays with literal values in by-tactic context, or having free variables from let-destructuring  
**Examples:** `locals := ([.u8 x, ...].map some).toArray`, `have (cs, fid) := ...`  
**Resolution:** Requires deep Lean 4 research or architectural changes  
**Files Blocked:**
- Normalization/Composition.lean:30 - error case (tried, failed - free variables from match destructuring)
- Normalization/EvalEquiv.lean:624 - shape lemma `norm_blockB_success_shape`
- Normalization/EvalEquiv.lean:701 - main composition theorem
- Withdrawal/EvalEquiv.lean:599 - `run_sigma_fail_produces_error` helper
- Withdrawal/EvalEquiv.lean:647 - `run_to_range_fail_produces_error` helper
- Rotation/EvalEquiv.lean:507 - main composition theorem
- Transfer/EvalEquiv.lean:776 - main composition theorem (commented as sorry)

### 2. Match Tree Simplification (MEDIUM)
**Count:** 3  
**Difficulty:** 20-40 lines each  
**Pattern:** Unfold let-bindings, rewrite with hypotheses, prove structural equality  
**Approach:** `rw [hsigma, hrange]`, `unfold`, `simp`, `rfl`  
**Files:**
- Withdrawal/EvalEquiv.lean:844 - let-bound `cs3`, `rangeArgs` (goal is to show match reduces to `.error`)
- Transfer/EvalEquiv.lean:718 - triple oracle allocation (shape lemma, commented as sorry)

### 3. Unreachable Cases (LOW PRIORITY)
**Count:** 2  
**Difficulty:** 5-10 lines each (once goal type known)  
**Pattern:** Overlapping pattern matches create unreachable branches  
**Approach:** Provide any value of goal type (often `.error`)  
**Files:**
- Withdrawal/EvalEquiv.lean:889 - arity mismatch (impossible, type system prevents)
- Withdrawal/EvalEquiv.lean:903 - arity mismatch (impossible, type system prevents)

## Detailed Sorry Inventory

### Normalization (3 sorries)

#### Composition.lean
1. **Line 30** - `normalization_eval_error_sigmaFails`
   - **Type:** Array Elaboration
   - **Description:** Prove eval returns `.error` when sigma verifier fails
   - **Blocker:** `have (sigmaCs, sigmaFid) := ...` creates free variables
   - **Structure:** Chain PCs 0→5→8, apply `step_normalization_pc8_none`
   - **Attempted:** 2026-04-23, failed on free variable constraint
   - **Estimated Effort:** 40-60 lines post-blocker resolution

#### EvalEquiv.lean
2. **Line 624** - `norm_blockB_success_shape`
   - **Type:** Array Elaboration (shape lemma with match)
   - **Description:** Shape lemma for blockB success case
   - **Blocker:** Match tree with oracle outcomes containing free variables
   - **Dependencies:** None (standalone shape lemma)
   - **Estimated Effort:** 30-40 lines post-blocker

3. **Line 701** - `normalization_eval_equiv_functional_sim`
   - **Type:** Array Elaboration (main composition)
   - **Description:** Top-level eval↔functional-sim equivalence
   - **Blocker:** Requires `norm_run_pc0_to_pc5` helper + array elaboration fix
   - **Structure:** Chain PCs 0-13, split on 2 oracles, apply shape lemmas
   - **Estimated Effort:** 150-200 lines post-helpers

### Withdrawal (5 sorries)

#### EvalEquiv.lean
4. **Line 599** - Inside `run_sigma_fail_produces_error`
   - **Type:** Array Elaboration
   - **Description:** PC-chaining helper for sigma failure path
   - **Blocker:** Array literal in `locals :=` field
   - **Estimated Effort:** 60-80 lines (architecture change or elaborator research needed)

5. **Line 647** - Inside `run_to_range_fail_produces_error`
   - **Type:** Array Elaboration
   - **Description:** PC-chaining helper for range failure after sigma success
   - **Blocker:** Same array literal issue as line 599
   - **Estimated Effort:** 80-100 lines (architecture change needed)

6. **Line 844** - Inside `withdrawal_eval_equiv_functional_sim`
   - **Type:** Match Simplification
   - **Description:** Show functional sim reduces to `.error` using `hrange`
   - **Challenge:** Let-bound `cs3`, `rangeArgs` need unfolding to match hypothesis
   - **Approach:** Use `MatchSimplification.withdrawal_range_pattern` lemma
   - **Estimated Effort:** 25-35 lines (can attempt with new utilities)

7. **Line 889** - Arity mismatch (unreachable)
   - **Type:** Unreachable
   - **Description:** Range oracle returned non-empty (type system prevents)
   - **Priority:** LOW - impossible case
   - **Solution:** Use `UnreachableLemmas.oracle_arity_mismatch_unreachable`
   - **Estimated Effort:** 5-8 lines (ready to attempt)

8. **Line 903** - Arity mismatch (unreachable)
   - **Type:** Unreachable
   - **Description:** Sigma oracle returned non-empty (impossible)
   - **Priority:** LOW
   - **Solution:** Use `UnreachableLemmas.oracle_arity_mismatch_unreachable`
   - **Estimated Effort:** 5-8 lines (ready to attempt)

### Rotation (1 sorry)

#### EvalEquiv.lean
9. **Line 507** - `rotation_eval_equiv_functional_sim`
   - **Type:** Array Elaboration (main composition)
   - **Description:** Top-level eval↔functional-sim equivalence
   - **Structure:** Chain PCs 0-14, split on 2 oracles, connect to shape lemmas
   - **Estimated Effort:** 200-250 lines post-blocker

### Transfer (2 sorries)

#### EvalEquiv.lean
10. **Line 718** - `transferBytecodeResult_success_shape`
    - **Type:** Match Simplification  
    - **Description:** Shape lemma for triple oracle success
    - **Challenge:** 3-level allocation nesting in match structure
    - **Approach:** Use `MatchSimplification.triple_alloc_let_unfold`
    - **Estimated Effort:** 35-45 lines (can attempt with new utilities)

11. **Line 776** - `transfer_eval_equiv_functional_sim`
    - **Type:** Array Elaboration (main composition - most complex)
    - **Description:** Top-level eval↔functional-sim equivalence
    - **Structure:** Chain PCs 0-23, split on 3 oracles at PCs 14, 18, 22
    - **Estimated Effort:** 300-450 lines post-blocker (longest composition)

## Completion Strategy

### Phase 1: Quick Wins (Ready Now)
**Target:** 2 unreachable cases  
**Time:** 1-2 hours  
**Dependencies:** UnreachableLemmas module (✅ created 2026-04-23)  
**Files:** Withdrawal/EvalEquiv.lean (889, 903)  
**Status:** Ready to attempt

### Phase 2: Match Simplification
**Target:** 2 shape/match lemmas  
**Time:** 1-2 days  
**Dependencies:** MatchSimplification module (✅ created 2026-04-23)  
**Files:** 
- Withdrawal/EvalEquiv.lean:844 (25-35 lines) - use `withdrawal_range_pattern`
- Transfer/EvalEquiv.lean:718 (35-45 lines) - use `triple_alloc_let_unfold`  
**Status:** Can attempt with new utilities

### Phase 3: Array Elaboration Research (CRITICAL BLOCKER)
**Target:** Solve or work around the core blocker  
**Time:** 1-3 weeks (research-heavy)  
**Impact:** Unblocks 7 of 11 remaining sorries (64%)  
**Approaches:**
1. Term-mode witness construction
2. Alternative proof architecture (avoid let-destructuring with free variables)
3. Lean 4 elaborator workarounds (revert/intro patterns, explicit witnesses)
4. Custom elaborators (meta-programming)
5. Factor out helpers that don't involve array elaboration
**Status:** Attempted Normalization/Composition.lean:30 (2026-04-23), hit blocker

### Phase 4: Main Compositions
**Target:** 4 top-level theorems + 1 shape lemma  
**Time:** 4-8 weeks post-Phase 3  
**Dependencies:** Must solve array elaboration blocker first  
**Files:**
- Normalization/EvalEquiv.lean:624 (shape lemma, 30-40 lines)
- Normalization/EvalEquiv.lean:701 (main composition, 150-200 lines)
- Withdrawal/EvalEquiv.lean:599, 647 (PC-chain helpers, 60-100 lines each)
- Rotation/EvalEquiv.lean:507 (main composition, 200-250 lines)
- Transfer/EvalEquiv.lean:776 (main composition, 300-450 lines)
- Total: ~900-1200 lines of PC-chaining proofs

## Total Effort Estimate

- **Phase 1:** 1-2 hours → 2 sorries removed (18% of total)
- **Phase 2:** 1-2 days → 2 sorries removed (18% of total)
- **Phase 3:** 1-3 weeks → Core blocker resolution
- **Phase 4:** 4-8 weeks → 7 sorries removed (64% of total - all array-blocked items)

**Total:** 5-11 weeks for complete Phase 6 closure

**Critical Path:** Array elaboration blocker gates 7 of 11 sorries (64%)

---

## Appendix: Grep Commands

```bash
# Count sorries by operation
for op in Registration Normalization Withdrawal Transfer Rotation; do
  count=$(grep -n "sorry$" MovementFormal/Experimental/ConfidentialAsset/$op/*.lean 2>/dev/null | wc -l)
  echo "$op: $count"
done

# Find array elaboration instances
grep -rn "Expected type must not contain free variables" lean/

# List all sorry locations
grep -rn "sorry$" MovementFormal/Experimental/ConfidentialAsset --include="*.lean"
```

## Maintenance

**Update this document when:**
1. Any sorry is completed (move to "Completed" section)
2. New blocker types discovered
3. Effort estimates change based on actual completion data
4. New workarounds found for array elaboration issue

**Last Updated:** 2026-04-23 (initial creation)
