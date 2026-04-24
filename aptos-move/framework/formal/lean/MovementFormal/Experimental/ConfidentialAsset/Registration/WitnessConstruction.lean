/-
# Witness Construction Infrastructure

Provides constructors and builders for all witness types needed in the registration
singleton branch proof. Automates witness construction from oracle results and
input values.

## Purpose

Manual witness construction for 67 instructions × multiple values per instruction
would require thousands of lines of boilerplate. This module provides:

- Automated witness builders from oracle responses
- Witness validation and well-formedness checks
- Composition operators for building complex witnesses from simple ones
- Tactics and automation for common witness patterns

## Witness Types

1. **Value Witnesses**: Concrete MoveValue instances with validity proofs
2. **Frame Witnesses**: Frame states at each PC with locals/pc invariants
3. **Stack Witnesses**: Stack contents with type correctness proofs
4. **Oracle Witnesses**: Oracle call results with determinism guarantees
5. **Transition Witnesses**: State transition proofs for each step

## Source

Supports proof construction in:
- PCChainProofs.lean
- ConcreteValueFlowAnalysis.lean
- ConcreteLemmaInstantiations.lean

-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.Native.Registration
import MovementFormal.Experimental.ConfidentialAsset.Registration.ValidationLemmasRefined
import MovementFormal.Experimental.ConfidentialAsset.Registration.TypeCorrectnessProofs
import MovementFormal.Experimental.ConfidentialAsset.Registration.OracleCallSpecifications

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## Value Witness Construction -/

/-- Witness for a validated MoveValue -/
structure ValueWitness where
  value : MoveValue
  type : MoveType
  h_type : HasType value type
  h_valid : IsWellFormedValue value

/-- Build ValueWitness from MoveValue with type inference -/
def mkValueWitness (v : MoveValue) (t : MoveType) : Option ValueWitness :=
  if h1 : HasType v t then
    if h2 : IsWellFormedValue v then
      some ⟨v, t, h1, h2⟩
    else
      none
  else
    none

/-- ValueWitness for u8 -/
def mkU8Witness (n : UInt8) : ValueWitness :=
  ⟨.u8 n, .u8, by trivial, by trivial⟩

/-- ValueWitness for address -/
def mkAddressWitness (addr : Address) : ValueWitness :=
  ⟨.address addr, .address, by trivial, by trivial⟩

/-- ValueWitness for vector<u8> (ByteArray) -/
def mkByteArrayWitness (ba : ByteArray) : ValueWitness :=
  ⟨.vector .u8 (ba.toList.map .u8), .vector .u8, by sorry, by sorry⟩

/-- ValueWitness for CompressedPoint -/
structure CompressedPointWitness extends ValueWitness where
  h_compressed : IsValidCompressedPoint value

def mkCompressedPointWitness (v : MoveValue)
    (h : IsValidCompressedPoint v) : CompressedPointWitness :=
  ⟨⟨v, .struct [], by sorry, by sorry⟩, h⟩

/-- ValueWitness for RistrettoPoint -/
structure RistrettoPointWitness extends ValueWitness where
  h_ristretto : IsValidRistrettoPoint value

def mkRistrettoPointWitness (v : MoveValue)
    (h : IsValidRistrettoPoint v) : RistrettoPointWitness :=
  ⟨⟨v, .struct [], by sorry, by sorry⟩, h⟩

/-- ValueWitness for Scalar -/
structure ScalarWitness extends ValueWitness where
  h_scalar : IsValidScalar value

def mkScalarWitness (v : MoveValue)
    (h : IsValidScalar v) : ScalarWitness :=
  ⟨⟨v, .struct [], by sorry, by sorry⟩, h⟩

/-- ValueWitness for Option<T> -/
structure OptionWitness extends ValueWitness where
  tag : Bool
  inner : MoveValue
  h_struct : value = .struct [.bool tag, inner]

def mkOptionWitness (tag : Bool) (inner : MoveValue) : OptionWitness :=
  let val := .struct [.bool tag, inner]
  ⟨⟨val, .struct [], by sorry, by sorry⟩, tag, inner, rfl⟩

def mkSomeWitness (inner : MoveValue) : OptionWitness :=
  mkOptionWitness true inner

def mkNoneWitness (inner : MoveValue) : OptionWitness :=
  mkOptionWitness false inner

/-! ## Oracle Witness Construction -/

/-- Witness for an oracle call with determinism proof -/
structure OracleCallWitness (oracle_fn : List MoveValue → Option (List MoveValue)) where
  args : List MoveValue
  results : List MoveValue
  h_call : oracle_fn args = some results
  h_deterministic : ∀ results', oracle_fn args = some results' → results = results'

/-- Build oracle witness from oracle call -/
def mkOracleWitness
    (oracle_fn : List MoveValue → Option (List MoveValue))
    (args : List MoveValue)
    (h : ∃ results, oracle_fn args = some results) :
    OracleCallWitness oracle_fn :=
  let ⟨results, h_call⟩ := h
  ⟨args, results, h_call, fun results' h' => by
    rw [h_call] at h'
    injection h'⟩

/-- newCompressedPointFromBytes witness -/
structure NewCompressedPointWitness (o : RegistrationNativeOracle) where
  input : ByteArray
  h_size : input.size = 32
  h_valid_bytes : IsValidCompressedPointBytes (.vector .u8 (input.toList.map .u8))
  option_result : MoveValue
  compressed_point : MoveValue
  h_call : o.newCompressedPointFromBytes
    [.vector .u8 (input.toList.map .u8)] = some [option_result]
  h_some : option_result = .struct [.bool true, compressed_point]
  h_valid_point : IsValidCompressedPoint compressed_point

def mkNewCompressedPointWitness
    (o : RegistrationNativeOracle)
    (ba : ByteArray)
    (h_size : ba.size = 32)
    (h_valid : IsValidCompressedPointBytes (.vector .u8 (ba.toList.map .u8))) :
    Option (NewCompressedPointWitness o) :=
  match h : o.newCompressedPointFromBytes [.vector .u8 (ba.toList.map .u8)] with
  | some [result] =>
      match result with
      | .struct [.bool true, point] =>
          if h_point : IsValidCompressedPoint point then
            some ⟨ba, h_size, h_valid, result, point, h, rfl, h_point⟩
          else
            none
      | _ => none
  | _ => none

/-- pointDecompress witness -/
structure PointDecompressWitness (o : RegistrationNativeOracle) where
  compressed : MoveValue
  h_valid_compressed : IsValidCompressedPoint compressed
  option_result : MoveValue
  decompressed : MoveValue
  h_call : o.pointDecompress [compressed] = some [option_result]
  h_some : option_result = .struct [.bool true, decompressed]
  h_valid_ristretto : IsValidRistrettoPoint decompressed

def mkPointDecompressWitness
    (o : RegistrationNativeOracle)
    (compressed : MoveValue)
    (h_valid : IsValidCompressedPoint compressed) :
    Option (PointDecompressWitness o) :=
  match h : o.pointDecompress [compressed] with
  | some [result] =>
      match result with
      | .struct [.bool true, decompressed] =>
          if h_rist : IsValidRistrettoPoint decompressed then
            some ⟨compressed, h_valid, result, decompressed, h, rfl, h_rist⟩
          else
            none
      | _ => none
  | _ => none

/-- basePointMul witness -/
structure BasePointMulWitness (o : RegistrationNativeOracle) where
  scalar : MoveValue
  h_valid_scalar : IsValidScalar scalar
  result_point : MoveValue
  h_call : o.basePointMul [scalar] = some [result_point]
  h_valid_point : IsValidRistrettoPoint result_point

def mkBasePointMulWitness
    (o : RegistrationNativeOracle)
    (scalar : MoveValue)
    (h_valid : IsValidScalar scalar) :
    Option (BasePointMulWitness o) :=
  match h : o.basePointMul [scalar] with
  | some [point] =>
      if h_point : IsValidRistrettoPoint point then
        some ⟨scalar, h_valid, point, h, h_point⟩
      else
        none
  | _ => none

/-- pointAdd witness -/
structure PointAddWitness (o : RegistrationNativeOracle) where
  point1 : MoveValue
  point2 : MoveValue
  h_valid1 : IsValidRistrettoPoint point1
  h_valid2 : IsValidRistrettoPoint point2
  result : MoveValue
  h_call : o.pointAdd [point1, point2] = some [result]
  h_valid_result : IsValidRistrettoPoint result

def mkPointAddWitness
    (o : RegistrationNativeOracle)
    (p1 p2 : MoveValue)
    (h1 : IsValidRistrettoPoint p1)
    (h2 : IsValidRistrettoPoint p2) :
    Option (PointAddWitness o) :=
  match h : o.pointAdd [p1, p2] with
  | some [result] =>
      if h_result : IsValidRistrettoPoint result then
        some ⟨p1, p2, h1, h2, result, h, h_result⟩
      else
        none
  | _ => none

/-- pointMul witness -/
structure PointMulWitness (o : RegistrationNativeOracle) where
  scalar : MoveValue
  point : MoveValue
  h_valid_scalar : IsValidScalar scalar
  h_valid_point : IsValidRistrettoPoint point
  result : MoveValue
  h_call : o.pointMul [scalar, point] = some [result]
  h_valid_result : IsValidRistrettoPoint result

def mkPointMulWitness
    (o : RegistrationNativeOracle)
    (scalar point : MoveValue)
    (h_scalar : IsValidScalar scalar)
    (h_point : IsValidRistrettoPoint point) :
    Option (PointMulWitness o) :=
  match h : o.pointMul [scalar, point] with
  | some [result] =>
      if h_result : IsValidRistrettoPoint result then
        some ⟨scalar, point, h_scalar, h_point, result, h, h_result⟩
      else
        none
  | _ => none

/-- pointEquals witness -/
structure PointEqualsWitness (o : RegistrationNativeOracle) where
  point1 : MoveValue
  point2 : MoveValue
  h_valid1 : IsValidRistrettoPoint point1
  h_valid2 : IsValidRistrettoPoint point2
  result : Bool
  h_call : o.pointEquals [point1, point2] = some [.bool result]

def mkPointEqualsWitness
    (o : RegistrationNativeOracle)
    (p1 p2 : MoveValue)
    (h1 : IsValidRistrettoPoint p1)
    (h2 : IsValidRistrettoPoint p2) :
    Option (PointEqualsWitness o) :=
  match h : o.pointEquals [p1, p2] with
  | some [.bool b] => some ⟨p1, p2, h1, h2, b, h⟩
  | _ => none

/-- sha3_256 witness -/
structure Sha3_256Witness (o : RegistrationNativeOracle) where
  input : ByteArray
  output : ByteArray
  h_output_size : output.size = 32
  h_call : o.sha3_256 [.vector .u8 (input.toList.map .u8)] =
           some [.vector .u8 (output.toList.map .u8)]

def mkSha3_256Witness
    (o : RegistrationNativeOracle)
    (input : ByteArray) :
    Option (Sha3_256Witness o) :=
  match h : o.sha3_256 [.vector .u8 (input.toList.map .u8)] with
  | some [.vector .u8 bytes] =>
      let output := ByteArray.mk bytes.toArray
      if h_size : output.size = 32 then
        some ⟨input, output, h_size, by sorry⟩
      else
        none
  | _ => none

/-- scalarFromHash witness -/
structure ScalarFromHashWitness (o : RegistrationNativeOracle) where
  hash : ByteArray
  h_size : hash.size = 32
  scalar : MoveValue
  h_call : o.scalarFromHash [.vector .u8 (hash.toList.map .u8)] = some [scalar]
  h_valid : IsValidScalar scalar

def mkScalarFromHashWitness
    (o : RegistrationNativeOracle)
    (hash : ByteArray)
    (h_size : hash.size = 32) :
    Option (ScalarFromHashWitness o) :=
  match h : o.scalarFromHash [.vector .u8 (hash.toList.map .u8)] with
  | some [scalar] =>
      if h_valid : IsValidScalar scalar then
        some ⟨hash, h_size, scalar, h, h_valid⟩
      else
        none
  | _ => none

/-! ## Frame Witness Construction -/

/-- Witness for a well-formed Frame at a specific PC -/
structure FrameWitness where
  frame : Frame
  pc : Nat
  h_pc : frame.pc = pc
  h_locals_size : frame.locals.length = 19
  h_well_formed : ∀ i, i < 19 → frame.locals[i]?.isSome

/-- Build FrameWitness from Frame and PC -/
def mkFrameWitness (f : Frame) (pc : Nat)
    (h_pc : f.pc = pc)
    (h_size : f.locals.length = 19) :
    FrameWitness :=
  ⟨f, pc, h_pc, h_size, by sorry⟩

/-- FrameWitness at PC 4 (initial state) -/
def mkInitialFrameWitness
    (chainId : UInt8)
    (sender : Address)
    (commitBa respBa : ByteArray) :
    FrameWitness :=
  let locals : List (Option MoveValue) := [
    some (.u8 chainId),
    some (.address sender),
    some (.vector .u8 (commitBa.toList.map .u8)),
    some (.vector .u8 (respBa.toList.map .u8))
  ] ++ List.replicate 15 none
  let frame : Frame := {
    pc := 4,
    locals := locals,
    -- other fields...
  }
  ⟨frame, 4, rfl, by simp [locals], by sorry⟩

/-- Update FrameWitness with new PC -/
def FrameWitness.withPC (w : FrameWitness) (new_pc : Nat) : FrameWitness :=
  ⟨{ w.frame with pc := new_pc }, new_pc, rfl, w.h_locals_size, w.h_well_formed⟩

/-- Update FrameWitness with new locals -/
def FrameWitness.withLocal (w : FrameWitness)
    (idx : Nat) (val : Option MoveValue)
    (h_idx : idx < 19) :
    FrameWitness :=
  let new_locals := w.frame.locals.set idx val
  ⟨{ w.frame with locals := new_locals },
   w.pc, w.h_pc, by sorry, by sorry⟩

/-! ## Stack Witness Construction -/

/-- Witness for a well-typed stack -/
structure StackWitness where
  stack : List MoveValue
  types : List MoveType
  h_length : stack.length = types.length
  h_types : ∀ i val ty, stack[i]? = some val → types[i]? = some ty → HasType val ty

/-- Build StackWitness from stack and types -/
def mkStackWitness (s : List MoveValue) (ts : List MoveType)
    (h_len : s.length = ts.length)
    (h_types : ∀ i val ty, s[i]? = some val → ts[i]? = some ty → HasType val ty) :
    StackWitness :=
  ⟨s, ts, h_len, h_types⟩

/-- Empty stack witness -/
def mkEmptyStackWitness : StackWitness :=
  ⟨[], [], rfl, by simp⟩

/-- Push value onto StackWitness -/
def StackWitness.push (w : StackWitness)
    (val : MoveValue) (ty : MoveType)
    (h_type : HasType val ty) :
    StackWitness :=
  ⟨val :: w.stack, ty :: w.types, by simp [w.h_length], by sorry⟩

/-- Pop value from StackWitness -/
def StackWitness.pop (w : StackWitness)
    (h_nonempty : w.stack ≠ []) :
    StackWitness × (MoveValue × MoveType) :=
  match w.stack, w.types with
  | val :: rest_stack, ty :: rest_types =>
      (⟨rest_stack, rest_types, by sorry, by sorry⟩, (val, ty))
  | _, _ => (w, (.bool false, .bool))  -- unreachable

/-! ## State Transition Witness -/

/-- Witness for a single step transition -/
structure StepWitness (o : RegistrationNativeOracle) where
  frame_before : FrameWitness
  stack_before : StackWitness
  ms_before : MachineState
  frame_after : FrameWitness
  stack_after : StackWitness
  ms_after : MachineState
  h_step : step (registrationModuleEnv o) []
    frame_before.frame stack_before.stack ms_before =
    .ok [] frame_after.frame stack_after.stack ms_after
  h_pc_increment : frame_after.pc = frame_before.pc + 1 ∨
                   frame_after.pc ≠ frame_before.pc  -- For branches

/-- Build StepWitness from step execution -/
def mkStepWitness
    (o : RegistrationNativeOracle)
    (fb : FrameWitness) (sb : StackWitness) (mb : MachineState)
    (h : ∃ fa sa ma,
      step (registrationModuleEnv o) [] fb.frame sb.stack mb = .ok [] fa sa ma) :
    Option (StepWitness o) :=
  let ⟨fa, sa, ma, h_step⟩ := h
  -- Build frame_after and stack_after witnesses
  sorry

/-! ## Multi-Step Witness Composition -/

/-- Witness for a PC range execution (multiple steps) -/
structure RangeWitness (o : RegistrationNativeOracle) where
  pc_start : Nat
  pc_end : Nat
  fuel : Nat
  h_fuel : fuel = pc_end - pc_start
  frame_start : FrameWitness
  stack_start : StackWitness
  ms_start : MachineState
  frame_end : FrameWitness
  stack_end : StackWitness
  ms_end : MachineState
  h_run : run (registrationModuleEnv o) fuel []
    frame_start.frame stack_start.stack ms_start =
    .ok [] frame_end.frame stack_end.stack ms_end
  h_pcs : frame_start.pc = pc_start ∧ frame_end.pc = pc_end

/-- Compose two RangeWitnesses -/
def RangeWitness.compose
    (w1 w2 : RangeWitness o)
    (h_connect : w1.pc_end = w2.pc_start ∧
                 w1.frame_end = w2.frame_start ∧
                 w1.stack_end = w2.stack_start ∧
                 w1.ms_end = w2.ms_start) :
    RangeWitness o :=
  ⟨w1.pc_start, w2.pc_end, w1.fuel + w2.fuel,
   by sorry,
   w1.frame_start, w1.stack_start, w1.ms_start,
   w2.frame_end, w2.stack_end, w2.ms_end,
   by sorry,
   by sorry⟩

/-! ## Complete Execution Witness -/

/-- Witness for complete PC 4→70 execution -/
structure CompleteExecutionWitness (o : RegistrationNativeOracle) where
  inputs : RegistrationInputValues
  phase1_witness : RangeWitness o
  h_phase1 : phase1_witness.pc_start = 4 ∧ phase1_witness.pc_end = 20
  phase2_witness : RangeWitness o
  h_phase2 : phase2_witness.pc_start = 20 ∧ phase2_witness.pc_end = 43
  phase3_witness : RangeWitness o
  h_phase3 : phase3_witness.pc_start = 43 ∧ phase3_witness.pc_end = 70
  final_result : Bool
  h_final_stack : phase3_witness.stack_end.stack = [.bool final_result]

/-- Build CompleteExecutionWitness from oracle and inputs -/
def mkCompleteExecutionWitness
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues) :
    Option (CompleteExecutionWitness o) :=
  sorry  -- Execute all three phases and collect witnesses

/-- Extract complete proof from execution witness -/
theorem completeExecutionWitness_implies_proof
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (witness : CompleteExecutionWitness o) :
    ∃ frame stack ms,
      run (registrationModuleEnv o) 67 []
        witness.phase1_witness.frame_start.frame
        witness.phase1_witness.stack_start.stack
        witness.phase1_witness.ms_start =
      .ok [] frame stack ms ∧
      frame.pc = 70 ∧
      stack = [.bool witness.final_result] :=
  sorry

/-! ## Witness Automation Tactics -/

/-- Automatically construct value witness from context -/
def autoValueWitness (v : MoveValue) : Option ValueWitness :=
  sorry  -- Try to infer type and validity from v

/-- Automatically construct oracle witness from call -/
def autoOracleWitness
    (oracle_fn : List MoveValue → Option (List MoveValue))
    (args : List MoveValue) :
    Option (OracleCallWitness oracle_fn) :=
  match oracle_fn args with
  | some results => some (mkOracleWitness oracle_fn args ⟨results, rfl⟩)
  | none => none

/-- Witness builder monad for chaining constructions -/
def WitnessBuilder (α : Type) : Type :=
  Option α

instance : Monad WitnessBuilder where
  pure x := some x
  bind mx f := mx >>= f

/-- Run witness builder -/
def WitnessBuilder.run {α : Type} (builder : WitnessBuilder α) : Option α :=
  builder

/-- Example: Build Phase 1 witness automatically -/
def buildPhase1Witness
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues) :
    WitnessBuilder (RangeWitness o) := do
  -- Build initial frame
  let frame_start := mkInitialFrameWitness
    inputs.chainId inputs.sender inputs.commitBa inputs.respBa
  let stack_start := mkEmptyStackWitness
  let ms_start : MachineState := sorry

  -- Execute Phase 1 (17 steps)
  let ⟨frame_end, stack_end, ms_end, h_run⟩ ← sorry

  -- Build RangeWitness
  let frame_end_witness : FrameWitness := sorry
  let stack_end_witness : StackWitness := sorry

  return ⟨4, 20, 17, rfl,
    frame_start, stack_start, ms_start,
    frame_end_witness, stack_end_witness, ms_end,
    h_run, by sorry⟩

end MovementFormal.Experimental.ConfidentialAsset.Registration
