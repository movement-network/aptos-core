# Phase 6 PC-Chaining Completion Guide

**Purpose:** Complete step-by-step guide for finishing the PC-chaining composition proofs for all 4 Phase 4 operations (Normalization, Withdrawal, Rotation, Transfer).

**Current Status:** All 4 operations have theorem scaffolds with `sorry` placeholders. This guide provides the systematic approach to replace each `sorry` with a complete proof.

**Time Estimate:** 
- Normalization: 4-6 hours (14 PCs, simplest)
- Withdrawal: 5-7 hours (15 PCs, similar to Normalization)
- Rotation: 5-7 hours (15 PCs, similar to Withdrawal)
- Transfer: 9-12 hours (24 PCs, most complex with 3 sub-calls)
- **Total: 23-32 hours** (3-4 days full-time)

---

## 1. Understanding PC-Chaining

### 1.1 What is PC-Chaining?

PC-chaining is the process of proving that a sequence of bytecode instructions (PCs 0 through N) executed via `run` produces the same result as your functional simulation predicate.

**The pattern:**
```lean
theorem operation_eval_equiv_functional_sim
    (proofRef : Address)
    (addr : Address)
    (h_oracle : oracleResult = verifyOperationBytecodeResult ...)
    : eval env (operationState 0 proofRef addr) cs ms =
        match oracleResult with
        | .success => .returned [] ms
        | .verifyFailed => .aborted 65537 ms
        | .error => .error ms
```

The proof strategy:
1. Unfold `eval` to `run`
2. Case-split on the oracle result
3. For each case, chain through all PCs using step theorems
4. Show final PC reaches the target state (`.returned`, `.aborted`, or `.error`)

### 1.2 The Step Library Pattern

Each PC step uses a theorem from `MovementFormal/MoveModel/StepLemmas/`:
- `StepLemmas.Basic` — `ldU64`, `ldTrue`, `ldFalse`, `pop`, `ret`, `brTrue`, `brFalse`
- `StepLemmas.Locals` — `stLoc`, `copyLoc`, `moveLoc`
- `StepLemmas.Structs` — `pack`, `unpack`, `mutBorrowField`, `immBorrowField`
- `StepLemmas.Calls` — `call`, `callGeneric`
- `StepLemmas.Run` — `run_steps_eq`, composition lemmas

**Example step:**
```lean
-- PC 3: StLoc 0
rw [step_stLoc_frame 
  (K := 0) 
  (v := .u64 proofRef)
  (h_local : cs.locals.get? 0 = none)
  (h_pc : st.pc = 3)]
```

### 1.3 The Shape Lemma Pattern

Before chaining PCs, prove shape lemmas that reduce complex oracle results to simple constructors:

```lean
theorem operation_functional_sim_success_shape
    (h_oracle : oracleResult = .success)
    : verifyOperationBytecodeResult env oracleResult = 
        .returned [] .empty
```

These transform the outer `match oracleResult` into direct constructor matches that `simp` can reduce.

---

## 2. Systematic PC-Chaining Workflow

### 2.1 Prerequisites (one-time per operation)

**Step 1:** Read the operation's `EvalEquiv.lean` file to understand:
- How many PCs total (check `eval_operation_eq_run`)
- Which PCs are error paths vs happy path
- What the final PC state should be for each oracle case

**Step 2:** Read the operation's functional sim (`FunctionalSim.lean` or inline):
- Understand what `verifyOperationBytecodeResult` returns for each oracle case
- Identify which oracle failures map to which error PCs

**Step 3:** List all shape lemmas needed:
- Success case: `_success_shape`
- Verify-failed case: `_verifyFailed_shape`
- Error cases: one per error PC (e.g., `_malformedProof_shape`, `_invalidSignature_shape`)

### 2.2 Phase 1: Prove Shape Lemmas

For each oracle case, prove a shape lemma that unfolds the functional sim to a direct constructor.

**Template:**
```lean
theorem operation_functional_sim_CASE_shape
    (env : ModuleEnvironment)
    (proofAddr : Address)
    (userAddr : Address)
    (h_oracle : oracleResult = .CASE)
    : verifyOperationBytecodeResult env proofAddr userAddr oracleResult = 
        .TARGET_CONSTRUCTOR
  := by
    unfold verifyOperationBytecodeResult
    simp [h_oracle]
    -- Additional case splits if needed
```

**Example (Normalization success):**
```lean
theorem normalization_functional_sim_success_shape
    (env : ModuleEnvironment)
    (proofAddr : Address)
    (userAddr : Address)
    (h_oracle : oracleResult = .success)
    : verifyNormalizationBytecodeResult env proofAddr userAddr oracleResult = 
        .returned [] .empty
  := by
    unfold verifyNormalizationBytecodeResult
    simp [h_oracle]
```

**Gotchas:**
- If the functional sim has nested matches, you may need `split` tactic
- Use `rfl` when both sides reduce to identical constructors
- Add helper lemmas if case analysis gets too deep

### 2.3 Phase 2: Success Path PC-Chaining

This is the main proof — chain through all happy-path PCs from PC 0 to the final `ret`.

**Step-by-step:**

1. **Open the theorem:**
```lean
theorem operation_eval_equiv_functional_sim
    (proofRef : Address)
    (addr : Address)
    (h_oracle : oracleResult = ...)
    : eval env (operationState 0 proofRef addr) cs ms =
        match oracleResult with
        | .success => .returned [] ms
        | .verifyFailed => .aborted 65537 ms
        | .error => .error ms
  := by
    unfold eval
    rw [eval_operation_eq_run]
    cases oracleResult with
    | success => 
      -- Success path proof goes here
      sorry
    | verifyFailed =>
      -- Verify-failed path proof goes here
      sorry
    | error =>
      -- Error path proof goes here
      sorry
```

2. **Focus on the success case:**
```lean
    | success => 
      -- Apply success shape lemma
      rw [operation_functional_sim_success_shape env proofRef addr rfl]
      
      -- Now prove: run (operationState 0 ...) = .returned [] ms
      unfold run operationState
      
      -- Chain through PCs
      sorry
```

3. **Add PC steps one by one:**

For each PC, look up the bytecode instruction and apply the matching step lemma.

**Common patterns:**

- **LdU64 (load constant):**
  ```lean
  rw [step_ldU64 
    (const := VALUE)
    (h_instr : instrs[PC] = .ldU64 VALUE)
    (h_pc : state.pc = PC)]
  ```

- **StLoc (store local):**
  ```lean
  rw [step_stLoc_frame
    (K := LOCAL_IDX)
    (v := VALUE_EXPRESSION)
    (h_local : locals.get? LOCAL_IDX = none)  -- or (some oldValue) if overwriting
    (h_pc : state.pc = PC)]
  ```

- **CopyLoc (copy local to stack):**
  ```lean
  rw [step_copyLoc
    (K := LOCAL_IDX)
    (h_local : locals.get? LOCAL_IDX = some VALUE)
    (h_pc : state.pc = PC)]
  ```

- **MoveLoc (move local to stack, clear local):**
  ```lean
  rw [step_moveLoc
    (K := LOCAL_IDX)
    (h_local : locals.get? LOCAL_IDX = some VALUE)
    (h_pc : state.pc = PC)]
  ```

- **ImmBorrowLoc (borrow local immutably):**
  ```lean
  rw [step_immBorrowLoc
    (K := LOCAL_IDX)
    (h_local : locals.get? LOCAL_IDX = some VALUE)
    (h_pc : state.pc = PC)]
  ```

- **Call (native call):**
  ```lean
  rw [step_call_native
    (fIdx := FUNCTION_INDEX)
    (h_func : env.functions[FUNCTION_INDEX] = .native NATIVE_NAME ...)
    (h_oracle : NATIVE_NAME stack = RESULT)
    (h_pc : state.pc = PC)]
  ```

- **Ret (return):**
  ```lean
  rw [step_ret
    (retValues := [])  -- or whatever values are on stack
    (h_pc : state.pc = FINAL_PC)]
  simp
  ```

4. **Handle branching (BrTrue/BrFalse):**

If there's a conditional jump, you need to prove which branch is taken:

```lean
-- BrTrue: jump if top of stack is true
rw [step_brTrue
  (target := TARGET_PC)
  (h_stack : stack.head? = some (.bool true))
  (h_pc : state.pc = PC)]

-- BrFalse: jump if top of stack is false
rw [step_brFalse
  (target := TARGET_PC)
  (h_stack : stack.head? = some (.bool false))
  (h_pc : state.pc = PC)]
```

**Common gotcha:** After a `brTrue`/`brFalse`, the PC jumps — make sure your next step uses the target PC, not PC+1.

5. **Handle native calls with oracles:**

For calls to `verify_*_proof_internal`, you need to relate the oracle result to the bytecode result:

```lean
-- Example: PC 10 calls verify_normalization_proof_internal
rw [step_call_native
  (fIdx := 15)
  (h_func : env.functions[15] = .native "verify_normalization_proof_internal" ...)
  (h_oracle : verifyNormalizationProofInternal stack = 
                match oracleResult with
                | .success => .some (.bool true)
                | .verifyFailed => .some (.bool false)
                | .error => .none)
  (h_pc : state.pc = 10)]

-- Then case-split on oracleResult (already done at top level)
-- and simplify using h_oracle assumption
```

6. **Prove final state:**

After the last PC (usually `ret`), the state should match the target:

```lean
-- After ret at PC N-1:
rw [step_ret (retValues := []) (h_pc : state.pc = N-1)]
simp
-- Goal should now be: .returned [] ms = .returned [] ms
rfl
```

### 2.4 Phase 3: Verify-Failed Path PC-Chaining

The verify-failed path handles the case where proof verification returns `false`.

**Pattern:**
1. Apply verify-failed shape lemma
2. Chain through PCs until the `brFalse` that jumps to the abort block
3. Prove the branch is taken (stack top is `false`)
4. Chain through abort block PCs until `abort` instruction
5. Show final state is `.aborted 65537`

**Example:**
```lean
    | verifyFailed =>
      rw [operation_functional_sim_verifyFailed_shape env proofRef addr rfl]
      
      -- Chain through PCs 0-10 (same as success path)
      -- ...
      
      -- PC 11: Call returns false
      rw [step_call_native
        (h_oracle : verifyProofInternal stack = .some (.bool false))]
      
      -- PC 12: BrFalse jumps to abort block at PC 20
      rw [step_brFalse
        (target := 20)
        (h_stack : stack.head? = some (.bool false))]
      
      -- PC 20: LdU64 65537 (VERIFY_FAILED abort code)
      rw [step_ldU64 (const := 65537)]
      
      -- PC 21: Abort
      rw [step_abort
        (code := 65537)
        (h_stack : stack.head? = some (.u64 65537))]
      
      rfl
```

### 2.5 Phase 4: Error Path PC-Chaining

Error paths handle oracle failures (malformed proof, decompression failure, etc.).

**Pattern:**
1. Apply error shape lemma
2. Chain through PCs until the native call that fails
3. Prove the call returns `.none` (error)
4. Show final state is `.error`

**Example:**
```lean
    | error =>
      rw [operation_functional_sim_error_shape env proofRef addr rfl]
      
      -- Chain through PCs 0-4
      -- ...
      
      -- PC 5: Call to decompress_point fails
      rw [step_call_native
        (h_oracle : decompressPoint stack = .none)]
      
      -- Step library should have lemma: native call returning none → .error
      rw [step_error_from_native_none]
      
      rfl
```

---

## 3. Operation-Specific Guides

### 3.1 Normalization (14 PCs, Simplest)

**File:** `lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/Phase6Composition.lean`

**Oracle cases:**
- `.success` → happy path, all 14 PCs, `ret` at PC 13
- `.verifyFailed` → PCs 0-10, `brFalse` to abort at PC 11, abort at PC 13
- `.error` → early error at PC 5 (decompress failure) or PC 10 (verify call fails)

**PC Breakdown:**
```
PC  0: LdU64 proofRef          // Load proof address
PC  1: StLoc 0                 // Store to local 0
PC  2: LdU64 userAddr          // Load user address
PC  3: StLoc 1                 // Store to local 1
PC  4: CopyLoc 0               // Copy proof address
PC  5: ImmBorrowLoc            // Borrow proof
PC  6: Call decompressProof    // Native: decompress, may fail → .error
PC  7: StLoc 2                 // Store decompressed proof
PC  8: CopyLoc 1               // Copy user address
PC  9: CopyLoc 2               // Copy proof
PC 10: Call verifyNormalizationProof  // Native: verify, returns bool
PC 11: BrFalse 13              // If false, jump to abort
PC 12: Ret                     // Success: return
PC 13: LdU64 65537 + Abort     // Verify failed: abort with code
```

**Shape lemmas needed:**
- `normalization_functional_sim_success_shape` (already exists)
- `normalization_functional_sim_verifyFailed_shape`
- `normalization_functional_sim_error_shape`

**Estimated time:** 4-6 hours

**Helper axioms (current):**
- `normalization_oracle_equivalence` — relates bytecode oracle to functional oracle
- `normalization_proof_decompression_deterministic` — decompress is deterministic

**TODO:** These axioms should be eliminated by directly proving the oracle correspondence in the main theorem.

### 3.2 Withdrawal (15 PCs)

**File:** `lean/MovementFormal/Experimental/ConfidentialAsset/Withdrawal/Phase6Composition.lean`

**Oracle cases:**
- `.success` → happy path, all 15 PCs
- `.verifyFailed` → abort path
- `.error` → early error (similar structure to Normalization)

**PC Breakdown:**
```
PC  0-13: Similar to Normalization (load, verify, branch)
PC 14: Ret or Abort
```

**Shape lemmas needed:**
- `withdrawal_functional_sim_success_shape`
- `withdrawal_functional_sim_verifyFailed_shape`
- `withdrawal_functional_sim_error_shape`

**Estimated time:** 5-7 hours

### 3.3 Rotation (15 PCs)

**File:** `lean/MovementFormal/Experimental/ConfidentialAsset/Rotation/Phase6Composition.lean`

**Oracle cases:**
- `.success`
- `.verifyFailed`
- `.error`

**PC Breakdown:**
Similar to Withdrawal (15 PCs total).

**Shape lemmas needed:**
- `rotation_functional_sim_success_shape`
- `rotation_functional_sim_verifyFailed_shape`
- `rotation_functional_sim_error_shape`

**Estimated time:** 5-7 hours

### 3.4 Transfer (24 PCs, Most Complex)

**File:** `lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/Phase6Composition.lean`

**Oracle cases:**
- `.success` → happy path, 24 PCs
- `.verifyFailed` → abort path
- `.senderProofError` → early error at sender proof verification
- `.receiverProofError` → error at receiver proof verification
- `.balanceProofError` → error at balance proof verification

**Why more complex:**
- 3 sub-calls: verify sender proof, verify receiver proof, verify balance proof
- Each sub-call can fail independently
- More branching logic

**PC Breakdown:**
```
PC  0-7:   Load and verify sender proof
PC  8-15:  Load and verify receiver proof
PC 16-23:  Load and verify balance proof, final return/abort
```

**Shape lemmas needed:**
- `transfer_functional_sim_success_shape`
- `transfer_functional_sim_verifyFailed_shape`
- `transfer_functional_sim_senderError_shape`
- `transfer_functional_sim_receiverError_shape`
- `transfer_functional_sim_balanceError_shape`

**Error path lemmas (already exist):**
- `transfer_eval_sender_proof_error`
- `transfer_eval_receiver_proof_error`
- `transfer_eval_balance_proof_error`

**Estimated time:** 9-12 hours

---

## 4. Common Proof Patterns and Tactics

### 4.1 Essential Tactics

**unfold** — Expand definition:
```lean
unfold eval run operationState verifyOperationBytecodeResult
```

**rw** — Rewrite with theorem:
```lean
rw [step_stLoc_frame (K := 0) (v := .u64 addr)]
```

**simp** — Simplify using simp lemmas:
```lean
simp [h_oracle]  -- Simplify using hypothesis
simp only [Array.get?, List.head?]  -- Simplify specific functions
```

**cases** — Case split on inductive type:
```lean
cases oracleResult with
| success => ...
| verifyFailed => ...
| error => ...
```

**split** — Split on if/match expression:
```lean
split
· -- First case
  ...
· -- Second case
  ...
```

**rfl** — Prove by reflexivity:
```lean
rfl  -- Both sides are definitionally equal
```

### 4.2 Debugging Failed Steps

**Problem:** Lean says "motive is not type correct"

**Cause:** PC counter mismatch — you're applying a step lemma for PC N but the current state has PC M.

**Fix:** Check the PC assumptions in your step lemmas. Use `trace` to see current state:
```lean
trace "{state.pc}"  -- Print current PC
```

**Problem:** "type mismatch" when applying step lemma

**Cause:** Stack or locals state doesn't match lemma assumptions.

**Fix:** Add explicit state assumptions:
```lean
have h_stack : stack = [.u64 val1, .u64 val2] := by simp [previous_steps]
rw [step_call (h_stack := h_stack)]
```

**Problem:** Proof gets stuck after many steps

**Cause:** Missing simplification or case split.

**Fix:** Use `simp?` to see what simp lemmas apply:
```lean
simp?  -- Shows which lemmas matched
```

### 4.3 Proof State Management

When proofs get long, factor out PC ranges into helper lemmas:

```lean
-- Helper: PCs 0-5 load arguments
theorem operation_pcs_0_5_load_args
    (proofRef : Address)
    (userAddr : Address)
    : run (operationState 0 proofRef userAddr) cs ms =
        run (operationState 6 proofRef userAddr) cs' ms
  := by
    -- Chain through PCs 0-5
    ...

-- Main theorem uses helper
theorem operation_eval_equiv_functional_sim := by
  ...
  rw [operation_pcs_0_5_load_args]
  -- Continue from PC 6
  ...
```

This keeps the main proof readable and makes debugging easier.

---

## 5. Axiom Elimination Strategy

### 5.1 Current Axioms in Phase 6

**Normalization:**
- `normalization_oracle_equivalence` (2 axioms total)
- `normalization_proof_decompression_deterministic`

**Withdrawal:**
- None (1 axiom in main theorem with `sorry`)

**Rotation:**
- None (1 axiom in main theorem with `sorry`)

**Transfer:**
- None (1 axiom in main theorem with `sorry`)

### 5.2 Elimination Plan

**Goal:** Replace all axioms with proofs, leaving only:
- Group theory axioms (in `AptosStd/Crypto/EdwardsCurve25519.lean`)
- Ristretto axioms (in `AptosStd/Crypto/Ristretto255.lean`)
- Bulletproofs axioms (in `AptosStd/Crypto/Bulletproofs.lean`)

**Step 1:** Replace helper axioms with direct oracle correspondence

Instead of:
```lean
axiom normalization_oracle_equivalence : ...

theorem normalization_eval_equiv_functional_sim := by
  apply normalization_oracle_equivalence
  ...
```

Directly prove:
```lean
theorem normalization_eval_equiv_functional_sim := by
  -- Inline the oracle correspondence proof
  ...
```

**Step 2:** Prove shape lemmas eliminate the need for helper axioms

Shape lemmas should be provable by pure unfolding and case analysis, no axioms needed.

**Step 3:** Verify axiom count with `#print axioms`

After completing each operation:
```lean
#print axioms normalization_eval_equiv_functional_sim
-- Should show only: group theory, Ristretto, Bulletproofs
```

---

## 6. Testing and Validation

### 6.1 Per-Operation Checklist

After completing an operation's PC-chaining proof:

- [ ] Theorem compiles with no `sorry`
- [ ] File builds in ≤3 minutes: `lake build MovementFormal.Experimental.ConfidentialAsset.OPERATION.Phase6Composition`
- [ ] `#print axioms` shows only documented crypto axioms (no temporary axioms)
- [ ] `verify-ca.sh --op OPERATION --stack lean` passes
- [ ] Downstream files still build: `lake build MovementFormal.Experimental.ConfidentialAsset.EndToEnd`

### 6.2 Full Phase 6 Acceptance Criteria

All 4 operations complete when:

- [ ] All theorems in `**/Phase6Composition.lean` have no `sorry`
- [ ] No temporary axioms remain (only 21 permanent crypto axioms from Phase 8)
- [ ] Full Lean tree builds in ≤10 minutes: `lake build MovementFormal`
- [ ] `verify-ca.sh --stack lean` passes for all operations
- [ ] `audit/COMPOSITION_CLAIMS.md` updated with file:line pointers to completed proofs
- [ ] `audit/AXIOM_INVENTORY.md` reconciled (no new axioms)

---

## 7. Example: Complete Normalization Success Path

Here's a complete example showing the full proof pattern for Normalization's success case:

```lean
theorem normalization_eval_equiv_functional_sim
    (env : NormalizationModuleEnvironment)
    (proofRef : Address)
    (userAddr : Address)
    (oracleResult : VerifyNormalizationResult)
    : eval env (normalizationState 0 proofRef userAddr) cs ms =
        match oracleResult with
        | .success => .returned [] ms
        | .verifyFailed => .aborted 65537 ms
        | .error => .error ms
  := by
    unfold eval
    rw [eval_normalization_eq_run]
    cases oracleResult with
    | success =>
      -- Apply success shape lemma
      rw [normalization_functional_sim_success_shape env proofRef userAddr rfl]
      
      -- Chain through all 14 PCs
      unfold run normalizationState
      
      -- PC 0: LdU64 proofRef
      rw [step_ldU64 (const := proofRef) (h_pc : pc = 0)]
      
      -- PC 1: StLoc 0
      rw [step_stLoc_frame (K := 0) (v := .u64 proofRef) (h_pc : pc = 1)]
      
      -- PC 2: LdU64 userAddr
      rw [step_ldU64 (const := userAddr) (h_pc : pc = 2)]
      
      -- PC 3: StLoc 1
      rw [step_stLoc_frame (K := 1) (v := .u64 userAddr) (h_pc : pc = 3)]
      
      -- PC 4: CopyLoc 0
      rw [step_copyLoc (K := 0) (h_local : locals[0] = some (.u64 proofRef)) (h_pc : pc = 4)]
      
      -- PC 5: ImmBorrowLoc
      rw [step_immBorrowLoc (K := 0) (h_pc : pc = 5)]
      
      -- PC 6: Call decompressProof (native, succeeds in success case)
      rw [step_call_native
        (fIdx := 14)
        (h_func : env.functions[14] = .native "decompress_normalization_proof")
        (h_oracle : decompressNormalizationProof stack = .some decompressedProof)
        (h_pc : pc = 6)]
      
      -- PC 7: StLoc 2
      rw [step_stLoc_frame (K := 2) (v := decompressedProof) (h_pc : pc = 7)]
      
      -- PC 8: CopyLoc 1
      rw [step_copyLoc (K := 1) (h_pc : pc = 8)]
      
      -- PC 9: CopyLoc 2
      rw [step_copyLoc (K := 2) (h_pc : pc = 9)]
      
      -- PC 10: Call verifyNormalizationProof (returns true in success case)
      rw [step_call_native
        (fIdx := 15)
        (h_func : env.functions[15] = .native "verify_normalization_proof_internal")
        (h_oracle : verifyNormalizationProofInternal stack = .some (.bool true))
        (h_pc : pc = 10)]
      
      -- PC 11: BrFalse 13 (not taken, stack top is true)
      rw [step_brFalse_not_taken
        (h_stack : stack.head? = some (.bool true))
        (h_pc : pc = 11)]
      
      -- PC 12: Ret
      rw [step_ret (retValues := []) (h_pc : pc = 12)]
      
      -- Goal: .returned [] ms = .returned [] ms
      rfl
      
    | verifyFailed =>
      -- Verify-failed path: similar structure, branch taken at PC 11
      sorry
      
    | error =>
      -- Error path: call fails at PC 6 or PC 10
      sorry
```

**Key points:**
- Each `rw` advances one PC
- Hypothesis names (`h_pc`, `h_local`, `h_oracle`) match step lemma parameters
- Final `rfl` closes when both sides are identical
- Success path is longest; error paths are shorter (early exit)

---

## 8. Troubleshooting Guide

### Issue: "unknown identifier 'step_ldU64'"

**Cause:** Step lemma not imported.

**Fix:** Add import at top of file:
```lean
import MovementFormal.MoveModel.StepLemmas.Basic
```

### Issue: Proof timeout or excessive memory usage

**Cause:** Large proof term, likely from repeated unfolding.

**Fix:** Factor out helper lemmas for PC ranges (see §4.3).

### Issue: "type mismatch" on `rw [step_...]`

**Cause:** Implicit arguments don't unify.

**Fix:** Make arguments explicit:
```lean
rw [step_stLoc_frame 
  (state := currentState)
  (K := 0)
  (v := .u64 val)]
```

### Issue: Can't prove local/stack assumptions for step lemma

**Cause:** Implicit state assumptions from previous steps not simplified.

**Fix:** Add intermediate `simp` or `have` to make state explicit:
```lean
have h_stack : currentState.stack = [.u64 x, .u64 y] := by
  simp [all_previous_steps]
rw [step_call (h_stack := h_stack)]
```

### Issue: Build time exceeds 3-minute budget

**Cause:** Proof too monolithic.

**Fix:**
1. Factor out PC-range helpers (§4.3)
2. Use `@[irreducible]` on intermediate state definitions
3. Check for redundant `simp` calls (use `simp only` with explicit lemma list)

---

## 9. Next Steps After Phase 6 Completion

Once all 4 PC-chaining proofs are complete:

1. **Update `COMPOSITION_CLAIMS.md`**: Add file:line pointers to each completed theorem
2. **Update `AXIOM_INVENTORY.md`**: Reconcile axiom count (should be unchanged, 23 total)
3. **Update `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §0**: Mark Phase 6 as ✅ COMPLETE
4. **Run full verification suite**: `./verify-ca.sh --stack lean` should pass all operations
5. **Measure build times**: Verify each operation ≤3 min, full tree ≤10 min
6. **Update `PHASE_7_STATUS.md`**: Phase 6 completion unblocks final Phase 7 audit package
7. **CI validation**: Ensure `.github/workflows/lean-ca.yaml` passes on clean build

**Then move to:**
- **Phase 1 singleton-some completion** (final 5%, ~1-2 days)
- **Phase 7 final audit package** (Docker publish, difftest harness integration)
- **Phase 8 axiom reduction** (eliminate `registration_eval_equiv_functional_sim` axiom)

---

## 10. References

**Lean Files:**
- Step lemmas: `lean/MovementFormal/MoveModel/StepLemmas/*.lean`
- Phase 6 scaffolds: `lean/MovementFormal/Experimental/ConfidentialAsset/*/Phase6Composition.lean`
- Functional sims: `lean/MovementFormal/Experimental/ConfidentialAsset/*/FunctionalSim.lean`

**Documentation:**
- Master plan: `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`
- Axiom inventory: `audit/AXIOM_INVENTORY.md`
- Composition claims: `audit/COMPOSITION_CLAIMS.md`
- Phase 6 progress: `audit/PHASE_6_PROGRESS_SUMMARY.md`

**Scripts:**
- Verification runner: `audit/verify-ca.sh`
- Axiom checker: `scripts/check_axioms.sh`

**Community Resources:**
- Lean Zulip: https://leanprover.zulipchat.com/
- Lean 4 manual: https://lean-lang.org/lean4/doc/
- Mathlib docs: https://leanprover-community.github.io/mathlib4_docs/

---

**END OF GUIDE**

**Estimated completion time: 23-32 hours** (3-4 days full-time, or 1-2 weeks part-time)

**Questions?** Check `MAINTENANCE_GUIDE.md` for ongoing verification maintenance or `CI_TROUBLESHOOTING_GUIDE.md` for CI failures.
