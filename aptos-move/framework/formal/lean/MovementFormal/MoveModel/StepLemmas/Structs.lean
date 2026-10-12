import MovementFormal.MoveModel.Step

/-!
# Step lemmas: struct and field instructions

Parametric step lemmas for `pack` / `unpack` / `immBorrowField` / `mutBorrowField`.
-/

set_option linter.unusedSimpArgs false

namespace MovementFormal.MoveModel.StepLemmas

open MovementFormal.MoveModel

variable {env : ModuleEnv} {frame : Frame} {cs : List Frame}
variable {ms : MachineState}

/-! ## `pack` — consume `numFields` values off the stack and push a struct -/

/-- `pack` with the fields-list given explicitly. The step definition uses `takeN`; we expose
    the split form. -/
theorem step_pack (structIdx numFields : Nat)
    (fields : List MoveValue) (rest : List MoveValue) (stack : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .pack structIdx numFields)
    (htake : takeN stack numFields = some (fields, rest)) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.struct_ fields :: rest) ms := by
  simp only [step, dif_pos hpc, hc, htake]

/-! ## `unpack` — consume a struct, push its fields (reversed onto the stack) -/

theorem step_unpack (structIdx numFields : Nat)
    (fields : List MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .unpack structIdx numFields)
    (hlen : fields.length = numFields) :
    step env frame cs (.struct_ fields :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (fields.reverse ++ rest) ms := by
  simp only [step, dif_pos hpc, hc]
  have : (fields.length == numFields) = true := by
    simp [hlen]
  simp [this]

/-! ## `immBorrowField` — borrow a field through an existing ref -/

theorem step_immBorrowField
    (fieldIdx : Nat) (rid : RefId) (fields : List MoveValue)
    (containers' : ContainerStore) (fid : RefId)
    (ref : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .immBorrowField fieldIdx)
    (hRef : getRefId ref = some rid)
    (hread : ms.containers.read rid = some (.struct_ fields))
    (hlt : fieldIdx < fields.length)
    (halloc : ms.containers.alloc (fields[fieldIdx]'hlt) = (containers', fid)) :
    step env frame cs (ref :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (.immRef fid :: rest)
           { ms with containers := containers' } := by
  simp only [step, dif_pos hpc, hc, hRef, hread, dif_pos hlt, halloc]

theorem step_mutBorrowField
    (fieldIdx : Nat) (rid : RefId) (fields : List MoveValue)
    (containers' : ContainerStore) (fid : RefId)
    (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .mutBorrowField fieldIdx)
    (hread : ms.containers.read rid = some (.struct_ fields))
    (hlt : fieldIdx < fields.length)
    (halloc : ms.containers.alloc (fields[fieldIdx]'hlt) = (containers', fid)) :
    step env frame cs (.mutRef rid :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (.mutRef fid :: rest)
           { ms with containers := containers' } := by
  simp only [step, dif_pos hpc, hc, hread, dif_pos hlt, halloc]

end MovementFormal.MoveModel.StepLemmas
