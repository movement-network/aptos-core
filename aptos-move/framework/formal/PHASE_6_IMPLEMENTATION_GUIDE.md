# Phase 6 PC-Chaining Implementation Guide

**Last updated:** 2026-04-22  
**Status:** Phase 6 is 80% complete (4 composition theorem scaffolds exist with sorry placeholders)  
**Outstanding:** PC-chaining proofs for 4 operations (8-12 days estimate)  
**Blocker:** Elaborator performance (workarounds documented in ELABORATOR_PERFORMANCE_WORKAROUNDS.md)

---

## Executive Summary

**Goal:** Complete end-to-end composition theorems binding Lean bytecode proofs to functional specifications for all 4 Phase 4 operations (Normalization, Withdrawal, Transfer, Rotation).

**Current state:**
- ✅ All 4 operations have EvalEquiv files with per-PC step theorems (Phase 4 complete)
- ✅ All 4 operations have Phase6Composition.lean scaffolds with axiom stubs
- 🟡 All 4 composition theorems have sorry placeholders (need PC-chaining proofs)

**What's left:**
- Prove `*_eval_equiv_functional_sim` theorems (one per operation)
- Replace sorry with actual PC-chaining logic
- Eliminate helper axioms used for scaffolding

**Estimated effort:** 8-12 days serial (or 3-4 days with 4 engineers in parallel)

**Key challenge:** Elaborator performance on long PC chains (24 PCs for Transfer). **Solution:** Use sub-lemma splitting (Workaround 1 from ELABORATOR_PERFORMANCE_WORKAROUNDS.md).

---

## Table of Contents

1. [Background](#background)
2. [Architecture Overview](#architecture-overview)
3. [Current State (Per-Operation Status)](#current-state-per-operation-status)
4. [Implementation Strategy](#implementation-strategy)
5. [Normalization (14 PCs)](#normalization-14-pcs)
6. [Withdrawal (15 PCs)](#withdrawal-15-pcs)
7. [Rotation (15 PCs)](#rotation-15-pcs)
8. [Transfer (24 PCs - Most Complex)](#transfer-24-pcs---most-complex)
9. [Testing Strategy](#testing-strategy)
10. [Acceptance Criteria](#acceptance-criteria)

---

## Background

### What is Phase 6?

From the verification plan (§6):

> **Phase 6 — End-to-end composition (2–4 weeks)**  
> Bind Move Prover results and Lean results for a single operation (e.g., `confidential_transfer`) into an English-language claim: "the entry point, as shipped bytecode, preserves balance conservation, respects freeze/allow-list, aborts precisely under the listed conditions, and its embedded proof-verification accepts iff the sigma predicate holds."

Phase 6 creates **composition theorems** that connect:
- **Bytecode-level** proofs (Lean EvalEquiv) ↔ **Functional specifications** (FunctionalSim)

### Why is This Important?

- **EvalEquiv** (Phase 4) proves: "bytecode dispatcher steps match MoveModel.step semantics"
- **FunctionalSim** (Phase 0) defines: "what the operation SHOULD do (mathematical spec)"
- **Phase 6** bridges the two: "bytecode implementation matches mathematical spec"

Without Phase 6, we have:
- ✅ Bytecode is correct w.r.t. VM semantics (EvalEquiv)
- ❌ No guarantee bytecode implements the intended mathematical operation

With Phase 6:
- ✅ Bytecode implements the sigma-verifier predicate (provably correct end-to-end)

---

## Architecture Overview

### File Structure (Per-Operation)

Each operation has 3 files:

```
MovementFormal/Experimental/ConfidentialAsset/<Operation>/
├── FunctionalSim.lean          # Mathematical specification (Phase 0, already done)
├── EvalEquiv.lean              # Bytecode step theorems (Phase 4, already done)
└── Phase6Composition.lean      # Composition theorem (Phase 6, needs completion)
```

### Phase6Composition.lean Structure

```lean
-- Phase6Composition.lean template

import .FunctionalSim
import .EvalEquiv
import MovementFormal.MoveModel.StepLemmas.Run

namespace MovementFormal.Experimental.ConfidentialAsset.<Operation>

-- Step 1: Shape reduction lemmas (functional sim → VM result)
theorem <operation>_shape_success : ... := by sorry
theorem <operation>_shape_verify_failed : ... := by sorry
theorem <operation>_shape_error : ... := by sorry

-- Step 2: Top-level eval↔functional-sim equivalence
theorem <operation>_eval_equiv_functional_sim
    (env : ModuleEnvironment)
    (initialFrame : CallFrame)
    ...
    : eval<Operation> oracle initialFrame = <functional_sim_result> := by
  -- PC-chaining proof goes here
  sorry

-- Step 3: Final composition claim (for auditors)
axiom <operation>_is_formally_verified : <english_claim>

end MovementFormal.Experimental.ConfidentialAsset.<Operation>
```

### Current Status Per-Operation

All 4 operations have this structure with `sorry` placeholders in Step 2 (the PC-chaining proof).

---

## Current State (Per-Operation Status)

### Normalization (14 PCs)

**File:** `MovementFormal/Experimental/ConfidentialAsset/Normalization/Phase6Composition.lean`

**Status:**
- ✅ FunctionalSim defined: `verifyNormalizationBytecodeResult`
- ✅ EvalEquiv complete: 14 per-PC step theorems, builds in ~0.5s
- 🟡 Shape reduction: 3 lemmas scaffolded with sorry
- ❌ PC-chaining: `normalization_eval_equiv_functional_sim` has sorry placeholder

**Outstanding:** PC-chaining proof (14 PCs, estimated 2-3 days)

**Blocker:** None (14 PCs small enough to not hit elaborator bottleneck, but sub-lemma splitting recommended for maintainability)

---

### Withdrawal (15 PCs)

**File:** `MovementFormal/Experimental/ConfidentialAsset/Withdrawal/Phase6Composition.lean`

**Status:**
- ✅ FunctionalSim defined: `verifyWithdrawalBytecodeResult`
- ✅ EvalEquiv complete: 15 per-PC step theorems, builds in ~0.5s
- ❌ Shape reduction: not scaffolded (needs creation)
- ❌ PC-chaining: `withdrawal_eval_equiv_functional_sim` has sorry placeholder

**Outstanding:**
1. Create shape reduction lemmas (1 day)
2. PC-chaining proof (15 PCs, estimated 2-3 days)

**Blocker:** None (15 PCs manageable)

---

### Rotation (15 PCs)

**File:** `MovementFormal/Experimental/ConfidentialAsset/Rotation/Phase6Composition.lean`

**Status:**
- ✅ FunctionalSim defined: `verifyRotationBytecodeResult`
- ✅ EvalEquiv complete: 15 per-PC step theorems, builds in ~0.5s
- ❌ Shape reduction: not scaffolded
- ❌ PC-chaining: `rotation_eval_equiv_functional_sim` has sorry placeholder

**Outstanding:**
1. Create shape reduction lemmas (1 day)
2. PC-chaining proof (15 PCs, estimated 2-3 days)

**Blocker:** None

---

### Transfer (24 PCs - Most Complex)

**File:** `MovementFormal/Experimental/ConfidentialAsset/Transfer/Phase6Composition.lean`

**Status:**
- ✅ FunctionalSim defined: `verifyTransferBytecodeResult`
- ✅ EvalEquiv complete: 24 per-PC step theorems + 3 error paths, builds in ~0.7s
- ❌ Shape reduction: not scaffolded
- ❌ PC-chaining: `transfer_eval_equiv_functional_sim` has sorry placeholder

**Outstanding:**
1. Create shape reduction lemmas (1 day)
2. PC-chaining proof (24 PCs, estimated 3-4 days)

**Blocker:** ⚠️ **Elaborator performance** (24 PCs likely to hit O(N²) bottleneck)  
**Mitigation:** Use sub-lemma splitting (3 sub-lemmas × 8 PCs each)

---

## Implementation Strategy

### Overall Approach

**Use Workaround 4 (defer composition) from ELABORATOR_PERFORMANCE_WORKAROUNDS.md:**

1. **Level 1** (already done): Per-PC step theorems from Phase 4 EvalEquiv
2. **Level 2** (NEW): PC-range sub-lemmas (5-10 PCs each)
3. **Level 3** (NEW): Final composition theorem (chains Level 2 via `run_chain`)

### Why This Works

- Each Level 2 lemma has shallow state chain (≤10 PCs) → fast elaboration
- Level 3 just applies Level 2 lemmas (no bound proofs) → O(1) elaboration
- Total build time: O(N log N) instead of O(N²)

### Effort Breakdown

Per operation:
1. **Shape reduction lemmas:** 1 day (3 lemmas: success, verify-failed, error)
2. **Level 2 PC-range sub-lemmas:** 2-3 days (depends on PC count)
3. **Level 3 composition theorem:** 0.5 day (just chain Level 2)

**Total per operation:** ~3.5-4.5 days

**All 4 operations:**
- **Serial:** 14-18 days
- **Parallel (4 engineers):** 3.5-4.5 days

---

## Normalization (14 PCs)

### Overview

**PCs:** 0-13 (dispatcher + 14 instruction steps)  
**Error paths:** 2 (oracle.result = none, verification failed)  
**Complexity:** LOW (shortest of the 4 operations)

### Step 1: Shape Reduction Lemmas

Already scaffolded in `Normalization/Phase6Composition.lean`:

```lean
theorem normalization_shape_success
    (oracle : NormalizationOracle)
    (h_some : oracle.result.isSome)
    : evalNormalization oracle initialFrame = 
        .returned [] MachineState.empty := by
  -- Pattern: oracle.result = some _ → returned []
  sorry

theorem normalization_shape_verify_failed
    (oracle : NormalizationOracle)
    (h_none : oracle.result.isNone)
    : evalNormalization oracle initialFrame = 
        .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE_value := by
  -- Pattern: oracle.result = none → aborted 65537
  sorry

theorem normalization_shape_error : ... := by
  -- Native call errors (point decompress, etc.)
  sorry
```

**TODO:** Replace `sorry` with actual proofs (1 day).

**Approach:**
1. Unfold `evalNormalization` definition
2. Case-split on `oracle.result` using `h_some`/`h_none`
3. Simplify via FunctionalSim lemmas
4. `rfl` to close goal

---

### Step 2: Level 2 PC-Range Sub-Lemmas

**Split:** 14 PCs → 2 sub-lemmas of 7 PCs each

**Use automation script:**
```bash
./scripts/generate_pc_range_lemmas.sh --operation normalization --pcs 14 --chunk-size 7
```

**Output:** `PCRangeComposition_Normalization.lean` with scaffolds:

```lean
theorem normalization_pcs_0_6
    (env : ModuleEnvironment)
    : MoveModel.run env normalizationState0 cs stack ms 7 =
        .success normalizationState7 cs stack ms := by
  -- Chain step_pc0 through step_pc6 from EvalEquiv.lean
  have h0 := step_pc0 env normalizationState0 ...
  have h1 := step_pc1 env ...
  ...
  have h6 := step_pc6 env ...
  exact run_chain [h0, h1, h2, h3, h4, h5, h6]

theorem normalization_pcs_7_13
    (env : ModuleEnvironment)
    : MoveModel.run env normalizationState7 cs stack ms 7 =
        .success normalizationState14 cs stack ms := by
  -- Chain step_pc7 through step_pc13
  ...
```

**TODO:** Fill in state definitions + proof bodies (2 days).

**State definitions:**
- `normalizationState0`: Initial frame (PC=0)
- `normalizationState7`: Frame after 7 steps (PC=7)
- `normalizationState14`: Final frame (PC=14, .returned [])

**Proof bodies:** Chain existing `step_pc<N>` theorems from `EvalEquiv.lean`.

---

### Step 3: Level 3 Composition Theorem

```lean
theorem normalization_eval_equiv_functional_sim
    (env : ModuleEnvironment)
    (oracle : NormalizationOracle)
    (initialFrame : CallFrame)
    (h_pc : initialFrame.pc = 0)
    (h_fn : initialFrame.function = normalizationFuncIdx)
    ...
    : evalNormalization oracle initialFrame = 
        verifyNormalizationBytecodeResult oracle initialFrame := by
  -- Unfold evalNormalization to run
  simp only [evalNormalization, eval_normalization_eq_run]
  -- Apply Level 2 sub-lemmas
  have h1 := normalization_pcs_0_6 env oracle cs stack ms
  have h2 := normalization_pcs_7_13 env oracle cs stack ms
  -- Chain via run_trans
  have h_full := run_trans h1 h2
  -- Match result to FunctionalSim via shape lemmas
  cases oracle.result with
  | some _ => exact normalization_shape_success oracle ...
  | none => exact normalization_shape_verify_failed oracle ...
```

**TODO:** Implement run_chain/run_trans helpers (0.5 day).

---

### Estimated Timeline

| Task | Effort | Dependencies |
|------|--------|--------------|
| Shape reduction lemmas | 1 day | None |
| Generate PC-range scaffolds | 0.1 day | Automation script |
| Fill in state definitions | 0.5 day | EvalEquiv.lean |
| Prove normalization_pcs_0_6 | 1 day | State defs |
| Prove normalization_pcs_7_13 | 1 day | State defs |
| Composition theorem | 0.5 day | Level 2 lemmas |
| **TOTAL** | **4.1 days** | |

---

## Withdrawal (15 PCs)

### Overview

**PCs:** 0-14 (dispatcher + 15 instruction steps)  
**Error paths:** 2 (oracle.result = none, verification failed)  
**Complexity:** LOW

### Approach

Same as Normalization:
1. Create shape reduction lemmas (not scaffolded yet) — 1 day
2. Generate PC-range scaffolds (15 PCs → 2 sub-lemmas of 7-8 PCs) — 0.1 day
3. Fill in proofs — 2 days
4. Composition theorem — 0.5 day

**Total:** ~3.6 days

---

## Rotation (15 PCs)

### Overview

**PCs:** 0-14 (dispatcher + 15 instruction steps)  
**Error paths:** 2 (oracle.result = none, verification failed)  
**Complexity:** LOW

### Approach

Same as Withdrawal (15 PCs, 2 sub-lemmas, ~3.6 days).

---

## Transfer (24 PCs - Most Complex)

### Overview

**PCs:** 0-23 (dispatcher + 24 instruction steps)  
**Error paths:** 3 (oracle.result = none, verification failed, recipient frozen)  
**Complexity:** **HIGH** (longest PC chain, most error paths)

### Blocker: Elaborator Performance

24 PCs will likely hit O(N²) elaborator bottleneck (see ELABORATOR_PERFORMANCE_WORKAROUNDS.md).

**Mitigation:** Split into 3 sub-lemmas of 8 PCs each.

### Step 1: Shape Reduction Lemmas

Transfer has 3 error paths:

```lean
theorem transfer_shape_success
    (oracle : TransferOracle)
    (h_some : oracle.result.isSome)
    (h_not_frozen : ¬oracle.recipient_frozen)
    : evalTransfer oracle initialFrame = 
        .returned [] MachineState.empty := by
  sorry

theorem transfer_shape_verify_failed
    (oracle : TransferOracle)
    (h_none : oracle.result.isNone)
    : evalTransfer oracle initialFrame = 
        .aborted ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE_value := by
  sorry

theorem transfer_shape_recipient_frozen
    (oracle : TransferOracle)
    (h_frozen : oracle.recipient_frozen)
    : evalTransfer oracle initialFrame = 
        .aborted ERECIPIENT_FROZEN_ABORT_CODE_value := by
  sorry

theorem transfer_shape_error : ... := by
  -- Native errors (decompress, etc.)
  sorry
```

**TODO:** Create these lemmas (not scaffolded yet) — 1 day.

---

### Step 2: Level 2 PC-Range Sub-Lemmas

**Split:** 24 PCs → 3 sub-lemmas of 8 PCs each

**Generate scaffolds:**
```bash
./scripts/generate_pc_range_lemmas.sh --operation transfer --pcs 24 --chunk-size 8
```

**Output:**
```lean
theorem transfer_pcs_0_7 : ... := by sorry
theorem transfer_pcs_8_15 : ... := by sorry
theorem transfer_pcs_16_23 : ... := by sorry
```

**TODO:** Fill in proofs — 3 days (1 day per sub-lemma, since Transfer is complex).

**Key challenges:**
- Transfer has 3 sub-calls (to other CA functions)
- Need to handle sub-call results correctly
- More local variables (sender, recipient, amount, auditor lists)

---

### Step 3: Level 3 Composition Theorem

```lean
theorem transfer_eval_equiv_functional_sim
    (env : ModuleEnvironment)
    (oracle : TransferOracle)
    (initialFrame : CallFrame)
    ...
    : evalTransfer oracle initialFrame = 
        verifyTransferBytecodeResult oracle initialFrame := by
  simp only [evalTransfer, eval_transfer_eq_run]
  have h1 := transfer_pcs_0_7 env oracle ...
  have h2 := transfer_pcs_8_15 env oracle ...
  have h3 := transfer_pcs_16_23 env oracle ...
  have h_full := run_trans (run_trans h1 h2) h3
  -- Match result to FunctionalSim via shape lemmas
  cases oracle.result with
  | some _ =>
      if h : oracle.recipient_frozen then
        exact transfer_shape_recipient_frozen oracle h
      else
        exact transfer_shape_success oracle ... h
  | none => exact transfer_shape_verify_failed oracle ...
```

**TODO:** 0.5 day.

---

### Estimated Timeline

| Task | Effort | Dependencies |
|------|--------|--------------|
| Shape reduction lemmas (4 lemmas) | 1 day | None |
| Generate PC-range scaffolds | 0.1 day | Automation script |
| Fill in state definitions | 0.5 day | EvalEquiv.lean |
| Prove transfer_pcs_0_7 | 1 day | State defs |
| Prove transfer_pcs_8_15 | 1 day | State defs |
| Prove transfer_pcs_16_23 | 1 day | State defs |
| Composition theorem | 0.5 day | Level 2 lemmas |
| **TOTAL** | **5.1 days** | |

---

## Testing Strategy

### Per-Operation Testing

After completing each operation's Phase6Composition.lean:

1. **Build test:**
   ```bash
   lake build MovementFormal.Experimental.ConfidentialAsset.<Operation>.Phase6Composition
   ```
   **Target:** <5s build time (acceptance criterion)

2. **Axiom check:**
   ```bash
   lake env lean --run scripts/check_axioms.sh --file Phase6Composition.lean
   ```
   **Target:** No new axioms (only existing crypto axioms)

3. **Integration test:**
   ```bash
   ./audit/verify-ca.sh --op <operation> --stack lean
   ```
   **Target:** Completes in <3 min

### Cross-Operation Testing

After completing all 4 operations:

1. **Full Lean tree build:**
   ```bash
   cd lean && lake build
   ```
   **Target:** <10 min (full tree, cold build)

2. **Axiom diff:**
   ```bash
   ./scripts/check_axioms.sh --diff
   ```
   **Target:** No drift from baseline (only permanent crypto axioms)

3. **Full verification suite:**
   ```bash
   ./audit/verify-ca.sh
   ```
   **Target:** All 4 operations pass, <6 min total

---

## Acceptance Criteria

### Per-Operation Criteria

For each operation (Normalization, Withdrawal, Rotation, Transfer):

- ✅ `<operation>_eval_equiv_functional_sim` theorem proved (no sorry)
- ✅ All shape reduction lemmas proved (no sorry)
- ✅ Build time: Phase6Composition.lean <5s
- ✅ `#print axioms <operation>_eval_equiv_functional_sim` shows only crypto axioms (no TEMPORARY)
- ✅ `verify-ca.sh --op <operation> --stack lean` passes in <3 min

### Phase 6 Overall Criteria

- ✅ All 4 operations meet per-operation criteria
- ✅ Full Lean tree builds in <10 min cold
- ✅ Axiom baseline unchanged (no new axioms)
- ✅ `verify-ca.sh --coverage` shows 100% Phase 6 completion
- ✅ CLAIMS.md updated with Phase 6 composition claims

---

## Appendices

### Appendix A: Helper Lemmas (run_chain, run_trans)

If not already in `MovementFormal.MoveModel.StepLemmas.Run`, add:

```lean
namespace MoveModel

-- Chain two run steps
theorem run_trans {fuel1 fuel2 : Nat}
    {env : ModuleEnvironment}
    {frame1 frame2 frame3 : CallFrame}
    {cs1 cs2 cs3 : ControlStack}
    {stack1 stack2 stack3 : List Value}
    {ms1 ms2 ms3 : MachineState}
    (h1 : run env frame1 cs1 stack1 ms1 fuel1 = .success frame2 cs2 stack2 ms2)
    (h2 : run env frame2 cs2 stack2 ms2 fuel2 = .success frame3 cs3 stack3 ms3)
    : run env frame1 cs1 stack1 ms1 (fuel1 + fuel2) = .success frame3 cs3 stack3 ms3 := by
  -- Proof uses run_add_fuel lemma
  simp only [run_add_fuel, h1, h2]
  rfl

-- Chain list of run steps
def run_chain : List (run ...) → run ... :=
  List.foldl run_trans
  -- (Actual implementation TBD based on exact run signature)

end MoveModel
```

### Appendix B: Automation Script Usage

**Generate Normalization scaffolds:**
```bash
./scripts/generate_pc_range_lemmas.sh --operation normalization --pcs 14 --chunk-size 7
```

**Generate Transfer scaffolds:**
```bash
./scripts/generate_pc_range_lemmas.sh --operation transfer --pcs 24 --chunk-size 8
```

**Dry-run (print to stdout):**
```bash
./scripts/generate_pc_range_lemmas.sh --operation withdrawal --pcs 15 --chunk-size 8 --dry-run
```

### Appendix C: Common Pitfalls

1. **Forgot @[irreducible] on state definitions**  
   → Elaborator hits O(N²) bottleneck even with sub-lemmas  
   → **Fix:** Add `@[irreducible]` to all `<op>State<N>` definitions

2. **Used Array.get with bound proofs in theorem statements**  
   → Same elaborator issue  
   → **Fix:** Use `Array.get?` in hypotheses (see ELABORATOR_PERFORMANCE_WORKAROUNDS.md)

3. **Monolithic proof (didn't split into sub-lemmas)**  
   → Build takes >10 min, LSP timeouts  
   → **Fix:** Split into sub-lemmas (Workaround 1)

4. **Forgot to import StepLemmas.Run**  
   → `run_trans` / `run_chain` undefined  
   → **Fix:** Add `import MovementFormal.MoveModel.StepLemmas.Run` to Phase6Composition.lean

### Appendix D: Related Documents

- [ELABORATOR_PERFORMANCE_WORKAROUNDS.md](ELABORATOR_PERFORMANCE_WORKAROUNDS.md): Detailed workarounds for elaborator bottleneck
- [PROOF_PATTERNS_LIBRARY.md](PROOF_PATTERNS_LIBRARY.md): Reusable proof patterns
- [PHASE_6_PROGRESS_SUMMARY.md](audit/PHASE_6_PROGRESS_SUMMARY.md): Current status tracker
- [CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md](CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md): §6 (phasing)

---

**End of guide.**
