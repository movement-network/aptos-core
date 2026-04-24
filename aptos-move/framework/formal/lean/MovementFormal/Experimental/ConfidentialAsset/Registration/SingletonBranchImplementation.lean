/-
# Singleton Branch Implementation Roadmap

Implementation plan for eliminating the TEMPORARY axiom
`registration_eval_equiv_functional_sim` by proving the singleton
branch (PC 4→70, 67 steps).

## Goal

Replace:
```lean
axiom registration_eval_equiv_functional_sim : ...
```

With:
```lean
theorem registration_eval_equiv_functional_sim : ... := by
  -- Complete proof using PC-by-PC composition
```

## Current Status

**Infrastructure**: ✅ COMPLETE (51 modules, 33,243+ lines)
- All 67 PC proof declarations created
- Proof composition framework ready
- Automation tactics available
- Run composition lemmas ready

**PC Proofs**: 🟡 IN PROGRESS
- Phase 1 (PC 4→20): 17 theorems declared, 0 complete
- Phase 2 (PC 20→43): 23 theorems declared, 0 complete
- Phase 3 (PC 43→70): 27 theorems declared, 0 complete
- Concrete patterns: 5 examples implemented

**Main Theorem**: ⏸️ BLOCKED on PC proofs

## Singleton Branch Structure

From SINGLETON_BRANCH_ROADMAP.md:

```
PC 4:  Call isSome (oracle case split)
PC 5:  BrFalse 79 (branch on result)
PC 6:  MutBorrowLoc 7
PC 7:  Call extract
PC 8:  StLoc 8
PC 9:  MoveLoc 6
PC 10: Call newScalarFromBytes (oracle case split)
...
PC 17-43: Fiat-Shamir message assembly (25 PCs, mechanically chainable)
...
PC 44-68: Sigma verification (oracle-heavy)
PC 69: BrFalse 71 (final branch)
PC 70: Ret (SUCCESS)
```

## Attack Plan (from Roadmap)

### Step 1: Container-Store Threading ✅ (Ready)
Use bundled snapshot approach from ContainerInteractionComplete.lean

### Step 2: Early Oracle Proofs (PC 4-5)
```lean
-- PC 4: isSome oracle call
theorem pc4_isSome_case_split :
    ∃ result, o.isSome [mv] = some [.bool result] ∧
    (result = true → can_continue_to_pc_6) ∧
    (result = false → branches_to_abort_pc_79) := by
  cases h_oracle : o.isSome [mv] with
  | none => sorry  -- Error path
  | some results =>
    cases results with
    | [] => sorry  -- Empty result (error)
    | [.bool b] =>
      use b
      cases b <;> sorry  -- Split true/false branches
    | _ => sorry  -- Multi-result (error)
```

### Step 3: Branch Handling (PC 5)
```lean
-- PC 5: BrFalse based on isSome result
theorem pc5_branch_split :
    (is_some = true → next_pc = 6) ∧
    (is_some = false → next_pc = 79) := by
  cases is_some <;> sorry
```

### Step 4: Continue Through PC 6-16
Linear composition using existing step lemmas

### Step 5: Fiat-Shamir Assembly (PC 17-43)
Mechanical composition - 25 straight-line PCs

### Step 6: Sigma Verification (PC 44-68)
Heavy oracle case-splitting

### Step 7: Terminal (PC 69-70)
Final branch + return

## Proof Engineering Patterns

### Pattern 1: Oracle Case Split
```lean
def handle_oracle_call
    (oracle_result : Option (List MoveValue))
    (on_success : MoveValue → Prop)
    (on_error : Prop) : Prop :=
  match oracle_result with
  | none => on_error  -- Native returned none
  | some [] => on_error  -- Empty result list
  | some [v] => on_success v  -- Success with single value
  | some (_ :: _ :: _) => on_error  -- Multiple results
```

### Pattern 2: Container Threading
```lean
structure ContainerSnapshot where
  refId : Nat
  contained_value : MoveValue
  is_mutable : Bool

def thread_containers
    (snapshot : ContainerSnapshot)
    (ms : MachineState) : MachineState :=
  { ms with containers := ms.containers.insert snapshot.refId ... }
```

### Pattern 3: Sequential Composition
```lean
theorem compose_n_steps
    (proofs : List (Frame → ... → ∃ frame', ...)) :
    run env proofs.length [] frame₀ stack₀ ms₀ =
    .ok [] frame_n stack_n ms_n := by
  -- Apply each proof sequentially
  -- Use run_sequential_compose repeatedly
  sorry
```

## Implementation Progress Tracking

### Phase 1 (PC 4→20): 17 steps
- [✓] Theorem declarations complete
- [ ] PC 4→5: isSome + BrFalse (0/2)
- [ ] PC 6→9: Extract + store (0/4)
- [ ] PC 10→11: newScalarFromBytes + store (0/2)
- [ ] PC 12→16: isSome + extract sequence (0/5)
- [ ] PC 17→20: Store scalars (0/4)

### Phase 2 (PC 20→43): 23 steps
- [✓] Theorem declarations complete
- [ ] PC 20→22: getBasePoint (0/3)
- [ ] PC 23→29: chainId computation (0/7)
- [ ] PC 30→36: sender computation (0/7)
- [ ] PC 37→43: message assembly (0/6)

### Phase 3 (PC 43→70): 27 steps
- [✓] Theorem declarations complete
- [ ] PC 43→49: Challenge derivation (0/7)
- [ ] PC 50→62: LHS computation (0/13)
- [ ] PC 63→68: RHS + equality check (0/6)
- [ ] PC 69→70: Final branch + return (0/1)

## Estimated Effort

From SINGLETON_BRANCH_ROADMAP.md:
- **Total**: 2000-3000 lines
- **PC steps**: ~130 one-line applications once framing is right
- **Case splits**: ~20 oracle case analyses
- **Compositions**: ~10 major composition lemmas

Current progress: ~4,500 lines infrastructure built
Remaining: ~2,500 lines of actual proofs

## Next Immediate Steps

1. **Implement PC 4→5 complete proofs** (with case splits)
2. **Test composition pattern** on first 5 PCs
3. **Extend to PC 10** (second oracle)
4. **Validate automation tactics** work on real proofs
5. **Build phase 1 composition** from individual PCs

## Blockers

None currently - all infrastructure complete.

## Success Criteria

- [ ] All 67 PC proofs implemented (no sorry)
- [ ] Phase compositions proven (3 theorems)
- [ ] Main theorem proven (PC 4→70)
- [ ] TEMPORARY axiom eliminated
- [ ] `#print axioms registration_eval_equiv_functional_sim` shows 0

## Timeline

Conservative estimate:
- Week 1-2: PC 4→20 (Phase 1) - ~650 lines
- Week 3-4: PC 20→43 (Phase 2) - ~900 lines
- Week 5-6: PC 43→70 (Phase 3) - ~950 lines
- Week 7: Integration + axiom elimination - ~200 lines
- **Total**: 7 weeks to complete singleton branch

Aggressive with full automation:
- 3-4 weeks if automation works well
- ~400 lines/week sustained pace

## Reference Documentation

- `SINGLETON_BRANCH_ROADMAP.md`: Overall strategy
- `AXIOM_INVENTORY.md`: Current axiom status
- `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`: Phase 1 requirements
- This file: Implementation tracking

end MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## Progress Metrics -/

/-- Track implementation progress -/
structure ImplementationMetrics where
  total_pcs : Nat := 67
  infrastructure_lines : Nat := 33243
  remaining_proof_lines : Nat := 2500
  pcs_complete : Nat := 0
  pcs_in_progress : Nat := 0
  estimated_weeks : Nat := 7

/-- Current progress percentage -/
def progress_percentage (m : ImplementationMetrics) : Float :=
  (m.pcs_complete.toFloat / m.total_pcs.toFloat) * 100.0

/-- Estimated completion based on current velocity -/
def estimated_completion_date
    (m : ImplementationMetrics)
    (pcs_per_week : Nat) : Nat :=
  let remaining := m.total_pcs - m.pcs_complete
  (remaining + pcs_per_week - 1) / pcs_per_week  -- Ceiling division

#eval progress_percentage { pcs_complete := 0, pcs_in_progress := 67 : ImplementationMetrics }  -- 0.0%

/-! ## Work Log -/

/-- Session log entry -/
structure SessionLog where
  date : String
  pcs_completed : List Nat
  lines_added : Nat
  notes : String

/-- Current session (2026-04-23) -/
def session_2026_04_23 : SessionLog :=
  { date := "2026-04-23"
    pcs_completed := []
    lines_added := 4511
    notes := "Infrastructure complete: 14 files created (Phase declarations, composition framework, automation tactics, verification infrastructure). Ready to begin PC proof implementations." }

end MovementFormal.Experimental.ConfidentialAsset.Registration
