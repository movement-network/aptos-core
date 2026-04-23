# Phase 1 Singleton-Some Branch Complete Implementation Guide

**Status:** Complete guide for finishing Registration singleton-some branch (final 5% of Phase 1)  
**Audience:** Verification engineers completing Phase 1  
**Current state:** 95% complete - singleton-some branch PC-level proofs outstanding  
**Estimated completion time:** 1-2 days (8-16 hours)

## Overview

The Registration rebuild (`EvalEquivRebuild.lean`, ~3330 lines, 197 theorems) is 95% complete. The singleton-some branch handles registration when a container store already exists for the account. This is the last remaining piece before Phase 1 is fully complete.

**What's done (95%):**
- ✅ `@[irreducible]` symbolic state + projection suite
- ✅ `eval_registration_eq_run` entry point theorem
- ✅ PC-lookup lemmas
- ✅ All 55 non-native PCs proved
- ✅ All 28 native-call happy-path PCs proved + 10 error-path variants
- ✅ Complete per-function descriptor suite (51 `@[simp]` lemmas)
- ✅ Composition theorems - early-error, 2-PC / 3-PC happy-path
- ✅ Complete non-singleton branch
- ✅ 16 functional-sim shape reductions
- ✅ Singleton-none branch complete

**What's outstanding (5%):**
- 🟡 Singleton-some branch PC-level proofs (container store mutation threading)
- 🟡 Final shape lemma for singleton-some success path

**File:** `lean/MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean`

## 1. Architecture Overview

### 1.1 The Three Execution Branches

Registration has three distinct execution paths based on container table state:

**Branch A: Non-singleton container** (✅ COMPLETE)
- Container table has multiple accounts
- New entry added to existing table
- No special handling needed
- Lines 2200-2400 in EvalEquivRebuild.lean

**Branch B: Singleton container, no existing store** (✅ COMPLETE)
- Container table has exactly one slot
- Slot is empty (None)
- Store created and inserted
- Lines 2400-2600 in EvalEquivRebuild.lean

**Branch C: Singleton container, existing store** (🟡 OUTSTANDING)
- Container table has exactly one slot
- Slot already contains a store (Some)
- Must handle MoveTo with existing value
- Lines 2600-2800 in EvalEquivRebuild.lean (current sorry placeholders)

**This guide focuses on Branch C.**

### 1.2 The Container Store Mutation Challenge

**Key difficulty:** When the singleton container already has a store, the `MoveTo` operation must:
1. Read the existing store from the container
2. Update the container entry with new store
3. Thread the updated `MoveStore` through all subsequent PCs

**Lean representation:**
```lean
-- Before MoveTo (PC 47)
ms : MoveStore
container : Container ConfidentialAssetStore = { entries := [(addr, some oldStore)] }

-- After MoveTo (PC 48)
ms' : MoveStore
container' : Container ConfidentialAssetStore = { entries := [(addr, some newStore)] }

-- All subsequent PCs must use ms' not ms
```

**Pattern from non-singleton branch:**
```lean
-- The MoveTo step theorem
theorem step_pc48_moveTo_singleton_some
    (addr : Address)
    (oldStore : ConfidentialAssetStore)
    (newStore : ConfidentialAssetStore)
    (h_container : cs.containers[containerIdx] = Container.singleton addr (some oldStore))
    : step env (registrationState 48 proofRef addr) cs ms = 
        .ok (registrationState 49 proofRef addr) cs' ms'
  where
    cs' = cs.update_container containerIdx (Container.singleton addr (some newStore))
    ms' = ms  -- No heap change for container update
:= by
  rw [registrationState, registrationState]
  rw [step_moveTo]
  -- Show container update
  simp only [h_container, Container.update, ...]
  rfl
```

### 1.3 Current State Analysis

**Lines 2780-2850:** Singleton-some branch structure
```lean
-- Current code (with sorry placeholders)
theorem registration_eval_equiv_functional_sim ... := by
  ...
  -- Non-singleton branch: COMPLETE
  case blockA_non_singleton => ...
  
  -- Singleton-none branch: COMPLETE
  case blockB_singleton_none => ...
  
  -- Singleton-some branch: OUTSTANDING
  case blockC_singleton_some =>
    -- Need to prove: run through PCs 45-55 with container update at PC 48
    sorry
```

**What exists:**
- Shape lemma declaration: `registration_shape_blockC_singleton_some_success`
- Branch entry point: Case split at PC 45 (container table load)
- Missing: PC-chaining from PC 45 → PC 55 with container mutation at PC 48

## 2. Step-by-Step Implementation Plan

### 2.1 Phase 1: Understand the Existing Pattern

**Read the non-singleton branch proof** (lines 2200-2400):

Key elements:
1. **Container load at PC 45:**
   ```lean
   theorem step_pc45_load_container_non_singleton
       (container : Container ConfidentialAssetStore)
       (h_container : cs.containers[containerIdx] = container)
       (h_non_singleton : ¬container.is_singleton)
       : step env (registrationState 45 ...) cs ms = 
           .ok (registrationState 46 ...) cs ms
   ```

2. **MoveTo at PC 48** (non-singleton case):
   ```lean
   theorem step_pc48_moveTo_non_singleton
       (container : Container ConfidentialAssetStore)
       : step env (registrationState 48 ...) cs ms = 
           .ok (registrationState 49 ...) cs' ms
     where cs' = cs.add_to_container containerIdx addr newStore
   ```

3. **Chaining PC 45 → PC 55:**
   ```lean
   theorem registration_run_blockA_non_singleton
       : run env (registrationState 45 ...) fuel cs ms =
           .returned [] cs' ms
   ```

**Pattern to reuse:**
- Load container at PC 45
- Check singleton condition at PC 46-47
- MoveTo at PC 48 (but different for singleton-some)
- Chain remaining PCs 49-55

### 2.2 Phase 2: Define Singleton-Some Step Theorems

**Step 1: PC 45 container load (singleton-some variant)**

Create a new step theorem variant:
```lean
theorem step_pc45_load_container_singleton_some
    (addr : Address)
    (oldStore : ConfidentialAssetStore)
    (h_container : cs.containers[containerIdx] = Container.singleton addr (some oldStore))
    : step env (registrationState 45 proofRef addr) cs ms = 
        .ok (registrationState 46 proofRef addr) cs ms
:= by
  rw [registrationState, registrationState]
  rw [step_immBorrowLoc]  -- Borrow container table
  simp only [h_container, Array.get?, ...]
  rfl
```

**Step 2: PC 46 singleton check**

```lean
theorem step_pc46_check_singleton_some
    (addr : Address)
    (oldStore : ConfidentialAssetStore)
    (h_singleton : container.is_singleton)
    : step env (registrationState 46 proofRef addr) cs ms = 
        .ok (registrationState 47 proofRef addr) cs ms
:= by
  rw [registrationState, registrationState]
  rw [step_branch]  -- Branch on is_singleton
  simp only [h_singleton, if_true, ...]
  rfl
```

**Step 3: PC 47 check existing entry**

```lean
theorem step_pc47_check_existing_some
    (addr : Address)
    (oldStore : ConfidentialAssetStore)
    (h_entry : container.entries[addr] = some oldStore)
    : step env (registrationState 47 proofRef addr) cs ms = 
        .ok (registrationState 48 proofRef addr) cs ms
:= by
  rw [registrationState, registrationState]
  rw [step_call_native]  -- Call container_table_contains
  simp only [h_entry, Option.isSome, ...]
  rfl
```

**Step 4: PC 48 MoveTo (the key step)**

This is where container mutation happens:

```lean
theorem step_pc48_moveTo_singleton_some
    (addr : Address)
    (oldStore : ConfidentialAssetStore)
    (newStore : ConfidentialAssetStore)
    (h_container : cs.containers[containerIdx] = Container.singleton addr (some oldStore))
    (h_newStore : newStore = construct_new_store proofRef)
    : step env (registrationState 48 proofRef addr) cs ms = 
        .ok (registrationState 49 proofRef addr) cs' ms
  where
    cs' = cs.update_container containerIdx (Container.singleton addr (some newStore))
:= by
  rw [registrationState, registrationState]
  rw [step_moveTo]
  
  -- Unfold MoveTo semantics for container update
  unfold MoveStore.moveTo_container
  simp only [h_container, h_newStore]
  
  -- Show container update
  unfold ContainerStore.update_container
  simp only [Array.set, ...]
  
  -- Locals unchanged (only container updated)
  simp only [registrationState_locals, ...]
  
  rfl
```

**Step 5: PCs 49-55 (unchanged from other branches)**

These PCs don't touch containers, so they're identical to non-singleton branch:

```lean
theorem step_pc49_moveLoc_singleton_some
    : step env (registrationState 49 proofRef addr) cs' ms = 
        .ok (registrationState 50 proofRef addr) cs' ms
:= step_pc49_moveLoc  -- Reuse existing theorem

-- (Similarly for PCs 50-54)

theorem step_pc55_ret_singleton_some
    : step env (registrationState 55 proofRef addr) cs' ms = 
        .returned [] cs' ms
:= step_pc55_ret  -- Reuse existing theorem
```

### 2.3 Phase 3: Build PC-Chaining Lemma

**Create intermediate chaining lemma:**

```lean
theorem registration_run_blockC_singleton_some
    (addr : Address)
    (oldStore : ConfidentialAssetStore)
    (newStore : ConfidentialAssetStore)
    (fuel : Nat)
    (h_fuel : fuel ≥ 11)
    (h_container : cs.containers[containerIdx] = Container.singleton addr (some oldStore))
    (h_newStore : newStore = construct_new_store proofRef)
    : run env (registrationState 45 proofRef addr) fuel cs ms =
        .returned [] cs' ms
  where
    cs' = cs.update_container containerIdx (Container.singleton addr (some newStore))
:= by
  -- Chain PCs 45-55
  have h45 : step env (registrationState 45 proofRef addr) cs ms = 
               .ok (registrationState 46 proofRef addr) cs ms := 
    step_pc45_load_container_singleton_some h_container
  
  have h46 : step env (registrationState 46 proofRef addr) cs ms = 
               .ok (registrationState 47 proofRef addr) cs ms := 
    step_pc46_check_singleton_some ...
  
  have h47 : step env (registrationState 47 proofRef addr) cs ms = 
               .ok (registrationState 48 proofRef addr) cs ms := 
    step_pc47_check_existing_some ...
  
  have h48 : step env (registrationState 48 proofRef addr) cs ms = 
               .ok (registrationState 49 proofRef addr) cs' ms := 
    step_pc48_moveTo_singleton_some h_container h_newStore
  
  -- Now cs' (updated container) is threaded through remaining PCs
  have h49 : step env (registrationState 49 proofRef addr) cs' ms = 
               .ok (registrationState 50 proofRef addr) cs' ms := 
    step_pc49_moveLoc_singleton_some
  
  -- ... (PCs 50-54) ...
  
  have h55 : step env (registrationState 55 proofRef addr) cs' ms = 
               .returned [] cs' ms := 
    step_pc55_ret_singleton_some
  
  -- Chain all steps via run_succ_ok_of_step
  calc run env (registrationState 45 proofRef addr) fuel cs ms
      = run env (registrationState 46 proofRef addr) (fuel - 1) cs ms := 
          by rw [run_succ_ok_of_step h45]; omega
    _ = run env (registrationState 47 proofRef addr) (fuel - 2) cs ms := 
          by rw [run_succ_ok_of_step h46]; omega
    _ = run env (registrationState 48 proofRef addr) (fuel - 3) cs ms := 
          by rw [run_succ_ok_of_step h47]; omega
    _ = run env (registrationState 49 proofRef addr) (fuel - 4) cs' ms := 
          by rw [run_succ_ok_of_step h48]; omega  -- cs becomes cs' here
    _ = run env (registrationState 50 proofRef addr) (fuel - 5) cs' ms := 
          by rw [run_succ_ok_of_step h49]; omega
    -- ... (continue for PCs 50-54) ...
    _ = run env (registrationState 55 proofRef addr) (fuel - 10) cs' ms := 
          by apply run_through_pc54_from_pc50; exact h_fuel
    _ = .returned [] cs' ms := 
          by rw [run_succ]; rw [h55]; simp
```

### 2.4 Phase 4: Complete Shape Lemma

**Update the existing shape lemma declaration:**

```lean
theorem registration_shape_blockC_singleton_some_success
    (oracle : RegistrationNativeOracle)
    (proofRef : RefValue)
    (addr : Address)
    (oldStore : ConfidentialAssetStore)
    (newStore : ConfidentialAssetStore)
    (h_container : cs.containers[containerIdx] = Container.singleton addr (some oldStore))
    (h_newStore : newStore = construct_new_store oracle proofRef)
    (h_schnorr : oracle.verifySchnorrSignature proofRef = some true)
    (h_hmac : oracle.verifyHMAC proofRef = some true)
    -- ... (other oracle success conditions) ...
    : verifyRegistrationBytecodeResult oracle proofRef addr cs ms =
        .returned [] (cs', ms)
  where
    cs' = cs.update_container containerIdx (Container.singleton addr (some newStore))
:= by
  unfold verifyRegistrationBytecodeResult
  
  -- Unfold functional sim definition
  -- (should reduce to .returned [] given all oracle success conditions)
  
  simp only [h_schnorr, h_hmac, ...]
  simp only [if_true, ...]
  
  -- Final result
  rfl
```

### 2.5 Phase 5: Integrate into Top-Level Theorem

**Update the main composition theorem:**

```lean
theorem registration_eval_equiv_functional_sim
    (oracle : RegistrationNativeOracle)
    (proofRef : RefValue)
    (addr : Address)
    (fuel : Nat)
    (h_fuel : fuel ≥ 56)
    (initMs : MoveStore)
    : (eval register fuel initMs).dropMs = 
        verifyRegistrationBytecodeResult oracle proofRef addr cs initMs
:= by
  rw [eval_registration_eq_run]
  
  -- Branch on container table state
  cases h_container : cs.containers[containerIdx] with
  | empty => -- Error path (no container)
    apply registration_shape_error_no_container
    exact h_container
  
  | non_singleton entries => -- Branch A: Non-singleton (COMPLETE)
    apply registration_shape_blockA_non_singleton
    exact h_container
  
  | singleton addr_in_container entry_opt =>
    -- Further branch on entry_opt
    cases entry_opt with
    | none => -- Branch B: Singleton-none (COMPLETE)
      apply registration_shape_blockB_singleton_none
      exact h_container
    
    | some oldStore => -- Branch C: Singleton-some (WE ARE HERE)
      -- Use the PC-chaining lemma from Phase 3
      have h_run : run env (registrationState 45 proofRef addr) fuel cs initMs =
                     .returned [] cs' initMs :=
        registration_run_blockC_singleton_some oracle proofRef addr oldStore newStore fuel h_fuel h_container h_newStore
      
      -- Connect run result to functional sim via shape lemma
      rw [h_run]
      apply registration_shape_blockC_singleton_some_success
      exact h_container
      exact h_newStore
      -- Pass oracle success hypotheses
      exact h_schnorr
      exact h_hmac
      -- ...
```

## 3. Detailed Implementation Walkthrough

### 3.1 File Location and Structure

**File:** `lean/MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean`

**Relevant sections:**
- Lines 1-500: Imports, state definitions, constants
- Lines 500-2200: Per-PC step theorems (55 PCs × ~20 lines each)
- Lines 2200-2400: Non-singleton branch proof (Branch A) - ✅ REFERENCE
- Lines 2400-2600: Singleton-none branch proof (Branch B) - ✅ REFERENCE
- Lines 2600-2800: Singleton-some branch proof (Branch C) - 🟡 TARGET
- Lines 2800-3000: Functional sim shape lemmas
- Lines 3000-3330: Top-level composition theorem

### 3.2 Step Theorem Template

**For each PC in the singleton-some path (PCs 45-55):**

```lean
theorem step_pcN_<instr>_singleton_some
    (addr : Address)
    (oldStore : ConfidentialAssetStore)
    (newStore : ConfidentialAssetStore)
    (cs : ContainerStore)  -- Or cs' after PC 48
    (h_container : cs.containers[containerIdx] = Container.singleton addr (some oldStore))
    -- ... other hypotheses ...
    : step env (registrationState N proofRef addr) cs ms = 
        .ok (registrationState (N+1) proofRef addr) cs' ms'
  where
    cs' = ... -- Container update if N == 48, else unchanged
    ms' = ms  -- Heap unchanged for container operations
:= by
  rw [registrationState, registrationState]
  rw [step_<instr>]  -- Specific instruction (immBorrowLoc, branch, moveTo, etc.)
  
  -- Instruction-specific reasoning
  simp only [h_container, ...]
  
  -- Close with reflexivity or specific tactic
  rfl
```

### 3.3 Container Update Mechanics

**Key Lean definitions (from MoveModel):**

```lean
structure ContainerStore where
  containers : Array (Option Container)

structure Container (T : Type) where
  entries : HashMap Address (Option T)

-- Container update operation
def ContainerStore.update_container (cs : ContainerStore) (idx : Nat) (new_container : Container T) : ContainerStore :=
  { cs with containers := cs.containers.set idx (some new_container) }

-- Singleton container helper
def Container.singleton (addr : Address) (value : Option T) : Container T :=
  { entries := HashMap.singleton addr value }
```

**At PC 48 (MoveTo with existing entry):**

```lean
-- Before
cs.containers[containerIdx] = Container.singleton addr (some oldStore)

-- After
cs'.containers[containerIdx] = Container.singleton addr (some newStore)

-- Lean expression
cs' = cs.update_container containerIdx (Container.singleton addr (some newStore))
```

### 3.4 Proof Tactics Cheat Sheet

**For container-related PCs:**

**Tactic 1: Unfolding container operations**
```lean
unfold ContainerStore.update_container
unfold Container.singleton
```

**Tactic 2: Simplifying container lookups**
```lean
simp only [HashMap.get, HashMap.singleton, ...]
```

**Tactic 3: Array indexing**
```lean
simp only [Array.get?, Array.set, ...]
```

**Tactic 4: Option unwrapping**
```lean
simp only [Option.some_bind, Option.map, ...]
```

**Tactic 5: Conditional reasoning**
```lean
cases h : condition
· -- false case
  simp [if_false]
· -- true case
  simp [if_true]
```

### 3.5 Common Pitfalls and Solutions

**Pitfall 1: Container Store vs Move Store Confusion**

**Problem:** Mixing up `cs : ContainerStore` (for object tables) and `ms : MoveStore` (for heap).

**Solution:** Container mutations update `cs`, heap mutations update `ms`. For Registration, only `cs` changes (via MoveTo to container table). `ms` is unchanged.

**Pitfall 2: Forgetting to Thread Updated Container**

**Problem:** After PC 48, subsequent PCs use `cs` instead of `cs'`.

**Solution:** All step theorems for PCs 49-55 must take `cs'` as input:
```lean
theorem step_pc49_moveLoc_singleton_some
    : step env (registrationState 49 ...) cs' ms = ...  -- cs' not cs!
```

**Pitfall 3: Hypothesis Naming Conflicts**

**Problem:** Multiple `h_container` hypotheses in scope with different values.

**Solution:** Use unique names:
```lean
-- PC 45
h_container_pre : cs.containers[containerIdx] = Container.singleton addr (some oldStore)

-- PC 48
h_container_post : cs'.containers[containerIdx] = Container.singleton addr (some newStore)
```

**Pitfall 4: Fuel Arithmetic Errors**

**Problem:** Fuel bounds don't match PC count.

**Solution:** For PCs 45-55 (11 PCs), need `fuel ≥ 11`. Use `omega` tactic:
```lean
have h_fuel_pc50 : fuel - 5 ≥ 6 := by omega
```

## 4. Testing and Validation

### 4.1 Per-Step Testing

**After writing each step theorem, test immediately:**

```bash
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
```

**Expected:** Build succeeds in <5s if step theorem is correct.

**If build fails:** Check error message for:
- Type mismatch (cs vs cs', ms vs ms')
- Missing hypothesis
- Incorrect state constructor argument

### 4.2 Incremental Integration Testing

**After completing PC-chaining lemma (Phase 3):**

```bash
lake build MovementFormal.Experimental.ConfidentialAsset.Registration
```

**Expected:** Builds with 1 sorry remaining (shape lemma connection).

**Test axiom count:**
```bash
./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Registration
```

**Expected output:**
```
Total axioms: 23
Temporary axioms: 1  # registration_eval_equiv_functional_sim (will be 0 when complete)
```

### 4.3 Final Validation

**After completing shape lemma (Phase 4) and integration (Phase 5):**

```bash
lake build MovementFormal.Experimental.ConfidentialAsset.Registration
```

**Expected:** Zero errors, zero warnings, zero sorry.

**Axiom check:**
```bash
./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Registration
```

**Expected output:**
```
Total axioms: 22  # Only permanent crypto axioms
Temporary axioms: 0  # ← KEY: Should be 0 now!
```

**Build time check:**
```bash
time lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
```

**Expected:** <3 minutes (Phase 1 acceptance criterion).

### 4.4 Regression Testing

**Test downstream dependencies:**

```bash
lake build MovementFormal.Experimental.ConfidentialAsset.Refinement
lake build MovementFormal.Experimental.ConfidentialAsset.EndToEnd
lake build MovementFormal.Experimental.ConfidentialAsset.BytecodeDifftestBridge
```

**Expected:** All build without modification (these depend on the public `registration_eval_equiv_functional_sim` theorem, which we just completed).

## 5. Estimated Timeline

### 5.1 Time Budget Breakdown

**Day 1 (4-6 hours):**
- [ ] Phase 2: Define singleton-some step theorems (PCs 45-48) - 2 hours
- [ ] Phase 2: Define remaining step theorems (PCs 49-55) - 1 hour
- [ ] Phase 3: Build PC-chaining lemma - 2 hours
- [ ] Testing and debugging - 1 hour

**Day 2 (4-6 hours):**
- [ ] Phase 4: Complete shape lemma - 2 hours
- [ ] Phase 5: Integrate into top-level theorem - 1 hour
- [ ] Final validation and testing - 1 hour
- [ ] Documentation and cleanup - 1 hour

**Total:** 8-12 hours over 1-2 days

### 5.2 Risk Mitigation

**Risk 1: Container update semantics unclear**
- Mitigation: Study non-singleton branch proof (lines 2200-2400) for reference
- Fallback: Consult with team lead on container table semantics

**Risk 2: Fuel arithmetic errors**
- Mitigation: Use `omega` tactic liberally, add explicit fuel hypotheses
- Fallback: Add intermediate chaining lemmas for smaller PC ranges

**Risk 3: Build time exceeds 3-minute budget**
- Mitigation: Ensure `@[irreducible]` on state definitions, use `simp only` not bare `simp`
- Fallback: Profile with `set_option trace.profiler true`, optimize hot spots

## 6. Success Criteria (Phase 1 Complete)

### 6.1 Primary Criteria

- ✅ Zero `sorry` in EvalEquivRebuild.lean
- ✅ Zero temporary axioms (only 22 permanent crypto axioms)
- ✅ Build time ≤ 3 minutes for EvalEquivRebuild.lean
- ✅ Full CA Lean tree builds in ≤ 10 minutes
- ✅ Downstream dependencies build unchanged

### 6.2 Verification Criteria

- ✅ All 197 theorems proved (no axiom stubs)
- ✅ Singleton-some branch covers all PCs 45-55
- ✅ Container mutation correctly threaded through PCs
- ✅ Shape lemma connects bytecode result to functional sim

### 6.3 Documentation Criteria

- ✅ Comments explain singleton-some branch structure
- ✅ Commit message references this guide
- ✅ Update CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md Phase 1 status to ✅ COMPLETE

## 7. Next Steps After Phase 1

### 7.1 Immediate (Week 1)

- Update verification plan (§0 progress tracker) to mark Phase 1 ✅ COMPLETE
- Measure actual build time and update plan (replace "target ≤3 min" with measured value)
- Run axiom baseline check and commit `registration-axioms-baseline.txt`

### 7.2 Short-term (Week 2-4)

- Begin Phase 6 (Normalization composition proof, estimated 3-5 hours)
- Apply singleton-some pattern to other operations if needed
- Profile build time across full CA tree, optimize if >10 min

### 7.3 Medium-term (Month 2)

- Complete Phase 6 for all 4 operations (Normalization, Withdrawal, Rotation, Transfer)
- Unblock MSL verification (ristretto255 patches)
- Expand difftest corpus to 95%+ coverage

## Appendix A: Quick Reference

### A.1 Key File Locations

```
lean/MovementFormal/
  Experimental/ConfidentialAsset/
    Registration/
      EvalEquivRebuild.lean         # Main file (lines 2600-2800 = target)
      Phase6Composition.lean        # Downstream (should build unchanged)
  MoveModel/
    StepLemmas/
      Run.lean                      # run_succ_ok_of_step lemma
      Calls.lean                    # step_moveTo lemma
```

### A.2 Key Theorems to Reference

```lean
-- From MoveModel/StepLemmas/Run.lean
run_succ_ok_of_step : 
  step env f1 cs1 ms = .ok f2 cs2 ms →
  run env f2 n cs2 ms = res →
  run env f1 (n+1) cs1 ms = res

-- From Registration/EvalEquivRebuild.lean (existing, reuse)
step_pc49_moveLoc : step env (registrationState 49 ...) cs ms = ...
step_pc50_ldLoc : step env (registrationState 50 ...) cs ms = ...
-- ... (all PCs 49-55 already have generic versions)

step_pc55_ret : step env (registrationState 55 ...) cs ms = .returned [] cs ms
```

### A.3 Common Lean Tactics

```lean
rw [theorem_name]              -- Rewrite with theorem
simp only [lemma1, lemma2]     -- Simplify with specific lemmas
omega                          -- Solve arithmetic goals
rfl                            -- Reflexivity (close definitional equality)
cases h : expr                 -- Case split on expression
unfold definition              -- Unfold definition
exact hypothesis               -- Apply hypothesis directly
```

### A.4 Build Commands

```bash
# Build just the modified file
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild

# Build full Registration module
lake build MovementFormal.Experimental.ConfidentialAsset.Registration

# Build full CA tree
lake build MovementFormal.Experimental.ConfidentialAsset

# Check axioms
./scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Registration

# Time the build
time lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
```

## Appendix B: Example Code Snippets

### B.1 Complete Step Theorem Example (PC 48 MoveTo)

```lean
theorem step_pc48_moveTo_singleton_some
    (oracle : RegistrationNativeOracle)
    (proofRef : RefValue)
    (addr : Address)
    (oldStore : ConfidentialAssetStore)
    (newStore : ConfidentialAssetStore)
    (cs : ContainerStore)
    (ms : MoveStore)
    (h_container : cs.containers[containerIdx] = some (Container.singleton addr (some oldStore)))
    (h_newStore : newStore = ConfidentialAssetStore.from_registration_proof oracle proofRef addr)
    : step env (registrationState 48 proofRef addr) cs ms = 
        .ok (registrationState 49 proofRef addr) cs' ms
  where
    cs' = cs.update_container containerIdx (Container.singleton addr (some newStore))
:= by
  -- Unfold state definitions
  rw [registrationState, registrationState]
  
  -- Apply MoveTo step lemma
  rw [step_moveTo]
  
  -- Expand container update
  unfold ContainerStore.update_container
  unfold Container.singleton
  
  -- Simplify with hypotheses
  simp only [h_container, h_newStore]
  
  -- Simplify array operations
  simp only [Array.set, Array.get?, ...]
  
  -- Simplify locals (unchanged)
  simp only [registrationState_locals, ...]
  
  -- Close
  rfl
```

### B.2 PC-Chaining Calc Block Example

```lean
calc run env (registrationState 45 proofRef addr) fuel cs ms
    = run env (registrationState 46 proofRef addr) (fuel - 1) cs ms := by
        rw [run_succ_ok_of_step (step_pc45_load_container_singleton_some h_container)]
        omega
  _ = run env (registrationState 47 proofRef addr) (fuel - 2) cs ms := by
        rw [run_succ_ok_of_step (step_pc46_check_singleton_some ...)]
        omega
  _ = run env (registrationState 48 proofRef addr) (fuel - 3) cs ms := by
        rw [run_succ_ok_of_step (step_pc47_check_existing_some ...)]
        omega
  _ = run env (registrationState 49 proofRef addr) (fuel - 4) cs' ms := by
        rw [run_succ_ok_of_step (step_pc48_moveTo_singleton_some h_container h_newStore)]
        omega
  -- cs becomes cs' after PC 48
  _ = run env (registrationState 50 proofRef addr) (fuel - 5) cs' ms := by
        rw [run_succ_ok_of_step (step_pc49_moveLoc)]
        omega
  -- ... (continue for PCs 50-54) ...
  _ = run env (registrationState 55 proofRef addr) (fuel - 10) cs' ms := by
        apply run_through_pc54_from_pc50
        omega
  _ = .returned [] cs' ms := by
        rw [run_succ]
        rw [step_pc55_ret]
        simp
```

## Summary

**Phase 1 Completion Path:**
1. Define 11 step theorems for singleton-some branch (PCs 45-55)
2. Build PC-chaining lemma connecting PCs 45 → 55 with container update at PC 48
3. Complete shape lemma for singleton-some success case
4. Integrate into top-level composition theorem
5. Validate: zero sorry, zero temporary axioms, <3 min build time

**Estimated time:** 1-2 days (8-16 hours)

**Key challenges:**
- Threading updated container store through PCs 49-55 after PC 48
- Fuel arithmetic for 11-PC chain
- Connecting bytecode result to functional sim via shape lemma

**Success indicators:**
- ✅ Phase 1 status: 95% → 100%
- ✅ `./scripts/check_axioms.sh` shows 0 temporary axioms
- ✅ `time lake build ...EvalEquivRebuild` completes in <3 minutes
- ✅ Full CA Lean tree builds in <10 minutes

**Next:** Phase 6 (composition proofs for 4 operations, 20-30 hours total)
