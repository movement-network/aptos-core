import MovementFormal.MoveModel.Step

/-!
# Step lemmas: integer casts and shifts

Parametric step lemmas for `castU8/16/32/64/128/256`, `shl`, `shr`. Each lemma takes the
input operand(s) plus the corresponding `castTo*` / `intShl` / `intShr` result as an `Option`,
keeping the lemma agnostic to the concrete width of the operand.
-/

set_option linter.unusedSimpArgs false

namespace MovementFormal.MoveModel.StepLemmas

open MovementFormal.MoveModel

variable {env : ModuleEnv} {frame : Frame} {cs : List Frame}
variable {ms : MachineState}

/-! ## Casts — one-operand `castU*` -/

theorem step_castU8 (v v' : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .castU8)
    (hop : castToU8 v = some v') :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v' :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_castU16 (v v' : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .castU16)
    (hop : castToU16 v = some v') :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v' :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_castU32 (v v' : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .castU32)
    (hop : castToU32 v = some v') :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v' :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_castU64 (v v' : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .castU64)
    (hop : castToU64 v = some v') :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v' :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_castU128 (v v' : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .castU128)
    (hop : castToU128 v = some v') :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v' :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_castU256 (v v' : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .castU256)
    (hop : castToU256 v = some v') :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v' :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

/-! ## Shifts — `shl` / `shr` consume a `u8` shift count on top of the stack -/

theorem step_shl (lhs v : MoveValue) (n : UInt8) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .shl)
    (hop : intShl lhs n = some v) :
    step env frame cs (.u8 n :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

theorem step_shr (lhs v : MoveValue) (n : UInt8) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .shr)
    (hop : intShr lhs n = some v) :
    step env frame cs (.u8 n :: lhs :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest) ms := by
  simp only [step, dif_pos hpc, hc, hop]

end MovementFormal.MoveModel.StepLemmas
