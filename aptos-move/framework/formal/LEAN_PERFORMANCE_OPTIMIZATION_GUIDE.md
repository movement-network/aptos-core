# Lean Performance Optimization Guide

**Audience:** Verification engineers working on Lean proofs  
**Prerequisites:** Basic Lean 4 knowledge, understanding of the step-lemma architecture  
**Related:** `PROOF_AUTOMATION_FRAMEWORK_GUIDE.md`, `LEAN_TACTICS_COOKBOOK.md`, `CI_CD_PIPELINE_COMPREHENSIVE_GUIDE.md`

## Purpose

This guide provides systematic techniques for diagnosing and fixing Lean performance issues in the CA verification codebase. The unified verification plan §4 sets a **≤3 minute per-file build budget**. This guide shows how to stay within that budget.

## Table of Contents

1. [Performance Budgets](#performance-budgets)
2. [Profiling Tools](#profiling-tools)
3. [Common Performance Anti-Patterns](#common-performance-anti-patterns)
4. [Optimization Techniques](#optimization-techniques)
5. [Case Studies](#case-studies)
6. [Preventive Measures](#preventive-measures)
7. [Emergency Procedures](#emergency-procedures)

---

## Performance Budgets

### Per-File Budgets

From the unified verification plan §4:

| File | Budget (cold) | Current | Status |
|------|---------------|---------|--------|
| `Registration/EvalEquivRebuild.lean` | 3 min | 3.0s | ✅ At budget |
| `Withdrawal/EvalEquiv.lean` | 3 min | 0.5s | ✅ Well under |
| `Transfer/EvalEquiv.lean` | 3 min | 0.7s | ✅ Well under |
| `Normalization/EvalEquiv.lean` | 3 min | 0.5s | ✅ Well under |
| `Rotation/EvalEquiv.lean` | 3 min | 0.5s | ✅ Well under |
| Full CA tree | 10 min | 1.6s (warm cache) | ✅ Well under |

**Why these budgets:**
- Developers must get feedback in <5 min to iterate effectively
- CI must complete verification in <15 min to keep PR pipeline fast
- Any file exceeding 3 min indicates an architecture problem, not just "slow proof"

### Build Types

**Cold build:** No `.lake` cache, no mathlib cache  
**Warm build:** Mathlib cached, dependencies built  
**Incremental build:** Single file changed, rest cached

Budgets apply to **cold builds** (worst case, e.g., CI on fresh runner).

### Alert Thresholds

| Threshold | Action |
|-----------|--------|
| >50% of budget | Investigate (not blocking) |
| >75% of budget | Fix before merge |
| >100% of budget | Blocks merge, must fix |

---

## Profiling Tools

### 1. `lake build --profile`

**What it shows:** Time spent per file, per tactic, per elaboration.

**Usage:**
```bash
cd aptos-move/framework/formal/lean
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild --profile
```

**Output example:**
```
[  0/  1] Building MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
  elaboration: 2.5s
  typeclass: 0.3s
  simp: 0.1s
  compilation: 0.1s
  total: 3.0s
```

**What to look for:**
- `elaboration` >50% of total → expensive theorem statement elaboration (see §3.1)
- `simp` >20% of total → inefficient simp usage (see §3.2)
- `typeclass` >30% of total → typeclass inference loop (see §3.3)

### 2. `set_option profiler true`

**What it shows:** Per-theorem timing and heartbeat usage.

**Usage:**
Add to top of file:
```lean
set_option profiler true

theorem foo : ... := by
  ...
```

**Output** (in Info View):
```
elaboration of foo took 1.2s
  elaboration: 0.8s
  typeclass: 0.2s
  unification: 0.1s
  simp: 0.1s
```

**What to look for:**
- Any single theorem >10s → investigate that theorem specifically
- Many theorems 1-5s → systemic issue (architecture, not individual proofs)

### 3. `set_option trace.profiler true`

**What it shows:** Detailed trace of elaboration steps.

**Warning:** Produces 10,000+ lines of output. Use only for targeted debugging.

**Usage:**
```lean
set_option trace.profiler true

-- Wrap only the slow theorem, not whole file
theorem slow_theorem : ... := by
  ...
```

**Output:**
```
[profiler] 'elaboration' took 800ms
  [profiler] 'typecheck term' took 300ms
  [profiler] 'unify locals[0] with ...' took 200ms
  [profiler] 'simp' took 100ms
    [profiler] 'simp lemma foo_simp' took 50ms
    [profiler] 'simp lemma bar_simp' took 50ms
  ...
```

**How to interpret:**
- Nested profiler entries show call stack
- Time attributed to parent includes all children
- Look for unexpectedly slow leaves (e.g., single `unify` taking 200ms)

### 4. `#print axioms` Timing Trick

**What it shows:** Whether a definition is compiled (fast) or elaborated on-demand (slow).

**Usage:**
```bash
time lean --run -c 'import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild; #print axioms registration_eval_equiv_functional_sim' > /dev/null
```

If this takes >5s, the import is slow (file performance issue).  
If <1s, the file itself is fine; slowness is in dependents.

### 5. Differential Profiling

**What it shows:** Which commit introduced a regression.

**Usage:**
```bash
# Baseline (known-good commit)
git checkout v1.0.0
time lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
# Record time: 1.5s

# Current (suspected regression)
git checkout main
lake clean  # Force rebuild
time lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
# Record time: 4.5s

# Regression: 4.5s - 1.5s = +3.0s
```

Then bisect:
```bash
git bisect start main v1.0.0
git bisect run sh -c 'lake clean && time lake build <Module> 2>&1 | grep "real.*0m[0-2]\\."'
# Finds first commit where build time >2s
```

---

## Common Performance Anti-Patterns

### 1. Expensive Elaboration in Theorem Statements

**Symptom:** File takes 30s+ to elaborate, but `sorry` bodies.

**Cause:** Bound proofs in theorem statement force chain-unfold during type-elaboration.

**Example (BAD — 600× slower):**
```lean
theorem step_0_to_1 : 
    step env (state 0) = .ok (state 1).withPc 1 := by
  simp [step, state]
  -- Even with sorry, this takes 30s because elaborating the statement
  -- unfolds `(state 0).locals[0]'<bound_proof>` which triggers chain-unfold
  sorry
```

**Why slow:** The bound proof `<bound_proof>` in `.locals[0]'<bound_proof>` forces Lean to prove `0 < (state 0).locals.size` during **statement elaboration**, before the tactic block runs. With chained state definitions (`state n = { state (n-1) with ... }`), this unfolds the entire chain.

**Example (GOOD — 600× faster):**
```lean
@[simp]
theorem state_locals_0 : (state 0).locals[0]? = some (.u8 chainId) := by
  unfold state; rfl

theorem step_0_to_1 :
    step env (state 0) = .ok (state 1).withPc 1 := by
  simp only [step, state, state_locals_0]
  -- Fast: no bound proof in statement, `?` version delays proof to tactic
```

**Fix:** Use `Array.get?` (returns `Option`) in theorem statements, not `Array.get'` (needs bound proof).

**Memory aid (from `feedback_fv_heartbeats.md`):**  
> "Lifting heq-rfl bridge lemmas alone doesn't help; bound-proof elaboration in theorem statement is the real cost."

### 2. Bare `simp` Instead of `simp only`

**Symptom:** Tactic takes 5-10s per invocation, scales O(N) with simp set size.

**Cause:** `simp` searches **all** `@[simp]` lemmas in scope (1000+). `simp only` searches only specified lemmas.

**Example (BAD):**
```lean
theorem step_0_to_1 : ... := by
  simp  -- Searches 1000+ lemmas, takes 5s
  rfl
```

**Example (GOOD):**
```lean
theorem step_0_to_1 : ... := by
  simp only [step, state_pc, state_code, code]  -- Searches 4 lemmas, takes 0.1s
  rfl
```

**Speedup:** 50-100× for typical proof.

**How to find culprits:**
```bash
grep -n "by simp$" *.lean
# Flag all bare `simp` (ends with `simp`, nothing after)
```

**How to fix systematically:**
1. Enable `set_option trace.simp true` on slow theorem
2. Read output, collect used lemmas:
   ```
   [simp] step: ... → ...
   [simp] state_pc: ... → ...
   ```
3. Replace `simp` with `simp only [step, state_pc, ...]`

### 3. Missing `@[irreducible]`

**Symptom:** Lean unfolds definitions during proof, causing exponential blowup.

**Cause:** By default, `def` is reducible — Lean unfolds it whenever type-checking needs to unify.

**Example (BAD):**
```lean
def state (pc : Nat) : Frame :=
  { code := verifyProofCode,
    pc := pc,
    locals := initialLocals,
    ... }

theorem step_0 : step env (state 0) = ... := by
  simp [step]  -- Unfolds `state 0` structurally, expensive
```

**Example (GOOD):**
```lean
@[irreducible]
def state (pc : Nat) : Frame := ...

@[simp]
theorem state_pc : (state pc).pc = pc := by unfold state; rfl

theorem step_0 : step env (state 0) = ... := by
  simp only [step, state_pc]  -- Uses projection, never unfolds `state` body
```

**Speedup:** 100-600× for large state definitions.

**When to use `@[irreducible]`:**
- Any large record definition used in many theorems
- Especially: symbolic state definitions (`registrationState`, `transferState`, etc.)

**When NOT to use:**
- Tiny definitions (1-2 fields)
- Definitions you actually want to unfold structurally

### 4. Redundant Typeclass Inference

**Symptom:** `typeclass` takes >30% of profile time.

**Cause:** Lean re-infers the same typeclass instance at every use site.

**Example (BAD):**
```lean
theorem foo : (x : Nat) → x + 0 = x := by
  intro x
  ring  -- Infers `AddMonoid Nat`, `Semiring Nat`, etc.

theorem bar : (x : Nat) → 0 + x = x := by
  intro x
  ring  -- Re-infers same instances
```

**Example (GOOD):**
```lean
variable [AddMonoid Nat]  -- Declare once at top

theorem foo : (x : Nat) → x + 0 = x := by
  intro x
  ring  -- Uses variable, no inference

theorem bar : (x : Nat) → 0 + x = x := by
  intro x
  ring  -- Uses variable, no inference
```

**When it matters:** Files with 100+ theorems using same typeclasses.

**How to detect:**
```bash
set_option trace.Meta.synthInstance true
# If you see the same instance synthesized 100 times, hoist to variable
```

### 5. Deep Proof Terms

**Symptom:** Lean crashes with "deep recursion" or "stack overflow".

**Cause:** Proof term nested 1000+ levels deep (e.g., `apply` 1000 times).

**Example (BAD):**
```lean
theorem chain_0_to_1000 : run env (state 0) 1000 = ... := by
  apply run_succ_ok_of_step
  apply run_succ_ok_of_step
  -- ... 1000 times ...
  rfl
```

Proof term: `run_succ_ok_of_step (run_succ_ok_of_step (... nested 1000 deep ...))`.

**Example (GOOD):**
```lean
theorem chain_0_to_10 : run env (state 0) 10 = ... := by
  pc_chain [step_0, step_1, ..., step_9]  -- Custom tactic, flat list

theorem chain_10_to_20 : run env (state 10) 10 = ... := by
  pc_chain [step_10, step_11, ..., step_19]

theorem chain_0_to_1000 : run env (state 0) 1000 = ... := by
  rw [chain_0_to_10, chain_10_to_20, ...]  -- Compose flat chains
```

Proof term: `Eq.trans (Eq.trans ... (flat))`.

**Speedup:** Avoids crash, enables composability.

**When to use:** PC-chaining proofs (200+ steps), composition theorems.

### 6. Inefficient `omega`

**Symptom:** `omega` tactic takes 10+ seconds.

**Cause:** Too many variables in scope, or non-linear arithmetic.

**Example (BAD):**
```lean
theorem foo (a b c d e f g h i j k : Nat) : a + b + c + d + e = ... := by
  omega  -- Tries all combinations of 11 variables, slow
```

**Example (GOOD):**
```lean
theorem foo (a b c d e f g h i j k : Nat) : a + b + c + d + e = ... := by
  have h1 : a + b = ... := by omega
  have h2 : c + d = ... := by omega
  rw [h1, h2]
  omega  -- Smaller problem, fast
```

**Speedup:** 10-100× for complex arithmetic.

**When it matters:** Proofs with 5+ Nat variables.

---

## Optimization Techniques

### Technique 1: Use `@[irreducible]` + Projection Lemmas

**When:** Large record definitions (10+ fields) used in many theorems.

**Steps:**

1. **Mark definition `@[irreducible]`:**
   ```lean
   @[irreducible]
   def registrationState (pc : Nat) (proofRef : Address) (locals : Locals) : Frame :=
     { code := verifyRegistrationProofCode,
       pc := pc,
       locals := locals,
       operandStack := [],
       ... }
   ```

2. **Write projection lemmas for each field:**
   ```lean
   @[simp]
   theorem registrationState_pc : (registrationState pc ref locals).pc = pc := by
     unfold registrationState; rfl

   @[simp]
   theorem registrationState_locals : (registrationState pc ref locals).locals = locals := by
     unfold registrationState; rfl

   -- ... one per field ...
   ```

3. **Use `simp only [state_pc, state_locals]` instead of `unfold state`:**
   ```lean
   theorem step_0 : step env (registrationState 0 ref locals) = ... := by
     simp only [step, registrationState_pc, registrationState_code]
     -- Never unfolds `registrationState` body
     rfl
   ```

**Speedup:** 100-600× for Registration (see memory `feedback_fv_heartbeats.md`).

**Example:** `Registration/EvalEquivRebuild.lean` lines 50-150 (projection suite).

### Technique 2: Replace `simp` with `simp only [...]`

**When:** Any `by simp` that takes >1s.

**Steps:**

1. **Profile to identify slow `simp`:**
   ```bash
   set_option profiler true
   theorem foo : ... := by simp; rfl
   -- Output: `simp` took 5.2s
   ```

2. **Enable trace to see which lemmas used:**
   ```lean
   set_option trace.simp true
   theorem foo : ... := by simp; rfl
   ```

   Output (Info View):
   ```
   [simp] step: ... → ...
   [simp] state_pc: ... → ...
   [simp] state_code: ... → ...
   [simp] code: ... → ...
   ```

3. **Replace with `simp only`:**
   ```lean
   theorem foo : ... := by
     simp only [step, state_pc, state_code, code]
     rfl
   ```

4. **Verify speedup:**
   ```bash
   set_option profiler true
   theorem foo : ... := by simp only [step, state_pc, state_code, code]; rfl
   -- Output: `simp only` took 0.1s (50× faster)
   ```

**Speedup:** 10-100×.

**Caveat:** Must maintain lemma list when definitions change. Worth it for hot-path proofs.

### Technique 3: Use Step-Lemma Library

**When:** Per-PC step proofs (e.g., `step_0`, `step_1`, ..., `step_N`).

**Steps:**

1. **Import step-lemma library:**
   ```lean
   import MovementFormal.MoveModel.StepLemmas.Basic
   import MovementFormal.MoveModel.StepLemmas.Locals
   import MovementFormal.MoveModel.StepLemmas.Calls
   ```

2. **Use library lemmas instead of manual `simp`:**
   ```lean
   -- BAD (manual, slow):
   theorem step_0 : step env (state 0) [] [] ms = .ok (state 1) [] [...] ms := by
     simp [step, state, state_pc, state_code, code]
     split <;> simp
     rfl

   -- GOOD (library, fast):
   theorem step_0 : step env (state 0) [] [] ms = .ok (state 1) [] [...] ms := by
     apply step_moveLoc  -- Library lemma for MoveLoc instruction
     simp only [state_code, state_pc, code, state_locals]
   ```

3. **For chaining, use `run_succ_ok_of_step`:**
   ```lean
   theorem chain_0_to_5 : run env (state 0) 5 = ... := by
     rw [run_succ_ok_of_step (fuel := 4) _ _ _ _ _ step_0]
     rw [run_succ_ok_of_step (fuel := 3) _ _ _ _ _ step_1]
     rw [run_succ_ok_of_step (fuel := 2) _ _ _ _ _ step_2]
     rw [run_succ_ok_of_step (fuel := 1) _ _ _ _ _ step_3]
     rw [run_succ_ok_of_step (fuel := 0) _ _ _ _ _ step_4]
     rfl
   ```

**Speedup:** 5-20× per step (removes boilerplate, precompiled library).

**Example:** All Phase 4 operations (`Withdrawal/EvalEquiv.lean`, `Transfer/EvalEquiv.lean`, etc.) use this pattern.

### Technique 4: Custom Tactics for Repetitive Patterns

**When:** Same proof pattern repeated 50+ times.

**Steps:**

1. **Identify pattern:**
   ```lean
   theorem step_0 : ... := by simp only [step, state_pc, state_code, code]; apply step_moveLoc; rfl
   theorem step_1 : ... := by simp only [step, state_pc, state_code, code]; apply step_moveLoc; rfl
   -- ... 50 more ...
   ```

2. **Extract to custom tactic:**
   ```lean
   syntax "step_auto" : tactic
   macro_rules
     | `(tactic| step_auto) => `(tactic|
         simp only [step, state_pc, state_code, code]
         first | apply step_moveLoc | apply step_stLoc | apply step_copyLoc
         try rfl)
   ```

3. **Use custom tactic:**
   ```lean
   theorem step_0 : ... := by step_auto
   theorem step_1 : ... := by step_auto
   -- ... 50 more, each 1 line instead of 3
   ```

**Speedup:** 2-5× compilation (smaller proof terms), 3-10× proof LOC.

**Example:** See `PROOF_AUTOMATION_FRAMEWORK_GUIDE.md` §4 "Custom Tactics".

### Technique 5: Batch Elaboration with `in` Sections

**When:** Many theorems use same local context (e.g., same `variable` declarations).

**Steps:**

1. **Group related theorems in `section ... end`:**
   ```lean
   section Step0To10
   variable {env : ModuleEnv} {ms : MachineState}

   theorem step_0 : ... := by ...
   theorem step_1 : ... := by ...
   -- ...
   theorem step_10 : ... := by ...
   end Step0To10
   ```

2. **Lean elaborates `variable` once, amortizes across all theorems in section.**

**Speedup:** 10-20% for files with 100+ theorems.

**When NOT to use:** If theorems need different contexts (e.g., different `env`).

### Technique 6: Avoid Re-proving Same Subgoals

**When:** Same subgoal appears in 10+ theorems.

**Steps:**

1. **Extract subgoal to helper lemma:**
   ```lean
   -- BAD (re-prove 10 times):
   theorem step_0 : ... := by
     have h : fuel ≥ 1 := by omega
     ...

   theorem step_1 : ... := by
     have h : fuel ≥ 1 := by omega
     ...
   -- ... 10 more ...

   -- GOOD (prove once):
   theorem fuel_geq_1 (fuel : Nat) (h : fuel ≥ 1) : fuel ≥ 1 := h

   theorem step_0 : ... := by
     have h := fuel_geq_1 fuel hfuel
     ...
   ```

2. **Or, push to assumption:**
   ```lean
   theorem step_chain (hfuel : fuel ≥ 10) : ... := by
     -- All steps get `hfuel` for free, no re-proving
     ...
   ```

**Speedup:** 5-10× for arithmetic-heavy proofs.

---

## Case Studies

### Case Study 1: Registration Rebuild (Part3 → EvalEquivRebuild)

**Before (Part3.lean):**
- Build time: 25.6M heartbeats (30+ min with `set_option maxHeartbeats 25600000`)
- Architecture: Chained state definitions (`state 1 = { state 0 with ... }`)
- Tactic: Bare `simp`, bound proofs in statements

**After (EvalEquivRebuild.lean):**
- Build time: 3.0s (600× faster)
- Architecture: `@[irreducible]` symbolic state, `Array.get?` in statements
- Tactic: `simp only [state_pc, state_locals]`, step-lemma library

**Key changes:**
1. `@[irreducible] def registrationState ...` → 100× speedup
2. `.locals[0]'<proof>` → `.locals[0]?` → 6× speedup
3. `simp` → `simp only [...]` → 50× speedup

**Compound effect:** 100 × 6 × 50 = 30,000× theoretical, 600× measured (other overheads).

**Lesson:** Architecture matters more than tactic cleverness.

### Case Study 2: Transfer EvalEquiv (Greenfield, Fast by Design)

**Goal:** Prove `verify_transfer_proof` bytecode ≡ functional sim in <3 min.

**Approach:**
- Copy architecture from Registration rebuild (Phase 1)
- Use `@[irreducible]` from day 1
- Use step-lemma library for all 24 PCs
- Use `simp only` everywhere

**Result:**
- First build: 0.7s (well under 3 min budget)
- 24 per-PC theorems + 3 error paths
- 27 theorems, ~400 lines, 0.7s

**Lesson:** Applying learned optimizations from day 1 keeps builds fast. No need to optimize later.

### Case Study 3: Gradual Regression (Hypothetical)

**Scenario:** Build time grows 1.5s → 3.0s over 20 PRs, no single PR flagged.

**Diagnosis:**
1. **Bisect to find inflection point:**
   ```bash
   git bisect start HEAD v1.0.0
   git bisect run sh -c 'lake clean && time lake build <Module> 2>&1 | grep "real.*0m[0-2]\\."'
   ```
   Finds commit `abc123` (first to exceed 2s).

2. **Analyze that PR:**
   ```bash
   git show abc123
   ```
   Found: Added 10 new `@[simp]` lemmas (increased simp set size).

3. **Fix:** Replace `simp` with `simp only` in hot-path theorems (those using new lemmas).

**Result:** Back to 1.5s.

**Lesson:** Even "innocent" changes (new simp lemmas) can cause gradual regression. Monitor trends, not just single-PR changes.

---

## Preventive Measures

### At Commit Time

**Pre-commit checklist:**
1. **Run local benchmark:**
   ```bash
   cd aptos-move/framework/formal
   ./scripts/benchmark_verification.sh --quick
   # Check output: any operation >3s?
   ```

2. **Check for bare `simp`:**
   ```bash
   git diff --cached | grep -E "^\+.*by simp$"
   # If found, convert to `simp only`
   ```

3. **Check for missing `@[irreducible]`:**
   ```bash
   git diff --cached | grep -E "^\+\s*def \w+State"
   # If found, ensure `@[irreducible]` on line above
   ```

### At PR Time

**PR template checklist:**
- [ ] `lake build <Module>` completes in <3 min locally
- [ ] No bare `simp` in hot-path proofs (50+ uses)
- [ ] New state definitions marked `@[irreducible]`
- [ ] Performance benchmark artifact shows <10% regression

### At Code Review Time

**Reviewer checklist:**
- Check CI performance benchmark result (comment on PR)
- Flag any theorem >10s in profile
- Flag any new `set_option maxHeartbeats` (sign of architecture problem, not fixable with higher limit)

**Red flags:**
- `set_option maxHeartbeats 10000000` → Architecture wrong, don't merge
- Build time >75% of budget → Request optimization before merge
- Many new `sorry` placeholders → Incomplete work, request completion

### At CI Time

**Automated checks (see `CI_CD_PIPELINE_COMPREHENSIVE_GUIDE.md`):**
- `performance-benchmarks` job compares against baseline
- Alert if any operation >50% of budget
- Block if any operation >100% of budget

---

## Emergency Procedures

### Build Timeout in CI (>15 min)

**Situation:** CI job hits timeout, blocks PR.

**Immediate fix (short-term):**
1. **Bump timeout:**
   ```yaml
   # In .github/workflows/ca-verification-suite.yaml
   lean-verification:
     timeout-minutes: 30  # Was 15
   ```

2. **Merge PR with timeline to fix root cause (1 week).**

**Root cause fix (long-term):**
1. **Profile slow file:**
   ```bash
   lake build --profile MovementFormal.Experimental.ConfidentialAsset.<Module>
   ```

2. **Apply optimization techniques from §4:**
   - Replace `simp` → `simp only`
   - Add `@[irreducible]` to state definitions
   - Use step-lemma library

3. **Revert timeout bump once fixed.**

### Stack Overflow / Deep Recursion

**Situation:** Lean crashes with "deep recursion" error.

**Immediate fix:**
1. **Identify culprit theorem:**
   Check error message for theorem name.

2. **Replace deep `apply` chain with composition:**
   ```lean
   -- BAD (deep):
   theorem chain : ... := by
     apply step_0
     apply step_1
     -- ... 500 more
     rfl

   -- GOOD (flat):
   theorem chain : ... := by
     rw [step_0, step_1, ..., step_500]
     rfl
   ```

### Mathlib Cache Issues

**Situation:** `lake exe cache get` fails, build takes hours.

**Immediate fix:**
1. **Check mathlib version compatibility:**
   ```bash
   cat lean-toolchain  # Should be v4.24.0
   grep mathlib4 lakefile.lean
   # Version should have cache available
   ```

2. **If incompatible, pin to known-good version:**
   ```lean
   -- In lakefile.lean
   require mathlib from git
     "https://github.com/leanprover-community/mathlib4.git" @ "v4.24.0-rc1"
   ```

3. **Clear cache and retry:**
   ```bash
   rm -rf .lake/build/lib
   lake exe cache get
   ```

---

## Related Guides

- [PROOF_AUTOMATION_FRAMEWORK_GUIDE.md](PROOF_AUTOMATION_FRAMEWORK_GUIDE.md) — Custom tactics, code generation
- [LEAN_TACTICS_COOKBOOK.md](LEAN_TACTICS_COOKBOOK.md) — Practical tactic recipes
- [BYTECODE_TRANSCRIPTION_WORKFLOW_GUIDE.md](BYTECODE_TRANSCRIPTION_WORKFLOW_GUIDE.md) — Architecture patterns
- [CI_CD_PIPELINE_COMPREHENSIVE_GUIDE.md](CI_CD_PIPELINE_COMPREHENSIVE_GUIDE.md) — CI performance budgets

---

**Document Status:** v1.0 (2026-04-22)  
**Maintainer:** Verification team  
**Last Updated:** 2026-04-22  
**Next Review:** 2026-07-22 (quarterly)
