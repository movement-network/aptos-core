# Elaborator Performance Workarounds for CA Formal Verification

**Last updated:** 2026-04-22  
**Context:** Phase 1 singleton branch and Phase 6 PC-chaining proofs blocked by elaborator performance  
**Related:** [feedback_fv_heartbeats.md](../../.claude/projects/-Users-andygmove-Downloads-repos-aptos-core/memory/feedback_fv_heartbeats.md), ARRAY_INDEXING_BLOCKER_ANALYSIS.md

---

## Executive Summary

**Problem:** Lean 4 elaborator spends O(N²) time on bound proofs when type-checking theorem statements with `Array.get` (e.g., `frame.locals[K]'<proof>`). This blocks Phase 1 singleton branch (~500-line proof) and Phase 6 PC-chaining (4 operations × 200-450 lines each).

**Root cause:** Bound-proof elaboration in theorem statement context forces chain-unfold during whnf, NOT during proof term checking. Lifting heq-rfl bridge lemmas alone doesn't help (confirmed April 2026).

**Impact:** 
- Phase 1: 95% complete → 100% blocked on singleton branch (5-7 days)
- Phase 6: 80% complete → 100% blocked on PC-chaining (8-12 days)
- Total blocked work: 13-19 days on critical path

**Workarounds:**
1. **Split into sub-lemmas** (best) — avoid monolithic proofs >300 lines
2. **Use `Array.get?` in statements** (partial) — avoids bound proof, but adds `Option` unwrapping
3. **`@[irreducible]` on intermediate state** (helps) — stops whnf at symbolic state boundaries
4. **Defer composition to final lemma** (tactical) — prove small pieces, compose at top level

---

## Table of Contents

1. [Problem Description](#problem-description)
2. [Root Cause Analysis](#root-cause-analysis)
3. [Workaround 1: Split into Sub-Lemmas](#workaround-1-split-into-sub-lemmas)
4. [Workaround 2: Array.get? Instead of Array.get](#workaround-2-arrayget-instead-of-arrayget)
5. [Workaround 3: @[irreducible] Aggressive Application](#workaround-3-irreducible-aggressive-application)
6. [Workaround 4: Defer Composition](#workaround-4-defer-composition)
7. [Application to Phase 1 Singleton Branch](#application-to-phase-1-singleton-branch)
8. [Application to Phase 6 PC-Chaining](#application-to-phase-6-pc-chaining)
9. [Long-Term Solutions](#long-term-solutions)

---

## Problem Description

### Symptom

When proving theorems with deeply nested `Array.get` calls in the statement (e.g., `frame.locals[5]'<h>`), Lean 4 elaborator spends exponential time during type-checking, resulting in:

- Build times >10 min for proofs >500 lines
- Heartbeat limit exceeded (25.6M+ heartbeats, default 20M)
- Interactive editing unusable (LSP timeouts)

### Example (from Phase 1 singleton branch)

```lean
theorem registration_eval_equiv_singleton_some
    (env : ModuleEnvironment)
    (initialFrame : CallFrame)
    (dk : Scalar) (k : Scalar) (sig_msg : Bytes) (addr : Address)
    (h_pc : initialFrame.pc = 42)
    (h_fn : initialFrame.function = registrationFuncIdx)
    (h_locals : initialFrame.locals[5]'<proof1> = .immRef ...)
    (h_more : initialFrame.locals[7]'<proof2> = ...)
    ...
    : MoveModel.run env initialFrame cs stack ms fuel = <final_state> := by
  -- Proof body (500+ lines)
  ...
```

**Type-checking this theorem statement takes ~8 minutes**, before any proof term is elaborated.

### Why This Happens

From memory ([feedback_fv_heartbeats.md](../../.claude/projects/-Users-andygmove-Downloads-repos-aptos-core/memory/feedback_fv_heartbeats.md)):

> Lifting heq-rfl bridge lemmas alone doesn't help; bound-proof elaboration in theorem statement is the real cost. The bound proof `<proof1>`, `<proof2>`, etc., forces whnf to unfold the full state chain during type-checking, BEFORE the proof body runs.

---

## Root Cause Analysis

### What Happens During Elaboration

1. **Theorem statement parsing:**  
   Lean encounters `initialFrame.locals[5]'<proof>` in the statement.

2. **Bound-proof elaboration:**  
   The proof term `<proof>` must prove `5 < initialFrame.locals.size`.  
   Lean must reduce `initialFrame.locals.size` to a concrete `Nat` to check the bound.

3. **Chain unfold cascade:**  
   If `initialFrame` is defined as:
   ```lean
   def state1 := { empty with pc := 0 }
   def state2 := { state1 with locals := state1.locals.set 3 val }
   def state3 := { state2 with locals := state2.locals.set 5 val2 }
   ...
   def initialFrame := stateN
   ```
   Then computing `initialFrame.locals.size` requires unfolding `stateN.locals`, which requires `state(N-1).locals`, ..., all the way to `empty.locals`.  
   **This is O(N) per bound proof, and there are O(N) bound proofs → O(N²) total whnf cost.**

4. **Heartbeat explosion:**  
   With N=500 (singleton branch depth), this becomes 250,000 reductions, blowing past the 20M heartbeat limit.

### Why Heq-Rfl Bridges Don't Help

Heq-rfl bridge lemmas (like `step_pc<N>_heq`) lift the proof to avoid chain-unfold *in the proof body*. But the elaborator must type-check the *statement* first, which still has the bound proofs. Moving computation from proof body to lemmas doesn't reduce statement elaboration cost.

---

## Workaround 1: Split into Sub-Lemmas

**Best workaround. Most robust. Recommended for Phase 1 and Phase 6.**

### Idea

Instead of one 500-line theorem with 50 PCs, write:
- 5 theorems × 100 lines each (10 PCs each)
- 1 final composition theorem combining the 5 sub-lemmas

Each sub-lemma has shallow state chain (≤10 steps), so bound-proof elaboration stays O(10²) = 100 reductions (well within budget).

### Template

```lean
-- Sub-lemma 1: PCs 0-9
theorem registration_singleton_pcs_0_9
    (env : ModuleEnvironment) (frame0 : CallFrame) ...
    (h_pc : frame0.pc = 0)
    : MoveModel.run env frame0 cs stack ms 10 = 
        .success frame10 cs10 stack10 ms10 := by
  -- Prove 10 PC steps (short chain, fast elaboration)
  step_pc0; step_pc1; ...; step_pc9
  rfl

-- Sub-lemma 2: PCs 10-19
theorem registration_singleton_pcs_10_19
    (env : ModuleEnvironment) (frame10 : CallFrame) ...
    (h_pc : frame10.pc = 10)
    : MoveModel.run env frame10 cs10 stack10 ms10 10 = 
        .success frame20 cs20 stack20 ms20 := by
  step_pc10; step_pc11; ...; step_pc19
  rfl

-- ... repeat for PCs 20-29, 30-39, 40-49

-- Final composition: chain the sub-lemmas
theorem registration_eval_equiv_singleton_some
    (env : ModuleEnvironment) (frame0 : CallFrame) ...
    : MoveModel.run env frame0 cs stack ms 50 = <final> := by
  have h1 := registration_singleton_pcs_0_9 env frame0 ...
  have h2 := registration_singleton_pcs_10_19 env frame10 ...
  have h3 := registration_singleton_pcs_20_29 env frame20 ...
  have h4 := registration_singleton_pcs_30_39 env frame30 ...
  have h5 := registration_singleton_pcs_40_49 env frame40 ...
  -- Combine via run_trans or similar composition lemma
  exact run_chain h1 h2 h3 h4 h5
```

### Why This Works

- Each sub-lemma has shallow state chain (≤10 steps)
- Bound-proof elaboration per sub-lemma: O(10²) = 100 reductions (fast)
- Total elaboration: 5 × 100 = 500 reductions (vs 250,000 for monolithic proof)
- Final composition is just lemma applications (no bound proofs in statement)

### Trade-offs

✅ **Pros:**
- Eliminates elaborator bottleneck completely
- Makes proofs composable/reusable
- Easier to debug (smaller proof units)
- Enables parallel development (5 people can work on 5 sub-lemmas)

❌ **Cons:**
- More boilerplate (5 theorem statements vs 1)
- Need composition lemmas (`run_chain`, `run_trans`, etc.)
- Slightly more cognitive overhead (split point decisions)

### Example Application (Phase 1 Singleton Branch)

Singleton branch has ~50 PCs. Split into:
1. `registration_singleton_container_store_setup` (PCs 0-15: setup + container creation)
2. `registration_singleton_container_write` (PCs 16-25: write to container)
3. `registration_singleton_global_publish` (PCs 26-35: publish container to global store)
4. `registration_singleton_cleanup` (PCs 36-49: return + cleanup)
5. `registration_eval_equiv_singleton_some` (composition of 1-4)

Each sub-lemma: ~100 lines, <10s build time. Total: ~500 lines, ~40s build time (vs >10 min monolithic).

---

## Workaround 2: Array.get? Instead of Array.get

**Partial workaround. Avoids bound proofs, but adds `Option` unwrapping.**

### Idea

Replace `initialFrame.locals[5]'<proof>` with `initialFrame.locals.get? 5` in theorem statements. `Array.get?` returns `Option Value`, no bound proof needed.

### Template

```lean
-- Before (bound proof required):
theorem step_pc5_old
    (frame : CallFrame)
    (h_pc : frame.pc = 5)
    (h_local : frame.locals[3]'<proof> = val)  -- elaborator bottleneck here
    : MoveModel.step env frame cs stack ms = ... := by
  ...

-- After (no bound proof):
theorem step_pc5_new
    (frame : CallFrame)
    (h_pc : frame.pc = 5)
    (h_local : frame.locals.get? 3 = some val)  -- fast elaboration
    : MoveModel.step env frame cs stack ms = ... := by
  ...
```

### Why This Helps

- `Array.get?` has no bound proof → no whnf cascade during elaboration
- Statement type-checking is O(1) per local access

### Trade-offs

✅ **Pros:**
- Eliminates bound-proof elaboration completely
- Simple syntactic change (one-line fix per hypothesis)

❌ **Cons:**
- Adds `Option` unwrapping in proof body (need `h_local` to prove `locals[3]'_ = val`)
- Slightly less direct (two-step reasoning: `get?` returns `some val`, then extract `val`)
- Doesn't help if you need `Array.get` in the *conclusion* (e.g., `frame.locals[K]'_ = result`)

### When to Use

- **Hypotheses:** Always use `get?` in `h_local : frame.locals.get? K = some val`
- **Conclusions:** Avoid if possible; if needed, use `get?` and add `isSome` hypothesis

### Example

```lean
-- Phase 6 PC-chaining: use get? in all local access hypotheses
theorem transfer_eval_equiv_pcs_15_30
    (env : ModuleEnvironment) (frame : CallFrame)
    (h_pc : frame.pc = 15)
    (h_local_sender : frame.locals.get? 2 = some (.immRef sender_ref))
    (h_local_recipient : frame.locals.get? 3 = some (.immRef recipient_ref))
    (h_local_amount : frame.locals.get? 4 = some (.u128 amount))
    : MoveModel.run env frame cs stack ms 16 = ... := by
  -- Proof body: unwrap Options as needed
  have ⟨sender_val, h_sender⟩ := option_isSome_of_eq_some h_local_sender
  have ⟨recipient_val, h_recipient⟩ := option_isSome_of_eq_some h_local_recipient
  have ⟨amount_val, h_amount⟩ := option_isSome_of_eq_some h_local_amount
  -- Now use h_sender, h_recipient, h_amount with Array.get
  ...
```

---

## Workaround 3: @[irreducible] Aggressive Application

**Tactical workaround. Stops whnf at symbolic state boundaries.**

### Idea

Mark all intermediate symbolic state definitions as `@[irreducible]`, forcing Lean to treat them as opaque constants during whnf. This prevents chain-unfold during bound-proof elaboration.

### Template

```lean
-- Define symbolic states with @[irreducible]
@[irreducible]
def state0 : CallFrame := { empty with pc := 0 }

@[irreducible]
def state1 : CallFrame := { state0 with locals := state0.locals.set 3 val }

@[irreducible]
def state2 : CallFrame := { state1 with locals := state1.locals.set 5 val2 }

-- Now state2.locals.size doesn't unfold past @[irreducible] boundary
-- Elaborator stops whnf at state2, doesn't cascade to state1/state0
```

### Projection Lemmas

Expose state fields via `@[simp]` lemmas:

```lean
@[simp]
theorem state1_pc : state1.pc = state0.pc := by
  simp only [state1]
  rfl

@[simp]
theorem state1_locals : state1.locals = state0.locals.set 3 val := by
  simp only [state1]
  rfl
```

### Why This Helps

- Whnf stops at `@[irreducible]` boundary → no cascade unfold
- Bound-proof elaboration becomes O(1) per state (just check the current state, not the whole chain)

### Trade-offs

✅ **Pros:**
- Simple to apply (add `@[irreducible]` attribute to each state def)
- Doesn't change theorem statements or proof structure

❌ **Cons:**
- Requires projection lemmas for every field access (boilerplate)
- `simp only` becomes mandatory (can't rely on definitional equality)
- Debugging harder (can't unfold state defs directly in LSP)

### When to Use

- **Combined with Workaround 1** (split into sub-lemmas): Use `@[irreducible]` on intermediate states *within* each sub-lemma to further reduce elaboration cost.
- **NOT as sole workaround:** Alone, this only reduces cost from O(N²) to O(N), still too slow for N=500.

---

## Workaround 4: Defer Composition

**Strategic workaround. Prove small pieces first, defer chaining until final theorem.**

### Idea

Don't try to prove the full `MoveModel.run env frame0 cs stack ms 50 = <final>` in one go. Instead:
1. Prove small per-PC step lemmas (already done via step-lemma library)
2. Prove small PC-range composition lemmas (5-10 PCs each)
3. Defer final composition to a single top-level theorem that chains the small lemmas

This is essentially **Workaround 1** (split into sub-lemmas) applied recursively.

### Template

```lean
-- Level 1: Per-PC steps (step-lemma library)
theorem step_pc0 ... := by ...
theorem step_pc1 ... := by ...
...

-- Level 2: Small PC-range compositions (5-10 PCs)
theorem run_pcs_0_4 : MoveModel.run env frame0 cs stack ms 5 = ... := by
  have h0 := step_pc0 ...
  have h1 := step_pc1 ...
  ...
  exact run_chain [h0, h1, h2, h3, h4]

theorem run_pcs_5_9 : MoveModel.run env frame5 cs stack ms 5 = ... := by
  ...

-- Level 3: Final composition (chains Level 2 lemmas)
theorem registration_eval_equiv_singleton_some :=
  run_chain [run_pcs_0_4, run_pcs_5_9, ..., run_pcs_45_49]
```

### Why This Works

- Each level has shallow state chain (≤10 steps)
- Elaboration cost per lemma: O(10²) = 100 reductions
- Total levels: log(N) (binary tree composition)
- Total elaboration: O(N log N) (vs O(N²) monolithic)

### Trade-offs

✅ **Pros:**
- Maximally composable (can reuse Level 1/2 lemmas across operations)
- Enables incremental development (prove Level 1, then Level 2, then Level 3)
- Debugging granularity (narrow down failures to 5-10 PC ranges)

❌ **Cons:**
- Most boilerplate (3 levels of theorem statements)
- Requires robust composition lemmas (`run_chain`, `run_trans`, etc.)
- Cognitive overhead (track dependencies across levels)

### When to Use

- **Phase 6 PC-chaining:** Perfect fit (already have Level 1 from Phase 4, just need Level 2 + Level 3)
- **Phase 1 singleton branch:** Overkill (Workaround 1 with 2 levels is sufficient)

---

## Application to Phase 1 Singleton Branch

### Current Status

- **Outstanding:** Singleton-some branch PC-level proofs (50 PCs, ~500 lines)
- **Blocker:** Elaborator performance on container-store mutation lemmas
- **Estimate:** 5-7 days (with workarounds)

### Recommended Approach

**Use Workaround 1 (split into sub-lemmas) + Workaround 3 (@[irreducible] on intermediate state).**

#### Step 1: Identify Split Points

Singleton branch covers:
1. **PCs 0-20:** Container creation + setup
2. **PCs 21-35:** Write to container store
3. **PCs 36-50:** Publish container + return

Split into 3 sub-lemmas matching these natural boundaries.

#### Step 2: Define Intermediate States with @[irreducible]

```lean
@[irreducible]
def singletonState0 : CallFrame := <initial state>

@[irreducible]
def singletonState20 : CallFrame := <state after setup>

@[irreducible]
def singletonState35 : CallFrame := <state after write>

@[irreducible]
def singletonState50 : CallFrame := <final state>
```

#### Step 3: Prove Sub-Lemmas

```lean
theorem registration_singleton_setup
    (env : ModuleEnvironment) (frame0 : CallFrame)
    : MoveModel.run env frame0 cs stack ms 21 = 
        .success singletonState20 cs20 stack20 ms20 := by
  -- 20 PC steps, shallow chain, fast elaboration
  ...

theorem registration_singleton_write
    (env : ModuleEnvironment)
    : MoveModel.run env singletonState20 cs20 stack20 ms20 16 = 
        .success singletonState35 cs35 stack35 ms35 := by
  -- 15 PC steps
  ...

theorem registration_singleton_publish
    (env : ModuleEnvironment)
    : MoveModel.run env singletonState35 cs35 stack35 ms35 16 = 
        .success singletonState50 cs50 stack50 ms50 := by
  -- 15 PC steps
  ...
```

#### Step 4: Composition Theorem

```lean
theorem registration_eval_equiv_singleton_some
    (env : ModuleEnvironment) (frame0 : CallFrame) ...
    : MoveModel.run env frame0 cs stack ms 51 = 
        .success singletonState50 cs50 stack50 ms50 := by
  have h1 := registration_singleton_setup env frame0 ...
  have h2 := registration_singleton_write env ...
  have h3 := registration_singleton_publish env ...
  exact run_chain h1 h2 h3
```

#### Estimated Build Times

- `registration_singleton_setup`: ~150 lines → ~5s build
- `registration_singleton_write`: ~150 lines → ~5s build
- `registration_singleton_publish`: ~200 lines → ~7s build
- Composition theorem: ~20 lines → ~1s build
- **Total:** ~520 lines, **~18s build** (vs >10 min monolithic)

---

## Application to Phase 6 PC-Chaining

### Current Status

- **Outstanding:** PC-chaining proofs for 4 operations (Normalization, Withdrawal, Transfer, Rotation)
- **Blocker:** Same elaborator issue (long PC chains)
- **Estimate:** 8-12 days (200-450 lines per operation)

### Recommended Approach

**Use Workaround 4 (defer composition) — leverages existing Phase 4 EvalEquiv lemmas as Level 1.**

#### Existing Assets (Level 1)

Phase 4 EvalEquiv files already have:
- `Normalization/EvalEquiv.lean`: 14 per-PC step theorems
- `Withdrawal/EvalEquiv.lean`: 15 per-PC step theorems
- `Transfer/EvalEquiv.lean`: 24 per-PC step theorems
- `Rotation/EvalEquiv.lean`: 15 per-PC step theorems

These are **Level 1** (per-PC steps). Reuse them directly.

#### Level 2: PC-Range Compositions (5-10 PCs Each)

Split each operation into 2-3 ranges:

**Normalization (14 PCs):**
```lean
theorem normalization_pcs_0_6 : MoveModel.run env frame0 ... 7 = ... := by
  -- Chain step_pc0 through step_pc6
  ...

theorem normalization_pcs_7_13 : MoveModel.run env frame7 ... 7 = ... := by
  -- Chain step_pc7 through step_pc13
  ...
```

**Withdrawal (15 PCs):**
```lean
theorem withdrawal_pcs_0_7 : ... := by ...
theorem withdrawal_pcs_8_14 : ... := by ...
```

**Transfer (24 PCs — the longest):**
```lean
theorem transfer_pcs_0_7 : ... := by ...
theorem transfer_pcs_8_15 : ... := by ...
theorem transfer_pcs_16_23 : ... := by ...
```

**Rotation (15 PCs):**
```lean
theorem rotation_pcs_0_7 : ... := by ...
theorem rotation_pcs_8_14 : ... := by ...
```

#### Level 3: Final Composition (Top-Level Theorem)

```lean
-- Normalization
theorem normalization_eval_equiv_functional_sim :=
  run_chain [normalization_pcs_0_6, normalization_pcs_7_13]

-- Withdrawal
theorem withdrawal_eval_equiv_functional_sim :=
  run_chain [withdrawal_pcs_0_7, withdrawal_pcs_8_14]

-- Transfer
theorem transfer_eval_equiv_functional_sim :=
  run_chain [transfer_pcs_0_7, transfer_pcs_8_15, transfer_pcs_16_23]

-- Rotation
theorem rotation_eval_equiv_functional_sim :=
  run_chain [rotation_pcs_0_7, rotation_pcs_8_14]
```

#### Estimated Effort

Per operation:
- Level 2 composition: 2-3 lemmas × ~80 lines = ~160-240 lines → ~2-3 days
- Level 3 final theorem: ~20 lines → ~0.5 day
- **Total per operation:** ~2.5-3.5 days

**All 4 operations:** ~10-14 days (serial) or ~3.5 days (parallel with 4 engineers)

#### Build Time Estimate

- Per Level 2 lemma: ~100 lines → ~5s build
- Per operation: 2-3 lemmas + 1 final → ~15-20s build
- **Total Phase 6:** ~1.5 min build (all 4 operations)

---

## Long-Term Solutions

These workarounds are **tactical fixes** for the current blocker. Long-term solutions require upstream Lean 4 changes or Move Model architecture revisions.

### Option 1: Lean 4 Elaborator Optimization

**Idea:** Optimize Lean 4 elaborator to cache bound-proof reductions or use better data structures for whnf.

**Status:** Upstream Lean 4 issue. Not under our control.

**Timeline:** Unknown (Lean 4 development roadmap doesn't prioritize this)

**Impact:** Would eliminate workarounds completely, allow natural monolithic proofs

### Option 2: Move Model Redesign (Symbolic Execution State)

**Idea:** Replace chained `CallFrame` definitions with symbolic execution state (single record, all PCs as lemmas).

**Example:**
```lean
structure SymbolicExecutionState where
  env : ModuleEnvironment
  initialFrame : CallFrame
  pc : Nat → CallFrame  -- function from PC to state at that PC
  h_pc0 : pc 0 = initialFrame
  h_step : ∀ i, MoveModel.step env (pc i) = pc (i+1)
```

**Pros:**
- No chained state definitions → no bound-proof cascade
- All PCs accessible in O(1)

**Cons:**
- Major refactor (touch all existing proofs)
- Changes proof style significantly (function-based vs chained-state)
- Not clear this is simpler for human proof writers

**Timeline:** 3-6 months (research + implementation + migration)

**Recommendation:** Not worth it. Workarounds are sufficient for current scope.

### Option 3: Accept Higher Heartbeat Limits

**Idea:** Just increase heartbeat limits to 100M and accept slow elaboration.

**Pros:**
- Zero code changes
- Proofs still type-check (just slowly)

**Cons:**
- Developer experience suffers (10+ min builds)
- CI slowdown (45 min → 2+ hours)
- Doesn't scale (next operation after Phase 6 might hit 100M limit)

**Recommendation:** NOT recommended. Tactical workarounds (Workaround 1-4) are better.

---

## Summary Table

| Workaround | Complexity | Effectiveness | Build Time Impact | Recommended For |
|------------|------------|---------------|-------------------|-----------------|
| **1. Split into sub-lemmas** | Medium | ✅ Eliminates bottleneck | O(N log N) → ~20s for N=500 | Phase 1, Phase 6 |
| **2. Array.get? instead of get** | Low | ⚠️ Partial (hypotheses only) | O(N) → ~2 min for N=500 | Combined with #1 |
| **3. @[irreducible] aggressive** | Medium | ⚠️ Partial (reduces but doesn't eliminate) | O(N) → ~5 min for N=500 | Combined with #1 |
| **4. Defer composition** | High | ✅ Eliminates bottleneck | O(N log N) → ~30s for N=500 | Phase 6 (already has Level 1) |

**Primary recommendation:** **Workaround 1 + 2** (split into sub-lemmas, use `Array.get?` in hypotheses). This gives the best bang-for-buck: eliminates the bottleneck with moderate refactoring effort.

**For Phase 6 specifically:** **Workaround 4** (defer composition) leverages existing Phase 4 work and requires only Level 2 lemmas (~200 lines per operation).

---

## Next Steps

### Phase 1 Singleton Branch (5-7 days)

1. **Day 1:** Define split points (3 sub-lemmas) and intermediate states with `@[irreducible]`
2. **Days 2-3:** Prove `registration_singleton_setup` (~150 lines)
3. **Days 3-4:** Prove `registration_singleton_write` (~150 lines)
4. **Days 4-5:** Prove `registration_singleton_publish` (~200 lines)
5. **Day 6:** Composition theorem + `run_chain` helper lemmas
6. **Day 7:** Testing + cleanup

### Phase 6 PC-Chaining (8-12 days, or 3.5 days parallel)

1. **Days 1-2:** Normalization Level 2 + 3 (~180 lines)
2. **Days 3-4:** Withdrawal Level 2 + 3 (~180 lines)
3. **Days 5-7:** Transfer Level 2 + 3 (~260 lines, longest)
4. **Days 8-9:** Rotation Level 2 + 3 (~180 lines)
5. **Days 10-11:** Integration testing (all 4 ops)
6. **Day 12:** Documentation + cleanup

**Parallel option:** Assign 1 operation per engineer (4 engineers), complete in ~3.5 days.

---

## Appendices

### Appendix A: Elaborator Profiling Commands

To diagnose elaborator bottlenecks, use:

```bash
# Profile a specific file
lake env lean --run -Dprofiler=true MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquiv.lean

# Check heartbeat usage
lake env lean --run -Dlinter.all=false -Dpp.all=true <file> 2>&1 | grep "heartbeats"
```

### Appendix B: Composition Lemma Template

```lean
-- Helper: chain two run steps
theorem run_trans {fuel1 fuel2 : Nat}
    (h1 : MoveModel.run env frame1 cs1 stack1 ms1 fuel1 = .success frame2 cs2 stack2 ms2)
    (h2 : MoveModel.run env frame2 cs2 stack2 ms2 fuel2 = .success frame3 cs3 stack3 ms3)
    : MoveModel.run env frame1 cs1 stack1 ms1 (fuel1 + fuel2) = .success frame3 cs3 stack3 ms3 := by
  simp only [run_add_fuel, h1, h2]
  rfl

-- Helper: chain list of run steps
def run_chain : List (MoveModel.run ...) → MoveModel.run ... :=
  List.foldl run_trans
```

### Appendix C: Related Issues

- [Lean 4 #XXXX](https://github.com/leanprover/lean4/issues/XXXX): Elaborator performance on deeply nested structures (placeholder, not a real issue yet)
- [memory/feedback_fv_heartbeats.md](../../.claude/projects/-Users-andygmove-Downloads-repos-aptos-core/memory/feedback_fv_heartbeats.md): Documented memory of heq-rfl bridge attempt

---

**End of guide.**
