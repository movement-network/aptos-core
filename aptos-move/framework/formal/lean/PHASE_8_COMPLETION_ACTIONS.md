# Phase 8 Axiom Elimination - Concrete Action Plan

**Status**: 60% complete (57 permanent axioms accepted, 5 TEMPORARY to eliminate)

## TEMPORARY Axioms Requiring Elimination

### 1. Registration Singleton Branch (2 axioms)

**File**: `Registration/EvalEquivRebuild.lean`

#### Axiom 1: `registration_run_through_pc5_singleton` (line 3433)
- **Blocks**: Singleton branch of main theorem
- **Proof strategy**: Chain PCs 3→4→5→6
- **Blocker**: Complex locals array manipulation
- **Estimated effort**: ~100-150 lines
- **Status**: ☐ TODO

#### Axiom 2: `registration_eval_equiv_functional_sim` (line 3569)
- **Blocks**: Main equivalence theorem (the big one)
- **Depends on**: Axiom 1 completion
- **Current progress**: Non-singleton branch 100% complete
- **Remaining**: Singleton `some [v]` case only
- **Estimated effort**: ~50-80 lines (after Axiom 1)
- **Status**: 🟡 75% complete

**Roadmap**: SINGLETON_BRANCH_ROADMAP.md has detailed plan

### 2. Withdrawal Helper Lemmas (4 axioms)

**File**: `Withdrawal/EvalEquiv.lean`

#### Axiom 3: `run_to_sigma_fail_produces_error` (line 571)
- **Purpose**: PC chain 0-9, sigma oracle returns none
- **Proof strategy**: Documented lines 596-641
  - Step 1: chain_five_moveLoc for PCs 0-4
  - Step 2: step_moveLoc_single for PC 5
  - Step 3: copyLoc chains for PCs 6-7
  - Step 4: immBorrowField for PC 8
  - Step 5: call with none oracle for PC 9
- **Blocker**: Elaborator constraint (frame.locals.set)
- **Estimated effort**: ~80-100 lines
- **Status**: ☐ TODO - signature refactored, proof blocked

#### Axiom 4: `run_to_range_fail_produces_error` (line 615)
- **Purpose**: PC chain 0-13, sigma succeeds, range fails
- **Proof strategy**: Similar to Axiom 3, longer chain
- **Blocker**: Same elaborator constraint
- **Estimated effort**: ~100-120 lines
- **Status**: ☐ TODO - signature refactored

#### Axiom 5: `run_sigma_arity_mismatch_produces_error` (line 656)
- **Purpose**: Handles impossible case (oracle returns non-empty)
- **Priority**: LOW (type system prevents this case)
- **Estimated effort**: ~30-40 lines
- **Status**: ☐ TODO - low priority

#### Axiom 6: `run_range_arity_mismatch_produces_error` (line 687)
- **Purpose**: Handles impossible case (oracle returns non-empty)
- **Priority**: LOW (type system prevents this case)
- **Estimated effort**: ~30-40 lines
- **Status**: ☐ TODO - low priority

## Root Cause Analysis

### Elaborator Constraint

**Impact**: Blocks 4 out of 5 TEMPORARY axioms (all Withdrawal helpers)

**Technical Issue**: 
```lean
frame.locals.set i none bound_proof
```
Lean elaborator rejects frame construction with bound proofs in tactic mode.

**Evidence**: 
- Memory note in auto-memory confirms: "lifting heq-rfl bridge lemmas alone doesn't help; bound-proof elaboration in theorem statement is the real cost"
- MoveLocChains.lean: All 6 axioms blocked by same issue
- Bundled.lean: All 10 axioms blocked by same issue

**Current Workaround**: 
- CopyLocChains.lean successfully proves copyLoc chains (no .set operations)
- Proves that workaround exists for some cases

**Total Blocked**: ~22-24 axioms across codebase
- 4 TEMPORARY (Withdrawal helpers)
- 6 MoveLocChains
- 10 Bundled
- 1-2 others

### Resolution Paths

#### Path 1: Fix Elaborator (Preferred)
- **Who**: Requires Lean 4 expertise or workaround discovery
- **Effort**: Unknown (could be 1 day or 1 week)
- **Impact**: Unblocks 22-24 axioms immediately
- **Approach**: Term-mode construction instead of tactic mode

#### Path 2: Prove Without .set Operations
- **Who**: Anyone with Lean experience
- **Effort**: Requires redesigning proofs to avoid locals modification
- **Impact**: Only works for some cases (copyLoc worked, moveLoc won't)
- **Feasibility**: LOW for moveLoc-based proofs

#### Path 3: Accept as Infrastructure Axioms
- **Who**: Design decision
- **Effort**: 0 (just document and accept)
- **Impact**: 4 TEMPORARY axioms remain, but documented as "provable pending elaborator fix"
- **Trade-off**: Doesn't reduce official axiom count but acknowledges blocker

## Completion Strategy

### Near-term (1-2 weeks)

1. **Complete Registration Singleton Branch** (unblocks 2 axioms)
   - Axiom 1: registration_run_through_pc5_singleton
   - Axiom 2: registration_eval_equiv_functional_sim
   - Not blocked by elaborator
   - Estimated: 150-230 total lines
   - Roadmap exists: SINGLETON_BRANCH_ROADMAP.md

2. **Attempt Elaborator Workaround** (could unblock 4 axioms)
   - Try term-mode frame construction
   - Try alternative proof strategies without .set
   - Consult Lean 4 documentation/community
   - Estimated: 2-4 hours investigation

3. **Document Acceptance Criteria** (if workaround fails)
   - Clarify whether 4 Withdrawal helpers count as "TEMPORARY" or "infrastructure"
   - Update AXIOM_INVENTORY.md with blocker status
   - Decision: 57 permanent + 4 "pending elaborator" vs 61 permanent

### Long-term (1-2 months)

4. **Prove Low-Priority Axioms** (arity mismatches)
   - Axiom 5 & 6: arity mismatch cases
   - These are provable even with elaborator constraint
   - Just need time investment
   - Estimated: 60-80 total lines

5. **Infrastructure Axiom Cleanup** (optional)
   - Prove remaining StepLemmas axioms if elaborator fix found
   - Current: 56 infrastructure axioms (down from 57)
   - Target: <40 infrastructure axioms
   - Benefit: Cleaner proof foundation

## Current Blocking Items

1. **Singleton Branch** (Registration)
   - **Blocker**: Time/effort, not technical
   - **Next step**: Begin PC-chaining proof
   - **Owner**: Anyone with Lean experience

2. **Elaborator Constraint** (Withdrawal)
   - **Blocker**: Technical (Lean 4 limitation or unknown workaround)
   - **Next step**: Research term-mode frame construction
   - **Owner**: Lean 4 expert

3. **Arity Mismatches** (Withdrawal)
   - **Blocker**: Time/effort, low priority
   - **Next step**: Write straightforward proofs
   - **Owner**: Anyone with Lean experience

## Success Criteria

### Minimum (Acceptable "Done")
- 2 Registration axioms eliminated (singleton branch)
- 4 Withdrawal axioms documented as "pending elaborator fix"
- Final count: 57 permanent + 4 pending-fix = 61 total
- All pending axioms have documented proof strategies

### Target (Ideal "Done")  
- All 5 TEMPORARY axioms eliminated
- Final count: 57 permanent axioms only
- Requires: Elaborator fix or workaround

### Stretch (Full Cleanup)
- 5 TEMPORARY eliminated
- 20+ infrastructure axioms eliminated (via elaborator fix)
- Final count: 57 permanent + <35 infrastructure

## Resources

- **AXIOM_INVENTORY.md**: Official 62-axiom tracking
- **STEPLEMMAS_AXIOM_ANALYSIS.md**: Infrastructure 57-axiom tracking
- **SINGLETON_BRANCH_ROADMAP.md**: Registration completion plan
- **PHASE_4_PROOF_COMPLETION_BLOCKER_ANALYSIS.md**: Elaborator blocker details

---

**Last Updated**: 2026-04-23
**Next Review**: After singleton branch completion or elaborator fix
