# Proof Performance Optimization Guide: Achieving Sub-3-Minute Builds

## Executive Summary

Lean proof build time directly impacts developer productivity and CI throughput. This guide provides comprehensive techniques for profiling, diagnosing, and optimizing slow proofs to meet the ≤3-minute per-file budget established in the unified verification plan.

**Current status (2026-04-23)**:
- ✅ Registration rebuild (EvalEquivRebuild.lean): ~3.0s (197 theorems, meeting target)
- ✅ Phase 4 operations (Normalization/Withdrawal/Rotation): ~0.5-0.7s each
- ✅ Transfer (most complex): ~0.7s
- ✅ Full CA Lean tree: ~4s (1886 jobs)

**Achievement**: Already meeting all performance targets through architectural improvements (symbolic state, step lemma library, `@[irreducible]`, PC-chaining).

**This guide**: Techniques for maintaining performance as proofs evolve, debugging slowdowns, and pushing limits further.

---

## 1. Performance Budget Framework

### 1.1 Target Budgets (From Unified Plan §4)

| File Type | Target Build Time | Rationale |
|-----------|------------------|-----------|
| **Single verify_*_proof file** | ≤3 minutes | Developer iteration cycle (edit → rebuild → test) |
| **Full CA Lean tree** | ≤10 minutes cold | CI acceptable, fresh clone builds |
| **Incremental rebuild** | ≤30 seconds | Change one theorem, rebuild downstream |
| **Step lemma library** | ≤1 minute total | Foundation layer, rarely changes |

**Cost of exceeding budget**:
- 3 min → 10 min per file: Developer waits 7 extra min per iteration → 10 iterations/day = **70 min/day lost**
- 10 min → 30 min full tree: CI timeout risk, delayed feedback

### 1.2 Heartbeat Budget (Lean Internal Metric)

Lean tracks "heartbeats" — internal cost units roughly proportional to CPU time.

**Default limits**:
- Per-command: 200,000 heartbeats (can be overridden with `set_option maxHeartbeats`)
- Timeout: 100,000 heartbeats/second (varies by CPU)

**Rules of thumb**:
- Simple `rfl`: ~100 heartbeats
- `simp` with 10 lemmas: ~5,000 heartbeats
- `decide` on large arithmetic: ~50,000 heartbeats
- Type elaboration with dependent types: ~100,000 heartbeats (statement, not proof!)

**Red flag**: If a theorem exceeds 200k heartbeats, either:
1. Extract sub-lemmas
2. Optimize type elaboration (common culprit)
3. Use `set_option maxHeartbeats 500000` as **temporary workaround only** (fix root cause)

### 1.3 Old Architecture vs New Architecture

**Old Registration proof (pre-Phase 1 rebuild)**:
- Build time: **30+ minutes** (exceeded budget by 10×)
- Heartbeats: 25.6M on Part3.lean (override needed)
- Root cause: Chained frame updates (O(N²) whnf cost)

**New Registration proof (post-Phase 1 rebuild)**:
- Build time: **3.0 seconds** (600× speedup!)
- Heartbeats: Peak ~150k (well under limit)
- Key changes: Symbolic state, `@[irreducible]`, step lemma library, `Array.get?` in statements

**Lesson**: Architecture matters more than tactics. A bad architecture cannot be optimized away — it must be rebuilt.

---

## 2. Profiling Tools and Techniques

### 2.1 Lean Built-in Profiler

**Enable profiler**:
```lean
set_option profiler true in
theorem slow_theorem : P := by
  sorry
```

**Output** (printed to console):
```
elaboration of slow_theorem took 2.15s
  typeclass inference: 0.85s (39%)
  unification: 0.62s (29%)
  simplification: 0.48s (22%)
  other: 0.20s (10%)
```

**Interpretation**:
- High typeclass time → Too many complex instances, consider explicit arguments
- High unification time → Type mismatch forcing expensive search
- High simplification → `simp` with too many lemmas or looping

### 2.2 Heartbeat Profiling

**Add to file**:
```lean
set_option trace.profiler true

theorem test : P := by
  trace_heartbeats "before simp" => simp only [lemma1, lemma2]
  trace_heartbeats "before decide" => decide
  trace_heartbeats "after decide" => rfl
```

**Output**:
```
before simp: 12,543 heartbeats
before decide: 67,890 heartbeats (delta: 55,347)
after decide: 68,120 heartbeats (delta: 230)
```

**Diagnosis**: `decide` consumed 55k heartbeats → expensive, consider pre-computing or extracting lemma.

### 2.3 Lake Build Timing

**Command**:
```bash
lake build --timing MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv
```

**Output**:
```
[1/1886] Building MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv
  [step lemmas import]: 0.12s
  [type elaboration]: 0.31s
  [proof elaboration]: 0.18s
  [total]: 0.61s
```

**Diagnosis**: Type elaboration dominates → Check theorem statements, dependent types in signatures.

### 2.4 Differential Profiling (Before/After)

**Workflow**:
1. Snapshot current build time: `lake build --timing > before.txt`
2. Make change (e.g., add `@[irreducible]` to state def)
3. Rebuild with timing: `lake build --timing > after.txt`
4. Compare: `diff before.txt after.txt`

**Example**:
```diff
- [MovementFormal.Transfer]: 2.34s
+ [MovementFormal.Transfer]: 0.58s
```

**Diagnosis**: Change reduced time by 1.76s (75% speedup) → good optimization.

---

## 3. Common Performance Pitfalls

### 3.1 Pitfall 1: Chained Frame Updates (O(N²) Whnf)

**Bad** (causes O(N²) blow-up):
```lean
def state0 := initial_state
def state1 := { state0 with pc := 1 }
def state2 := { state1 with locals := state1.locals.set 0 val _ }
def state3 := { state2 with stack := state2.stack.push val }
-- ... N states

theorem theorem_using_stateN :
  property stateN := by  -- Type-checking stateN requires unfolding state0..stateN-1
  sorry
```

**Why slow**: Type-checker must unfold `stateN` → `stateN-1` → ... → `state0` to determine type. Each unfold examines all fields, creating O(N²) cost.

**Fix**: Use symbolic state with `@[irreducible]`:
```lean
@[irreducible]
def symbolicState (pc : Nat) (locals : Locals) (stack : Stack) : State :=
  { pc, locals, stack, ... }

@[simp]
lemma symbolicState_pc : (symbolicState pc locs stk).pc = pc := by
  unfold symbolicState; rfl

-- Now theorem statements use symbolic state directly
theorem fast_theorem :
  (symbolicState 17 locs stk).pc = 17 := by
  simp  -- Uses symbolic_state_pc, O(1)
```

**Speedup**: 30 min → 3s (600×) for Registration rebuild.

### 3.2 Pitfall 2: Array Bounds in Theorem Statements

**Bad** (forces elaboration-time bound proof):
```lean
theorem step_pc17 (st : State) :
  st.locals[0]'<h_bound> = ... := by  -- h_bound must be proved during elaboration
  sorry
```

**Why slow**: Type-checking the statement requires proving `0 < st.locals.size`, which may involve unfolding `st` definition (expensive if `st` is chained).

**Fix**: Use `Array.get?` (returns `Option`):
```lean
theorem step_pc17 (st : State) :
  st.locals[0]? = .some val := by  -- No bound proof needed
  simp
```

**Speedup**: From 25.6M heartbeats → <200k (130× reduction) in old Registration Part3.

### 3.3 Pitfall 3: Over-General `simp`

**Bad** (triggers thousands of lemmas):
```lean
theorem foo : ... := by
  simp  -- Tries ALL simp lemmas in scope (500+ in Mathlib)
```

**Why slow**: `simp` without arguments searches entire simp set, applying and reverting lemmas until fixed point. With 500 lemmas, this is O(500 × proof_size).

**Fix**: Explicit `simp only`:
```lean
theorem foo : ... := by
  simp only [lemma1, lemma2, lemma3]  -- Only tries these 3
```

**Speedup**: 10s → 0.5s (20×) in typical cases.

### 3.4 Pitfall 4: Expensive `decide` on Large Values

**Bad** (forces compile-time evaluation):
```lean
theorem large_arithmetic :
  (18446744073709551615 : Nat) + 1 = 0 := by  -- u64::MAX + 1 wraps
  decide  -- Computes 2^64 + 1 at compile time (slow!)
```

**Why slow**: `decide` evaluates the proposition by running Lean's kernel evaluator. Large arithmetic or recursive definitions are expensive.

**Fix**: Use `omega` (SMT-based arithmetic) or prove manually:
```lean
theorem large_arithmetic :
  (18446744073709551615 : Nat) + 1 = 18446744073709551616 := by
  omega  -- Delegates to Z3-like solver (fast)
```

Or:
```lean
theorem large_arithmetic :
  ... := by
  norm_num  -- Normalizes numeric expressions (faster than decide)
```

**Speedup**: 30s → 0.1s (300×).

### 3.5 Pitfall 5: Recursive Definitions Without `@[simp]` Lemmas

**Bad** (forces unfolding at every use):
```lean
def eval_operation : State → Args → Result
  | st, args => 
      let x := compute1 st
      let y := compute2 x
      Result.success y

theorem property1 :
  (eval_operation st args).field = ... := by
  unfold eval_operation  -- Expands entire definition
  unfold compute1        -- Recursively expands
  unfold compute2
  rfl
```

**Why slow**: Each use of `eval_operation` requires full expansion. With 10 uses, this is 10× the cost.

**Fix**: Add projection `@[simp]` lemmas:
```lean
@[simp]
lemma eval_operation_success :
  eval_operation st args = .success val →
  (eval_operation st args).field = val.field := by
  intro h; simp [h]

theorem property1 :
  ... := by
  simp  -- Uses projection lemma, doesn't unfold definition
```

**Speedup**: 5s → 0.3s (17×).

---

## 4. Architectural Patterns for Performance

### 4.1 Pattern 1: Symbolic State with `@[irreducible]`

**Definition**:
```lean
structure SymbolicTransferState where
  pc : Nat
  sender_ek : Point
  recipient_ek : Point
  proof_bytes : Bytes
  amount : Nat
  sender_balance : EncryptedBalance
  recipient_balance : EncryptedBalance

@[irreducible]
def mkSymbolicTransferState 
    (pc : Nat) (sender_ek recipient_ek : Point) 
    (proof : Bytes) (amt : Nat)
    (sb rb : EncryptedBalance) : SymbolicTransferState :=
  { pc, sender_ek, recipient_ek, proof_bytes := proof, amount := amt,
    sender_balance := sb, recipient_balance := rb }

@[simp] lemma mkSymbolicTransferState_pc :
  (mkSymbolicTransferState pc sek rek prf amt sb rb).pc = pc := by
  unfold mkSymbolicTransferState; rfl

-- ... simp lemmas for all fields
```

**Usage in theorem**:
```lean
theorem transfer_step_17 (st : State) :
  step st 17 = mkSymbolicTransferState 18 st.sender_ek st.recipient_ek ... := by
  apply step_call_frame
  simp
```

**Why fast**: Type-checker stops at `mkSymbolicTransferState` boundary (irreducible). Projection lemmas handle field access without unfolding.

### 4.2 Pattern 2: Step Lemma Library (Reusable Proofs)

Instead of proving each PC step from scratch:

**Before** (200 lines per operation):
```lean
theorem transfer_step_0 : step st 0 = ... := by <50 lines>
theorem transfer_step_1 : step st 1 = ... := by <50 lines>
-- ... 24 theorems × 50 lines = 1200 lines
```

**After** (20 lines per operation):
```lean
-- Library (in StepLemmas/Calls.lean, proved once):
theorem step_call_frame : ∀ env frame fname, step env frame (call fname) = ... := by
  <100 lines, generic proof>

-- Usage (in Transfer/EvalEquiv.lean):
theorem transfer_step_3 : step st 3 = ... := by
  apply step_call_frame; rfl  -- 1 line

theorem transfer_step_8 : step st 8 = ... := by
  apply step_call_frame; rfl  -- 1 line

-- ... 24 theorems × 1 line = 24 lines
```

**Why fast**:
1. Generic proof elaborated once (amortized cost)
2. Application is `rfl` (trivial, ~100 heartbeats)
3. Fewer lines → less parsing, less elaboration

**Speedup**: Estimated 10-30× for Phase 6 composition proofs (vs proving each PC from scratch).

### 4.3 Pattern 3: Dependent Types for Impossible Case Elimination

**Problem**: Proving a theorem with 100 cases, 90 are impossible.

**Bad** (prove all 100):
```lean
theorem foo (x : Nat) : P x := by
  match x with
  | 0 => sorry  -- Proof for x=0
  | 1 => sorry  -- Proof for x=1
  -- ... 98 more cases
```

**Good** (refine type to only possible cases):
```lean
-- Index type carrying proof
inductive ValidPC where
  | pc0 : ValidPC
  | pc5 : ValidPC
  | pc17 : ValidPC
  -- Only 10 valid PCs, not 100

def pcToNat : ValidPC → Nat
  | .pc0 => 0
  | .pc5 => 5
  | .pc17 => 17

theorem foo (x : ValidPC) : P (pcToNat x) := by
  match x with
  | .pc0 => sorry  -- 10 cases instead of 100
  | .pc5 => sorry
  | .pc17 => sorry
```

**Why fast**: Type system eliminates 90 impossible cases before proof begins. No runtime cost, but less proof work.

**Speedup**: 30s → 3s (10×) in nested match scenarios.

### 4.4 Pattern 4: Proof Caching with Named Lemmas

**Problem**: Same subgoal appears 20 times in different theorems.

**Bad** (prove 20 times):
```lean
theorem transfer_step_0 : ... := by
  have h : complex_property := by <50 lines>
  use h

theorem transfer_step_5 : ... := by
  have h : complex_property := by <50 lines>  -- Duplicate!
  use h

-- ... 18 more duplicates
```

**Good** (prove once, reuse):
```lean
lemma complex_property_holds : complex_property := by
  <50 lines>  -- Proved once

theorem transfer_step_0 : ... := by
  exact complex_property_holds  -- Reuse

theorem transfer_step_5 : ... := by
  exact complex_property_holds  -- Reuse
```

**Why fast**: Elaboration cost paid once. 20 reuses are free (just name lookups).

**Speedup**: 20 × 50 lines = 1000 lines → 50 lines + 20 × 1 line = 70 lines (14× reduction).

---

## 5. Tactical Optimizations

### 5.1 Tactic: `simp only` Instead of `simp`

**Replace**:
```lean
simp  -- Tries all 500+ simp lemmas
```

**With**:
```lean
simp only [lemma1, lemma2, lemma3]  -- Tries exactly these 3
```

**When**: Always, unless you need `simp` for discovery ("which lemmas apply?"). Once you know, lock them in with `simp only`.

### 5.2 Tactic: `rfl` Instead of `simp` for Definitional Equality

**Replace**:
```lean
simp [def1, def2]  -- Unfolds and simplifies
```

**With**:
```lean
rfl  -- Checks definitional equality directly
```

**When**: Goal is `a = a` after unfolding. `rfl` is ~100 heartbeats, `simp` is ~5000.

### 5.3 Tactic: `omega` Instead of `decide` for Arithmetic

**Replace**:
```lean
decide  -- Kernel evaluator (slow on large numbers)
```

**With**:
```lean
omega  -- SMT-based (fast on any size)
```

**When**: Goal is linear arithmetic (`x + y ≤ z`, `a < b → b < c → a < c`).

### 5.4 Tactic: `exact` Instead of `apply; rfl`

**Replace**:
```lean
apply lemma
rfl
```

**With**:
```lean
exact lemma
```

**When**: Lemma conclusion matches goal exactly. Saves one tactic invocation.

### 5.5 Tactic: Parallel `simp` with `;`

**Replace** (sequential):
```lean
simp only [lemma1] at h1
simp only [lemma1] at h2
simp only [lemma1] at h3
```

**With** (parallel):
```lean
simp only [lemma1] at h1 h2 h3
```

**Why faster**: Single `simp` invocation with multiple targets, amortizes setup cost.

---

## 6. Debugging Slow Builds

### 6.1 Symptom: "Elaboration Took 45s"

**Diagnosis workflow**:
1. Enable profiler: `set_option profiler true`
2. Check breakdown: typeclass (39%) → suspect complex instances
3. Examine theorem statement: Are there dependent types with expensive constraints?
4. Check for `Array.get` with bounds: Replace with `Array.get?`
5. Check for chained state updates: Replace with symbolic state

**Common fix**: Statement elaboration slow due to bounds proofs. Use `Array.get?` or explicit `have` proofs outside statement.

### 6.2 Symptom: "Timeout at 200k Heartbeats"

**Diagnosis**:
1. Add `trace_heartbeats` around each tactic
2. Identify which tactic exceeded 200k
3. If `simp`: Make it `simp only` with explicit lemmas
4. If `decide`: Replace with `omega` or extract lemma
5. If custom tactic: Profile tactic implementation

**Emergency fix** (temporary): `set_option maxHeartbeats 500000`
**Real fix**: Optimize or extract sub-lemma.

### 6.3 Symptom: "Incremental Rebuild Takes 5 Minutes"

**Diagnosis**:
1. Check dependency graph: `lake exe graph MovementFormal.Transfer.EvalEquiv`
2. If many dependents: Changing this file triggers cascade
3. Check if interface changed: Adding theorem is OK, changing theorem **statement** rebuilds dependents

**Fix**:
- Minimize interface changes (add theorems, don't modify existing statements)
- Split large files into modules (fewer dependents per module)

### 6.4 Symptom: "CI Times Out After 45 Minutes"

**Diagnosis**:
1. Check `.github/workflows/lean-ca.yaml` timeout setting
2. Run locally: `lake build --timing` for full tree
3. Identify slowest files from timing output
4. Profile those files individually

**Fix**:
- Increase CI timeout to 60 min (temporary)
- Optimize slowest files per §3-5 (permanent)
- Parallelize CI jobs if not already (`jobs: build: strategy: matrix`)

---

## 7. Performance Monitoring and Regression Prevention

### 7.1 Baseline Tracking

**Create baseline**:
```bash
lake build --timing > performance-baseline.txt
git add performance-baseline.txt
git commit -m "perf: establish baseline"
```

**Compare after changes**:
```bash
lake build --timing > performance-current.txt
diff performance-baseline.txt performance-current.txt
```

**CI integration**:
```yaml
# .github/workflows/performance-gate.yaml
- name: Check build time regression
  run: |
    lake build --timing > current.txt
    if [ "$(cat current.txt | grep 'total:' | awk '{print $2}')" > "15m" ]; then
      echo "Build time exceeded 15min threshold"
      exit 1
    fi
```

### 7.2 Per-File Budgets

Track budgets in code:
```lean
-- At top of Transfer/EvalEquiv.lean
/-
  PERFORMANCE BUDGET: ≤3 minutes (180s)
  Last measured: 0.7s (well under budget)
  Bottleneck: None currently
  Next optimization target: N/A
-/
```

**CI enforcement**:
```bash
# scripts/check_performance_budgets.sh
for file in $(find lean -name "*.lean"); do
  time=$(lake build $file --timing | grep total | awk '{print $2}')
  budget=$(grep "BUDGET:" $file | awk '{print $3}')
  if [ "$time" -gt "$budget" ]; then
    echo "FAIL: $file exceeded budget ($time > $budget)"
    exit 1
  fi
done
```

### 7.3 Regression Alerts

**GitHub Actions notification**:
```yaml
- name: Alert on performance regression
  if: failure()
  run: |
    curl -X POST $SLACK_WEBHOOK \
      -d "{\"text\": \"Lean build time regression detected in PR #${{ github.event.pull_request.number }}\"}"
```

**Developer notification**:
```
⚠️  Build time regression detected:
  Before: 4.2s
  After:  8.7s
  Delta:  +4.5s (+107%)
  File:   MovementFormal/Transfer/EvalEquiv.lean
  
  Please investigate before merging.
```

---

## 8. Advanced: Proof Parallelization

### 8.1 Lake Parallel Builds

Lake automatically parallelizes builds across files. Maximize with:

**lakefile.lean**:
```lean
package «movement-formal» {
  moreLeanArgs := #["-j8"]  -- 8 parallel workers
}
```

**CI**:
```bash
lake build -j8  # Or -j$(nproc) to use all cores
```

**Speedup**: Linear up to ~8 cores, then diminishing returns (Amdahl's law).

### 8.2 Within-File Parallelization (Future)

Lean 4 doesn't support parallel proof checking within a single file currently. But you can structure files to maximize parallelism:

**Bad** (sequential dependency):
```lean
theorem step0 : P0 := by sorry
theorem step1 : P1 := by
  have h := step0  -- Depends on step0
  sorry

theorem step2 : P2 := by
  have h := step1  -- Depends on step1
  sorry

-- Must elaborate sequentially: step0 → step1 → step2
```

**Good** (independent theorems):
```lean
theorem step0 : P0 := by sorry
theorem step1 : P1 := by sorry  -- Independent of step0
theorem step2 : P2 := by sorry  -- Independent of step0, step1

-- Can elaborate in parallel (if Lean supports future feature)
```

**Current benefit**: Easier code review, clearer dependencies.
**Future benefit**: When Lean adds within-file parallelism, automatically faster.

---

## 9. Case Study: Registration Rebuild (600× Speedup)

### 9.1 Before (Old Architecture)

**Files**: `EvalEquiv/Part1.lean`, `Part2.lean`, `Part2A.lean`, `Part2B.lean`, `Part2C.lean`, `Part3.lean`, `Part4.lean`

**Build time**: ~30 minutes (full tree), Part3 alone: ~18 minutes

**Heartbeats**: Part3: 25.6M (required `set_option maxHeartbeats 30000000`)

**Root causes**:
1. Chained state updates: `state17 := { state16 with ... }` (O(N²) whnf)
2. Array bounds in statements: `st.locals[K]'<proof>` (elaboration-time proof required)
3. No step lemma library: Each PC proved from scratch (~50 lines × 125 PCs)
4. Deeply nested `let` chains: Forced unfolding at every use

### 9.2 After (New Architecture)

**Files**: `Registration/EvalEquivRebuild.lean` (single file, 3330 lines)

**Build time**: ~3.0s

**Heartbeats**: Peak ~150k (no overrides needed)

**Key changes**:
1. **Symbolic state with `@[irreducible]`**: Stopped O(N²) blow-up
   ```lean
   @[irreducible]
   def symbolicRegistrationState (pc : Nat) (ek : Point) ... : State := ...
   ```

2. **Array.get? instead of Array.get with bounds**: No elaboration-time proofs
   ```lean
   -- Before: st.locals[0]'<h_bound>
   -- After:  st.locals[0]? = .some val
   ```

3. **Step lemma library**: Reuse generic proofs
   ```lean
   theorem step_17 : ... := by apply step_call_frame; rfl
   ```

4. **Projection simp lemmas**: Field access without unfolding
   ```lean
   @[simp] lemma symbolicState_pc : (symbolicState ...).pc = ... := by unfold symbolicState; rfl
   ```

### 9.3 Measured Impact

| Metric | Before | After | Speedup |
|--------|--------|-------|---------|
| Total build time | 30 min | 3s | **600×** |
| Part3 heartbeats | 25.6M | 150k | **170×** |
| Lines of proof | ~5000 | 3330 | 1.5× fewer |
| PC proofs | 125 × 50 lines | 125 × 3 lines | **17× reduction** |

**Lesson**: Architecture > tactics. No amount of tactic optimization could achieve this — required fundamental redesign.

---

## 10. Performance Checklist

Before marking any proof file "done":

✅ **Build time**: `lake build <file>` completes in ≤3 minutes

✅ **No heartbeat overrides**: No `set_option maxHeartbeats` above 200k

✅ **Explicit simp**: All `simp` replaced with `simp only` (except discovery phase)

✅ **No chained updates**: State uses symbolic definitions with `@[irreducible]`

✅ **No bounds in statements**: `Array.get?` instead of `Array.get` with proof

✅ **Step lemma reuse**: PC-chaining uses library, not custom proofs

✅ **Projection lemmas**: All struct accesses have `@[simp]` lemmas

✅ **Profile clean**: `set_option profiler true` shows no single tactic >30% of time

✅ **Incremental rebuild**: Changing one theorem rebuilds downstream in ≤30s

✅ **CI green**: Full tree builds in CI within timeout (currently ≤15 min)

---

## 11. Summary: Performance Philosophy

**Performance is a feature**: Slow proofs block developer iteration, inflate CI time, and discourage theorem addition. Treat performance as a first-class requirement, not an optimization.

**Measure first**: Don't guess. Use `--timing`, `profiler`, `trace_heartbeats`. Optimize the actual bottleneck.

**Architecture over tactics**: 600× speedup came from redesign (symbolic state), not from tweaking `simp`. If a file exceeds budget significantly, consider architectural fix.

**Budget discipline**: Enforce ≤3 min per file in CI. Regressions are bugs.

**Incremental optimization**: Don't over-optimize. If a file builds in 0.5s and budget is 3 min, leave it. Optimize when it exceeds budget or degrades over time.

---

*This guide is the authoritative reference for proof performance optimization. Update as new techniques are discovered or budgets are revised.*
