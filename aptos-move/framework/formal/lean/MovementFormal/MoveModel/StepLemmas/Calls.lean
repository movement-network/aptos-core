import MovementFormal.MoveModel.Step

/-!
# Step lemmas: function-call dispatch

Parametric step lemmas for `.call funcIdx`. Four cases in the step definition:

- `.bytecode code numLocals` — push a new frame, saved frame goes on callStack
- `.native impl` — invoke a pure native, post-process via `handleNativeResult`
- `.nativeAbort impl` — native that may abort, post-process via `handleNativeAbortResult`
- `.nativeRef impl` — native that reads containers, post-process via `handleNativeResult`

This file covers the **bytecode** case (the one verify-proof chains actually dispatch through
to recurse into a callee). Native cases are intentionally left as TODOs: their observational
behavior depends on the concrete native implementation, so per-verifier EvalEquiv proofs will
state native-call step lemmas with the native's refinement hypothesis inline.
-/

set_option linter.unusedSimpArgs false

namespace MovementFormal.MoveModel.StepLemmas

open MovementFormal.MoveModel

variable {env : ModuleEnv} {frame : Frame} {cs : List Frame}
variable {ms : MachineState}

/-- `.call funcIdx` dispatching to a bytecode function body.

  The caller's frame is saved with `pc + 1` (so after the callee returns, execution resumes at
  the instruction after the call). The callee starts at `pc = 0` with locals initialized from
  the popped arguments and the remaining slots set to `none`. -/
theorem step_call_bytecode
    (funcIdx : Nat)
    (args rest stack : List MoveValue) (code : Array MoveInstr) (numLocals : Nat)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .call funcIdx)
    (hlt : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = args.length)
    (htake : takeN stack args.length = some (args, rest))
    (hbody : env.functions[funcIdx].body = .bytecode code numLocals) :
    step env frame cs stack ms =
      .ok
        { code := code,
          pc := 0,
          locals := (args.map some ++
                      List.replicate (numLocals - args.length) none).toArray,
          localRefs := (List.replicate numLocals none).toArray }
        ({ frame with pc := frame.pc + 1 } :: cs) rest
        { ms with containers := ms.containers, globals := ms.globals } := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hparams, htake, hbody]

/-! ## Native call dispatch — `.native impl` body

For `.call funcIdx` where the function's body is `.native impl`, `step` produces
`handleNativeResult (impl args) numReturns (advance frame) cs rest (withCG ms containers globals)`.

The observational behavior depends on `impl args`:
- `some results` with `results.length = numReturns` → `.ok (advance frame) cs (results.reverse ++ rest) (withCG …)`
- `some results` with `results.length ≠ numReturns` → `.error`
- `none` → `.error`

The `_some` variant below covers the happy path (native returns the expected number of values).
Callers provide the concrete `impl args = some results` hypothesis as an oracle-level claim. -/

/-- `.call funcIdx` dispatching to a `.native impl` that returns exactly one value. -/
theorem step_call_native_ret1
    (funcIdx : Nat)
    (args rest stack : List MoveValue)
    (impl : List MoveValue → Option (List MoveValue))
    (numParams : Nat) (v : MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .call funcIdx)
    (hlt : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = numParams)
    (hreturns : env.functions[funcIdx].numReturns = 1)
    (hbody : env.functions[funcIdx].body = .native impl)
    (htake : takeN stack numParams = some (args, rest))
    (himpl : impl args = some [v]) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest)
           { ms with containers := ms.containers, globals := ms.globals } := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hparams, htake, hbody]
  unfold handleNativeResult
  rw [himpl, hreturns]
  rfl

/-- Native call returning `none` produces `.error`. -/
theorem step_call_native_none
    (funcIdx : Nat)
    (args rest stack : List MoveValue)
    (impl : List MoveValue → Option (List MoveValue))
    (numParams : Nat)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .call funcIdx)
    (hlt : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = numParams)
    (hbody : env.functions[funcIdx].body = .native impl)
    (htake : takeN stack numParams = some (args, rest))
    (himpl : impl args = none) :
    step env frame cs stack ms = .error := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hparams, htake, hbody]
  unfold handleNativeResult
  rw [himpl]

/-- `.call funcIdx` dispatching to a `.nativeAbort impl` that returns a value (Except success). -/
theorem step_call_nativeAbort_ret1_ok
    (funcIdx : Nat)
    (args rest stack : List MoveValue)
    (impl : List MoveValue → Option (Except UInt64 (List MoveValue)))
    (numParams : Nat) (v : MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .call funcIdx)
    (hlt : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = numParams)
    (hreturns : env.functions[funcIdx].numReturns = 1)
    (hbody : env.functions[funcIdx].body = .nativeAbort impl)
    (htake : takeN stack numParams = some (args, rest))
    (himpl : impl args = some (.ok [v])) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest)
           { ms with containers := ms.containers, globals := ms.globals } := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hparams, htake, hbody]
  unfold handleNativeAbortResult
  rw [himpl]
  unfold handleNativeResult
  rw [hreturns]
  rfl

/-- `.call funcIdx` dispatching to a `.nativeAbort impl` that returns an Except error code. -/
theorem step_call_nativeAbort_abort
    (funcIdx : Nat)
    (args rest stack : List MoveValue)
    (impl : List MoveValue → Option (Except UInt64 (List MoveValue)))
    (numParams : Nat) (code : UInt64)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .call funcIdx)
    (hlt : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = numParams)
    (hbody : env.functions[funcIdx].body = .nativeAbort impl)
    (htake : takeN stack numParams = some (args, rest))
    (himpl : impl args = some (.error code)) :
    step env frame cs stack ms = .aborted code := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hparams, htake, hbody]
  unfold handleNativeAbortResult
  rw [himpl]

/-- NativeAbort call returning `none` produces `.error`. -/
theorem step_call_nativeAbort_none
    (funcIdx : Nat)
    (args rest stack : List MoveValue)
    (impl : List MoveValue → Option (Except UInt64 (List MoveValue)))
    (numParams : Nat)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .call funcIdx)
    (hlt : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = numParams)
    (hbody : env.functions[funcIdx].body = .nativeAbort impl)
    (htake : takeN stack numParams = some (args, rest))
    (himpl : impl args = none) :
    step env frame cs stack ms = .error := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hparams, htake, hbody]
  unfold handleNativeAbortResult
  rw [himpl]

/-- NativeRef call returning `none` produces `.error`. -/
theorem step_call_nativeRef_none
    (funcIdx : Nat)
    (args rest stack : List MoveValue)
    (impl : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (numParams : Nat)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .call funcIdx)
    (hlt : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = numParams)
    (hbody : env.functions[funcIdx].body = .nativeRef impl)
    (htake : takeN stack numParams = some (args, rest))
    (himpl : impl ms.containers args = none) :
    step env frame cs stack ms = .error := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hparams, htake, hbody]
  rw [himpl]

/-! ## Native-ref call dispatch — `.nativeRef impl` body (reads container store)

`.nativeRef impl` calls a native that may read the container store. `step` produces
`match impl containers args with | some (results, containers') => handleNativeResult … | none => .error`. -/

/-- `.call funcIdx` dispatching to a `.native impl` that returns 2 values. -/
theorem step_call_native_ret2
    (funcIdx : Nat)
    (args rest stack : List MoveValue)
    (impl : List MoveValue → Option (List MoveValue))
    (numParams : Nat) (v1 v2 : MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .call funcIdx)
    (hlt : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = numParams)
    (hreturns : env.functions[funcIdx].numReturns = 2)
    (hbody : env.functions[funcIdx].body = .native impl)
    (htake : takeN stack numParams = some (args, rest))
    (himpl : impl args = some [v1, v2]) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs ([v1, v2] ++ rest)
           { ms with containers := ms.containers, globals := ms.globals } := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hparams, htake, hbody]
  unfold handleNativeResult
  rw [himpl, hreturns]
  rfl

/-- `.call funcIdx` dispatching to a `.native impl` that returns zero values. -/
theorem step_call_native_ret0
    (funcIdx : Nat)
    (args rest stack : List MoveValue)
    (impl : List MoveValue → Option (List MoveValue))
    (numParams : Nat)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .call funcIdx)
    (hlt : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = numParams)
    (hreturns : env.functions[funcIdx].numReturns = 0)
    (hbody : env.functions[funcIdx].body = .native impl)
    (htake : takeN stack numParams = some (args, rest))
    (himpl : impl args = some []) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs rest
           { ms with containers := ms.containers, globals := ms.globals } := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hparams, htake, hbody]
  unfold handleNativeResult
  rw [himpl, hreturns]
  rfl

/-- `.call funcIdx` dispatching to a `.nativeRef impl` that returns zero values. -/
theorem step_call_nativeRef_ret0
    (funcIdx : Nat)
    (args rest stack : List MoveValue)
    (impl : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (numParams : Nat) (containers' : ContainerStore)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .call funcIdx)
    (hlt : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = numParams)
    (hreturns : env.functions[funcIdx].numReturns = 0)
    (hbody : env.functions[funcIdx].body = .nativeRef impl)
    (htake : takeN stack numParams = some (args, rest))
    (himpl : impl ms.containers args = some ([], containers')) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs rest
           { ms with containers := containers', globals := ms.globals } := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hparams, htake, hbody]
  rw [himpl]
  unfold handleNativeResult
  rw [hreturns]
  rfl

/-- `.call funcIdx` dispatching to a `.nativeRef impl` that returns exactly one value. -/
theorem step_call_nativeRef_ret1
    (funcIdx : Nat)
    (args rest stack : List MoveValue)
    (impl : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (numParams : Nat) (v : MoveValue) (containers' : ContainerStore)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .call funcIdx)
    (hlt : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = numParams)
    (hreturns : env.functions[funcIdx].numReturns = 1)
    (hbody : env.functions[funcIdx].body = .nativeRef impl)
    (htake : takeN stack numParams = some (args, rest))
    (himpl : impl ms.containers args = some ([v], containers')) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (v :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  simp only [step, dif_pos hpc, hc, dif_pos hlt, hparams, htake, hbody]
  rw [himpl]
  unfold handleNativeResult
  rw [hreturns]
  rfl

end MovementFormal.MoveModel.StepLemmas
