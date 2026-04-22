import MovementFormal.MoveModel.Step

/-!
# Step lemmas: value-level vector instructions

Parametric step lemmas for `vecPack` / `vecLen` / `vecPushBack` / `vecPopBack` / `vecUnpack` /
`vecSwap`. These are the value-level (non-reference) vector ops the Move compiler emits for
small fixed-arity constructors and getters.

Reference-level vec ops (`vecLenRef`, `vecImmBorrow`, `vecMutBorrow`, etc.) are covered by a
separate file when needed; CA bytecode uses mostly value-level ops in the auditor-list path of
`verify_transfer_proof`.
-/

set_option linter.unusedSimpArgs false

namespace MovementFormal.MoveModel.StepLemmas

open MovementFormal.MoveModel

variable {env : ModuleEnv} {frame : Frame} {cs : List Frame}
variable {ms : MachineState}

/-! ## `vecPack elemType numElems` — consume `numElems` values, push a `.vector` -/

theorem step_vecPack
    (elemType : MoveType) (numElems : Nat)
    (elems rest stack : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .vecPack elemType numElems)
    (htake : takeN stack numElems = some (elems, rest)) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.vector elemType elems :: rest) ms := by
  simp only [step, dif_pos hpc, hc, htake]

/-! ## `vecLen elemType` — read the length of the top `.vector` onto the stack -/

theorem step_vecLen
    (elemType : MoveType) (elems : List MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .vecLen elemType) :
    step env frame cs (.vector elemType elems :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs
           (.u64 elems.length.toUInt64 :: rest) ms := by
  simp only [step, dif_pos hpc, hc]

/-! ## `vecPushBack elemType` — push `val` onto the `.vector` on the stack below -/

theorem step_vecPushBack
    (elemType : MoveType) (val : MoveValue) (elems rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .vecPushBack elemType) :
    step env frame cs (val :: .vector elemType elems :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs
           (.vector elemType (elems ++ [val]) :: rest) ms := by
  simp only [step, dif_pos hpc, hc]

/-! ## `vecPopBack elemType` — pop the last element off the top `.vector`

Produces two stack values: the popped element on top, the shorter vector underneath. Aborts
to `.error` if the vector is empty; the `_nonEmpty` variant requires the element list has the
form `elems ++ [last]`. -/

theorem step_vecPopBack_nonEmpty
    (elemType : MoveType) (elems : List MoveValue) (last : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .vecPopBack elemType) :
    step env frame cs (.vector elemType (elems ++ [last]) :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs
           (last :: .vector elemType elems :: rest) ms := by
  simp only [step, dif_pos hpc, hc]
  -- `(elems ++ [last]).reverse = last :: elems.reverse`, so the match takes the cons branch
  -- with `init := elems.reverse` and the result uses `init.reverse = elems`.
  have : (elems ++ [last]).reverse = last :: elems.reverse := by
    simp [List.reverse_append]
  rw [this]
  show _ = _
  simp

/-! ## `vecUnpack elemType numElems` — split a `.vector` of expected length into stack values -/

theorem step_vecUnpack
    (elemType : MoveType) (numElems : Nat) (elems rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .vecUnpack elemType numElems)
    (hlen : elems.length = numElems) :
    step env frame cs (.vector elemType elems :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (elems.reverse ++ rest) ms := by
  have hbeq : (elems.length == numElems) = true := by simp [hlen]
  simp only [step, dif_pos hpc, hc, hbeq, if_true]

/-! ## Reference-level vector ops — `vecLenRef` / `vecImmBorrow` / `vecMutBorrow` / `vecPushBackRef`

These operate through a `.mutRef` or `.immRef` pointing at a `.vector` in the container store.
Used by the transfer bytecode's auditor-list loop (each auditor's ciphertext is looked up via
`vecImmBorrow` on the auditor-index vector). -/

/-- `vecLenRef`: read the length of the `.vector` pointed to by the top reference. -/
theorem step_vecLenRef_imm
    (elemType : MoveType) (rid : RefId) (elems rest : List MoveValue) (innerT : MoveType)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .vecLenRef elemType)
    (hread : ms.containers.read rid = some (.vector innerT elems)) :
    step env frame cs (.immRef rid :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs
           (.u64 elems.length.toUInt64 :: rest) ms := by
  simp only [step, dif_pos hpc, hc, getRefId_imm, hread]

theorem step_vecLenRef_mut
    (elemType : MoveType) (rid : RefId) (elems rest : List MoveValue) (innerT : MoveType)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .vecLenRef elemType)
    (hread : ms.containers.read rid = some (.vector innerT elems)) :
    step env frame cs (.mutRef rid :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs
           (.u64 elems.length.toUInt64 :: rest) ms := by
  simp only [step, dif_pos hpc, hc, getRefId_mut, hread]

/-- `vecPushBackRef`: append `val` to the `.vector` pointed to by `mutRef`. 0-return, mutates
the container store. -/
theorem step_vecPushBackRef
    (elemType innerT : MoveType) (val : MoveValue) (rid : RefId) (elems rest : List MoveValue)
    (containers' : ContainerStore)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .vecPushBackRef elemType)
    (hread : ms.containers.read rid = some (.vector innerT elems))
    (hwrite : ms.containers.write rid (.vector innerT (elems ++ [val])) = some containers') :
    step env frame cs (val :: .mutRef rid :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs rest
           { ms with containers := containers' } := by
  simp only [step, dif_pos hpc, hc, hread, hwrite]

end MovementFormal.MoveModel.StepLemmas
