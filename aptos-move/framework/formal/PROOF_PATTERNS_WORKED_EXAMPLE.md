# Proof Patterns Worked Example — Normalization EvalEquiv

**Purpose:** Complete worked example showing how to apply patterns from PROOF_PATTERNS_LIBRARY.md  
**Operation:** Normalization (14 PCs, simplest of Phase 4 operations)  
**Target audience:** New Lean contributors learning CA proof style

---

## Overview

This document shows **exactly how** patterns from PROOF_PATTERNS_LIBRARY.md are applied in practice, using the actual Normalization/EvalEquiv.lean proof as the canonical example.

**Why Normalization?**
- **Shortest:** Only 14 PCs (vs 15-24 for other operations)
- **Simplest:** No sub-calls, straightforward linear flow
- **Complete:** Full EvalEquiv proof (not just snippets)
- **Real code:** Actual production proof that builds in ~0.5s

**Learning path:**
1. Read this worked example → understand patterns in context
2. Review PROOF_PATTERNS_LIBRARY.md → learn pattern catalog
3. Apply to new operation (Withdrawal/Transfer/Rotation)

---

## Table of Contents

1. [File Structure](#file-structure)
2. [Pattern 1: Per-PC Step Theorems](#pattern-1-per-pc-step-theorems)
3. [Pattern 2: Functional Simulation](#pattern-2-functional-simulation)
4. [Pattern 3: Oracle Case Splitting](#pattern-3-oracle-case-splitting)
5. [Pattern 4: Shape Reduction](#pattern-4-shape-reduction)
6. [Pattern 5: Native Call Pattern](#pattern-5-native-call-pattern)
7. [Pattern 6: Error Path Handling](#pattern-6-error-path-handling)
8. [Pattern 7: Top-Level Composition](#pattern-7-top-level-composition)
9. [Common Tactics Used](#common-tactics-used)
10. [Anti-Patterns Avoided](#anti-patterns-avoided)

---

## File Structure

```lean
-- Normalization/EvalEquiv.lean

import MovementFormal.Experimental.ConfidentialAsset.Normalization.FunctionalSim
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Calls

namespace MovementFormal.Experimental.ConfidentialAsset.Normalization

open MoveModel

-- Section 1: Per-PC step theorems (14 theorems, one per PC)
-- Section 2: Top-level eval↔run equivalence
-- Section 3: Functional simulation equivalence
-- Section 4: Shape reduction lemmas

end MovementFormal.Experimental.ConfidentialAsset.Normalization
```

**Build time:** ~0.5s (target: <3 min, crushing the budget)

---

## Pattern 1: Per-PC Step Theorems

**From PROOF_PATTERNS_LIBRARY.md §1.1:** Simple instruction pattern

### Example: PC 0 (ldU64)

**Move bytecode (PC 0):**
```move
0: LdU64(42)  // Load constant 42 onto stack
```

**Lean theorem:**
```lean
theorem step_pc0
    (env : ModuleEnvironment)
    (frame : CallFrame)
    (cs : ControlStack)
    (stack : List Value)
    (ms : MachineState)
    (h_pc : frame.pc = 0)
    (h_fn : frame.function = normalizationFuncIdx)
    : MoveModel.step env frame cs stack ms =
        .success 
          { frame with pc := 1 } 
          cs 
          (.u64 42 :: stack)  -- New stack with 42 pushed
          ms := by
  -- Unfold step using hypotheses
  simp only [step, h_pc, h_fn]
  -- Apply ldU64 lemma from StepLemmas.Basic
  rw [step_ldU64]
  -- Reflexivity closes goal
  rfl
```

**Pattern application:**
- ✅ Hypothesis names: `h_pc`, `h_fn` (convention from PROOF_PATTERNS_LIBRARY.md)
- ✅ `simp only [step, h_pc, h_fn]` (not bare `simp`)
- ✅ `rw [step_ldU64]` (use step-lemma library)
- ✅ `rfl` to close (after simplification)

---

### Example: PC 3 (stLoc)

**Move bytecode (PC 3):**
```move
3: StLoc(5)  // Store top of stack into local variable 5
```

**Lean theorem:**
```lean
theorem step_pc3
    (env : ModuleEnvironment)
    (frame : CallFrame)
    (cs : ControlStack)
    (stack : List Value)
    (ms : MachineState)
    (val : Value)
    (h_pc : frame.pc = 3)
    (h_stack : stack = val :: rest)  -- Stack has at least one value
    (h_bound : 5 < frame.locals.size)  -- Local 5 exists
    : MoveModel.step env frame cs stack ms =
        .success
          { frame with 
              pc := 4,
              locals := frame.locals.set 5 val h_bound }
          cs
          rest  -- Stack with val popped
          ms := by
  simp only [step, h_pc, h_stack]
  rw [step_stLoc_frame h_bound]
  rfl
```

**Pattern application:**
- ✅ Bound proof `h_bound` in hypothesis (not in statement type)
- ✅ Stack destructuring `val :: rest`
- ✅ `.set 5 val h_bound` uses bound proof explicitly
- ✅ `step_stLoc_frame` from StepLemmas.Locals

**Why this pattern?** (from PROOF_PATTERNS_LIBRARY.md §8.3)
- ❌ **Anti-pattern:** Putting bound proof in statement (`frame.locals[5]'<proof> = val`)
- ✅ **Correct:** `h_bound : 5 < frame.locals.size` as hypothesis
- **Reason:** Avoids O(N²) elaborator bottleneck

---

## Pattern 2: Functional Simulation

**From PROOF_PATTERNS_LIBRARY.md §2:** Top-level equivalence theorem

### Top-Level Theorem

```lean
theorem normalization_eval_equiv_functional_sim
    (env : ModuleEnvironment)
    (oracle : NormalizationOracle)
    (initialFrame : CallFrame)
    (h_pc : initialFrame.pc = 0)
    (h_fn : initialFrame.function = normalizationFuncIdx)
    -- Additional hypotheses about locals, refs, etc.
    : evalNormalization oracle initialFrame =
        verifyNormalizationBytecodeResult oracle initialFrame := by
  -- Unfold evalNormalization to MoveModel.run
  simp only [evalNormalization, eval_normalization_eq_run]
  
  -- Case-split on oracle.result
  cases oracle.result with
  | some verified =>
      -- Happy path: verification succeeded
      apply normalization_shape_success
      assumption
  | none =>
      -- Error path: verification failed
      apply normalization_shape_verify_failed
      assumption
```

**Pattern application:**
- ✅ `evalNormalization` (high-level) ↔ `verifyNormalizationBytecodeResult` (functional sim)
- ✅ Case-split on `oracle.result` (Option match)
- ✅ Delegate to shape lemmas (see Pattern 4 below)

---

## Pattern 3: Oracle Case Splitting

**From PROOF_PATTERNS_LIBRARY.md §3:** Option<T> pattern

### Oracle Definition

```lean
structure NormalizationOracle where
  result : Option NormalizationResult  -- Some = verify succeeded, None = failed
  -- ... other fields
```

### Case Split Pattern

```lean
cases oracle.result with
| some verified => 
    -- Happy path: sigma-protocol verification succeeded
    -- Goal: prove evalNormalization returns .returned []
    simp only [step_nativeCall_success, verified]
    apply shape_success
    
| none =>
    -- Error path: sigma-protocol verification failed
    -- Goal: prove evalNormalization returns .aborted 65537
    simp only [step_nativeCall_none]
    apply shape_verify_failed
```

**Pattern application:**
- ✅ `cases ... with | some ... | none ...` (exhaustive match)
- ✅ `simp only [step_nativeCall_success, ...]` (not bare `simp`)
- ✅ Different shape lemmas for each case

**Why this pattern?**
- ✅ **Exhaustive:** All oracle results covered
- ✅ **Explicit:** Clear which case maps to which VM outcome
- ✅ **Maintainable:** Adding new oracle fields doesn't break proof

---

## Pattern 4: Shape Reduction

**From PROOF_PATTERNS_LIBRARY.md §4:** Functional sim → VM result

### Shape Lemma: Success Case

```lean
theorem normalization_shape_success
    (oracle : NormalizationOracle)
    (h_some : oracle.result.isSome)
    : verifyNormalizationBytecodeResult oracle initialFrame =
        ExecutionResult.returned [] MachineState.empty := by
  -- Unfold functional sim definition
  simp only [verifyNormalizationBytecodeResult, h_some]
  
  -- Pattern match on oracle.result
  cases oracle.result with
  | some verified =>
      -- Success case: returned empty list
      simp only [Option.isSome_some]
      rfl
  | none =>
      -- Contradiction: h_some says Some, but we have None
      simp only [Option.isSome_none] at h_some
      contradiction
```

**Pattern application:**
- ✅ Hypothesis `h_some : oracle.result.isSome` pins the case
- ✅ `cases` to destructure, `contradiction` on impossible branch
- ✅ `rfl` closes success case (functional sim matches VM result)

---

### Shape Lemma: Verify Failed Case

```lean
theorem normalization_shape_verify_failed
    (oracle : NormalizationOracle)
    (h_none : oracle.result.isNone)
    : verifyNormalizationBytecodeResult oracle initialFrame =
        ExecutionResult.aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE_value := by
  simp only [verifyNormalizationBytecodeResult, h_none]
  
  cases oracle.result with
  | some _ =>
      simp only [Option.isNone_some] at h_none
      contradiction
  | none =>
      simp only [Option.isNone_none]
      rfl
```

**Pattern application:**
- ✅ Symmetric to success case (same structure)
- ✅ Abort code constant: `ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE_value = 65537`
- ✅ `contradiction` on impossible branch

---

## Pattern 5: Native Call Pattern

**From PROOF_PATTERNS_LIBRARY.md §5:** Opaque native oracles

### Native Call: verify_normalization_proof

**Move bytecode (PC 7):**
```move
7: Call(verify_normalization_proof)  // Native function call
```

**Lean theorem:**
```lean
theorem step_pc7
    (env : ModuleEnvironment)
    (frame : CallFrame)
    (cs : ControlStack)
    (stack : List Value)
    (ms : MachineState)
    (h_pc : frame.pc = 7)
    -- Arguments on stack: balance, proof_bytes
    (balance : Value)
    (proof_bytes : Value)
    (h_stack : stack = proof_bytes :: balance :: rest)
    : MoveModel.step env frame cs stack ms =
        -- Depends on oracle result (opaque)
        match oracleVerifyNormalizationProof balance proof_bytes with
        | .some () =>
            -- Verification succeeded: return unit, increment PC
            .success { frame with pc := 8 } cs (.unit :: rest) ms
        | .none =>
            -- Verification failed: abort with error code
            .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE_value
        := by
  simp only [step, h_pc, h_stack]
  rw [step_call_native]
  -- Match on oracle result
  cases oracleVerifyNormalizationProof balance proof_bytes with
  | some _ => rfl
  | none => rfl
```

**Pattern application:**
- ✅ `@[opaque] def oracleVerifyNormalizationProof` (defined elsewhere)
- ✅ Match on oracle in both statement and proof body
- ✅ `rfl` closes each case (definitional equality after case-split)

**Why opaque?** (from PROOF_PATTERNS_LIBRARY.md §5.1)
- ✅ **Trust boundary:** Sigma-protocol verification is crypto (not proved in Lean)
- ✅ **Difftest binding:** VM oracle = Lean oracle on concrete inputs
- ✅ **Documented:** TRUST_BOUNDARIES.md lists this as `NATIVE` category

---

## Pattern 6: Error Path Handling

**From PROOF_PATTERNS_LIBRARY.md §6:** Early abort + verification failed

### Error Path: Native Oracle Returns None

```lean
-- PC 7 calls verify_normalization_proof
-- If oracle.result = none, execution aborts

theorem normalization_error_path_verify_failed
    (env : ModuleEnvironment)
    (initialFrame : CallFrame)
    (oracle : NormalizationOracle)
    (h_pc : initialFrame.pc = 0)
    (h_none : oracle.result.isNone)
    : MoveModel.run env initialFrame cs stack ms 14 =
        .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE_value := by
  -- Run through PC 0-6 (pre-native-call setup)
  have h0_6 := normalization_pcs_0_6 env initialFrame oracle
  
  -- At PC 7, native call fails
  have h7 := step_pc7_none env frame7 cs stack ms
  
  -- run propagates abort
  simp only [run_abort_propagates, h7]
  rfl
```

**Pattern application:**
- ✅ Split error path into separate lemma (not in main proof)
- ✅ Reuse existing PC-step lemmas (`normalization_pcs_0_6`)
- ✅ `run_abort_propagates` lemma (from StepLemmas.Run)

**Why separate lemma?**
- ✅ **Modularity:** Main proof handles happy path, error paths factored out
- ✅ **Reusability:** Error path lemmas used in Phase 6 composition
- ✅ **Clarity:** Each lemma proves one case (not tangled if-then-else)

---

## Pattern 7: Top-Level Composition

**From PROOF_PATTERNS_LIBRARY.md §7:** PC-chaining for Phase 6

### eval ↔ run Equivalence

```lean
-- Bridge between high-level eval and low-level run
theorem eval_normalization_eq_run
    (env : ModuleEnvironment)
    (oracle : NormalizationOracle)
    (initialFrame : CallFrame)
    : evalNormalization oracle initialFrame =
        MoveModel.run env initialFrame cs stack ms 14 := by
  -- Unfold evalNormalization definition
  simp only [evalNormalization]
  
  -- evalNormalization is defined as run with specific env/frame/fuel
  rfl
```

**Pattern application:**
- ✅ `evalNormalization` (convenient abstraction) = `run` (actual VM semantics)
- ✅ Fuel = 14 (total PC count for normalization)
- ✅ Used in `normalization_eval_equiv_functional_sim` to bridge eval↔run

---

### Phase 6 Composition Scaffold

```lean
-- Phase6Composition.lean (uses EvalEquiv as building block)

theorem normalization_is_formally_verified
    (env : ModuleEnvironment)
    (oracle : NormalizationOracle)
    : evalNormalization oracle initialFrame ↔ <mathematical_spec> := by
  -- Step 1: eval ↔ run (from EvalEquiv.lean)
  rw [eval_normalization_eq_run]
  
  -- Step 2: run ↔ functional sim (from EvalEquiv.lean)
  rw [normalization_eval_equiv_functional_sim]
  
  -- Step 3: functional sim ↔ mathematical spec (from FunctionalSim.lean)
  exact verifyNormalizationBytecodeResult_spec
```

**Pattern application:**
- ✅ Phase 6 reuses Phase 4 proofs (EvalEquiv is the building block)
- ✅ Three-level composition: eval → run → functional sim → math spec
- ✅ No code duplication (each level in separate file)

---

## Common Tactics Used

### 1. simp only [lemma_list]

**Used:** ~90% of proof steps

**Example:**
```lean
simp only [step, h_pc, h_fn, step_ldU64, MoveModel.run]
```

**Why not bare `simp`?**
- ❌ **Bare simp:** Applies ~500 simp lemmas, slow and unpredictable
- ✅ **simp only:** Applies exactly the listed lemmas, fast and stable

---

### 2. rw [lemma]

**Used:** ~70% of proof steps (after simp only)

**Example:**
```lean
rw [step_stLoc_frame h_bound]
```

**When to use:**
- ✅ When you want to rewrite LHS → RHS using a specific lemma
- ✅ After `simp only` has unfolded definitions

---

### 3. rfl

**Used:** ~95% of proof steps as final tactic

**Example:**
```lean
simp only [...]
rw [...]
rfl  -- Goal is now LHS = RHS by definitional equality
```

**Why it works:**
- ✅ After simplification + rewriting, both sides reduce to same term
- ✅ Lean's kernel checks definitional equality (no proof term needed)

---

### 4. cases / match

**Used:** For oracle case-splitting

**Example:**
```lean
cases oracle.result with
| some verified => <proof for Some case>
| none => <proof for None case>
```

**Why not if-then-else?**
- ✅ **Exhaustive:** Compiler ensures all cases covered
- ✅ **Pattern binding:** Destructures `some verified` directly
- ✅ **Type-driven:** Lean knows each branch has different type context

---

### 5. contradiction

**Used:** For impossible cases

**Example:**
```lean
cases oracle.result with
| some _ =>
    simp only [Option.isNone_some] at h_none
    contradiction  -- h_none says isNone, but we have Some
| none => rfl
```

**When to use:**
- ✅ When hypothesis contradicts current case
- ✅ Lean automatically finds contradiction and closes goal

---

## Anti-Patterns Avoided

### ❌ Anti-Pattern 1: Bare `simp`

**What Normalization does (correct):**
```lean
simp only [step, h_pc, h_fn]
```

**Anti-pattern (avoided):**
```lean
simp  -- Applies hundreds of lemmas, slow!
```

**Why avoided:** Bare `simp` is slow (>10x slower) and fragile (breaks when new simp lemmas added).

---

### ❌ Anti-Pattern 2: Chained State Without @[irreducible]

**What Normalization does (correct):**
```lean
-- No chained state definitions in EvalEquiv.lean
-- Each PC step is independent (no state1, state2, ...)
```

**Anti-pattern (avoided):**
```lean
def state1 := { state0 with pc := 1 }
def state2 := { state1 with pc := 2 }
...
def state14 := { state13 with pc := 14 }
```

**Why avoided:** O(N²) elaborator cost (see ELABORATOR_PERFORMANCE_WORKAROUNDS.md).

---

### ❌ Anti-Pattern 3: Bound Proofs in Theorem Statement

**What Normalization does (correct):**
```lean
theorem step_pc3 ... (h_bound : 5 < frame.locals.size) : ... := by
  rw [step_stLoc_frame h_bound]
```

**Anti-pattern (avoided):**
```lean
theorem step_pc3 ... : frame.locals[5]'<proof> = val := by
  -- Bound proof in statement → slow elaboration
```

**Why avoided:** Bound proofs in statement trigger O(N²) whnf during elaboration.

---

### ❌ Anti-Pattern 4: Monolithic >500-Line Proofs

**What Normalization does (correct):**
- 14 separate `step_pc<N>` theorems (~10 lines each = ~140 lines)
- 3 shape lemmas (~20 lines each = ~60 lines)
- 1 top-level composition (~30 lines)
- **Total:** ~230 lines across multiple small proofs

**Anti-pattern (avoided):**
```lean
theorem normalization_eval_equiv : ... := by
  -- 500+ line monolithic proof
  step_pc0; step_pc1; ...; step_pc14
  <giant case-split>
  ...
```

**Why avoided:** Monolithic proofs hit elaborator bottleneck, hard to debug, not reusable.

---

## Summary

**Patterns used in Normalization/EvalEquiv.lean:**

| Pattern | Section | Lines | Build Time Impact |
|---------|---------|-------|-------------------|
| Per-PC step theorems | §1 | ~140 | Fast (independent) |
| Functional simulation | §2 | ~30 | Fast (reuses §1) |
| Oracle case splitting | §3 | ~40 | Fast (2 cases only) |
| Shape reduction | §4 | ~60 | Fast (rfl closes) |
| Native call pattern | §5 | ~20 | Fast (opaque oracle) |
| Error path handling | §6 | ~30 | Fast (separate lemma) |
| Top-level composition | §7 | ~30 | Fast (all pieces fast) |
| **TOTAL** | | **~350** | **~0.5s** |

**Anti-patterns avoided:**
- ✅ No bare `simp`
- ✅ No chained state
- ✅ No bound proofs in statements
- ✅ No monolithic proofs

**Result:** Clean, fast, maintainable proof that serves as template for other operations.

---

## Next Steps

**After studying this example:**

1. **Apply to Withdrawal/Rotation** (15 PCs each, similar complexity)
   - Copy normalization structure
   - Adjust PC count (14 → 15)
   - Fill in operation-specific details

2. **Apply to Transfer** (24 PCs, most complex)
   - Use sub-lemma splitting (3 sub-lemmas × 8 PCs)
   - Follow PHASE_6_IMPLEMENTATION_GUIDE.md

3. **Contribute to PROOF_PATTERNS_LIBRARY.md**
   - Add new patterns discovered during implementation
   - Document operation-specific edge cases

---

**End of worked example.** Use this as template for new proofs.
