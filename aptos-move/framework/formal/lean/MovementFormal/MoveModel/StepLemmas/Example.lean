import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Arithmetic

/-!
# Architecture demo: proving a tiny bytecode with per-instruction-class step lemmas

This file exists as the reference template for the rebuilt `EvalEquiv` chains in Phase 1 / 4 of
the unified verification plan. It is **not** part of any downstream proof — it's a worked example
showing how to compose the Phase 0 step-lemma library into a bytecode-trace equality.

## Pattern illustrated

Given a 3-instruction program `[ldU64 5, ldU64 7, add]` on any input stack/frame:

1. Each PC step is discharged by one step-lemma application (no `simp [step]` that forces
   whnf on the whole frame).
2. Statement shape uses `run env frame _ _ _ fuel = ...` — we avoid the chain-of-frames idiom
   that made the old `EvalEquiv/Part3.lean` O(N²) to elaborate.
3. Each step's hypothesis (`frame.code[pc] = .ldU64 5`, etc.) is passed explicitly — the
   real rebuild will cache these as `@[simp]` projections from the `Frame.code` constant.

The rebuilt `verify_*_proof` chains in Phase 1 / 4 scale this pattern across 40–80 instructions
with the same per-PC discipline.
-/

namespace MovementFormal.MoveModel.StepLemmas.Example

open MovementFormal.MoveModel
open MovementFormal.MoveModel.StepLemmas

/-- The demo bytecode: push 5, push 7, add, ret. `ret` on an empty callStack makes `step`
    return `.returned …` so `run` terminates with a clean witness instead of PC-out-of-bounds. -/
def demoCode : Array MoveInstr := #[.ldU64 5, .ldU64 7, .add, .ret]

/-- A minimal frame running `demoCode` at PC 0 with no locals. -/
def demoFrame : Frame :=
  { code := demoCode,
    pc := 0,
    locals := #[],
    localRefs := #[] }

/-- After one step of `demoFrame`, the frame has advanced to PC 1 and pushed `.u64 5`. -/
theorem demo_step0 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) :
    step env demoFrame cs stack ms =
      .ok { demoFrame with pc := 1 } cs (.u64 5 :: stack) ms := by
  have hpc : demoFrame.pc < demoFrame.code.size := by decide
  have hc : demoFrame.code[demoFrame.pc]'hpc = .ldU64 5 := rfl
  exact step_ldU64 (5 : UInt64) hpc hc

/-- After step 1 starting from `{demoFrame with pc := 1}`, PC moves to 2 and `.u64 7` is pushed. -/
theorem demo_step1 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) :
    step env { demoFrame with pc := 1 } cs stack ms =
      .ok { demoFrame with pc := 2 } cs (.u64 7 :: stack) ms := by
  let f : Frame := { demoFrame with pc := 1 }
  have hpc : f.pc < f.code.size := by decide
  have hc : f.code[f.pc]'hpc = .ldU64 7 := rfl
  exact step_ldU64 (7 : UInt64) hpc hc

/-- After step 2, the `add` consumes two `u64` values and pushes their sum. -/
theorem demo_step2 (env : ModuleEnv) (cs : List Frame)
    (ms : MachineState) (rest : List MoveValue) :
    step env { demoFrame with pc := 2 } cs (.u64 7 :: .u64 5 :: rest) ms =
      .ok { demoFrame with pc := 3 } cs (.u64 12 :: rest) ms := by
  let f : Frame := { demoFrame with pc := 2 }
  have hpc : f.pc < f.code.size := by decide
  have hc : f.code[f.pc]'hpc = .add := rfl
  have hop : intAdd (.u64 5) (.u64 7) = some (.u64 12) := rfl
  exact step_add (MoveValue.u64 5) (MoveValue.u64 7) (MoveValue.u64 12) rest hpc hc hop

/-! ## Multi-step composition

Scale-test for the architecture: threading three individual step theorems into a single
`run` equality. This is the shape the rebuilt `verify_*_proof` chains will take — one
application per PC, composed through `run`'s recursion. -/

/-- After one step at pc=3, the `ret` on an empty callStack returns `[u64 12]`. -/
theorem demo_step3 (env : ModuleEnv) (ms : MachineState) (rest : List MoveValue) :
    step env { demoFrame with pc := 3 } [] (MoveValue.u64 12 :: rest) ms =
      .returned (MoveValue.u64 12 :: rest) ms := by
  let f : Frame := { demoFrame with pc := 3 }
  have hpc : f.pc < f.code.size := by decide
  have hc : f.code[f.pc]'hpc = .ret := rfl
  exact step_ret_top hpc hc

/-- Four `run` fuel units executed end-to-end yield `.returned [u64 12] ms`. -/
theorem demo_run_full (env : ModuleEnv) (ms : MachineState) :
    run env demoFrame [] [] ms 4 =
      .returned [MoveValue.u64 12] ms := by
  unfold run
  simp only [demo_step0]
  unfold run
  simp only [demo_step1]
  unfold run
  simp only [demo_step2]
  unfold run
  rw [demo_step3]

end MovementFormal.MoveModel.StepLemmas.Example
