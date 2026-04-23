# Lean Proof Patterns Library

**Last updated:** 2026-04-22

Reusable proof patterns for CA formal verification. Covers common theorem types, proof structures, and tactical recipes for Lean 4.

## Table of Contents

1. [Per-PC Step Theorems](#per-pc-step-theorems)
2. [Functional Simulation Equivalence](#functional-simulation-equivalence)
3. [Oracle Case Splitting](#oracle-case-splitting)
4. [Shape Reduction Lemmas](#shape-reduction-lemmas)
5. [Native Call Patterns](#native-call-patterns)
6. [Error Path Handling](#error-path-handling)
7. [Composition Theorems](#composition-theorems)
8. [Common Tactics](#common-tactics)

---

## Per-PC Step Theorems

### Pattern: Simple Instruction (stLoc, ldU64, etc.)

**When to use:** Instructions that modify state predictably (store local, load constant, stack operations).

**Template:**

```lean
theorem step_pc<N> (env : ModuleEnvironment) (frame : CallFrame) (cs : ControlStack) 
    (stack : List Value) (ms : MachineState) :
    frame.pc = <N> →
    frame.function = <funcIdx> →
    MoveModel.step env frame cs stack ms = 
      .success {
        frame with
          pc := <N+1>
          locals := frame.locals.set <localIdx> <value> <bounds_proof>
      } cs stack ms := by
  intro hpc hfn
  simp only [step, hpc, hfn]
  rw [step_stLoc_frame]  -- Use step-lemma library
  simp [bounds_proof]
  rfl
```

**Key techniques:**
- Import step-lemma library: `import MovementFormal.MoveModel.StepLemmas.Basic`
- Use parametric lemmas: `step_stLoc_frame`, `step_ldU64_frame`, etc.
- `simp only` with explicit lemma list (not bare `simp`)
- Finish with `rfl` for definitional equality

**Example (from Registration/EvalEquivRebuild.lean):**

```lean
theorem step_pc3 : frame.pc = 3 → frame.function = 0 →
    step env frame cs stack ms = .success { frame with pc := 4, stack := Value.u64 0 :: stack } cs stack ms := by
  intro hpc hfn
  simp only [step, hpc, hfn]
  rw [step_ldU64]
  rfl
```

### Pattern: Conditional Branch (brTrue, brFalse)

**When to use:** Instructions that branch based on stack top.

**Template:**

```lean
theorem step_pc<N>_true (env : ModuleEnvironment) (frame : CallFrame) (cs : ControlStack)
    (stack : List Value) (ms : MachineState) :
    frame.pc = <N> →
    stack = Value.bool true :: rest →
    MoveModel.step env frame cs stack ms =
      .success { frame with pc := <target_pc> } cs rest ms := by
  intro hpc hstack
  simp only [step, hpc, hstack]
  rw [step_brTrue_frame]
  simp [target_offset]
  rfl

theorem step_pc<N>_false : -- Similar for false branch
```

**Key techniques:**
- Split into `_true` and `_false` cases
- Pattern-match stack: `Value.bool true :: rest`
- Calculate target PC from offset: `pc + offset`

### Pattern: Field Access (immBorrowField, copyField)

**When to use:** Reading struct fields from references or values.

**Template:**

```lean
theorem step_pc<N> (env : ModuleEnvironment) (frame : CallFrame) (cs : ControlStack)
    (stack : List Value) (ms : MachineState) (structVal : StructValue) :
    frame.pc = <N> →
    stack = Value.struct structVal :: rest →
    structVal.fields[<fieldIdx>]? = some <fieldValue> →
    MoveModel.step env frame cs stack ms =
      .success { frame with pc := <N+1> } cs (<fieldValue> :: rest) ms := by
  intro hpc hstack hfield
  simp only [step, hpc, hstack]
  rw [step_immBorrowField_frame]
  simp [hfield]
  rfl
```

**Key techniques:**
- Use `Array.get?` (not `Array.get` with proof) for field access
- Pattern-match struct value
- Provide field existence proof as hypothesis

---

## Functional Simulation Equivalence

### Pattern: Top-Level Eval Equivalence

**When to use:** Proving `eval <function> oracle = functionalSim oracle`.

**Template:**

```lean
theorem <operation>_eval_equiv_functional_sim :
    ∀ oracle : <Operation>Oracle,
    eval <operation> oracle = functionalSim oracle := by
  intro oracle
  unfold eval functionalSim
  rw [eval_<operation>_eq_run]  -- Unfold eval to run
  -- Case split on oracle results
  match oracle.oracleResult1, oracle.oracleResult2 with
  | .some result1, .some result2 =>
    -- Happy path: thread through PC chain
    simp only [step_pc0, step_pc1, step_pc2, ...]
    rfl
  | .none, _ | _, .none =>
    -- Error path: early abort
    simp only [step_pc0_none, step_pc1_none]
    rfl
```

**Key techniques:**
- Unfold both sides to common representation (`run`)
- Match on oracle results to split happy/error paths
- Apply per-PC step theorems in sequence
- Finish with `rfl` when both sides reduce to same value

**Example (from Normalization/EvalEquiv.lean structure):**

```lean
theorem eval_normalization_eq_run :
    eval verifyNormalizationProof oracle =
    run env initialFrame initialCS initialStack ms 14 := by
  unfold eval
  rfl

theorem normalization_eval_equiv_functional_sim :
    ∀ oracle, eval verifyNormalizationProof oracle = functionalSim oracle := by
  intro oracle
  rw [eval_normalization_eq_run]
  -- Match on oracle.verifyResult
  match oracle.verifyResult with
  | .some true => 
    -- Happy path: 14 PCs
    simp only [step_pc0, step_pc1, ..., step_pc13]
    rfl
  | .some false =>
    -- Verification failed: abort at PC 9
    simp only [step_pc0, ..., step_pc9_failed]
    rfl
  | .none =>
    -- Oracle error: abort earlier
    sorry  -- Complete when oracle error path mapped
```

### Pattern: Intermediate Equivalence Lemmas

**When to use:** Breaking large proofs into manageable pieces.

**Template:**

```lean
-- Lemma: Reduction from step N to step M
theorem eval_pcs_<N>_to_<M> (oracle : Oracle) (state<N> : State) :
    -- Precondition: we're at state after PC N
    state<N> = { pc := <N+1>, ... } →
    -- Postcondition: after PCs N+1..M, we reach state<M>
    runFrom state<N> (<M> - <N>) = state<M> := by
  intro hstate
  simp only [runFrom, step_pc<N+1>, step_pc<N+2>, ..., step_pc<M>]
  rfl
```

**Key techniques:**
- Split long PC chains into blocks (e.g., 0-5, 6-10, 11-15)
- Each block lemma proves transition from one state to next
- Compose block lemmas in top-level theorem

---

## Oracle Case Splitting

### Pattern: Option<T> Result

**When to use:** Native calls return `Option<Result>`.

**Template:**

```lean
match oracle.nativeCallResult with
| .some result =>
  -- Happy path: native succeeded
  match result with
  | .success value =>
    simp only [step_nativeCall_success]
    -- Continue with value on stack
    simp only [step_pc<next>, ...]
  | .error errorCode =>
    simp only [step_nativeCall_error]
    -- Abort with error code
    rfl
| .none =>
  -- Oracle failure: native didn't return
  simp only [step_nativeCall_none]
  rfl
```

**Key techniques:**
- Nested match for `Option` then `Result`
- Different proof path for each case
- Use specialized step lemmas: `step_nativeCall_success`, `step_nativeCall_error`, `step_nativeCall_none`

### Pattern: Boolean Verification Result

**When to use:** Sigma protocol verify returns `bool`.

**Template:**

```lean
match oracle.verifyResult with
| .some true =>
  -- Verification passed
  simp only [step_verify_pass]
  -- Continue to success path
  ...
| .some false =>
  -- Verification failed: abort with ESIGMA_PROTOCOL_VERIFY_FAILED (65537)
  simp only [step_verify_fail]
  rw [ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE_value]
  rfl
| .none =>
  -- Oracle error
  simp only [step_verify_none]
  rfl
```

**Key techniques:**
- Three-way split: true/false/none
- Use constant definitions: `ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE_value = 65537`
- Early `rfl` for abort paths (no further computation)

---

## Shape Reduction Lemmas

### Pattern: Functional Sim to VM Result

**When to use:** Proving functional sim reduces to concrete VM result shape.

**Template:**

```lean
theorem functionalSim_<case>_shape (oracle : Oracle) :
    oracle.verifyResult = .some true →
    oracle.otherConditions... →
    functionalSim oracle = .returned [] MachineState.empty := by
  intro hver hother
  unfold functionalSim
  simp only [hver, hother]
  -- Case split on internal logic
  split
  · -- Success case
    rfl
  · -- Unreachable (contradicts hypotheses)
    contradiction
```

**Key techniques:**
- One lemma per case (success, verify-failed, each error path)
- Hypotheses pin oracle results
- `split` tactic for conditional branches in functional sim
- Prove unreachable branches by `contradiction`

**Example (from Registration/EvalEquivRebuild.lean):**

```lean
theorem functionalSim_blockCDE_success (oracle : RegistrationOracle) :
    oracle.verifyResult = .some true →
    functionalSim oracle = .returned [] MachineState.empty := by
  intro hver
  unfold functionalSim
  simp only [hver]
  split <;> rfl

theorem functionalSim_blockCDE_verifyFailed (oracle : RegistrationOracle) :
    oracle.verifyResult = .some false →
    functionalSim oracle = .aborted 65537 := by
  intro hver
  unfold functionalSim
  simp only [hver]
  rfl
```

---

## Native Call Patterns

### Pattern: Opaque Native with Oracle

**When to use:** Calling Rust/Move native that Lean treats as black-box oracle.

**Template:**

```lean
-- Native oracle definition
@[opaque]
def oracleNativeCall (args : List Value) : Option NativeResult :=
  -- Lean doesn't implement this; runtime provides oracle
  none

-- Step theorem for native call
theorem step_pc<N>_native (oracle : Oracle) :
    frame.pc = <N> →
    stack = arg1 :: arg2 :: rest →
    oracle.nativeResult = .some (.success result) →
    MoveModel.step env frame cs stack ms =
      .success { frame with pc := <N+1> } cs (result :: rest) ms := by
  intro hpc hstack hresult
  simp only [step, hpc, hstack]
  rw [step_call_native]
  simp [oracleNativeCall, hresult]
  rfl
```

**Key techniques:**
- Define oracle as `@[opaque]` (Lean doesn't evaluate it)
- Oracle appears in theorem hypothesis
- Step lemma for native calls: `step_call_native`
- Runtime substitutes real oracle values during difftest

### Pattern: Native Error Handling

**When to use:** Native can fail with error code.

**Template:**

```lean
theorem step_pc<N>_native_error (oracle : Oracle) (errorCode : Nat) :
    frame.pc = <N> →
    oracle.nativeResult = .some (.error errorCode) →
    MoveModel.step env frame cs stack ms =
      .aborted errorCode := by
  intro hpc herror
  simp only [step, hpc]
  rw [step_call_native_error]
  simp [herror]
  rfl
```

---

## Error Path Handling

### Pattern: Early Abort (Option.none)

**When to use:** Oracle returns `none` instead of expected value.

**Template:**

```lean
theorem step_pc<N>_none (oracle : Oracle) :
    frame.pc = <N> →
    oracle.someOracle = .none →
    MoveModel.step env frame cs stack ms =
      .error "oracle returned none" := by
  intro hpc hnone
  simp only [step, hpc, hnone]
  rfl
```

**Key techniques:**
- Separate `_none` variant for each oracle-dependent PC
- Proof is trivial: oracle `.none` triggers error immediately
- No need to thread through rest of execution

### Pattern: Verification Failed Abort

**When to use:** Sigma protocol verify returns `false`.

**Template:**

```lean
theorem step_pc<N>_verify_failed (oracle : Oracle) :
    frame.pc = <N> →
    oracle.verifyResult = .some false →
    MoveModel.step env frame cs stack ms =
      .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE := by
  intro hpc hverify
  simp only [step, hpc, hverify]
  rw [ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE_value]
  rfl

-- Constant definition
def ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE : Nat := 65537
theorem ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE_value :
    ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE = 65537 := rfl
```

**Key techniques:**
- Use named constant for error code
- Provide `_value` theorem for `rfl` proofs
- All verify-failed paths abort with same code

---

## Composition Theorems

### Pattern: PC-Chaining (Phase 6)

**When to use:** Proving composition of multiple PCs into functional equivalence.

**Template:**

```lean
-- Helper: Single PC step preserves invariant
theorem pc<N>_preserves_invariant (state : State) (oracle : Oracle) :
    invariant state →
    let state' := step state
    invariant state' := by
  intro hinv
  unfold step
  -- Case split on branches
  split
  · -- Branch 1: show invariant preserved
    sorry
  · -- Branch 2: show invariant preserved
    sorry

-- Main composition theorem
theorem <operation>_composition :
    ∀ oracle,
    eval <operation> oracle =
    match run initialState <maxPC> oracle with
    | .returned vals ms => functionalSim_success vals ms
    | .aborted code => functionalSim_error code
    | .error msg => functionalSim_error_msg msg := by
  intro oracle
  -- Unfold to PC chain
  simp only [run, step_pc0, step_pc1, ...]
  -- Apply per-PC invariant lemmas
  apply pc0_preserves_invariant
  apply pc1_preserves_invariant
  ...
  -- Final state matches functional sim
  rfl
```

**Key techniques:**
- Define state invariant (captures what's true throughout execution)
- Prove each PC preserves invariant
- Chain invariant proofs to show final state correct
- Phase 6 scaffolds have `sorry` placeholders for this pattern

---

## Common Tactics

### Tactic: simp only [lemma_list]

**When to use:** Almost always (avoid bare `simp`).

**Why:**
- `simp` applies ALL simp lemmas in scope → slow, unpredictable
- `simp only [...]` applies only listed lemmas → fast, reproducible
- Lean LSP shows which lemmas are needed (click on goal)

**Example:**

```lean
simp only [step, MoveModel.stepInstruction, evaluateBinOp, Value.add]
```

### Tactic: rw [lemma]

**When to use:** Rewriting with equality or equivalence lemma.

**Example:**

```lean
rw [step_stLoc_frame]  -- Replace step with known equality
rw [Array.get_set_eq]  -- Simplify array update
```

**Gotcha:** `rw` doesn't close goal, need `rfl` or further tactics.

### Tactic: rfl

**When to use:** Proving definitional equality (both sides reduce to same term).

**Example:**

```lean
theorem example : 2 + 2 = 4 := rfl
theorem example2 : step ... = .success ... := by simp [...]; rfl
```

**When it fails:** Sides aren't definitionally equal → use `simp`/`rw` first.

### Tactic: split

**When to use:** Case-splitting on `match` or `if` expressions.

**Example:**

```lean
match oracle.result with
| .some val => _
| .none => _

-- Proof:
split
· -- .some val case
  rfl
· -- .none case
  rfl
```

**Variant:** `split <;> tactic` applies tactic to all branches.

### Tactic: contradiction

**When to use:** Goal is unreachable due to contradictory hypotheses.

**Example:**

```lean
theorem example (h1 : x = true) (h2 : x = false) : P := by
  contradiction  -- h1 and h2 contradict
```

### Tactic: intro

**When to use:** Introducing hypotheses from `∀` or `→` in goal.

**Example:**

```lean
theorem example : ∀ x, P x → Q x := by
  intro x        -- Introduce ∀ x
  intro hP       -- Introduce P x hypothesis
  -- Now prove Q x given hP
```

### Tactic: apply

**When to use:** Applying a lemma whose conclusion matches goal.

**Example:**

```lean
theorem helper : P → Q := ...
theorem main : P := ...

theorem example : Q := by
  apply helper  -- Goal becomes: prove P
  apply main    -- Closes goal
```

---

## Anti-Patterns (What NOT to Do)

### ❌ Bare `simp`

**Problem:** Slow, unpredictable, breaks on Mathlib updates.

```lean
-- BAD
theorem example : ... := by
  simp  -- Applies 1000+ lemmas, who knows which ones?
  
-- GOOD
theorem example : ... := by
  simp only [step, evaluateBinOp, Value.add]  -- Explicit lemma list
```

### ❌ Chained State Without `@[irreducible]`

**Problem:** O(N²) whnf cost, heartbeat explosion.

```lean
-- BAD
def state1 := { frame with pc := 1 }
def state2 := { state1 with locals := state1.locals.set 0 val proof }
def state3 := { state2 with stack := val :: state2.stack }
-- Lean unfolds state2 when elaborating state3, state3 when proving theorem

-- GOOD
@[irreducible]
def SymbolicState := { pc : Nat, locals : Array (Option Value), stack : List Value }
def state1 : SymbolicState := { pc := 1, ... }
-- Lean doesn't unfold, uses projection lemmas
```

### ❌ Bound Proofs in Theorem Statement

**Problem:** Triggers elaboration of full bounds chain.

```lean
-- BAD
theorem example : frame.locals[3]'<proof> = some val := ...

-- GOOD
theorem example : frame.locals[3]? = some val := ...  -- Uses Array.get? (Option type)
```

### ❌ Monolithic Proofs (>500 lines)

**Problem:** Hard to debug, slow to elaborate, breaks incrementality.

```lean
-- BAD
theorem big_proof : ... := by
  -- 800 lines of tactics
  ...

-- GOOD
theorem helper1 : ... := by
  -- 100 lines
  
theorem helper2 : ... := by
  -- 100 lines

theorem big_proof : ... := by
  apply helper1
  apply helper2
  rfl
```

### ❌ Unnamed `sorry`

**Problem:** No tracking, no TODO list, easy to forget.

```lean
-- BAD
theorem example : P := by
  sorry  -- No one knows what's missing

-- GOOD (if work-in-progress)
axiom example : P  -- Appears in `#print axioms`, CI catches it
-- TEMPORARY AXIOM: prove when <milestone> completes (tracked in #123)
```

---

## Quick Reference

| Task | Pattern | Section |
|------|---------|---------|
| Prove step for `stLoc` / `ldU64` | Simple instruction template | §1 |
| Prove step for `brTrue` | Conditional branch template | §1 |
| Prove step for field access | Field access template | §1 |
| Prove `eval = functionalSim` | Top-level equivalence template | §2 |
| Split long proof into blocks | Intermediate equivalence lemmas | §2 |
| Handle `Option<Result>` oracle | Option result pattern | §3 |
| Handle boolean verify result | Boolean verification pattern | §3 |
| Prove functional sim shape | Shape reduction lemma | §4 |
| Call native oracle | Opaque native template | §5 |
| Handle native errors | Native error template | §5 |
| Handle oracle `.none` | Early abort template | §6 |
| Handle verify failed | Verification failed template | §6 |
| Prove PC-chaining invariant | Composition theorem template | §7 |

---

## For More Examples

- **Registration EvalEquiv:** `lean/MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean`
  - 197 theorems, zero sorry, 3.0s build
  - Shows all patterns in production use
  
- **Phase 4 EvalEquiv files:** `Normalization/`, `Withdrawal/`, `Transfer/`, `Rotation/`
  - Simpler than Registration (no container mutations)
  - Good starting point for learning patterns

- **Step-lemma library:** `lean/MovementFormal/MoveModel/StepLemmas/`
  - Reusable per-instruction lemmas
  - Import and apply, don't re-prove

---

## Getting Help

- **Pattern not listed here?** Ask in #formal-verification Slack
- **Proof stuck?** Share minimal example + profiler output
- **New pattern discovered?** PR this doc with addition

**Happy proving!** 🎓
