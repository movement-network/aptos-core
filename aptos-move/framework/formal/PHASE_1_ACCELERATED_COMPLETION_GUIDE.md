# Phase 1 Accelerated Completion Guide

**Goal:** Complete the Registration singleton-some branch proof in 4-8 hours (vs 1-2 days unguided)  
**Status:** Phase 1 is 95% complete, only singleton-some branch remaining (~200-300 lines)  
**Prerequisites:** Familiarity with Lean 4, understanding of Phase 4 architecture patterns  
**Estimated Effort:** 4-8 hours with this guide, 1-2 days without

---

## Executive Summary

The Registration operation is the most complex CA operation (55 PCs, 197 theorems). Phase 4 completed the rebuild with all branches except the **singleton-some** branch, which handles the case where:
1. Container table lookup returns `some(existing_container)`
2. We need to mutate the container via `MoveTo`

This guide provides an accelerated path to completing this final branch using the proven Phase 4 architecture patterns.

**Key deliverables:**
- ✅ Singleton-none branch: COMPLETE (handles fresh container creation)
- 🟡 Singleton-some branch: REMAINING (~200-300 lines, this guide)
- ✅ Non-singleton branch: COMPLETE (handles multiple potential containers)

**Performance target:** < 3 minutes build time (currently ~3.0s for completed branches)

**Axiom budget:** 0 temporary axioms (only permanent crypto axioms allowed)

---

## Architecture Overview

### The Singleton-Some Branch Flow

```
PC 39: LoadContainerTable
PC 40: ImmBorrow container_addr
PC 41: Call table_with_length.borrow (...) → returns `some(container_ref)`
PC 42: BrTrue (BRANCH TAKEN because result is some)
  ↓
PC 43-51: Singleton-some path
  PC 43: CopyLoc container_ref
  PC 44: ReadRef (get container value)
  PC 45: StLoc old_container
  PC 46: Borrow mut container_ref
  PC 47: UpdateContainer (mutate fields)
  PC 48: MoveTo container_addr old_container  ← CRITICAL: Table mutation
  PC 49: (cleanup)
  PC 50: (cleanup)
  PC 51: Branch to common_path (PC 55)
```

**Critical challenge:** Threading the heap state through `MoveTo`, which updates the container table.

**Pattern to use:** Container table mutation lemmas (similar to `step_moveTo_table_insert`)

---

## Prerequisites Check

Before starting, ensure you have:

**Files to read:**
1. ✅ `PHASE_1_SINGLETON_SOME_BRANCH_GUIDE.md` (detailed reference)
2. ✅ `BEST_PRACTICES_AND_PATTERNS.md` (architecture patterns)
3. ✅ `NORMALIZATION_COMPLETE_IMPLEMENTATION.md` (simple operation example)

**Files to modify:**
1. `lean/MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean`
2. `lean/MovementFormal/MoveModel/Native/Registration.lean` (if adding table mutation lemmas)

**Commands to run:**
```bash
# Test current state (should build successfully for non-singleton branches)
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild

# Profile build time
./scripts/profile_lean_build.sh MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
```

**Expected output:** ~3.0s build time, 0 errors (singleton-some branch not yet implemented)

---

## Step-by-Step Implementation

### Step 1: Define Symbolic States for Singleton-Some Branch (30-60 minutes)

**File:** `EvalEquivRebuild.lean`

**Location:** After the singleton-none state definitions

**Task:** Define `@[irreducible]` states for PCs 43-51 (singleton-some path)

**Code template:**

```lean
/-!
### Singleton-Some Branch Symbolic States

When container table lookup returns `some(container_ref)`, we:
1. Read the old container value
2. Mutate the container
3. Update the table via MoveTo

PCs 43-51
-/

@[irreducible]
def registrationStateSingletonSome_PC43
    (proofRef : RefValue)
    (ownerAddr : Address)
    (containerRef : RefValue)
    (storageTable : ContainerTable)
    (ms : MachineState) : Frame :=
  { code := verifyRegistrationCode,
    pc := 43,
    locals := #[
      some (MoveValue.ref proofRef),
      some (MoveValue.address ownerAddr),
      some (MoveValue.ref containerRef),
      none,  -- old_container (not yet read)
      none   -- temporary
    ],
    localRefs := #[
      some proofRef,
      none,
      some containerRef,
      none,
      none
    ] }

@[irreducible]
def registrationStateSingletonSome_PC44
    (proofRef : RefValue)
    (ownerAddr : Address)
    (containerRef : RefValue)
    (storageTable : ContainerTable)
    (ms : MachineState) : Frame :=
  { code := verifyRegistrationCode,
    pc := 44,
    locals := #[
      some (MoveValue.ref proofRef),
      some (MoveValue.address ownerAddr),
      some (MoveValue.ref containerRef),
      none,  -- old_container (will be populated by ReadRef)
      none
    ],
    localRefs := #[
      some proofRef,
      none,
      some containerRef,
      none,
      none
    ] }

-- TODO: Define states for PCs 45-51 similarly
-- Key: Track the old_container value from PC 44 onward
-- Key: Track heap mutations at PC 48 (MoveTo)
```

**Performance tip:** Use `@[irreducible]` on all state constructors (100× speedup)

**Estimated time:** 30-60 minutes to define all 9 PC states (43-51)

---

### Step 2: Write Step Lemmas for PCs 43-47 (Container Read) (60-90 minutes)

**Task:** Prove each individual PC step for the container read phase

**Pattern:** Use existing step lemma library from `StepLemmas/`

**Code template for PC 43 (CopyLoc):**

```lean
theorem step_singletonSome_pc43_copyLoc_containerRef
    (oracle : RegistrationNativeOracle)
    (proofRef : RefValue)
    (ownerAddr : Address)
    (containerRef : RefValue)
    (storageTable : ContainerTable)
    (cs : CallStack)
    (ms : MachineState)
    (h_container_ref : ms.heap.get? containerRef = some container_value)
    : step env (registrationStateSingletonSome_PC43 proofRef ownerAddr containerRef storageTable ms) cs ms =
        .ok (registrationStateSingletonSome_PC44 proofRef ownerAddr containerRef storageTable ms) cs ms := by
  rw [registrationStateSingletonSome_PC43, registrationStateSingletonSome_PC44]
  rw [step_copyLoc]
  simp only [Array.get?]
  -- CopyLoc duplicates the value in locals[2] (containerRef)
  rfl
```

**Code template for PC 44 (ReadRef):**

```lean
theorem step_singletonSome_pc44_readRef_container
    (oracle : RegistrationNativeOracle)
    (proofRef : RefValue)
    (ownerAddr : Address)
    (containerRef : RefValue)
    (container : Container)
    (storageTable : ContainerTable)
    (cs : CallStack)
    (ms : MachineState)
    (h_container : ms.heap.get? containerRef = some container)
    : step env (registrationStateSingletonSome_PC44 proofRef ownerAddr containerRef storageTable ms) cs ms =
        .ok (registrationStateSingletonSome_PC45 proofRef ownerAddr containerRef container storageTable ms) cs ms := by
  rw [registrationStateSingletonSome_PC44, registrationStateSingletonSome_PC45]
  rw [step_readRef]
  apply step_readRef_value
  exact h_container
```

**Code template for PC 45 (StLoc - store old_container):**

```lean
theorem step_singletonSome_pc45_stLoc_oldContainer
    (oracle : RegistrationNativeOracle)
    (proofRef : RefValue)
    (ownerAddr : Address)
    (containerRef : RefValue)
    (container : Container)
    (storageTable : ContainerTable)
    (cs : CallStack)
    (ms : MachineState)
    : step env (registrationStateSingletonSome_PC45 proofRef ownerAddr containerRef container storageTable ms) cs ms =
        .ok (registrationStateSingletonSome_PC46 proofRef ownerAddr containerRef container storageTable ms) cs ms := by
  rw [registrationStateSingletonSome_PC45, registrationStateSingletonSome_PC46]
  rw [step_stLoc]
  simp only [Array.get?, Array.set]
  rfl
```

**Estimated time:** 15-20 minutes per PC (5 PCs = 60-90 minutes total)

**Testing strategy:** Test each lemma individually:
```bash
# Add #check after each theorem to verify it type-checks
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
```

---

### Step 3: Write Step Lemma for PC 48 (MoveTo - Table Mutation) (90-120 minutes)

**This is the critical step.** MoveTo updates the container table in the heap.

**Challenge:** Thread the heap update through the proof.

**Step 3a: Define Table Mutation Helper Lemma**

**File:** `MovementFormal/MoveModel/Native/Registration.lean`

**Code:**

```lean
/-!
# Container Table Mutation Lemmas

Helpers for reasoning about table updates via MoveTo.
-/

/-- Helper: MoveTo updates the container table at the given address -/
theorem step_moveTo_table_update
    (containerAddr : Address)
    (container : Container)
    (tableRef : RefValue)
    (storageTable : ContainerTable)
    (ms : MachineState)
    (h_table : ms.heap.get? tableRef = some (MoveValue.table storageTable))
    : let ms' := ms.update_heap tableRef (MoveValue.table (storageTable.insert containerAddr container))
      ms'.heap.get? tableRef = some (MoveValue.table (storageTable.insert containerAddr container)) := by
  simp only [MachineState.update_heap]
  rfl

/-- Helper: After MoveTo, the container table contains the new container at containerAddr -/
theorem heap_get_after_table_insert
    (containerAddr : Address)
    (container : Container)
    (tableRef : RefValue)
    (storageTable : ContainerTable)
    (ms ms' : MachineState)
    (h_update : ms' = ms.update_heap tableRef (MoveValue.table (storageTable.insert containerAddr container)))
    : ms'.heap.get? tableRef = some (MoveValue.table (storageTable.insert containerAddr container)) := by
  rw [h_update]
  exact step_moveTo_table_update containerAddr container tableRef storageTable ms h_table
```

**Step 3b: Apply Helper in PC 48 Step Lemma**

**File:** `EvalEquivRebuild.lean`

**Code:**

```lean
theorem step_singletonSome_pc48_moveTo_updateTable
    (oracle : RegistrationNativeOracle)
    (proofRef : RefValue)
    (ownerAddr : Address)
    (containerRef : RefValue)
    (containerAddr : Address)
    (old_container new_container : Container)
    (storageTable : ContainerTable)
    (tableRef : RefValue)
    (cs : CallStack)
    (ms : MachineState)
    (h_table : ms.heap.get? tableRef = some (MoveValue.table storageTable))
    (h_new_container : new_container = update_container_fields old_container ...)
    : step env (registrationStateSingletonSome_PC48 proofRef ownerAddr containerRef containerAddr old_container new_container storageTable ms) cs ms =
        .ok (registrationStateSingletonSome_PC49 proofRef ownerAddr containerRef containerAddr new_container storageTable' ms') cs ms' := by
  -- Unfold symbolic states
  rw [registrationStateSingletonSome_PC48, registrationStateSingletonSome_PC49]
  
  -- Apply MoveTo instruction step
  rw [step_moveTo]
  
  -- MoveTo updates the table by inserting new_container at containerAddr
  let storageTable' := storageTable.insert containerAddr new_container
  let ms' := ms.update_heap tableRef (MoveValue.table storageTable')
  
  -- Apply helper lemma for table mutation
  have h_heap : ms'.heap.get? tableRef = some (MoveValue.table storageTable') := by
    exact step_moveTo_table_update containerAddr new_container tableRef storageTable ms h_table
  
  -- Simplify and close
  simp only [h_heap]
  rfl
```

**Debugging tips:**
- If `rfl` fails, use `simp only [...]` to normalize both sides
- If heap update doesn't match, check that `ms'` is threaded correctly through subsequent PCs
- Use `#check` to verify types before attempting proof

**Estimated time:** 90-120 minutes (30 min for helper lemmas, 60-90 min for PC 48 step lemma)

---

### Step 4: Write Step Lemmas for PCs 49-51 (Cleanup and Branch) (30-45 minutes)

**Task:** Prove cleanup PCs and final branch to common path

**Code template for PC 49-50 (cleanup):**

```lean
theorem step_singletonSome_pc49_cleanup
    (...)
    : step env (registrationStateSingletonSome_PC49 ...) cs ms =
        .ok (registrationStateSingletonSome_PC50 ...) cs ms := by
  rw [registrationStateSingletonSome_PC49, registrationStateSingletonSome_PC50]
  rw [step_<instruction>]  -- e.g., step_pop, step_drop
  simp only [Array.get?]
  rfl
```

**Code template for PC 51 (branch to common path):**

```lean
theorem step_singletonSome_pc51_branch_to_common
    (...)
    : step env (registrationStateSingletonSome_PC51 ...) cs ms =
        .ok (registrationStateCommonPath_PC55 ...) cs ms := by
  rw [registrationStateSingletonSome_PC51, registrationStateCommonPath_PC55]
  rw [step_branch]
  -- Branch instruction jumps to PC 55 (common path)
  simp only []
  rfl
```

**Estimated time:** 10-15 minutes per PC (3 PCs = 30-45 minutes)

---

### Step 5: Chain Singleton-Some Branch (60-90 minutes)

**Task:** Chain all singleton-some PCs together into a single theorem

**Code template:**

```lean
/-!
# Singleton-Some Branch Chaining Theorem

Chains PCs 43-51 (singleton-some path) together.
-/

theorem registration_singleton_some_branch_chain
    (oracle : RegistrationNativeOracle)
    (proofRef : RefValue)
    (ownerAddr : Address)
    (containerRef : RefValue)
    (containerAddr : Address)
    (container : Container)
    (storageTable : ContainerTable)
    (tableRef : RefValue)
    (cs : CallStack)
    (ms : MachineState)
    -- Preconditions
    (h_table : ms.heap.get? tableRef = some (MoveValue.table storageTable))
    (h_container : ms.heap.get? containerRef = some container)
    (h_lookup : storageTable.lookup containerAddr = some container)
    : run env (registrationStateSingletonSome_PC43 proofRef ownerAddr containerRef storageTable ms) cs ms =
        run env (registrationStateCommonPath_PC55 proofRef ownerAddr ... ms') cs ms' := by
  unfold run
  
  -- Chain PC 43 → PC 44
  rw [step_singletonSome_pc43_copyLoc_containerRef oracle proofRef ownerAddr containerRef storageTable cs ms h_container]
  
  -- Chain PC 44 → PC 45
  rw [step_singletonSome_pc44_readRef_container oracle proofRef ownerAddr containerRef container storageTable cs ms h_container]
  
  -- Chain PC 45 → PC 46
  rw [step_singletonSome_pc45_stLoc_oldContainer ...]
  
  -- Chain PC 46 → PC 47
  rw [step_singletonSome_pc46_mutBorrow ...]
  
  -- Chain PC 47 → PC 48
  rw [step_singletonSome_pc47_updateFields ...]
  
  -- Chain PC 48 → PC 49 (CRITICAL: MoveTo updates heap)
  rw [step_singletonSome_pc48_moveTo_updateTable oracle proofRef ownerAddr containerRef containerAddr old_container new_container storageTable tableRef cs ms h_table h_new_container]
  
  -- Chain PC 49 → PC 50
  rw [step_singletonSome_pc49_cleanup ...]
  
  -- Chain PC 50 → PC 51
  rw [step_singletonSome_pc50_cleanup ...]
  
  -- Chain PC 51 → PC 55 (branch to common path)
  rw [step_singletonSome_pc51_branch_to_common ...]
  
  -- Now at common path PC 55, continue from there
  rfl
```

**Debugging tips:**
- If chaining fails at PC 48, verify heap state `ms'` matches
- If `rfl` fails at the end, check that final state matches `registrationStateCommonPath_PC55`
- Use `#check` to verify hypotheses are in scope

**Estimated time:** 60-90 minutes

---

### Step 6: Integrate into Main Theorem (30-45 minutes)

**Task:** Update the main `verifyRegistrationProof_eval_equiv` theorem to include singleton-some branch

**Location:** Main theorem near end of `EvalEquivRebuild.lean`

**Code template:**

```lean
theorem verifyRegistrationProof_eval_equiv
    (oracle : RegistrationNativeOracle)
    (proofRef : RefValue)
    (cs : CallStack)
    (ms : MachineState)
    : run env (registrationInitialState proofRef) cs ms =
        verifyRegistrationResult oracle proofRef := by
  unfold verifyRegistrationResult
  
  -- ... existing proof for PCs 0-38 ...
  
  -- PC 41: table_with_length.borrow (oracle call)
  cases h_lookup : oracle.lookupContainer containerAddr
  case none =>
    -- Singleton-none branch (already complete)
    exact registration_singleton_none_branch_chain ...
  case some container =>
    -- Singleton-some branch (NEW: this is what we're adding)
    exact registration_singleton_some_branch_chain oracle proofRef ownerAddr containerRef containerAddr container storageTable tableRef cs ms h_table h_container h_lookup
```

**Estimated time:** 30-45 minutes

---

### Step 7: Test and Validate (30-60 minutes)

**Task:** Verify the proof builds without errors and meets performance targets

**Commands:**

```bash
# 1. Full build
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild

# Expected output: Build succeeded in <3 minutes

# 2. Profile build time
./scripts/profile_lean_build.sh MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild

# Expected output: ~3.0s (max 180s)

# 3. Check axiom count
./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild

# Expected output: 10 axioms (all permanent, 0 temporary)

# 4. Run verification suite
./audit/verify-ca.sh --lean --operation registration

# Expected output: All tests pass
```

**Acceptance criteria:**
- ✅ Build succeeds with 0 errors
- ✅ Build time < 3 minutes (target: ~3.0s)
- ✅ 0 temporary axioms (only 10 permanent crypto axioms)
- ✅ All verification tests pass

**If build time > 3 minutes:** Apply performance tuning (see Step 8)

---

### Step 8: Performance Tuning (if needed) (30-60 minutes)

**If build time exceeds 3 minutes, apply these optimizations:**

**Optimization 1: Verify `@[irreducible]` on all state constructors**

```bash
# Check for missing @[irreducible]
grep -n "def registrationStateSingletonSome" EvalEquivRebuild.lean | grep -v "@\[irreducible\]"

# Should output nothing (all states have @[irreducible])
```

**Fix:** Add `@[irreducible]` to any state definitions missing it.

**Expected speedup:** 100× per missing annotation

---

**Optimization 2: Replace bare `simp` with `simp only [...]`**

```bash
# Find bare simp calls
grep -n "simp$" EvalEquivRebuild.lean

# Should output nothing
```

**Fix:** Replace `simp` with `simp only [Array.get?, MachineState.update_heap]` (list specific lemmas)

**Expected speedup:** 5-10× per occurrence

---

**Optimization 3: Batch rewrites instead of individual `rw`**

**Bad (slow):**
```lean
rw [step_pc43_copyLoc]
rw [step_pc44_readRef]
rw [step_pc45_stLoc]
```

**Good (fast):**
```lean
rw [step_pc43_copyLoc, step_pc44_readRef, step_pc45_stLoc]
```

**Expected speedup:** 2-3× per batch

---

**Optimization 4: Use step lemma library instead of manual proofs**

Check if you're duplicating lemmas from `StepLemmas/`:
```bash
grep -n "theorem step_" EvalEquivRebuild.lean | wc -l

# If > 200, you may have duplicates
```

**Fix:** Import and reuse lemmas from `StepLemmas/Basic.lean`, `StepLemmas/Refs.lean`, etc.

**Expected speedup:** 10-20× by reusing pre-compiled lemmas

---

## Common Errors and Solutions

### Error 1: Type Mismatch in Heap Threading

**Symptom:**
```
type mismatch
  ms'
has type
  MachineState
but is expected to have type
  MachineState
```

**Cause:** Heap state `ms'` from PC 48 (MoveTo) not threaded correctly to PC 49

**Solution:** Ensure `ms'` is passed consistently:
```lean
def registrationStateSingletonSome_PC49 ... (ms : MachineState) :=
  { ... }

-- Use ms' (updated heap) not ms
step ... (registrationStateSingletonSome_PC48 ... ms) =
  .ok (registrationStateSingletonSome_PC49 ... ms') ...
```

---

### Error 2: MoveTo Step Lemma Fails

**Symptom:**
```
unsolved goals
⊢ step env ... = .ok ...
```

**Cause:** Table mutation helper lemma not applied or hypothesis missing

**Solution:** Verify hypotheses:
```lean
(h_table : ms.heap.get? tableRef = some (MoveValue.table storageTable))
(h_new_container : new_container = ...)

-- Then apply:
have h_heap : ms'.heap.get? tableRef = some ... := by
  exact step_moveTo_table_update ... h_table
```

---

### Error 3: Chaining Theorem Doesn't Unify

**Symptom:**
```
type mismatch
  registrationStateCommonPath_PC55 ...
has type
  Frame
but is expected to have type
  Frame
```

**Cause:** Final state from PC 51 doesn't match expected state at PC 55

**Solution:** Check that all parameters (proofRef, ownerAddr, etc.) match:
```lean
-- PC 51 final state should match PC 55 initial state
registrationStateSingletonSome_PC51 proofRef ownerAddr ... ms'
registrationStateCommonPath_PC55 proofRef ownerAddr ... ms'  -- must match!
```

---

### Error 4: Build Time > 3 Minutes

**Symptom:**
```
Build succeeded in 4m 32s
```

**Cause:** Missing `@[irreducible]` or using bare `simp`

**Solution:** Apply optimizations from Step 8

**Check:**
```bash
# 1. Count @[irreducible] annotations
grep -c "@\[irreducible\]" EvalEquivRebuild.lean

# Expected: ≥55 (one per PC state)

# 2. Count bare simp
grep -c "simp$" EvalEquivRebuild.lean

# Expected: 0
```

---

## Validation Checklist

Before considering Phase 1 complete, verify:

- [ ] Build succeeds with 0 errors
- [ ] Build time < 3 minutes (target: ~3.0s)
- [ ] 0 temporary axioms (only 10 permanent crypto axioms)
- [ ] Singleton-some branch chains PCs 43-51
- [ ] Main theorem includes both singleton-none and singleton-some branches
- [ ] All verification tests pass: `./audit/verify-ca.sh --lean --operation registration`
- [ ] Performance profiling shows no hot spots: `./scripts/profile_lean_build.sh ...`
- [ ] Code review: All `sorry` removed, all `TODO` resolved
- [ ] Documentation: Updated VERIFICATION_PROGRESS_SUMMARY.md to reflect Phase 1 ✅ 100%

---

## Success Criteria

**Phase 1 is complete when:**

1. **Functionality:**
   - ✅ All 55 PCs proven
   - ✅ Singleton-none branch complete
   - ✅ Singleton-some branch complete (new)
   - ✅ Non-singleton branch complete
   - ✅ Main theorem covers all branches

2. **Performance:**
   - ✅ Build time < 3 minutes (ideally ~3.0s)
   - ✅ No heartbeat budget exceeded warnings

3. **Quality:**
   - ✅ 0 temporary axioms
   - ✅ 10 permanent crypto axioms (documented in TRUST_BOUNDARIES.md)
   - ✅ No `sorry` in code
   - ✅ All tests pass

4. **Documentation:**
   - ✅ VERIFICATION_PROGRESS_SUMMARY.md updated
   - ✅ Git commit with clear message: `formal: complete Phase 1 registration singleton-some branch`

---

## Time Estimates Summary

| Step | Task | Estimated Time |
|------|------|----------------|
| 1 | Define symbolic states (PCs 43-51) | 30-60 min |
| 2 | Write step lemmas for PCs 43-47 | 60-90 min |
| 3 | Write PC 48 MoveTo step lemma (critical) | 90-120 min |
| 4 | Write step lemmas for PCs 49-51 | 30-45 min |
| 5 | Chain singleton-some branch | 60-90 min |
| 6 | Integrate into main theorem | 30-45 min |
| 7 | Test and validate | 30-60 min |
| 8 | Performance tuning (if needed) | 30-60 min |
| **Total** | **End-to-end** | **4-8 hours** |

**Speedup vs unguided:** 3-6× faster (12-24 hours unguided → 4-8 hours with guide)

---

## Next Steps After Phase 1

Once Phase 1 is complete:

1. **Update progress:** Edit `VERIFICATION_PROGRESS_SUMMARY.md`:
   ```markdown
   | Phase 1 | Registration rebuild | ✅ 100% | None | Done |
   ```

2. **Apply ristretto255 patches:** Unblocks Phases 2/3/5 (MSL verification)
   - See `PHASE_0_RISTRETTO255_PATCH_NOTES.md`
   - Estimated: 0.5-1 day

3. **Begin Phase 6:** PC-chaining composition proofs
   - See `PHASE_6_PC_CHAINING_IMPLEMENTATION_GUIDE.md`
   - Estimated: 20-30 hours for all 4 operations

4. **Publish Docker image:** Completes Phase 7
   - See `DOCKER_REPRODUCIBILITY_GUIDE.md`
   - Estimated: 30 minutes

---

## References

### Implementation Guides
- `PHASE_1_SINGLETON_SOME_BRANCH_GUIDE.md` (detailed reference)
- `BEST_PRACTICES_AND_PATTERNS.md` (architecture patterns)
- `NORMALIZATION_COMPLETE_IMPLEMENTATION.md` (simplest operation example)
- `COMPLETE_VERIFICATION_WORKFLOW.md` (end-to-end workflow)

### Reference Documentation
- `LEAN_PROOF_TACTICS_REFERENCE.md` (Lean 4 tactics)
- `ERROR_DIAGNOSIS_GUIDE.md` (troubleshooting)
- `PERFORMANCE_TUNING_DEEP_DIVE.md` (optimization techniques)

### Automation
- `./scripts/profile_lean_build.sh` (build profiling)
- `./scripts/check_axioms.sh` (axiom counting)
- `./audit/verify-ca.sh` (full verification suite)

---

## Getting Help

**If stuck for > 30 minutes on a single error:**

1. Check `ERROR_DIAGNOSIS_GUIDE.md` for the specific error message
2. Review the corresponding section in `PHASE_1_SINGLETON_SOME_BRANCH_GUIDE.md`
3. Compare with the completed singleton-none branch (similar pattern)
4. Verify prerequisites (did you read the referenced files?)

**If build time > 3 minutes:**

1. Apply Step 8 optimizations
2. Profile to find hot spots: `./scripts/profile_lean_build.sh ...`
3. Review `PERFORMANCE_TUNING_DEEP_DIVE.md` case studies

**If axioms > 10:**

1. Check for temporary axioms: `./scripts/check_axioms.sh ...`
2. Replace any `axiom` with `theorem` + proof
3. Ensure only permanent crypto axioms remain (see `TRUST_BOUNDARIES.md`)

---

**Good luck! Phase 1 completion is the final major Lean milestone before Phase 6.**
