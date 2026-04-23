# Lean Proof Tactics Reference for CA Verification

**Purpose:** Comprehensive reference for all Lean 4 tactics used in Confidential Assets formal verification. Organized by use case with real examples from the CA codebase.

**Audience:** Developers writing or maintaining Lean proofs in `lean/MovementFormal/`.

**Version:** Lean 4.24.0, Mathlib nightly (pinned in `lean-toolchain`)

---

## Table of Contents

1. [Basic Tactics](#1-basic-tactics)
2. [Rewriting Tactics](#2-rewriting-tactics)
3. [Simplification Tactics](#3-simplification-tactics)
4. [Case Analysis](#4-case-analysis)
5. [Hypothesis Management](#5-hypothesis-management)
6. [Decidability and Computation](#6-decidability-and-computation)
7. [Structural Tactics](#7-structural-tactics)
8. [Advanced Tactics](#8-advanced-tactics)
9. [Custom CA Tactics](#9-custom-ca-tactics)
10. [Performance-Critical Patterns](#10-performance-critical-patterns)

---

## 1. Basic Tactics

### 1.1 `rfl` (Reflexivity)

**Purpose:** Close goals where LHS and RHS are definitionally equal.

**Example from CA:**
```lean
theorem step_pc0_immBorrowLoc :
    step env (normalizationState 0 proofRef) cs ms = .ok (normalizationState 1 proofRef') cs ms := by
  rw [normalizationState]
  rw [step_immBorrowLoc_frame]
  rfl  -- Both sides are now identical after rewriting
```

**When to use:**
- After all rewrites when both sides are syntactically equal
- As the final tactic in most proofs

**Common pitfalls:**
- **Using `rfl` too early** — if sides aren't equal yet, Lean will error
- **Missing rewrites** — ensure all definitional unfoldings are done first

---

### 1.2 `exact` (Exact Match)

**Purpose:** Provide the exact proof term for the goal.

**Example from CA:**
```lean
theorem normalization_eval_equiv_functional_sim : ... := by
  unfold verifyNormalizationBytecodeResult
  cases h : oracle.verifyNormalizationProof proofRef
  case none =>
    exact normalization_shape_verifyFailed oracle proofRef cs ms h
  case some proof =>
    exact normalization_shape_success oracle proofRef proof cs ms h
```

**When to use:**
- Dispatching to helper lemmas
- Providing a witness for an existential goal
- When the proof term is known and simple

---

### 1.3 `assumption` (Use Hypothesis)

**Purpose:** Close the goal by finding a matching hypothesis.

**Example:**
```lean
theorem step_pc5_with_precondition 
    (h_bounds : frame.locals.size > 5) : ... := by
  rw [step_stLoc_frame]
  assumption  -- Lean finds h_bounds in context and uses it
```

**When to use:**
- After introducing hypotheses that match the goal
- As a fallback when the exact hypothesis name is unclear

---

## 2. Rewriting Tactics

### 2.1 `rw` (Rewrite)

**Purpose:** Replace subexpressions using an equality.

**Example from CA (PC-chaining):**
```lean
theorem normalization_run_eq : 
    run env frame cs ms = .returned [] ms := by
  unfold run
  rw [step_pc0, step_pc1, step_pc2, ..., step_pc13]  -- Chain through all PCs
  cases h : oracle.verifyProof ref
  simp
  rfl
```

**Variants:**
- `rw [lemma]` — rewrite left-to-right
- `rw [←lemma]` — rewrite right-to-left (reversed)
- `rw [lemma] at h` — rewrite in hypothesis `h` instead of goal

**Common patterns in CA:**
- **PC chaining:** `rw [step_pc0, step_pc1, ..., step_pcN]`
- **State unfolding:** `rw [registrationState]`
- **Oracle substitution:** `rw [h_oracle]`

**Performance tip:**
- Avoid bare `rw [def]` on large definitions — mark them `@[irreducible]` and unfold explicitly

---

### 2.2 `unfold` (Definitional Unfolding)

**Purpose:** Expand a definition in the goal.

**Example from CA:**
```lean
theorem eval_registration_eq_run :
    eval (registrationModuleEnv o) verifyRegistrationProofIdx args cs ms =
      run env (registrationInitFrame args) cs ms := by
  unfold eval registrationModuleEnv verifyRegistrationProofIdx
  simp only [List.get, Array.size, ...]
  rfl
```

**When to use:**
- Unfolding entry points (`eval`, `run`)
- Expanding custom definitions (`registrationState`, `normalizationState`)

**Difference from `rw`:**
- `unfold` always expands definitions
- `rw` uses equalities (can be lemmas, not just definitions)

---

## 3. Simplification Tactics

### 3.1 `simp` (Simplifier)

**Purpose:** Apply a set of simplification lemmas to reduce the goal.

**⚠️ WARNING:** Bare `simp` is BANNED in CA proofs (causes performance issues).

**Always use `simp only [...]` with an explicit lemma list:**

```lean
theorem step_pc3_call :
    step env frame cs ms = ... := by
  rw [step_call_frame]
  simp only [Frame.pc, Frame.code, Frame.locals, Option.isSome, decide_eq_true]
  rfl
```

**Why `simp only`:**
- Predictable performance (no unbounded simp set exploration)
- Explicit about what's being simplified (easier to audit)
- Faster compilation (no simp lemma database search)

**Common simp lemma sets in CA:**
- `[Frame.pc, Frame.locals, Frame.code]` — frame projections
- `[Option.isSome, Option.isNone, Option.get?]` — option operations
- `[List.get?, Array.get?, Array.size]` — array/list operations
- `[decide_eq_true, decide_eq_false]` — boolean decidability

---

### 3.2 `simp_all` (Simplify Goal and Hypotheses)

**Purpose:** Apply simplification to both the goal and all hypotheses.

**Example:**
```lean
theorem helper (h1 : x + 0 = x) (h2 : y * 1 = y) : x + y = ... := by
  simp_all only [add_zero, mul_one]
  rfl
```

**When to use:**
- When hypotheses need simplification too (not just the goal)
- Useful in case-split branches where hypotheses are messy

**Performance warning:**
- Still expensive if not controlled — use `simp_all only [...]` with an explicit list

---

## 4. Case Analysis

### 4.1 `cases` (Pattern Matching)

**Purpose:** Destruct a value into its constructors.

**Example from CA (oracle case-split):**
```lean
theorem normalization_composition :
    run env frame cs ms = verifyNormalizationBytecodeResult oracle ref := by
  unfold verifyNormalizationBytecodeResult
  cases h : oracle.verifyNormalizationProof ref
  case none =>
    -- Proof failed case
    rw [h]
    apply normalization_shape_verifyFailed
  case some proof =>
    -- Proof succeeded case
    rw [h]
    apply normalization_shape_success
```

**Variants:**
- `cases x` — destruct `x` into its constructors
- `cases h : x` — destruct `x` and name the equality `h : x = <constructor>`
- `case <constructor> => ...` — handle each case separately

**Common CA use cases:**
- **Oracle results:** `cases h : oracle.verifyProof ref` (splits `none` vs `some`)
- **Option types:** `cases frame.locals.get? idx` (splits `none` vs `some`)
- **Execution results:** `cases run env frame cs ms` (splits `.ok` vs `.error` vs `.aborted` vs `.returned`)

---

### 4.2 `split` (If-Then-Else)

**Purpose:** Split an `if-then-else` expression.

**Example:**
```lean
theorem conditional_step :
    step env frame cs ms = if condition then branch_a else branch_b := by
  split
  case inl h =>
    -- h : condition = true
    rw [h]
    ...
  case inr h =>
    -- h : condition = false
    rw [h]
    ...
```

**When to use:**
- When the goal contains `if` expressions
- Alternative to `cases` for boolean conditions

---

## 5. Hypothesis Management

### 5.1 `intro` (Introduce Variables)

**Purpose:** Introduce hypotheses from the goal's quantifiers or implications.

**Example:**
```lean
theorem forall_implies_example : ∀ x : Nat, x > 0 → x + 1 > 1 := by
  intro x        -- Introduce the quantified variable
  intro h_pos    -- Introduce the hypothesis x > 0
  -- Goal is now: x + 1 > 1, with h_pos : x > 0 in context
  omega
```

**When to use:**
- At the start of proofs with `∀` or `→` in the goal
- To name hypotheses for later use

---

### 5.2 `have` (Intermediate Claims)

**Purpose:** Prove an intermediate lemma and add it to the context.

**Example from CA:**
```lean
theorem step_pc7_with_bounds :
    step env frame cs ms = ... := by
  have h_size : frame.locals.size = 19 := by
    unfold frame
    rfl
  
  rw [step_stLoc_frame h_size]
  rfl
```

**When to use:**
- Proving preconditions for step lemmas (e.g., array bounds)
- Breaking down complex proofs into manageable pieces
- Avoiding repetition of the same proof term

**Variants:**
- `have h : P := by <proof>` — prove `P` and name it `h`
- `have h : P := <term>` — provide `P` as a term directly

---

### 5.3 `let` (Introduce Definitions)

**Purpose:** Introduce a local definition in the proof.

**Example:**
```lean
theorem sum_preservation :
    sum_balance(store.pending_balance) = ... := by
  let old_sum := sum_balance(old(store.pending_balance))
  let new_sum := sum_balance(store.pending_balance)
  
  have h_eq : old_sum = new_sum := by ...
  
  rw [h_eq]
  rfl
```

**When to use:**
- Naming complex subexpressions for readability
- Avoiding repetition of the same expression

---

## 6. Decidability and Computation

### 6.1 `decide` (Decidable Propositions)

**Purpose:** Solve goals that are computationally decidable.

**Example from CA (array bounds):**
```lean
theorem pc_in_bounds : 7 < verifyRegistrationProofCode.size := by
  decide  -- Lean computes: verifyRegistrationProofCode.size = 97, 7 < 97 is true
```

**When to use:**
- Arithmetic comparisons (`<`, `≤`, `=` on `Nat`, `Int`)
- Boolean expressions
- Finite case distinctions

**Performance warning:**
- `decide` can be slow for large computations — use it for simple facts only

---

### 6.2 `omega` (Linear Arithmetic)

**Purpose:** Solve linear arithmetic goals.

**Example:**
```lean
theorem bounds_lemma (h1 : x > 5) (h2 : y < 10) : x + y < 20 := by
  omega  -- Automatic linear arithmetic solver
```

**When to use:**
- Arithmetic goals involving `+`, `-`, `*` (by constants), `<`, `≤`, `=`
- Bounds proofs
- Numerical reasoning

**Limitations:**
- Only linear arithmetic (no division, exponentiation, multiplication of variables)
- Only `Nat`, `Int`, `Rat` types

---

## 7. Structural Tactics

### 7.1 `apply` (Apply Lemma)

**Purpose:** Apply a lemma or function to the goal.

**Example from CA:**
```lean
theorem normalization_composition : ... := by
  unfold verifyNormalizationBytecodeResult
  cases h : oracle.verifyNormalizationProof ref
  case none =>
    apply normalization_shape_verifyFailed  -- Apply helper lemma
    assumption  -- Provide the required hypothesis
```

**When to use:**
- Dispatching to helper lemmas
- Applying implications (`P → Q` when goal is `Q` and you can prove `P`)

**Difference from `exact`:**
- `apply` can leave subgoals (for the lemma's hypotheses)
- `exact` requires the term to match the goal exactly

---

### 7.2 `constructor` (Build Data)

**Purpose:** Construct a value of an inductive type.

**Example:**
```lean
theorem pair_example : ∃ x : Nat, x > 5 := by
  constructor  -- Provides the witness
  -- Now need to provide the Nat and the proof x > 5
  exact 10
  decide
```

**When to use:**
- Existential goals (`∃ x, P x`)
- Conjunction goals (`P ∧ Q`)
- Building structs/records

---

## 8. Advanced Tactics

### 8.1 `conv` (Conversion Mode)

**Purpose:** Navigate into subexpressions and rewrite selectively.

**Example:**
```lean
theorem selective_rewrite :
    f (g (h x)) + g (h x) = ... := by
  conv =>
    lhs                    -- Focus on left-hand side
    arg 1                  -- Navigate to first argument of (+)
    rw [my_lemma]          -- Rewrite only f (g (h x)), not g (h x)
  rfl
```

**When to use:**
- When `rw` rewrites too much (need selective rewriting)
- Navigating into nested expressions

**Common pitfall:**
- Over-use makes proofs hard to read — prefer `rw at h` when possible

---

### 8.2 `induction` (Inductive Proofs)

**Purpose:** Prove by induction on a structure (e.g., `Nat`, `List`).

**Example:**
```lean
theorem sum_append (xs ys : List Nat) :
    sum (xs ++ ys) = sum xs + sum ys := by
  induction xs with
  | nil => simp [sum, List.append]
  | cons x xs ih =>
    simp [sum, List.append, ih]
    omega
```

**When to use:**
- Proofs over recursive data structures (`List`, `Nat`, `Tree`)
- Recursively-defined functions

---

## 9. Custom CA Tactics

### 9.1 `@[irreducible]` Attribute (Not a Tactic, But Critical)

**Purpose:** Mark definitions as opaque to prevent automatic unfolding.

**Example from CA:**
```lean
@[irreducible]
def registrationState (pc : Nat) (proofRef : RefValue) (...) : Frame :=
  { code := verifyRegistrationProofCode,
    pc := pc,
    locals := ...,
    localRefs := ... }
```

**Why critical for performance:**
- Without `@[irreducible]`, Lean unfolds the full definition every time it's used
- Leads to O(N²) elaboration cost in PC-chaining proofs
- **100× speedup** in Phase 4 proofs by using `@[irreducible]`

**How to use:**
- Mark state constructors `@[irreducible]`
- Expose projection lemmas with `@[simp]`:
  ```lean
  @[simp]
  theorem registrationState_pc : (registrationState pc ref ...).pc = pc := by
    unfold registrationState
    rfl
  ```

---

### 9.2 Step Lemma Library Pattern

**Not a tactic, but a critical CA proof pattern:**

**Structure:**
```lean
-- In StepLemmas.Basic:
theorem step_immBorrowLoc_frame 
    {env : Environment} {frame : Frame} {cs : CallStack} {ms : MachineState}
    (h_pc : frame.pc < frame.code.size)
    (h_instr : frame.code.get? frame.pc = some (Instruction.immBorrowLoc locIdx))
    : step env frame cs ms = .ok { frame with pc := frame.pc + 1, ... } cs ms := by
  unfold step
  simp only [h_instr, Frame.pc, ...]
  rfl

-- In actual proof:
theorem step_pc0 :
    step env (registrationState 0 ...) cs ms = .ok (registrationState 1 ...) cs ms := by
  rw [registrationState]
  rw [step_immBorrowLoc_frame]  -- One-line application
  rfl
```

**Benefits:**
- Each step lemma proved once, reused 100+ times
- **10-20× speedup** vs proving each PC step from scratch

---

## 10. Performance-Critical Patterns

### 10.1 Avoid Bare `simp`

**Bad:**
```lean
theorem slow_proof : ... := by
  simp  -- Searches entire simp lemma database, expensive!
  rfl
```

**Good:**
```lean
theorem fast_proof : ... := by
  simp only [Frame.pc, Frame.locals, Option.get?]  -- Explicit lemma list
  rfl
```

**Performance impact:** 5-10× speedup in large proof files.

---

### 10.2 Use `@[irreducible]` for State Constructors

**Bad:**
```lean
def statePC0 : Frame := { code := [...], pc := 0, ... }  -- Will unfold everywhere

theorem step_0 : step env statePC0 cs ms = ... := by
  rw [statePC0]  -- Expensive unfold every time
  ...
```

**Good:**
```lean
@[irreducible]
def statePC0 : Frame := { code := [...], pc := 0, ... }

@[simp]
theorem statePC0_pc : statePC0.pc = 0 := by unfold statePC0; rfl

theorem step_0 : step env statePC0 cs ms = ... := by
  rw [step_immBorrowLoc_frame]  -- Uses statePC0 opaquely
  rfl
```

**Performance impact:** 100× speedup in Phase 4 proofs.

---

### 10.3 Avoid Bound Proofs in Theorem Statements

**Bad:**
```lean
theorem step_with_bounds :
    step env { frame with locals := frame.locals.set! 5 val } cs ms = ... := by
  -- The bound proof for .set! is elaborated during statement parsing — expensive!
  ...
```

**Good:**
```lean
theorem step_with_bounds :
    frame.locals.get? 5 = some val →
    step env { frame with locals := frame.locals.set! 5 val' } cs ms = ... := by
  intro h_get
  have h_bounds : 5 < frame.locals.size := by ...
  rw [Array.set!_eq_set h_bounds]
  ...
```

**Performance impact:** 50× speedup in statements with many array accesses.

---

## Summary Table

| Tactic | Purpose | Performance | When to Use |
|---|---|---|---|
| `rfl` | Close definitionally equal goals | Fast | Final step of most proofs |
| `exact` | Provide exact proof term | Fast | Dispatch to helper lemmas |
| `rw` | Rewrite using equality | Medium | PC chaining, state unfolding |
| `simp only` | Controlled simplification | Medium | Reduce expressions with explicit lemma list |
| `cases` | Pattern match / destruct | Fast | Oracle case-splits, option unwrapping |
| `decide` | Decidable computation | Slow | Simple arithmetic, boolean expressions |
| `omega` | Linear arithmetic solver | Medium | Bounds proofs, numerical reasoning |
| `have` | Intermediate claim | Fast | Breaking down complex proofs, preconditions |
| `apply` | Apply lemma | Fast | Use helper lemmas, dispatch to subgoals |
| `@[irreducible]` | Opaque definitions | **Critical** | State constructors (100× speedup) |

---

## Resources

- **Lean 4 documentation:** https://lean-lang.org/documentation/
- **Mathlib tactics:** https://leanprover-community.github.io/mathlib4_docs/tactics.html
- **CA step lemma library:** `lean/MovementFormal/MoveModel/StepLemmas/`
- **CA proof examples:** `lean/MovementFormal/Experimental/ConfidentialAsset/*/EvalEquiv.lean`
- **Performance guide:** `PERFORMANCE_OPTIMIZATION_GUIDE.md`

---

## Next Steps

After mastering these tactics:
1. Study the step lemma library pattern (§9.2)
2. Review Phase 4 EvalEquiv files for concrete examples
3. Practice on a simple operation (Normalization) before tackling complex ones (Transfer)
4. Always profile build times (`lake build --verbose`) to catch performance regressions
