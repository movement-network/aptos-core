# Proof Debugging: Advanced Strategies for Lean 4 Verification

**Version**: 1.0  
**Last Updated**: 2026-04-22  
**Status**: Production  
**Audience**: Verification engineers debugging complex proofs  
**Estimated Read Time**: 80 minutes  
**Prerequisites**: ADVANCED_LEAN_PROOF_TECHNIQUES_GUIDE.md  

---

## Table of Contents

1. [Overview](#overview)
2. [Systematic Debugging Methodology](#systematic-debugging-methodology)
3. [Understanding Error Messages](#understanding-error-messages)
4. [Trace and Profiling Tools](#trace-and-profiling-tools)
5. [Type Unification Failures](#type-unification-failures)
6. [Timeout and Performance Debugging](#timeout-and-performance-debugging)
7. [Tactic Failure Diagnosis](#tactic-failure-diagnosis)
8. [Heq and Dependent Type Issues](#heq-and-dependent-type-issues)
9. [Axiom and Sorry Tracking](#axiom-and-sorry-tracking)
10. [Proof Refactoring Strategies](#proof-refactoring-strategies)
11. [Common Proof Patterns Gone Wrong](#common-proof-patterns-gone-wrong)
12. [Emergency Recovery Procedures](#emergency-recovery-procedures)

---

## Overview

### When Proofs Go Wrong

**Common Failure Modes:**
1. **Type errors**: "expected X, got Y"
2. **Tactic failures**: "tactic 'rw' failed, pattern not found"
3. **Timeouts**: Elaboration takes too long
4. **Universe errors**: Universe level mismatch
5. **Recursion errors**: Stack overflow, infinite loops
6. **Sorry accumulation**: Temporary gaps become permanent

**This Guide's Approach:**

For each failure mode:
1. **Symptoms**: How to recognize it
2. **Root cause**: What's actually wrong
3. **Diagnosis**: How to investigate
4. **Fix**: How to resolve it
5. **Prevention**: How to avoid it

---

## Systematic Debugging Methodology

### The Debugging Loop

**Process:**
```
┌─────────────────────────────────────┐
│ 1. Reproduce Minimal Failure        │
│    - Isolate failing theorem        │
│    - Remove unrelated code          │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 2. Understand Error Message         │
│    - Read carefully                 │
│    - Identify expected vs. actual   │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 3. Inspect Proof State              │
│    - Use trace options              │
│    - Print intermediate goals       │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 4. Form Hypothesis                  │
│    - What's the root cause?         │
│    - How should it be fixed?        │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 5. Test Hypothesis                  │
│    - Try minimal fix                │
│    - Check if error changes         │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ 6. Apply Fix or Iterate             │
│    - If works: document lesson      │
│    - If fails: back to step 4       │
└─────────────────────────────────────┘
```

### Minimal Reproduction

**Goal:** Isolate the smallest proof that exhibits the failure.

**Technique:**
```lean
-- Original failing proof (200 lines)
theorem big_theorem : ... := by
  rw [lemma1]
  rw [lemma2]
  ... (198 more lines)
  rw [lemma200]  -- Fails here

-- Step 1: Binary search for failing line
theorem test1 : ... := by
  rw [lemma1]
  ... (first 100 lines)
  sorry  -- Does this half work?

theorem test2 : ... := by
  rw [lemma101]
  ... (second 100 lines)
  sorry  -- Or does this half fail?

-- Step 2: Narrow down to failing line
theorem test_minimal : ... := by
  rw [lemma199]
  rw [lemma200]  -- Just the failing part

-- Step 3: Simplify context
theorem test_minimal_simple :
    simplified_hypothesis →
    simplified_goal := by
  rw [lemma200]  -- Now easier to debug
```

**Example:**
```lean
-- Failing proof
theorem transfer_correct : complex_statement := by
  unfold transferState
  simp [step, run]
  rw [big_lemma]  -- Type error here
  sorry

-- Minimal reproduction
theorem minimal_fail :
    P → Q := by  -- Simplified types
  rw [big_lemma]  -- Still fails

#check big_lemma  -- Inspect lemma type
-- big_lemma : ∀ x : Nat, P x → Q x
-- But we have: P (not P x)
-- Root cause: need to apply big_lemma to specific x
```

---

## Understanding Error Messages

### Type Mismatch Errors

**Error:**
```
type mismatch
  transferState 5 ref locals
has type
  Frame (locals_length := 10)
but is expected to have type
  Frame (locals_length := 11)
```

**Diagnosis:**
```lean
-- Check types explicitly
#check transferState 5 ref locals
-- Output: Frame (locals_length := 10)

-- Check what's expected
#check expected_value
-- Output: Frame (locals_length := 11)

-- Root cause: Different dependent type indices
```

**Fix Options:**

**Option 1: Prove indices equal**
```lean
theorem locals_length_eq : locals_length 5 = locals_length 6 := by
  unfold locals_length
  rfl

theorem transfer_correct :
    transferState 5 ref locals = expected := by
  have h_eq := locals_length_eq
  -- Use h_eq to unify types
  sorry
```

**Option 2: Use heq**
```lean
theorem transfer_correct_heq :
    HEq (transferState 5 ref locals) expected := by
  -- Work with heterogeneous equality
  sorry
```

**Option 3: Refactor to avoid dependent types**
```lean
-- Instead of:
structure Frame (locals_length : Nat) where ...

-- Use:
structure Frame where
  locals : List Value
  h_length : locals.length = expected_length
```

### Pattern Not Found Errors

**Error:**
```
tactic 'rewrite' failed, did not find instance of the pattern in the target expression
  transferState ?pc ?ref ?locals
```

**Diagnosis:**
```lean
theorem failing_rewrite : goal := by
  -- Check what lemma expects
  #check lemma_to_apply
  -- lemma_to_apply : ∀ pc ref locals, transferState pc ref locals = ...
  
  -- Check current goal
  -- goal : transferState 5 ref' (locals.updated 0 val) = ...
  -- Problem: lemma expects exact "locals", we have "locals.updated 0 val"
  
  rw [lemma_to_apply]  -- Fails: pattern doesn't match
```

**Fix:**
```lean
theorem fixed_rewrite : goal := by
  -- Introduce variable for updated locals
  set locals' := locals.updated 0 val with h_locals'
  
  -- Now pattern matches
  rw [lemma_to_apply]
  
  -- Substitute back if needed
  rw [←h_locals']
```

### Universe Level Errors

**Error:**
```
universe level mismatch
  Type 1
has been assigned to
  Type 0
```

**Root Cause:**
Universe levels track type hierarchy:
- `Type 0` = types of values (Nat, Bool, ...)
- `Type 1` = types of types (Nat : Type 0, so Type 0 : Type 1)
- `Type 2` = types of types of types
- ...

**Example:**
```lean
-- Fails: universe mismatch
def bad_function (α : Type 0) : Type 1 :=
  α  -- α : Type 0, but expected Type 1

-- Fixed: correct universes
def good_function (α : Type u) : Type u :=
  α
```

**Debugging:**
```lean
set_option pp.universes true

#check my_function
-- Output: my_function.{u} : Type u → Type u

-- Check instantiation
#check my_function Nat
-- Output: my_function.{0} Nat : Type 0
```

---

## Trace and Profiling Tools

### Essential Trace Options

**1. Tactic Traces:**
```lean
set_option trace.Meta.Tactic true

theorem example : ... := by
  rw [lemma1]  -- Shows: [Meta.Tactic.rewrite] lemma1 : ...
  simp         -- Shows: [Meta.Tactic.simp] trying lemma X
  sorry
```

**2. Simp Traces:**
```lean
set_option trace.Meta.Tactic.simp true
set_option trace.Meta.Tactic.simp.rewrite true

theorem example : ... := by
  simp
  -- Output:
  -- [simp] trying: lemma1
  -- [simp.rewrite] lemma1: x + 0 ==> x
  -- [simp] trying: lemma2
  -- [simp.rewrite] lemma2: 0 + x ==> x
```

**3. Type Checking Traces:**
```lean
set_option trace.Meta.isDefEq true

theorem example : ... := by
  exact my_proof
  -- Shows: [isDefEq] trying to unify:
  --   expected: ...
  --   actual: ...
```

**4. Elaboration Traces:**
```lean
set_option trace.Elab.command true

def my_definition := ...
-- Shows elaboration steps for definition
```

### Profiling

**Time Profiling:**
```lean
set_option profiler true

theorem slow_proof : ... := by
  rw [lemma1]         -- 0.5s
  simp                -- 10.2s (BOTTLENECK!)
  rw [lemma2]         -- 0.3s
  sorry

-- Diagnose simp slowness
set_option trace.Meta.Tactic.simp true
-- Check which simp lemmas are slow
```

**Memory Profiling:**
```lean
set_option profiler.mem true

theorem memory_heavy : ... := by
  unfold big_definition  -- 500MB allocated
  simp                   -- 2GB allocated (PROBLEM!)
```

**Fix Memory Issues:**
```lean
-- Don't unfold large definitions
@[irreducible]
def big_definition := ...

-- Use simp lemmas instead
@[simp]
theorem big_definition_field : big_definition.field = ... := by
  unfold big_definition
  rfl

theorem memory_light : ... := by
  -- Don't unfold
  simp  -- Uses simp lemma, fast
```

### Interactive Debugging

**Tactic State Inspection:**
```lean
theorem debug_proof : ... := by
  rw [lemma1]
  trace "After lemma1: {goal}"  -- Print current goal
  
  simp
  trace "After simp: {goal}"
  
  have h : intermediate_fact := by
    trace "Proving intermediate: {goal}"
    sorry
  
  trace "Have h: {h}"
  sorry
```

**Proof Term Inspection:**
```lean
-- See actual proof term generated
#print my_theorem
-- Output: 200-line proof term

-- Check for large terms (performance issue)
#check @my_theorem
-- Output shows type with size annotation
```

---

## Type Unification Failures

### Common Unification Failures

**Failure 1: Definitional vs. Propositional Equality**

**Problem:**
```lean
def f (n : Nat) : Nat := n + 0

theorem bad_proof : f 5 = 5 := by
  rfl  -- Fails! f 5 doesn't unfold to 5 definitionally
```

**Fix:**
```lean
theorem good_proof : f 5 = 5 := by
  unfold f
  simp  -- Now 5 + 0 = 5 (simp lemma)
```

**Failure 2: Implicit Arguments**

**Problem:**
```lean
theorem my_lemma {α : Type} (x : α) : ... := ...

theorem bad_use : ... := by
  rw [my_lemma]  -- Which α? Lean can't infer
```

**Fix:**
```lean
theorem good_use : ... := by
  rw [@my_lemma Nat]  -- Explicit type
  -- or
  rw [my_lemma (α := Nat)]  -- Named argument
```

**Failure 3: Higher-Order Unification**

**Problem:**
```lean
theorem higher_order_lemma {f : Nat → Nat} : f 0 = 0 := ...

theorem bad_use : (fun x => x + 1) 0 = 0 := by
  rw [higher_order_lemma]  -- Can't unify (fun x => x + 1) with ?f
```

**Fix:**
```lean
theorem good_use : (fun x => x + 1) 0 = 0 := by
  have h := @higher_order_lemma (fun x => x + 1)
  exact h
```

### Debugging Unification

**Technique: Show Implicit Arguments**
```lean
set_option pp.explicit true
set_option pp.implicit true

#check my_function
-- Before: my_function : Nat → Nat
-- After: my_function.{0} (@Nat.{0}) : @Nat.{0} → @Nat.{0}
```

**Technique: Check Metavariables**
```lean
theorem debug_meta : ... := by
  rw [lemma]
  trace "{goal}"  -- Shows ?m_1, ?m_2 (unsolved metavariables)
  -- If metavariables remain, unification failed partially
```

---

## Timeout and Performance Debugging

### Diagnosing Slow Proofs

**Step 1: Profile**
```bash
# Build with profiling
lake build --profile MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv

# Output shows per-theorem times
# elaboration time: 45s for theorem transfer_complete
```

**Step 2: Binary Search**
```lean
-- Split proof in half
theorem transfer_part1 : intermediate_goal := by
  ... (first half)
  sorry

theorem transfer_part2 : final_goal := by
  have h := transfer_part1
  ... (second half)
  sorry

-- Profile each half
-- Identify which half is slow
```

**Step 3: Identify Bottleneck**
```lean
set_option profiler true

theorem transfer_complete : ... := by
  rw [lemma1]         -- 0.5s
  rw [lemma2]         -- 0.3s
  simp                -- 40s (BOTTLENECK!)
  rw [lemma3]         -- 0.4s
```

### Common Performance Issues

**Issue 1: Bare Simp**

**Problem:**
```lean
theorem slow : ... := by
  simp  -- Tries all simp lemmas in scope (thousands)
```

**Fix:**
```lean
theorem fast : ... := by
  simp only [specific_lemma1, specific_lemma2]
  -- Or
  simp [specific_lemma1, specific_lemma2]
```

**Issue 2: Large Unfoldings**

**Problem:**
```lean
theorem slow : ... := by
  unfold transferState  -- Expands 500-line definition
  simp  -- Now has to simplify huge term
```

**Fix:**
```lean
-- Mark definition irreducible
@[irreducible]
def transferState := ...

-- Provide simp lemmas for projections
@[simp]
theorem transferState_pc : (transferState ...).pc = ... := by
  unfold transferState; rfl

theorem fast : ... := by
  simp  -- Uses simp lemma, doesn't unfold
```

**Issue 3: Heq Elaboration**

**Problem:**
```lean
theorem slow : HEq x y := by
  -- Heq is 2-3x slower than regular equality
  sorry
```

**Fix:**
```lean
-- Prove type equality first
theorem type_eq : typeof x = typeof y := by ...

-- Then use regular equality
theorem fast : x = y := by
  have h_type := type_eq
  -- Use h_type to convert
  sorry
```

### Timeout Recovery

**When Elaboration Times Out:**

**Strategy 1: Increase Timeout**
```lean
set_option maxHeartbeats 200000  -- Default: 200000 (20s)

theorem slow_but_correct : ... := by
  sorry  -- Now has more time
```

**Strategy 2: Split Proof**
```lean
-- Instead of one huge proof
theorem huge : ... := by
  ... (1000 lines, times out)

-- Split into chunks
theorem chunk1 : ... := by ... (200 lines)
theorem chunk2 : ... := by ... (200 lines)
theorem chunk3 : ... := by ... (200 lines)
theorem chunk4 : ... := by ... (200 lines)
theorem chunk5 : ... := by ... (200 lines)

theorem huge : ... := by
  have h1 := chunk1
  have h2 := chunk2
  have h3 := chunk3
  have h4 := chunk4
  have h5 := chunk5
  -- Combine (fast)
```

**Strategy 3: Use Compiled Lemmas**
```lean
-- Expensive computation done once at definition
def precomputed_value := expensive_computation

-- Used many times in proofs (fast)
theorem use_precomputed : ... := by
  rw [precomputed_value]
```

---

## Tactic Failure Diagnosis

### Why Tactics Fail

**Tactic: `rw [lemma]`**

**Failure Modes:**
1. **Pattern not found**
   ```lean
   -- Lemma: ∀ x, f x = g x
   -- Goal: f (h y) = g (h y)
   rw [lemma]  -- Fails: can't match f ?x with f (h y)
   ```
   **Fix:** `rw [lemma (h y)]` or `simp [lemma]`

2. **Type mismatch**
   ```lean
   -- Lemma: ∀ (x : Nat), f x = g x
   -- Goal: f true = g true  (Bool, not Nat)
   rw [lemma]  -- Fails: type mismatch
   ```
   **Fix:** Use correct lemma for Bool

3. **Universe mismatch**
   ```lean
   -- Lemma: ∀ (α : Type 0), f α = g α
   -- Goal: f (Type 0) = g (Type 0)
   rw [lemma]  -- Fails: Type 0 : Type 1, not Type 0
   ```
   **Fix:** Polymorphic universe levels

**Tactic: `simp`**

**Failure Modes:**
1. **Infinite loop**
   ```lean
   @[simp] theorem bad_simp : f (g x) = g (f x) := ...
   
   theorem fails : f (g (g x)) = ... := by
     simp  -- Loops: f(g(g x)) → g(f(g x)) → g(g(f x)) → f(g(g(f x))) → ...
   ```
   **Fix:** Don't mark as simp, or use direction-preserving simp lemmas

2. **Doesn't simplify enough**
   ```lean
   theorem not_simplified : complex_expr = simple_expr := by
     simp  -- Simplifies partially, doesn't reach simple_expr
   ```
   **Fix:** Add more simp lemmas, or use `simp_all`

3. **Too slow**
   ```lean
   theorem slow : ... := by
     simp  -- Tries 10,000 simp lemmas
   ```
   **Fix:** `simp only [relevant_lemmas]`

**Tactic: `induction`**

**Failure Modes:**
1. **Can't generalize**
   ```lean
   theorem bad_induction (n : Nat) : P n := by
     have h : Q n := ...  -- Uses n
     induction n  -- Fails: can't generalize n in h
   ```
   **Fix:** `induction n generalizing h` or reorder

2. **Motive not well-formed**
   ```lean
   theorem bad_motive : ... := by
     induction h : n  -- h : ... isn't right form
   ```
   **Fix:** Check induction syntax

---

## Heq and Dependent Type Issues

### When Heq Appears

**Symptom:**
```lean
-- Goal shows HEq instead of Eq
goal : HEq (transferState 5 locals₁) (transferState 6 locals₂)
```

**Root Cause:** Dependent types differ
```lean
transferState 5 locals₁ : Frame (locals_length := f 5)
transferState 6 locals₂ : Frame (locals_length := f 6)

-- f 5 ≠ f 6 (different indices)
-- Can't use Eq, must use HEq
```

### Heq Elimination

**Strategy 1: Prove Index Equality**
```lean
theorem indices_equal : f 5 = f 6 := by
  unfold f
  rfl  -- Both evaluate to 10

theorem eliminate_heq :
    (transferState 5 locals₁) = (transferState 6 locals₂) := by
  have h_eq := indices_equal
  subst h_eq  -- Now types match, can use Eq
  sorry
```

**Strategy 2: Heq-to-Eq Bridge**
```lean
theorem heq_to_eq {α : Type} (x y : α) (h : HEq x y) : x = y := by
  cases h
  rfl

theorem use_bridge :
    (transferState 5 locals₁) = (transferState 6 locals₂) := by
  have h_heq : HEq ... := ...
  exact heq_to_eq _ _ h_heq
```

**Strategy 3: Avoid Dependent Types**
```lean
-- Instead of dependent index
structure Frame (n : Nat) where
  locals : { l : List Value // l.length = n }

-- Use constraint
structure Frame where
  locals : List Value
  n : Nat
  h : locals.length = n

-- Now all Frames have same type (no dependent index)
```

### Debugging Heq Proofs

**Check Where Heq Originates:**
```lean
theorem debug_heq : HEq x y := by
  trace "{x} : {type_of x}"
  trace "{y} : {type_of y}"
  -- See which types differ
  sorry
```

**Minimize Heq Usage:**
```lean
-- Bad: Heq everywhere
theorem bad : HEq (f (g x)) (f (g y)) := by
  have h1 : HEq (g x) (g y) := ...
  have h2 : HEq (f (g x)) (f (g y)) := ...
  sorry

-- Good: Eliminate early
theorem good : (f (g x)) = (f (g y)) := by
  have h1 : g x = g y := heq_to_eq _ _ ...
  rw [h1]
  rfl
```

---

## Axiom and Sorry Tracking

### Finding Axioms

**Command:**
```lean
#print axioms my_theorem
-- Output:
-- ax1: cryptographic_assumption
-- ax2: oracle_soundness
-- ax3: ...
```

**Check Axiom Count:**
```bash
#!/bin/bash
# count_axioms.sh

grep -r "axiom" lean/**/*.lean | grep -v "^--" | wc -l
```

**Automated Check:**
```lean
-- In CI/CD
#check my_theorem
-- Verify axiom count hasn't increased
```

### Sorry Management

**Finding Sorries:**
```bash
# Find all sorry in production code
grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/ \
  --include="*.lean" | grep -v "TEMPORARY"
```

**Tracking Temporary Sorries:**
```lean
-- Annotate temporary sorries
axiom temp_lemma_remove_by_2026_Q2 : P → Q  -- TEMPORARY

theorem uses_temp : ... := by
  have h := temp_lemma_remove_by_2026_Q2
  sorry  -- TEMPORARY: depends on temp_lemma
```

**Sorry Removal Plan:**
```markdown
# Sorry Removal Roadmap

## High Priority (Block Release)
- [ ] transfer_soundness (4 hours, Owner: Alice)
- [ ] withdrawal_completeness (6 hours, Owner: Bob)

## Medium Priority (Next Quarter)
- [ ] normalization_frame_conditions (2 hours, Owner: Carol)

## Low Priority (Technical Debt)
- [ ] optimization_lemma (nice-to-have)
```

---

## Proof Refactoring Strategies

### When to Refactor

**Signs Proof Needs Refactoring:**
1. >200 lines in single theorem
2. Elaborates >20 seconds
3. Repeated proof patterns
4. Hard to understand
5. Breaks frequently on small changes

### Refactoring Technique 1: Lemma Extraction

**Before:**
```lean
theorem monolithic : ... := by
  rw [big_step]
  · unfold step
    split <;> simp
    cases h : oracle_result
    · -- 50 lines for failure case
      sorry
    · -- 50 lines for success case
      sorry
  rw [another_big_step]
  · -- Another 50 lines
    sorry
  -- ... (repeat 5 more times)
```

**After:**
```lean
theorem oracle_failure_case : ... := by
  -- Extracted 50 lines
  sorry

theorem oracle_success_case : ... := by
  -- Extracted 50 lines
  sorry

theorem monolithic : ... := by
  rw [big_step]
  · cases h : oracle_result
    · exact oracle_failure_case
    · exact oracle_success_case
  rw [another_big_step]
  · exact another_extracted_lemma
```

### Refactoring Technique 2: State Simplification

**Before:**
```lean
structure ComplicatedState where
  field1 : Nat
  field2 : Bool
  field3 : List Value
  field4 : Address
  -- ... 20 more fields
  h_invariant : complex_property field1 field2 field3 ...
```

**After:**
```lean
@[irreducible]
structure ComplicatedState where
  field1 : Nat
  field2 : Bool
  -- ... (fields)
  h_invariant : complex_property field1 field2 ...

-- Provide targeted simp lemmas
@[simp]
theorem ComplicatedState_field1 : state.field1 = ... := by
  unfold ComplicatedState; rfl
```

### Refactoring Technique 3: Proof Automation

**Before:**
```lean
theorem step_0 : step (state_at 0) = some (state_at 1) := by
  unfold step; split <;> simp; rfl

theorem step_1 : step (state_at 1) = some (state_at 2) := by
  unfold step; split <;> simp; rfl

-- ... (repeat 50 times)
```

**After:**
```lean
-- Custom tactic
syntax "step_auto" : tactic
macro_rules
| `(tactic| step_auto) => `(tactic| (unfold step; split <;> simp; rfl))

theorem step_0 : step (state_at 0) = some (state_at 1) := by step_auto
theorem step_1 : step (state_at 1) = some (state_at 2) := by step_auto
-- ... (50 one-liners)
```

---

## Common Proof Patterns Gone Wrong

### Pattern 1: Nested Induction

**Anti-Pattern:**
```lean
theorem bad_nested_induction (m n : Nat) : P m n := by
  induction m with
  | zero =>
    induction n with  -- Nested induction (hard to reason about)
    | zero => sorry
    | succ n ih => sorry
  | succ m ihm =>
    induction n with
    | zero => sorry
    | succ n ihn => sorry
```

**Better:**
```lean
theorem good_induction (m n : Nat) : P m n := by
  induction m, n using Nat.strong_induction_on with
  | intro m n ih =>
    -- Single induction on both simultaneously
    sorry
```

### Pattern 2: Proof by Cases Explosion

**Anti-Pattern:**
```lean
theorem bad_cases : ... := by
  cases x <;> cases y <;> cases z  -- 2³ = 8 cases
  all_goals sorry  -- Most cases identical
```

**Better:**
```lean
theorem good_cases : ... := by
  -- Extract commonality
  have h_common : ∀ x y z, common_property x y z := by sorry
  
  cases x
  · exact h_common none y z
  · exact h_common (some x) y z
```

### Pattern 3: Over-Generalization

**Anti-Pattern:**
```lean
-- Too general: hard to prove
theorem bad_general {α β γ : Type} (f : α → β → γ) : ... := by
  sorry  -- Stuck: too abstract
```

**Better:**
```lean
-- Specific to needs
theorem good_specific : transfer_function args = result := by
  unfold transfer_function
  -- Concrete, provable
  sorry
```

---

## Emergency Recovery Procedures

### Proof Broke After Dependency Update

**Symptom:** Proofs that compiled yesterday now fail after Lean update.

**Recovery:**
```bash
# Step 1: Identify what changed
git diff lakefile.lean
# Check Lean version change

# Step 2: Check release notes
# Look for breaking changes in Lean 4 release notes

# Step 3: Try old version
lake update --restore
lake build

# Step 4: If must upgrade, fix proofs
# Common fixes:
# - `simp` behavior changed → use `simp only`
# - Tactic renamed → update to new name
# - Library reorganized → update imports
```

### Massive Proof Corruption

**Symptom:** Git merge corrupted proofs, 100s of errors.

**Recovery:**
```bash
# Step 1: Backup current state
git stash

# Step 2: Check last working commit
git log --oneline
git checkout <last-working-commit>
lake build  # Verify it works

# Step 3: Reapply changes carefully
git checkout main
git merge <last-working-commit> --strategy-option=theirs

# Step 4: Rebuild incrementally
lake build MovementFormal.Experimental.ConfidentialAsset.Registration
# Fix errors one module at a time
```

### Out of Memory During Compilation

**Symptom:** `lake build` killed by OS, out of memory error.

**Recovery:**
```bash
# Step 1: Build one file at a time
lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.State
lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.StepLemmas
# ... (one at a time)

# Step 2: Identify memory-heavy file
ps aux | grep lean  # Monitor memory usage
# File using >8GB RAM is problem

# Step 3: Fix memory issue
# - Split large proofs
# - Mark definitions irreducible
# - Use simp only instead of bare simp
```

---

## Cross-References

### Related Documentation

**Techniques:**
- `ADVANCED_LEAN_PROOF_TECHNIQUES_GUIDE.md` - Advanced proof patterns
- `LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md` - Performance tuning
- `PHASE_6_PC_CHAINING_DETAILED_TUTORIAL.md` - Basic proof techniques

**Debugging:**
- `INTEGRATION_TESTING_AND_CROSS_LAYER_VALIDATION_GUIDE.md` - Cross-layer debugging
- `MOVE_BYTECODE_AND_VM_EXECUTION_DEEP_DIVE.md` - Bytecode debugging

### External Resources

**Lean 4:**
- [Lean 4 Manual](https://lean-lang.org/lean4/doc/) - Official docs
- [Zulip Chat](https://leanprover.zulipchat.com/) - Community help
- [Lean 4 GitHub Issues](https://github.com/leanprover/lean4/issues) - Bug reports

---

## Maintenance

### Document Ownership

- **Author**: Verification team
- **Reviewers**: Lean experts
- **Approver**: Tech lead
- **Last Review**: 2026-04-22
- **Next Review**: 2026-07-22 (quarterly)

### Feedback

Debugging questions or new patterns discovered?
- **Lean help**: verification-team@movementlabs.xyz
- **Bug reports**: GitHub issues
- **Pattern contributions**: Submit PR with examples

---

**End of Guide**

Total pages: ~35 (~28K characters)
