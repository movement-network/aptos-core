# Phase 6 Quick Start Guide

**For:** Anyone completing the remaining Phase 6 composition theorems  
**Prerequisites:** Lean 4 familiarity, completed Phase 4 (step theorems)  
**Current Status:** 11 sorries, 4 axioms, 64% blocked on array elaboration issue

---

## 1. Orientation (5 minutes)

### What is Phase 6?
Prove that bytecode execution (`eval → run`) is equivalent to functional simulation for each CA operation.

**Goal:** Eliminate all `sorry` placeholders in composition theorems across 5 operations.

### File Structure
```
lean/MovementFormal/Experimental/ConfidentialAsset/
├── Normalization/
│   ├── EvalEquiv.lean          ← 2 sorries (lines 624, 701)
│   └── Composition.lean        ← 1 sorry (line 43 - updated from 30)
├── Withdrawal/
│   └── EvalEquiv.lean          ← 5 sorries (lines 599, 647, 844, 889, 903)
├── Rotation/
│   └── EvalEquiv.lean          ← 1 sorry (line 507)
└── Transfer/
    └── EvalEquiv.lean          ← 2 sorries (lines 718, 776)
```

### Status Overview
| Category | Count | Blocking | Ready |
|----------|-------|----------|-------|
| Array Elaboration | 6 | YES | ❌ Research needed |
| Match Simplification | 3 | NO | ✅ Utilities ready |
| Unreachable Cases | 2 | NO | ✅ Utilities ready |

---

## 2. Validation (2 minutes)

Run these to confirm setup:

```bash
cd aptos-move/framework/formal

# Check sorry count
./scripts/validate_sorry_inventory.sh

# Track progress
./scripts/track_phase6_progress.sh

# Build CA modules
cd lean && lake build MovementFormal.Experimental.ConfidentialAsset
```

**Expected:** 11 sorries, full tree builds successfully

---

## 3. Quick Wins (1-2 hours)

**Target:** Withdrawal/EvalEquiv.lean lines 889, 903 (unreachable cases)

### Context
These are in impossible branches of pattern matching. Lean requires proof even though execution never reaches them.

### Approach
```lean
-- At line 889 (range oracle arity mismatch)
-- Currently: sorry
-- Replace with:
-- Goal is to show: (eval ...).dropMs = .error
-- Functional sim already returns .error for this case (line 385: | some (_ :: _, _) => .error)
-- Need axiom or proof that bytecode also produces .error

-- For now, document blocker:
sorry -- TODO: requires run_range_arity_mismatch_produces_error axiom
      -- Functional sim returns .error (line 385), need bytecode proof
```

**Status:** More complex than initially thought. These require axioms or deep bytecode reasoning.

**Estimated:** 4-6 hours each (not quick wins - reclassify)

**Skip for now** - move to Phase 2 instead.

---

## 4. Match Simplification (1-2 days)

**Target:** Withdrawal:844, Transfer:718

### 4.1 Withdrawal Line 844 (Match Reduction)

**Location:** `MovementFormal/Experimental/ConfidentialAsset/Withdrawal/EvalEquiv.lean:844`

**Goal:** Show functional sim reduces to `.error` when range oracle fails

**Blocker:** Let-bound variables `cs3`, `rangeArgs` don't match expanded expressions in goal

**Solution Pattern:**
```lean
-- Current context:
-- hrange : o.verifyRangeProof cs3 rangeArgs = none
-- where cs3, rangeArgs are let-bound in functional sim

-- Goal has expanded expressions:
-- o.verifyRangeProof (cs2.alloc proofFields[1]).fst [newBalRef, .immRef (...).snd]

-- Step 1: Unfold verifyWithdrawalBytecodeResult (line 742)
simp only [verifyWithdrawalBytecodeResult]

-- Step 2: Reduce match using hrange
-- The functional sim will match cs3 and rangeArgs by definition
-- Use MatchSimplification.withdrawal_range_pattern
rw [MatchSimplification.oracle_none_reduces]
· rfl  -- .error = .error
· exact hrange
```

**Files needed:**
- `import MovementFormal.MoveModel.MatchSimplification` (already exists)

**Estimated:** 25-35 lines, 2-4 hours

**Probability of success:** 70% (utilities ready, but may hit elaboration issues)

### 4.2 Transfer Line 718 (Triple Allocation Shape)

**Location:** `MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean:718`

**Goal:** Prove `transferBytecodeResult_success_shape` lemma

**Blocker:** 3-level nested allocation in match structure

**Solution Pattern:**
```lean
-- Use MatchSimplification.triple_alloc_let_unfold
-- Pattern: let (cs1, fid1) := cs0.alloc x
--          let (cs2, fid2) := cs1.alloc y
--          let (cs3, fid3) := cs2.alloc z
--          match oracle cs3 ... with ...

unfold transferBytecodeResult
have halloc := MatchSimplification.triple_alloc_let_unfold initMs.containers
  (proofFields[0]'...) (proofFields[1]'...) (proofFields[2]'...)
-- halloc now contains 6 equalities showing each cs_i and fid_i
-- equals the corresponding .fst/.snd projection

-- Use halloc to rewrite match structure
rw [halloc.1, halloc.2.1, ...]
-- Then match reduces based on oracle hypotheses
```

**Estimated:** 35-45 lines, 3-6 hours

**Probability of success:** 60% (more complex nesting)

---

## 5. Array Elaboration Blocker (1-3 weeks)

**Affects:** 7 of 11 sorries (64%)

### Symptom
```
error: Expected type must not contain free variables
```

### Root Causes
1. `have (cs, fid) := ...` - let-destructuring creates free variables
2. `locals := ([.u8 x, ...].map some).toArray` - array literals in theorem statements
3. Using witnesses from existential quantifiers in dependent contexts

### Examples
- Normalization/Composition.lean:43 - tried, failed (documented in commit 7dcac9375a)
- All main composition theorems (Normalization:701, Withdrawal:599/647, Rotation:507, Transfer:776)

### Research Paths

#### Option 1: Term-Mode Construction
Instead of tactic-mode `have (cs, fid) := ...`, build witnesses in term mode:

```lean
-- Instead of:
have (cs1, sigmaFid) := initMs.containers.alloc (proofFields[0]'...)

-- Try:
let alloc_result := initMs.containers.alloc (proofFields[0]'...)
show ... = match alloc_result with | (cs1, sigmaFid) => ...
```

**Resources:**
- Lean 4 Manual: "Term Mode vs Tactic Mode"
- Mathlib tactics: `refine`, `exact`, `apply` with explicit lambda

**Time:** 3-5 days to prototype

#### Option 2: Revert/Intro Patterns
Clean up free variables before type-checking:

```lean
revert cs1 sigmaFid  -- Remove from context
intro                 -- Reintroduce cleanly
-- Now cs1, sigmaFid should not be "free" in elaborator's view
```

**Resources:**
- Lean Zulip: search "free variable constraint"
- Similar issues in mathlib

**Time:** 1-2 days to test

#### Option 3: Alternative Proof Architecture
Avoid let-destructuring entirely:

```lean
-- Instead of proving:
-- theorem foo : eval ... = match verifyBytecodeResult ... with ...

-- Prove intermediate lemmas that don't require destructuring:
theorem eval_produces_returned_or_error : ∃ res, eval ... = res
theorem bytecode_result_welltyped : ...

-- Then compose
```

**Resources:**
- Look at how Registration/EvalEquivRebuild.lean handled similar issues
- May have factored proofs differently

**Time:** 1-2 weeks to refactor

#### Option 4: Meta-Programming (Last Resort)
Write custom elaborator that handles array literals specially:

```lean
elab "array_literal_helper" : tactic => ...
```

**Resources:**
- Lean 4 metaprogramming book
- Mathlib elaborator examples

**Time:** 2-3 weeks, requires deep Lean 4 knowledge

### Recommended First Step
Try **Option 2** (revert/intro) on Normalization/Composition.lean:43 since it's smallest.

If that fails, prototype **Option 1** (term-mode) on same file.

Document findings in `audit/ARRAY_ELABORATION_RESEARCH_LOG.md`.

---

## 6. Workflow

### Daily Development Loop
```bash
# 1. Pick a sorry
grep -n "sorry$" lean/MovementFormal/Experimental/ConfidentialAsset/Withdrawal/EvalEquiv.lean

# 2. Read context
# Use editor to navigate to line, read 20 lines before/after

# 3. Attempt proof
# Start with `sorry -- WIP: <your-approach>`
# Incrementally replace with actual proof

# 4. Build check
cd lean && lake build MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv

# 5. Track progress
cd .. && ./scripts/track_phase6_progress.sh

# 6. Commit when complete
git add -A
git commit -m "formal(phase6): complete Withdrawal line 844 match reduction

- Used MatchSimplification.oracle_none_reduces
- Proof: 28 lines
- Builds: ✅
- Remaining: 10 sorries"
```

### When Stuck
1. Check `audit/SORRY_CATEGORIZATION.md` for blocker type
2. If array elaboration: skip for now, document in research log
3. If match simplification: try MatchSimplification lemmas
4. If unsure: ask in Lean Zulip with minimal reproducible example

### Success Criteria
- `./scripts/validate_sorry_inventory.sh` shows decreasing count
- `lake build MovementFormal.Experimental.ConfidentialAsset` succeeds
- Proof is <100 lines (if longer, consider factoring helper lemma)

---

## 7. Utility Modules (Created 2026-04-23)

### UnreachableLemmas.lean
```lean
import MovementFormal.MoveModel.UnreachableLemmas

-- For impossible pattern match branches
-- Usage: oracle_arity_mismatch_unreachable
```

### MatchSimplification.lean
```lean
import MovementFormal.MoveModel.MatchSimplification

-- Key lemmas:
-- alloc_let_unfold: unfold single allocation let-binding
-- triple_alloc_let_unfold: unfold 3 nested allocations
-- oracle_none_reduces: rewrite match when oracle = none
-- withdrawal_range_pattern: specific pattern for Withdrawal:844
```

### ProofPatterns.lean (from earlier session)
```lean
import MovementFormal.MoveModel.ProofPatterns

-- Reusable tactics and lemmas:
-- fuel_ge_succ_of_ge_n: fuel arithmetic
-- frame_update_pc_preserves_locals: frame field preservation
-- match_some_empty_reduces: oracle match reduction
```

### ArrayLemmas.lean (from earlier session)
```lean
import MovementFormal.MoveModel.ArrayLemmas

-- containers_alloc_proof_irrel: proof irrelevance for container allocation
-- Useful for lines like Withdrawal:779, 828, 832
-- (but those lines are NOT actual sorries - they're in refine applications)
```

---

## 8. Common Pitfalls

### ❌ Pitfall 1: Counting Sorries in Comments
```bash
# WRONG: grep "sorry" includes comments
grep -r "sorry" *.lean

# RIGHT: only count actual sorry statements
grep -n "sorry$" *.lean
```

**Why:** Many files have `sorry` in comments explaining strategy

### ❌ Pitfall 2: Attempting Array-Blocked Sorries First
**Don't start with:**
- Normalization/Composition.lean:43
- Any main composition theorem (lines with "eval_equiv_functional_sim")

**These require solving the blocker first.**

### ❌ Pitfall 3: Overly Optimistic "Unreachable" Cases
Lines 889, 903 marked "quick wins" are actually hard - they need axioms about bytecode behavior in impossible cases.

**Better quick wins:** Focus on match simplification where utilities exist.

### ❌ Pitfall 4: Not Building Incrementally
```lean
-- WRONG: Write 50-line proof, then build
sorry -- TODO: fill this in later
-- ... 50 lines of uncompiled code ...

-- RIGHT: Build after each 5-10 line segment
sorry -- WIP: step 1 complete, builds ✓
-- Incrementally replace sorry with proved segments
```

---

## 9. Getting Help

### In-Repository Resources
1. `audit/SORRY_CATEGORIZATION.md` - full sorry inventory
2. `audit/PHASE_6_SYSTEMATIC_COMPLETION_PLAN.md` - original roadmap
3. `SESSION_DELIVERABLES_2026_04_23.md` - previous session notes
4. Example proofs in `lean/MovementFormal/Examples/`

### External Resources
1. **Lean Zulip:** https://leanprover.zulipchat.com
   - Search: "Expected type must not contain free variables"
   - Post minimal reproducible examples
2. **Lean 4 Manual:** Chapter on "Dependent Type Theory"
3. **Mathlib Docs:** Search for similar pattern match proofs
4. **Registration/EvalEquivRebuild.lean:** Completed example (197 theorems, zero sorry)

### Team Contacts
- See `audit/AUDITOR_GUIDE.md` for verification workflow
- Git blame recent commits for context on past decisions

---

## 10. Success Metrics

### Phase 6 Complete When:
- ✅ `./scripts/validate_sorry_inventory.sh` shows 0 sorries
- ✅ `./scripts/check_axioms.sh` shows 0 phase-6-specific axioms
- ✅ `lake build MovementFormal.Experimental.ConfidentialAsset` < 5 seconds
- ✅ All 5 operations have proved `*_eval_equiv_functional_sim` theorems

### Intermediate Milestones:
- **25% complete:** 3 sorries removed (match simplification done)
- **50% complete:** 6 sorries removed (half array-blocked resolved)
- **75% complete:** 9 sorries removed (3 main compositions proved)
- **100% complete:** All 11 sorries removed

---

## 11. Timeline Estimates

Based on `audit/SORRY_CATEGORIZATION.md`:

| Milestone | Sorries Removed | Estimated Time | Prerequisites |
|-----------|----------------|----------------|---------------|
| Match simplification done | 3 | 1-2 days | Utilities exist ✅ |
| Array blocker solved | 0 (unblocks 7) | 1-3 weeks | Deep research |
| First main composition | 1 | 1 week | Array blocker solved |
| All main compositions | 7 | 4-8 weeks | Array blocker + helpers |
| **Total Phase 6** | 11 | **5-11 weeks** | Full roadmap |

**Critical path:** Array elaboration blocker resolution

---

## 12. Next Session Checklist

Before starting work:
- [ ] Run `./scripts/track_phase6_progress.sh` to see current status
- [ ] Check `git log --oneline -5` for recent changes
- [ ] Read any new `SESSION_DELIVERABLES_*.md` files
- [ ] Verify `lake build` succeeds before making changes

After completing sorries:
- [ ] Update `audit/SORRY_CATEGORIZATION.md` (move to "Completed" section)
- [ ] Run validation: `./scripts/validate_sorry_inventory.sh`
- [ ] Create commit with metrics in message (use previous commits as template)
- [ ] Update `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` Phase 6 status if milestone reached

---

**Last Updated:** 2026-04-23  
**Document Status:** Living guide - update as work progresses  
**See Also:** `audit/COMPLETION_ROADMAP.md` for higher-level planning
