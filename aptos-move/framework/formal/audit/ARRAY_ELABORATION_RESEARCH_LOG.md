# Array Elaboration Blocker - Research Log

**Critical Issue:** "Expected type must not contain free variables" error  
**Impact:** Blocks 8 of 11 Phase 6 sorries (73% of remaining work)  
**Status:** Active research needed  
**Timeline:** 1-3 weeks estimated for resolution

---

## Problem Statement

When proving composition theorems in Phase 6, we frequently need to:
1. Let-destructure container allocation results: `let (cs1, fid1) := initMs.containers.alloc (proofFields[0]'h1)`
2. Later prove equality with expressions using different bound proofs: `alloc (proofFields[0]'h2) = (cs1, fid1)`

Lean's elaborator rejects this with:
```
error: Expected type must not contain free variables
```

### Root Causes
1. **Proof irrelevance mismatch:** `proofFields[0]'h1 ≠ proofFields[0]'h2` definitionally (different proofs)
2. **Free variables from destructuring:** `cs1`, `fid1` are seen as "free" when they come from match/let
3. **Dependent type propagation:** The bound proofs propagate through function calls and matches

---

## Affected Sorries

| File | Line | Type | Blocker Details |
|------|------|------|----------------|
| Normalization/Composition.lean | 43 | Error case theorem | `have (sigmaCs, sigmaFid) := ...` creates free variables |
| Normalization/EvalEquiv.lean | 624 | Shape lemma | Match tree with oracle outcomes |
| Normalization/EvalEquiv.lean | 701 | Main composition | Requires helper axioms (also array-blocked) |
| Withdrawal/EvalEquiv.lean | 599 | PC-chain helper | Array literals in locals field |
| Withdrawal/EvalEquiv.lean | 647 | PC-chain helper | Same as 599 |
| Withdrawal/EvalEquiv.lean | 844 | Match reduction | Let-bound cs3/rangeArgs don't match goal (attempted 2026-04-23) |
| Rotation/EvalEquiv.lean | 507 | Main composition | Similar pattern to Normalization:701 |
| Transfer/EvalEquiv.lean | 776 | Main composition | Most complex - 3-level allocation nesting |

**Total:** 8 sorries blocked (73% of Phase 6 work)

---

## Research Attempts

### Attempt 1: Normalization/Composition.lean:43 (2026-04-23)

**Goal:** Prove `normalization_eval_error_sigmaFails` - eval returns error when sigma verifier always fails

**Approach:**
```lean
-- Chain PCs 0→5→8 using helper axioms
have ⟨locals5, h0to5⟩ := norm_run_pc0_to_pc5 ...
rw [h0to5]

have h5to8 := norm_run_pc5_to_pc8 ...
rw [h5to8]

-- At PC 8: destructure allocation result
have (sigmaCs, sigmaFid) := MachineState.empty.containers.alloc (proofFields[0]'(by omega))

-- Apply step theorem
have hstep_err := step_normalization_pc8_none ... (hSigmaFail sigmaCs [...])
```

**Error:**
```
Expected type must not contain free variables
  sigmaCs, sigmaFid
```

**Why it failed:** The `have (sigmaCs, sigmaFid) := ...` creates free variables in the context. When we try to use them in `hSigmaFail sigmaCs [...]`, the elaborator sees them as free.

**Time spent:** 45 minutes  
**Status:** Documented, reverted to sorry

### Attempt 2: Withdrawal/EvalEquiv.lean:844 (2026-04-23)

**Goal:** Show functional sim match reduces to `.error` using `hrange` hypothesis

**Approach 1: Direct rewrite**
```lean
rw [hrange]  -- hrange : o.verifyRangeProof cs3 rangeArgs = none
```
**Error:** Pattern not found in goal (goal has different bound proof)

**Approach 2: Prove oracle expressions equal**
```lean
have h_oracle_eq : o.verifyRangeProof (cs2.alloc (proofFields[1]'hFieldCount)).fst [...] =
                   o.verifyRangeProof cs3 rangeArgs := by
  rfl
```
**Error:** Not definitionally equal (different bound proofs)

**Why it failed:** 
- Goal has: `(cs2.alloc proofFields[1]).fst` (bound proof inferred)
- Let-binding has: `cs2.alloc (proofFields[1]'hFieldCount)` (explicit bound)
- These are NOT definitionally equal in Lean

**Time spent:** 30 minutes  
**Status:** Documented, reverted to sorry

---

## Solution Paths

### Path 1: Revert/Intro Pattern ⭐ RECOMMENDED FIRST TRY

**Estimated Time:** 1-2 days  
**Difficulty:** Medium  
**Success Probability:** 40-60%

**Approach:**
```lean
-- Before creating free variables:
revert cs1 fid1
intro
-- Now cs1, fid1 are not "free" in elaborator's view
-- Continue proof...
```

**Pros:**
- Quick to test
- No architecture changes
- Uses standard Lean tactics

**Cons:**
- May not work if free variables are deeply nested
- Not guaranteed to solve all cases

**Next Steps:**
1. Try on Normalization/Composition.lean:43 (smallest case)
2. Document whether elaborator still complains
3. If works, apply pattern to other sorries

### Path 2: Term-Mode Construction

**Estimated Time:** 3-5 days  
**Difficulty:** High  
**Success Probability:** 60-70%

**Approach:**
```lean
-- Instead of tactic-mode have:
show ... = match alloc_result with | (cs1, fid1) => ...
where
  alloc_result := initMs.containers.alloc (proofFields[0]'...)
```

**Pros:**
- Avoids tactic mode elaboration issues
- More explicit control over witness construction
- Mathlib uses this pattern successfully

**Cons:**
- Requires rewriting proofs in term mode
- Steeper learning curve
- May be verbose

**Resources:**
- Lean 4 Manual: Chapter on "Term Mode vs Tactic Mode"
- Mathlib: search for term-mode match patterns
- Examples in mathlib/Data/List/Basic.lean

**Next Steps:**
1. Read Lean 4 manual term-mode section
2. Find mathlib examples with similar patterns
3. Prototype on simplified CA example
4. If successful, apply to Normalization/Composition.lean:43

### Path 3: Alternative Proof Architecture

**Estimated Time:** 1-2 weeks  
**Difficulty:** High  
**Success Probability:** 80%

**Approach:**
```lean
-- Instead of single monolithic theorem with let-destructuring:
-- Break into multiple lemmas that don't require destructuring

theorem eval_produces_result_or_error : 
  ∃ res, eval ... = res ∧ (res = .error ∨ ∃ ms, res = .returned [] ms)

theorem bytecode_result_matches_oracle :
  verifyBytecodeResult ... = .error ↔ oracle.verify ... = none

-- Then compose without needing to destructure
theorem main_composition :
  eval ... = match verifyBytecodeResult ... with ...
:= by
  -- Use previous lemmas, avoid destructuring
```

**Pros:**
- Guaranteed to work (no free variables)
- Better factorization - reusable lemmas
- Follows Registration/EvalEquivRebuild.lean successful pattern

**Cons:**
- Significant refactoring (100-200 lines per operation)
- Changes proof structure
- Takes longer

**Resources:**
- Registration/EvalEquivRebuild.lean (197 theorems, zero sorry)
- Check how it avoided this issue
- Pattern: small lemmas with clear dependencies

**Next Steps:**
1. Read Registration/EvalEquivRebuild.lean thoroughly
2. Identify factorization patterns it used
3. Draft new architecture for one operation (Normalization smallest)
4. If successful, replicate for others

### Path 4: Meta-Programming (Last Resort)

**Estimated Time:** 2-3 weeks  
**Difficulty:** Very High  
**Success Probability:** 90% (but expensive)

**Approach:**
```lean
-- Custom elaborator that handles array literals specially
elab "array_literal_helper" : tactic => do
  -- Meta-programming to bypass free variable constraint
  ...
```

**Pros:**
- Can solve the problem definitively
- Reusable for future similar issues
- Deepens Lean 4 expertise

**Cons:**
- Requires deep Lean 4 knowledge
- Time-consuming
- Overkill if simpler solutions work

**Resources:**
- Lean 4 Meta-programming book: https://github.com/arthurpaulino/lean4-metaprogramming-book
- Mathlib elaborator examples: mathlib/Tactic/
- Lean Zulip #lean4 stream for help

**Next Steps:**
1. Only attempt if Paths 1-3 fail
2. Study meta-programming book chapters 1-5
3. Find similar elaborator in mathlib
4. Adapt for CA use case

---

## Proof Irrelevance Lemmas (Partial Solution)

Created `MovementFormal/MoveModel/ArrayLemmas.lean` with:

```lean
theorem containers_alloc_proof_irrel (cs : ContainerStore) (arr : Array MoveValue)
    (i : Nat) (h1 : i < arr.length) (h2 : i < arr.length) :
    cs.alloc (arr[i]'h1) = cs.alloc (arr[i]'h2)
```

**Status:** Compiled ✅, but doesn't solve free variable issue

**Why it helps:** Allows rewriting when both bound proofs are in scope

**Why it's not enough:** Doesn't eliminate free variables from let-destructuring

---

## Timeline & Priority

### Week 1-2: Quick Attempts (Path 1 & 2)
- Day 1-2: Try revert/intro on Normalization/Composition.lean:43
- Day 3-5: If revert/intro fails, prototype term-mode on same file
- Document results in this log

### Week 3: Decision Point
- If Path 1 or 2 succeeded: Apply to all 8 blocked sorries (1 week)
- If both failed: Start Path 3 (alternative architecture)

### Week 4-6: Architecture Refactor (if needed)
- Study Registration/EvalEquivRebuild.lean pattern
- Refactor one operation completely
- Test build times and proof clarity
- Replicate for other operations

### Fallback: Meta-programming (if all else fails)
- Only if Paths 1-3 fail
- Allocate 2-3 weeks
- High confidence but expensive

---

## Success Criteria

**Minimum:** Solve blocker for at least 4 of 8 sorries (50%)
**Target:** Solve blocker for 6 of 8 sorries (75%)
**Stretch:** Solve blocker for all 8 sorries (100%)

**Metrics:**
- Time to first successful sorry removal: <1 week
- Total time to remove 4 sorries: <3 weeks
- Build time impact: <20% increase per file
- Proof clarity: Readable without meta-programming knowledge

---

## External Resources

### Lean Zulip Discussions
- Search: "Expected type must not contain free variables"
- Search: "proof irrelevance array"
- Thread: https://leanprover.zulipchat.com/#narrow/...

### Similar Issues in Mathlib
- Find proofs with array access in dependent contexts
- Check Data.Array.Lemmas for patterns
- Look for term-mode match constructions

### Lean 4 Manual
- Chapter: "Dependent Type Theory"
- Section: "Proof Irrelevance"
- Section: "Elaboration"

---

## Update Log

**2026-04-23:**
- Documented blocker impact: 8 of 11 sorries (73%)
- Attempted Normalization/Composition.lean:43 - failed on free variables
- Attempted Withdrawal/EvalEquiv.lean:844 - failed on bound proof mismatch
- Created ArrayProofIrrelevancePatterns.lean with examples
- Recommended path: Start with revert/intro pattern (Path 1)

**Next Update:** After attempting Path 1 (revert/intro)
