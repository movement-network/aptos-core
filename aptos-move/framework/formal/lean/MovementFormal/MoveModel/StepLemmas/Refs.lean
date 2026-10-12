import MovementFormal.MoveModel.Step

/-!
# Step lemmas: reference instructions

Parametric step lemmas for `immBorrowLoc` / `mutBorrowLoc` / `readRef` / `writeRef` /
`freezeRef`. Reference semantics in `MoveModel.Step` split into several sub-cases based on
whether the target local already has a `localRef` recorded (aliased view) or needs a fresh
allocation in the container store.
-/

set_option linter.unusedSimpArgs false

namespace MovementFormal.MoveModel.StepLemmas

open MovementFormal.MoveModel

variable {env : ModuleEnv} {frame : Frame} {cs : List Frame}
variable {stack : List MoveValue} {ms : MachineState}

/-! ## `immBorrowLoc idx` — push immutable reference to local `idx`

  Three cases:
  - `localRefs[idx] = some rid`: reuse existing `rid`, no container alloc
  - `localRefs[idx] = none` (or idx ≥ localRefs.size): alloc new container for `v`, push new ref
-/

/-- `immBorrowLoc` when an existing `localRef` is already recorded. -/
theorem step_immBorrowLoc_existing
    (idx : Nat) (v : MoveValue) (rid : RefId)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .immBorrowLoc idx)
    (hlt : idx < frame.locals.size)
    (hv : frame.locals[idx]'hlt = some v)
    (hltRef : idx < frame.localRefs.size)
    (hRef : frame.localRefs[idx]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.immRef rid :: stack) ms := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hv, dif_pos hltRef, hRef]

/-- `immBorrowLoc` when there's no existing ref — a fresh container cell is allocated. -/
theorem step_immBorrowLoc_fresh
    (idx : Nat) (v : MoveValue) (containers' : ContainerStore) (rid : RefId)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .immBorrowLoc idx)
    (hlt : idx < frame.locals.size)
    (hv : frame.locals[idx]'hlt = some v)
    (halloc : ms.containers.alloc v = (containers', rid))
    (hRefNone :
      ¬ idx < frame.localRefs.size ∨
      ∃ (h : idx < frame.localRefs.size), frame.localRefs[idx]'h = none) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.immRef rid :: stack)
           { ms with containers := containers' } := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hv, halloc]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz, halloc]
  · simp only [dif_pos hSz, hNone, halloc]

/-! ## `mutBorrowLoc idx` — push mutable reference to local `idx`

  Unlike `immBorrowLoc`, the "fresh" case also writes back into `localRefs[idx]` so subsequent
  reads go through the container cell.
-/

/-- `mutBorrowLoc` when an existing `localRef` is already recorded. -/
theorem step_mutBorrowLoc_existing
    (idx : Nat) (v : MoveValue) (rid : RefId)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .mutBorrowLoc idx)
    (hlt : idx < frame.locals.size)
    (hv : frame.locals[idx]'hlt = some v)
    (hltRef : idx < frame.localRefs.size)
    (hRef : frame.localRefs[idx]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.mutRef rid :: stack) ms := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hv, dif_pos hltRef, hRef]

/-- `mutBorrowLoc` when there's no existing ref but `idx < localRefs.size` —
    allocate and update `localRefs[idx]`. -/
theorem step_mutBorrowLoc_freshInBounds
    (idx : Nat) (v : MoveValue) (containers' : ContainerStore) (rid : RefId)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .mutBorrowLoc idx)
    (hlt : idx < frame.locals.size)
    (hv : frame.locals[idx]'hlt = some v)
    (hltRef : idx < frame.localRefs.size)
    (hRef : frame.localRefs[idx]'hltRef = none)
    (halloc : ms.containers.alloc v = (containers', rid)) :
    step env frame cs stack ms =
      .ok { frame with
              pc := frame.pc + 1,
              localRefs := frame.localRefs.set idx (some rid) (by omega) }
           cs (.mutRef rid :: stack) { ms with containers := containers' } := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hv, dif_pos hltRef, hRef, halloc]

/-- `mutBorrowLoc` when `idx ≥ localRefs.size` — allocate but do not update localRefs. -/
theorem step_mutBorrowLoc_freshOutOfBounds
    (idx : Nat) (v : MoveValue) (containers' : ContainerStore) (rid : RefId)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .mutBorrowLoc idx)
    (hlt : idx < frame.locals.size)
    (hv : frame.locals[idx]'hlt = some v)
    (hNotLt : ¬ idx < frame.localRefs.size)
    (halloc : ms.containers.alloc v = (containers', rid)) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.mutRef rid :: stack)
           { ms with containers := containers' } := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hv, dif_neg hNotLt, halloc]

/-! ## `readRef` — dereference the top reference, pushing its value

Two variants (immutable and mutable reference) — stated separately to keep simp chains linear. -/

theorem step_readRef_imm (rid : RefId) (v : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .readRef)
    (hread : ms.containers.read rid = some v) :
    step env frame cs (.immRef rid :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest) ms := by
  simp only [step, dif_pos hpc, hc, getRefId_imm, hread]

theorem step_readRef_mut (rid : RefId) (v : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .readRef)
    (hread : ms.containers.read rid = some v) :
    step env frame cs (.mutRef rid :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest) ms := by
  simp only [step, dif_pos hpc, hc, getRefId_mut, hread]

/-! ## `writeRef` — store top-but-one through the `mutRef` on top -/

theorem step_writeRef
    (rid : RefId) (val : MoveValue) (containers' : ContainerStore) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .writeRef)
    (hwrite : ms.containers.write rid val = some containers') :
    step env frame cs (.mutRef rid :: val :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs rest { ms with containers := containers' } := by
  simp only [step, dif_pos hpc, hc, hwrite]

/-! ## `freezeRef` — convert `mutRef` to `immRef` -/

theorem step_freezeRef (rid : RefId) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .freezeRef) :
    step env frame cs (.mutRef rid :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (.immRef rid :: rest) ms := by
  simp only [step, dif_pos hpc, hc]

end MovementFormal.MoveModel.StepLemmas
