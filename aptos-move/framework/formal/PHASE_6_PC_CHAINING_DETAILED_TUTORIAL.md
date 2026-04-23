# Phase 6 PC-Chaining Detailed Tutorial

**Audience:** Verification engineers implementing Phase 6 composition proofs  
**Prerequisites:** Completed Phase 4 (EvalEquiv proofs), understanding of Lean step lemmas  
**Related:** `LEAN_TACTICS_COOKBOOK.md`, `PROOF_AUTOMATION_FRAMEWORK_GUIDE.md`

## Purpose

This guide provides step-by-step tutorial for implementing PC-chaining proofs in Phase 6 composition theorems. Transforms `sorry` placeholders into complete proofs using the step-lemma library and `run` composition patterns.

## Table of Contents

1. [Phase 6 Overview](#phase-6-overview)
2. [PC-Chaining Architecture](#pc-chaining-architecture)
3. [Step-by-Step Tutorial](#step-by-step-tutorial)
4. [Common Patterns](#common-patterns)
5. [Debugging Techniques](#debugging-techniques)
6. [Optimization Strategies](#optimization-strategies)

---

## Phase 6 Overview

### What is Phase 6?

**Goal:** Prove that `eval` on entry-point bytecode equals functional simulation result

**Current status (per operation):**
- Registration: `registration_eval_equiv_functional_sim` — TEMPORARY AXIOM (needs singleton branch proof)
- Withdrawal: `withdrawal_eval_equiv_functional_sim` — theorem with `sorry` (needs PC-chaining)
- Transfer: `transfer_eval_equiv_functional_sim` — theorem with `sorry` (needs PC-chaining)
- Normalization: `normalization_eval_equiv_functional_sim` — theorem with `sorry` (needs PC-chaining)
- Rotation: `rotation_eval_equiv_functional_sim` — theorem with `sorry` (needs PC-chaining)

**Outstanding work:** 4 operations × ~200-450 lines each = 800-1800 lines total

**Estimated effort:** 23-32 hours (5-8 hours per operation)

### What is PC-Chaining?

**Definition:** Composing per-PC step lemmas through the `run` function to prove full execution trace

**Example (conceptual):**
```lean
-- Phase 4: Per-PC step lemmas (already complete)
theorem step_0 : step env (state 0) = .ok (state 1) := ...
theorem step_1 : step env (state 1) = .ok (state 2) := ...
theorem step_2 : step env (state 2) = .ok (state 3) := ...

-- Phase 6: Chain them via `run`
theorem chain_0_to_3 : run env (state 0) 3 = run env (state 3) 0 := by
  rw [run_succ_ok_of_step _ _ _ _ _ step_0]  -- Peel off step 0
  rw [run_succ_ok_of_step _ _ _ _ _ step_1]  -- Peel off step 1
  rw [run_succ_ok_of_step _ _ _ _ _ step_2]  -- Peel off step 2
  rfl  -- run 0 = result
```

**Why needed:** Phase 4 proves individual steps. Phase 6 proves the full sequence composes correctly.

---

## PC-Chaining Architecture

### Run Function (Recap)

**Definition:**
```lean
def run (env : ModuleEnv) (frame : Frame) (cs : List Frame) 
        (stack : List MoveValue) (ms : MachineState) : Nat → ExecResult
  | 0 => .error  -- Out of fuel
  | fuel + 1 =>
      match step env frame cs stack ms with
      | .ok frame' cs' stack' ms' => run env frame' cs' stack' ms' fuel
      | .error => .error
      | .aborted code => .aborted code
      | .returned results ms' => .returned results ms'
```

**Key insight:** `run (fuel + 1)` = `step` once, then `run fuel` on new state

### Step Lemma Library (Recap)

**Core lemmas (from `StepLemmas.Run`):**
```lean
-- When step returns .ok, peel it off and recurse
theorem run_succ_ok_of_step (fuel : Nat) (frame' : Frame) (cs' : List Frame)
    (stack' : List MoveValue) (ms' : MachineState)
    (hstep : step env frame cs stack ms = .ok frame' cs' stack' ms') :
    run env frame cs stack ms (fuel + 1) = run env frame' cs' stack' ms' fuel

-- When step returns .error, run stops
theorem run_succ_error_of_step (fuel : Nat)
    (hstep : step env frame cs stack ms = .error) :
    run env frame cs stack ms (fuel + 1) = .error

-- When step returns .aborted, run stops
theorem run_succ_aborted_of_step (fuel : Nat) (code : UInt64)
    (hstep : step env frame cs stack ms = .aborted code) :
    run env frame cs stack ms (fuel + 1) = .aborted code

-- When step returns .returned, run stops
theorem run_succ_returned_of_step (fuel : Nat) (results : List MoveValue) (ms' : MachineState)
    (hstep : step env frame cs stack ms = .returned results ms') :
    run env frame cs stack ms (fuel + 1) = .returned results ms'
```

**Usage:** Apply `run_succ_ok_of_step` repeatedly to peel off PCs one at a time

### Shape Lemmas (Recap)

**Purpose:** Reduce functional simulation to simple result shape

**Example (Withdrawal):**
```lean
-- Shape lemma: When oracle succeeds, functional sim returns []
theorem verifyWithdrawalBytecodeResult_success 
    (h : oracle.verifySigmaProof proof = .success) 
    (h2 : oracle.verifyRangeProof rangeProof = .success) :
    verifyWithdrawalBytecodeResult oracle args = .returned [] := by
  unfold verifyWithdrawalBytecodeResult
  rw [h, h2]
  rfl

-- Shape lemma: When oracle fails, functional sim aborts
theorem verifyWithdrawalBytecodeResult_failed
    (h : oracle.verifySigmaProof proof = .failed) :
    verifyWithdrawalBytecodeResult oracle args = .aborted ESIGMA_PROTOCOL_VERIFY_FAILED := by
  unfold verifyWithdrawalBytecodeResult
  rw [h]
  rfl
```

**Usage:** Match on oracle result, apply shape lemma to reduce RHS

---

## Step-by-Step Tutorial

### Tutorial: Implementing Withdrawal PC-Chaining

**Goal:** Complete `withdrawal_eval_equiv_functional_sim` theorem (currently `sorry`)

**Starting point (from `Withdrawal/Phase6Composition.lean`):**
```lean
theorem withdrawal_eval_equiv_functional_sim 
    (oracle : WithdrawalModuleOracle)
    (args : List MoveValue) 
    (fuel : Nat) 
    (hfuel : fuel ≥ 50) :
    (eval (withdrawalModuleEnv oracle) verifyWithdrawalProofIdx args fuel initMs).dropMs =
    verifyWithdrawalBytecodeResult oracle args := by
  -- TODO(Phase 6): Complete PC-chaining proof
  sorry
```

**Step 1: Unfold `eval` to `run`** (5 minutes)

```lean
theorem withdrawal_eval_equiv_functional_sim 
    (oracle : WithdrawalModuleOracle)
    (args : List MoveValue) 
    (fuel : Nat) 
    (hfuel : fuel ≥ 50) :
    (eval (withdrawalModuleEnv oracle) verifyWithdrawalProofIdx args fuel initMs).dropMs =
    verifyWithdrawalBytecodeResult oracle args := by
  -- Unfold eval to run on initial state
  unfold eval
  rw [eval_withdrawal_eq_run]  -- Lemma from Phase 4
  -- Now goal is: (run env (withdrawalState 0 args) fuel).dropMs = ...
  
  sorry
```

**What changed:** Goal now uses `run` instead of `eval` (simpler to work with)

**Step 2: Case-split on oracle results** (10 minutes)

```lean
theorem withdrawal_eval_equiv_functional_sim 
    (oracle : WithdrawalModuleOracle)
    (args : List MoveValue) 
    (fuel : Nat) 
    (hfuel : fuel ≥ 50) :
    (eval (withdrawalModuleEnv oracle) verifyWithdrawalProofIdx args fuel initMs).dropMs =
    verifyWithdrawalBytecodeResult oracle args := by
  unfold eval
  rw [eval_withdrawal_eq_run]
  
  -- Case-split on oracle results (2 oracles: sigma + range proof)
  match h1 : oracle.verifySigmaProof proof, h2 : oracle.verifyRangeProof rangeProof with
  | .success, .success =>
      -- Happy path: both oracles succeed
      sorry
  | .failed, _ =>
      -- Error path: sigma verification failed
      sorry
  | .error, _ =>
      -- Error path: sigma verification error
      sorry
  | .success, .failed =>
      -- Error path: range proof verification failed
      sorry
  | .success, .error =>
      -- Error path: range proof verification error
      sorry
```

**What changed:** 5 cases (happy path + 4 error paths)

**Step 3: Prove happy path (PC-chaining)** (2-3 hours)

```lean
  | .success, .success =>
      -- Apply shape lemma to RHS
      rw [verifyWithdrawalBytecodeResult_success h1 h2]
      -- Now goal is: (run ... fuel).dropMs = .returned []
      
      -- Peel off PCs 0-14 via step lemmas
      rw [run_succ_ok_of_step (fuel - 1) _ _ _ _ step_withdrawal_pc0]
      rw [run_succ_ok_of_step (fuel - 2) _ _ _ _ step_withdrawal_pc1]
      rw [run_succ_ok_of_step (fuel - 3) _ _ _ _ step_withdrawal_pc2]
      rw [run_succ_ok_of_step (fuel - 4) _ _ _ _ step_withdrawal_pc3]
      rw [run_succ_ok_of_step (fuel - 5) _ _ _ _ step_withdrawal_pc4]
      rw [run_succ_ok_of_step (fuel - 6) _ _ _ _ step_withdrawal_pc5]
      rw [run_succ_ok_of_step (fuel - 7) _ _ _ _ step_withdrawal_pc6]
      rw [run_succ_ok_of_step (fuel - 8) _ _ _ _ step_withdrawal_pc7]
      rw [run_succ_ok_of_step (fuel - 9) _ _ _ _ step_withdrawal_pc8]
      
      -- PC 9 is first oracle call (sigma proof)
      rw [step_withdrawal_pc9_some h1]  -- Oracle succeeds, step returns .ok
      rw [run_succ_ok_of_step (fuel - 10) _ _ _ _ _]
      
      rw [run_succ_ok_of_step (fuel - 11) _ _ _ _ step_withdrawal_pc10]
      rw [run_succ_ok_of_step (fuel - 12) _ _ _ _ step_withdrawal_pc11]
      rw [run_succ_ok_of_step (fuel - 13) _ _ _ _ step_withdrawal_pc12]
      
      -- PC 13 is second oracle call (range proof)
      rw [step_withdrawal_pc13_some h2]  -- Oracle succeeds, step returns .ok
      rw [run_succ_ok_of_step (fuel - 14) _ _ _ _ _]
      
      -- PC 14 is final (ret)
      rw [step_withdrawal_pc14]
      -- Step returns .returned [], so run stops
      rw [run_succ_returned_of_step]
      
      -- Now goal is: (.returned []).dropMs = .returned []
      rfl
```

**What changed:** Complete PC-chaining proof for happy path (15 PCs)

**Step 4: Prove error paths** (1-2 hours total)

```lean
  | .failed, _ =>
      -- Sigma verification failed → aborts at PC 9
      rw [verifyWithdrawalBytecodeResult_failed h1]
      -- Now goal is: (run ... fuel).dropMs = .aborted ESIGMA_PROTOCOL_VERIFY_FAILED
      
      -- Peel off PCs 0-8
      rw [run_succ_ok_of_step (fuel - 1) _ _ _ _ step_withdrawal_pc0]
      rw [run_succ_ok_of_step (fuel - 2) _ _ _ _ step_withdrawal_pc1]
      rw [run_succ_ok_of_step (fuel - 3) _ _ _ _ step_withdrawal_pc2]
      rw [run_succ_ok_of_step (fuel - 4) _ _ _ _ step_withdrawal_pc3]
      rw [run_succ_ok_of_step (fuel - 5) _ _ _ _ step_withdrawal_pc4]
      rw [run_succ_ok_of_step (fuel - 6) _ _ _ _ step_withdrawal_pc5]
      rw [run_succ_ok_of_step (fuel - 7) _ _ _ _ step_withdrawal_pc6]
      rw [run_succ_ok_of_step (fuel - 8) _ _ _ _ step_withdrawal_pc7]
      rw [run_succ_ok_of_step (fuel - 9) _ _ _ _ step_withdrawal_pc8]
      
      -- PC 9 oracle call fails → aborts
      rw [step_withdrawal_pc9_failed h1]
      -- Step returns .aborted, so run stops
      rw [run_succ_aborted_of_step]
      
      -- Now goal is: (.aborted ESIGMA_PROTOCOL_VERIFY_FAILED).dropMs = .aborted ...
      rfl
  
  | .error, _ =>
      -- Sigma verification error → .error at PC 9
      rw [verifyWithdrawalBytecodeResult_error h1]
      
      -- Peel off PCs 0-8 (same as above)
      rw [run_succ_ok_of_step (fuel - 1) _ _ _ _ step_withdrawal_pc0]
      -- ... (8 more PCs)
      rw [run_succ_ok_of_step (fuel - 9) _ _ _ _ step_withdrawal_pc8]
      
      -- PC 9 oracle call errors → .error
      rw [step_withdrawal_pc9_error h1]
      rw [run_succ_error_of_step]
      rfl
  
  | .success, .failed =>
      -- Range proof verification failed → aborts at PC 13
      rw [verifyWithdrawalBytecodeResult_rangeProofFailed h2]
      
      -- Peel off PCs 0-12 (includes successful sigma verification at PC 9)
      rw [run_succ_ok_of_step (fuel - 1) _ _ _ _ step_withdrawal_pc0]
      -- ... (8 more PCs)
      rw [run_succ_ok_of_step (fuel - 10) _ _ _ _ step_withdrawal_pc9_some h1]
      rw [run_succ_ok_of_step (fuel - 11) _ _ _ _ step_withdrawal_pc10]
      rw [run_succ_ok_of_step (fuel - 12) _ _ _ _ step_withdrawal_pc11]
      rw [run_succ_ok_of_step (fuel - 13) _ _ _ _ step_withdrawal_pc12]
      
      -- PC 13 oracle call fails → aborts
      rw [step_withdrawal_pc13_failed h2]
      rw [run_succ_aborted_of_step]
      rfl
  
  | .success, .error =>
      -- Range proof verification error → .error at PC 13
      rw [verifyWithdrawalBytecodeResult_rangeProofError h2]
      
      -- Peel off PCs 0-12
      rw [run_succ_ok_of_step (fuel - 1) _ _ _ _ step_withdrawal_pc0]
      -- ... (11 more PCs)
      rw [run_succ_ok_of_step (fuel - 13) _ _ _ _ step_withdrawal_pc12]
      
      -- PC 13 oracle call errors → .error
      rw [step_withdrawal_pc13_error h2]
      rw [run_succ_error_of_step]
      rfl
```

**What changed:** All 5 cases complete, no more `sorry`

**Total time:** ~3-4 hours (including debugging, fixing typos, running `lake build`)

**Final proof:** ~150-200 lines

---

## Common Patterns

### Pattern 1: Straight-Line Code (No Branches)

**Scenario:** Operations with no conditional branches (e.g., Normalization before any oracle calls)

**Pattern:**
```lean
theorem chain_straight_line : run env (state 0) N = ... := by
  rw [run_succ_ok_of_step _ _ _ _ _ step_0]
  rw [run_succ_ok_of_step _ _ _ _ _ step_1]
  rw [run_succ_ok_of_step _ _ _ _ _ step_2]
  -- ... N times ...
  rfl
```

**Optimization:** Use multi-step lemmas to reduce boilerplate:
```lean
theorem chain_0_to_10 : run env (state 0) 10 = run env (state 10) 0 := by
  repeat { rw [run_succ_ok_of_step]; try { apply step_pc_next } }
  rfl
```

### Pattern 2: Oracle Call (Happy Path)

**Scenario:** PC N calls oracle, oracle succeeds

**Pattern:**
```lean
-- Peel off PCs before oracle call
rw [run_succ_ok_of_step _ _ _ _ _ step_0]
-- ... up to PC N-1 ...
rw [run_succ_ok_of_step _ _ _ _ _ step_N_minus_1]

-- Oracle call at PC N (oracle succeeds)
rw [step_pcN_some h_oracle_success]  -- h_oracle_success : oracle.verify ... = .success

-- Continue after oracle call
rw [run_succ_ok_of_step _ _ _ _ _ step_N_plus_1]
-- ... rest of PCs ...
```

**Key:** Use `step_pcN_some` variant (oracle succeeds → step returns `.ok`)

### Pattern 3: Oracle Call (Error Path)

**Scenario:** PC N calls oracle, oracle fails → abort

**Pattern:**
```lean
-- Peel off PCs before oracle call (same as happy path)
rw [run_succ_ok_of_step _ _ _ _ _ step_0]
-- ... up to PC N-1 ...

-- Oracle call at PC N (oracle fails)
rw [step_pcN_failed h_oracle_failed]  -- h_oracle_failed : oracle.verify ... = .failed

-- Step returns .aborted, run stops
rw [run_succ_aborted_of_step]

-- Goal now: (.aborted CODE).dropMs = .aborted CODE
rfl
```

**Key:** Use `step_pcN_failed` variant (oracle fails → step returns `.aborted`)

### Pattern 4: Multiple Oracle Calls

**Scenario:** Operation calls 2+ oracles (e.g., Transfer: sigma + 2 range proofs)

**Pattern:**
```lean
-- Case-split on ALL oracle results
match h1 : oracle.verifySigma ..., h2 : oracle.verifyRange1 ..., h3 : oracle.verifyRange2 ... with
| .success, .success, .success =>
    -- Happy path: all 3 succeed
    -- Peel PCs up to first oracle
    rw [run_succ_ok_of_step _ _ _ _ _ step_0]
    -- ...
    rw [step_pcN_some h1]  -- First oracle succeeds
    
    -- Peel PCs between first and second oracle
    rw [run_succ_ok_of_step _ _ _ _ _ step_N_plus_1]
    -- ...
    rw [step_pcM_some h2]  -- Second oracle succeeds
    
    -- Peel PCs between second and third oracle
    rw [run_succ_ok_of_step _ _ _ _ _ step_M_plus_1]
    -- ...
    rw [step_pcK_some h3]  -- Third oracle succeeds
    
    -- Finish
    rw [run_succ_ok_of_step _ _ _ _ _ step_K_plus_1]
    -- ... to ret
    rfl

| .failed, _, _ =>
    -- First oracle failed → abort early (don't reach second/third oracles)
    -- ... peel to first oracle, abort ...
| .success, .failed, _ =>
    -- Second oracle failed → abort after first succeeds
    -- ... peel through first oracle, to second oracle, abort ...
| .success, .success, .failed =>
    -- Third oracle failed → abort after first two succeed
    -- ... peel through first two oracles, to third oracle, abort ...
-- ... other error cases (8 total for 3 oracles: 2^3) ...
```

**Key:** 2^N cases for N oracles (exponential!) — consider grouping error paths

### Pattern 5: Conditional Branch (if/else)

**Scenario:** Bytecode has `brFalse` (conditional branch)

**Pattern:**
```lean
-- Assume condition is true (branch not taken)
theorem chain_branch_not_taken (hcond : condition = true) : ... := by
  rw [run_succ_ok_of_step _ _ _ _ _ step_before_branch]
  
  -- brFalse PC: condition true → fall through (PC+1)
  rw [step_brFalse_notTaken hcond]
  rw [run_succ_ok_of_step _ _ _ _ _ step_after_branch]
  -- ... continue on fall-through path ...
  rfl

-- Assume condition is false (branch taken)
theorem chain_branch_taken (hcond : condition = false) : ... := by
  rw [run_succ_ok_of_step _ _ _ _ _ step_before_branch]
  
  -- brFalse PC: condition false → jump to target
  rw [step_brFalse_taken hcond]
  rw [run_succ_ok_of_step _ _ _ _ _ step_at_target]
  -- ... continue on branch-taken path ...
  rfl
```

**Key:** Two separate theorems, one per branch outcome

---

## Debugging Techniques

### Technique 1: Incremental Verification

**Problem:** Proof fails after 50 `rw` lines, hard to find error

**Solution:** Verify incrementally (check goal after each `rw`)

```lean
theorem chain_incremental : run env (state 0) 50 = ... := by
  rw [run_succ_ok_of_step _ _ _ _ _ step_0]
  -- Check goal now (Ctrl+Shift+Enter in VS Code)
  -- Goal should be: run env (state 1) 49 = ...
  
  rw [run_succ_ok_of_step _ _ _ _ _ step_1]
  -- Check goal now
  -- Goal should be: run env (state 2) 48 = ...
  
  -- ... continue ...
```

**Why:** Catches errors early (know exactly which `rw` broke)

### Technique 2: Explicit Intermediate States

**Problem:** Lean can't infer intermediate states (too many underscores `_`)

**Solution:** Explicitly name intermediate states

```lean
-- BAD (too implicit):
rw [run_succ_ok_of_step _ _ _ _ _ step_0]
rw [run_succ_ok_of_step _ _ _ _ _ step_1]
-- Lean struggles to infer all underscores

-- GOOD (explicit states):
rw [run_succ_ok_of_step (fuel - 1) (state 1) [] [] MachineState.empty step_0]
rw [run_succ_ok_of_step (fuel - 2) (state 2) [] [] MachineState.empty step_1]
-- Lean knows exactly what's happening
```

**Trade-off:** More verbose, but easier to debug

### Technique 3: Simplify Goal Before Matching

**Problem:** Goal too complex to read after 20 `rw` lines

**Solution:** Use `simp only` to normalize goal

```lean
rw [run_succ_ok_of_step _ _ _ _ _ step_0]
rw [run_succ_ok_of_step _ _ _ _ _ step_1]
-- ... 10 more ...

simp only [dropMs, ExecResult.dropMs]  -- Simplify goal
-- Now goal is readable again

-- Continue
rw [run_succ_ok_of_step _ _ _ _ _ step_12]
-- ...
```

**Why:** Keeps goal manageable, easier to spot errors

### Technique 4: Check Step Lemma Statements

**Problem:** `rw [step_N]` fails with "type mismatch"

**Diagnosis:** Step lemma statement doesn't match current goal

**Solution:**
```lean
-- Check step lemma statement
#check step_withdrawal_pc9_some
-- Expected: ∀ (h : oracle.verifySigmaProof ... = .success), 
--             step env (state 9) = .ok (state 10)

-- Check current goal (hover in VS Code)
-- Goal: step env (state 9) = ...

-- If mismatch: either
--   1. Wrong step lemma (use step_pc10 instead of step_pc9?)
--   2. Goal state wrong (should be state 8, not state 9?)
```

**Fix:** Use correct step lemma or fix preceding `rw` lines

### Technique 5: Profile Slow Proofs

**Problem:** Proof takes >10 seconds to compile

**Diagnosis:** Expensive `rw` or `simp`

**Solution:**
```lean
set_option profiler true

theorem slow_chain : ... := by
  rw [run_succ_ok_of_step _ _ _ _ _ step_0]  -- Check profiler output
  -- If this line takes >1s, investigate step_0
  
  rw [run_succ_ok_of_step _ _ _ _ _ step_1]
  -- ... find the slow line ...
```

**Fix:** Replace slow `rw` with `simp only [step_N, state_pc, ...]` (more explicit, faster)

---

## Optimization Strategies

### Strategy 1: Bundle Straight-Line Sequences

**Before (50 lines, repetitive):**
```lean
rw [run_succ_ok_of_step _ _ _ _ _ step_0]
rw [run_succ_ok_of_step _ _ _ _ _ step_1]
-- ... 48 more lines ...
rw [run_succ_ok_of_step _ _ _ _ _ step_49]
```

**After (5 lines, bundled):**
```lean
theorem chain_0_to_49 : run env (state 0) 50 = run env (state 50) 0 := by
  repeat (rw [run_succ_ok_of_step]; try { apply step_pc_next })
  rfl

-- Use in main proof:
rw [chain_0_to_49]
```

**Speedup:** 10× fewer lines, clearer intent

### Strategy 2: Precompute Oracle Case Splits

**Before (100 lines per case):**
```lean
match h1 : oracle.verify1, h2 : oracle.verify2 with
| .success, .success =>
    -- 100 lines of PC-chaining
| .failed, _ =>
    -- 100 lines of PC-chaining (mostly duplicated)
| ...
```

**After (helper lemmas):**
```lean
-- Helper: PC-chaining up to first oracle
theorem chain_0_to_firstOracle : run env (state 0) 10 = run env (state 10) 0 := by
  -- ... 10 PCs ...
  rfl

-- Main proof uses helper:
match h1 : oracle.verify1, h2 : oracle.verify2 with
| .success, .success =>
    rw [chain_0_to_firstOracle]  -- Reuse
    -- ... only PCs after first oracle (shorter)
| .failed, _ =>
    rw [chain_0_to_firstOracle]  -- Reuse
    -- ... abort at first oracle (even shorter)
```

**Speedup:** Reduces duplication, easier to maintain

### Strategy 3: Use `run_succ_N_ok` Multi-Step Lemmas

**Before (5 lines for 5 PCs):**
```lean
rw [run_succ_ok_of_step _ _ _ _ _ step_0]
rw [run_succ_ok_of_step _ _ _ _ _ step_1]
rw [run_succ_ok_of_step _ _ _ _ _ step_2]
rw [run_succ_ok_of_step _ _ _ _ _ step_3]
rw [run_succ_ok_of_step _ _ _ _ _ step_4]
```

**After (1 line with multi-step lemma):**
```lean
rw [run_succ_five_ok step_0 step_1 step_2 step_3 step_4]
```

**Where `run_succ_five_ok` is:**
```lean
theorem run_succ_five_ok 
    (h0 : step env (state 0) = .ok (state 1))
    (h1 : step env (state 1) = .ok (state 2))
    (h2 : step env (state 2) = .ok (state 3))
    (h3 : step env (state 3) = .ok (state 4))
    (h4 : step env (state 4) = .ok (state 5)) :
    run env (state 0) (fuel + 5) = run env (state 5) fuel := by
  rw [run_succ_ok_of_step _ _ _ _ _ h0]
  rw [run_succ_ok_of_step _ _ _ _ _ h1]
  rw [run_succ_ok_of_step _ _ _ _ _ h2]
  rw [run_succ_ok_of_step _ _ _ _ _ h3]
  rw [run_succ_ok_of_step _ _ _ _ _ h4]
```

**Speedup:** 5× fewer lines, clearer (group of 5 PCs = 1 logical unit)

### Strategy 4: Parallel Proof Development

**Scenario:** 4 operations to prove (Withdrawal, Transfer, Normalization, Rotation)

**Sequential (slow):** 1 person × 4 ops × 5 hours = 20 hours

**Parallel (fast):** 4 people × 1 op × 5 hours = 5 hours (wall-clock)

**Process:**
1. Assign one operation per engineer
2. Each engineer proves their operation independently
3. Share helper lemmas (e.g., `chain_0_to_10` if common)
4. Code review each other's proofs

**Speedup:** 4× wall-clock time (if 4 engineers available)

---

## Related Guides

- [LEAN_TACTICS_COOKBOOK.md](LEAN_TACTICS_COOKBOOK.md) — Tactic recipes
- [PROOF_AUTOMATION_FRAMEWORK_GUIDE.md](PROOF_AUTOMATION_FRAMEWORK_GUIDE.md) — Automation strategies
- [LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md](LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md) — Performance tips
- [BYTECODE_TRANSCRIPTION_WORKFLOW_GUIDE.md](BYTECODE_TRANSCRIPTION_WORKFLOW_GUIDE.md) — Phase 4 workflow

---

**Document Status:** v1.0 (2026-04-22)  
**Maintainer:** Verification team  
**Last Updated:** 2026-04-22  
**Next Review:** After Phase 6 completion

**Key Takeaway:** PC-chaining is systematic: (1) unfold eval → run, (2) case-split on oracles, (3) peel PCs one-by-one via `run_succ_ok_of_step`, (4) stop at abort/return. Estimate 3-4 hours per operation × 4 operations = 12-16 hours total for Phase 6 completion. Use bundling and multi-step lemmas to reduce proof size. Verify incrementally to catch errors early.
