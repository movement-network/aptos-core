# Phase 1 Singleton Branch Implementation Starter Kit

**Last updated:** 2026-04-22  
**Purpose:** Complete implementation guide with templates for Phase 1 singleton branch  
**Status:** Ready to implement (workarounds documented, automation ready)  
**Estimated effort:** 5-7 days with sub-lemma splitting approach

---

## Executive Summary

**Context:** Phase 1 is 95% complete. Outstanding: singleton-some branch PC-level proofs (~50 PCs covering container-store mutation logic).

**Blocker:** Elaborator performance on long PC chains (see ELABORATOR_PERFORMANCE_WORKAROUNDS.md).

**Solution:** Split into 3 sub-lemmas (~17 PCs each) using Workaround 1 (split into sub-lemmas).

**This starter kit provides:**
- Complete 7-day implementation roadmap
- Generated Lean scaffolds (via automation script)
- State definition templates
- Proof body patterns
- Testing checkpoints

**Impact:** Completes Phase 1 → 100%, eliminates last TEMPORARY axiom (`registration_eval_equiv_functional_sim`).

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Day-by-Day Roadmap](#day-by-day-roadmap)
4. [State Definitions (Template)](#state-definitions-template)
5. [Sub-Lemma 1: Container Setup (PCs 0-16)](#sub-lemma-1-container-setup-pcs-0-16)
6. [Sub-Lemma 2: Container Write (PCs 17-33)](#sub-lemma-2-container-write-pcs-17-33)
7. [Sub-Lemma 3: Publish + Return (PCs 34-49)](#sub-lemma-3-publish--return-pcs-34-49)
8. [Composition Theorem](#composition-theorem)
9. [Testing Strategy](#testing-strategy)
10. [Acceptance Criteria](#acceptance-criteria)

---

## Prerequisites

### ✅ 1. Read Background Documents

- **ELABORATOR_PERFORMANCE_WORKAROUNDS.md:** Understand why sub-lemma splitting is needed
- **PROOF_PATTERNS_LIBRARY.md:** Review per-PC step patterns
- **Registration/EvalEquivRebuild.lean:** Understand existing non-singleton branch proof structure

---

### ✅ 2. Generate Scaffolds

```bash
cd aptos-move/framework/formal

# Generate 3 sub-lemma scaffolds for singleton branch (50 PCs total)
./scripts/generate_pc_range_lemmas.sh \
  --operation registration_singleton \
  --pcs 50 \
  --chunk-size 17 \
  --output lean/MovementFormal/Experimental/ConfidentialAsset/Registration/SingletonBranch.lean
```

**Output:** `SingletonBranch.lean` with scaffolds for:
- `registration_singleton_pcs_0_16` (setup)
- `registration_singleton_pcs_17_33` (write)
- `registration_singleton_pcs_34_49` (publish)
- `registration_singleton_eval_equiv` (composition)

---

### ✅ 3. Set Up Development Environment

```bash
cd lean

# Ensure mathlib cache is warm
lake exe cache get

# Build existing Registration files to baseline
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild

# Expected: ~3s build time (no errors)
```

---

## Architecture Overview

### File Structure

```
lean/MovementFormal/Experimental/ConfidentialAsset/Registration/
├── EvalEquiv.lean            # Existing (axiom stub)
├── EvalEquivRebuild.lean     # Existing (non-singleton branch complete)
├── SingletonBranch.lean      # NEW (this starter kit creates this)
└── FunctionalSim.lean        # Existing (mathematical spec)
```

### Proof Strategy

**Current state:**
- `registration_eval_equiv_functional_sim` is a TEMPORARY axiom
- Non-singleton branch is complete (~3000 lines, 197 theorems)
- Singleton branch is pending (~500 lines estimated)

**Approach:**
1. Prove singleton branch in `SingletonBranch.lean` (3 sub-lemmas)
2. Replace axiom with theorem in `EvalEquiv.lean` (compose non-singleton + singleton)
3. Delete TEMPORARY axiom marker

**Build target:** `SingletonBranch.lean` builds in <5s (acceptance criterion).

---

## Day-by-Day Roadmap

### Day 1: Setup + State Definitions

**Morning (4h):**
1. Generate scaffolds (see Prerequisites §2)
2. Review scaffold structure
3. Define `@[irreducible]` state definitions (see templates below)
4. Add projection lemmas for each state

**Afternoon (4h):**
5. Verify state definitions type-check
6. Write unit tests for state projections
7. Document state transition invariants

**Checkpoint:** All 4 state definitions (`singletonState0`, `singletonState17`, `singletonState34`, `singletonState50`) compile and have projection lemmas.

---

### Day 2-3: Sub-Lemma 1 (Container Setup, PCs 0-16)

**Day 2 Morning (4h):**
1. Implement PC 0-8 (dispatcher + early setup steps)
2. Use step-lemma library (`step_ldU64`, `step_stLoc`, etc.)
3. Build incrementally (add 2-3 PCs, build, repeat)

**Day 2 Afternoon (4h):**
4. Implement PC 9-16 (container creation + initialization)
5. Handle `borrowGlobal`, `newContainerRef` steps
6. Add intermediate state assertions

**Day 3 Morning (4h):**
7. Complete proof body for `registration_singleton_pcs_0_16`
8. Replace `sorry` with actual `run_chain` composition
9. Test build: `lake build .SingletonBranch` (expect <2s)

**Checkpoint:** `registration_singleton_pcs_0_16` proves with no `sorry`, builds in <2s.

---

### Day 4-5: Sub-Lemma 2 (Container Write, PCs 17-33)

**Day 4 (8h):**
1. Implement PC 17-25 (write preparation)
2. Implement PC 26-33 (actual container mutation)
3. Focus on: `writeRef`, `packStruct`, `storeGlobal` steps
4. Handle ownership transfer (container `&mut` → global store)

**Day 5 Morning (4h):**
5. Complete proof body for `registration_singleton_pcs_17_33`
6. Replace `sorry` with composition
7. Test build (expect <2s)

**Checkpoint:** `registration_singleton_pcs_17_33` proves with no `sorry`, builds in <2s.

---

### Day 6: Sub-Lemma 3 (Publish + Return, PCs 34-49)

**Morning (4h):**
1. Implement PC 34-41 (publish container to global store)
2. Use `moveToSender`, `ret` steps
3. Handle cleanup (drop temporary refs)

**Afternoon (4h):**
4. Implement PC 42-49 (final return + cleanup)
5. Complete proof body for `registration_singleton_pcs_34_49`
6. Test build (expect <2s)

**Checkpoint:** `registration_singleton_pcs_34_49` proves with no `sorry`, builds in <2s.

---

### Day 7: Composition + Integration

**Morning (2h):**
1. Implement composition theorem `registration_singleton_eval_equiv`
2. Chain 3 sub-lemmas via `run_trans`
3. Match result to FunctionalSim via shape lemmas

**Afternoon (2h):**
4. Update `EvalEquiv.lean`: replace axiom with theorem
5. Full build test: `lake build .Registration.EvalEquiv`
6. Axiom check: `#print axioms registration_eval_equiv_functional_sim`

**Final Checks (4h):**
7. Run `./audit/verify-ca.sh --op register --stack lean` (expect <3 min)
8. Update AXIOM_INVENTORY.md (remove TEMPORARY axiom)
9. Update axiom baseline: `./scripts/track_axiom_drift.sh --baseline`
10. Create PR with metrics (build time, axiom diff, LoC)

**Checkpoint:** Phase 1 → 100% complete, TEMPORARY axiom eliminated, full tree builds in <5s.

---

## State Definitions (Template)

### Pattern: @[irreducible] + Projection Lemmas

```lean
-- SingletonBranch.lean

import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

open MoveModel

-- ============================================================================
-- Intermediate States (chunk boundaries)
-- ============================================================================

-- State at PC 0 (entry)
@[irreducible]
def singletonState0 (env : ModuleEnvironment) (initialFrame : CallFrame) : CallFrame :=
  { initialFrame with
    pc := 0,
    function := registrationFuncIdx
    -- TODO: Add other fields as needed
  }

-- Projection lemmas
@[simp]
theorem singletonState0_pc (env : ModuleEnvironment) (frame : CallFrame) :
    (singletonState0 env frame).pc = 0 := by
  simp only [singletonState0]
  rfl

@[simp]
theorem singletonState0_function (env : ModuleEnvironment) (frame : CallFrame) :
    (singletonState0 env frame).function = registrationFuncIdx := by
  simp only [singletonState0]
  rfl

-- State at PC 17 (after container setup)
@[irreducible]
def singletonState17 (env : ModuleEnvironment) (initialFrame : CallFrame) 
    (containerRef : Reference) : CallFrame :=
  { singletonState0 env initialFrame with
    pc := 17,
    locals := (singletonState0 env initialFrame).locals.set 5 (.immRef containerRef) sorry
    -- TODO: Fill in actual locals state
    -- TODO: Add bound proof (replace sorry with actual proof that 5 < locals.size)
  }

-- State at PC 34 (after container write)
@[irreducible]
def singletonState34 (env : ModuleEnvironment) (initialFrame : CallFrame)
    (containerRef : Reference) : CallFrame :=
  { singletonState17 env initialFrame containerRef with
    pc := 34
    -- TODO: Fill in actual state after write
  }

-- State at PC 50 (final, returned)
@[irreducible]
def singletonState50 (env : ModuleEnvironment) (initialFrame : CallFrame) : CallFrame :=
  { singletonState34 env initialFrame sorry with
    pc := 50
    -- TODO: Fill in final state
  }

-- ============================================================================
-- Sub-Lemma 1: Container Setup (PCs 0-16)
-- ============================================================================

theorem registration_singleton_pcs_0_16
    (env : ModuleEnvironment)
    (initialFrame : CallFrame)
    (cs : ControlStack)
    (stack : List Value)
    (ms : MachineState)
    (h_pc : initialFrame.pc = 0)
    (h_fn : initialFrame.function = registrationFuncIdx)
    -- TODO: Add other hypotheses (locals, refs, etc.)
    : MoveModel.run env (singletonState0 env initialFrame) cs stack ms 17 =
        .success (singletonState17 env initialFrame sorry) cs stack ms := by
  -- TODO: Implement proof body
  -- Pattern:
  --   have h0 := step_pc0 env (singletonState0 env initialFrame) cs stack ms
  --   have h1 := step_pc1 env ...
  --   ...
  --   have h16 := step_pc16 env ...
  --   exact run_chain [h0, h1, ..., h16]
  sorry

-- ============================================================================
-- Sub-Lemma 2: Container Write (PCs 17-33)
-- ============================================================================

theorem registration_singleton_pcs_17_33
    (env : ModuleEnvironment)
    (initialFrame : CallFrame)
    (containerRef : Reference)
    (cs : ControlStack)
    (stack : List Value)
    (ms : MachineState)
    -- TODO: Add hypotheses
    : MoveModel.run env (singletonState17 env initialFrame containerRef) cs stack ms 17 =
        .success (singletonState34 env initialFrame containerRef) cs stack ms := by
  -- TODO: Implement proof body
  sorry

-- ============================================================================
-- Sub-Lemma 3: Publish + Return (PCs 34-49)
-- ============================================================================

theorem registration_singleton_pcs_34_49
    (env : ModuleEnvironment)
    (initialFrame : CallFrame)
    (containerRef : Reference)
    (cs : ControlStack)
    (stack : List Value)
    (ms : MachineState)
    -- TODO: Add hypotheses
    : MoveModel.run env (singletonState34 env initialFrame containerRef) cs stack ms 16 =
        .success (singletonState50 env initialFrame) cs stack ms := by
  -- TODO: Implement proof body
  sorry

-- ============================================================================
-- Composition Theorem (chains 3 sub-lemmas)
-- ============================================================================

theorem registration_singleton_eval_equiv
    (env : ModuleEnvironment)
    (initialFrame : CallFrame)
    (cs : ControlStack)
    (stack : List Value)
    (ms : MachineState)
    (h_pc : initialFrame.pc = 0)
    (h_fn : initialFrame.function = registrationFuncIdx)
    -- TODO: Add operation-specific hypotheses
    : MoveModel.run env (singletonState0 env initialFrame) cs stack ms 50 =
        .success (singletonState50 env initialFrame) cs stack ms := by
  -- Chain all 3 sub-lemmas
  have h1 := registration_singleton_pcs_0_16 env initialFrame cs stack ms h_pc h_fn
  have h2 := registration_singleton_pcs_17_33 env initialFrame sorry cs stack ms
  have h3 := registration_singleton_pcs_34_49 env initialFrame sorry cs stack ms
  
  -- Use run_trans to combine
  have h12 := run_trans h1 h2
  have h123 := run_trans h12 h3
  
  exact h123

end MovementFormal.Experimental.ConfidentialAsset.Registration
```

---

## Sub-Lemma 1: Container Setup (PCs 0-16)

### Key Steps

**PC 0-4:** Dispatcher (function index check, argument loading)
- Use existing `step_pc<N>` patterns from `EvalEquivRebuild.lean`
- Focus: Load `dk`, `k`, `sig_msg`, `addr` from initial frame

**PC 5-10:** Container creation
- `newContainerRef`: Creates empty container reference
- `stLoc 5`: Store container ref in local 5
- Pattern:
  ```lean
  have h5 := step_ldU64 env state5 cs stack ms
  have h6 := step_newContainerRef env state6 cs stack ms
  have h7 := step_stLoc 5 env state7 cs stack ms h_bound7
  ```

**PC 11-16:** Container initialization
- `packStruct`: Pack fields into container struct
- `writeRef`: Initialize container fields
- Pattern:
  ```lean
  have h11 := step_packStruct env state11 cs stack ms field_vals
  have h12 := step_writeRef env state12 cs stack ms ref_val
  ```

### Expected Complexity

- **Lines:** ~150 (17 PCs × ~9 lines per PC = ~153)
- **Build time:** <2s (shallow chain, fast elaboration)
- **Proof pattern:** Mostly `rfl` after `simp only [step, ...]`

---

## Sub-Lemma 2: Container Write (PCs 17-33)

### Key Steps

**PC 17-25:** Write preparation
- Load container ref from local 5
- Load values to write (encryption key, etc.)
- Borrow container fields

**PC 26-33:** Actual container mutation
- `writeRef` on each field
- Handle ownership transfer (container goes from `&mut` to owned)
- `storeGlobal`: Write container to global store

### Key Challenge: Ownership Transfer

**Pattern:**
```lean
-- Before write: containerRef is &mut
have h_ref_before : containerRef.kind = .mut := sorry

-- After write: container is owned (moved to global store)
have h_owned_after : newContainer.kind = .owned := by
  simp only [writeRef_transfers_ownership]
  rfl
```

### Expected Complexity

- **Lines:** ~150 (17 PCs × ~9 lines = ~153)
- **Build time:** <2s
- **Proof pattern:** More `writeRef` cases, need ownership lemmas

---

## Sub-Lemma 3: Publish + Return (PCs 34-49)

### Key Steps

**PC 34-41:** Publish to global store
- `moveToSender`: Move container to sender's global storage
- Update `MachineState.globalStore`

**PC 42-49:** Return + cleanup
- Drop temporary references
- `ret`: Return empty value
- Clean up call frame

### Key Challenge: Global Store Mutation

**Pattern:**
```lean
-- Before: container not in global store
have h_not_exists : ¬exists env.globalStore addr ContainerType := sorry

-- After moveToSender: container exists in global store
have h_exists : exists env.globalStore addr ContainerType := by
  simp only [moveToSender_adds_to_store]
  rfl
```

### Expected Complexity

- **Lines:** ~160 (16 PCs × ~10 lines = ~160)
- **Build time:** <2s
- **Proof pattern:** Global store lemmas, cleanup steps

---

## Composition Theorem

### Template

```lean
theorem registration_singleton_eval_equiv
    (env : ModuleEnvironment)
    (oracle : RegistrationOracle)
    (initialFrame : CallFrame)
    (h_pc : initialFrame.pc = 0)
    (h_fn : initialFrame.function = registrationFuncIdx)
    (h_singleton : oracle.container_exists_before = false)  -- NEW: singleton case
    : evalRegistration oracle initialFrame = 
        verifyRegistrationBytecodeResult oracle initialFrame := by
  -- Unfold eval to run
  simp only [evalRegistration, eval_registration_eq_run]
  
  -- Apply 3 sub-lemmas
  have h1 := registration_singleton_pcs_0_16 env initialFrame cs stack ms h_pc h_fn
  have h2 := registration_singleton_pcs_17_33 env initialFrame containerRef cs stack ms
  have h3 := registration_singleton_pcs_34_49 env initialFrame containerRef cs stack ms
  
  -- Chain via run_trans
  have h12 := run_trans h1 h2
  have h_full := run_trans h12 h3
  
  -- Match to FunctionalSim via shape lemmas
  cases oracle.result with
  | some _ => exact registration_singleton_shape_success oracle ...
  | none => exact registration_singleton_shape_verify_failed oracle ...
```

### Integration with Non-Singleton Branch

**In `EvalEquiv.lean`:**
```lean
-- Replace TEMPORARY axiom with theorem
theorem registration_eval_equiv_functional_sim
    (env : ModuleEnvironment)
    (oracle : RegistrationOracle)
    (initialFrame : CallFrame)
    : evalRegistration oracle initialFrame = 
        verifyRegistrationBytecodeResult oracle initialFrame := by
  -- Case-split on singleton vs non-singleton
  cases oracle.container_exists_before with
  | true => 
      -- Non-singleton branch (already proved in EvalEquivRebuild.lean)
      exact registration_non_singleton_eval_equiv env oracle initialFrame
  | false =>
      -- Singleton branch (newly proved in SingletonBranch.lean)
      exact registration_singleton_eval_equiv env oracle initialFrame h_singleton
```

---

## Testing Strategy

### Per-Sub-Lemma Testing

**After completing each sub-lemma:**

```bash
# Build just the SingletonBranch file
cd lean
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.SingletonBranch

# Expected: <2s per sub-lemma
# If >5s: split sub-lemma further or add more @[irreducible]
```

---

### Integration Testing

**After completing all 3 sub-lemmas:**

```bash
# Full Registration build
lake build MovementFormal.Experimental.ConfidentialAsset.Registration

# Axiom check
lake env lean --run <<EOF
#print axioms registration_eval_equiv_functional_sim
-- Expected: Only crypto axioms (no TEMPORARY)
EOF

# Full CA tree build
lake build

# Expected: <10 min cold, <5s incremental
```

---

### Acceptance Testing

```bash
# Per-operation verification
./audit/verify-ca.sh --op register --stack lean

# Expected: <3 min, all tests pass

# Axiom drift check
./scripts/track_axiom_drift.sh --compare HEAD~1

# Expected: -1 axiom (TEMPORARY eliminated)

# Update baseline
./scripts/track_axiom_drift.sh --baseline
```

---

## Acceptance Criteria

### Per-Sub-Lemma Criteria

For each sub-lemma (`pcs_0_16`, `pcs_17_33`, `pcs_34_49`):

- ✅ Theorem proves with no `sorry`
- ✅ Build time <2s (per sub-lemma file alone)
- ✅ Uses `@[irreducible]` state definitions
- ✅ All PCs covered (no gaps)

---

### Overall Phase 1 Criteria

- ✅ `registration_singleton_eval_equiv` theorem proves (no `sorry`)
- ✅ `registration_eval_equiv_functional_sim` TEMPORARY axiom replaced with theorem
- ✅ `#print axioms registration_eval_equiv_functional_sim` shows only crypto axioms
- ✅ Full `SingletonBranch.lean` builds in <5s
- ✅ Full Registration directory builds in <5s
- ✅ Full CA Lean tree builds in <10 min cold
- ✅ `verify-ca.sh --op register` passes in <3 min
- ✅ Axiom baseline updated (1 axiom eliminated)
- ✅ AXIOM_INVENTORY.md updated (TEMPORARY section empty)

---

## Appendices

### Appendix A: Common Proof Tactics

```lean
-- PC step application
have h<N> := step_pc<N> env state<N> cs stack ms
  h_pc<N>  -- PC hypothesis
  h_fn     -- Function hypothesis
  h_local  -- Local variable hypothesis (if needed)

-- Simplification
simp only [step, MoveModel.run, state<N>, step_pc<N>]

-- Reflexivity (after simplification)
rfl

-- Bound proof (for Array.get)
have h_bound : K < frame.locals.size := by decide

-- Ownership transfer
have h_ownership := writeRef_transfers_ownership ref val
simp only [h_ownership]
```

---

### Appendix B: Estimated Metrics

| Metric | Estimate | Actual (fill in during implementation) |
|--------|----------|---------------------------------------|
| Total lines (SingletonBranch.lean) | ~520 | |
| Build time (SingletonBranch.lean) | <5s | |
| Build time (full Registration) | <5s | |
| Implementation days | 5-7 | |
| Axioms eliminated | 1 (TEMPORARY) | |
| Phase 1 completion | 95% → 100% | |

---

**End of starter kit.** Ready to implement when Phase 1 work begins.
