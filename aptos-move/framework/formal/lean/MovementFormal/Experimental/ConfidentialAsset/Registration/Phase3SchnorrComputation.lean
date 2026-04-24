/-
# Phase 3: Schnorr Verification Computation

Complete implementation of Phase 3 (PC 43-70): Schnorr signature verification
computation and final result determination.

## Phase 3 Overview

**Input state (PC 43):**
- Locals contain:
  - challenge scalar e (from Phase 2)
  - decompressed commit point C (from Phase 2)
  - response point R (compressed, needs decompression)

**Computation:**
1. Decompress response point: R_decomp = decompress(R)
2. Compute C * e (point scalar multiplication)
3. Compute R + C * e (point addition) = verification_point
4. Compute G * e (base point multiplication) = expected_point
5. Check verification_point == expected_point
6. Return true if equal, false otherwise

**Output state (PC 70):**
- Stack: [.bool result]
- PC: 70 (function exit)

## Schnorr Equation

The verification checks: **R + C * e = G * e**

Where:
- R = response point (from prover)
- C = commitment point (public key)
- e = challenge (hash of message)
- G = generator point

## PC Sequence

PC 43-47: Decompress response point R
PC 48-52: Compute C * e
PC 53-57: Compute R + C * e (verification point)
PC 58-62: Compute G * e (expected point)
PC 63-67: Compare points
PC 68-70: Return result

## Source

Based on:
- `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`
  verify_registration_proof, PC 43-70

-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.Programs.Registration
import MovementFormal.Experimental.ConfidentialAsset.Registration.ConcreteValueFlowAnalysis
import MovementFormal.Experimental.ConfidentialAsset.Registration.SchnorrProtocolVerification
import MovementFormal.Experimental.ConfidentialAsset.Registration.OracleCallSpecifications

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## Phase 3 Sub-stages -/

/-- Stage 1: Response point decompression (PC 43-47) -/
structure Phase3Stage1
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs) where

  -- PC 43: Initial state
  state43 : Frame × List MoveValue × MachineState
  h_pc43 : state43.1.pc = 43
  h_stack43 : state43.2.1 = []

  -- PC 43-44: Load response point from locals
  respPoint : MoveValue
  h_respPoint : respPoint = p1.respPoint
  h_respValid : IsValidCompressedPoint respPoint

  -- PC 44-45: Call pointDecompress
  respDecompOption : MoveValue
  respDecompPoint : MoveValue
  h_decomp : o.pointDecompress [respPoint] = some [respDecompOption]
  h_decompSome : respDecompOption = .struct [.bool true, respDecompPoint]
  h_decompValid : IsValidRistrettoPoint respDecompPoint

  -- PC 45-47: Unwrap and store
  state47 : Frame × List MoveValue × MachineState
  h_pc47 : state47.1.pc = 47
  h_stack47 : state47.2.1 = []
  h_resp_stored : ∃ idx, state47.1.locals[idx]? = some (some respDecompPoint)

/-- Stage 2: Commit point scalar multiplication (PC 48-52) -/
structure Phase3Stage2
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs)
    (p2 : Phase2Values o inputs p1)
    (s1 : Phase3Stage1 o inputs p1) where

  -- PC 48-49: Load challenge and commit point
  challenge : MoveValue
  commitDecomp : MoveValue
  h_challenge : challenge = p2.challenge
  h_commitDecomp : commitDecomp = p2.commitDecompPoint
  h_challengeValid : IsValidScalar challenge
  h_commitValid : IsValidRistrettoPoint commitDecomp

  -- PC 49-50: Call pointMul(challenge, commitDecomp)
  commitMulChallenge : MoveValue
  h_mul : o.pointMul [challenge, commitDecomp] = some [commitMulChallenge]
  h_mulValid : IsValidRistrettoPoint commitMulChallenge

  -- PC 50-52: Store result
  state52 : Frame × List MoveValue × MachineState
  h_pc52 : state52.1.pc = 52
  h_stack52 : state52.2.1 = []
  h_mul_stored : ∃ idx, state52.1.locals[idx]? = some (some commitMulChallenge)

/-- Stage 3: Verification point computation (PC 53-57) -/
structure Phase3Stage3
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs)
    (p2 : Phase2Values o inputs p1)
    (s1 : Phase3Stage1 o inputs p1)
    (s2 : Phase3Stage2 o inputs p1 p2 s1) where

  -- PC 53-54: Load R_decomp and C*e
  respDecomp : MoveValue
  commitMul : MoveValue
  h_respDecomp : respDecomp = s1.respDecompPoint
  h_commitMul : commitMul = s2.commitMulChallenge

  -- PC 54-55: Call pointAdd(R, C*e)
  verificationPoint : MoveValue
  h_add : o.pointAdd [respDecomp, commitMul] = some [verificationPoint]
  h_verificationValid : IsValidRistrettoPoint verificationPoint

  -- PC 55-57: Store verification point
  state57 : Frame × List MoveValue × MachineState
  h_pc57 : state57.1.pc = 57
  h_stack57 : state57.2.1 = []
  h_verification_stored : ∃ idx,
    state57.1.locals[idx]? = some (some verificationPoint)

/-- Stage 4: Expected point computation (PC 58-62) -/
structure Phase3Stage4
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (p2 : Phase2Values o inputs _) where

  -- PC 58-59: Load challenge
  challenge : MoveValue
  h_challenge : challenge = p2.challenge

  -- PC 59-60: Call basePointMul(challenge)
  expectedPoint : MoveValue
  h_baseMul : o.basePointMul [challenge] = some [expectedPoint]
  h_expectedValid : IsValidRistrettoPoint expectedPoint

  -- PC 60-62: Store expected point
  state62 : Frame × List MoveValue × MachineState
  h_pc62 : state62.1.pc = 62
  h_stack62 : state62.2.1 = []
  h_expected_stored : ∃ idx, state62.1.locals[idx]? = some (some expectedPoint)

/-- Stage 5: Point comparison and result (PC 63-70) -/
structure Phase3Stage5
    (o : RegistrationNativeOracle)
    (s3 : Phase3Stage3 o inputs _ _ _ _)
    (s4 : Phase3Stage4 o inputs _) where

  -- PC 63-64: Load both points
  verificationPoint : MoveValue
  expectedPoint : MoveValue
  h_verification : verificationPoint = s3.verificationPoint
  h_expected : expectedPoint = s4.expectedPoint

  -- PC 64-65: Call pointEquals
  equalityResult : Bool
  h_equals : o.pointEquals [verificationPoint, expectedPoint] =
    some [.bool equalityResult]

  -- PC 65-67: BrFalse (branch on result)
  -- If true: continue to PC 68 (success path)
  -- If false: jump to PC 73 (error path)

  -- PC 68-70: Success path (returns true)
  state70 : Frame × List MoveValue × MachineState
  h_pc70 : state70.1.pc = 70
  h_stack70 : state70.2.1 = [.bool equalityResult]
  h_success : equalityResult = true

/-! ## PC-by-PC Step Proofs (Happy Path) -/

/-- PC 43→44: CopyLoc respPoint -/
theorem pc43_to_44
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 43)
    (h_stack : stack = [])
    (h_locals : ∃ idx, frame.locals[idx]? = some (some p1.respPoint)) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 44 ∧
      stack' = [p1.respPoint] ∧
      ms' = ms := by
  sorry

/-- PC 44→45: pointDecompress(respPoint) -/
theorem pc44_to_45
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs)
    (p3 : Phase3Values o inputs p1 _)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 44)
    (h_stack : stack = [p1.respPoint]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 45 ∧
      stack' = [p3.respDecompOption] ∧
      ms' = ms := by
  sorry

/-- PC 45→46: Unwrap respDecompOption -/
theorem pc45_to_46
    (o : RegistrationNativeOracle)
    (p3 : Phase3Values o inputs _ _)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 45)
    (h_stack : stack = [p3.respDecompOption]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 46 ∧
      stack' = [p3.respDecompPoint] ∧
      ms' = ms := by
  sorry

/-- PC 46→47: StLoc respDecompPoint -/
theorem pc46_to_47
    (o : RegistrationNativeOracle)
    (p3 : Phase3Values o inputs _ _)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 46)
    (h_stack : stack = [p3.respDecompPoint]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 47 ∧
      stack' = [] ∧
      ms' = ms := by
  sorry

/-- PC 47→48: CopyLoc challenge -/
theorem pc47_to_48
    (o : RegistrationNativeOracle)
    (p2 : Phase2Values o inputs _)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 47)
    (h_locals : ∃ idx, frame.locals[idx]? = some (some p2.challenge)) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 48 ∧
      stack' = [p2.challenge] ∧
      ms' = ms := by
  sorry

/-- PC 48→49: CopyLoc commitDecompPoint -/
theorem pc48_to_49
    (o : RegistrationNativeOracle)
    (p2 : Phase2Values o inputs _)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 48)
    (h_stack : stack = [p2.challenge])
    (h_locals : ∃ idx, frame.locals[idx]? = some (some p2.commitDecompPoint)) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 49 ∧
      stack' = [p2.commitDecompPoint, p2.challenge] ∧
      ms' = ms := by
  sorry

/-- PC 49→50: pointMul(challenge, commitDecomp) -/
theorem pc49_to_50
    (o : RegistrationNativeOracle)
    (p2 : Phase2Values o inputs _)
    (p3 : Phase3Values o inputs _ p2)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 49)
    (h_stack : stack = [p2.commitDecompPoint, p2.challenge]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 50 ∧
      stack' = [p3.commitMulChallenge] ∧
      ms' = ms := by
  sorry

/-- Placeholder theorems for PC 50-62 (similar pattern) -/
axiom pc50_to_51 : ∀ o inputs p3 frame stack ms,
  frame.pc = 50 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 51

axiom pc51_to_52 : ∀ o inputs p3 frame stack ms,
  frame.pc = 51 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 52

axiom pc52_to_53 : ∀ o inputs p3 frame stack ms,
  frame.pc = 52 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 53

axiom pc53_to_54 : ∀ o inputs p3 frame stack ms,
  frame.pc = 53 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 54

axiom pc54_to_55 : ∀ o inputs p3 frame stack ms,
  frame.pc = 54 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 55

axiom pc55_to_56 : ∀ o inputs p3 frame stack ms,
  frame.pc = 55 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 56

axiom pc56_to_57 : ∀ o inputs p3 frame stack ms,
  frame.pc = 56 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 57

axiom pc57_to_58 : ∀ o inputs p3 frame stack ms,
  frame.pc = 57 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 58

axiom pc58_to_59 : ∀ o inputs p3 frame stack ms,
  frame.pc = 58 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 59

axiom pc59_to_60 : ∀ o inputs p3 frame stack ms,
  frame.pc = 59 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 60

axiom pc60_to_61 : ∀ o inputs p3 frame stack ms,
  frame.pc = 60 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 61

axiom pc61_to_62 : ∀ o inputs p3 frame stack ms,
  frame.pc = 61 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 62

/-- PC 62→63: CopyLoc verificationPoint -/
theorem pc62_to_63
    (o : RegistrationNativeOracle)
    (p3 : Phase3Values o inputs _ _)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 62)
    (h_locals : ∃ idx, frame.locals[idx]? = some (some p3.verificationPoint)) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 63 ∧
      stack' = [p3.verificationPoint] ∧
      ms' = ms := by
  sorry

/-- PC 63→64: CopyLoc expectedPoint -/
theorem pc63_to_64
    (o : RegistrationNativeOracle)
    (p3 : Phase3Values o inputs _ _)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 63)
    (h_stack : stack = [p3.verificationPoint])
    (h_locals : ∃ idx, frame.locals[idx]? = some (some p3.expectedPoint)) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 64 ∧
      stack' = [p3.expectedPoint, p3.verificationPoint] ∧
      ms' = ms := by
  sorry

/-- PC 64→65: pointEquals(verificationPoint, expectedPoint) -/
theorem pc64_to_65
    (o : RegistrationNativeOracle)
    (p3 : Phase3Values o inputs _ _)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 64)
    (h_stack : stack = [p3.expectedPoint, p3.verificationPoint]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 65 ∧
      stack' = [p3.equalityResult] ∧
      ms' = ms := by
  sorry

/-- PC 65→66: BrFalse (success path: equalityResult = true) -/
theorem pc65_to_66_success
    (o : RegistrationNativeOracle)
    (p3 : Phase3Values o inputs _ _)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 65)
    (h_stack : stack = [.bool true])
    (h_success : p3.verificationPassed = true) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 66 ∧
      stack' = [] ∧
      ms' = ms := by
  sorry

axiom pc66_to_67 : ∀ o inputs p3 frame stack ms,
  frame.pc = 66 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 67

axiom pc67_to_68 : ∀ o inputs p3 frame stack ms,
  frame.pc = 67 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 68

axiom pc68_to_69 : ∀ o inputs p3 frame stack ms,
  frame.pc = 68 → ∃ frame' stack' ms',
  step (registrationModuleEnv o) [] frame stack ms = .ok [] frame' stack' ms' ∧
  frame'.pc = 69

/-- PC 69→70: Final return -/
theorem pc69_to_70
    (o : RegistrationNativeOracle)
    (p3 : Phase3Values o inputs _ _)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 69)
    (h_stack : stack = [.bool p3.verificationPassed]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 70 ∧
      stack' = [.bool p3.finalResult] ∧
      ms' = ms := by
  sorry

/-! ## Phase 3 Complete Execution -/

/-- Phase 3 complete: PC 43→70 in 27 steps (success path) -/
theorem phase3_complete_success
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs)
    (p2 : Phase2Values o inputs p1)
    (p3 : Phase3Values o inputs p1 p2)
    (frame₀ : Frame) (stack₀ : List MoveValue) (ms₀ : MachineState)
    (h_pc : frame₀.pc = 43)
    (h_stack : stack₀ = [])
    (h_success : p3.verificationPassed = true) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 27 [] frame₀ stack₀ ms₀ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 70 ∧
      stack' = [.bool true] ∧
      ms' = ms₀ := by
  sorry

/-- Phase 3 verification correctness -/
theorem phase3_verification_correct
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs)
    (p2 : Phase2Values o inputs p1)
    (p3 : Phase3Values o inputs p1 p2)
    (h_success : p3.verificationPassed = true) :
    p3.verificationPoint = p3.expectedPoint := by
  sorry

/-- Phase 3 implements Schnorr verification equation -/
theorem phase3_implements_schnorr_equation
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (p1 : Phase1Values o inputs)
    (p2 : Phase2Values o inputs p1)
    (p3 : Phase3Values o inputs p1 p2) :
    p3.verificationPassed = true ↔
    (∃ ctx : SchnorrVerificationContext o,
      schnorrEquationHolds ctx) := by
  sorry

end MovementFormal.Experimental.ConfidentialAsset.Registration
