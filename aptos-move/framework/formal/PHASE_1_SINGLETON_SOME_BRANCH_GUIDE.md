# Phase 1 Singleton-Some Branch Completion Guide

**Purpose:** Step-by-step implementation guide for completing the last outstanding piece of Phase 1 — the singleton-some branch of `registration_eval_equiv_functional_sim` in `EvalEquivRebuild.lean`.

**Context:** The non-singleton branch is complete (all 55 non-native PCs + 28 native happy-path PCs + 10 error paths proved). The functional-sim reduction pieces are in place. What remains is threading container-store mutation through the PC-level proof for the singleton-some case.

**Estimated effort:** 200-300 lines of Lean, 1-2 days with this guide.

**Prerequisites:** Familiarity with the Phase 4 architecture patterns (symbolic state, per-PC step lemmas, `@[irreducible]`, `Array.get?`).

---

## 1. Understanding the singleton-some branch

### 1.1 What makes it different

The **singleton-some** branch is the happy-path case where:
1. The Schnorr proof verifies successfully (`verifySchnorrProof` returns `some proof`)
2. The HMAC proof verifies successfully (`verifyHmacProof` returns `some proof`)
3. The container store mutation succeeds (new `ConfidentialAssetStore` created)

Unlike the non-singleton branch (which aborts early), this path:
- Mutates `ms.containerStore` by inserting a new resource
- Returns `.returned [] ms'` where `ms'` has the updated store
- Requires threading the state mutation through all the PC steps

### 1.2 Current state

From `EvalEquivRebuild.lean`:
```lean
-- Outstanding: the PC-level side of the singleton-some branch — 
-- threading through container-store mutation. All functional-sim 
-- reduction pieces are in place.
```

The functional-sim reduction `_blockCDE_success` already handles the outer structure:
```lean
theorem verifyRegistrationBytecodeResult_blockCDE_success :
    verifyRegistrationBytecodeResult oracle
      (.some schnorrProof) (.some hmacProof) pubkey pubkeyUncompressed =
    .returned [] { ms with containerStore := updatedStore } :=
  by simp [verifyRegistrationBytecodeResult]; rfl
```

What's missing: the PC-by-PC proof that the `run` trace actually produces this result.

---

## 2. Architecture: how to thread state mutation

### 2.1 The key challenge

The non-singleton branch works with `ms` unchanged:
```lean
run env initialFrame cs ms = .aborted errorCode
```

The singleton-some branch needs:
```lean
run env initialFrame cs ms = .returned [] ms'
  where ms'.containerStore = ms.containerStore.insert addr newStore
```

This means:
1. **Track the mutation point** — which PC performs the `MoveTo` that inserts the resource
2. **Split the run chain** — `run` before mutation uses `ms`, `run` after mutation uses `ms'`
3. **Prove the mutation** — the `MoveTo` step transforms `ms` to `ms'` as expected

### 2.2 Existing pattern: block-level composition

The non-singleton proof already uses a block-decomposition pattern:
```lean
run = step_pc0 ∘ step_pc1 ∘ ... ∘ step_pcN
```

For singleton-some, extend this with a **split point**:
```lean
run = (step_pc0 ... step_pcK) ∘ step_moveTo ∘ (step_pcK+2 ... step_pcN)
      \_________before________/   \mutation/   \_______after______/
                uses ms                          uses ms'
```

The `step_moveTo` lemma handles the `MoveTo` instruction and proves:
```lean
step env frameK cs ms = .ok frameK+1 cs ms'
  where ms' = { ms with containerStore := ... }
```

---

## 3. Step-by-step implementation plan

### 3.1 Identify the MoveTo PC

**Task:** Find which PC executes the `MoveTo` instruction.

**How:**
1. Open `lean/MovementFormal/MoveModel/Programs/Registration.lean`
2. Search for `verifyRegistrationProofCode`
3. Look for the `Instruction.moveTo` constructor
4. Note the PC index (likely around PC 48-52 based on the registration flow)

**Example:**
```lean
def verifyRegistrationProofCode : Array Instruction := #[
  ...,
  Instruction.moveTo 7 0,  -- PC 49: move ConfidentialAssetStore to address in loc 0
  ...,
]
```

Let's say it's PC 49. Record this — you'll use it repeatedly.

### 3.2 Define the pre-MoveTo state

**Task:** Define a symbolic state for the frame just before the `MoveTo` instruction.

**How:** Add a new `@[irreducible]` helper in `EvalEquivRebuild.lean`:

```lean
/-- State just before MoveTo at PC 49 (singleton-some branch). -/
@[irreducible]
def registrationStatePreMoveTo 
    (proofRef pubkeyRef publicInputsRef : RefValue)
    (schnorrProof hmacProof : SchnorrProof)
    (pubkey pubkeyUncompressed : RistrettoPoint)
    (addr : Address) : Frame :=
  { code := verifyRegistrationProofCode,
    pc := 49,
    locals := #[
      some (MoveValue.address addr),                    -- loc 0: owner address
      some (MoveValue.struct [MoveValue.address addr]), -- loc 1: Object
      ...,
      some (MoveValue.struct [...]),                    -- loc 7: ConfidentialAssetStore (not yet written)
      ...
    ],
    localRefs := #[...],
  }
```

**Pattern:** Mirror the structure from existing state helpers like `registrationState` but at PC 49.

**Key fields:**
- `pc := 49` (the MoveTo PC)
- `locals[7]` contains the `ConfidentialAssetStore` value to be written
- `locals[0]` contains the target address

### 3.3 Prove the MoveTo step

**Task:** Prove the step lemma for the `MoveTo` instruction.

**Template:**
```lean
theorem step_pc49_moveTo 
    (proofRef pubkeyRef publicInputsRef : RefValue)
    (schnorrProof hmacProof : SchnorrProof)
    (pubkey pubkeyUncompressed : RistrettoPoint)
    (addr : Address)
    (cs : CallStack)
    (ms : MachineState)
    (h_containerStore : ms.containerStore.get? addr = none) :
    step env (registrationStatePreMoveTo proofRef pubkeyRef publicInputsRef 
              schnorrProof hmacProof pubkey pubkeyUncompressed addr) cs ms =
      .ok (registrationStatePostMoveTo ...) cs 
          { ms with containerStore := ms.containerStore.insert addr newStoreValue } := by
  -- 1. Unfold the pre-state
  rw [registrationStatePreMoveTo]
  
  -- 2. Apply the MoveTo step lemma from StepLemmas.Basic
  rw [step_moveTo_frame]
  
  -- 3. Simplify the containerStore update
  simp only [ContainerStore.insert, ...]
  
  -- 4. Resolve the inserted value
  unfold newStoreValue
  rfl
```

**Key points:**
- The hypothesis `h_containerStore : ms.containerStore.get? addr = none` ensures the address is fresh (no duplicate registration)
- The result is `.ok` with an updated `ms'` where `ms'.containerStore` has the new entry
- Use `step_moveTo_frame` from `StepLemmas.Basic` (or add it if it doesn't exist)

### 3.4 Define the post-MoveTo state

**Task:** Define the state after the `MoveTo` completes.

```lean
@[irreducible]
def registrationStatePostMoveTo 
    (proofRef pubkeyRef publicInputsRef : RefValue)
    (...) : Frame :=
  { code := verifyRegistrationProofCode,
    pc := 50,  -- next PC after MoveTo
    locals := #[
      some (MoveValue.address addr),
      some (MoveValue.struct [MoveValue.address addr]),
      ...,
      none,  -- loc 7 is now consumed by MoveTo
      ...
    ],
    localRefs := #[...],
  }
```

**Pattern:** Same as pre-state, but:
- `pc := 50` (incremented)
- `locals[7] := none` (the value was moved out)

### 3.5 Prove the remaining PCs (post-MoveTo)

**Task:** Prove the steps from PC 50 to the final `Ret`.

**Structure:** These are standard PC steps using the existing step-lemma library:

```lean
theorem step_pc50_ret
    (...) :
    step env (registrationStatePostMoveTo ...) cs ms' =
      .returned [] ms' := by
  rw [registrationStatePostMoveTo]
  rw [step_ret_frame]
  simp only [Frame.pc, Frame.code, ...]
  rfl
```

**Note:** Use `ms'` (the updated machine state with the new container store entry) for all post-MoveTo steps.

### 3.6 Compose the full singleton-some theorem

**Task:** Combine all the pieces into the top-level theorem.

**Template:**
```lean
theorem registration_eval_equiv_functional_sim_singleton_some
    (oracle : RegistrationNativeOracle)
    (proofRef pubkeyRef publicInputsRef : RefValue)
    (args : List MoveValue)
    (cs : CallStack)
    (ms : MachineState)
    (h_schnorr : oracle.verifySchnorrProof ... = some schnorrProof)
    (h_hmac : oracle.verifyHmacProof ... = some hmacProof)
    (h_fresh : ms.containerStore.get? addr = none) :
    run env (registrationInitFrame args) cs ms =
      .returned [] { ms with containerStore := ms.containerStore.insert addr newStore } := by
  -- 1. Unfold eval to run
  rw [eval_registration_eq_run]
  
  -- 2. Chain through PCs 0-48 (pre-MoveTo)
  rw [step_pc0, step_pc1, ..., step_pc48]
  
  -- 3. Apply the MoveTo step (PC 49)
  rw [step_pc49_moveTo]
  
  -- 4. Chain through PCs 50-N (post-MoveTo, using ms')
  rw [step_pc50_ret]
  
  -- 5. Resolve oracle cases
  cases h_schnorr
  cases h_hmac
  simp
  rfl
```

**Key insight:** The composition splits at PC 49. Before: use `ms`. After: use `ms'`.

### 3.7 Integrate with the main theorem

**Task:** Combine the singleton-some branch with the existing non-singleton branches.

The top-level `registration_eval_equiv_functional_sim` is currently a `sorry`. Replace it with:

```lean
theorem registration_eval_equiv_functional_sim
    (oracle : RegistrationNativeOracle)
    (...) :
    eval (registrationModuleEnv oracle) verifyRegistrationProofIdx args cs ms =
      verifyRegistrationBytecodeResult oracle ... := by
  unfold verifyRegistrationBytecodeResult
  
  -- Case split on oracle results
  cases h_schnorr : oracle.verifySchnorrProof ...
  case none =>
    -- Non-singleton branch: Schnorr failed
    apply registration_eval_equiv_schnorr_failed
    assumption
  case some schnorrProof =>
    cases h_hmac : oracle.verifyHmacProof ...
    case none =>
      -- Non-singleton branch: HMAC failed
      apply registration_eval_equiv_hmac_failed
      assumption
    case some hmacProof =>
      -- Singleton-some branch: both proofs succeeded
      apply registration_eval_equiv_functional_sim_singleton_some
      assumption
      assumption
      assumption
```

**Result:** All three branches are now covered:
1. Schnorr failed → early abort
2. Schnorr succeeded, HMAC failed → later abort
3. Both succeeded → container store mutation + success return

---

## 4. Common pitfalls and troubleshooting

### 4.1 Type mismatches on `ms` vs `ms'`

**Symptom:** Lean reports a type error like:
```
expected: ExecResult ... ms
found:    ExecResult ... ms'
```

**Cause:** Using the wrong machine state variable in a step lemma.

**Fix:** Ensure the split point is correct:
- PCs 0-48: all use `ms`
- PC 49 (MoveTo): takes `ms`, returns `ms'`
- PCs 50+: all use `ms'`

### 4.2 ContainerStore.insert elaboration cost

**Symptom:** The proof hangs during elaboration when inserting into the container store.

**Cause:** Lean is trying to reduce the full `Map.insert` definition.

**Fix:** Mark the store value as `@[irreducible]`:
```lean
@[irreducible]
def newConfidentialAssetStore (pubkey : RistrettoPoint) : ConfidentialAssetStore :=
  { encryption_pubkey := pubkey,
    pending_balance := [],
    actual_balance := [],
    frozen := false,
    allow_list_enabled := false }
```

Then use it in the insert:
```lean
ms.containerStore.insert addr (newConfidentialAssetStore pubkey)
```

### 4.3 Missing step lemma for MoveTo

**Symptom:** No `step_moveTo_frame` lemma exists in `StepLemmas.Basic`.

**Fix:** Add it yourself:

```lean
-- In lean/MovementFormal/MoveModel/StepLemmas/Basic.lean

theorem step_moveTo_frame 
    {env : Environment} {frame : Frame} {cs : CallStack} {ms : MachineState}
    (h_pc : frame.pc < frame.code.size)
    (h_instr : frame.code[frame.pc]'h_pc = Instruction.moveTo typeIdx locIdx)
    (h_locals : frame.locals.get? locIdx = some (some value))
    (h_fresh : ms.containerStore.get? targetAddr = none) :
    step env frame cs ms =
      .ok { frame with 
            pc := frame.pc + 1,
            locals := frame.locals.set! locIdx none }
          cs
          { ms with containerStore := ms.containerStore.insert targetAddr value } := by
  unfold step
  simp only [h_instr, h_locals, h_fresh]
  rfl
```

Adjust the signature to match the actual `step` definition's handling of `MoveTo`.

### 4.4 Oracle reduction not happening

**Symptom:** The `cases oracle.verifySchnorrProof` doesn't reduce to the expected value.

**Cause:** The oracle is opaque or not defined in the current context.

**Fix:** Ensure you have the oracle result as a hypothesis:
```lean
(h_schnorr : oracle.verifySchnorrProof pubkey msg sig = some proof)
```

Then `rw [h_schnorr]` before the `cases`.

---

## 5. Testing the implementation

### 5.1 Incremental build check

After each step, run:
```bash
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
```

**Target:** Under 3 minutes (Phase 1 acceptance criterion).

If it exceeds 3 minutes, you've likely introduced an expensive elaboration. Check for:
- Unfurled state definitions (missing `@[irreducible]`)
- Bare `simp` instead of `simp only [...]`
- Bound proofs in theorem statements instead of `Array.get?`

### 5.2 Axiom check

Once the `sorry` in `registration_eval_equiv_functional_sim` is closed, verify no new axioms were introduced:

```bash
cd lean
lake env lean --run ../scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv
```

**Expected output:** Only the documented crypto axioms (Ristretto, SHA, Bulletproofs), zero temporary axioms.

If new axioms appear, they're likely from:
- Missing proofs in the container store insertion logic
- Unproved hypotheses in the MoveTo step

### 5.3 Full tree build

Check that downstream files still build:

```bash
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.Refinement
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EndToEnd
```

**Expected:** No changes needed in these files — they consume the public name `registration_eval_equiv_functional_sim` which you just proved, so they should stay green.

### 5.4 Verification suite

Run the full Phase 1 verification:

```bash
./audit/verify-ca.sh --op register --stack lean
```

**Target:** ≤ 3 minutes, zero errors.

---

## 6. Example: minimal singleton-some scaffold

Here's a minimal working scaffold to get started:

```lean
-- In EvalEquivRebuild.lean, after the existing non-singleton proofs

/-- Symbolic state at PC 49 (just before MoveTo). -/
@[irreducible]
def registrationStatePC49 (addr : Address) (store : ConfidentialAssetStore) : Frame :=
  { code := verifyRegistrationProofCode,
    pc := 49,
    locals := #[some (MoveValue.address addr), ..., some (MoveValue.struct [store])],
    localRefs := #[...] }

/-- Step lemma for PC 49: MoveTo instruction. -/
theorem step_pc49_moveTo 
    (addr : Address) (store : ConfidentialAssetStore) (cs : CallStack) (ms : MachineState)
    (h_fresh : ms.containerStore.get? addr = none) :
    step env (registrationStatePC49 addr store) cs ms =
      .ok (registrationStatePC50 addr) cs 
          { ms with containerStore := ms.containerStore.insert addr store } := by
  rw [registrationStatePC49]
  rw [step_moveTo_frame]  -- from StepLemmas.Basic
  simp only [ContainerStore.insert]
  rfl

/-- Symbolic state at PC 50 (after MoveTo). -/
@[irreducible]
def registrationStatePC50 (addr : Address) : Frame :=
  { code := verifyRegistrationProofCode,
    pc := 50,
    locals := #[some (MoveValue.address addr), ..., none],  -- loc 7 consumed
    localRefs := #[...] }

/-- Step lemma for PC 50: Ret. -/
theorem step_pc50_ret (addr : Address) (cs : CallStack) (ms : MachineState) :
    step env (registrationStatePC50 addr) cs ms =
      .returned [] ms := by
  rw [registrationStatePC50]
  rw [step_ret_frame]
  rfl

/-- Singleton-some branch theorem. -/
theorem registration_singleton_some
    (oracle : RegistrationNativeOracle)
    (args : List MoveValue)
    (addr : Address)
    (store : ConfidentialAssetStore)
    (cs : CallStack)
    (ms : MachineState)
    (h_schnorr : oracle.verifySchnorrProof ... = some ...)
    (h_hmac : oracle.verifyHmacProof ... = some ...)
    (h_fresh : ms.containerStore.get? addr = none) :
    run env (registrationInitFrame args) cs ms =
      .returned [] { ms with containerStore := ms.containerStore.insert addr store } := by
  rw [eval_registration_eq_run]
  rw [step_pc0, step_pc1, ..., step_pc48]  -- Pre-MoveTo chain
  rw [step_pc49_moveTo]  -- The mutation point
  rw [step_pc50_ret]     -- Post-MoveTo
  cases h_schnorr
  cases h_hmac
  simp
  rfl
```

**Expand this scaffold** by:
1. Filling in the actual PC numbers (search `verifyRegistrationProofCode`)
2. Adding all the intermediate state helpers
3. Chaining through all PCs before and after the MoveTo

---

## 7. Integration with existing code

### 7.1 Where to add the code

**Location:** `lean/MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean`

**Structure:**
```
EvalEquivRebuild.lean
├── Initial-frame construction (already exists)
├── eval entry-point unfolding (already exists)
├── Symbolic states for each PC (partial, extend with PC 49-50)
├── Step lemmas for each PC (partial, extend with MoveTo + post-MoveTo)
├── Block-level composition (partial, extend with singleton-some)
└── Top-level theorem (currently sorry, replace with case-split)
```

### 7.2 Dependencies

The singleton-some branch needs:
- `MovementFormal.MoveModel.StepLemmas.Basic` (for `step_moveTo_frame`)
- `MovementFormal.MoveModel.ContainerStore` (for `.insert`)
- `MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim` (for `verifyRegistrationBytecodeResult_blockCDE_success`)

All already imported in `EvalEquivRebuild.lean`.

### 7.3 Public API

The only public-facing change is:
```lean
-- OLD (temporary axiom stub):
axiom registration_eval_equiv_functional_sim : ...

-- NEW (proved theorem):
theorem registration_eval_equiv_functional_sim : ... := by
  [proof with case split]
```

No changes to the signature. Downstream files (`Refinement.lean`, `EndToEnd.lean`) reference the name unchanged.

---

## 8. Acceptance criteria

Phase 1 is complete when:

1. **Zero temporary axioms.** Running:
   ```bash
   lake env lean --run scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv
   ```
   Shows only documented crypto axioms (Ristretto, SHA, Bulletproofs), no `registration_eval_equiv_functional_sim` axiom.

2. **Build time under budget.** Running:
   ```bash
   time lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
   ```
   Completes in under 3 minutes.

3. **Full tree builds cleanly.** Running:
   ```bash
   lake build MovementFormal.Experimental.ConfidentialAsset
   ```
   Completes in under 10 minutes with zero errors.

4. **Verification script passes.** Running:
   ```bash
   ./audit/verify-ca.sh --op register --stack lean
   ```
   Exits 0 in under 3 minutes.

5. **No downstream breakage.** Files referencing `registration_eval_equiv_functional_sim` still build unchanged.

---

## 9. Next steps after Phase 1 completion

Once the singleton-some branch is closed:

1. **Update the progress tracker.** Edit `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §0:
   ```diff
   - Phase 1: 🟡 in progress | ... | Outstanding: singleton-some branch
   + Phase 1: ✅ COMPLETE | <commit-sha> | EvalEquivRebuild.lean builds in 2.8s, zero axioms
   ```

2. **Delete the axiom stub.** In `EvalEquiv.lean`, replace:
   ```lean
   axiom registration_eval_equiv_functional_sim : ...
   ```
   With:
   ```lean
   -- Re-export from EvalEquivRebuild
   theorem registration_eval_equiv_functional_sim := EvalEquivRebuild.registration_eval_equiv_functional_sim
   ```

3. **Snapshot the axiom baseline.** Generate the baseline for axiom-diff CI:
   ```bash
   lake env lean --run scripts/check_axioms.sh MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv \
     > audit/registration-axioms-baseline.txt
   ```

4. **Move to Phase 2/4.** With Registration validated on the new architecture, replicate the pattern for the other four `verify_*_proof` operations (Phases 2, 4).

---

## 10. Resources

- **Architecture reference:** `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §4
- **Step-lemma library:** `lean/MovementFormal/MoveModel/StepLemmas/`
- **Existing worked examples:** `ROTATION_PROOF_WORKED_EXAMPLE.md`, `WITHDRAWAL_PROOF_WORKED_EXAMPLE.md`
- **Functional sim reference:** `lean/MovementFormal/Experimental/ConfidentialAsset/Registration/FunctionalSim.lean`
- **Bytecode source:** `lean/MovementFormal/MoveModel/Programs/Registration.lean`

---

## Summary

Completing the singleton-some branch is straightforward but detail-intensive:
1. Identify the MoveTo PC
2. Define pre/post-MoveTo symbolic states
3. Prove the MoveTo step lemma
4. Chain through the remaining PCs
5. Compose into the top-level theorem with a case split

Follow the scaffold in §6, watch the pitfalls in §4, and test incrementally (§5). Target: 200-300 lines, 1-2 days, zero new axioms, builds in under 3 minutes.

Once done, Phase 1 is ✅ COMPLETE and the architecture is validated for Phases 2/4.
