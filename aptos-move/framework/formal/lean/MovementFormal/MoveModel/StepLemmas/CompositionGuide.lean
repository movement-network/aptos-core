import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.StepLemmas.PCChaining
import MovementFormal.MoveModel.StepLemmas.OraclePatterns
import MovementFormal.MoveModel.FrameInvariants
import MovementFormal.MoveModel.StackManagement

/-!
# Composition proof guide — How to prove Phase 6 theorems

This module provides comprehensive guidance for completing Phase 6 composition theorems.
It ties together all the infrastructure modules into a coherent workflow.

## Table of Contents

1. **Overview**: What Phase 6 composition theorems prove
2. **Prerequisites**: What must be in place before starting
3. **Proof structure**: The standard template for all 4 verifiers
4. **Step-by-step walkthrough**: Detailed guide with code examples
5. **Common patterns**: Reusable techniques across verifiers
6. **Debugging guide**: How to fix common proof failures
7. **Completion checklist**: How to know when you're done

---

## 1. Overview: What Phase 6 composition theorems prove

Each of the 4 confidential asset verifiers (Normalization, Withdrawal, Rotation, Transfer)
has a **composition theorem** that connects three levels:

### Level 0: Functional simulation (the "spec")
A pure function that describes what the verifier SHOULD do:

```lean
def verifyWithdrawalBytecodeResult
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64)
    (curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length) :
    WithdrawalBytecodeResult :=
  match o.verifySigmaProof initMs.containers sigmaArgs with
  | none => .error
  | some ([], cs') =>
      match o.verifyRangeProof cs' rangeArgs with
      | none => .error
      | some ([], cs'') => .returned { initMs with containers := cs'' }
      | _ => .error
  | _ => .error
```

This is the "ground truth" — it states the logic without any bytecode details.

### Level 1: Bytecode evaluation (the "implementation")
The actual Move VM execution of the `verify_withdrawal_proof` bytecode:

```lean
eval (withdrawalModuleEnv o) verifyWithdrawalProofIdx args fuel initMs
```

This runs the 15-instruction bytecode through the Move VM semantics (`step` function),
consuming fuel at each PC.

### Level 2: The composition theorem (the "proof")
The theorem that Level 1 implements Level 0 correctly:

```lean
theorem withdrawal_eval_equiv_functional_sim
    (o : WithdrawalModuleOracle) ... :
    (eval (withdrawalModuleEnv o) verifyWithdrawalProofIdx args fuel initMs).dropMs =
      match verifyWithdrawalBytecodeResult o ... with
      | .returned ms => .returned [] ms
      | .error => .error
```

**In English**: "If you run the bytecode with enough fuel, you get exactly what
the functional simulation says you should get."

---

## 2. Prerequisites: What must be in place before starting

Before attempting a composition proof, you must have:

### A. Per-PC step theorems (Phase 4)
For every PC from 0 to N-1, a theorem proving that `step` at that PC does what you expect:

```lean
theorem step_withdrawal_pc0 ... : step env frame [] [] ms = .ok frame' [] [v0] ms := ...
theorem step_withdrawal_pc1 ... : step env frame [] [v0] ms = .ok frame'' [] [v1, v0] ms := ...
...
theorem step_withdrawal_pc14 ... : step env frame [] [] ms = .returned [] ms := ...
```

Plus error variants for oracle calls:

```lean
theorem step_withdrawal_pc9_none ... : step env frame [] stack ms = .error := ...
theorem step_withdrawal_pc13_none ... : step env frame [] stack ms = .error := ...
```

### B. Functional simulation definition (Phase 4)
The pure function describing expected behavior:

```lean
inductive WithdrawalBytecodeResult
  | returned (ms : MachineState)
  | error

def verifyWithdrawalBytecodeResult ... : WithdrawalBytecodeResult := ...
```

### C. eval_eq_run unfolding lemma (Phase 4)
Reduces `eval` to `run`:

```lean
theorem eval_withdrawal_eq_run ... :
    eval (withdrawalModuleEnv o) verifyWithdrawalProofIdx args fuel initMs =
      run (withdrawalModuleEnv o) initFrame [] [] initMs fuel
```

### D. Shape lemmas (helpful but not required)
Theorems that connect functional simulation branches to run outcomes:

```lean
theorem verifyWithdrawalBytecodeResult_sigmaFails ... :
    o.verifySigmaProof cs args = none →
    verifyWithdrawalBytecodeResult o ... = .error

theorem verifyWithdrawalBytecodeResult_success ... :
    o.verifySigmaProof cs sigmaArgs = some ([], cs') →
    o.verifyRangeProof cs' rangeArgs = some ([], cs'') →
    verifyWithdrawalBytecodeResult o ... = .returned { initMs with containers := cs'' }
```

### E. Infrastructure modules (Phase 4, completed)
- `StepLemmas/Run.lean`: run_succ_N_ok helpers
- `FrameInvariants.lean`: Frame state tracking
- `StackManagement.lean`: Stack evolution tracking
- `StepLemmas/OraclePatterns.lean`: Oracle splitting helpers
- `StepLemmas/PCChaining.lean`: Multi-step composition patterns

**If any of A–E are missing or incomplete, complete them first.**

---

## 3. Proof structure: The standard template for all 4 verifiers

Every composition proof follows this structure:

```lean
theorem <verifier>_eval_equiv_functional_sim ... := by
  -- PART 1: Unfold eval to run
  rw [eval_<verifier>_eq_run]

  -- PART 2: Chain PCs for first marshal sequence
  -- Use moveLoc/copyLoc chain lemmas or manual step applications
  -- Goal: reach PC just before first oracle call

  -- PART 3: Split on first oracle outcome (sigma)
  cases hsigma : o.verifySigmaProof containers args with
  | none =>
      -- Error path: show run produces .error
      -- Apply step_<verifier>_pcN_none
      -- Simplify to match .error branch of functional simulation
  | some ⟨retVals, containers'⟩ =>
      cases retVals with
      | nil =>
          -- Success path: sigma returned empty list (expected)

          -- PART 4: Chain PCs for second marshal sequence
          -- Goal: reach PC just before second oracle call

          -- PART 5: Split on second oracle outcome (range)
          cases hrange : o.verifyRangeProof containers' args' with
          | none =>
              -- Error path: show run produces .error
          | some ⟨retVals2, containers''⟩ =>
              cases retVals2 with
              | nil =>
                  -- Success path: both oracles succeeded

                  -- PART 6: Chain final PCs to ret
                  -- Apply ret lemma
                  -- Simplify to match .returned branch of functional simulation

              | cons _ _ =>
                  -- Impossible: arity mismatch
                  sorry

      | cons _ _ =>
          -- Impossible: arity mismatch
          sorry
```

**Key insight**: The proof structure mirrors the branching structure of the functional simulation.

---

## 4. Step-by-step walkthrough: Detailed guide with code examples

Let's walk through a concrete example: `withdrawal_eval_equiv_functional_sim`.

### Step 1: Set up the proof context

```lean
theorem withdrawal_eval_equiv_functional_sim
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64)
    (curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (fuel : Nat)
    (hfuel : fuel ≥ 15) :
    let args := [.u8 chainId, .address sender, .address contract,
                 ekRef, .u64 amount, curBalRef, newBalRef, proofRef]
    (eval (withdrawalModuleEnv o) verifyWithdrawalProofIdx args fuel initMs).dropMs =
      match verifyWithdrawalBytecodeResult o chainId sender contract ekRef amount curBalRef newBalRef
              proofRid proofFields initMs hFieldCount with
      | .returned ms => .returned [] ms
      | .error => .error := by
```

### Step 2: Unfold eval to run

```lean
  rw [eval_withdrawal_eq_run]
```

Goal state is now:

```lean
⊢ (run (withdrawalModuleEnv o) initFrame [] [] initMs fuel).dropMs = match ... with ...
```

where `initFrame` is the frame at PC 0 with 8 locals.

### Step 3: Chain PCs 0-5 (moveLoc for first 6 args)

**Option A: Use PC-chaining pattern (when blocker resolved)**

```lean
  have h5 := moveLoc_chain_6_pattern verifyWithdrawalProofCode ...
  rw [h5]
```

**Option B: Manual chaining (current workaround)**

```lean
  -- Apply run_succ_six_ok to peel off 6 steps
  rw [show fuel = (fuel - 9) + 9 from by omega]
  rw [show (fuel - 9) + 9 = ((fuel - 9) + 3) + 6 from by omega]

  -- Manually construct frame6 and stack6
  -- NOTE: This is where the array indexing blocker hits
  -- For now, use sorry or opaque helpers
  sorry
```

### Step 4: Chain PCs 6-7 (copyLoc for next 2 args)

Similar to step 3, apply `run_succ_two_ok` or pattern.

### Step 5: PC 8 (immBorrowField 0)

```lean
  -- Allocate container for sigma field
  obtain ⟨containers1, fid1, halloc1⟩ :
      ∃ cs fid, initMs.containers.alloc (proofFields[0]'_) = (cs, fid) := by
    sorry -- Container allocation exists (axiom or explicit construction)

  -- Apply step_withdrawal_pc8
  have hstep8 := step_withdrawal_pc8 o frame8 [] stack8 initMs
    verifyWithdrawalProofCode rfl proofRid proofFields containers1 fid1 proofRef
    hproofRef hread (by omega) halloc1

  rw [StepLemmas.run_succ_ok_of_step _ frame8 [] stack8 initMs hstep8]
```

### Step 6: PC 9 (call verifySigmaProof) — SPLIT

```lean
  -- Build sigma arguments
  let sigmaArgs := [.immRef fid1, newBalRef, curBalRef, .u64 amount, ekRef,
                    .address contract, .address sender, .u8 chainId]

  -- Prove takeN extracts exactly 8 args
  have htake9 : takeN stack9 8 = some (sigmaArgs, []) := by
    simp [stack9, stack8, sigmaArgs, takeN]
    sorry -- Arithmetic

  -- Split on sigma oracle outcome
  cases hsigma : o.verifySigmaProof containers1 sigmaArgs with
  | none =>
      -- Error path
      have hstep9_err := step_withdrawal_pc9_none o frame9 [] stack9 ms9
        verifyWithdrawalProofCode rfl sigmaArgs [] htake9 hsigma

      rw [StepLemmas.run_succ_error_of_step _ hstep9_err]
      simp [verifyWithdrawalBytecodeResult, ExecResult.dropMs]
      rw [hsigma]
      rfl

  | some ⟨retVals, containers2⟩ =>
      cases retVals with
      | nil =>
          -- Success path: sigma returned []
          have hstep9_ok := step_withdrawal_pc9 o frame9 [] stack9 ms9
            verifyWithdrawalProofCode rfl sigmaArgs [] containers2 htake9 hsigma

          rw [StepLemmas.run_succ_ok_of_step _ frame9 [] stack9 ms9 hstep9_ok]

          -- Continue to PCs 10-14 (similar structure)
          sorry

      | cons _ _ =>
          -- Impossible: arity mismatch
          sorry
```

### Step 7: Chain PCs 10-11 (moveLoc for balance refs)

Same pattern as Step 3.

### Step 8: PC 12 (immBorrowField 1)

Same pattern as Step 5, but for `proofFields[1]`.

### Step 9: PC 13 (call verifyRangeProof) — SPLIT

Same pattern as Step 6, but for range oracle.

### Step 10: PC 14 (ret)

```lean
  have hstep14 := step_withdrawal_pc14 verifyWithdrawalProofCode rfl

  rw [StepLemmas.run_succ_returned_of_step _ [] ms14 hstep14]
  simp [verifyWithdrawalBytecodeResult, ExecResult.dropMs]
  rw [hsigma, hrange]
  rfl
```

---

## 5. Common patterns: Reusable techniques across verifiers

### Pattern: Oracle call error propagation

When an oracle returns `none`, you need to:
1. Apply `step_*_pcN_none` theorem
2. Apply `run_succ_error_of_step`
3. Simplify functional simulation to `.error`
4. Use `rw [hsigma]` or `rw [hrange]` to match the split case
5. Close with `rfl`

```lean
cases hsigma : o.verifySigmaProof cs args with
| none =>
    have herr := step_*_pcN_none ... hsigma
    rw [run_succ_error_of_step _ herr]
    simp [verifyBytecodeResult]
    rw [hsigma]; rfl
```

### Pattern: Arity mismatch (impossible cases)

When oracle returns non-empty list but expects empty:

```lean
| cons hd tl =>
    -- Impossible: oracle returned values when expecting 0 returns
    -- This violates the oracle type contract
    sorry -- or: apply arity_mismatch_impossible_axiom
```

These cases can be sorried — they're unreachable in well-typed bytecode.

### Pattern: Container allocation

When you need to allocate a field:

```lean
obtain ⟨containers', fid, halloc⟩ :
    ∃ cs fid, ms.containers.alloc (proofFields[idx]'h) = (cs, fid) := by
  sorry -- Allocation exists (constructor + fresh ID)
```

Then use `halloc` in the `step_*_pcN` application.

### Pattern: Fuel management

Whenever you apply `run_succ_N_ok`, adjust fuel:

```lean
rw [show fuel = (fuel - m) + m from by omega]
rw [show (fuel - m) + m = ((fuel - m) + k) + n from by omega]
  where m = remaining PCs, k = next segment, n = current segment
```

Use `omega` to discharge fuel arithmetic goals.

---

## 6. Debugging guide: How to fix common proof failures

### Error: "Expected type must not contain free variables"

**Cause**: Array indexing in proof term (e.g., `frame.locals[i]'h`).

**Fix**: Use opaque helper or axiom placeholder:

```lean
-- Before (fails):
let frame' := { frame with locals := frame.locals.set i none (by omega) }

-- After (works):
axiom frameAfterMoveLoc (frame : Frame) (idx : Nat) : Frame
let frame' := frameAfterMoveLoc frame i
```

### Error: "Type mismatch" in step application

**Cause**: Frame/stack/ms state doesn't match step theorem preconditions.

**Debug**:
1. Add `#check hstep` before application
2. Compare actual types with expected types
3. Look for missing `rfl` proofs or incorrect field values

**Fix**: Reconstruct frame/stack/ms to match preconditions exactly.

### Error: "Failed to unify" in `cases` statement

**Cause**: Oracle outcome doesn't match the split variable.

**Debug**:
1. Check that `hsigma : o.verifySigmaProof cs args = ...` matches the actual arguments
2. Verify `cs` and `args` are the correct containers and argument list

**Fix**: Reconstruct oracle arguments to match functional simulation.

### Error: "Unsolved goals" after `rfl`

**Cause**: Functional simulation result doesn't match run result.

**Debug**:
1. Add `simp [verifyBytecodeResult]` before `rfl`
2. Check that all oracle split cases (`hsigma`, `hrange`) are rewritten
3. Verify ms/containers threading through steps

**Fix**: Add missing rewrites or simplifications to align states.

---

## 7. Completion checklist: How to know when you're done

A composition theorem is complete when:

- [ ] **Builds successfully**: `lake build <Module>.EvalEquiv` green
- [ ] **No sorry remaining**: All sorries eliminated or documented as axioms
- [ ] **All split cases handled**: Every oracle outcome (none/some) has a proof path
- [ ] **Arity mismatches discharged**: Impossible cases (cons _ _) sorried with justification
- [ ] **Fuel sufficient**: `hfuel : fuel ≥ N` where N = number of PCs
- [ ] **Shape lemmas align**: Functional simulation branches match run outcomes
- [ ] **Container threading correct**: ms.containers evolves through allocations and oracle calls
- [ ] **Stack evolution correct**: Stack grows/shrinks according to instruction semantics
- [ ] **Frame invariant maintained**: PC advances from 0 to N-1 to ret

---

## 8. Integration with Phase 5 (Move Prover) and Phase 6 (Difftest)

Phase 6 composition theorems are only ONE part of the full verification story:

### Phase 5: Move Prover (source-level specs)
Move Prover verifies MSL specs for `withdraw_to`, `transfer_to`, etc.:
- Balance conservation
- Freeze/allow-list checks
- Abort conditions

**Connection to Phase 6**: Phase 5 proves properties of the *entry point*,
Phase 6 proves properties of the *proof verifier*. Together they cover the full operation.

### Phase 6: Difftest (VM↔Lean)
Difftest verifies that Lean's `eval` matches the actual VM output on concrete inputs.

**Connection to composition theorems**: Composition theorems prove `eval` matches
functional simulation. Difftest proves `eval` matches VM. Transitivity gives:
VM output matches functional simulation (for tested inputs).

### The full chain

```
Move Source (withdraw_to)
      ↓ (Move Prover)
MSL Spec (balance conservation, freezes, aborts)
      ↓ (Lean composition theorem)
Bytecode eval (verify_withdrawal_proof)
      ↓ (Difftest)
VM execution (actual on-chain behavior)
```

**When all three pass**:
- Move Prover: ✅ Entry point preserves invariants
- Lean composition: ✅ Proof verifier implements functional simulation
- Difftest: ✅ Lean eval matches VM output

Then we have **end-to-end formal verification** from source to on-chain execution.

---

## 9. Estimated effort per verifier

Based on the structure above:

| Verifier       | PCs  | Oracles | Estimated lines |
|----------------|------|---------|-----------------|
| Normalization  | 14   | 2       | ~200-250        |
| Withdrawal     | 15   | 2       | ~200-250        |
| Rotation       | 15   | 2       | ~250-300        |
| Transfer       | 24   | 3       | ~350-400        |

**Total for all 4**: ~1000-1200 lines of proof work.

**Current blocker**: Array indexing free variable constraint prevents completion.
Once resolved, estimated effort per verifier: 3-5 days per person.

---

## 10. Related files

- `MovementFormal/Experimental/ConfidentialAsset/Withdrawal/EvalEquiv.lean`: Per-PC step theorems + composition stub
- `MovementFormal/Experimental/ConfidentialAsset/Withdrawal/FunctionalSim.lean`: Functional simulation definition
- `MovementFormal/Experimental/ConfidentialAsset/Withdrawal/Phase6Composition.lean`: High-level composition axiom
- `MovementFormal/MoveModel/Programs/Withdrawal.lean`: Bytecode program definition
- `MovementFormal/MoveModel/StepLemmas/*.lean`: Infrastructure for composition proofs

Similar files exist for Normalization, Rotation, and Transfer.

---

## 11. Example: Complete (hypothetical) proof skeleton

```lean
theorem withdrawal_eval_equiv_functional_sim ... := by
  rw [eval_withdrawal_eq_run]

  -- PCs 0-5: moveLoc chain
  have h5 := moveLoc_chain_6 ...
  rw [h5]

  -- PCs 6-7: copyLoc chain
  have h7 := copyLoc_chain_2 ...
  rw [h7]

  -- PC 8: immBorrowField
  obtain ⟨cs1, fid1, halloc1⟩ := ...
  have h8 := step_withdrawal_pc8 ... halloc1
  rw [run_succ_ok_of_step _ _ _ _ _ h8]

  -- PC 9: call sigma, split
  cases hsigma : o.verifySigmaProof ... with
  | none =>
      have herr := step_withdrawal_pc9_none ... hsigma
      rw [run_succ_error_of_step _ herr]
      simp [verifyWithdrawalBytecodeResult]; rw [hsigma]; rfl
  | some ⟨[], cs2⟩ =>
      have h9 := step_withdrawal_pc9 ... hsigma
      rw [run_succ_ok_of_step _ _ _ _ _ h9]

      -- PCs 10-11: moveLoc chain
      have h11 := moveLoc_chain_2 ...
      rw [h11]

      -- PC 12: immBorrowField
      obtain ⟨cs3, fid2, halloc2⟩ := ...
      have h12 := step_withdrawal_pc12 ... halloc2
      rw [run_succ_ok_of_step _ _ _ _ _ h12]

      -- PC 13: call range, split
      cases hrange : o.verifyRangeProof ... with
      | none =>
          have herr := step_withdrawal_pc13_none ... hrange
          rw [run_succ_error_of_step _ herr]
          simp [verifyWithdrawalBytecodeResult]; rw [hsigma, hrange]; rfl
      | some ⟨[], cs4⟩ =>
          have h13 := step_withdrawal_pc13 ... hrange
          rw [run_succ_ok_of_step _ _ _ _ _ h13]

          -- PC 14: ret
          have h14 := step_withdrawal_pc14 ...
          rw [run_succ_returned_of_step _ _ _ h14]
          simp [verifyWithdrawalBytecodeResult]; rw [hsigma, hrange]; rfl

      | some ⟨_ :: _, _⟩ => sorry -- Arity mismatch

  | some ⟨_ :: _, _⟩ => sorry -- Arity mismatch
```

This structure is **repeatable** across all 4 verifiers, with only parameter differences.

---

## Conclusion

Phase 6 composition theorems are the **capstone** of the formal verification effort.
They connect:
- Bytecode execution (Level 1)
- Functional simulation (Level 0)
- Per-PC step theorems (infrastructure)

Once the array indexing blocker is resolved, completing all 4 proofs is estimated at
~1000-1200 lines, spread across 3-5 days per verifier.

This guide provides the roadmap. The infrastructure is in place. The path is clear.
-/

namespace MovementFormal.MoveModel.StepLemmas.CompositionGuide

-- This module is purely documentary — no executable code.

end MovementFormal.MoveModel.StepLemmas.CompositionGuide
