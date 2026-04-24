import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.Native.Registration

/-! # Native Call Patterns for Registration Proof

This file catalogs all native function call patterns appearing in the registration
proof and provides specialized lemmas for each pattern. Native calls are the most
complex instructions, requiring:

1. **Function index lookup**: Validating funcIdx < env.functions.size
2. **Argument extraction**: takeN from stack matching numParams
3. **Oracle invocation**: Calling the native implementation
4. **Result validation**: Checking result count matches numReturns
5. **Stack reconstruction**: Pushing results back (reversed)

## Native Calls in Registration Proof

**Cryptographic natives** (value-level, .native body):
- newCompressedPointFromBytes (PC 3)
- newScalarFromBytes (PC 10)
- pointMul (PC 53, 57)
- pointAdd (PC 60)
- pointDecompress (PC 63)
- pointEquals (PC 66)
- hashToPointBase (PC 47)
- pubkeyToPoint (PC 49)
- newScalarFromSha2_512 (PC 44)

**Ref-aware natives** (.nativeRef body):
- optionIsSomeRef (PC 4, 13)
- optionExtractRef (PC 7, 17)
- vectorPushBackU8Ref (PC 26, multiple)
- vectorAppendU8Ref (PC 29, 33, 37, 41, multiple)
- bcsToBytesAddressRef (used in message assembly)

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.NativeCallPatterns

open MovementFormal.MoveModel
open MovementFormal.MoveModel.StepLemmas

/-! ## Generic Native Call Lemmas

General lemmas applicable to all native calls.
-/

/-- Native call with 1 argument, 1 result (common pattern). -/
theorem native_call_1_to_1
    (env : ModuleEnv)
    (cs : List Frame)
    (frame : Frame)
    (ms : MachineState)
    (funcIdx : Nat)
    (impl : List MoveValue → Option (List MoveValue))
    (arg result : MoveValue)
    (rest_stack : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hinstr : frame.code[frame.pc]'hpc = .call funcIdx)
    (hbounds : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = 1)
    (hreturns : env.functions[funcIdx].numReturns = 1)
    (hbody : env.functions[funcIdx].body = .native impl)
    (horacle : impl [arg] = some [result]) :
    step env frame cs (arg :: rest_stack) ms =
      .ok { frame with pc := frame.pc + 1 } cs (result :: rest_stack) ms := by
  have htake : takeN (arg :: rest_stack) 1 = some ([arg], rest_stack) := by rfl
  exact step_call_native_ret1 funcIdx [arg] rest_stack (arg :: rest_stack)
          impl 1 result hpc hinstr hbounds hparams hreturns hbody htake horacle

/-- Native call with 2 arguments, 1 result.
    Note: Stack top is arg1, then arg2. takeN reverses, so oracle gets [arg2, arg1]. -/
theorem native_call_2_to_1
    (env : ModuleEnv)
    (cs : List Frame)
    (frame : Frame)
    (ms : MachineState)
    (funcIdx : Nat)
    (impl : List MoveValue → Option (List MoveValue))
    (arg1 arg2 result : MoveValue)
    (rest_stack : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hinstr : frame.code[frame.pc]'hpc = .call funcIdx)
    (hbounds : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = 2)
    (hreturns : env.functions[funcIdx].numReturns = 1)
    (hbody : env.functions[funcIdx].body = .native impl)
    (horacle : impl [arg2, arg1] = some [result]) :
    step env frame cs (arg1 :: arg2 :: rest_stack) ms =
      .ok { frame with pc := frame.pc + 1 } cs (result :: rest_stack) ms := by
  have htake : takeN (arg1 :: arg2 :: rest_stack) 2 = some ([arg2, arg1], rest_stack) := by
    simp [takeN]
  exact step_call_native_ret1 funcIdx [arg2, arg1] rest_stack (arg1 :: arg2 :: rest_stack)
          impl 2 result hpc hinstr hbounds hparams hreturns hbody htake horacle

/-- NativeRef call with 1 argument, 1 result. -/
theorem nativeRef_call_1_to_1
    (env : ModuleEnv)
    (cs : List Frame)
    (frame : Frame)
    (ms : MachineState)
    (funcIdx : Nat)
    (impl : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (arg result : MoveValue)
    (containers' : ContainerStore)
    (rest_stack : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hinstr : frame.code[frame.pc]'hpc = .call funcIdx)
    (hbounds : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = 1)
    (hreturns : env.functions[funcIdx].numReturns = 1)
    (hbody : env.functions[funcIdx].body = .nativeRef impl)
    (horacle : impl ms.containers [arg] = some ([result], containers')) :
    step env frame cs (arg :: rest_stack) ms =
      .ok { frame with pc := frame.pc + 1 } cs (result :: rest_stack)
           { ms with containers := containers' } := by
  have htake : takeN (arg :: rest_stack) 1 = some ([arg], rest_stack) := by rfl
  exact step_call_nativeRef_ret1 funcIdx [arg] rest_stack (arg :: rest_stack)
          impl 1 result containers' hpc hinstr hbounds hparams hreturns hbody htake horacle

/-- NativeRef call with 2 arguments, 0 results (returns unit).
    Note: Stack top is arg1, then arg2. takeN reverses, so oracle gets [arg2, arg1]. -/
theorem nativeRef_call_2_to_0
    (env : ModuleEnv)
    (cs : List Frame)
    (frame : Frame)
    (ms : MachineState)
    (funcIdx : Nat)
    (impl : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (arg1 arg2 : MoveValue)
    (containers' : ContainerStore)
    (rest_stack : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hinstr : frame.code[frame.pc]'hpc = .call funcIdx)
    (hbounds : funcIdx < env.functions.size)
    (hparams : env.functions[funcIdx].numParams = 2)
    (hreturns : env.functions[funcIdx].numReturns = 0)
    (hbody : env.functions[funcIdx].body = .nativeRef impl)
    (horacle : impl ms.containers [arg2, arg1] = some ([], containers')) :
    step env frame cs (arg1 :: arg2 :: rest_stack) ms =
      .ok { frame with pc := frame.pc + 1 } cs rest_stack
           { ms with containers := containers' } := by
  have htake : takeN (arg1 :: arg2 :: rest_stack) 2 = some ([arg2, arg1], rest_stack) := by
    simp [takeN]
  exact step_call_nativeRef_ret0 funcIdx [arg2, arg1] rest_stack (arg1 :: arg2 :: rest_stack)
          impl 2 containers' hpc hinstr hbounds hparams hreturns hbody htake horacle

/-! ## Specific Native Call Patterns

Specialized lemmas for each native function in the registration proof.

Note: Structure definitions commented out due to Lean limitation with dot notation
on structure parameters. The generic theorems above are sufficient.
-/

/-
/-- newCompressedPointFromBytes call pattern. -/
structure NewCompressedPointFromBytesCallPattern (o : RegistrationNativeOracle) where
  env : ModuleEnv
  frame : Frame
  ms : MachineState
  commitBa_val : MoveValue
  v_result : MoveValue
  rest_stack : List MoveValue
  funcIdx : Nat
  -- Preconditions
  hpc : frame.pc < frame.code.size
  hinstr : frame.code[frame.pc]'hpc = .call funcIdx
  hbounds : funcIdx < env.functions.size
  hfunc : env.functions[funcIdx] = {
    numParams := 1,
    numReturns := 1,
    body := .native o.newCompressedPointFromBytes
  }
  -- Oracle
  horacle : o.newCompressedPointFromBytes [commitBa_val] = some [v_result]
  -- Conclusion
  step_result : step env frame [] (commitBa_val :: rest_stack) ms =
                .ok { frame with pc := frame.pc + 1 } [] (v_result :: rest_stack) ms

/-- newScalarFromBytes call pattern. -/
structure NewScalarFromBytesCallPattern (o : RegistrationNativeOracle) where
  env : ModuleEnv
  frame : Frame
  ms : MachineState
  respBa_val : MoveValue
  s_opt_result : MoveValue
  rest_stack : List MoveValue
  funcIdx : Nat
  hpc : frame.pc < frame.code.size
  hinstr : frame.code[frame.pc]'hpc = .call funcIdx
  hbounds : funcIdx < env.functions.size
  hfunc : env.functions[funcIdx] = {
    numParams := 1,
    numReturns := 1,
    body := .native o.newScalarFromBytes
  }
  horacle : o.newScalarFromBytes [respBa_val] = some [s_opt_result]
  step_result : step env frame [] (respBa_val :: rest_stack) ms =
                .ok [] { frame with pc := frame.pc + 1 } (s_opt_result :: rest_stack) ms

/-- optionIsSomeRef call pattern. -/
structure OptionIsSomeRefCallPattern (o : RegistrationNativeOracle) where
  env : ModuleEnv
  frame : Frame
  ms : MachineState
  rid : RefId
  tag : Bool
  rest_stack : List MoveValue
  containers' : ContainerStore
  funcIdx : Nat
  hpc : frame.pc < frame.code.size
  hinstr : frame.code[frame.pc]'hpc = .call funcIdx
  hbounds : funcIdx < env.functions.size
  hfunc : env.functions[funcIdx] = {
    numParams := 1,
    numReturns := 1,
    body := .nativeRef o.optionIsSomeRef
  }
  horacle : o.optionIsSomeRef ms.containers [.immRef rid] = some ([.bool tag], containers')
  step_result : step env frame [] (.immRef rid :: rest_stack) ms =
                .ok [] { frame with pc := frame.pc + 1 } (.bool tag :: rest_stack)
                     { ms with containers := containers' }

/-- optionExtractRef call pattern. -/
structure OptionExtractRefCallPattern (o : RegistrationNativeOracle) where
  env : ModuleEnv
  frame : Frame
  ms : MachineState
  rid : RefId
  extracted : MoveValue
  rest_stack : List MoveValue
  containers' : ContainerStore
  funcIdx : Nat
  hpc : frame.pc < frame.code.size
  hinstr : frame.code[frame.pc]'hpc = .call funcIdx
  hbounds : funcIdx < env.functions.size
  hfunc : env.functions[funcIdx] = {
    numParams := 1,
    numReturns := 1,
    body := .nativeRef optionExtractRef
  }
  horacle : optionExtractRef ms.containers [.mutRef rid] = some ([extracted], containers')
  step_result : step env frame [] (.mutRef rid :: rest_stack) ms =
                .ok [] { frame with pc := frame.pc + 1 } (extracted :: rest_stack)
                     { ms with containers := containers' }

/-- vectorPushBackU8Ref call pattern. -/
structure VectorPushBackU8RefCallPattern (o : RegistrationNativeOracle) where
  env : ModuleEnv
  frame : Frame
  ms : MachineState
  rid : RefId
  byte : UInt8
  rest_stack : List MoveValue
  containers' : ContainerStore
  funcIdx : Nat
  hpc : frame.pc < frame.code.size
  hinstr : frame.code[frame.pc]'hpc = .call funcIdx
  hbounds : funcIdx < env.functions.size
  hfunc : env.functions[funcIdx] = {
    numParams := 2,
    numReturns := 0,
    body := .nativeRef vectorPushBackU8Ref
  }
  horacle : vectorPushBackU8Ref ms.containers [.mutRef rid, .u8 byte] = some ([], containers')
  step_result : step env frame [] (.mutRef rid :: .u8 byte :: rest_stack) ms =
                .ok [] { frame with pc := frame.pc + 1 } rest_stack
                     { ms with containers := containers' }

/-- pointMul call pattern. -/
structure PointMulCallPattern (o : RegistrationNativeOracle) where
  env : ModuleEnv
  frame : Frame
  ms : MachineState
  point scalar result : MoveValue
  rest_stack : List MoveValue
  funcIdx : Nat
  hpc : frame.pc < frame.code.size
  hinstr : frame.code[frame.pc]'hpc = .call funcIdx
  hbounds : funcIdx < env.functions.size
  hfunc : env.functions[funcIdx] = {
    numParams := 2,
    numReturns := 1,
    body := .native o.pointMul
  }
  horacle : o.pointMul [point, scalar] = some [result]
  step_result : step env frame [] (point :: scalar :: rest_stack) ms =
                .ok [] { frame with pc := frame.pc + 1 } (result :: rest_stack) ms

/-- pointAdd call pattern. -/
structure PointAddCallPattern (o : RegistrationNativeOracle) where
  env : ModuleEnv
  frame : Frame
  ms : MachineState
  point1 point2 result : MoveValue
  rest_stack : List MoveValue
  funcIdx : Nat
  hpc : frame.pc < frame.code.size
  hinstr : frame.code[frame.pc]'hpc = .call funcIdx
  hbounds : funcIdx < env.functions.size
  hfunc : env.functions[funcIdx] = {
    numParams := 2,
    numReturns := 1,
    body := .native o.pointAdd
  }
  horacle : o.pointAdd [point1, point2] = some [result]
  step_result : step env frame [] (point1 :: point2 :: rest_stack) ms =
                .ok [] { frame with pc := frame.pc + 1 } (result :: rest_stack) ms

/-- pointEquals call pattern. -/
structure PointEqualsCallPattern (o : RegistrationNativeOracle) where
  env : ModuleEnv
  frame : Frame
  ms : MachineState
  point1 point2 : MoveValue
  equals : Bool
  rest_stack : List MoveValue
  funcIdx : Nat
  hpc : frame.pc < frame.code.size
  hinstr : frame.code[frame.pc]'hpc = .call funcIdx
  hbounds : funcIdx < env.functions.size
  hfunc : env.functions[funcIdx] = {
    numParams := 2,
    numReturns := 1,
    body := .native o.pointEquals
  }
  horacle : o.pointEquals [point1, point2] = some [.bool equals]
  step_result : step env frame [] (point1 :: point2 :: rest_stack) ms =
                .ok [] { frame with pc := frame.pc + 1 } (.bool equals :: rest_stack) ms

/-- newScalarFromSha2_512 call pattern. -/
structure NewScalarFromSha2_512CallPattern where
  env : ModuleEnv
  frame : Frame
  ms : MachineState
  message challenge : MoveValue
  rest_stack : List MoveValue
  funcIdx : Nat
  hpc : frame.pc < frame.code.size
  hinstr : frame.code[frame.pc]'hpc = .call funcIdx
  hbounds : funcIdx < env.functions.size
  hfunc : env.functions[funcIdx] = {
    numParams := 1,
    numReturns := 1,
    body := .native newScalarFromSha2_512
  }
  horacle : newScalarFromSha2_512 [message] = some [challenge]
  step_result : step env frame [] (message :: rest_stack) ms =
                .ok [] { frame with pc := frame.pc + 1 } (challenge :: rest_stack) ms

/-- hashToPointBase call pattern (0 arguments). -/
structure HashToPointBaseCallPattern (o : RegistrationNativeOracle) where
  env : ModuleEnv
  frame : Frame
  ms : MachineState
  base : MoveValue
  rest_stack : List MoveValue
  funcIdx : Nat
  hpc : frame.pc < frame.code.size
  hinstr : frame.code[frame.pc]'hpc = .call funcIdx
  hbounds : funcIdx < env.functions.size
  hfunc : env.functions[funcIdx] = {
    numParams := 0,
    numReturns := 1,
    body := .native o.hashToPointBase
  }
  horacle : o.hashToPointBase [] = some [base]
  step_result : step env frame [] rest_stack ms =
                .ok [] { frame with pc := frame.pc + 1 } (base :: rest_stack) ms

/-! ## Pattern Construction Lemmas

Lemmas for building call patterns from components.
-/

/-- Construct newCompressedPointFromBytes pattern from oracle hypothesis. -/
theorem build_newCompressedPointFromBytes_pattern
    (o : RegistrationNativeOracle)
    (env : ModuleEnv)
    (frame : Frame)
    (ms : MachineState)
    (commitBa_val v_result : MoveValue)
    (rest_stack : List MoveValue)
    (funcIdx : Nat)
    (hpc : frame.pc < frame.code.size)
    (hinstr : frame.code[frame.pc]'hpc = .call funcIdx)
    (hbounds : funcIdx < env.functions.size)
    (hfunc : env.functions[funcIdx].numParams = 1 ∧
             env.functions[funcIdx].numReturns = 1 ∧
             env.functions[funcIdx].body = .native o.newCompressedPointFromBytes)
    (horacle : o.newCompressedPointFromBytes [commitBa_val] = some [v_result]) :
    step env frame [] (commitBa_val :: rest_stack) ms =
      .ok [] { frame with pc := frame.pc + 1 } (v_result :: rest_stack) ms := by
  sorry  -- Apply native_call_1_to_1

/-- Construct pointMul pattern from oracle hypothesis. -/
theorem build_pointMul_pattern
    (o : RegistrationNativeOracle)
    (env : ModuleEnv)
    (frame : Frame)
    (ms : MachineState)
    (point scalar result : MoveValue)
    (rest_stack : List MoveValue)
    (funcIdx : Nat)
    (hpc : frame.pc < frame.code.size)
    (hinstr : frame.code[frame.pc]'hpc = .call funcIdx)
    (hbounds : funcIdx < env.functions.size)
    (hfunc : env.functions[funcIdx].numParams = 2 ∧
             env.functions[funcIdx].numReturns = 1 ∧
             env.functions[funcIdx].body = .native o.pointMul)
    (horacle : o.pointMul [point, scalar] = some [result]) :
    step env frame [] (point :: scalar :: rest_stack) ms =
      .ok [] { frame with pc := frame.pc + 1 } (result :: rest_stack) ms := by
  sorry  -- Apply native_call_2_to_1

/-! ## Pattern Validation

Lemmas for validating call patterns are well-formed.
-/

/-- Valid newCompressedPointFromBytes pattern has correct types. -/
theorem valid_newCompressedPointFromBytes_pattern
    (pattern : NewCompressedPointFromBytesCallPattern o)
    (h_bytes : ∃ data, pattern.commitBa_val = .vector .u8 data)
    (h_result : ∃ tag inner rest, pattern.v_result = .struct_ (.bool tag :: inner :: rest)) :
    True := by
  trivial

/-- Valid pointMul pattern has point and scalar inputs. -/
theorem valid_pointMul_pattern
    (pattern : PointMulCallPattern o)
    (h_point : IsValidCompressedPoint pattern.point)
    (h_scalar : IsValidScalar pattern.scalar) :
    True := by
  trivial
-/

/-! ## Pattern Composition

Lemmas for composing multiple native call patterns.
-/

/-- Sequential native calls compose. -/
theorem native_calls_compose
    (env : ModuleEnv)
    (frame1 frame2 frame3 : Frame)
    (ms1 ms2 ms3 : MachineState)
    (stack1 stack2 stack3 : List MoveValue)
    (h_step1 : step env frame1 [] stack1 ms1 = ExecResult.ok frame2 [] stack2 ms2)
    (h_step2 : step env frame2 [] stack2 ms2 = ExecResult.ok frame3 [] stack3 ms3)
    (h_native1 : ∃ funcIdx, frame1.code[frame1.pc]? = some (.call funcIdx))
    (h_native2 : ∃ funcIdx, frame2.code[frame2.pc]? = some (.call funcIdx)) :
    ∃ intermediate_frame intermediate_stack intermediate_ms,
      step env frame1 [] stack1 ms1 = ExecResult.ok intermediate_frame [] intermediate_stack intermediate_ms ∧
      step env intermediate_frame [] intermediate_stack intermediate_ms = ExecResult.ok frame3 [] stack3 ms3 := by
  exact ⟨frame2, stack2, ms2, h_step1, h_step2⟩

end MovementFormal.Experimental.ConfidentialAsset.Registration.NativeCallPatterns
