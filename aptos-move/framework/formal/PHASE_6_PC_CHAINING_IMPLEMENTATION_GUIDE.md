# Phase 6 PC-Chaining Proof Implementation Guide

**Purpose:** Complete implementation guide for the PC-chaining proofs needed in Phase 6 composition theorems. These are the ~1,000-1,500 lines of proof that connect `eval` → `run` → `verifyXBytecodeResult` for the four Phase 4 operations (normalization, withdrawal, transfer, rotation).

**Status:** Scaffolds with `sorry` are in place. This guide shows how to close them systematically.

**Target audience:** Developers with Phase 1/4 experience, ready to tackle the composition layer.

---

## 1. What are PC-chaining proofs?

### 1.1 The composition gap

Currently:
- **Phase 4 EvalEquiv files** prove: `eval (module env) funcIdx args cs ms = run env initialFrame cs ms`
- **FunctionalSim files** define: `verifyXBytecodeResult oracle inputs = <expected result>`
- **Phase 6 Composition files** have `sorry`: `run env initialFrame cs ms = verifyXBytecodeResult oracle inputs`

The **PC-chaining proof** bridges the gap: it proves that stepping through the bytecode PCs one-by-one yields the same result as the high-level functional simulation.

### 1.2 Why it's non-trivial

The functional sim is a nested match:
```lean
verifyNormalizationBytecodeResult oracle proofRef =
  match oracle.verifyNormalizationProof proofRef with
  | none => .error "proof verification failed"
  | some _ => .returned [] empty
```

The `run` trace is a chain of 14 `step` calls:
```lean
run env frame cs ms = step_pc0 ∘ step_pc1 ∘ ... ∘ step_pc13
```

Proving they're equal requires:
1. **Unfolding `run`** into the PC chain
2. **Case-splitting on the oracle** to handle `none` vs `some`
3. **Reducing each PC step** to a simpler form
4. **Matching the result** to the functional-sim shape

### 1.3 Pattern: shape lemmas + main theorem

The standard approach (already scaffolded in Phase 6 files):

1. **Shape lemmas** — one per oracle outcome, proving `run` reduces to the expected `.error`/`.returned`/`.aborted`:
   ```lean
   theorem normalization_shape_verifyFailed :
       oracle.verifyNormalizationProof proofRef = none →
       run env frame cs ms = .error "proof verification failed"
   ```

2. **Main composition theorem** — dispatches to the shape lemmas via case-split:
   ```lean
   theorem normalization_eval_equiv_functional_sim :
       run env frame cs ms = verifyNormalizationBytecodeResult oracle proofRef := by
     unfold verifyNormalizationBytecodeResult
     cases h : oracle.verifyNormalizationProof proofRef
     case none => apply normalization_shape_verifyFailed; assumption
     case some _ => apply normalization_shape_success; assumption
   ```

**This guide** shows how to close the shape lemmas (the bulk of the work).

---

## 2. General PC-chaining proof structure

### 2.1 The canonical template

Every shape lemma follows this pattern:

```lean
theorem operation_shape_case
    (oracle : Oracle)
    (inputs : Inputs)
    (cs : CallStack)
    (ms : MachineState)
    (h_oracle : oracle.verifyProof inputs = <expected-value>) :
    run env (initialFrame inputs) cs ms = <expected-result> := by
  -- Step 1: Unfold run to the PC chain
  rw [run_def]
  
  -- Step 2: Apply each step lemma in sequence
  rw [step_pc0, step_pc1, step_pc2, ...]
  
  -- Step 3: Resolve the oracle call (substitute h_oracle)
  rw [h_oracle]
  
  -- Step 4: Simplify the final result
  simp only [expected-result-def]
  rfl
```

### 2.2 Key tactics

- **`rw [step_pcN]`** — replace `step env frameN cs ms` with `step env frameN+1 cs ms` (or final result)
- **`cases h : oracle.verifyProof ...`** — split on oracle outcomes
- **`simp only [...]`** — reduce definitions with a controlled simp set (never bare `simp`)
- **`rfl`** — close the proof when both sides are syntactically equal

### 2.3 When to use helper axioms

If a PC step involves complex native calls (e.g., Ristretto point decompression, Bulletproofs verification), you may need a **helper axiom** to abstract it:

```lean
axiom ristretto_point_decompress_step :
    step env frameK cs ms = .ok frameK+1 cs ms
```

These are catalogued in `AXIOM_INVENTORY.md` and are acceptable if:
1. The native is crypto-opaque (Ristretto, SHA, Bulletproofs)
2. Difftest rows cover the concrete behavior
3. The axiom is named, documented, and reviewed

Prefer proving steps directly when possible; axiomatize only when the native is truly opaque.

---

## 3. Operation-by-operation implementation

### 3.1 Normalization (easiest, recommended first)

**Complexity:** Low. 14 PCs, 1 native call (`verifyNormalizationProof`), 2 outcomes (success / verify-failed).

**Files:**
- EvalEquiv: `lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean`
- FunctionalSim: `lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/FunctionalSim.lean`
- Phase6: `lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/Phase6Composition.lean`

**Current state (from Phase 6 scaffold):**
```lean
theorem normalization_eval_equiv_functional_sim :
    run env (normalizationInitFrame args) cs ms =
      verifyNormalizationBytecodeResult oracle proofRef := by
  sorry  -- TODO: PC-chaining proof
```

**Implementation steps:**

#### Step A: Define the shape lemmas

Add two shape lemmas in `Phase6Composition.lean`:

```lean
-- Shape lemma 1: Proof verification failed
theorem normalization_shape_verifyFailed
    (oracle : NormalizationNativeOracle)
    (proofRef : RefValue)
    (cs : CallStack)
    (ms : MachineState)
    (h_verify : oracle.verifyNormalizationProof proofRef = none) :
    run env (normalizationInitFrame [proofRef]) cs ms =
      .error "normalization proof verification failed" := by
  sorry  -- Filled in Step B

-- Shape lemma 2: Proof verification succeeded
theorem normalization_shape_success
    (oracle : NormalizationNativeOracle)
    (proofRef : RefValue)
    (cs : CallStack)
    (ms : MachineState)
    (h_verify : oracle.verifyNormalizationProof proofRef = some proof) :
    run env (normalizationInitFrame [proofRef]) cs ms =
      .returned [] ms := by
  sorry  -- Filled in Step C
```

#### Step B: Fill in the verify-failed shape lemma

**Goal:** Prove that when `verifyNormalizationProof` returns `none`, the execution errors.

**Approach:** Chain through PCs until the native call, substitute `h_verify`, observe the error path.

```lean
theorem normalization_shape_verifyFailed
    (oracle : NormalizationNativeOracle)
    (proofRef : RefValue)
    (cs : CallStack)
    (ms : MachineState)
    (h_verify : oracle.verifyNormalizationProof proofRef = none) :
    run env (normalizationInitFrame [proofRef]) cs ms =
      .error "normalization proof verification failed" := by
  -- Unfold run
  unfold run
  
  -- Chain through PCs 0-13
  -- (Exact PC step lemmas from EvalEquiv.lean)
  rw [normalization_step_pc0]  -- immBorrowLoc
  rw [normalization_step_pc1]  -- load constant
  rw [normalization_step_pc2]  -- load constant
  rw [normalization_step_pc3]  -- call verifyNormalizationProof
  
  -- At PC 3, the native call happens
  -- The oracle returns none (from h_verify)
  rw [h_verify]
  
  -- The call step with none result produces .error
  simp only [step_call_native_none]
  
  -- Match the error message
  rfl
```

**Notes:**
- The step lemmas `normalization_step_pc0`, etc., are imported from `Normalization/EvalEquiv.lean`
- If they're not named this way, use the actual names (e.g., `step_pc0_immBorrowLoc`)
- The `step_call_native_none` lemma comes from `StepLemmas.Calls` — it states that a native call returning `none` produces `.error`

#### Step C: Fill in the success shape lemma

**Goal:** Prove that when `verifyNormalizationProof` returns `some proof`, the execution succeeds.

```lean
theorem normalization_shape_success
    (oracle : NormalizationNativeOracle)
    (proofRef : RefValue)
    (proof : NormalizationProof)
    (cs : CallStack)
    (ms : MachineState)
    (h_verify : oracle.verifyNormalizationProof proofRef = some proof) :
    run env (normalizationInitFrame [proofRef]) cs ms =
      .returned [] ms := by
  -- Unfold run
  unfold run
  
  -- Chain through PCs 0-2 (same as verify-failed case)
  rw [normalization_step_pc0]
  rw [normalization_step_pc1]
  rw [normalization_step_pc2]
  rw [normalization_step_pc3]
  
  -- Substitute the oracle result (some proof)
  rw [h_verify]
  
  -- The call step with some result produces .ok with the proof value
  simp only [step_call_native_some]
  
  -- Continue through remaining PCs (4-13)
  rw [normalization_step_pc4]  -- store result
  rw [normalization_step_pc5]  -- ...
  -- ... (all remaining PCs)
  rw [normalization_step_pc13]  -- ret
  
  -- Final result is .returned
  rfl
```

**Notes:**
- PC 3 is the call; PCs 4-13 are post-call housekeeping + return
- The `step_call_native_some` lemma (from `StepLemmas.Calls`) handles the `some` case
- If any PC step is complex (e.g., involves a container store read/write), you may need intermediate `have` statements to prove preconditions

#### Step D: Compose into the main theorem

Replace the `sorry` in `normalization_eval_equiv_functional_sim`:

```lean
theorem normalization_eval_equiv_functional_sim
    (oracle : NormalizationNativeOracle)
    (proofRef : RefValue)
    (cs : CallStack)
    (ms : MachineState) :
    run env (normalizationInitFrame [proofRef]) cs ms =
      verifyNormalizationBytecodeResult oracle proofRef := by
  -- Unfold the functional sim definition
  unfold verifyNormalizationBytecodeResult
  
  -- Case-split on the oracle result
  cases h : oracle.verifyNormalizationProof proofRef
  case none =>
    -- Dispatch to the verify-failed shape lemma
    exact normalization_shape_verifyFailed oracle proofRef cs ms h
  case some proof =>
    -- Dispatch to the success shape lemma
    exact normalization_shape_success oracle proofRef proof cs ms h
```

**Result:** The `sorry` is closed. `normalization_eval_equiv_functional_sim` is a theorem.

### 3.2 Withdrawal (medium complexity)

**Complexity:** Medium. 15 PCs, 1 native call (`verifyWithdrawalProof`), 2 outcomes (success / verify-failed).

**Structure:** Nearly identical to Normalization, but with 1 additional PC.

**Files:**
- EvalEquiv: `lean/MovementFormal/Experimental/ConfidentialAsset/Withdrawal/EvalEquiv.lean`
- FunctionalSim: `lean/MovementFormal/Experimental/ConfidentialAsset/Withdrawal/FunctionalSim.lean`
- Phase6: `lean/MovementFormal/Experimental/ConfidentialAsset/Withdrawal/Phase6Composition.lean`

**Implementation:** Follow the exact same pattern as Normalization (Steps A-D), substituting:
- `normalization` → `withdrawal`
- 14 PCs → 15 PCs
- `verifyNormalizationProof` → `verifyWithdrawalProof`

**Estimated effort:** 150-200 lines, 2-4 hours (after Normalization is done, this is copy-paste-adjust).

### 3.3 Rotation (medium-high complexity)

**Complexity:** Medium-high. 15 PCs, 1 native call (`verifyRotationProof`), 2 outcomes, **state mutation** (encryption key update).

**Challenge:** Unlike Normalization/Withdrawal, Rotation mutates the `ConfidentialAssetStore` (updates `encryption_pubkey`). The PC chain must thread `ms` → `ms'` through the mutation point (similar to Registration's singleton-some branch).

**Files:**
- EvalEquiv: `lean/MovementFormal/Experimental/ConfidentialAsset/Rotation/EvalEquiv.lean`
- FunctionalSim: `lean/MovementFormal/Experimental/ConfidentialAsset/Rotation/FunctionalSim.lean`
- Phase6: `lean/MovementFormal/Experimental/ConfidentialAsset/Rotation/Phase6Composition.lean`

**Implementation:**

#### Additional steps vs Normalization:

1. **Identify the mutation PC** — which PC executes the store update (likely a `MutBorrowField` + `WriteRef` sequence)
2. **Split the PC chain** — PCs before mutation use `ms`, PCs after use `ms'`
3. **Prove the mutation step** — show that the update step transforms `ms` to `ms'` correctly

**Template shape lemma (success case with mutation):**

```lean
theorem rotation_shape_success
    (oracle : RotationNativeOracle)
    (inputs : ...)
    (cs : CallStack)
    (ms : MachineState)
    (h_verify : oracle.verifyRotationProof ... = some proof) :
    run env (rotationInitFrame inputs) cs ms =
      .returned [] { ms with containerStore := ms.containerStore.update addr updatedStore } := by
  unfold run
  
  -- PCs 0-K: before mutation (use ms)
  rw [rotation_step_pc0, ..., rotation_step_pcK]
  
  -- PC K+1: the mutation step (ms → ms')
  rw [rotation_step_pcK+1_mutate]
  
  -- PCs K+2 to 14: after mutation (use ms')
  rw [rotation_step_pcK+2, ..., rotation_step_pc14]
  
  -- Resolve oracle
  rw [h_verify]
  simp
  rfl
```

**Key difference:** The final result is `.returned [] ms'`, not `.returned [] ms`.

**Estimated effort:** 200-250 lines, 4-6 hours.

### 3.4 Transfer (highest complexity)

**Complexity:** High. 24 PCs, **3 native sub-calls** (`verifyTransferProofSender`, `verifyTransferProofRecipient`, `updateBalances`), 4 outcomes (sender-failed, recipient-failed, update-failed, success).

**Challenge:** Multiple oracle calls mean more case-splits and more shape lemmas.

**Files:**
- EvalEquiv: `lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean`
- FunctionalSim: `lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/FunctionalSim.lean`
- Phase6: `lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/Phase6Composition.lean`

**Implementation:**

#### Four shape lemmas (one per outcome):

```lean
theorem transfer_shape_senderFailed : ...  -- oracle.verifySenderProof = none
theorem transfer_shape_recipientFailed : ...  -- sender ok, recipient none
theorem transfer_shape_updateFailed : ...  -- both ok, update fails
theorem transfer_shape_success : ...  -- all three succeed
```

#### Nested case-split in main theorem:

```lean
theorem transfer_eval_equiv_functional_sim : ... := by
  unfold verifyTransferBytecodeResult
  
  -- Split on sender proof
  cases h_sender : oracle.verifySenderProof ...
  case none =>
    exact transfer_shape_senderFailed ...
  case some senderProof =>
    -- Split on recipient proof
    cases h_recipient : oracle.verifyRecipientProof ...
    case none =>
      exact transfer_shape_recipientFailed ...
    case some recipientProof =>
      -- Split on balance update
      cases h_update : oracle.updateBalances ...
      case none =>
        exact transfer_shape_updateFailed ...
      case some _ =>
        exact transfer_shape_success ...
```

**PC chaining:** Each shape lemma chains through a different subset of PCs:
- `senderFailed`: PCs 0-7 (stop at first native call)
- `recipientFailed`: PCs 0-15 (stop at second native call)
- `updateFailed`: PCs 0-22 (stop at third native call)
- `success`: PCs 0-23 (full chain)

**Estimated effort:** 400-500 lines, 8-12 hours.

---

## 4. Common proof tactics and patterns

### 4.1 Unfolding run

If `run` is defined recursively, unfold it to the step chain:

```lean
unfold run
-- or
rw [run_def]
```

If `run` is defined as a `step` composition, the steps are already exposed.

### 4.2 Applying step lemmas

Each PC step is proved in the EvalEquiv file. Import and rewrite:

```lean
import MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv

theorem normalization_shape_success : ... := by
  rw [EvalEquiv.step_pc0]
  rw [EvalEquiv.step_pc1]
  ...
```

If the step lemmas are in the same namespace, you can drop the prefix:

```lean
open MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv

theorem normalization_shape_success : ... := by
  rw [step_pc0, step_pc1, ...]
```

### 4.3 Resolving oracle calls

When the PC chain reaches a native call:

```lean
-- Before oracle substitution:
step env frame cs ms = ... (call oracle.verifyProof ref) ...

-- After substitution with h_verify : oracle.verifyProof ref = some proof:
rw [h_verify]

-- Result:
step env frame cs ms = ... (call (some proof)) ...
```

The `step_call_native_some` / `step_call_native_none` lemmas then reduce this to `.ok` / `.error`.

### 4.4 Simplifying the final result

After all PC steps, the goal should be:

```lean
.returned [] ms = .returned [] ms
-- or
.error "message" = .error "message"
```

Close with:
```lean
rfl
```

If the goal is almost but not quite syntactically equal, use `simp only` with a controlled simp set:

```lean
simp only [ExecResult.returned, MachineState.update, ...]
rfl
```

**Never use bare `simp`** — it can introduce expensive rewrites and break build times.

### 4.5 Handling state mutation

When a PC mutates `ms`:

```lean
-- PC K: mutates ms to ms'
theorem step_pcK_mutate : 
    step env frameK cs ms = .ok frameK+1 cs ms' := by ...

-- In the main proof:
rw [step_pcK_mutate]

-- All subsequent steps use ms':
rw [step_pcK+1]  -- this step lemma must be parametric over any machine state
rw [step_pcK+2]
```

Ensure the step lemmas are parametric over `ms` (not hardcoded to a specific state).

### 4.6 Using helper axioms for opaque natives

If a native call is crypto-opaque (e.g., `ristretto255_point_decompress`):

```lean
axiom step_pcN_ristretto_decompress :
    step env frameN cs ms = .ok frameN+1 cs ms

-- In the main proof:
rw [step_pcN_ristretto_decompress]
```

Document the axiom in `AXIOM_INVENTORY.md`:
```markdown
| Axiom name | File | Category | Justification |
|---|---|---|---|
| `step_pcN_ristretto_decompress` | `Normalization/Phase6Composition.lean` | Crypto-opaque | Ristretto point decompression, covered by difftest corpus row N |
```

---

## 5. Step-by-step workflow

### 5.1 Start with the simplest operation (Normalization)

1. Open `lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/Phase6Composition.lean`
2. Locate the `sorry` in `normalization_eval_equiv_functional_sim`
3. Add the two shape lemmas (verify-failed, success) with `sorry`
4. Fill in the verify-failed shape lemma (Steps B above)
5. Fill in the success shape lemma (Steps C above)
6. Replace the main theorem's `sorry` with the case-split (Step D above)
7. Build: `lake build MovementFormal.Experimental.ConfidentialAsset.Normalization.Phase6Composition`
8. Verify: no new axioms, builds in under 1 minute

### 5.2 Replicate for Withdrawal and Rotation

Once Normalization is done, Withdrawal is nearly identical. Rotation adds state mutation (follow §3.3).

**Time estimates:**
- Normalization: 3-5 hours (first one, learning the pattern)
- Withdrawal: 2-4 hours (copy-paste-adjust)
- Rotation: 4-6 hours (state mutation complexity)
- Transfer: 8-12 hours (nested case-splits + 3 native calls)

**Total Phase 6 PC-chaining effort:** ~20-30 hours.

### 5.3 Incremental testing

After each shape lemma:
```bash
lake build MovementFormal.Experimental.ConfidentialAsset.<Operation>.Phase6Composition
```

**Target:** Under 1 minute per file.

If it exceeds 1 minute, check for:
- Bare `simp` instead of `simp only [...]`
- Expensive unfolds (missing `@[irreducible]`)
- Redundant step rewrites

### 5.4 Axiom audit

After closing all four operations, audit the axioms:

```bash
lake env lean --run scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Normalization.Phase6Composition
lake env lean --run scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Withdrawal.Phase6Composition
lake env lean --run scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Rotation.Phase6Composition
lake env lean --run scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Transfer.Phase6Composition
```

**Expected:** Only documented crypto axioms (Ristretto, SHA, Bulletproofs) + any helper axioms for opaque natives.

**Zero** temporary axioms.

---

## 6. Common pitfalls and troubleshooting

### 6.1 Step lemma not found

**Symptom:** `unknown identifier 'step_pc0'`

**Cause:** Step lemmas not imported from EvalEquiv file.

**Fix:**
```lean
import MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv
open MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv
```

### 6.2 Type mismatch on machine state

**Symptom:** `expected ExecResult ... ms, found ExecResult ... ms'`

**Cause:** Using the wrong machine state variable after a mutation.

**Fix:** Split the PC chain at the mutation point (see §4.5).

### 6.3 Oracle doesn't reduce

**Symptom:** After `rw [h_verify]`, the oracle call is still in the goal.

**Cause:** The oracle result isn't being substituted.

**Fix:** Ensure `h_verify` has the exact form `oracle.verifyProof ref = <value>`. Use `rw [h_verify]` not `simp [h_verify]`.

### 6.4 Proof hangs during elaboration

**Symptom:** `lake build` hangs at "elaborating <theorem>".

**Cause:** Expensive `simp` or unfold.

**Fix:**
- Replace `simp` with `simp only [specific lemmas]`
- Mark large definitions `@[irreducible]`
- Avoid unfolding `run` repeatedly — unfold once at the start

### 6.5 Final rfl fails

**Symptom:** `rfl` fails with "not definitionally equal".

**Cause:** The LHS and RHS differ by a non-trivial rewrite.

**Fix:**
- Add `simp only [...]` before `rfl` to reduce further
- Check if a step lemma is missing
- Verify the oracle case-split covers all cases

---

## 7. Acceptance criteria for Phase 6

Phase 6 is complete when:

1. **All four operations have closed composition theorems:**
   - `normalization_eval_equiv_functional_sim`
   - `withdrawal_eval_equiv_functional_sim`
   - `rotation_eval_equiv_functional_sim`
   - `transfer_eval_equiv_functional_sim`

2. **No temporary axioms** beyond documented crypto axioms (Ristretto, SHA, Bulletproofs) and accepted helper axioms for opaque natives.

3. **Build times under budget:**
   - Each Phase6Composition.lean file: ≤ 1 minute
   - Full CA Lean tree: ≤ 10 minutes

4. **Verification script passes:**
   ```bash
   ./audit/verify-ca.sh --op normalization --stack lean
   ./audit/verify-ca.sh --op withdrawal --stack lean
   ./audit/verify-ca.sh --op rotation --stack lean
   ./audit/verify-ca.sh --op transfer --stack lean
   ```
   All exit 0 in ≤ 3 minutes per operation.

5. **Progress tracker updated** in `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §0:
   ```diff
   - Phase 6: 🟡 in progress | ... | Outstanding: PC-chaining proofs
   + Phase 6: ✅ COMPLETE | <commit-sha> | All 4 operations, zero temporary axioms, builds in ~4min
   ```

---

## 8. Resources

- **Architecture reference:** `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §4, §6
- **Step-lemma library:** `lean/MovementFormal/MoveModel/StepLemmas/`
- **EvalEquiv files (source of step lemmas):**
  - `lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean`
  - `lean/MovementFormal/Experimental/ConfidentialAsset/Withdrawal/EvalEquiv.lean`
  - `lean/MovementFormal/Experimental/ConfidentialAsset/Rotation/EvalEquiv.lean`
  - `lean/MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean`
- **FunctionalSim files (defines expected results):**
  - `lean/MovementFormal/Experimental/ConfidentialAsset/*/FunctionalSim.lean`
- **Phase 6 scaffold files (where you'll work):**
  - `lean/MovementFormal/Experimental/ConfidentialAsset/*/Phase6Composition.lean`
- **Existing worked examples:** `ROTATION_PROOF_WORKED_EXAMPLE.md`, `WITHDRAWAL_PROOF_WORKED_EXAMPLE.md`
- **Axiom inventory:** `audit/AXIOM_INVENTORY.md`

---

## Summary

PC-chaining proofs connect the low-level bytecode trace (`run`) to the high-level functional simulation (`verifyXBytecodeResult`). The pattern is:

1. **Shape lemmas** for each oracle outcome (verify-failed, success, ...)
2. **PC-by-PC chaining** using step lemmas from EvalEquiv files
3. **Oracle substitution** at native call PCs
4. **State mutation handling** (for Rotation, Registration)
5. **Main theorem** dispatches via case-split on oracle results

**Order of attack:**
1. Normalization (simplest, 3-5 hours)
2. Withdrawal (copy-paste-adjust, 2-4 hours)
3. Rotation (state mutation, 4-6 hours)
4. Transfer (nested case-splits, 8-12 hours)

**Total effort:** ~20-30 hours for all four operations.

Follow the canonical template (§2.1), watch the pitfalls (§6), test incrementally (§5.3). Once done, Phase 6 is ✅ COMPLETE and the full composition chain is proved end-to-end.
