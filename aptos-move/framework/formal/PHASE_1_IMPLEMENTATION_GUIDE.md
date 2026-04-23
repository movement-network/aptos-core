# Phase 1 Implementation Guide: Registration Singleton Branch

**Goal:** Complete the remaining `sorry` in `Registration/EvalEquivRebuild.lean`  
**Outstanding work:** Singleton-some branch PC-level proof (~200-300 lines estimated)  
**Current status:** All functional-sim reductions complete, all non-singleton PCs proved  
**Difficulty:** Medium-High (container store mutation, PC chaining through mutation)

This guide provides step-by-step instructions, code templates, and proof strategies for completing the Phase 1 Registration rebuild.

---

## Table of Contents

1. [Current Status](#current-status)
2. [Outstanding Work](#outstanding-work)
3. [Architecture Overview](#architecture-overview)
4. [Step-by-Step Implementation](#step-by-step-implementation)
5. [Code Templates](#code-templates)
6. [Common Proof Patterns](#common-proof-patterns)
7. [Testing & Validation](#testing--validation)
8. [Performance Targets](#performance-targets)

---

## Current Status

### What's Complete (✅)

**Symbolic state infrastructure:**
- `@[irreducible]` state definition + projection suite
- PC-lookup lemmas for all 55 instructions
- `eval_registration_eq_run` top-level theorem structure

**Non-singleton branch:**
- All 55 non-native PCs proved
- All 28 native-call happy-path PCs proved
- 10 error-path `_none` variants proved
- Complete functional-sim shape reductions (16 lemmas covering all match trees)

**Functional simulation:**
- Early-error composition theorems (2-PC / 3-PC paths)
- Complete non-singleton branch reduction (`blockE_nonSingleton`)
- All error-path reductions (14 `.error` variants)

**Total progress:**
- **197 theorems** proved
- **Zero `sorry`** in infrastructure (only 1 `sorry` in singleton branch body)
- **Zero axioms** (except TEMPORARY `registration_eval_equiv_functional_sim`)
- **3.0s** build time (within 3-min budget)

### What's Outstanding (🔲)

**Singleton-some branch:**
- PC-level proof for container-store mutation path
- Threading through `KeyAccountId` creation
- Threading through `ContainerStore` update
- Final composition to functional-sim success case

**Estimated scope:**
- ~200-300 lines of Lean
- ~20-30 PC steps (subset of the 55 total)
- ~5-10 new helper lemmas for store mutation

---

## Outstanding Work

### High-Level Structure

The singleton-some branch handles the happy-path case where:
1. Schnorr signature verification succeeds (oracle returns `.some _`)
2. HMAC verification succeeds (oracle returns `.some _`)
3. A new `KeyAccountId` container is created
4. The container is stored in `ContainerStore`
5. Function returns successfully

### Bytecode Flow (Simplified)

```
PC 0-10:  Load arguments, validate inputs
PC 11-25: Schnorr verification oracle call
          → If `.none`: early error (✅ PROVED)
          → If `.some bundle`: continue to HMAC (🔲 OUTSTANDING)
PC 26-40: HMAC verification oracle call
          → If `.none`: early error (✅ PROVED)
          → If `.some keyId`: continue to store creation (🔲 OUTSTANDING)
PC 41-50: Create KeyAccountId container
          → Allocate in ContainerStore
          → Store keyId (🔲 OUTSTANDING)
PC 51-55: Return success
          → Stack cleanup, return `.returned []` (🔲 OUTSTANDING)
```

**Outstanding PCs:** 26-55 (singleton-some path)

---

## Architecture Overview

### Key Insight: Container Store is Pure

The `ContainerStore` mutation is **not** a VM-level side effect — it's a pure functional update of an immutable map:

```lean
def updateContainerStore (cs : ContainerStore) (addr : Address) (container : Container) : ContainerStore :=
  cs.insert addr container
```

**Why this matters:**
- No IO, no memory barriers, no concurrency issues
- Proof is purely equational (rewrite lemmas + `rfl`)
- Similar to proving map insertion preserves invariants

### Proof Strategy: Forward Chaining

**Step 1:** Prove each PC step individually
```lean
theorem step_pc26 : step env (RegistrationState 26 ...) cs ms = ... := by ...
theorem step_pc27 : step env (RegistrationState 27 ...) cs ms = ... := by ...
-- ... (repeat for PC 26-55)
```

**Step 2:** Compose PC steps into larger blocks
```lean
theorem block_schnorr_to_hmac (PC 11-25) : ... := by
  rw [step_pc11, step_pc12, ..., step_pc25]
  rfl

theorem block_hmac_to_store (PC 26-40) : ... := by
  rw [step_pc26, step_pc27, ..., step_pc40]
  rfl

theorem block_store_to_return (PC 41-55) : ... := by
  rw [step_pc41, step_pc42, ..., step_pc55]
  rfl
```

**Step 3:** Compose blocks into singleton-some branch
```lean
theorem singleton_some_branch :
    run env (RegistrationState 0 ...) cs ms =
    .returned [] := by
  rw [block_schnorr_to_hmac, block_hmac_to_store, block_store_to_return]
  simp [registrationFunctionalSim]
  rfl
```

---

## Step-by-Step Implementation

### Step 1: Set Up Working Environment

**Create a scratch file for development:**

```bash
cd aptos-move/framework/formal/lean
cp MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean \
   MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuildScratch.lean
```

**Edit `EvalEquivRebuildScratch.lean`:**
- Focus only on the singleton-some branch
- Comment out other sections to reduce noise
- Add verbose `trace` statements for debugging

**Build incrementally:**
```bash
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuildScratch
```

### Step 2: Identify Singleton-Some Entry Point

**Find the entry point for the singleton-some branch:**

```lean
-- In the top-level theorem eval_registration_eq_run
theorem eval_registration_eq_run : ... := by
  -- ... (early PCs)

  -- PC 25: Schnorr oracle call
  rw [step_pc25_schnorr_call]

  -- Case split on Schnorr oracle result
  cases h_schnorr : schnorrOracle schnorr_args with
  | none =>
      -- Early error (✅ PROVED)
      rw [block_early_error_schnorr]
      rfl
  | some schnorr_bundle =>
      -- Singleton-some branch (🔲 OUTSTANDING)
      sorry  -- ← START HERE
```

**Your task:** Replace the `sorry` with the PC-chaining proof.

### Step 3: Prove PC Steps for HMAC Block (PC 26-40)

**Template for each PC step:**

```lean
theorem step_pc26
    {env : ModuleEnvironment}
    {schnorr_bundle : SchnorrBundle}
    {cs : ContainerStore}
    {ms : MemoryStore}
    (h_schnorr : schnorrOracle ... = .some schnorr_bundle)
    : step env (RegistrationState 26 ... [.some schnorr_bundle]) cs ms =
      StepResult.continue
        (RegistrationState 27 ... [...])
        cs ms := by
  simp only [step, RegistrationState]
  rw [step_moveLoc_frame]  -- Or appropriate step lemma
  simp [h_schnorr]
  rfl
```

**Repeat for PC 27-40.** Most will be `ImmBorrowLoc`, `MoveLoc`, `Call` instructions.

**Compose into block:**

```lean
theorem block_hmac_verification
    {env : ModuleEnvironment}
    {schnorr_bundle : SchnorrBundle}
    {cs : ContainerStore}
    {ms : MemoryStore}
    (h_schnorr : schnorrOracle ... = .some schnorr_bundle)
    : run env (RegistrationState 26 ... [.some schnorr_bundle]) cs ms =
      -- After HMAC call at PC 40
      StepResult.continue
        (RegistrationState 41 ... [.some keyId])
        cs ms' := by
  rw [step_pc26, step_pc27, ..., step_pc40_hmac_call]
  -- Case split on HMAC oracle
  cases h_hmac : hmacOracle ... with
  | none =>
      -- HMAC error (already handled in error paths)
      sorry
  | some keyId =>
      -- Happy path
      simp [h_hmac]
      rfl
```

### Step 4: Prove PC Steps for Container Store Creation (PC 41-50)

**Key PC: Allocate container**

```lean
theorem step_pc41_allocate_container
    {env : ModuleEnvironment}
    {keyId : KeyId}
    {cs : ContainerStore}
    {ms : MemoryStore}
    (h_hmac : hmacOracle ... = .some keyId)
    : step env (RegistrationState 41 ... [.some keyId]) cs ms =
      StepResult.continue
        (RegistrationState 42 ... [...])
        cs' ms' := by
  simp only [step, RegistrationState]
  -- Allocate new container in ContainerStore
  rw [step_allocateContainer_frame]  -- Hypothetical step lemma (may need to add)
  simp [h_hmac]
  -- cs' = cs.insert newAddr newContainer
  rfl
```

**Key PC: Store KeyAccountId**

```lean
theorem step_pc45_store_keyId
    {env : ModuleEnvironment}
    {keyId : KeyId}
    {containerAddr : Address}
    {cs : ContainerStore}
    {ms : MemoryStore}
    (h_container : cs.get? containerAddr = .some emptyContainer)
    : step env (RegistrationState 45 ... [.ref containerAddr]) cs ms =
      StepResult.continue
        (RegistrationState 46 ... [...])
        cs'' ms' := by
  simp only [step, RegistrationState]
  -- Update container with keyId
  rw [step_storeField_frame]  -- Store keyId into container field
  simp [h_container]
  -- cs'' = cs.update containerAddr (λ c => { c with keyId := keyId })
  rfl
```

**Compose into block:**

```lean
theorem block_store_creation
    {env : ModuleEnvironment}
    {keyId : KeyId}
    {cs : ContainerStore}
    {ms : MemoryStore}
    (h_hmac : hmacOracle ... = .some keyId)
    : run env (RegistrationState 41 ... [.some keyId]) cs ms =
      StepResult.continue
        (RegistrationState 51 ... [...])
        cs_final ms_final := by
  rw [step_pc41_allocate_container,
      step_pc42, step_pc43, step_pc44,
      step_pc45_store_keyId,
      step_pc46, ..., step_pc50]
  simp [h_hmac]
  rfl
```

### Step 5: Prove PC Steps for Return (PC 51-55)

**Template:**

```lean
theorem step_pc51_cleanup
    {env : ModuleEnvironment}
    {cs : ContainerStore}
    {ms : MemoryStore}
    : step env (RegistrationState 51 ... [...]) cs ms =
      StepResult.continue (RegistrationState 52 ... [...]) cs ms := by
  simp only [step, RegistrationState]
  rw [step_pop_frame]  -- Or appropriate step lemma
  rfl

-- ... (repeat for PC 52-54)

theorem step_pc55_return
    {env : ModuleEnvironment}
    {cs : ContainerStore}
    {ms : MemoryStore}
    : step env (RegistrationState 55 ... []) cs ms =
      StepResult.returned [] := by
  simp only [step, RegistrationState]
  rfl  -- Ret instruction with empty stack
```

**Compose into block:**

```lean
theorem block_return
    {env : ModuleEnvironment}
    {cs : ContainerStore}
    {ms : MemoryStore}
    : run env (RegistrationState 51 ... [...]) cs ms =
      StepResult.returned [] := by
  rw [step_pc51_cleanup, step_pc52, step_pc53, step_pc54, step_pc55_return]
  rfl
```

### Step 6: Compose Blocks into Singleton-Some Branch

**Top-level composition:**

```lean
theorem singleton_some_branch
    {env : ModuleEnvironment}
    {schnorr_bundle : SchnorrBundle}
    {keyId : KeyId}
    {cs : ContainerStore}
    {ms : MemoryStore}
    (h_schnorr : schnorrOracle ... = .some schnorr_bundle)
    (h_hmac : hmacOracle ... = .some keyId)
    : run env (RegistrationState 0 ... [...]) cs ms =
      StepResult.returned [] := by
  -- Chain through all blocks
  rw [block_entry,                    -- PC 0-25 (already proved)
      step_pc25_schnorr_call,
      block_hmac_verification,        -- PC 26-40 (Step 3)
      block_store_creation,           -- PC 41-50 (Step 4)
      block_return]                   -- PC 51-55 (Step 5)
  simp [h_schnorr, h_hmac]
  rfl
```

### Step 7: Plug into Top-Level Theorem

**Update `eval_registration_eq_run`:**

```lean
theorem eval_registration_eq_run : ... := by
  -- ... (early PCs)

  -- Case split on Schnorr oracle result
  cases h_schnorr : schnorrOracle schnorr_args with
  | none =>
      rw [block_early_error_schnorr]
      rfl
  | some schnorr_bundle =>
      -- Case split on HMAC oracle result
      cases h_hmac : hmacOracle hmac_args with
      | none =>
          rw [block_early_error_hmac]
          rfl
      | some keyId =>
          -- Singleton-some branch (🎉 COMPLETE)
          rw [singleton_some_branch h_schnorr h_hmac]
          simp [registrationFunctionalSim]
          rfl
```

---

## Code Templates

### Template: Per-PC Step Theorem

```lean
theorem step_pcN
    {env : ModuleEnvironment}
    -- Named implicits for current state
    {var1 var2 : Type}
    {cs : ContainerStore}
    {ms : MemoryStore}
    -- Hypotheses (from previous PCs or oracle calls)
    (h_oracle : oracleCall ... = .some result)
    (h_state : currentState.field = expectedValue)
    : step env (RegistrationState N ... stackBefore) cs ms =
      StepResult.continue
        (RegistrationState (N+1) ... stackAfter)
        cs' ms' := by
  simp only [step, RegistrationState]
  rw [step_INSTRUCTION_CLASS_frame]  -- Apply appropriate step lemma
  simp [h_oracle, h_state]
  -- Prove cs' = ... and ms' = ... if modified
  rfl
```

### Template: Block Composition

```lean
theorem block_NAME
    {env : ModuleEnvironment}
    {var1 var2 : Type}
    {cs : ContainerStore}
    {ms : MemoryStore}
    (h_entry : entryCondition)
    : run env (RegistrationState PC_START ... stackStart) cs ms =
      StepResult.continue
        (RegistrationState PC_END ... stackEnd)
        cs_final ms_final := by
  rw [step_pcSTART,
      step_pcSTART_PLUS_1,
      -- ... (all PCs in block)
      step_pcEND]
  simp [h_entry]
  -- Prove cs_final = ... and ms_final = ... if modified
  rfl
```

### Template: Oracle Case Split

```lean
-- In a block or top-level theorem
cases h_oracle : oracleCall args with
| none =>
    -- Error path
    rw [block_error_path]
    simp [h_oracle]
    rfl
| some result =>
    -- Happy path
    rw [block_happy_path h_oracle]
    simp [h_oracle]
    rfl
```

---

## Common Proof Patterns

### Pattern 1: Threading a Value Through PCs

**Scenario:** Oracle returns a value at PC N; you need it at PC M (M > N).

**Strategy:** Add hypothesis to each intermediate step.

```lean
theorem step_pcN : oracleCall ... = .some val → ... := by ...
theorem step_pcN_PLUS_1 (h : oracleCall ... = .some val) : ... := by
  simp [h]  -- val is now available
  rfl
```

### Pattern 2: Container Store Mutation

**Scenario:** Allocate or update a container.

**Strategy:** Track `cs` changes explicitly.

```lean
-- Before mutation
(cs : ContainerStore)

-- After mutation (allocate)
(cs' : ContainerStore)
(h_allocate : cs' = cs.insert newAddr newContainer)

-- After mutation (update)
(cs'' : ContainerStore)
(h_update : cs'' = cs'.update addr (λ c => { c with field := val }))
```

**Proof:**
```lean
simp [h_allocate, h_update]
-- Prove properties about cs''
rfl
```

### Pattern 3: Stack Manipulation Across PCs

**Scenario:** Value pushed at PC N, popped at PC M.

**Strategy:** Track stack explicitly in state.

```lean
-- PC N: Push val
RegistrationState N ... [val, ...rest]

-- PC N+1: Val still on stack
RegistrationState (N+1) ... [val, ...rest]

-- PC M: Pop val
RegistrationState M ... [...rest]
```

**Proof:**
```lean
simp only [RegistrationState_stack]
-- Pattern-match on stack structure
rfl
```

---

## Testing & Validation

### Incremental Build Checks

After each step, build and check for errors:

```bash
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuildScratch
```

**Expected output:**
- ✅ Compiles successfully
- ⚠️ Warnings OK (unused variables, etc.)
- ❌ Errors → fix before continuing

### Axiom Check

After completing the singleton-some branch, verify no new axioms were introduced:

```bash
cd lean
lake env lean --run scripts/check_axioms.lean MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
```

**Expected output:**
```
Axioms in MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild:
  - registration_eval_equiv_functional_sim (TEMPORARY - to be removed)
  - <crypto axioms from upstream>

Total new axioms: 0 ✅
```

### Difftest Validation

Once the proof is complete, validate against difftest corpus:

```bash
cd ../../move-lean-difftest
./difftest.sh --suite confidential_asset --filter registration
```

**Expected output:**
```
Running difftest for registration...
  ✅ registration_happy_path_001: PASS
  ✅ registration_error_schnorr_failed: PASS
  ✅ registration_error_hmac_failed: PASS
  ... (all tests PASS)

Summary: 15/15 tests PASS ✅
```

### Performance Validation

Check that build time stays within budget:

```bash
time lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
```

**Expected output:**
```
...
real    0m3.2s   ✅ (within 3-min budget)
user    0m2.8s
sys     0m0.4s
```

---

## Performance Targets

### Per-Section Budgets

| Section | PCs | Estimated Build Time | Status |
|---------|-----|----------------------|--------|
| Entry block (PC 0-10) | 11 | 0.3s | ✅ Complete |
| Schnorr block (PC 11-25) | 15 | 0.5s | ✅ Complete |
| HMAC block (PC 26-40) | 15 | 0.5s | 🔲 Outstanding |
| Store creation (PC 41-50) | 10 | 0.4s | 🔲 Outstanding |
| Return block (PC 51-55) | 5 | 0.2s | 🔲 Outstanding |
| Top-level composition | - | 0.3s | 🔲 Outstanding |
| **Total** | **55** | **~2.2-2.5s** | **Target: ≤3.0s** |

### Regression Prevention

If any section exceeds its budget:

1. **Profile with heartbeats:**
   ```lean
   set_option profiler true in
   theorem expensive_theorem : ... := by ...
   ```

2. **Check for anti-patterns:**
   - Chained state definitions? → Use symbolic state
   - Bare `simp`? → Use `simp only [...]`
   - Bound proofs in statements? → Use `Array.get?`

3. **Refactor:**
   - Break into smaller lemmas
   - Apply step-lemma library more aggressively
   - Add `@[simp]` lemmas for common patterns

---

## Troubleshooting

### Error: "Type mismatch in stack"

**Symptom:**
```
expected: [.ref proofRef, .ref inputsRef]
got:      [.ref inputsRef, .ref proofRef]
```

**Cause:** Stack order is backwards.

**Fix:** Check PC step theorems — ensure stack is built in the correct order (LIFO).

### Error: "Failed to unify ContainerStore"

**Symptom:**
```
expected: cs'
got:      cs
```

**Cause:** Forgot to track container store mutation.

**Fix:** Add `cs'` to theorem statement and hypothesis `h_cs : cs' = cs.insert ...`.

### Error: "Unknown identifier 'oracleResult'"

**Symptom:**
```
unknown identifier 'oracleResult'
```

**Cause:** Forgot to add hypothesis for oracle call.

**Fix:** Add `(h_oracle : oracleCall ... = .some oracleResult)` to theorem.

### Error: "Timeout (deterministic timeout)"

**Symptom:**
```
(deterministic) timeout at 'typeclass', maximum number of heartbeats (200000) has been reached
```

**Cause:** Lean is unfolding too much (likely chained state or bound proofs).

**Fix:**
1. Check for chained state definitions → use symbolic state
2. Check for bound proofs in statements → use `Array.get?`
3. Add `@[irreducible]` to state definition if missing

---

## Next Steps

### After Completing Singleton-Some Branch

1. **Remove TEMPORARY axiom:**
   ```lean
   -- Delete this line:
   axiom registration_eval_equiv_functional_sim : ...

   -- It's now proved!
   ```

2. **Run full axiom check:**
   ```bash
   ./scripts/check_axioms.sh
   ```
   Expect: **0 new axioms** (only upstream crypto axioms remain).

3. **Update Phase 1 status:**
   Edit `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`:
   ```diff
   - | 1 | Registration rebuilt | 🟡 in progress | ...
   + | 1 | Registration rebuilt | ✅ done | <commit-SHA> | 3.0s build, 197 theorems, 0 axioms
   ```

4. **Run verify-ca.sh:**
   ```bash
   ./audit/verify-ca.sh --op register --stack lean
   ```
   Expect: **PASS** in ≤3 min.

5. **Create PR:**
   - Title: `Phase 1: Complete Registration rebuild (singleton-some branch)`
   - Body: Link to this guide, metrics (build time, theorem count, axiom count)
   - Reviewers: Tag formal verification team

---

## Summary

**Estimated effort:** 1-2 days (200-300 lines of Lean)  
**Difficulty:** Medium-High (container store mutation, PC chaining)  
**Payoff:** Phase 1 complete → unblocks all future Phase 4 operations  
**Architecture validation:** Proves that symbolic state + step-lemma library scales to complex operations

**Success criteria:**
- ✅ Zero `sorry` in `EvalEquivRebuild.lean`
- ✅ Zero new axioms (only TEMPORARY axiom removed)
- ✅ Build time ≤3.0s
- ✅ All difftest tests PASS
- ✅ `verify-ca.sh --op register --stack lean` completes in ≤3 min

**Questions?** See:
- `PROOF_PATTERNS_LIBRARY.md` for Lean proof patterns
- `PERFORMANCE_OPTIMIZATION_GUIDE.md` for debugging slow builds
- `CONTRIBUTING_TO_CA_VERIFICATION.md` for workflow and PR process

---

**File:** `PHASE_1_IMPLEMENTATION_GUIDE.md`  
**Lines:** ~750  
**Purpose:** Step-by-step guide for completing Phase 1 Registration singleton branch  
**Audience:** Developers working on Phase 1, reviewers auditing implementation  
**Cross-references:** `EvalEquivRebuild.lean`, `PROOF_PATTERNS_LIBRARY.md`, `PERFORMANCE_OPTIMIZATION_GUIDE.md`
