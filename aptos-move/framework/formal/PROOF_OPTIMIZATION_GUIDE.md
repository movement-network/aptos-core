# Proof Optimization Guide

**Last updated:** 2026-04-23

Guide to optimizing Lean proof performance, reducing heartbeat usage, and improving build times for CA formal verification.

---

## Table of Contents

1. [Understanding Performance](#understanding-performance)
2. [Common Performance Issues](#common-performance-issues)
3. [Optimization Techniques](#optimization-techniques)
4. [Profiling Tools](#profiling-tools)
5. [Case Studies](#case-studies)
6. [Best Practices](#best-practices)

---

## Understanding Performance

### Metrics

**Heartbeats:**
- CPU cycles consumed during elaboration
- Default limit: 200,000
- High heartbeat usage (>100,000) indicates inefficient proofs

**Build Time:**
- Wall-clock time to compile a file
- Target: <3 minutes per operation file
- Current: ~3s per operation (well within budget)

**Memory Usage:**
- RAM consumed during proof checking
- Large proofs can exceed available memory
- Symptoms: Swapping, slow builds, crashes

### What Makes Proofs Slow?

1. **Deep type unification**
   - Complex dependent types
   - Long definitional equality chains
   - Nested structures

2. **Excessive whnf (weak-head normal form)**
   - Large definitions being unfolded
   - Chained state transformations
   - Deeply nested pattern matches

3. **Tactic overhead**
   - Slow tactics (`simp` with large lemma sets)
   - Repeated tactic calls
   - Inefficient proof search

---

## Common Performance Issues

### Issue 1: Chained Frame Definitions

**Problem:**
```lean
def frame0 : Frame := initial
def frame1 : Frame := {frame0 with pc := 1}
def frame2 : Frame := {frame1 with pc := 2, locals := ...}
...
def frame50 : Frame := {frame49 with ...}
```

**Why slow:** Each frame unfolds all previous frames during type checking.
Cost: O(N²) where N = number of frames.

**Solution:** Use symbolic state with `@[irreducible]`
```lean
@[irreducible] def symbolicState : VerifyState := {
  pc := ...,
  locals := Array.mk [...],
  stack := [...],
  ...
}

@[simp] lemma symbolicState_pc : symbolicState.pc = N := by
  unfold symbolicState; rfl
```

### Issue 2: Heartbeat Limit Exceeded

**Symptoms:**
```
maximum heartbeat threshold reached (196,534 heartbeats)
```

**Immediate fix:**
```lean
set_option maxHeartbeats 400000 in
theorem expensive_proof : ... := ...
```

**Long-term fix:** Optimize the proof (see techniques below)

### Issue 3: Slow `simp` Calls

**Problem:**
```lean
simp  -- Takes 30 seconds, high heartbeat usage
```

**Diagnosis:**
```lean
simp?  -- Shows which lemmas it's trying
```

**Solution:**
```lean
-- Option 1: Be explicit
simp only [lemma1, lemma2, lemma3]

-- Option 2: Simplify manually first
have h : complicated_term = simplified_term := by rfl
simp [h]

-- Option 3: Use rw instead
rw [lemma1, lemma2]
```

### Issue 4: Array Bounds Proofs

**Problem:**
```lean
locals[5]'<proof_that_5_<_locals.size>
```

Proof forces unfolding of entire locals array during elaboration.

**Solution:** Use `Array.get?`
```lean
match locals.get? 5 with
| some val => ...
| none => absurd  -- Prove this case is impossible
```

---

## Optimization Techniques

### Technique 1: Use `@[irreducible]`

**When:** Large definitions that don't need to be unfolded.

**How:**
```lean
@[irreducible] def expensiveComputation : Result := ...

-- Expose interface via simp lemmas
@[simp] lemma expensiveComputation_field1 :
  expensiveComputation.field1 = value := by
  unfold expensiveComputation; rfl
```

**Effect:** Stops automatic unfolding, reducing whnf cost.

### Technique 2: Break Large Proofs into Lemmas

**Before:**
```lean
theorem big_proof : complicated_statement := by
  -- 200 lines of tactics
  ...
```

**After:**
```lean
lemma helper1 : part1 := by
  -- 50 lines
  ...

lemma helper2 : part2 := by
  -- 50 lines
  ...

theorem big_proof : complicated_statement := by
  apply main_theorem helper1 helper2
```

**Effect:**
- Each lemma typechecks independently
- Incremental compilation
- Easier to debug

### Technique 3: Simplify Before Tactics

**Before:**
```lean
theorem foo : very_complicated_lhs = result := by
  simp  -- Has to work with complicated term
```

**After:**
```lean
theorem foo : very_complicated_lhs = result := by
  show simplified_lhs = result  -- Definitionally equal
  simp  -- Now working with simple term
```

or

```lean
theorem foo : very_complicated_lhs = result := by
  have h : very_complicated_lhs = simplified_lhs := by rfl
  rw [h]
  simp
```

**Effect:** Reduces term size during tactic execution.

### Technique 4: Use `exact` Instead of Tactics

**Before:**
```lean
theorem foo : bar := by
  simp
  rw [lemma1]
  apply lemma2
  -- ... many more tactics
```

**After (if you know the proof term):**
```lean
theorem foo : bar :=
  proof_term
```

**Effect:** No tactic overhead, direct term construction.

### Technique 5: Avoid Deep Pattern Matches

**Before:**
```lean
match x with
| case1 =>
  match y with
  | subcase1 =>
    match z with
    | subsubcase1 => ...
```

**After:**
```lean
-- Extract to separate lemmas
lemma handle_case1_subcase1_subsubcase1 : ... := ...

-- Use lemmas in main match
match x with
| case1 =>
  match y with
  | subcase1 => handle_case1_subcase1 z
```

**Effect:** Reduces nesting depth, improves readability.

---

## Profiling Tools

### Built-in Profiling

```lean
set_option profiler true in
theorem my_proof : ... := ...
```

Output shows time spent in each tactic.

### Build Profiling

```bash
# Time each file build
lake build --verbose 2>&1 | grep "Building" | while read line; do
  echo "$line"
  time lake build $(echo "$line" | awk '{print $2}')
done
```

### Heartbeat Counting

```bash
# Find high-heartbeat theorems
grep -r "set_option maxHeartbeats" lean/ --include="*.lean"
```

### Memory Profiling

```bash
# Monitor memory during build
while true; do
  ps aux | grep lake | grep -v grep
  sleep 1
done > memory_profile.log &

lake build
kill %1  # Stop monitoring
```

---

## Case Studies

### Case Study 1: Registration Rebuild (Phase 1)

**Before (old EvalEquiv):**
- Build time: 30+ minutes
- Heartbeat limit: 25.6M (128× default)
- Files: 7 (Part1-Part4, split to manage size)

**After (EvalEquivRebuild):**
- Build time: 3 seconds
- Heartbeat limit: Default (200K)
- Files: 1 (all in EvalEquivRebuild.lean)

**Optimizations applied:**
1. `@[irreducible]` symbolic state
2. `Array.get?` instead of bounded access
3. Per-instruction-class step lemmas
4. No chained frames

**Result:** 600× speedup

### Case Study 2: Transfer EvalEquiv (Phase 4)

**Initial version:**
- Build time: ~5 minutes
- Heartbeat usage: ~300K (exceeding default)

**Optimized:**
- Build time: ~240ms
- Heartbeat usage: ~180K (within default)

**Optimizations:**
1. Broke 100-line proof into 5 lemmas
2. Used `show` to simplify terms before `simp`
3. Replaced generic `simp` with `simp only [specific_lemmas]`

**Result:** 75× speedup

---

## Best Practices

### 1. Design for Performance from Day 1

**Do:**
- Use `@[irreducible]` on large definitions
- Expose interface via `@[simp]` projection lemmas
- Use `Array.get?` in theorem statements
- Plan proof structure before writing

**Don't:**
- Chain frame definitions (`{prev with ...}`)
- Use bounded array access (`arr[i]'<proof>`)
- Write 200-line monolithic proofs
- Hope to optimize later

### 2. Iterate Incrementally

**Workflow:**
```lean
-- Start with sorry to check types
theorem new_theorem : statement := by sorry

-- Add structure
theorem new_theorem : statement := by
  have part1 : ... := by sorry
  have part2 : ... := by sorry
  exact combine part1 part2

-- Fill in parts one at a time
-- Measure performance as you go
```

### 3. Profile Early, Profile Often

**After every significant addition:**
```bash
# Time the build
time lake build MovementFormal.Path.To.File

# If >30s, investigate
set_option profiler true in
theorem slow_proof : ... := ...
```

### 4. Learn From Existing Code

**Study fast files:**
- `lean/MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean` (3s)
- `lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean` (240ms)

**Study patterns:**
- How are states defined?
- How are proofs structured?
- What tactics are used?

### 5. When in Doubt, Ask

**Before spending hours optimizing:**
- Ask team members
- Check documentation
- Post in discussion channels

---

## Quick Reference

### Slow proof checklist:

- [ ] Using `@[irreducible]` on large definitions?
- [ ] Using `Array.get?` instead of bounded access?
- [ ] Proof broken into <50 line chunks?
- [ ] Using `show` to simplify before tactics?
- [ ] Using `simp only` instead of generic `simp`?
- [ ] Avoiding deep pattern match nesting?
- [ ] Profiled to identify bottleneck?

### Performance targets:

| Metric | Target | Current (Registration) |
|--------|--------|------------------------|
| Per-file build | <3 min | ~3s |
| Heartbeat usage | <200K | ~180K |
| Sorry count | 0 | 0 |
| Proof length | <50 lines | ~20 lines avg |

### Commands:

```bash
# Profile build
set_option profiler true in
theorem my_proof : ... := ...

# Find slow files
lake build --verbose 2>&1 | grep "Building"

# Check heartbeat usage
grep "maxHeartbeats" lean/ -r --include="*.lean"

# Clean rebuild
cd lean && lake clean && lake exe cache get && lake build
```

---

## Summary

**Key principles:**
1. **Design for performance** - Use `@[irreducible]`, `Array.get?`, modular structure
2. **Break into pieces** - <50 line proofs, extract lemmas
3. **Simplify before tactics** - Use `show`, `have` to reduce term size
4. **Profile and measure** - Know where time is spent
5. **Learn from examples** - Study fast existing code

**Performance hierarchy:**
1. `exact proof_term` - Fastest (no tactics)
2. `show ...; rw [...]` - Fast (simple tactics on simplified terms)
3. `simp only [specific]` - Medium (targeted simplification)
4. `simp` - Slow (searches large lemma set)
5. `sorry` - Instant but incomplete! (Development only)

**When optimizing:**
- Start with the slowest files (use `lake build --verbose`)
- Focus on high-heartbeat theorems first
- Measure before and after each change
- Don't over-optimize - "fast enough" is good enough

Happy optimizing! ⚡
