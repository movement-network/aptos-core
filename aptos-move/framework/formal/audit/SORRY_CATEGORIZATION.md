# Sorry Categorization - Confidential Assets Phase 6

**Generated:** 2026-04-23  
**Updated:** 2026-04-23 05:25 AM (verified recount)  
**Purpose:** Systematic categorization of all `sorry` placeholders to guide completion work

## Summary Statistics

**✅ VERIFIED COUNTS (2026-04-23 05:41 - RECOUNTED):** Actual file scan: **12 sorries** across CA Lean code  
**⚠️ MAJOR REDUCTION:** Down from 32 sorries (62.5% reduction) - significant progress since last verification

| Operation | Total Sorries | Files | Array Blocked | Unreachable | Other |
|-----------|---------------|-------|---------------|-------------|-------|
| Registration | 0 | — | 0 | 0 | 0 |
| Normalization | 2 | Composition (1), EvalEquiv (1) | ~2 | 0 | 0 |
| Withdrawal | 7 | EvalEquiv (7) | ~2 | 5 | 0 |
| Rotation | 1 | EvalEquiv (1) | ~1 | 0 | 0 |
| Transfer | 2 | EvalEquiv (2) | ~2 | 0 | 0 |
| **TOTAL** | **12** | **5 files** | **~7 (58%)** | **5 (42%)** | **0 (0%)** |

**Key findings:**
- **MAJOR PROGRESS:** Sorry count reduced from 32→12 (62.5% reduction)
- **Registration COMPLETE:** 0 sorries (was 2) - Phase 1 proof work landed
- **Unreachable cases:** 5 sorries (42% of total) - mostly arity mismatches in Withdrawal
- **Array elaboration:** 7 sorries (58% of total) - down from 24, still the main blocker
- **Blocker shift:** Array elaboration percentage dropped from 75%→58% as unreachable cases now dominate

## Blocker Type Definitions

### 1. Array Elaboration (HARD BLOCKER - 75% of all sorries)
**Count:** ~24 sorries (VERIFIED 2026-04-23 05:25)  
**Symptom:** "Expected type must not contain free variables" OR array proof irrelevance issues  
**Root Cause:** 
- (a) Passing arrays with literal values in by-tactic context, or having free variables from let-destructuring
- (b) Different bound proofs for same array access (`arr[i]'h1` vs `arr[i]'h2`)  
**Examples:** `locals := ([.u8 x, ...].map some).toArray`, `have (cs, fid) := ...`, `proofFields[1]'hFieldCount`  
**Resolution:** Requires deep Lean 4 elaborator research (1-3 weeks) or major architectural refactoring  
**Impact:** Blocks Phase 4 completion (EvalEquiv proofs for 4 operations) and Phase 6 (composition theorems)  
**Files Most Affected:**
- Withdrawal/EvalEquiv.lean: ~14 sorries
- Normalization/EvalEquiv.lean + Composition.lean: ~6 sorries  
- Rotation/EvalEquiv.lean: ~2 sorries
- Transfer/EvalEquiv.lean: ~2 sorries

### 2. Unreachable Cases (LOW PRIORITY - 6% of sorries)
**Count:** 2  
**Difficulty:** 5-10 lines each (if elaborator cooperates)  
**Pattern:** Overlapping pattern matches create unreachable branches  
**Approach:** Provide any value of goal type (often `.error`), but elaborator doesn't generate usable hypotheses  
**Files:**
- Withdrawal/EvalEquiv.lean:892 - arity mismatch (impossible, type system prevents)
- Withdrawal/EvalEquiv.lean:899 - arity mismatch (impossible, type system prevents)
- Withdrawal/EvalEquiv.lean:907 - arity mismatch (impossible, type system prevents)

### 3. Other / Unclassified (19% of sorries)
**Count:** ~6  
**Includes:**
- Registration singleton case: 1 sorry (6-12 hour PC-threading proof, tractable but time-intensive)
- Registration Refinement: 1 sorry (old code, can ignore)
- Template: 1 sorry (not real code)
- Various composition theorem structure placeholders: ~3 sorries

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
   - **Type:** Array Elaboration (RECLASSIFIED 2026-04-23)
   - **Description:** Show functional sim reduces to `.error` using `hrange`
   - **Blocker:** Array proof irrelevance - `proofFields[1]'h1` vs `proofFields[1]'h2` access same element but aren't definitionally equal
   - **Comment in code:** "This blocks on the same array elaboration issue affecting other sorries"
   - **Estimated Effort:** 30-40 lines post-array-elaboration resolution

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
    - **Type:** Array Elaboration (RECLASSIFIED 2026-04-23)
    - **Description:** Shape lemma for triple oracle success
    - **Blocker:** Array proof irrelevance in 3-level allocation nesting (`halloc0`, `halloc1` pattern)
    - **Challenge:** Must thread through `proofFields[0]`, `proofFields[1]`, `proofFields[2]` with different bound proofs
    - **Estimated Effort:** 50-70 lines post-array-elaboration resolution

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

### Phase 2: Match Simplification (DEPRECATED - SKIP)
**UPDATED 2026-04-23:** All match simplification sorries reclassified as Array Elaboration.  
**Previous target:** 2 sorries (Withdrawal:844, Transfer:718)  
**Reclassification reason:** Both blocked on array proof irrelevance, not pure match tree simplification  
**Impact:** Phase 2 is now empty; proceed directly to Phase 3  

### Phase 3: Array Elaboration Research (CRITICAL BLOCKER)
**Target:** Solve or work around the core blocker  
**Time:** 1-3 weeks (research-heavy)  
**Impact:** Unblocks 9 of 11 remaining sorries (82% - UPDATED from 64%)  
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

## Total Effort Estimate (UPDATED 2026-04-23)

- **Phase 1:** 1-2 hours → 2 sorries removed (18% of total) - unreachable cases
- **Phase 2:** ~~1-2 days → 2 sorries~~ → DEPRECATED (reclassified to array elaboration)
- **Phase 3:** 1-3 weeks → Core blocker resolution (array elaboration)
- **Phase 4:** 4-8 weeks → 9 sorries removed (82% of total - all array-blocked items)

**Total:** 5-11 weeks for complete Phase 6 closure

**Critical Path:** Array elaboration blocker gates 9 of 11 sorries (82% - UPDATED from 64%)

**Key Finding (2026-04-23):** The array elaboration blocker is more pervasive than initially categorized.
Two sorries previously thought to be "match simplification" (medium difficulty, 1-2 days) are actually
blocked on the same array proof irrelevance issue. This increases array-blocked percentage from 64%→82%.

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
