# Phase 6 Master Coordination Guide — Complete All Composition Proofs

**Purpose:** Systematic roadmap to close all 4 Phase 6 composition theorem sorry placeholders  
**Timeline:** 3-5 weeks (sequential) or 2-3 weeks (2 developers in parallel)  
**Status:** 0/4 complete (all have sorry scaffolds, 0 have complete proofs)

---

## Executive Summary

**What is Phase 6?**  
Phase 6 connects the Phase 4 bytecode-level theorems (EvalEquiv) to the functional simulation layer. Each operation has a composition theorem stating: "bytecode execution via `eval` equals functional simulation result."

**Why does it matter?**  
Without Phase 6, we have:
- ✅ Bytecode step theorems (prove each instruction works correctly)
- ❌ NO end-to-end claim that the full bytecode sequence matches functional semantics

With Phase 6 complete:
- ✅ End-to-end claim: `eval verify_X_proof ≡ functional_sim_result`
- ✅ Enables composition with MSL specs (MSL talks about functional semantics)
- ✅ Closes the verification loop: MSL ↔ Lean ↔ Difftest

---

## Current State (2026-04-23)

### Operation Status Matrix

| Operation | PCs | Step Theorems | Helpers Needed | Main Theorem | Est. Lines | Priority |
|-----------|-----|---------------|----------------|--------------|------------|----------|
| **Normalization** | 14 | ✅ 14/14 | 2 (1 axiom, 1 sorry) | sorry | 250-300 | **HIGH** |
| **Withdrawal** | 15 | ✅ 15/15 | 1 (TBD) | sorry | 250-300 | **HIGH** |
| **Rotation** | 15 | ✅ 15/15 | 1 (TBD) | sorry | 250-320 | MEDIUM |
| **Transfer** | 24 | ✅ 24/24 | 2-3 (TBD) | sorry | 400-500 | LOW* |

\* Transfer is lowest priority because it's the most complex; validate approach on simpler ops first.

**Total Phase 6 sorry debt:** 4 theorems + 4-7 helper theorems = ~1,500-1,800 lines

---

## Recommended Completion Order

### **Week 1-2: Normalization (FIRST)**

**Why first:**
- Simplest (14 PCs, 1 oracle split point)
- Already has detailed implementation guide (see `NORMALIZATION_PHASE6_COMPLETE_PROOF_IMPLEMENTATION.md`)
- Validates the PC-chaining proof pattern for other ops

**Work items:**
1. ✅ Read `NORMALIZATION_PHASE6_COMPLETE_PROOF_IMPLEMENTATION.md` (already created)
2. ⏳ Resolve stack state discrepancy in `norm_run_pc5_to_pc8` (blocker)
3. ⏳ Prove `norm_run_pc5_to_pc8` (80-100 lines)
4. ⏳ Prove `norm_run_pc0_to_pc5_locals_property` helper (30-40 lines)
5. ⏳ Complete main composition `normalization_eval_equiv_functional_sim` (150-200 lines)
6. ⏳ Build and verify ≤3s build time
7. ⏳ Update unified plan Phase 6 status

**Deliverable:** Normalization EvalEquiv with 0 sorry, 1 temporary axiom (`norm_run_pc0_to_pc5`)

**Timeline:** 1-2 weeks (1 developer) or 4-5 days (2 developers)

---

### **Week 2-3: Withdrawal (SECOND)**

**Why second:**
- Similar complexity to Normalization (15 PCs)
- Additional parameter (`amount : UInt64`) but same oracle pattern
- Implementation guide already created (see `WITHDRAWAL_PHASE6_COMPLETE_PROOF_IMPLEMENTATION.md`)

**Work items:**
1. ✅ Read `WITHDRAWAL_PHASE6_COMPLETE_PROOF_IMPLEMENTATION.md` (already created)
2. ⏳ Run `./scripts/extract_stack_evolution.sh withdrawal` to generate stack table
3. ⏳ Audit bytecode sequence for PCs 10-12 (resolve blocker)
4. ⏳ Decide: single helper `withdrawal_run_pc0_to_pc9` OR split helpers
5. ⏳ Prove helper(s) (100-150 lines)
6. ⏳ Complete main composition (150-200 lines)
7. ⏳ Build and verify ≤3s build time

**Deliverable:** Withdrawal EvalEquiv with 0 sorry, 0-1 temporary axioms

**Timeline:** 1-2 weeks (1 developer) or 4-5 days (2 developers)

---

### **Week 3-4: Rotation (THIRD)**

**Why third:**
- Same PC count as Withdrawal (15 PCs)
- Different oracle arguments but same structural pattern
- Can reuse proof strategies from Normalization + Withdrawal

**Work items:**
1. ⏳ Create implementation guide (follow Withdrawal template)
2. ⏳ Run stack evolution extractor
3. ⏳ Prove helpers (100-150 lines)
4. ⏳ Complete main composition (150-200 lines)
5. ⏳ Build and verify ≤3s build time

**Deliverable:** Rotation EvalEquiv with 0 sorry, 0-1 temporary axioms

**Timeline:** 1-2 weeks (1 developer) or 4-5 days (2 developers)

---

### **Week 4-5: Transfer (LAST)**

**Why last:**
- Most complex (24 PCs, 3 oracle split points)
- Needs 2-3 helper theorems to manage proof size
- Benefits from lessons learned on simpler ops

**Work items:**
1. ⏳ Create implementation guide
2. ⏳ Run stack evolution extractor
3. ⏳ Design helper theorem decomposition (split at oracle boundaries)
4. ⏳ Prove 2-3 helpers (200-300 lines)
5. ⏳ Complete main composition (200-300 lines)
6. ⏳ Build and verify ≤3s build time

**Deliverable:** Transfer EvalEquiv with 0 sorry, 0-2 temporary axioms

**Timeline:** 1.5-2 weeks (1 developer) or 5-7 days (2 developers)

---

## Proof Pattern Template

All 4 operations follow the same proof structure:

```lean
theorem <operation>_eval_equiv_functional_sim
    (o : <Operation>ModuleOracle)
    (params : ...)
    (fuel : Nat)
    (hfuel : fuel ≥ TOTAL_PCS) :
    (eval env idx args fuel initMs).dropMs =
    match functional_sim o params with
    | .returned ms => .returned [] ms
    | .error => .error := by
  -- Step 1: Unfold eval to run
  rw [eval_<operation>_eq_run]
  
  -- Step 2: Chain initial PCs using helper (up to first oracle call)
  have h_helper1 := <operation>_run_pc0_to_pcN ...
  rw [h_helper1]
  
  -- Step 3: Oracle case split
  generalize h_oracle : o.oracleCall args = oracleResult
  cases oracleResult with
  | none =>
    -- Error path: apply error step theorem + connect to functional sim
    have step_err := step_<operation>_pcN_none ...
    rw [run_succ_error_of_step _ step_err]
    unfold functional_sim
    simp only [h_oracle]
    rfl
  
  | some res =>
    cases res with
    | nil =>
      -- Success path: continue chaining PCs
      have step_ok := step_<operation>_pcN ...
      rw [run_succ_ok_of_step _ _ _ _ _ step_ok]
      
      -- Chain remaining PCs (may need another helper)
      <continue chaining>
      
      -- If another oracle: repeat case split pattern
      
      -- Final ret: connect to .returned
      have step_ret := step_<operation>_pcRET ...
      rw [run_succ_returned_of_step _ _ _ step_ret]
      unfold functional_sim
      simp only [h_oracle, ...]
      rfl
    
    | cons _ _ =>
      -- Arity mismatch: connect to .error
      <handle arity error>
```

---

## Helper Theorem Design Patterns

### Pattern 1: Bundled PC-Chain Helper (Normalization style)

**When to use:** Short PC sequences (≤8 PCs) with no oracle splits

**Example:**
```lean
theorem <op>_run_pcA_to_pcB
    (params : ...)
    (fuel : Nat)
    (hfuel : fuel ≥ (B - A)) :
    run env frameA cs stackA msA fuel =
    run env frameB cs stackB msB (fuel - (B - A)) := by
  -- Chain all PCs individually using run_succ_ok_of_step
  <proof body>
```

**Advantages:**
- Single sorry/axiom to close
- Clean separation in main theorem

**Disadvantages:**
- Harder to debug (all PCs in one proof)
- Longer to prove initially

---

### Pattern 2: Split Helpers (Transfer style)

**When to use:** Long PC sequences (>8 PCs) or natural breakpoints at oracle calls

**Example:**
```lean
-- Helper 1: Setup (PCs 0-7)
theorem <op>_run_pc0_to_pc8 ...

-- Helper 2: First verification (PCs 8-15, assuming oracle at PC 8)
theorem <op>_run_pc8_to_pc16 ...

-- Helper 3: Second verification (PCs 16-23, assuming oracle at PC 16)
theorem <op>_run_pc16_to_pc24 ...
```

**Advantages:**
- Easier to debug (smaller proof chunks)
- Parallelizable (different developers)

**Disadvantages:**
- More axioms to track
- More theorem boilerplate

---

### Pattern 3: Locals Property Helpers (Supplemental)

**When to use:** Helper theorems (Pattern 1 or 2) produce existential witnesses (e.g., `∃ locals5, ...`)

**Example:**
```lean
theorem <op>_run_pc0_to_pcN_locals_property
    (h_witness : <helper theorem applied>) :
    locals_N[K] = some expected_value ∧
    locals_N[K'] = some expected_value' := by
  -- Derive properties from witness structure
  <proof>
```

**Why needed:** Main composition theorem needs to prove hypotheses for later step theorems

---

## Automation Tools Reference

### 1. PC-Chaining Proof Scaffold Generator

**Script:** `scripts/generate_pc_chain_proof.sh`

**Usage:**
```bash
./scripts/generate_pc_chain_proof.sh normalization 5 8 > pc5_to_pc8_scaffold.lean
```

**Output:** Structured proof skeleton with sorry placeholders for each PC

**When to use:** Starting a new helper theorem from scratch

---

### 2. Stack Evolution Extractor

**Script:** `scripts/extract_stack_evolution.sh`

**Usage:**
```bash
./scripts/extract_stack_evolution.sh withdrawal > WITHDRAWAL_STACK_EVOLUTION.md
```

**Output:** Markdown table showing stack state at each PC

**When to use:** Before writing main composition proof (prevents stack tracking errors)

---

### 3. Axiom Diff Guard (CI)

**Script:** Already in CI via `axiom-diff-ca.yaml`

**Purpose:** Alerts if new axioms appear (catches accidental sorry → axiom conversion)

**Manual check:**
```bash
./audit/verify-ca.sh --coverage | grep "axiom"
```

---

## Common Pitfalls and Solutions

### Pitfall 1: Stack State Mismatch

**Symptom:** Proof fails at `rw [run_succ_ok_of_step ...]` with type mismatch

**Cause:** Stack evolution tracking error (wrong number/order of values)

**Solution:**
1. Run `./scripts/extract_stack_evolution.sh <op>` to generate truth table
2. Compare proof's `stackN` against table
3. Fix discrepancy

---

### Pitfall 2: Locals Mutation Tracking

**Symptom:** `hlocals_at_K` hypothesis fails in later PCs

**Cause:** `moveLoc K` sets `locals[K] := none`, forgot to update witness

**Solution:**
```lean
-- After moveLoc K, create new locals witness
set localsN' := localsN.set K none (by omega)

-- Prove other indices unchanged
have hlocals_at_K' : localsN'[K'] = some val := by
  unfold localsN'
  simp [Array.get_set_ne (by omega : K ≠ K')]
  exact hlocals_at_K
```

---

### Pitfall 3: Container Allocation Threading

**Symptom:** `ms.containers` mismatch after `immBorrowField`

**Cause:** Forgot to thread `containers'` from alloc through subsequent steps

**Solution:**
```lean
-- Capture alloc result
generalize halloc : ms.containers.alloc val = allocRes
obtain ⟨cs', fid⟩ := allocRes

-- Thread cs' through all subsequent steps
set msN' := { msN with containers := cs' }
```

---

### Pitfall 4: Fuel Arithmetic Errors

**Symptom:** `omega` fails on fuel bounds, or `hfuel : fuel ≥ N` doesn't match

**Cause:** Miscounted PCs or wrong decomposition

**Solution:**
```bash
# Count PCs in bytecode
grep "theorem step_<op>_pc" <EvalEquiv.lean> | wc -l

# Verify total in code_size lemma
grep "code_size.*= [0-9]" <EvalEquiv.lean>
```

---

## Testing and Validation Checklist

After completing each operation's Phase 6 proof:

- [ ] **Build time:** `time lake build MovementFormal...EvalEquiv` ≤ 3 seconds
- [ ] **Axiom count:** `./audit/verify-ca.sh --coverage` shows expected axioms only
- [ ] **No sorry:** `grep -c sorry <EvalEquiv.lean>` returns 0
- [ ] **CI green:** Push branch, wait for `lean-ca` job to pass
- [ ] **Verify-ca script:** `./audit/verify-ca.sh --op <operation> --stack lean` ≤ 3 min
- [ ] **Update plan:** Edit `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` Phase 6 row

---

## Progress Tracking

Use this table to track completion (update after each operation finishes):

| Operation | Helpers Status | Main Theorem Status | Build Time | Axioms | Completed Date |
|-----------|----------------|---------------------|------------|--------|----------------|
| **Normalization** | 🟡 1/2 done | ❌ sorry | n/a | 1 temp | — |
| **Withdrawal** | ❌ 0/1 done | ❌ sorry | n/a | TBD | — |
| **Rotation** | ❌ 0/1 done | ❌ sorry | n/a | TBD | — |
| **Transfer** | ❌ 0/3 done | ❌ sorry | n/a | TBD | — |

**Legend:**
- ✅ Complete (0 sorry, build verified)
- 🟡 In progress (some sorry remaining)
- ❌ Not started

**Update this table in git commits as work progresses.**

---

## Parallel Work Strategy (2 Developers)

If working in parallel, assign:

**Developer A:**
- Week 1: Normalization helpers + main theorem
- Week 2: Rotation helpers + main theorem
- Week 3: Transfer helper 1 + helper 2

**Developer B:**
- Week 1: Withdrawal stack audit + helpers
- Week 2: Withdrawal main theorem + Rotation stack audit
- Week 3: Transfer helper 3 + main theorem

**Sync points:**
- End of Week 1: Compare Normalization vs Withdrawal proof patterns
- End of Week 2: Decide Transfer helper decomposition based on lessons learned
- End of Week 3: Code review all 4 operations for consistency

---

## Definition of Done (Phase 6)

Phase 6 is COMPLETE when:

1. ✅ All 4 composition theorems have 0 sorry
2. ✅ Each EvalEquiv file builds in ≤3 seconds
3. ✅ Total temporary axioms ≤ 4 (one per operation, for PC-chain helpers)
4. ✅ `./audit/verify-ca.sh --op <each-op> --stack lean` ≤ 3 min
5. ✅ CI `lean-ca` job green on all operations
6. ✅ `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` Phase 6 row updated to "✅ COMPLETE"

**Then:** Phase 6 → Phase 7 (reproducibility package) → Phase 8 (axiom closure)

---

## Resources

**Implementation guides (created this session):**
- `NORMALIZATION_PHASE6_COMPLETE_PROOF_IMPLEMENTATION.md` — detailed Normalization proof with code
- `WITHDRAWAL_PHASE6_COMPLETE_PROOF_IMPLEMENTATION.md` — detailed Withdrawal proof with blockers identified
- `PHASE_6_COMPLETION_GUIDE.md` — high-level roadmap (older, pre-dates detailed guides)

**Automation scripts:**
- `scripts/generate_pc_chain_proof.sh` — scaffold generator
- `scripts/extract_stack_evolution.sh` — stack table extractor

**Relevant Lean files:**
- `lean/MovementFormal/MoveModel/StepLemmas/` — reusable step lemma library
- `lean/MovementFormal/Experimental/ConfidentialAsset/<Op>/EvalEquiv.lean` — operation-specific proofs

**Reference implementations:**
- `lean/MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean` — complete example (3455 lines, 0 sorry, 0 axioms)

---

## Next Actions (Immediate)

1. **Resolve Normalization blocker:** Audit bytecode for PCs 5-7 to confirm stack state
2. **Generate stack tables:** Run `extract_stack_evolution.sh` for all 4 ops
3. **Start Normalization proof:** Begin with `norm_run_pc5_to_pc8` (smallest chunk)
4. **Parallelize if possible:** Assign Withdrawal to second developer

**First concrete task (60-90 minutes):**
```bash
# 1. Generate stack evolution table
cd aptos-move/framework/formal
./scripts/extract_stack_evolution.sh normalization > NORMALIZATION_STACK_EVOLUTION.md

# 2. Read the table
cat NORMALIZATION_STACK_EVOLUTION.md

# 3. Audit PCs 5-7 in the table to resolve blocker in NORMALIZATION_PHASE6_COMPLETE_PROOF_IMPLEMENTATION.md

# 4. Begin coding norm_run_pc5_to_pc8 proof with correct stack state

# 5. Test build
cd lean
time lake build MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv
```

---

**END OF MASTER COORDINATION GUIDE**
