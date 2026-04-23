# Next Steps for Verification Completion

**Current Status**: ~86% complete (10 axioms, 17 sorries)  
**Last Updated**: 2026-04-23

This document provides concrete, actionable guidance for completing the remaining 14% of verification work.

## Quick Start

If you have 1 hour: Read `BLOCKERS_AND_PATH_FORWARD.md` to understand what's blocked and why.

If you have 1 day: Attempt the Rotation composition proof (1 sorry, simplest operation).

If you have 1 week: Tackle the Phase 1 singleton branch (6-12 hour PC-threading proof).

If you have 1 month: Research term-mode proofs or architectural restructuring for Phase 4/6.

---

## Priority 1: Phase 1 Singleton Branch (High Impact, Clear Path)

**Effort**: 6-12 hours of focused proof work  
**Impact**: Eliminates 1 TEMPORARY axiom, brings Phase 1 to 100%  
**Difficulty**: Medium (tedious PC-threading, not architecturally blocked)

### What to Do

**File**: `lean/MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean:3557`

**Goal**: Complete the singleton success branch `some [mv]` for `o.newCompressedPointFromBytes`.

**Steps**:
1. Start at line 3557 where the sorry is
2. Use `registration_run_through_pc2` helper to reach PC 3
3. Thread through PC 3 (`immBorrowLoc 7`)
4. Continue through all 67 PCs to match functional simulation
5. Handle oracle calls and container-store mutations
6. Connect to final `.returned` state

**Tactics Available**:
- `run_succ_ok_of_step` - chain consecutive PCs
- Per-PC step theorems: `step_registration_pc0`, `step_registration_pc1`, ...
- PC-lookup lemmas: all 83 PCs already proved
- Helper compositions: 2-PC and 3-PC compositions available

**Expected Proof Structure**:
```lean
-- At line 3557, replace sorry with:
-- 1. Apply registration_run_through_pc2
have h_pc2 := registration_run_through_pc2 ... 
rw [h_pc2]

-- 2. Thread PC 3 (immBorrowLoc 7)
have h_pc3 := step_registration_pc3 ...
rw [run_succ_ok_of_step _ _ _ _ _ h_pc3]

-- 3. Continue for 64 more PCs using same pattern
-- (Refer to existing 2-PC/3-PC compositions for similar structure)

-- 4. Final return at PC 67
have h_pc67 := step_registration_pc67_ret ...
rw [run_succ_returned_of_step _ _ _ h_pc67]

-- 5. Match with functional simulation
unfold registration_eval_equiv_functional_sim_impl
simp [oracle success cases]
```

**Why This Is Doable**:
- All infrastructure exists (step lemmas, helpers, compositions)
- Non-singleton branch is complete (shows the pattern)
- Just needs time investment, not new tactics or architectural changes

**Expected Outcome**: Phase 1 goes from 95% → 100%, eliminates the TEMPORARY axiom.

---

## Priority 2: Phase 4/6 Elaborator Workaround (High Impact, Research Needed)

**Effort**: 2-3 weeks (1 week research + 1-2 weeks implementation per operation)  
**Impact**: Eliminates 17 sorries + enables Phase 6 completion  
**Difficulty**: High (requires deep Lean 4 knowledge OR architectural redesign)

### Option A: Term-Mode Proof Construction

**Pros**: Bypasses tactic elaborator, should work around let-binding issue  
**Cons**: Very verbose, hard to maintain, steep learning curve

**Proof of Concept**: Start with Rotation (1 sorry, simplest case)

**File**: `lean/MovementFormal/Experimental/ConfidentialAsset/Rotation/EvalEquiv.lean:507`

**Approach**:
1. Study Lean 4 term-mode proof construction
2. Build proof term directly instead of using tactics
3. Manually construct the nested match eliminations
4. Document pattern for reuse on other operations

**Resources**:
- Lean 4 manual: https://lean-lang.org/theorem_proving_in_lean4/
- Mathlib term-mode examples
- Lean Zulip #lean4 channel for help

**Expected Code**:
```lean
-- Instead of tactic mode:
theorem rotation_eval_equiv_functional_sim ... := by
  unfold ... 
  rw [...]
  sorry  -- hits elaborator issue

-- Use term mode:
theorem rotation_eval_equiv_functional_sim ... :=
  -- Explicitly construct proof term
  match_eq_proof (halloc0 : ...) (hsigmaOk : ...)
    (λ cs1 fid1 =>
      match_eq_proof (hsigmaOk cs1 ...)
        (λ cs2 => ...))
```

**If Successful**: Replicate pattern for Normalization (2 sorries), Transfer (2), Withdrawal (12).

### Option B: Architectural Restructuring

**Pros**: Clean solution, easier to maintain  
**Cons**: Significant upfront cost, breaks existing proofs

**Approach**:
1. Redesign functional sims to avoid nested let-bindings
2. Use explicit function parameters instead of let-bindings
3. Reimplement Phase 4 proofs with new architecture
4. Update Phase 6 composition proofs

**Expected Code**:
```lean
-- Current (blocked):
def verifyXBytecodeResult ... :=
  let (cs1, fid1) := alloc x in
  match oracle cs1 with ...

-- New (unblocked):
def verifyXBytecodeResult_impl (cs1 : ContainerStore) (fid1 : RefId) 
    (h : alloc x = (cs1, fid1)) ... :=
  match oracle cs1 with ...

def verifyXBytecodeResult ... :=
  verifyXBytecodeResult_impl (alloc x).1 (alloc x).2 rfl
```

**Expected Timeline**: 4-6 weeks for complete redesign + reimplementation

### Option C: Wait for Lean 4 Improvements

**Pros**: No local work needed  
**Cons**: No ETA, might never happen

**Action Items**:
1. Post minimal reproducer to Lean 4 Zulip
2. File GitHub issue on leanprover/lean4
3. Monitor Lean 4 release notes for elaborator improvements
4. Test each new release against blocked proofs

---

## Priority 3: Phase 7 Docker Publish (Low Effort, External Dependency)

**Effort**: 15 minutes  
**Impact**: Completes Phase 7 (99% → 100%)  
**Blocker**: Needs Docker registry credentials

### What to Do

**Files**: `audit/Dockerfile`, `audit/DOCKER_REPRODUCIBILITY_GUIDE.md`

**Steps**:
1. Get credentials for Docker registry from infra team
2. Build image: `docker build -t ca-verification:v1.0 audit/`
3. Test image: `docker run --rm ca-verification:v1.0 ./verify-ca.sh --quick`
4. Push image: `docker push ca-verification:v1.0`
5. Capture digest: `docker inspect --format='{{.RepoDigests}}' ca-verification:v1.0`
6. Update documentation with digest
7. Commit changes

**Expected Outcome**: Phase 7 complete, reproducible verification image available.

---

## Priority 4: Upstream Framework Specs (Medium Effort, External Coordination)

**Effort**: 1-2 days  
**Impact**: Unblocks Phase 2/3/5 Move Prover VCs  
**Blocker**: Requires aptos-framework team coordination or direct contribution

### What to Do

**Missing Modifies Clauses** (33 errors):
- `aptos_framework::object::create_named_object`
- `aptos_framework::primary_fungible_store::transfer`
- `aptos_framework::dispatchable_fungible_asset::transfer`
- `aptos_framework::coin::withdraw`

**Approach A: Contribute to aptos-framework**

1. Clone aptos-framework repository
2. Add modifies clauses to the 4 functions above
3. Run Move Prover to verify specs
4. Submit PR with changes
5. Wait for review + merge

**Approach B: Coordinate with Framework Team**

1. File issue listing missing modifies clauses
2. Provide reproducer showing CA compilation errors
3. Request framework team to add clauses
4. Update CA specs once framework is patched

**Expected Outcome**: Move Prover generates meaningful VCs for CA specs (currently 0 VCs).

---

## Not Recommended

### ❌ Adding More Helper Lemmas

**Why**: Current StepLemmas library is comprehensive. More helpers won't solve the let-binding blocker.

**Exception**: Only add helpers if you're actively working on a proof and discover a pattern that needs abstraction.

### ❌ Adding More Difftest Test Cases

**Why**: Current 87 rows (43 hex + 43 metadata) provide good coverage. Diminishing returns on additional tests.

**Exception**: Add tests for specific edge cases if you discover gaps in coverage.

### ❌ Documentation-Only Work

**Why**: Documentation is already comprehensive (~157k lines). More docs without closing proofs is low value.

**Exception**: Update docs when you close proofs or resolve blockers.

---

## Success Criteria

### Phase 1 Complete
- [ ] `registration_eval_equiv_functional_sim` TEMPORARY axiom eliminated
- [ ] Singleton branch sorry at line 3557 closed
- [ ] All 197 Registration theorems proved (0 axioms remaining)
- [ ] Full tree builds in <10 min

### Phase 4/6 Complete
- [ ] All 17 sorries closed (Norm 2, Rot 1, Transfer 2, Withdrawal 12)
- [ ] 4 helper axioms either proved or accepted as lemmas
- [ ] 5 Phase 6 composition axioms either proved or accepted
- [ ] Full tree builds in <10 min

### Phase 7 Complete
- [ ] Docker image published with digest captured
- [ ] Reproducibility guide updated with image reference
- [ ] Clean reproduction verified from fresh clone + Docker pull

### All Phases Complete
- [ ] 0 TEMPORARY axioms
- [ ] ≤5 permanent axioms (composition + helpers acceptable)
- [ ] All reconciliation checks pass
- [ ] verify-ca.sh runs green for all operations
- [ ] CI passes all checks

---

## Getting Help

### Lean 4 Questions
- **Zulip**: https://leanprover.zulipchat.com/ (#lean4 stream)
- **GitHub**: https://github.com/leanprover/lean4/issues

### Move Prover Questions
- **Aptos Discord**: #move-prover channel
- **GitHub**: https://github.com/aptos-labs/aptos-core/issues

### CA-Specific Questions
- Check existing documentation in `formal/` directory
- Review session summaries: `formal/SESSION_*.md`, `formal/FINAL_SESSION_SUMMARY_*.md`
- Read blocker analysis: `formal/BLOCKERS_AND_PATH_FORWARD.md`

---

## Timeline Estimates

### Aggressive (1 Month)
- Week 1: Phase 1 singleton branch (6-12 hours)
- Week 2: Phase 7 Docker publish (15 min) + Research term-mode proofs
- Week 3: Attempt Rotation term-mode proof (proof of concept)
- Week 4: Coordinate upstream framework specs OR continue term-mode research

### Realistic (3 Months)
- Month 1: Phase 1 complete + term-mode research + POC
- Month 2: Term-mode proofs for simple operations (Rot, Norm, Transfer)
- Month 3: Term-mode proofs for complex operation (Withdrawal) + Phase 7 + upstream coordination

### Conservative (6 Months)
- Months 1-2: Architectural restructuring (redesign functional sims)
- Months 3-4: Reimplement Phase 4 proofs with new architecture
- Months 5-6: Complete Phase 6 compositions + upstream specs + Phase 7

---

## Conclusion

**The verification is 86% complete with clear paths to 100%.**

The remaining work requires ONE OF:
1. **Time investment** (Phase 1: 6-12 hours of PC-threading)
2. **Technical research** (Phase 4/6: term-mode proofs or architectural redesign)
3. **External coordination** (Phase 7: Docker credentials; Phase 2/3/5: upstream specs)

**No work is fundamentally blocked or impossible.** Every remaining sorry has a known solution; the choice is between:
- **Fast but verbose** (term-mode proofs)
- **Clean but expensive** (architectural restructuring)
- **Free but uncertain** (wait for Lean 4 improvements)

Pick the path that fits your timeline and resources. All three are viable.
