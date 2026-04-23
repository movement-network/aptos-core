# Advanced Debugging Guide — CA Formal Verification

**Purpose:** Comprehensive debugging strategies for complex Lean proof failures  
**Target Audience:** Verification engineers working on Phase 1, 4, or 6  
**Prerequisites:** Basic Lean 4 knowledge, familiarity with CA architecture  
**Scope:** Lean-specific debugging (for MSL or Difftest debugging, see ERROR_DIAGNOSIS_GUIDE.md)

---

## Table of Contents

1. [Debugging Philosophy](#debugging-philosophy)
2. [Diagnostic Tools](#diagnostic-tools)
3. [Common Failure Patterns](#common-failure-patterns)
4. [Case Studies](#case-studies)
5. [Advanced Techniques](#advanced-techniques)
6. [Performance Debugging](#performance-debugging)

---

## Debugging Philosophy

### The Scientific Method for Proof Debugging

**1. Observe:** What is the exact error message?  
**2. Hypothesize:** What could cause this error?  
**3. Test:** Add diagnostics to validate hypothesis  
**4. Iterate:** Refine hypothesis based on test results  
**5. Fix:** Apply minimal change to resolve issue  
**6. Validate:** Confirm fix doesn't break other proofs

**Golden rule:** **Never guess. Always diagnose.**

Guessing leads to:
- ❌ Incorrect fixes that mask underlying issues
- ❌ Technical debt (workarounds instead of solutions)
- ❌ Performance regressions (heavyweight tactics to paper over problems)

Diagnosing leads to:
- ✅ Root cause understanding
- ✅ Minimal, targeted fixes
- ✅ Transferable knowledge for similar issues

---

## Diagnostic Tools

### Tool 1: `#check` — Type Inspection

**Purpose:** Verify types of terms, identify type mismatches

**Usage:**
```lean
#check step_pc0_immBorrowLoc
-- Output: step_pc0_immBorrowLoc : Frame → CallStack → MachineState → StepResult

#check registrationState 0 proofRef
-- Output: registrationState 0 proofRef : Frame
```

**When to use:**
- Type mismatch errors
- "expected X, got Y" errors
- Verifying hypothesis types in theorems

---

### Tool 2: `#print` — Definition Inspection

**Purpose:** View definition of functions, inspect reducibility

**Usage:**
```lean
#print registrationState
-- Shows full definition (if not @[irreducible])

#print MoveValue
-- Shows inductive type constructors
```

**When to use:**
- Understanding opaque function behavior
- Checking if `@[irreducible]` is applied
- Inspecting inductive type structure

---

### Tool 3: `set_option trace.Meta.Tactic.simp true` — Simp Tracer

**Purpose:** Debug `simp` failures, understand what `simp` is doing

**Usage:**
```lean
set_option trace.Meta.Tactic.simp true in
theorem test_simp : x + 0 = x := by
  simp
  -- Trace output shows:
  -- [Meta.Tactic.simp] @add_zero: x + 0 ==> x
  -- [Meta.Tactic.simp] rewrite x + 0 ~> x
```

**When to use:**
- `simp` doesn't solve goal
- `simp` is slow (> 1s)
- Need to know which lemmas `simp` applies

---

### Tool 4: `trace "{term}"` — Debug Printing

**Purpose:** Print intermediate values during proof

**Usage:**
```lean
theorem example_proof : ... := by
  have h := some_lemma ...
  trace "h = {h}"
  -- Output: h = <value>
  rw [h]
```

**When to use:**
- Need to see intermediate proof state
- Debugging complex term construction
- Validating hypothesis values

---

### Tool 5: `sorry` Bisection — Isolate Failures

**Purpose:** Binary search for failing sub-proof

**Strategy:**
```lean
theorem big_proof : ... := by
  step1  -- works
  step2  -- works
  step3  -- ???
  step4  -- ???
  step5  -- fails somewhere

-- Bisect:
theorem big_proof : ... := by
  step1
  step2
  sorry  -- Does this work? YES → problem is in step3-5
  
theorem big_proof : ... := by
  step1
  step2
  step3
  step4
  sorry  -- Does this work? NO → problem is in step3-4
  
-- Continue bisecting until you isolate the exact failing step
```

---

### Tool 6: Lean LSP Diagnostics

**Purpose:** Hover over terms for type/goal information

**Usage:** In VS Code or other LSP editor:
- Hover over term → see type
- Hover over proof step → see goal before and after
- Click on error → see full error message with context

**When to use:** Always! LSP is your primary debugging interface.

---

## Common Failure Patterns

### Pattern 1: `rfl` Fails — Terms Don't Reduce

**Symptom:**
```lean
theorem example : foo = bar := by
  rfl
-- Error: tactic 'rfl' failed, equality does not hold by reflexivity
```

**Diagnosis:**
```lean
-- Check if both sides reduce to same normal form
#reduce foo  -- Output: <normalized_foo>
#reduce bar  -- Output: <normalized_bar>
-- If outputs differ, rfl will fail
```

**Common causes:**

**Cause 1: `@[irreducible]` blocks reduction**
```lean
@[irreducible]
def foo : Nat := 42

theorem test : foo = 42 := by
  rfl  -- FAILS: foo doesn't reduce because @[irreducible]
```

**Fix:** Use `rw [foo]` to unfold explicitly, or remove `@[irreducible]` for this proof
```lean
theorem test : foo = 42 := by
  rw [foo]
  rfl  -- Now works
```

---

**Cause 2: Beta-reduction not applied**
```lean
def f (x : Nat) : Nat := x + 1

theorem test : f 5 = 6 := by
  rfl  -- FAILS in some contexts if f doesn't reduce
```

**Fix:** Use `simp only [f]` or `unfold f`
```lean
theorem test : f 5 = 6 := by
  simp only [f]
  rfl  -- Now f 5 reduces to 5 + 1, then to 6
```

---

**Cause 3: Definitional vs propositional equality**
```lean
theorem test (h : x = y) : x = y := by
  rfl  -- FAILS: h is propositional, not definitional
```

**Fix:** Use `exact h` instead
```lean
theorem test (h : x = y) : x = y := by
  exact h  -- Directly use hypothesis
```

---

### Pattern 2: `cases` Produces No Goals

**Symptom:**
```lean
theorem example (h : Option.some x = some y) : x = y := by
  cases h
-- Error: 'cases' tactic failed, no goals produced
```

**Diagnosis:**
```lean
#check Option.some_injective
-- Option.some_injective : ∀ {α : Type u} {a b : α}, some a = some b → a = b
```

**Fix:** Use `Option.some.inj` or specialized lemma
```lean
theorem example (h : Option.some x = some y) : x = y := by
  exact Option.some.inj h
```

---

### Pattern 3: `omega` Can't Solve Arithmetic

**Symptom:**
```lean
theorem example (h : x < 10) (h2 : x ≥ 5) : x < 15 := by
  omega
-- Error: omega failed to prove goal
```

**Diagnosis:**
```lean
-- omega works on linear integer arithmetic
-- Check if goal is non-linear or involves other types
```

**Fix:** Provide intermediate steps
```lean
theorem example (h : x < 10) (h2 : x ≥ 5) : x < 15 := by
  have : x < 15 := Nat.lt_trans h (by omega : 10 < 15)
  exact this
```

---

### Pattern 4: Type Mismatch in Hypothesis Application

**Symptom:**
```lean
theorem example (h : ∀ x, P x) : P 5 := by
  exact h
-- Error: type mismatch
--   h
-- has type
--   ∀ (x : ?m.X), P x
-- but is expected to have type
--   P 5
```

**Diagnosis:**
```lean
#check h  -- h : ∀ (x : Nat), P x
#check h 5  -- h 5 : P 5  ← This is what you want!
```

**Fix:** Apply `h` to argument
```lean
theorem example (h : ∀ x, P x) : P 5 := by
  exact h 5
```

---

## Case Studies

### Case Study 1: Registration PC 48 MoveTo Failure

**Context:** Trying to prove PC 48 step lemma (MoveTo updates container table)

**Initial error:**
```lean
theorem step_pc48_moveTo : 
    step env (registrationState 48 ...) cs ms =
      .ok (registrationState 49 ...) cs ms' := by
  rw [registrationState]
  rw [step_moveTo]
  rfl
-- Error: tactic 'rfl' failed
```

**Step 1: Diagnose with #check**
```lean
#check step_moveTo
-- step_moveTo : ... (requires specific heap update pattern)

#check registrationState 49
-- ... (check ms vs ms' difference)
```

**Step 2: Identify root cause**
The issue: `ms'` is heap-updated state, but `registrationState 49 ... ms` doesn't account for heap change.

**Step 3: Fix by threading heap update**
```lean
theorem step_pc48_moveTo : 
    step env (registrationState 48 ...) cs ms =
      .ok (registrationState 49 ...) cs ms' := by
  -- Define ms' as heap-updated state
  let ms' := ms.update_heap tableRef (MoveValue.table storageTable')
  
  rw [registrationState]
  rw [step_moveTo]
  
  -- Now both sides match
  simp only [ms']
  rfl
```

**Lesson:** State mutation requires explicit heap threading.

---

### Case Study 2: Chaining Theorem Unification Failure

**Context:** Chaining step lemmas in `run` proof

**Initial error:**
```lean
theorem chain_example :
    run env (state 0) cs ms = .returned [] ms' := by
  unfold run
  rw [step_pc0 ...]
  rw [step_pc1 ...]
-- Error: tactic 'rw' failed, equality not found in goal
```

**Step 1: Inspect goal**
```lean
-- Goal after step_pc0:
-- run env (state 1) cs ms = .returned [] ms'
--
-- step_pc1 LHS:
-- step env (state 1) cs ms = .ok (state 2) cs ms
--
-- Mismatch: run vs step!
```

**Step 2: Identify root cause**
`run` is a fixed-point definition that internally calls `step`. Need to unfold `run` step by step.

**Step 3: Fix by matching patterns**
```lean
theorem chain_example :
    run env (state 0) cs ms = .returned [] ms' := by
  unfold run
  simp only [step_pc0 ...]
  unfold run  -- Unfold again for next step
  simp only [step_pc1 ...]
  -- Continue...
```

**Alternative: Use custom run unfold lemma**
```lean
theorem run_step_ok (h : step env frame cs ms = .ok frame' cs' ms') :
    run env frame cs ms = run env frame' cs' ms' := by
  unfold run
  simp only [h]

-- Now use in proof:
theorem chain_example :
    run env (state 0) cs ms = .returned [] ms' := by
  rw [run_step_ok (step_pc0 ...)]
  rw [run_step_ok (step_pc1 ...)]
  -- Much cleaner!
```

**Lesson:** Understand the structure of recursive definitions (`run`), use helper lemmas for cleaner proofs.

---

### Case Study 3: Performance Degradation After Refactor

**Context:** Refactored state definitions, build time increased from 3s to 45s

**Initial symptoms:**
```bash
lake build MovementFormal.Experimental.ConfidentialAsset.Registration
# [180/197] Building ...  (taking forever)
```

**Step 1: Profile to find hotspot**
```bash
./scripts/profile_lean_build.sh MovementFormal.Experimental.ConfidentialAsset.Registration

# Output:
# Hottest theorem: step_pc25_readRef (15s, 8M heartbeats)
```

**Step 2: Inspect hot theorem**
```lean
theorem step_pc25_readRef : ... := by
  rw [registrationState]  -- ← Slow: registrationState unfolding
  rw [step_readRef]
  simp  -- ← Slow: bare simp
  rfl
```

**Step 3: Diagnose root cause**
- `registrationState` was refactored to remove `@[irreducible]`
- Unfolding it in every theorem is expensive (100× slowdown)
- `simp` with no lemma list is expensive (10× slowdown)

**Step 4: Fix**
```lean
-- Add back @[irreducible]
@[irreducible]
def registrationState ... := ...

-- Replace bare simp
theorem step_pc25_readRef : ... := by
  rw [registrationState]
  rw [step_readRef]
  simp only [Array.get?, MachineState.heap]  -- Targeted simp
  rfl
```

**Step 5: Validate**
```bash
lake build MovementFormal.Experimental.ConfidentialAsset.Registration
# [197/197] Building ... (3.2s)  ✅ Back to baseline!
```

**Lesson:** `@[irreducible]` is not just for performance—it's essential for scalability. Never remove it without profiling impact.

---

## Advanced Techniques

### Technique 1: Proof by Reflection

**Use case:** Repetitive proofs with regular structure

**Pattern:**
```lean
-- Instead of 55 nearly-identical step lemmas, generate them via metaprogramming

-- Define a tactic that generates step lemma proofs
syntax "step_lemma_tactic" : tactic

macro_rules
  | `(tactic| step_lemma_tactic) => `(tactic|
      rw [state]
      rw [step_<instr>]
      simp only [Array.get?]
      rfl)

-- Use in all step lemmas
theorem step_pc0 : ... := by step_lemma_tactic
theorem step_pc1 : ... := by step_lemma_tactic
-- ... (55 lemmas, all use same tactic)
```

**Benefit:** Changes to proof strategy apply to all lemmas automatically.

---

### Technique 2: Custom Simplification Sets

**Use case:** Domain-specific simplification rules

**Pattern:**
```lean
-- Define simp set for CA verification
attribute [ca_simp] Array.get?
attribute [ca_simp] MachineState.heap
attribute [ca_simp] step_immBorrowLoc
attribute [ca_simp] step_readRef

-- Use in proofs
theorem example : ... := by
  simp only [ca_simp]
  rfl
```

**Benefit:** Consistent, fast simplification across all proofs.

---

### Technique 3: Congruence Lemmas for State Constructors

**Use case:** Proving equality of states with only one field different

**Pattern:**
```lean
-- Define congruence lemma
theorem registrationState_congr_pc (h : pc1 = pc2) :
    registrationState pc1 proof = registrationState pc2 proof := by
  rw [h]

-- Use in proof
theorem step_pc0 : step env (registrationState 0 proof) = ... := by
  have h : registrationState 0 proof = registrationState 1 proof := by
    sorry  -- Would need to prove pc changed
  -- Actually, this example doesn't work directly, but idea is:
  -- Use congruence to avoid unfolding entire state
```

**Benefit:** Avoid expensive unfolding of `@[irreducible]` states.

---

## Performance Debugging

### Diagnostic Workflow

**Step 1: Identify slow theorem**
```bash
./scripts/profile_lean_build.sh MovementFormal.Experimental.ConfidentialAsset.Registration | grep "Slow"

# Output:
# Slow theorem: step_pc42_brTrue (8.3s, 12M heartbeats)
```

---

**Step 2: Isolate theorem in standalone file**
```lean
-- test_slow_theorem.lean
import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild

-- Copy theorem here
theorem step_pc42_brTrue : ... := by
  rw [registrationState]
  rw [step_brTrue]
  cases h : ...
  sorry
```

---

**Step 3: Bisect proof to find hot tactic**
```lean
theorem step_pc42_brTrue : ... := by
  trace "Start: {getHeartbeats}"
  rw [registrationState]
  trace "After rw registrationState: {getHeartbeats}"  -- ← Check heartbeat delta
  rw [step_brTrue]
  trace "After rw step_brTrue: {getHeartbeats}"
  cases h : ...
  trace "After cases: {getHeartbeats}"
  sorry
```

---

**Step 4: Apply targeted optimization**

If `rw [registrationState]` is slow:
- ✅ Ensure `@[irreducible]` is set
- ✅ Use custom unfold lemma instead of direct `rw`

If `simp` is slow:
- ✅ Replace with `simp only [specific_lemmas]`
- ✅ Check if simp set is too large

If `cases` is slow:
- ✅ Use `cases'` or `split` instead
- ✅ Provide explicit motive

---

**Step 5: Validate fix**
```bash
lake build test_slow_theorem.lean
# Before: 8.3s
# After: 0.3s  ✅ 27× speedup
```

---

## Summary

**Key debugging principles:**
1. ✅ Use diagnostic tools (`#check`, `#print`, trace)
2. ✅ Understand error messages (read carefully, don't guess)
3. ✅ Bisect failures (isolate the exact failing sub-proof)
4. ✅ Profile before optimizing (measure, don't guess)
5. ✅ Apply minimal fixes (targeted changes, not sledgehammers)

**Common fixes:**
- Type mismatches → Use `#check` to verify types
- `rfl` failures → Check for `@[irreducible]`, use `rw` or `simp`
- Slow proofs → Profile, find hotspot, apply targeted optimization
- Unification failures → Match pattern structure (e.g., `run` vs `step`)

**Resources:**
- Lean 4 documentation: https://lean-lang.org/lean4/doc/
- Mathlib4 tactics: https://leanprover-community.github.io/mathlib4_docs/
- CA-specific guides: `LEAN_PROOF_TACTICS_REFERENCE.md`, `ERROR_DIAGNOSIS_GUIDE.md`

---

**For additional help:** Review case studies in this guide, or see `TROUBLESHOOTING_GUIDE.md` for common issues.
