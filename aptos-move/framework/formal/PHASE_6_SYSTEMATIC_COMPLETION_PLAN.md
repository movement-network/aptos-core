# Phase 6 Systematic Completion Plan

**Status:** 17 sorries + 3 axioms remaining across 5 operations  
**Goal:** Complete all Phase 6 composition theorems  
**Approach:** Bottom-up, starting with helpers

---

## Current State (2026-04-23)

### Sorry Count by File
- Registration/EvalEquiv.lean: 0 sorries ✅ COMPLETE
- Normalization/EvalEquiv.lean: 2 sorries (lines 624, 701)
- Rotation/EvalEquiv.lean: 2 sorries (line 507 + composition)
- Transfer/EvalEquiv.lean: 3 sorries (lines 718, 776 + composition)
- Withdrawal/EvalEquiv.lean: 16 sorries (composition + helpers)
- Normalization/Composition.lean: 1 sorry (line 30)

### Axiom Count
- `norm_run_pc0_to_pc5`: PC-chaining helper (array blocker)
- `run_withdrawal_through_pc2`: PC-chaining helper (array blocker)
- `registration_eval_equiv_functional_sim`: Main theorem (to be proved)

---

## Completion Strategy

### Phase A: Quick Wins (1-2 hours)
Target: Eliminate unreachable/trivial sorries

1. **Unreachable match cases** (Withdrawal lines 879, 892)
   - Status: Attempted, keeping as sorry with comments
   - Effort: Low priority, not blocking

2. **Struct equality proofs** 
   - Pattern: `{ ms with containers := cs } = { ms with containers := cs, globals := ms.globals }`
   - Solution: Prove `ms.globals = (withContainers ms cs).globals`
   - Files: Withdrawal, Transfer, Rotation
   - Estimated: 30 min total

3. **Match reduction proofs**
   - Pattern: Unfold functional sim, rewrite with hypotheses, simplify
   - Files: Withdrawal line 873, Transfer line 873
   - Estimated: 1 hour total

### Phase B: Helper Axioms (3-5 days)
Target: Convert axioms to theorems

1. **norm_run_pc0_to_pc5** (Normalization)
   - Blocker: "Expected type must not contain free variables"
   - Requires: Array elaboration workaround or term-mode construction
   - Research: Lean 4 array tactics, explicit witnesses
   - Estimated: 2-3 days of focused work

2. **run_withdrawal_through_pc2** (Withdrawal)
   - Same blocker as above
   - Can reuse patterns from Normalization
   - Estimated: 1-2 days after Normalization pattern established

3. **PC 5-8 helpers** (Normalization, Withdrawal)
   - Once PC 0-5 solved, these follow similar pattern
   - Estimated: 1 day

### Phase C: Main Composition Theorems (1-2 weeks)
Target: Complete eval↔functional-sim equivalence

**Dependencies:** Phase B must complete first

1. **Normalization** (line 701)
   - Requires: norm_run_pc0_to_pc5, norm_run_pc5_to_pc8
   - Pattern: Chain helpers + oracle case splits + shape lemmas
   - Estimated: 150-200 lines, 2-3 days

2. **Rotation** (line 507)
   - Similar structure to Normalization (15 PCs vs 14)
   - Can reuse patterns
   - Estimated: 200-250 lines, 2-3 days

3. **Transfer** (lines 718, 776)
   - Most complex: 24 PCs, 3 sub-calls
   - Requires: Triple oracle nesting pattern
   - Estimated: 400-450 lines, 4-5 days

4. **Withdrawal** (multiple)
   - Depends on run_withdrawal_through_pc2 axiom
   - 15-PC chain + dual oracle splits
   - Estimated: 300-400 lines, 3-4 days

5. **Composition.lean theorems**
   - Thin wrappers once main theorems complete
   - Estimated: 1 day total for all 4 operations

---

## Blockers & Workarounds

### Critical Blocker: Array Elaboration
**Issue:** Cannot pass `locals := ([.u8 x, ...].map some).toArray` to step theorems  
**Error:** "Expected type must not contain free variables"

**Attempted Solutions:**
- Direct array construction: Failed
- Existential witnesses: Partial success
- Axiom helpers: Current workaround

**Research Needed:**
- Lean 4 array tactics documentation
- Term-mode proof construction patterns
- Alternative frame representations

**Potential Workarounds:**
1. Refactor step theorems to accept lists instead of arrays
2. Use explicit witness construction with `⟨locals, h_props⟩` pattern
3. Build frames incrementally via repeated single-PC steps
4. Investigate Lean 4 meta-programming for custom elaborators

---

## Timeline Estimate

**Optimistic (full-time, experienced Lean developer):**
- Phase A: 2 hours
- Phase B: 1 week  
- Phase C: 2 weeks
- **Total: 3 weeks**

**Realistic (part-time, learning curve):**
- Phase A: 1 day
- Phase B: 2-3 weeks
- Phase C: 3-4 weeks  
- **Total: 6-8 weeks**

**Conservative (includes research time):**
- Phase A: 2 days
- Phase B: 4 weeks (includes array blocker research)
- Phase C: 4-5 weeks
- **Total: 10-12 weeks**

---

## Success Metrics

- [ ] All 17 sorries removed
- [ ] All 3 axioms converted to theorems (or documented as permanent)
- [ ] Full CA Lean tree builds with zero sorry warnings
- [ ] Phase 6 row in unified plan updated to ✅ COMPLETE
- [ ] Difftest hygiene check passes (no sorry detection)
- [ ] `#print axioms` output matches baseline (only crypto axioms)

---

## Next Immediate Steps

1. **Today:** Attempt Phase A quick wins (struct equality proofs)
2. **This week:** Research Lean 4 array elaboration workarounds
3. **Next week:** Prototype term-mode construction for PC-chain helpers
4. **Month 1:** Complete Phase B (convert axioms)
5. **Month 2:** Complete Phase C (main composition theorems)

---

**Key Insight:** The array elaboration blocker is the main obstacle. Once solved for one operation, the pattern applies to all others. Priority should be deep research into this specific Lean 4 issue rather than attempting proofs blindly.
