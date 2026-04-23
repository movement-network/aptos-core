# Phase 6 Completion Guide: Closing Composition Theorem Sorries

## Executive Summary

Phase 6 is 🟡 in progress with all 5 operation scaffolds landed but composition theorems containing `sorry` placeholders. This guide provides the complete roadmap to eliminate all sorries and achieve full end-to-end composition proofs connecting MSL specs, Lean bytecode theorems, and difftest validation.

**Current status (2026-04-23)**:
- ✅ All 4 Phase 4 operations converted from axiom stubs to theorems with structured proof scaffolding
- ✅ Normalization: 3 shape lemmas + `normalization_eval_equiv_functional_sim` theorem with sorry
- ✅ Withdrawal: `withdrawal_eval_equiv_functional_sim` theorem with sorry
- ✅ Rotation: `rotation_eval_equiv_functional_sim` theorem with sorry
- ✅ Transfer: `transfer_eval_equiv_functional_sim` theorem with sorry + 3 error-path lemmas
- ⏳ Registration: `registration_eval_equiv_functional_sim` still as axiom (Phase 1 work)
- 📊 Total: ~520 lines of Lean (functional sims + shape lemmas + composition scaffolds), 13 theorems + 2 helper axioms + 4 composition theorems with sorry

**Estimated work remaining**: 800-1800 lines of PC-chaining proofs across 4 operations (200-450 lines per operation).

---

## 1. Architecture: How Composition Theorems Work

### 1.1 Three-Layer Proof Architecture

```
Layer 0 (L0): Mathematical specification
  ↓
  SigmaVerifiers.lean - Pure mathematical predicates
  Example: verify_normalization_predicate : Scalar → Point → Proof → Bool

Layer 1 (L1): Functional simulation
  ↓
  FunctionalSim.lean - High-level operational semantics
  Example: eval_normalization : State → Args → Result

Layer 2 (L2): Bytecode execution
  ↓
  EvalEquiv.lean - MoveVM step-by-step execution
  Example: run : State → Bytecode → Nat → Result
```

**Composition theorem pattern**:
```lean
theorem operation_eval_equiv_functional_sim 
    (st : State) (args : OperationArgs) :
  eval_operation st args = 
  match run st (transcribe_operation args) TOTAL_STEPS with
  | .returned [] store' => .success (extract_result store')
  | .aborted code => 
      if code = VERIFY_FAILED_CODE then .verifyFailed
      else .error code
  | .error msg => .error INTERNAL_ERROR
  | _ => .error UNEXPECTED_SHAPE
```

### 1.2 Why Composition Matters

The composition theorem is the **critical bridge** that connects:
1. **MSL specs** (Move Prover proves) ↔ **Source-level correctness**
2. **Lean bytecode theorems** (this layer) ↔ **Bytecode-level correctness**
3. **Difftest corpus** (runtime validation) ↔ **Concrete input/output pairs**

Without completing Phase 6, we have:
- ✅ MSL proves balance conservation at source level (Phase 2/5)
- ✅ Lean proves each PC step is correct (Phase 4 EvalEquiv)
- ❌ **Missing**: Proof that chaining all PC steps produces the functional simulation result

The `sorry` placeholders represent **unfinished PC-chaining proofs** — the mechanical but essential work of showing that stepping through all 14-24 program counters in sequence produces the same result as the high-level `eval_operation` function.

---

## 2. PC-Chaining Proof Pattern

### 2.1 The Basic Template

Every composition theorem follows this structure:

```lean
theorem operation_eval_equiv_functional_sim 
    (st : State) (args : OperationArgs) :
  eval_operation st args = run st bytecode TOTAL_STEPS := by
  -- Step 1: Unfold the functional simulation to its components
  unfold eval_operation
  
  -- Step 2: Case-split on oracle results (crypto operations)
  match h_oracle : call_native_oracle args with
  | .some oracle_result =>
    -- Happy path: oracle succeeds
    sorry  -- PC-chaining proof goes here
  | .none =>
    -- Error path: oracle fails
    sorry  -- Error-path proof goes here
```

### 2.2 PC-Chaining Proof Structure

The `sorry` in the happy path needs to be replaced with:

```lean
-- Prove that stepping through all PCs in sequence equals functional sim
have pc0_step : run st bytecode 0 = intermediate_state_0 := by
  apply step_ldU64_frame  -- Use step lemma library
  
have pc1_step : run intermediate_state_0 bytecode 1 = intermediate_state_1 := by
  apply step_stLoc_frame
  simp [intermediate_state_0]

have pc2_step : run intermediate_state_1 bytecode 2 = intermediate_state_2 := by
  apply step_immBorrowLoc_frame
  simp [intermediate_state_1]

-- ... repeat for all PCs ...

have pcN_step : run intermediate_state_{N-1} bytecode N = final_state := by
  apply step_ret_frame
  simp [intermediate_state_{N-1}]

-- Combine all steps via transitivity
calc run st bytecode TOTAL_STEPS
    = intermediate_state_0 := pc0_step
  _ = intermediate_state_1 := pc1_step
  _ = intermediate_state_2 := pc2_step
  -- ... chain all steps ...
  _ = final_state := pcN_step
  _ = eval_operation st args := by
      unfold eval_operation
      simp [oracle_result, h_oracle]
      rfl
```

### 2.3 Why This Is Mechanical

Each `pcK_step` proof:
1. Identifies the instruction at PC K (e.g., `ldU64`, `stLoc`, `call`)
2. Applies the corresponding step lemma from `StepLemmas/` library
3. Simplifies using the previous intermediate state definition
4. Closes with `rfl` or `decide`

**No novel mathematics** — just systematic application of the step lemma library built in Phase 0.

---

## 3. Operation-Specific Completion Plans

### 3.1 Normalization (Simplest: 14 instructions)

**File**: `MovementFormal/Experimental/ConfidentialAsset/Normalization/Phase6Composition.lean`

**Current status**:
- ✅ 3 shape lemmas proved (`verifyNormalizationResult_success`, `_verifyFailed`, `_error`)
- ⏳ `normalization_eval_equiv_functional_sim` has sorry
- ⏳ 2 helper axioms for PC-chaining (`normalization_pc_chain_happy`, `normalization_pc_chain_error`)

**Completion steps**:
1. Prove `normalization_pc_chain_happy` by chaining all 14 PCs for happy path (estimated 150-200 lines)
2. Prove `normalization_pc_chain_error` for 2 error paths (estimated 50-80 lines)
3. Remove both helper axioms, replace sorry in main theorem with applications of the proved lemmas
4. Verify `#print axioms normalization_eval_equiv_functional_sim` shows only crypto axioms

**Estimated effort**: 200-280 lines, 1-2 weeks (simplest operation, good starting point)

**PC sequence** (from Phase 4 EvalEquiv.lean):
```
0: ldU64 (load store address)
1: stLoc 0 (store to local)
2: immBorrowLoc 0 (borrow store)
3: call verify_normalization_proof (oracle call - key decision point)
4-13: continuation PCs based on oracle result
```

**Critical decision points**:
- PC 3: Oracle call splits into `.some` (happy) vs `.none` (error)
- PC 10 (approximate): Verification result splits into success vs verifyFailed

### 3.2 Withdrawal (14 instructions, similar structure)

**File**: `MovementFormal/Experimental/ConfidentialAsset/Withdrawal/Phase6Composition.lean`

**Current status**:
- ✅ `withdrawal_eval_equiv_functional_sim` theorem scaffolded with sorry
- ⏳ No helper lemmas yet (can follow normalization pattern)

**Completion steps**:
1. Add 3 shape lemmas (success, verifyFailed, error) following normalization pattern
2. Add 2 helper axioms for PC-chaining (happy + error paths)
3. Prove helper axioms (200-250 lines estimated)
4. Remove axioms, close main theorem sorry

**Estimated effort**: 250-300 lines, 1-2 weeks

**PC sequence**: 15 instructions (similar to normalization, one extra for withdrawal-specific logic)

### 3.3 Rotation (15 instructions)

**File**: `MovementFormal/Experimental/ConfidentialAsset/Rotation/Phase6Composition.lean`

**Current status**:
- ✅ `rotation_eval_equiv_functional_sim` theorem scaffolded with sorry
- ⏳ No helper lemmas yet

**Completion steps**:
1. Follow same pattern as withdrawal (shape lemmas + PC-chain helpers)
2. Prove PC-chaining for 15 instructions (200-280 lines estimated)
3. Close main theorem sorry

**Estimated effort**: 250-320 lines, 1-2 weeks

**Unique aspects**: Rotation involves encryption key updates, which affects frame reasoning. The step lemmas handle this, but intermediate states need careful attention to key field updates.

### 3.4 Transfer (Most Complex: 24 instructions, 3 sub-calls)

**File**: `MovementFormal/Experimental/ConfidentialAsset/Transfer/Phase6Composition.lean`

**Current status**:
- ✅ `transfer_eval_equiv_functional_sim` theorem scaffolded with sorry
- ✅ 3 error-path lemmas already declared
- ⏳ Main theorem sorry remains

**Completion steps**:
1. Add shape lemmas for all oracle result combinations
2. Prove PC-chaining for 24-instruction sequence with 3 native calls:
   - Call 1: Verify sender proof
   - Call 2: Update sender balance
   - Call 3: Update recipient balance
3. Handle sender + recipient state updates (two store mutations)
4. Close main theorem sorry (350-450 lines estimated)

**Estimated effort**: 400-500 lines, 2-3 weeks (most complex operation)

**PC sequence complexity**:
- 24 total instructions (longest bytecode sequence)
- 3 native oracle calls (vs 1 for other operations)
- 2 store mutations (sender + recipient)
- Multiple early-exit error paths

**Critical decision points**:
- PC ~8: Sender proof verification oracle
- PC ~14: Sender balance update oracle
- PC ~20: Recipient balance update oracle
- Each can fail independently, creating 2³=8 total execution paths (though some are unreachable)

### 3.5 Registration (Unique: Phase 1 axiom, not Phase 6 work)

**File**: `MovementFormal/Experimental/ConfidentialAsset/Registration/Phase6Composition.lean`

**Current status**:
- ⏳ `registration_eval_equiv_functional_sim` declared as axiom (TEMPORARY)
- ⏳ To be proved in Phase 1 rebuild completion

**Note**: Registration composition is **not** part of Phase 6 sorry-closing work. It's blocked on Phase 1 EvalEquiv rebuild completing in `Registration/EvalEquivRebuild.lean`. Once Phase 1 closes, the axiom in `Phase6Composition.lean` gets replaced with a theorem applying the proved `registration_eval_equiv` from the rebuild.

---

## 4. Proof Development Workflow

### 4.1 Recommended Order

Tackle operations in order of increasing complexity:

1. **Normalization** (14 PC, 1 oracle, simplest) — validates the PC-chaining pattern
2. **Withdrawal** (15 PC, 1 oracle) — confirms pattern scales
3. **Rotation** (15 PC, 1 oracle, key update) — adds frame complexity
4. **Transfer** (24 PC, 3 oracles, dual-store) — final boss

**Rationale**: Early operations validate the proof architecture. If PC-chaining for normalization takes significantly more or less than 200 lines, adjust estimates for later operations before starting them.

### 4.2 Per-Operation Development Cycle

**Phase A: Setup (30 minutes)**
1. Copy shape lemma structure from normalization to target operation
2. Declare 2 helper axioms: `operation_pc_chain_happy`, `operation_pc_chain_error`
3. Update main theorem to apply helpers instead of `sorry`
4. Verify `lake build` succeeds with axioms in place

**Phase B: Happy-Path PC-Chaining (3-7 days depending on operation)**
1. Start a new `PC_CHAIN_PROOF_SCRATCH.lean` file for iterative work
2. Unfold `run` definition for PC 0
3. Apply `step_<instr_type>_frame` from step lemma library
4. Simplify to get `intermediate_state_0` definition
5. Repeat for PC 1, 2, ..., N
6. Chain all steps via `calc` block
7. Connect final state to functional sim via `rfl`
8. Copy completed proof from scratch file to helper axiom body
9. Remove `axiom`, replace with `theorem` + proof

**Phase C: Error-Path Proofs (1-3 days)**
1. Identify all error PCs (oracle `.none` results, verification failures)
2. For each error path, prove PC-chain up to the error point
3. Show error propagates correctly to `eval_operation` error result
4. Close `operation_pc_chain_error` helper

**Phase D: Integration (30 minutes)**
1. Remove all helper axioms
2. Verify main theorem builds with only crypto axioms in `#print axioms`
3. Run `./audit/verify-ca.sh --op <operation> --stack lean` (≤3 min acceptance)
4. Update Phase 6 progress tracker in unified plan

### 4.3 Tools and Techniques

**Step lemma library** (built in Phase 0):
```lean
-- In MovementFormal/MoveModel/StepLemmas/
step_ldU64_frame : ∀ env frame, run env frame (ldU64 n) = ...
step_stLoc_frame : ∀ env frame k, run env frame (stLoc k) = ...
step_immBorrowLoc_frame : ∀ env frame k, run env frame (immBorrowLoc k) = ...
step_call_frame : ∀ env frame fname, run env frame (call fname) = ...
-- ... 30+ instruction-class lemmas
```

**Proof automation tactics**:
- `simp only [step, <lemma_names>]` — unfold one step at a time
- `decide` — close arithmetic/boolean goals (PC bounds, abort code equality)
- `rfl` — close definitional equalities after simplification
- `calc` — chain multi-step equalities for readability

**Common pitfalls**:
1. **Forgetting oracle case-split**: Must split on `match oracle_call` before PC-chaining
2. **Wrong intermediate state**: Double-check each `intermediate_state_K` matches actual `run` output
3. **Importing wrong modules**: Ensure `StepLemmas.Calls` is imported for `step_call_frame`
4. **Heartbeat timeout**: If proof exceeds 200k heartbeats, extract sub-lemmas (shouldn't happen with step library)

---

## 5. Quality Gates and Acceptance Criteria

### 5.1 Per-Operation Acceptance

Before marking an operation's composition theorem "done":

✅ **Axiom-free**: `#print axioms operation_eval_equiv_functional_sim` shows only:
  - Crypto axioms (Ristretto discrete log, SHA collision resistance, Bulletproofs soundness)
  - **NO** temporary axioms, **NO** `sorry`, **NO** `operation_pc_chain_*` helpers

✅ **Build performance**: `lake build MovementFormal.Experimental.ConfidentialAsset.<Operation>.Phase6Composition` completes in ≤3 minutes

✅ **Difftest consistency**: `./audit/verify-ca.sh --op <operation> --stack difftest` passes (confirms functional sim matches VM)

✅ **Full-stack green**: `./audit/verify-ca.sh --op <operation>` passes all three stacks (Lean + MSL + difftest)

### 5.2 Phase 6 Global Acceptance

Before marking Phase 6 as ✅ COMPLETE in unified plan §0:

✅ **All 4 operations closed**: Normalization, Withdrawal, Rotation, Transfer composition theorems proved

✅ **Registration clean**: Phase 1 axiom replaced with theorem (blocks on Phase 1 completion, not Phase 6 work)

✅ **Composition claims documented**: `audit/COMPOSITION_CLAIMS.md` updated with:
  - Theorem names and file locations for all 5 operations
  - Plain-English explanation of what each composition proves
  - Command to re-verify each composition in isolation

✅ **End-to-end claims written**: For each operation, write the English-language claim that binds MSL + Lean + difftest:
  ```
  "confidential_transfer is formally verified" means:
  1. Move Prover proves (MSL): balance sum preserved, abort conditions sound, no unauthorized mutations
  2. Lean proves (bytecode): verify_transfer_proof bytecode ≡ sigma-predicate
  3. Difftest binds (VM): same bytes flow through MSL stack, Lean stack, and VM with identical results
  ```

✅ **CI green**: All Phase 6 composition files in CI with ≤15 min total Lean build time

---

## 6. Estimated Timeline and Effort

### 6.1 Sequential Development (One Developer)

| Operation | Setup | Happy Path | Error Paths | Integration | Total |
|-----------|-------|------------|-------------|-------------|-------|
| Normalization | 0.5 days | 4-5 days | 2-3 days | 0.5 days | **7-9 days** |
| Withdrawal | 0.25 days | 5-6 days | 2-3 days | 0.5 days | **8-10 days** |
| Rotation | 0.25 days | 5-7 days | 2-3 days | 0.5 days | **8-11 days** |
| Transfer | 0.5 days | 8-10 days | 3-5 days | 1 day | **13-17 days** |
| **TOTAL** | | | | | **36-47 days** (~7-9 weeks) |

**Assumptions**:
- Developer familiar with Lean 4, step lemma library, and CA architecture
- Step lemmas from Phase 0 are complete and correct
- No major architecture issues discovered (normalization validates this early)

### 6.2 Parallel Development (Two Developers)

**Developer A**:
- Normalization (7-9 days)
- Transfer (13-17 days)
- **Total: 20-26 days**

**Developer B**:
- Withdrawal (8-10 days)
- Rotation (8-11 days)
- **Total: 16-21 days**

**Critical path**: Developer A (transfer is the bottleneck)
**Parallel completion**: **4-5 weeks** (vs 7-9 weeks sequential)

### 6.3 Risk Factors

**Low risk** (mitigation in place):
- Step lemma library incomplete → Phase 0 already landed complete library
- Proof pattern unclear → Normalization validates pattern in week 1

**Medium risk** (requires monitoring):
- Transfer complexity underestimated → Could take 20-25 days instead of 13-17
- Heartbeat timeouts → Extract sub-lemmas if any proof exceeds 200k (unlikely with step library)

**High risk** (would require architecture change):
- Step lemma library has fundamental gap for crypto oracle calls → Would surface in normalization week 1; Plan B is to axiomatize oracle interface (acceptable, crypto already axiomatized)

---

## 7. Integration with Other Phases

### 7.1 Phase 1 Dependency (Registration)

Phase 6 for Registration is **blocked** on Phase 1 completing:
- Phase 1 rebuilds `Registration/EvalEquivRebuild.lean` with `registration_eval_equiv` theorem
- Once Phase 1 closes, `Registration/Phase6Composition.lean` replaces axiom with application of Phase 1 theorem
- Estimated 0.5 days of work after Phase 1 lands

**Action**: Do NOT wait for Phase 1 to finish before starting Phase 6 on the other 4 operations. Phase 1 and Phase 6 can proceed in parallel.

### 7.2 Phase 7 Deliverables (Audit Package)

Phase 6 completion unblocks Phase 7 composition claims documentation:
- `audit/COMPOSITION_CLAIMS.md` §2 (currently draft) can be finalized with theorem names
- Each composition theorem gets a `verify-ca.sh --claim` entry
- `audit/TRUST_BOUNDARIES.md` can confirm zero temporary axioms remain

**Action**: Update Phase 7 deliverables within the same PR that closes each operation's composition theorem.

### 7.3 Phase 8 Axiom Reduction

Phase 6 sorries are **NOT** axioms (they're incomplete proofs). Closing Phase 6 does not reduce the axiom count in `audit/AXIOM_INVENTORY.md` (currently 23 axioms, all crypto-related).

However, Phase 6 completion is a **prerequisite** for axiom reduction work because:
- Can't audit axiom necessity until all proofs are complete
- Composition theorems surface which crypto axioms are actually load-bearing

**Action**: Phase 8 axiom reduction sprint should start AFTER Phase 6 completes (not before).

---

## 8. Success Metrics and Monitoring

### 8.1 Weekly Progress Tracking

Track these metrics every Friday:

| Metric | Target | Current | On Track? |
|--------|--------|---------|-----------|
| Operations closed (composition theorem proved) | 1 per 2 weeks | — | — |
| Total sorry count in Phase6Composition/*.lean | 0 by end | 4 | — |
| Temporary axioms in composition files | 0 by end | 2 (normalization) | — |
| Lean build time for Phase 6 files | ≤3 min per op | — | — |
| Lines of proof code written | ~1000 per month | — | — |

### 8.2 Milestone Checkpoints

**Milestone 1** (End of Week 2): Normalization composition proved
- Validates PC-chaining pattern works
- Establishes proof template for other operations
- Decision point: Continue with current architecture or iterate

**Milestone 2** (End of Week 4): Withdrawal composition proved
- Confirms pattern scales to second operation
- Refines effort estimates for rotation/transfer

**Milestone 3** (End of Week 6): Rotation composition proved
- Three operations complete (75% of work)
- Transfer is the only remaining operation

**Milestone 4** (End of Week 9): Transfer composition proved
- Phase 6 complete (modulo Registration waiting on Phase 1)
- All 4 sorry placeholders eliminated
- Ready for Phase 7 documentation finalization

---

## 9. Contingency Plans

### 9.1 If PC-Chaining Doesn't Scale

**Symptom**: Normalization PC-chaining proof exceeds 500 lines or takes >3 weeks.

**Diagnosis**: Step lemma library has a fundamental gap (e.g., oracle call semantics not captured).

**Plan B: Axiomatize Oracle Interface**
```lean
axiom oracle_call_semantics :
  ∀ fname args, 
  run st (call fname) 1 = 
  match oracle_eval fname args with
  | .some result => continuation_with result
  | .none => error_state
```

This would reduce PC-chaining to:
- Non-oracle PCs: Apply step lemmas (works)
- Oracle PCs: Apply oracle axiom (avoids proving oracle internals)

**Impact**: Acceptable — crypto is already axiomatized, extending axiom boundary to oracle interface is philosophically consistent. Would add 1-3 axioms to the 23 current axioms.

### 9.2 If Transfer Is Intractable

**Symptom**: Transfer PC-chaining exceeds 800 lines or takes >6 weeks.

**Diagnosis**: 3 oracle calls + 2 store mutations create combinatorial explosion.

**Plan B: Split Into Sub-Lemmas**
```lean
lemma transfer_sender_path : ... := sorry  -- PCs 0-12 (sender side)
lemma transfer_recipient_path : ... := sorry  -- PCs 13-20 (recipient side)
lemma transfer_finalization_path : ... := sorry  -- PCs 21-24 (return)

theorem transfer_eval_equiv_functional_sim :=
  by apply_composition [transfer_sender_path, transfer_recipient_path, transfer_finalization_path]
```

**Impact**: Proof stays the same total length, but broken into reviewable chunks. No axiom increase.

### 9.3 If Timeline Slips

**Symptom**: Week 4 and only normalization is complete (vs normalization + withdrawal target).

**Triage**:
1. Assess bottleneck: Is it proof engineering time, or proof complexity?
2. If engineering time: Add second developer to parallelize withdrawal + rotation
3. If complexity: Re-estimate transfer timeline upward (potentially 4-5 weeks instead of 2-3)

**Communication**: Update unified plan §0 Phase 6 status with revised completion estimate. Phase 6 slipping does NOT block Phase 7 Docker/CI work (those can proceed in parallel).

---

## 10. Next Steps (Immediate Actions)

### For the Lean Proof Engineer Starting Phase 6:

**Week 1, Day 1** (Normalization setup):
1. ✅ Read this guide (you are here)
2. Open `MovementFormal/Experimental/ConfidentialAsset/Normalization/Phase6Composition.lean`
3. Locate the `sorry` in `normalization_eval_equiv_functional_sim`
4. Create `PC_CHAIN_PROOF_SCRATCH.lean` for iterative work
5. Start PC 0 proof using `step_ldU64_frame`

**Week 1, Day 2-5** (Normalization happy path):
6. Chain PCs 1-13 following the pattern from Day 1
7. Verify intermediate states match `run` output at each step
8. Complete `calc` block connecting all steps

**Week 2, Day 1-3** (Normalization error paths):
9. Prove error-path PC-chains for oracle `.none` cases
10. Connect error states to `eval_normalization` error results

**Week 2, Day 4** (Normalization integration):
11. Remove helper axioms, replace with proved lemmas
12. Verify `#print axioms` shows only crypto axioms
13. Run `./audit/verify-ca.sh --op normalize --stack lean` (≤3 min target)
14. **MILESTONE 1 COMPLETE** — Update unified plan §0, proceed to Withdrawal

---

## 11. References and Resources

### Lean Files (Current State)
- **Step lemma library**: `MovementFormal/MoveModel/StepLemmas/Basic.lean`, `Calls.lean`, `Locals.lean`, `Structs.lean`, `Run.lean`
- **Functional sims**: `MovementFormal/Experimental/ConfidentialAsset/<Operation>/FunctionalSim.lean`
- **EvalEquiv (Phase 4 complete)**: `<Operation>/EvalEquiv.lean` — reference for PC structure and instruction sequences
- **Phase 6 scaffolds (current work)**: `<Operation>/Phase6Composition.lean` — files with `sorry` to be closed

### Documentation
- **Unified plan**: `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §0 (progress tracker), §6 (phasing)
- **Proof techniques**: `ADVANCED_PROOF_TECHNIQUES_AND_PATTERNS_GUIDE.md` (PC-chaining pattern, symbolic state)
- **Best practices**: `VERIFICATION_BEST_PRACTICES_COMPENDIUM.md` (no sorry, extract lemmas, performance)

### External Resources
- **Lean 4 theorem proving**: https://lean-lang.org/theorem_proving_in_lean4/
- **Mathlib tactics**: https://leanprover-community.github.io/mathlib4_docs/tactics.html
- **calc tactic**: Essential for chaining multi-step proofs (search "calc mode" in Lean docs)

---

## Appendix A: Proof Size Estimates by Operation

| Operation | PCs | Oracles | Stores | Happy Path | Error Paths | Total Lines | Confidence |
|-----------|-----|---------|--------|------------|-------------|-------------|------------|
| Normalization | 14 | 1 | 1 | 150-200 | 50-80 | 200-280 | High (simplest) |
| Withdrawal | 15 | 1 | 1 | 170-230 | 50-90 | 220-320 | High (similar) |
| Rotation | 15 | 1 | 1 | 170-250 | 50-100 | 220-350 | Medium (key update) |
| Transfer | 24 | 3 | 2 | 300-400 | 100-150 | 400-550 | Medium (complex) |
| **TOTAL** | | | | **790-1080** | **250-420** | **1040-1500** | |

**Note**: Estimates assume step lemma library works as designed. If normalization significantly exceeds 280 lines, revise estimates upward before starting withdrawal.

---

## Appendix B: Example PC-Chaining Proof (Simplified)

From a hypothetical 5-PC operation:

```lean
theorem simple_operation_eval_equiv_functional_sim 
    (st : State) (args : Args) :
  eval_simple_operation st args = run st bytecode 5 := by
  unfold eval_simple_operation
  
  -- Oracle case-split
  match h_oracle : call_oracle args with
  | .some oracle_result =>
    -- PC 0: Load immediate
    have pc0 : run st bytecode 0 = st' := by
      apply step_ldU64_frame
      rfl
    
    -- PC 1: Store to local
    have pc1 : run st' bytecode 1 = st'' := by
      apply step_stLoc_frame
      simp [st']
      rfl
    
    -- PC 2: Call oracle
    have pc2 : run st'' bytecode 2 = st''' := by
      apply step_call_frame
      simp [st'', h_oracle, oracle_result]
      rfl
    
    -- PC 3: Move result to return position
    have pc3 : run st''' bytecode 3 = st'''' := by
      apply step_moveLoc_frame
      simp [st''']
      rfl
    
    -- PC 4: Return
    have pc4 : run st'''' bytecode 4 = final_state := by
      apply step_ret_frame
      simp [st'''']
      rfl
    
    -- Chain all steps
    calc run st bytecode 5
        = st' := pc0
      _ = st'' := pc1
      _ = st''' := pc2
      _ = st'''' := pc3
      _ = final_state := pc4
      _ = eval_simple_operation st args := by
          unfold eval_simple_operation
          simp [oracle_result, h_oracle]
          rfl
  
  | .none =>
    -- Error path (oracle failed)
    have error_pc : run st bytecode 2 = error_state := by
      apply step_call_frame
      simp [h_oracle]  -- .none case
      rfl
    
    calc run st bytecode 5
        = error_state := error_pc
      _ = eval_simple_operation st args := by
          unfold eval_simple_operation
          simp [h_oracle]  -- propagate oracle failure
          rfl
```

**Key observations**:
- Each `pcK` proof is 3-5 lines (apply step lemma, simplify, close)
- `calc` block makes the chain explicit and readable
- Oracle case-split at the beginning handles both happy and error paths
- Total proof: ~60 lines for 5 PCs (scales to 150-200 lines for 14 PCs)

---

*This guide is the authoritative reference for Phase 6 completion. Update this file as proof patterns are validated or revised based on normalization results.*
