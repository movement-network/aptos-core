import MovementFormal.MoveModel.Step

/-!
# Step lemmas: local-variable instructions

Parametric step lemmas for `copyLoc` / `moveLoc` / `stLoc`. Each lemma takes an arbitrary frame
plus preconditions (PC in bounds, instruction identity, local index in bounds, local value
present, etc.) and produces the resulting `ExecResult` without unfolding frame-definition
chains at the call site.

These are the workhorses of `verify_*_proof` EvalEquiv chains — most instructions in those
functions are local-variable manipulations.
-/

namespace MovementFormal.MoveModel.StepLemmas

open MovementFormal.MoveModel

variable {env : ModuleEnv} {frame : Frame} {cs : List Frame}
variable {stack : List MoveValue} {ms : MachineState}

/-! ## `stLoc idx` — pop `v` from stack into local `idx` -/

theorem step_stLoc (idx : Nat) (v : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .stLoc idx)
    (hlt : idx < frame.locals.size) :
    step env frame cs (v :: rest) ms =
      .ok { frame with
              pc := frame.pc + 1,
              locals := frame.locals.set idx (some v) hlt }
           cs rest ms := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt]

/-! ## `copyLoc idx` — push a copy of local `idx` onto the stack

  Three sub-cases match the step semantics exactly:
  - local has no `localRef`: just push the stored value
  - local has a `localRef` pointing at a live container cell: push the cell contents
  - local has a `localRef` that is `none`: same as no-ref case
-/

/-- `copyLoc` when `localRefs[idx] = none` (or idx ≥ localRefs.size): push stored value. -/
theorem step_copyLoc_noRef (idx : Nat) (v : MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .copyLoc idx)
    (hlt : idx < frame.locals.size)
    (hv : frame.locals[idx]'hlt = some v)
    (hRefNone :
      ¬ idx < frame.localRefs.size ∨
      ∃ (h : idx < frame.localRefs.size), frame.localRefs[idx]'h = none) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: stack) ms := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]
  · simp only [dif_pos hSz, hNone]

/-- `copyLoc` when `localRefs[idx] = some rid` and the container cell is live. -/
theorem step_copyLoc_withRef (idx : Nat) (v : MoveValue) (rid : RefId) (cv : MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .copyLoc idx)
    (hlt : idx < frame.locals.size)
    (hv : frame.locals[idx]'hlt = some v)
    (hltRef : idx < frame.localRefs.size)
    (hRef : frame.localRefs[idx]'hltRef = some rid)
    (hread : ms.containers.read rid = some cv) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (cv :: stack) ms := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hv, dif_pos hltRef, hRef, hread]

/-! ## `moveLoc idx` — push local `idx` onto stack, clearing the local -/

/-- `moveLoc` when `localRefs[idx] = none` (simplest case: just clear and push). -/
theorem step_moveLoc_noRef (idx : Nat) (v : MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .moveLoc idx)
    (hlt : idx < frame.locals.size)
    (hv : frame.locals[idx]'hlt = some v)
    (hRefNone :
      ¬ idx < frame.localRefs.size ∨
      ∃ (h : idx < frame.localRefs.size), frame.localRefs[idx]'h = none) :
    step env frame cs stack ms =
      .ok { frame with
              pc := frame.pc + 1,
              locals := frame.locals.set idx none
                (by omega) }
           cs (v :: stack) ms := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]
  · simp only [dif_pos hSz, hNone]

/-- `moveLoc` when `localRefs[idx] = some rid` and the container read succeeds. -/
theorem step_moveLoc_withRef (idx : Nat) (v : MoveValue) (rid : RefId) (cv : MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .moveLoc idx)
    (hlt : idx < frame.locals.size)
    (hv : frame.locals[idx]'hlt = some v)
    (hltRef : idx < frame.localRefs.size)
    (hRef : frame.localRefs[idx]'hltRef = some rid)
    (hread : ms.containers.read rid = some cv) :
    step env frame cs stack ms =
      .ok { frame with
              pc := frame.pc + 1,
              locals := frame.locals.set idx none (by omega),
              localRefs := frame.localRefs.set idx none (by omega) }
           cs (cv :: stack) ms := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hv, dif_pos hltRef, hRef, hread]

end MovementFormal.MoveModel.StepLemmas
