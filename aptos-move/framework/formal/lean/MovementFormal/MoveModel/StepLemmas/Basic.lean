import MovementFormal.MoveModel.Step

/-!
# Step lemmas: simple instructions (Phase 0 foundation)

Parametric single-step lemmas for instructions whose semantics do not touch locals or refs.
Each lemma takes an arbitrary `env / frame / callStack / stack / ms`, a PC-in-bounds hypothesis
(`hpc`), and an instruction-identity hypothesis (`hc` — usually discharged by a cached
`frame.code[frame.pc] = .ldU64 v` projection), and produces the resulting `ExecResult` by
`simp only [step, dif_pos hpc, hc]`.

These lemmas are intentionally parametric so each specific-PC proof can apply them as a one-liner
rather than re-deriving the step semantics. They form the foundation for rebuilt `verify_*_proof`
EvalEquiv chains (see `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §4).
-/

namespace MovementFormal.MoveModel.StepLemmas

open MovementFormal.MoveModel

variable {env : ModuleEnv} {frame : Frame} {cs : List Frame}
variable {stack : List MoveValue} {ms : MachineState}

/-! ## No-op -/

theorem step_nop (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .nop) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs stack ms := by
  simp only [step, dif_pos hpc, hc]

/-! ## Pop -/

theorem step_pop (v : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .pop) :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs rest ms := by
  simp only [step, dif_pos hpc, hc]

/-! ## Constant loads -/

theorem step_ldU8 (v : UInt8)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .ldU8 v) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.u8 v :: stack) ms := by
  simp only [step, dif_pos hpc, hc]

theorem step_ldU16 (v : UInt16)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .ldU16 v) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.u16 v :: stack) ms := by
  simp only [step, dif_pos hpc, hc]

theorem step_ldU32 (v : UInt32)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .ldU32 v) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.u32 v :: stack) ms := by
  simp only [step, dif_pos hpc, hc]

theorem step_ldU64 (v : UInt64)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .ldU64 v) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.u64 v :: stack) ms := by
  simp only [step, dif_pos hpc, hc]

theorem step_ldU128 (v : U128)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .ldU128 v) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.u128 v :: stack) ms := by
  simp only [step, dif_pos hpc, hc]

theorem step_ldU256 (v : U256)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .ldU256 v) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.u256 v :: stack) ms := by
  simp only [step, dif_pos hpc, hc]

theorem step_ldTrue
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .ldTrue) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.bool true :: stack) ms := by
  simp only [step, dif_pos hpc, hc]

theorem step_ldFalse
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .ldFalse) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.bool false :: stack) ms := by
  simp only [step, dif_pos hpc, hc]

theorem step_ldSigner (addrBytes : ByteArray)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .ldSigner addrBytes) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.signer addrBytes :: stack) ms := by
  simp only [step, dif_pos hpc, hc]

/-- `ldConst idx` — push the constant at `env.constants[idx]` onto the stack. -/
theorem step_ldConst (idx : Nat)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .ldConst idx)
    (hlt : idx < env.constants.size) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs
           (env.constants[idx].value :: stack) ms := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt]

/-! ## Unconditional branch -/

theorem step_branch (offset : Nat)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .branch offset) :
    step env frame cs stack ms =
      .ok { frame with pc := offset } cs stack ms := by
  simp only [step, dif_pos hpc, hc]

/-! ## Conditional branches (stack carries the boolean) -/

theorem step_brTrue_taken (offset : Nat) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .brTrue offset) :
    step env frame cs (.bool true :: rest) ms =
      .ok { frame with pc := offset } cs rest ms := by
  simp only [step, dif_pos hpc, hc]

theorem step_brTrue_not_taken (offset : Nat) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .brTrue offset) :
    step env frame cs (.bool false :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs rest ms := by
  simp only [step, dif_pos hpc, hc]

theorem step_brFalse_taken (offset : Nat) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .brFalse offset) :
    step env frame cs (.bool false :: rest) ms =
      .ok { frame with pc := offset } cs rest ms := by
  simp only [step, dif_pos hpc, hc]

theorem step_brFalse_not_taken (offset : Nat) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .brFalse offset) :
    step env frame cs (.bool true :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs rest ms := by
  simp only [step, dif_pos hpc, hc]

/-! ## Abort -/

theorem step_abort (code : UInt64) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .abort_) :
    step env frame cs (.u64 code :: rest) ms = .aborted code := by
  simp only [step, dif_pos hpc, hc]

/-! ## Return (top-level vs nested) -/

theorem step_ret_top
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .ret) :
    step env frame [] stack ms = .returned stack ms := by
  simp only [step, dif_pos hpc, hc]

theorem step_ret_nested (caller : Frame) (restCalls : List Frame)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .ret) :
    step env frame (caller :: restCalls) stack ms =
      .ok caller restCalls stack ms := by
  simp only [step, dif_pos hpc, hc]

end MovementFormal.MoveModel.StepLemmas
