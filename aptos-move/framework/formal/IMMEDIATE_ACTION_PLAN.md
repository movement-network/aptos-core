# Immediate Action Plan: Next Steps for CA Formal Verification

**Date:** 2026-04-23  
**Context:** 88% complete, 3 main blockers identified  
**Goal:** Clear, prioritized, executable actions to reach 100%

---

## TL;DR - Do This Now

```bash
# 1. Execute Docker publish (15 min, zero blockers)
cd aptos-move/framework/formal/audit
./scripts/publish_docker_image.sh

# 2. Run state validation (5 min)
cd aptos-move/framework/formal
./scripts/validate_current_state.sh --format markdown --output STATE_$(date +%Y%m%d).md

# 3. Run infrastructure tests (2 min)
./scripts/test_verification_infrastructure.sh --quick
```

After these 3 commands, you'll have:
- ✅ Phase 7 100% complete (Docker published)
- ✅ Current state documented with timestamp
- ✅ Infrastructure validated (14/15 tests passing)

---

## Priority Matrix

| Priority | Task | Time | Blocker | Owner | Impact |
|----------|------|------|---------|-------|--------|
| **P0** | Docker publish | 15 min | None | Anyone | Completes Phase 7 |
| **P1** | Ristretto255 investigation | 4-6 hours | None | Move Prover engineer | Unblocks Phases 2/3/5 |
| **P2** | Apply ristretto255 patches | 2-3 days | Investigation complete | Move Prover engineer | Enables 88+ spec VCs |
| **P3** | Phase 1 singleton branch | 5-7 days | Elaborator | Lean engineer | Eliminates 1 TEMPORARY axiom |
| **P4** | Enable remaining CI workflows | 1-2 hours | None | DevOps | Full automation |
| **P5** | Phase 4 helper sorries | 1-2 days | Elaborator | Lean engineer | Optional cleanup |

---

## Detailed Action Items

### P0: Docker Publish (15 minutes, zero blockers)

**Why now:** Only remaining Phase 7 task, zero dependencies, immediate completion

**Commands:**
```bash
cd aptos-move/framework/formal/audit
./scripts/publish_docker_image.sh

# Expected output:
# - Image built: ca-fv:latest
# - Tests passed: 3/3
# - Image published: [registry]/ca-fv:[digest]
# - toolchain.lock updated with digest
```

**Success criteria:**
- Docker image built successfully
- All tests pass inside container
- Image digest captured in toolchain.lock
- Image pushed to registry (or locally tagged for later push)

**On success:**
- Phase 7: 99% → 100% ✅
- verify-ca.sh fully reproducible
- Audit package complete

**On failure:**
- Check Docker daemon running: `docker ps`
- Check disk space: `df -h`
- Check Dockerfile syntax: validated in infrastructure tests ✅

**Next:** Update PHASE_7_STATUS.md to mark Docker publish complete

---

### P1: Ristretto255 Investigation (4-6 hours, zero blockers)

**Why now:** Blocks 3 phases (2/3/5), investigation can start immediately

**Goal:** Understand exact current state and test complete patches

**Phases:**
1. **Phase 1: Document current state** (1-2 hours)
   ```bash
   # Run Move Prover on ristretto255 in isolation
   cd aptos-move/framework/aptos-stdlib
   movement move prove \
       --package-dir . \
       --named-addresses aptos_std=0x1 \
       --filter ristretto255 \
       --verbose \
       --vc-timeout 120 \
       2>&1 | tee /tmp/ristretto255_prove.log

   # Run Move Prover on CA modules
   cd ../aptos-experimental
   movement move prove \
       --package-dir . \
       --named-addresses aptos_experimental=0x7 \
       --filter confidential_asset \
       --verbose \
       --vc-timeout 120 \
       2>&1 | tee /tmp/ca_prove.log

   # Analyze VC counts
   grep "VC" /tmp/ristretto255_prove.log
   grep "VC" /tmp/ca_prove.log
   ```

   **Deliverable:** Test results log with exact error messages and VC counts

2. **Phase 2: Locate and read specs** (30 min)
   ```bash
   # Find ristretto255 specs
   find aptos-move/framework/aptos-stdlib -name "*ristretto255*.spec.move"

   # Check current workarounds
   grep -n "pragma deactivated" \
       aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.spec.move

   # Check scalar_from_u* specs
   grep -A10 "spec scalar_from_u64_internal" \
       aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.spec.move
   ```

   **Deliverable:** Current workaround documentation

3. **Phase 3: Test complete patches** (2-3 hours)
   ```bash
   # Backup current state
   cp aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.spec.move \
      aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.spec.move.backup

   # Apply patches (manual editing based on PHASE_0_RISTRETTO255_PATCH_NOTES.md)
   # Three options:
   # A. Module-level pragma bv_implementation = false
   # B. Companion bv-typed spec functions
   # C. Swap u64/u128 for MSL num

   # Test ristretto255
   movement move prove --package-dir . --filter ristretto255 --verbose

   # If successful, test CA
   cd ../aptos-experimental
   movement move prove --package-dir . --filter confidential_asset --verbose
   ```

   **Deliverable:** VC count comparison (before: 0, after: X)

4. **Phase 4: Document findings** (1 hour)
   - Create RISTRETTO255_TEST_RESULTS_[DATE].md
   - Include: current state, after patches, error messages, VC counts
   - Recommendation: apply locally vs upstream PR vs wait

**Success criteria:**
- Exact current behavior documented
- Complete patches tested
- VC generation confirmed (> 0 VCs)
- Recommendation made with rationale

**On success:**
- Clear path to unblock Phases 2/3/5
- Decision: apply patches locally (immediate) or upstream PR (eventual)

**On failure:**
- Document why patches don't work
- Escalate to upstream or accept limited verification
- Update TRUST_BOUNDARIES.md with limitation

---

### P2: Apply Ristretto255 Patches (2-3 days, after investigation)

**Why after P1:** Need investigation results to know which approach

**Approach A: Local patches (recommended for immediate unblocking)**
```bash
# Apply patches locally
cd aptos-move/framework/aptos-stdlib/sources/cryptography
# Edit ristretto255.spec.move based on test results

# Verify
cd ../../../formal/audit
./verify-ca.sh --stack move-prover

# Document divergence
echo "# Local Ristretto255 Patches" > ../../formal/RISTRETTO255_LOCAL_PATCHES.md
echo "..." >> ../../formal/RISTRETTO255_LOCAL_PATCHES.md
```

**Timeline:** 1 day for patches + 1-2 days for spec strengthening

**Success criteria:**
- CA modules generate > 0 VCs
- VCs verify or fail with actionable errors
- Per-operation verification ≤ 180s

**On success:**
- Phases 2/3/5: 80%/80%/70% → 90%+/90%+/85%+
- Move Prover stack fully operational
- 3-stack verification green (Lean + MSL + difftest)

**Approach B: Upstream PR (recommended in parallel)**
```bash
# Fork aptos-core
# Create branch: fix/ristretto255-spec-patches
# Apply patches
# Submit PR with test results from investigation

# Timeline: Unknown (upstream review/merge)
# Benefit: Entire ecosystem benefits
```

**Recommendation:** Hybrid - Apply locally for immediate progress, submit upstream PR in parallel

---

### P3: Phase 1 Singleton Branch (5-7 days, elaborator-friendly approach)

**Why after P2:** Highest-impact TEMPORARY axiom, but takes longer

**Current state:**
- 3 sorries in EvalEquivRebuild.lean (lines 3498, 3503, 3778)
- Non-singleton branch complete (demonstrates architecture works)
- Target: Eliminate `registration_eval_equiv_functional_sim` axiom

**Approach:**
1. Study non-singleton branch structure (proven to work)
2. Break singleton work into smaller sub-lemmas (<50 lines each)
3. Use `@[irreducible]` aggressively on intermediate states
4. Avoid monolithic proof (elaborator bottleneck)

**Estimate:** 5-7 days (1 day planning + 4-6 days implementation)

**Success criteria:**
- All 3 sorries eliminated
- `registration_eval_equiv_functional_sim` proved (not axiom)
- Build time still ≤3 min (currently 3.0s, plenty of headroom)
- Phase 1: 95% → 100% ✅

**On success:**
- Phase 8: 60% → 68% (1 of 5 TEMPORARY axioms eliminated)
- Registration verification 100% complete
- Architecture validated for all operations

---

### P4: Enable Remaining CI Workflows (1-2 hours)

**Why now:** Infrastructure ready, just needs activation

**Workflows to enable:**
1. `.github/workflows/ca-nightly-verification.yaml`
   - Nightly verification (4 parallel jobs)
   - Auto-creates issues on failure
   - 90-day artifact retention

2. `.github/workflows/ca-pr-validation.yaml`
   - PR validation (7 parallel jobs)
   - Auto-posts/updates PR comments
   - Performance regression detection

3. `.github/workflows/move-prover-ca.yaml` (after ristretto255 fix)
   - Move Prover compilation and verification
   - Z3/Boogie environment setup
   - VC count tracking

**Commands:**
```bash
# Test workflows locally first
cd .github/workflows

# Verify YAML syntax
yamllint ca-nightly-verification.yaml
yamllint ca-pr-validation.yaml

# Enable in GitHub (requires repo permissions)
# - Go to Actions tab
# - Enable workflows
# - Test with manual trigger
```

**Success criteria:**
- All 3 workflows appear in Actions tab
- First manual run succeeds
- Proper permissions configured (issue creation, PR comments)

---

### P5: Phase 4 Helper Sorries (1-2 days, optional)

**Why P5:** Non-blocking, main theorems complete, nice-to-have

**Current state:**
- 4 helper sorries in EvalEquiv files
- All main theorems complete via equivalence axioms
- Blocker: Let-binding elaboration issues

**Approach:**
1. Study let-binding elaboration constraints in Lean 4
2. Either: Redesign to avoid let-bindings
3. Or: Accept as permanent architectural limitation

**Estimate:** 1-2 days (if pursued)

**Success criteria:**
- 4 sorries eliminated
- Or: Documented as permanent limitation with rationale

**Decision:** Defer until Phases 1-3 complete (higher priority work)

---

## Weekly Execution Plan

### Week 1 (Current Week)

**Monday (Today):**
- ✅ Execute Docker publish (15 min) - P0
- ✅ Run state validation - monitoring
- ✅ Run infrastructure tests - monitoring

**Tuesday-Wednesday:**
- ⏱️ Ristretto255 investigation (4-6 hours) - P1
- ⏱️ Document findings and make recommendation

**Thursday-Friday:**
- ⏱️ Apply ristretto255 patches locally (if recommended)
- ⏱️ Test VC generation
- ⏱️ Begin spec strengthening

**Weekend (optional):**
- Submit upstream PR for ristretto255 (if applicable)

### Week 2

**Monday-Wednesday:**
- Complete spec strengthening (Phases 2/3/5)
- Measure verification time
- Optimize slow specs if needed

**Thursday-Friday:**
- Enable remaining CI workflows - P4
- Begin Phase 1 singleton branch planning - P3

### Week 3

**Full week:**
- Phase 1 singleton branch implementation (5-7 days)

### Week 4

**Monday:**
- Complete singleton branch
- Celebrate Phase 1 100% complete! 🎉

**Tuesday-Friday:**
- Quarterly documentation update
- Performance baseline refresh
- Optional: Phase 4 helper sorries - P5

---

## Success Milestones

### Milestone 1: Phase 7 Complete (Today)
- ✅ Docker publish
- ✅ All §10 deliverables shipped
- ✅ Reproducibility package ready

### Milestone 2: Move Prover Operational (Week 1)
- ✅ Ristretto255 blocker resolved
- ✅ VCs generating for CA specs
- ✅ Phases 2/3/5 verification green

### Milestone 3: Full 3-Stack Green (Week 2)
- ✅ Lean stack green
- ✅ Move Prover stack green
- ✅ Difftest stack green
- ✅ All CI workflows enabled

### Milestone 4: Phase 1 Complete (Week 3-4)
- ✅ Singleton branch proved
- ✅ 1 TEMPORARY axiom eliminated
- ✅ Registration 100% complete

### Milestone 5: CA FV 100% Done (Week 4)
- ✅ All 9 phases complete
- ✅ 5 TEMPORARY axioms eliminated (or 1 high-priority)
- ✅ Full audit package shipped
- ✅ Reviewer can confirm in ≤30 min

---

## Risk Management

### Risk 1: Ristretto255 patches don't work

**Mitigation:**
- Fallback A: Strengthen CA specs within current limitations
- Fallback B: Wait for upstream fix, focus on Lean side
- Fallback C: Accept limited verification, document in TRUST_BOUNDARIES.md

**Probability:** Low (patches well-studied, multiple approaches available)

### Risk 2: Phase 1 singleton branch takes longer than 7 days

**Mitigation:**
- Break into smaller chunks, deliver incrementally
- Accept partial completion (main proof structure + some sorries)
- Document progress transparently

**Probability:** Medium (elaborator blockers are unpredictable)

### Risk 3: CI workflows have permission issues

**Mitigation:**
- Test locally first with `act` or similar
- Manual approval workflow initially
- Escalate to repo admin if needed

**Probability:** Low (permissions already configured for existing workflows)

---

## Communication Plan

### Daily Updates (if team collaboration)
- Post progress to team channel
- Update PHASE_*_STATUS.md files
- Run `./scripts/validate_current_state.sh` daily

### Weekly Updates
- Run `./scripts/track_phase_progress.sh --format markdown`
- Compare against previous week
- Celebrate wins, document blockers

### Milestone Completion
- Update CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md §0 progress tracker
- Create session summary (like COMPLETE_SESSION_SUMMARY_2026_04_23.md)
- Share with stakeholders

---

## Quick Reference Commands

```bash
# Daily validation
./scripts/validate_current_state.sh
./scripts/test_verification_infrastructure.sh --quick

# Phase progress
./scripts/track_phase_progress.sh

# Full verification check
cd audit && ./verify-ca.sh

# Performance benchmarking
./scripts/benchmark_verification.sh --baseline

# Axiom diff check
./scripts/check_axioms.sh --baseline

# Trust boundary reconciliation
./scripts/reconcile_trust_boundaries.sh
```

---

## Conclusion

Clear path to 100% completion in 3-4 weeks with 5 concrete priority levels. P0 (Docker publish) can be done today in 15 minutes. P1 (ristretto255 investigation) unlocks 3 phases. P3 (singleton branch) eliminates highest-priority TEMPORARY axiom.

**Today's focus:** P0 (Docker) + P1 (investigation) = 5-6 hours of high-impact work

**This week's goal:** Phase 7 complete + ristretto255 blocker resolved

**This month's goal:** Full 3-stack green + Phase 1 complete

All actionable, all measurable, all achievable.
