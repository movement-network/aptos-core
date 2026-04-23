# Lean Tactics Cookbook

**Purpose:** Practical recipes for common proof patterns in Confidential Assets verification.

**Audience:** Formal verification engineers writing Lean 4 proofs.

**Scope:** Proven tactics patterns, common proof recipes, debugging strategies.

**Prerequisites:** Basic Lean 4 knowledge (completed "Theorem Proving in Lean 4").

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Basic Recipes](#2-basic-recipes)
3. [Step Lemma Recipes](#3-step-lemma-recipes)
4. [PC-Chaining Recipes](#4-pc-chaining-recipes)
5. [Oracle Handling Recipes](#5-oracle-handling-recipes)
6. [Arithmetic Recipes](#6-arithmetic-recipes)
7. [Debugging Recipes](#7-debugging-recipes)
8. [Performance Recipes](#8-performance-recipes)

---

## 1. Introduction

### 1.1 What is This Guide?

**This is a cookbook** — a collection of proven recipes for common proof patterns in CA verification.

**Not a reference** — For comprehensive tactics documentation, see `LEAN_PROOF_TACTICS_REFERENCE.md`.

**Goal:** Copy-paste solutions to common proof situations, adapt to your case.

### 1.2 How to Use This Guide

**When stuck on a proof:**

1. Identify the proof pattern (step lemma? PC-chaining? arithmetic?)
2. Find matching recipe in this guide
3. Copy recipe template
4. Fill in specifics for your case
5. Test and iterate

**Recipe format:**

```
Recipe Name
  Goal: What you're trying to prove
  Pattern: When to use this recipe
  Solution: Tactic sequence
  Example: Concrete case
  Variations: Common adjustments
```

### 1.3 Conventions

**Placeholder notation:**

- `<name>` — Fill in with your specific name
- `...` — Continuation of pattern
- `-- Comment` — Explanation, not code

**Tactic abbreviations:**

- `rw` = rewrite
- `simp` = simplify
- `exact` = exact proof term

---

## 2. Basic Recipes

### Recipe 2.1: Prove Equality by Unfolding

**Goal:** Prove `A = B` where definitions match.

**Pattern:** Both sides are defined constructions that are obviously equal.

**Solution:**

```lean
theorem my_equality : A = B := by
  unfold A B
  rfl
```

**Example:**

```lean
@[simp]
theorem registrationState_pc (pc : Nat) (ref : Address) (locals : Locals) :
    (registrationState pc ref locals).pc = pc := by
  unfold registrationState  -- Expand definition
  rfl                       -- Both sides equal after expansion
```

**Variations:**

```lean
-- If need to unfold multiple definitions
theorem complex_equality : A = B := by
  unfold A
  unfold B
  unfold helper1
  unfold helper2
  rfl

-- If equality is hidden in structure
theorem struct_equality : struct.field = value := by
  unfold struct
  simp  -- Simplify field access
  rfl
```

---

### Recipe 2.2: Prove by Simplification

**Goal:** Prove `P` where `P` follows from known lemmas.

**Pattern:** Goal can be reduced to `True` or `rfl` using simp lemmas.

**Solution:**

```lean
theorem my_theorem : P := by
  simp [lemma1, lemma2, lemma3]
```

**Example:**

```lean
theorem locals_length_preserved :
    (updateLocal locals idx value).length = locals.length := by
  simp [updateLocal]  -- Use simp lemma for updateLocal
```

**Variations:**

```lean
-- With only specific lemmas (performance critical)
theorem my_theorem : P := by
  simp only [lemma1, lemma2]
  -- Faster than bare `simp`

-- With additional reasoning after simp
theorem my_theorem : P := by
  simp [lemma1]
  -- Goal simplified but not solved
  exact some_proof
```

**Warning:** Avoid bare `simp` in CA proofs (performance). Always specify lemmas: `simp only [...]`.

---

### Recipe 2.3: Prove by Cases

**Goal:** Prove `P` by splitting into cases.

**Pattern:** Goal depends on value of some term (enum, bool, option).

**Solution:**

```lean
theorem my_theorem (x : Type) : P x := by
  cases x with
  | case1 => <proof for case1>
  | case2 => <proof for case2>
  | case3 => <proof for case3>
```

**Example:**

```lean
theorem oracle_result_valid (result : OracleResult) :
    result = .success ∨ result = .verifyFailed ∨ result = .error := by
  cases result with
  | success => left; rfl
  | verifyFailed => right; left; rfl
  | error => right; right; rfl
```

**Variations:**

```lean
-- Named fields in pattern
theorem option_cases (opt : Option Nat) : P opt := by
  cases opt with
  | none => <proof when none>
  | some n => <proof when some, n available>

-- Multiple case splits
theorem double_cases (x : Bool) (y : Bool) : P x y := by
  cases x with
  | true =>
    cases y with
    | true => <both true>
    | false => <x true, y false>
  | false =>
    cases y with
    | true => <x false, y true>
    | false => <both false>
```

---

### Recipe 2.4: Prove by Hypothesis

**Goal:** Prove `P` using existing hypothesis.

**Pattern:** Goal exactly matches a hypothesis, or follows trivially.

**Solution:**

```lean
theorem my_theorem (h : P) : P := by
  exact h
```

**Example:**

```lean
theorem use_oracle_hypothesis
    (h_oracle : verify_proof_oracle proof = .success)
    : verify_proof_oracle proof = .success := by
  exact h_oracle
```

**Variations:**

```lean
-- Hypothesis needs transformation
theorem transformed_hypothesis
    (h : A = B)
    : B = A := by
  exact h.symm  -- Symmetry of equality

-- Hypothesis is implication
theorem use_implication
    (h_impl : A → B)
    (h_a : A)
    : B := by
  exact h_impl h_a  -- Apply implication
```

---

### Recipe 2.5: Prove Conjunction

**Goal:** Prove `A ∧ B`.

**Pattern:** Must prove both parts independently.

**Solution:**

```lean
theorem my_conjunction : A ∧ B := by
  constructor
  · <proof of A>
  · <proof of B>
```

**Example:**

```lean
theorem balance_preservation :
    (sender_balance' = sender_balance - amount) ∧
    (receiver_balance' = receiver_balance + amount) := by
  constructor
  · -- Prove sender balance decreases
    rw [update_sender_balance]
    ring
  · -- Prove receiver balance increases
    rw [update_receiver_balance]
    ring
```

**Variations:**

```lean
-- Three-way conjunction
theorem triple_conjunction : A ∧ B ∧ C := by
  constructor
  · <proof of A>
  · constructor
    · <proof of B>
    · <proof of C>

-- Using have for intermediate results
theorem conjunction_with_intermediates : A ∧ B := by
  have ha : A := by <proof of A>
  have hb : B := by <proof of B>
  exact ⟨ha, hb⟩
```

---

## 3. Step Lemma Recipes

### Recipe 3.1: CopyLoc Step

**Goal:** Prove `step env (state pc ...) = .inProgress (state (pc+1) ...)` where instruction is `CopyLoc[idx]`.

**Pattern:** Copying local variable to stack.

**Solution:**

```lean
theorem step_pc_to_pc1
    (h_locals : locals.length > idx)
    : step env (operationState pc ref locals) =
        .inProgress (operationState (pc+1) ref locals') := by
  unfold step
  rw [operationState_code, operationState_pc]
  simp only [operationCode]
  apply step_copyLoc
  · exact h_locals  -- Index in bounds
  · simp only [locals']  -- Locals unchanged
  done
```

**Example:**

```lean
theorem registrationStep_0_to_1
    (h_locals : locals.length > 0)
    : step env (registrationState 0 proofRef locals) =
        .inProgress (registrationState 1 proofRef locals) := by
  unfold step
  rw [registrationState_code, registrationState_pc]
  simp only [verifyRegistrationProofCode]
  apply step_copyLoc
  · exact h_locals
  · rfl
```

**Variations:**

```lean
-- If locals unchanged, can use same locals
theorem copyLoc_preserves_locals :
    step env (state pc locals) =
      .inProgress (state (pc+1) locals) := by
  unfold step
  rw [state_code, state_pc]
  simp only [code]
  apply step_copyLoc
  · omega  -- Prove index in bounds
  · rfl    -- Locals identical

-- If need to track stack change
theorem copyLoc_updates_stack
    (h_get : locals[idx] = some value)
    : step env (state pc locals []) =
        .inProgress (state (pc+1) locals [value]) := by
  unfold step
  apply step_copyLoc
  · omega
  · exact h_get
```

---

### Recipe 3.2: StLoc Step

**Goal:** Prove step for `StLoc[idx]` (store stack top to local).

**Pattern:** Popping from stack, storing to local variable.

**Solution:**

```lean
theorem step_pc_to_pc1
    (h_stack : stack = [value])
    : step env (operationState pc ref (value :: stack_rest)) =
        .inProgress (operationState (pc+1) ref locals') := by
  unfold step
  rw [operationState_code, operationState_pc]
  simp only [operationCode]
  apply step_stLoc
  · exact h_stack  -- Stack has value on top
  · simp only [locals']  -- locals' = locals with idx updated
  done
```

**Example:**

```lean
theorem registrationStep_2_to_3
    (h_stack : stack = [.ristrettoPoint clonedPoint])
    : step env (registrationState 2 ref ([.ristrettoPoint clonedPoint] ++ rest)) =
        .inProgress (registrationState 3 ref locals') := by
  unfold step
  rw [registrationState_code, registrationState_pc]
  simp only [verifyRegistrationProofCode]
  apply step_stLoc
  · exact h_stack
  · unfold locals'
    simp [updateLocal]
```

---

### Recipe 3.3: Call Native Function Step

**Goal:** Prove step for `Call <native_function>`.

**Pattern:** Calling native function (oracle).

**Solution:**

```lean
theorem step_pc_to_pc1
    (h_oracle : env.oracle «function_name» args = result)
    : step env (operationState pc ref locals) =
        .inProgress (operationState (pc+1) ref locals') := by
  unfold step
  rw [operationState_code, operationState_pc]
  simp only [operationCode]
  apply step_call_native
  · exact h_oracle  -- Oracle returns result
  · simp only [locals']  -- Updated with result
  done
```

**Example:**

```lean
theorem registrationStep_7_to_8
    (h_oracle : env.oracle «verify_registration_proof_native» proof = .success)
    : step env (registrationState 7 ref locals) =
        .inProgress (registrationState 8 ref locals') := by
  unfold step
  rw [registrationState_code, registrationState_pc]
  simp only [verifyRegistrationProofCode]
  apply step_call_native
  · exact h_oracle
  · simp [locals']
```

**Variations:**

```lean
-- If oracle can fail
theorem call_native_with_error
    (h_oracle : env.oracle «function» args = .error)
    : step env (state pc locals) = .error := by
  unfold step
  rw [state_code, state_pc]
  simp only [code]
  apply step_call_native_error
  exact h_oracle

-- If oracle result affects control flow
theorem call_native_branches
    (h_oracle : env.oracle «verify» proof = result)
    : step env (state pc locals) =
        match result with
        | .success => .inProgress (state (pc+1) locals_success)
        | .verifyFailed => .inProgress (state (pc+1) locals_failed)
  := by
  cases result with
  | success => <proof for success>
  | verifyFailed => <proof for failed>
```

---

### Recipe 3.4: BrTrue/BrFalse Step

**Goal:** Prove step for conditional branch.

**Pattern:** Branch based on boolean stack value.

**Solution:**

```lean
-- BrTrue (branch if true)
theorem step_pc_brTrue_to_target
    (h_stack : stack.top = .bool true)
    : step env (operationState pc ref (stack :: rest)) =
        .inProgress (operationState target ref rest) := by
  unfold step
  rw [operationState_code, operationState_pc]
  simp only [operationCode]
  apply step_brTrue
  exact h_stack

-- BrFalse (branch if false)
theorem step_pc_brFalse_to_target
    (h_stack : stack.top = .bool false)
    : step env (operationState pc ref (stack :: rest)) =
        .inProgress (operationState target ref rest) := by
  unfold step
  rw [operationState_code, operationState_pc]
  simp only [operationCode]
  apply step_brFalse
  exact h_stack
```

**Example:**

```lean
theorem registrationStep_8_to_12_failure
    (h_stack : stack = [.bool false])
    : step env (registrationState 8 ref ([.bool false] :: rest)) =
        .inProgress (registrationState 12 ref rest) := by
  unfold step
  rw [registrationState_code, registrationState_pc]
  simp only [verifyRegistrationProofCode]
  apply step_brFalse_take  -- Branch taken when false
  rfl
```

**Variations:**

```lean
-- BrTrue does NOT branch (falls through)
theorem brTrue_fallthrough
    (h_stack : stack.top = .bool false)
    : step env (state pc (stack :: rest)) =
        .inProgress (state (pc+1) rest) := by
  apply step_brTrue_skip
  exact h_stack

-- BrFalse does NOT branch (falls through)
theorem brFalse_fallthrough
    (h_stack : stack.top = .bool true)
    : step env (state pc (stack :: rest)) =
        .inProgress (state (pc+1) rest) := by
  apply step_brFalse_skip
  exact h_stack
```

---

### Recipe 3.5: LdU64 / Ret / Abort Steps

**Goal:** Prove steps for simple instructions.

**Pattern:** Load constant, return, or abort.

**Solution:**

```lean
-- LdU64 (load constant)
theorem step_pc_ldU64 :
    step env (operationState pc ref locals) =
      .inProgress (operationState (pc+1) ref ([.u64 value] :: locals)) := by
  unfold step
  rw [operationState_code, operationState_pc]
  simp only [operationCode]
  apply step_ldU64
  rfl

-- Ret (return)
theorem step_pc_ret
    (h_stack : stack = [returnValue])
    : step env (operationState pc ref (stack :: rest)) =
        .returned [returnValue] := by
  unfold step
  rw [operationState_code, operationState_pc]
  simp only [operationCode]
  apply step_ret
  exact h_stack

-- Abort
theorem step_pc_abort
    (h_stack : stack = [.u64 abortCode])
    : step env (operationState pc ref (stack :: rest)) =
        .aborted abortCode := by
  unfold step
  rw [operationState_code, operationState_pc]
  simp only [operationCode]
  apply step_abort
  exact h_stack
```

**Example:**

```lean
theorem registrationStep_11_to_12_load_abort_code :
    step env (registrationState 11 ref locals) =
      .inProgress (registrationState 12 ref ([.u64 65537] :: locals)) := by
  unfold step
  rw [registrationState_code, registrationState_pc]
  simp only [verifyRegistrationProofCode]
  apply step_ldU64
  rfl

theorem registrationStep_12_abort
    (h_stack : stack = [.u64 65537])
    : step env (registrationState 12 ref (stack :: rest)) =
        .aborted 65537 := by
  unfold step
  rw [registrationState_code, registrationState_pc]
  simp only [verifyRegistrationProofCode]
  apply step_abort
  rfl
```

---

## 4. PC-Chaining Recipes

### Recipe 4.1: Linear Chain (No Branches)

**Goal:** Chain steps from PC A to PC B with no branches.

**Pattern:** Sequence of steps without conditionals.

**Solution:**

```lean
theorem chain_A_to_B :
    run env (state A ...) (B - A) = .inProgress (state B ...) := by
  -- Chain each step
  rw [run_succ, step_A_to_A1]
  rw [run_succ, step_A1_to_A2]
  rw [run_succ, step_A2_to_A3]
  -- ... continue for all steps ...
  rw [run_succ, step_Bminus1_to_B]
  rw [run_zero]
  rfl
```

**Example:**

```lean
theorem registration_setup_chain_0_to_5 :
    run env (registrationState 0 ref locals) 5 =
      .inProgress (registrationState 5 ref locals') := by
  rw [run_succ, registrationStep_0_to_1]
  rw [run_succ, registrationStep_1_to_2]
  rw [run_succ, registrationStep_2_to_3]
  rw [run_succ, registrationStep_3_to_4]
  rw [run_succ, registrationStep_4_to_5]
  rw [run_zero]
  rfl
```

**Variations:**

```lean
-- Use eval instead of run (for complete execution)
theorem eval_chain_to_return :
    eval env (state 0 ...) cs ms =
      .returned [result] ms' := by
  unfold eval
  rw [eval_eq_run]
  rw [run_succ, step_0_to_1]
  rw [run_succ, step_1_to_2]
  -- ... chain to Ret ...
  rw [run_succ, step_N_ret]
  rfl
```

---

### Recipe 4.2: Branching Chain (Oracle Result)

**Goal:** Chain steps with branch depending on oracle result.

**Pattern:** Native call returns result, branch on result.

**Solution:**

```lean
theorem chain_with_oracle_branch
    (h_oracle : oracleResult = ...)
    : eval env (state 0 ...) cs ms =
        match oracleResult with
        | .success => .returned [] ms'
        | .verifyFailed => .aborted abortCode ms
  := by
  unfold eval
  rw [eval_eq_run]
  cases oracleResult with
  | success =>
    -- Success path
    rw [run_succ, step_0_to_1]
    -- ... chain to native call ...
    rw [run_succ, step_N_call h_oracle]
    rw [run_succ, step_N1_brTrue_fallthrough]  -- True → don't branch
    -- ... chain to Ret ...
    rw [run_succ, step_M_ret]
    rfl
  | verifyFailed =>
    -- Failure path
    rw [run_succ, step_0_to_1]
    -- ... chain to native call ...
    rw [run_succ, step_N_call h_oracle]
    rw [run_succ, step_N1_brFalse_take]  -- False → branch to abort
    -- ... chain to Abort ...
    rw [run_succ, step_P_ldU64]
    rw [run_succ, step_P1_abort]
    rfl
```

**Example:**

```lean
theorem registration_eval_equiv
    (h_oracle : oracleResult = verify_registration_oracle proof)
    : eval env (registrationState 0 ref) cs ms =
        match oracleResult with
        | .success => .returned [.u64 0] ms
        | .verifyFailed => .aborted 65537 ms
  := by
  unfold eval
  rw [eval_registration_eq_run]
  cases oracleResult with
  | success =>
    -- Success: 0 → 1 → ... → 10 → Ret
    rw [run_succ, registrationStep_0_to_1]
    rw [run_succ, registrationStep_1_to_2]
    -- ... (steps 2-7) ...
    rw [run_succ, registrationStep_7_to_8 h_oracle]
    rw [run_succ, registrationStep_8_to_9_success]
    rw [run_succ, registrationStep_9_to_10]
    rw [run_succ, registrationStep_10_ret]
    rfl
  | verifyFailed =>
    -- Failure: 0 → 1 → ... → 8 → 12 → Abort
    rw [run_succ, registrationStep_0_to_1]
    rw [run_succ, registrationStep_1_to_2]
    -- ... (steps 2-7) ...
    rw [run_succ, registrationStep_7_to_8 h_oracle]
    rw [run_succ, registrationStep_8_to_12_failure]
    rw [run_succ, registrationStep_11_to_12]
    rw [run_succ, registrationStep_12_abort]
    rfl
```

---

### Recipe 4.3: Multi-Path Chain

**Goal:** Chain with multiple decision points.

**Pattern:** Several branches (e.g., deserialize can fail, verify can fail, balance check can fail).

**Solution:**

```lean
theorem multi_path_chain
    (h_deserialize : deserializeResult = ...)
    (h_verify : verifyResult = ...)
    (h_balance : balanceCheckResult = ...)
    : eval env (state 0 ...) cs ms = ... := by
  unfold eval
  cases deserializeResult with
  | success =>
    cases verifyResult with
    | success =>
      cases balanceCheckResult with
      | sufficient =>
        -- All checks pass: complete success path
        <chain to Ret>
      | insufficient =>
        -- Balance check fails: abort EINSUFFICIENT_BALANCE
        <chain to abort>
    | verifyFailed =>
      -- Verify fails: abort EVERIFY_FAILED
      <chain to abort>
  | error =>
    -- Deserialize fails: abort EINVALID_FORMAT
    <chain to abort>
```

**Example:**

```lean
theorem transfer_multi_path_eval
    (h_deserialize : deserializeResult = ...)
    (h_verify : verifyResult = ...)
    (h_balance : balanceCheckResult = ...)
    : eval env (transferState 0 ...) cs ms = ... := by
  unfold eval
  cases deserializeResult with
  | success =>
    cases verifyResult with
    | success =>
      cases balanceCheckResult with
      | sufficient =>
        -- Happy path
        rw [transferStep_0_to_1]
        -- ... (all steps to Ret) ...
        rfl
      | insufficient =>
        -- Balance check abort
        rw [transferStep_0_to_1]
        -- ... (steps to balance check) ...
        rw [transferStep_N_brFalse_to_abort]
        rw [transferStep_abort_insufficient_balance]
        rfl
    | verifyFailed =>
      -- Verify abort
      rw [transferStep_0_to_1]
      -- ... (steps to verify) ...
      rw [transferStep_M_brFalse_to_abort]
      rw [transferStep_abort_verify_failed]
      rfl
  | error =>
    -- Deserialize error
    rw [transferStep_0_to_deserialize_error]
    rfl
```

---

## 5. Oracle Handling Recipes

### Recipe 5.1: Oracle Hypothesis in Theorem

**Goal:** Use oracle result in theorem statement.

**Pattern:** Theorem proves behavior depends on oracle.

**Solution:**

```lean
theorem operation_with_oracle
    (h_oracle : env.oracle «function» args = result)
    : eval env (state 0 ...) cs ms = <depends on result> := by
  cases result with
  | case1 => <proof for case1 given h_oracle>
  | case2 => <proof for case2 given h_oracle>
```

**Example:**

```lean
theorem registration_depends_on_oracle
    (h_oracle : env.oracle «verify_registration_proof_native» proof = result)
    : eval env (registrationState 0 ref) cs ms =
        match result with
        | .success => .returned [.u64 0] ms
        | .verifyFailed => .aborted 65537 ms
  := by
  cases result with
  | success =>
    -- Use h_oracle in proof
    unfold eval
    -- ... (steps using h_oracle) ...
    rw [registrationStep_7_to_8 h_oracle]
    -- ... (continue) ...
  | verifyFailed =>
    unfold eval
    -- ... (steps using h_oracle) ...
    rw [registrationStep_7_to_8 h_oracle]
    -- ... (continue to abort) ...
```

---

### Recipe 5.2: Multiple Oracles

**Goal:** Handle multiple oracle calls in one operation.

**Pattern:** Deserialize oracle, verify oracle, etc.

**Solution:**

```lean
theorem operation_multiple_oracles
    (h_oracle1 : env.oracle «function1» args1 = result1)
    (h_oracle2 : env.oracle «function2» args2 = result2)
    : eval env (state 0 ...) cs ms = ... := by
  cases result1 with
  | success =>
    cases result2 with
    | success =>
      -- Both oracles succeed
      <chain using h_oracle1 and h_oracle2>
    | failed =>
      -- Second oracle fails
      <chain to abort>
  | failed =>
    -- First oracle fails
    <chain to abort>
```

**Example:**

```lean
theorem transfer_two_oracles
    (h_deserialize : env.oracle «deserialize_proof» bytes = deserializeResult)
    (h_verify : env.oracle «verify_proof» proof = verifyResult)
    : eval env (transferState 0 ...) cs ms = ... := by
  cases deserializeResult with
  | success proof =>
    cases verifyResult with
    | success =>
      -- Both succeed
      unfold eval
      rw [transferStep_deserialize h_deserialize]
      rw [transferStep_verify h_verify]
      -- ... (continue to success) ...
    | verifyFailed =>
      -- Verify fails
      rw [transferStep_deserialize h_deserialize]
      rw [transferStep_verify h_verify]
      -- ... (branch to abort) ...
  | error =>
    -- Deserialize fails
    rw [transferStep_deserialize_error h_deserialize]
    rfl
```

---

### Recipe 5.3: Oracle Axiom Usage

**Goal:** Use axiom about oracle correctness.

**Pattern:** Need to reason about oracle semantics (not just result).

**Solution:**

```lean
-- Axiom states oracle correctness
axiom verify_oracle_sound :
  ∀ proof,
    env.oracle «verify_proof» proof = .success →
    is_valid_proof proof

-- Use in theorem
theorem operation_ensures_valid_proof
    (h_oracle : env.oracle «verify_proof» proof = .success)
    : is_valid_proof proof := by
  apply verify_oracle_sound
  exact h_oracle
```

**Example:**

```lean
axiom verify_registration_oracle_sound :
  ∀ proof,
    env.oracle «verify_registration_proof_native» proof = .success →
    is_valid_registration_proof proof

theorem registration_success_implies_valid_proof
    (h_eval : eval env (registrationState 0 ref) cs ms = .returned [.u64 0] ms')
    : ∃ proof, is_valid_registration_proof proof := by
  -- Extract oracle result from eval
  have h_oracle : env.oracle «verify_registration_proof_native» proof = .success :=
    extract_oracle_from_eval h_eval
  -- Apply soundness axiom
  have h_valid : is_valid_registration_proof proof :=
    verify_registration_oracle_sound proof h_oracle
  exact ⟨proof, h_valid⟩
```

---

## 6. Arithmetic Recipes

### Recipe 6.1: Prove Arithmetic Equality

**Goal:** Prove `a + b - c = d` (linear arithmetic).

**Pattern:** Goal is arithmetic equation solvable by `omega` or `ring`.

**Solution:**

```lean
theorem my_arithmetic : a + b - c = d := by
  omega  -- For Nat arithmetic
  -- or
  ring   -- For ring arithmetic (Int, Real, etc.)
```

**Example:**

```lean
theorem balance_update_arithmetic
    (sender_balance : Nat)
    (amount : Nat)
    (h_sufficient : sender_balance ≥ amount)
    : (sender_balance - amount) + amount = sender_balance := by
  omega

theorem balance_preservation
    (initial_total : Nat)
    (amount : Nat)
    : (sender - amount) + (receiver + amount) = initial_total := by
  ring
```

**Variations:**

```lean
-- With hypotheses
theorem arithmetic_with_bounds
    (h1 : x > 0)
    (h2 : y < 100)
    : x + y < 101 := by
  omega

-- Nonlinear arithmetic (omega can't handle)
theorem nonlinear
    (h : x * y = z)
    : z / x = y := by
  sorry  -- Omega can't solve, need manual proof
  -- Try: field_simp, nlinarith, or manual steps
```

---

### Recipe 6.2: Prove Inequality

**Goal:** Prove `a < b` or `a ≤ b`.

**Pattern:** Inequality follows from hypotheses and linear reasoning.

**Solution:**

```lean
theorem my_inequality
    (h1 : a < c)
    (h2 : c ≤ b)
    : a < b := by
  omega
```

**Example:**

```lean
theorem balance_non_negative
    (balance : Nat)
    (h_valid : is_valid_balance balance)
    : balance ≥ 0 := by
  omega  -- Nat is always ≥ 0

theorem sufficient_balance_implies_valid_subtraction
    (balance : Nat)
    (amount : Nat)
    (h_sufficient : balance ≥ amount)
    : balance - amount ≥ 0 := by
  omega
```

---

### Recipe 6.3: Prove Modular Arithmetic

**Goal:** Prove properties involving `%` (mod).

**Pattern:** Modular arithmetic reasoning.

**Solution:**

```lean
theorem my_mod_property
    (h : x % n = r)
    : x = (x / n) * n + r := by
  have := Nat.div_add_mod x n
  rw [h] at this
  exact this.symm
```

**Example:**

```lean
theorem balance_commitment_mod
    (commitment : Nat)
    (h_commit : commitment = pedersen_commit balance r)
    : commitment % prime = pedersen_commit (balance % prime) r % prime := by
  rw [h_commit]
  apply pedersen_commit_mod_homomorphism
```

---

## 7. Debugging Recipes

### Recipe 7.1: Inspect Goal

**Goal:** Understand current proof state.

**Pattern:** Stuck, don't know what to prove.

**Solution:**

```lean
theorem my_theorem : P := by
  -- Show current goal
  trace "{goal}"
  
  -- Or in VS Code: hover over `by` to see goal
  
  sorry
```

**Example:**

```lean
theorem debug_step :
    step env (state pc locals) = ... := by
  unfold step
  rw [state_code]
  -- Hover here to see goal after rewrites
  trace "Current goal: {goal}"
  sorry
```

---

### Recipe 7.2: Check Hypothesis Type

**Goal:** Understand what a hypothesis says.

**Pattern:** Have hypothesis `h`, don't know its type.

**Solution:**

```lean
theorem my_theorem (h : <unknown type>) : P := by
  -- Check hypothesis type
  have : <expected type> := h
  -- If type mismatch, error message shows actual type
  
  sorry
```

**Example:**

```lean
theorem check_oracle_type
    (h_oracle : <what is this?>)
    : P := by
  -- Try to assign to known type
  have h_check : env.oracle «verify_proof» proof = .success := h_oracle
  -- If wrong, error shows actual type of h_oracle
  
  sorry
```

---

### Recipe 7.3: Reduce Goal to Simpler Form

**Goal:** Goal is too complex, want simpler subgoal.

**Pattern:** Use `suffices` to work backwards.

**Solution:**

```lean
theorem complex_goal : A := by
  suffices B from <proof that B implies A>
  -- Now prove simpler goal B
  <proof of B>
```

**Example:**

```lean
theorem complex_chain :
    eval env (state 0 ...) = .returned [] ms := by
  suffices run env (state 0 ...) N = .inProgress (state N ...) from
    <proof that this implies eval result>
  -- Now prove simpler run statement
  rw [run_succ, step_0_to_1]
  -- ... (easier to chain steps) ...
```

---

### Recipe 7.4: Split Complex Proof

**Goal:** Proof is very long, want to modularize.

**Pattern:** Extract lemmas for subparts.

**Solution:**

```lean
-- Extract lemma for subpart
theorem helper_lemma : <subgoal> := by
  <proof of subgoal>

-- Main theorem uses helper
theorem main_theorem : <complex goal> := by
  <some steps>
  apply helper_lemma
  <remaining steps>
```

**Example:**

```lean
-- Helper: chain first 10 steps
theorem registration_setup_chain :
    run env (registrationState 0 ref) 10 =
      .inProgress (registrationState 10 ref locals') := by
  rw [run_succ, registrationStep_0_to_1]
  -- ... (steps 1-10) ...
  rfl

-- Main theorem uses helper
theorem registration_eval_equiv :
    eval env (registrationState 0 ref) cs ms = ... := by
  unfold eval
  rw [registration_setup_chain]  -- Use helper for first 10 steps
  -- Continue from step 10
  rw [run_succ, registrationStep_10_to_11]
  -- ...
```

---

### Recipe 7.5: Try Automation Then Inspect Failure

**Goal:** Tactic fails, want to see why.

**Pattern:** `simp` or `omega` fails mysteriously.

**Solution:**

```lean
theorem my_theorem : P := by
  simp? only [lemma1, lemma2]
  -- simp? shows which lemmas it would use
  -- Helps diagnose why simp fails
  
  sorry
```

**Example:**

```lean
theorem step_lemma :
    step env (state pc locals) = .inProgress (state (pc+1) locals') := by
  unfold step
  simp? only [state_code, state_pc, code]
  -- Output shows which lemmas matched
  -- If doesn't solve goal, shows simplified goal
  
  sorry
```

---

## 8. Performance Recipes

### Recipe 8.1: Replace Bare `simp` with `simp only`

**Goal:** Speed up proof elaboration.

**Pattern:** Proof uses `simp` (slow, searches many lemmas).

**Solution:**

```lean
-- Before (slow)
theorem my_theorem : P := by
  simp
  
-- After (fast)
theorem my_theorem : P := by
  simp only [lemma1, lemma2, lemma3]
```

**Example:**

```lean
-- Before (slow, searches all simp lemmas)
theorem step_copyLoc :
    step env (state pc locals) = ... := by
  unfold step
  simp  -- Searches 1000+ simp lemmas
  
-- After (fast, only uses needed lemmas)
theorem step_copyLoc :
    step env (state pc locals) = ... := by
  unfold step
  simp only [state_code, state_pc, code_at_pc]  -- Only 3 lemmas
```

**How to find needed lemmas:**

```lean
-- Use simp? to see which lemmas are used
theorem my_theorem : P := by
  simp?
  -- Output: "Try this: simp only [lemma1, lemma2, lemma3]"
  
-- Replace simp with suggested simp only
```

---

### Recipe 8.2: Use `@[irreducible]` for Large Definitions

**Goal:** Prevent Lean from unfolding large definitions repeatedly.

**Pattern:** Definition is complex structure (Frame, State, etc.).

**Solution:**

```lean
-- Mark as irreducible
@[irreducible]
def myLargeDefinition : ComplexType := <large definition>

-- Provide simp lemmas for field access
@[simp]
theorem myLargeDefinition_field1 : myLargeDefinition.field1 = value1 := by
  unfold myLargeDefinition; rfl

@[simp]
theorem myLargeDefinition_field2 : myLargeDefinition.field2 = value2 := by
  unfold myLargeDefinition; rfl
```

**Example:**

```lean
-- State definition (irreducible for performance)
@[irreducible]
def registrationState (pc : Nat) (ref : Address) (locals : Locals) : Frame :=
  { code := verifyRegistrationProofCode,
    pc := pc,
    locals := locals,
    operandStack := [],
    frameId := ⟨0, by omega⟩,
    typeArgs := [],
    initialLocals := [...]
  }

-- Simp lemmas (O(1) field access)
@[simp]
theorem registrationState_pc : (registrationState pc ref locals).pc = pc := by
  unfold registrationState; rfl

@[simp]
theorem registrationState_code : (registrationState pc ref locals).code =
    verifyRegistrationProofCode := by
  unfold registrationState; rfl
```

**Performance gain:** 600× speedup (measured in CA verification).

---

### Recipe 8.3: Avoid Nested `unfold` in Large Proofs

**Goal:** Reduce elaboration time.

**Pattern:** Proof unfolds many definitions repeatedly.

**Solution:**

```lean
-- Before (slow, unfolds repeatedly)
theorem my_theorem : P := by
  unfold def1
  unfold def2
  unfold def3
  -- ... (100 more lines, each unfolds again) ...
  
-- After (fast, unfold once at top)
theorem my_theorem : P := by
  unfold def1 def2 def3  -- Unfold all at once
  -- ... (rest of proof uses folded forms) ...
  -- or
  show <explicitly simplified goal>
  <proof of simplified goal>
```

**Example:**

```lean
-- Before (slow)
theorem registration_chain :
    eval env (registrationState 0 ref) = ... := by
  unfold eval
  unfold registrationState  -- Unfolds large structure
  rw [step_0_to_1]
  unfold registrationState  -- Unfolds again!
  rw [step_1_to_2]
  unfold registrationState  -- Again!
  -- ... (100 more unfolds) ...
  
-- After (fast, use simp lemmas instead)
theorem registration_chain :
    eval env (registrationState 0 ref) = ... := by
  unfold eval
  rw [registrationStep_0_to_1]  -- Uses simp lemmas, no unfold
  rw [registrationStep_1_to_2]
  -- ... (no unfolds, uses registrationState_pc etc.) ...
```

---

**END OF COOKBOOK**

**Key takeaways:**

1. **Copy-paste recipes, adapt to your case** — don't start from scratch
2. **Step lemmas follow standard patterns** — CopyLoc, StLoc, Call, Branch
3. **PC-chaining is rewriting** — just `rw [step_N_to_N1]` repeatedly
4. **Oracle handling uses case splits** — `cases oracleResult with ...`
5. **Arithmetic uses `omega` or `ring`** — let automation solve equations
6. **Debug by inspecting goals** — `trace`, hover in VS Code
7. **Optimize with `simp only` and `@[irreducible]`** — massive speedup

**Next steps:**

- Practice recipes on simple theorems
- Use recipes as templates for CA proofs
- Add your own recipes as you discover patterns

**Questions?** See `LEAN_PROOF_TACTICS_REFERENCE.md` for complete tactics reference.
