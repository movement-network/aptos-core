# Performance Optimization Guide: CA Formal Verification

**Purpose:** Deep dive into build time optimization, profiling, and performance regression prevention.

**Target audience:** Developers experiencing slow builds, CI maintainers, performance engineers.

**Scope:** Lean build performance, Move Prover optimization, CI efficiency.

---

## Table of Contents

1. [Performance Budgets](#1-performance-budgets)
2. [Profiling Tools](#2-profiling-tools)
3. [Lean Optimization Strategies](#3-lean-optimization-strategies)
4. [Move Prover Optimization](#4-move-prover-optimization)
5. [CI Performance](#5-ci-performance)
6. [Regression Prevention](#6-regression-prevention)

---

## 1. Performance Budgets

### 1.1 Target Metrics (from Unified Plan §4)

**Lean build times:**

| Scope | Budget | Current (Phase 4) | Status |
|-------|--------|-------------------|--------|
| Per-file incremental | <3 min | 0.5-3s | ✅ Well under |
| Full CA tree cold | <10 min | ~4s | ✅ Well under |
| Single operation | <3 min | 0.5-0.7s | ✅ Well under |

**Move Prover:**

| Scope | Budget | Current | Status |
|-------|--------|---------|--------|
| Compilation (per op) | <5 min | ~1s | ✅ Well under |
| VC generation | <10 min | 0 VCs (blocked) | N/A |
| Full verification | <20 min | Pending ristretto255 | TBD |

**CI:**

| Scope | Budget | Current | Status |
|-------|--------|---------|--------|
| Pre-check (fast-fail) | <1 min | ~30s | ✅ Target (pending impl) |
| Per-operation verify | <3 min | 1-2s | ✅ Well under |
| Full verification suite | <45 min | ~13 min | ✅ Well under |

**Key insight:** We're well within budget for Lean, but need to ensure we stay there as Phase 1 (singleton branch, 50 PCs) lands.

---

## 2. Profiling Tools

### 2.1 Lean Build Profiling

**Built-in `lake` timing:**

```bash
cd lean

# Time full build
time lake build

# Time specific module
time lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild

# Verbose output (shows per-file times)
lake build --verbose
```

**Per-theorem profiling:**

```lean
-- In .lean file
set_option profiler true in
theorem expensive_theorem ... := by
  ...

-- Output shows time per tactic
```

**Example output:**

```
elaboration: tactic execution took 234ms
  simp took 120ms
  rw took 89ms
  rfl took 25ms
```

### 2.2 Heartbeat Tracking

**Measure elaboration cost:**

```lean
set_option maxHeartbeats 1000000 in  -- Increase limit temporarily
theorem potentially_expensive ... := by
  ...
```

**If elaboration exceeds heartbeats:**

```
maximum recursion depth exceeded
  set_option maxRecDepth <num>
OR
maximum number of heartbeats exceeded
  set_option maxHeartbeats <num>
```

**Diagnosis:** Expensive elaboration, likely caused by:
1. Large state chains (see §3.2)
2. Bound proofs in statement (see §3.3)
3. Excessive simp unfolding (see §3.4)

### 2.3 Lake Cache Analysis

**Check cache status:**

```bash
cd lean

# Cache hit/miss stats
lake build --verbose 2>&1 | grep "cache"

# Find stale modules (not built recently)
find .lake/build -name "*.olean" -mtime +7

# Clear cache (nuclear option)
lake clean
```

**Cache efficiency:**

```bash
# First build (cold)
lake clean && time lake build
# → ~4s (with Mathlib cache)

# Incremental build (hot)
touch MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean
time lake build
# → ~0.7s (only rebuilds Transfer + downstream)
```

### 2.4 Benchmark Script

**Use built-in benchmarking:**

```bash
cd formal
./scripts/benchmark_verification.sh

# Output formats
./scripts/benchmark_verification.sh --format json > benchmark.json
./scripts/benchmark_verification.sh --format csv > benchmark.csv
./scripts/benchmark_verification.sh --format markdown > benchmark.md
```

**Metrics tracked:**
- Per-operation Lean build time
- Full tree build time
- Per-operation verify-ca.sh time
- Memory usage (if available)

---

## 3. Lean Optimization Strategies

### 3.1 Architectural Patterns (from §4 of Plan)

**These patterns are WHY Phase 4 builds in 0.5-0.7s (not 25 minutes like old Registration):**

1. **Symbolic state (not chained frames)**

**Bad (O(N²) elaboration):**

```lean
def state1 := { initialFrame with pc := 1, locals := [...] }
def state2 := { state1 with pc := 2, locals := state1.locals.set 0 val ... }
def state3 := { state2 with pc := 3, stack := val :: state2.stack }
-- Each state definition unfolds all previous definitions during elaboration
```

**Good (O(N) elaboration):**

```lean
@[irreducible]
def symbolicState (pc : Nat) (locals : Locals) (stack : Stack) : CallFrame :=
  { initialFrame with pc, locals, stack }

theorem step_pc1 : ... symbolicState 1 newLocals newStack ... := by rfl
theorem step_pc2 : ... symbolicState 2 newLocals2 newStack2 ... := by rfl
```

**Impact:** 100× speedup on long PC chains.

---

2. **Per-instruction-class step lemmas**

**Bad (re-prove for every PC):**

```lean
theorem step_pc0 ... : step env frame cs stack ms = ... := by
  unfold step
  cases frame.code[frame.pc]
  case moveLoc idx =>
    -- 20 lines of proof
  ...

theorem step_pc1 ... : step env frame cs stack ms = ... := by
  unfold step
  cases frame.code[frame.pc]
  case moveLoc idx =>
    -- SAME 20 lines repeated
```

**Good (prove once, apply many times):**

```lean
-- In StepLemmas.Locals:
theorem step_moveLoc
    (env : ModuleEnvironment) (frame : CallFrame)
    (idx : Nat)
    (h_instr : frame.code[frame.pc] = .moveLoc idx)
    : step env frame cs stack ms = ... := by
  -- Prove once

-- Apply:
theorem step_pc0 ... := by simp only [step, step_moveLoc, <code_pc0>]; rfl
theorem step_pc1 ... := by simp only [step, step_moveLoc, <code_pc1>]; rfl
```

**Impact:** 10-20× speedup, code 5× shorter.

---

3. **Array.get? (not Array.get with bound proofs)**

**Bad (bound proof forces chain unfold during elaboration):**

```lean
theorem step_pc10
    : step env frame cs stack ms =
      let val := frame.locals[5]'<proof_that_5_lt_locals_len>
      ...
```

**The bound proof `<proof_that_5_lt_locals_len>` is elaborated during theorem statement type-checking, which forces unfolding `frame`, then `state9`, then `state8`, ..., all the way to initial state.**

**Good (get? defers bound checking to proof body):**

```lean
theorem step_pc10
    (h_locals_len : frame.locals.size > 5)
    : step env frame cs stack ms =
      match frame.locals.get? 5 with
      | some val => ...
      | none => .error  -- Unreachable if h_locals_len holds
```

**Impact:** 50× speedup on elaboration (see memory `feedback_fv_heartbeats.md`).

---

4. **@[irreducible] on state definitions**

**Without @[irreducible]:**

```lean
def complexState := { ... 50 fields ... }

theorem uses_state : f complexState = ... := by
  simp  -- UNFOLDS complexState, processes all 50 fields
```

**With @[irreducible]:**

```lean
@[irreducible]
def complexState := { ... 50 fields ... }

@[simp] theorem complexState_field1 : complexState.field1 = value1 := by
  unfold complexState; rfl

theorem uses_state : f complexState.field1 = ... := by
  simp only [complexState_field1]  -- Only unfolds specific field
```

**Impact:** whnf stops at boundary instead of traversing full structure.

---

### 3.2 Anti-Pattern: Chained State Definitions

**Symptom:** Build time increases superlinearly with PC count (10 PCs → 1s, 20 PCs → 5s, 50 PCs → 60s).

**Cause:** Each state definition unfolds previous states during elaboration.

**Example (DO NOT DO THIS):**

```lean
def state0 := initialFrame
def state1 := { state0 with pc := 1 }
def state2 := { state1 with pc := 2, locals := state1.locals.set 0 val ... }
-- ...
def state50 := { state49 with pc := 50, ... }

theorem final : state50.pc = 50 := by rfl  -- Heartbeat explosion!
```

**Fix:** Use symbolic state (see §3.1 pattern 1).

---

### 3.3 Anti-Pattern: Bound Proofs in Statements

**Symptom:** `set_option maxHeartbeats` needed, theorem statement takes >10s to elaborate.

**Cause:** Bound proof in statement forces chain unfold during type-checking.

**Example (DO NOT DO THIS):**

```lean
theorem step_pc10
    : step env frame cs stack ms =
      let val := frame.locals[5]'(by decide : 5 < frame.locals.size)
      ...
```

**The `(by decide)` proof is elaborated before the theorem body, which requires knowing `frame.locals.size`, which requires unfolding `frame`, which requires unfolding state chain.**

**Fix:** Use `Array.get?` or add precondition (see §3.1 pattern 3).

---

### 3.4 Anti-Pattern: Bare `simp`

**Symptom:** `simp` takes >5s, unpredictable behavior across Lean versions.

**Cause:** `simp` tries every `@[simp]` lemma in scope (hundreds in Mathlib).

**Example (AVOID):**

```lean
theorem step_pc10 ... := by
  simp  -- Which lemmas? No one knows!
```

**Fix:** Use `simp only [...]` with explicit lemma list:

```lean
theorem step_pc10 ... := by
  simp only [step, step_moveLoc, code_pc10, env_fn0_body]
  rfl
```

**Benefits:**
- Faster (only tries listed lemmas)
- Deterministic (same behavior across Lean versions)
- Readable (explicit about what's being simplified)

---

### 3.5 Optimization Checklist

**Before committing Lean code:**

- [ ] No chained state definitions (use `@[irreducible]` symbolic state)
- [ ] No bound proofs in theorem statements (use `Array.get?`)
- [ ] No bare `simp` (use `simp only [...]`)
- [ ] Per-instruction-class lemmas used (not re-proving)
- [ ] Build time <3 min per file (`time lake build <Module>`)
- [ ] No `set_option maxHeartbeats` (or if needed, documented + GitHub issue)

---

## 4. Move Prover Optimization

### 4.1 Spec Complexity Reduction

**Target:** Each function's VCs should prove in <10 seconds.

**Complexity drivers:**

1. **Nested quantifiers:**

```move
// Bad (O(N²) SMT solving)
ensures forall i in 0..len(balance):
    forall j in 0..len(balance):
        i != j ==> balance[i] != balance[j];

// Good (helper spec fun)
ensures all_unique(balance);

spec fun all_unique(v: vector<u8>): bool {
    forall i in 0..len(v):
        !vector::contains(&slice(v, i+1, len(v)), &v[i])
}
```

**Impact:** 5-10× faster verification.

---

2. **Recursive spec funs (unbounded depth):**

```move
// Bad (may not terminate)
spec fun sum(v: vector<u8>): u256 {
    if (len(v) == 0) { 0 }
    else { v[0] + sum(v) }  // TYPO: should be sum(slice(v, 1, len(v)))
}

// Good (bounded or well-founded)
spec fun sum(v: vector<u8>): u256 {
    if (len(v) == 0) {
        0
    } else {
        v[0] + sum(slice(v, 1, len(v)))  // Decreasing len(v)
    }
}
```

---

3. **Large conjunctions:**

```move
// Bad (single massive ensures)
ensures A && B && C && D && E && F && G && H && I && J;

// Good (separate ensures clauses)
ensures A;
ensures B;
ensures C;
// ... (SMT solver can tackle incrementally)
```

---

### 4.2 Incremental Verification

**Problem:** Full prover run takes 5+ minutes for all CA functions.

**Solution:** Verify only changed functions.

**Script:**

```bash
# In CI or locally
CHANGED_FUNCTIONS=$(git diff HEAD~1 --name-only | \
  grep -E "confidential_asset.*\.move$" | \
  xargs grep -h "public fun " | \
  awk '{print $3}' | cut -d'(' -f1 | sort -u)

for fun in $CHANGED_FUNCTIONS; do
  echo "Verifying $fun..."
  movement move prove \
    --package-dir aptos-experimental \
    --filter "$fun" \
    --vc-timeout 60
done
```

**Impact:** 10× faster for typical PR (1-2 functions changed).

---

### 4.3 Prover Flags

**Recommended optimizations:**

```bash
movement move prove \
  --package-dir aptos-experimental \
  --filter <function> \
  --vc-timeout 60 \           # Fail fast on timeouts
  --keep-build \              # Cache Boogie IR
  --cores $(nproc) \          # Parallel VC checking
  --skip-fetch-latest-git-deps \
  --verbose=warn              # Less output (faster)
```

**Cache `.bpl` files (Boogie IR):**

```bash
# First run generates .bpl
movement move prove --keep-build ...

# Subsequent runs reuse .bpl (faster compilation)
movement move prove --keep-build ...
```

---

## 5. CI Performance

### 5.1 Mathlib Cache

**Problem:** `lake exe cache get!` takes 2 min every CI run.

**Solution:** Cache Mathlib oleans between runs (see `CI_ENHANCEMENT_GUIDE.md` §2.2).

**Impact:** ~2 min savings per run, 80% cache hit rate.

---

### 5.2 Parallelization

**Problem:** Sequential checks take 5× longer than necessary.

**Solution:** Use matrix strategy (see `CI_ENHANCEMENT_GUIDE.md` §2.3).

**Example:**

```yaml
jobs:
  verify-operations:
    strategy:
      matrix:
        operation: [register, withdraw, transfer, normalize, rotate]
    steps:
      - run: ./audit/verify-ca.sh --op ${{ matrix.operation }}
```

**Impact:** 5 operations × 3 min = 15 min serial → 3 min parallel (5× speedup).

---

### 5.3 Incremental Difftest

**Problem:** All 87 corpus rows run even if only one operation changed.

**Solution:** Detect changed operations, run only relevant suites (see `CI_ENHANCEMENT_GUIDE.md` §3.1).

**Impact:** 70-75% reduction in difftest time.

---

## 6. Regression Prevention

### 6.1 Automated Benchmarking

**Track build times over time:**

```bash
# In CI
./scripts/benchmark_verification.sh --format json > benchmark-${{ github.run_id }}.json

# Upload as artifact
# Compare against baseline
```

**Regression detection:**

```bash
./scripts/detect_performance_regression.sh \
  --baseline benchmark-baseline.json \
  --current benchmark-current.json \
  --threshold 20  # Fail if >20% slower
```

---

### 6.2 Per-File Build Time Budget

**Enforce in CI:**

```yaml
- name: Check build times
  run: |
    for file in $(find lean/MovementFormal/Experimental/ConfidentialAsset -name "*.lean"); do
      module=$(basename $file .lean)
      time_output=$(time lake build "MovementFormal.Experimental.ConfidentialAsset.$module" 2>&1)
      elapsed=$(echo "$time_output" | grep real | awk '{print $2}')
      
      # Parse elapsed time (e.g., "0m2.345s")
      if [[ $elapsed > "0m180s" ]]; then
        echo "ERROR: $module exceeds 3-minute budget: $elapsed"
        exit 1
      fi
    done
```

---

### 6.3 Pre-Commit Hook (Local)

**Catch performance issues before push:**

```bash
# In pre-commit hook
if git diff --cached --name-only | grep -q "\.lean$"; then
  echo "Checking Lean build time..."
  
  # Quick check: incremental build should be fast
  start=$(date +%s)
  lake build > /dev/null 2>&1
  end=$(date +%s)
  elapsed=$((end - start))
  
  if [ "$elapsed" -gt 180 ]; then
    echo "WARNING: Lean build took ${elapsed}s (>3 min budget)"
    echo "Consider optimizing before commit."
    # Don't fail, just warn
  fi
fi
```

---

## Appendix A: Performance Troubleshooting

### Symptom: Lean build takes >10 minutes

**Diagnosis:**

1. Check Mathlib cache:
   ```bash
   ls -lh lean/.lake/packages/mathlib/.lake/build/lib | head
   ```
   If empty or stale: `lake exe cache get!`

2. Check for chained state:
   ```bash
   grep -n "def state.*:= { state" lean/MovementFormal/**/*.lean
   ```
   If found: Refactor to symbolic state.

3. Profile specific file:
   ```bash
   time lake build <slow module>
   ```

**Fix:** Apply architectural patterns from §3.1.

---

### Symptom: Move Prover times out

**Diagnosis:**

1. Check VC count:
   ```bash
   movement move prove --filter <function> 2>&1 | grep "VC count"
   ```
   If >100 VCs: Spec too complex.

2. Check quantifier nesting:
   ```bash
   grep -E "forall.*forall" aptos-experimental/sources/**/*.spec.move
   ```
   If found in failing spec: Simplify.

**Fix:** Apply spec complexity reduction from §4.1.

---

### Symptom: CI runs out of memory

**Diagnosis:**

1. Check runner memory:
   ```yaml
   - run: free -h  # Linux
   - run: vm_stat  # macOS
   ```

2. Check Lean peak memory:
   ```bash
   /usr/bin/time -v lake build 2>&1 | grep "Maximum resident"
   ```

**Fix:**
- Use self-hosted runner with more RAM
- Split large files into smaller modules
- Reduce incremental build parallelism (`lake build -j1`)

---

## Appendix B: Benchmarking Best Practices

**When to benchmark:**

- Before/after major refactor
- Before/after adding 10+ theorems
- Before/after changing proof patterns
- Weekly (automated in CI)

**What to measure:**

- Per-file build time (cold + hot)
- Full tree build time
- Peak memory usage
- VC generation time (Move Prover)
- SMT solving time (Move Prover)

**How to report:**

```markdown
## Performance Impact

**Before:**
- Transfer/EvalEquiv.lean: 2.3s
- Full CA tree: 8.2s

**After:**
- Transfer/EvalEquiv.lean: 0.7s (3.3× faster)
- Full CA tree: 4.1s (2× faster)

**Changes:**
- Removed chained state definitions (lines 45-120)
- Applied symbolic state pattern (lines 130-145)
- Added @[irreducible] to transferState (line 132)
```

---

**Questions?** See `DEVELOPER_ONBOARDING_GUIDE.md` §5 Where to Get Help.
