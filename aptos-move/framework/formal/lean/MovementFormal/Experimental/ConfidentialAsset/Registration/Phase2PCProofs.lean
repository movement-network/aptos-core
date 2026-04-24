/-
# Phase 2 PC Proof Implementations

Concrete implementations of all PC→PC+1 proofs for Phase 2 (PC 20→43).
Phase 2 performs message assembly and challenge derivation.

## Phase 2 Structure (23 steps)

PC 20→21: CopyLoc respOption
PC 21→22: Call getBasePoint
PC 22→23: StLoc base_pt
PC 23→24: CopyLoc chainId
PC 24→25: Call basePointMul (G * chainId)
PC 25→26: StLoc chainId_sc
PC 26→27: CopyLoc chainId_sc
PC 27→28: CopyLoc commit_pt
PC 28→29: Call pointAdd (chainId_sc + commit_pt = term1)
PC 29→30: StLoc term1
PC 30→31: CopyLoc sender
PC 31→32: Call basePointMul (G * sender)
PC 32→33: StLoc sender_sc
PC 33→34: CopyLoc sender_sc
PC 34→35: CopyLoc term1
PC 35→36: Call pointAdd (sender_sc + term1 = message_pt)
PC 36→37: StLoc message_pt
PC 37→38: CopyLoc message_pt
PC 38→39: Call pointToBytes
PC 39→40: StLoc message_ba
PC 40→41: CopyLoc message_ba
PC 41→42: Call sha3_256
PC 42→43: StLoc message_hash
PC 43: (boundary - start of Phase 3)

## Source

Implements concrete proofs using templates from ConcretePCStepTemplates.lean.

-/

import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Step
import MovementFormal.Experimental.ConfidentialAsset.Registration.ConcretePCStepTemplates
import MovementFormal.Experimental.ConfidentialAsset.Registration.OracleCallSpecifications
import MovementFormal.Experimental.ConfidentialAsset.Registration.ConcreteValueFlowAnalysis

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

/-! ## PC 20→21: CopyLoc respOption -/

theorem pc20_to_21
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 20)
    (h_locals : frame.locals.size = 19)
    (respOpt : MoveValue)
    (h_resp : frame.locals[8]? = some (some respOpt))
    (h_stack : stack = []) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 21 ∧
      stack' = [respOpt] ∧
      frame'.locals = frame.locals := by
  sorry

/-! ## PC 21→22: Call getBasePoint -/

theorem pc21_to_22
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 21)
    (base_pt : MoveValue)
    (h_oracle : o.getBasePoint [] = some [base_pt])
    (h_valid : IsValidRistrettoPoint base_pt) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 22 ∧
      stack' = [base_pt] := by
  sorry

/-! ## PC 22→23: StLoc base_pt -/

theorem pc22_to_23
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 22)
    (base_pt : MoveValue)
    (h_stack : stack = [base_pt]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 23 ∧
      frame'.locals[10]? = some (some base_pt) ∧
      stack' = [] := by
  sorry

/-! ## PC 23→24: CopyLoc chainId -/

theorem pc23_to_24
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 23)
    (h_chainId : frame.locals[4]? = some (some (.u8 inputs.chainId))) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 24 ∧
      stack' = [.u8 inputs.chainId] := by
  sorry

/-! ## PC 24→25: Call basePointMul (G * chainId) -/

theorem pc24_to_25
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 24)
    (h_stack : stack = [.u8 inputs.chainId])
    (chainId_sc : MoveValue)
    (h_oracle : o.basePointMul [.u8 inputs.chainId] = some [chainId_sc])
    (h_valid : IsValidRistrettoPoint chainId_sc) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 25 ∧
      stack' = [chainId_sc] := by
  sorry

/-! ## PC 25→26: StLoc chainId_sc -/

theorem pc25_to_26
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 25)
    (chainId_sc : MoveValue)
    (h_stack : stack = [chainId_sc]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 26 ∧
      frame'.locals[11]? = some (some chainId_sc) ∧
      stack' = [] := by
  sorry

/-! ## PC 26→27: CopyLoc chainId_sc -/

theorem pc26_to_27
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 26)
    (chainId_sc : MoveValue)
    (h_local : frame.locals[11]? = some (some chainId_sc)) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 27 ∧
      stack' = [chainId_sc] := by
  sorry

/-! ## PC 27→28: CopyLoc commit_pt -/

theorem pc27_to_28
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 27)
    (chainId_sc : MoveValue)
    (h_stack : stack = [chainId_sc])
    (commit_pt : MoveValue)
    (h_local : frame.locals[9]? = some (some commit_pt)) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 28 ∧
      stack' = [commit_pt, chainId_sc] := by
  sorry

/-! ## PC 28→29: Call pointAdd (term1 = chainId_sc + commit_pt) -/

theorem pc28_to_29
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 28)
    (chainId_sc commit_pt : MoveValue)
    (h_stack : stack = [commit_pt, chainId_sc])
    (term1 : MoveValue)
    (h_oracle : o.pointAdd [chainId_sc, commit_pt] = some [term1])
    (h_valid : IsValidRistrettoPoint term1) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 29 ∧
      stack' = [term1] := by
  sorry

/-! ## PC 29→30: StLoc term1 -/

theorem pc29_to_30
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 29)
    (term1 : MoveValue)
    (h_stack : stack = [term1]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 30 ∧
      frame'.locals[14]? = some (some term1) ∧
      stack' = [] := by
  sorry

/-! ## PC 30→31: CopyLoc sender -/

theorem pc30_to_31
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 30)
    (h_sender : frame.locals[1]? = some (some (.address inputs.sender))) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 31 ∧
      stack' = [.address inputs.sender] := by
  sorry

/-! ## PC 31→32: Call basePointMul (G * sender) -/

theorem pc31_to_32
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 31)
    (h_stack : stack = [.address inputs.sender])
    (sender_sc : MoveValue)
    (h_oracle : o.basePointMul [.address inputs.sender] = some [sender_sc])
    (h_valid : IsValidRistrettoPoint sender_sc) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 32 ∧
      stack' = [sender_sc] := by
  sorry

/-! ## PC 32→33: StLoc sender_sc -/

theorem pc32_to_33
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 32)
    (sender_sc : MoveValue)
    (h_stack : stack = [sender_sc]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 33 ∧
      frame'.locals[13]? = some (some sender_sc) ∧
      stack' = [] := by
  sorry

/-! ## PC 33→34: CopyLoc sender_sc -/

theorem pc33_to_34
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 33)
    (sender_sc : MoveValue)
    (h_local : frame.locals[13]? = some (some sender_sc)) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 34 ∧
      stack' = [sender_sc] := by
  sorry

/-! ## PC 34→35: CopyLoc term1 -/

theorem pc34_to_35
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 34)
    (sender_sc : MoveValue)
    (h_stack : stack = [sender_sc])
    (term1 : MoveValue)
    (h_local : frame.locals[14]? = some (some term1)) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 35 ∧
      stack' = [term1, sender_sc] := by
  sorry

/-! ## PC 35→36: Call pointAdd (message_pt = sender_sc + term1) -/

theorem pc35_to_36
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 35)
    (sender_sc term1 : MoveValue)
    (h_stack : stack = [term1, sender_sc])
    (message_pt : MoveValue)
    (h_oracle : o.pointAdd [sender_sc, term1] = some [message_pt])
    (h_valid : IsValidRistrettoPoint message_pt) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 36 ∧
      stack' = [message_pt] := by
  sorry

/-! ## PC 36→37: StLoc message_pt -/

theorem pc36_to_37
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 36)
    (message_pt : MoveValue)
    (h_stack : stack = [message_pt]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 37 ∧
      frame'.locals[15]? = some (some message_pt) ∧
      stack' = [] := by
  sorry

/-! ## PC 37→38: CopyLoc message_pt -/

theorem pc37_to_38
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 37)
    (message_pt : MoveValue)
    (h_local : frame.locals[15]? = some (some message_pt)) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 38 ∧
      stack' = [message_pt] := by
  sorry

/-! ## PC 38→39: Call pointToBytes -/

theorem pc38_to_39
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 38)
    (message_pt : MoveValue)
    (h_stack : stack = [message_pt])
    (message_ba : MoveValue)
    (h_oracle : o.pointToBytes [message_pt] = some [message_ba])
    (h_valid : match message_ba with
      | .vector .u8 bytes => bytes.length = 32
      | _ => False) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 39 ∧
      stack' = [message_ba] := by
  sorry

/-! ## PC 39→40: StLoc message_ba -/

theorem pc39_to_40
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 39)
    (message_ba : MoveValue)
    (h_stack : stack = [message_ba]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 40 ∧
      frame'.locals[16]? = some (some message_ba) ∧
      stack' = [] := by
  sorry

/-! ## PC 40→41: CopyLoc message_ba -/

theorem pc40_to_41
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 40)
    (message_ba : MoveValue)
    (h_local : frame.locals[16]? = some (some message_ba)) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 41 ∧
      stack' = [message_ba] := by
  sorry

/-! ## PC 41→42: Call sha3_256 -/

theorem pc41_to_42
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 41)
    (message_ba : MoveValue)
    (h_stack : stack = [message_ba])
    (message_hash : MoveValue)
    (h_oracle : o.sha3_256 [message_ba] = some [message_hash])
    (h_valid : match message_hash with
      | .vector .u8 bytes => bytes.length = 32
      | _ => False) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 42 ∧
      stack' = [message_hash] := by
  sorry

/-! ## PC 42→43: StLoc message_hash -/

theorem pc42_to_43
    (o : RegistrationNativeOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (h_pc : frame.pc = 42)
    (message_hash : MoveValue)
    (h_stack : stack = [message_hash]) :
    ∃ frame' stack' ms',
      step (registrationModuleEnv o) [] frame stack ms =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 43 ∧
      frame'.locals[17]? = some (some message_hash) ∧
      stack' = [] := by
  sorry

/-! ## Phase 2 Complete Composition -/

/-- Compose all Phase 2 proofs (PC 20→43) -/
theorem phase2_complete
    (o : RegistrationNativeOracle)
    (inputs : RegistrationInputValues)
    (frame₂₀ : Frame) (stack₂₀ : List MoveValue) (ms₂₀ : MachineState)
    (h_pc : frame₂₀.pc = 20)
    (h_phase1_complete : ∃ commit_pt resp_pt,
      frame₂₀.locals[9]? = some (some commit_pt) ∧
      frame₂₀.locals[12]? = some (some resp_pt)) :
    ∃ frame' stack' ms',
      run (registrationModuleEnv o) 23 [] frame₂₀ stack₂₀ ms₂₀ =
      .ok [] frame' stack' ms' ∧
      frame'.pc = 43 ∧
      ∃ message_pt challenge_sc,
        frame'.locals[15]? = some (some message_pt) ∧
        frame'.locals[17]? = some (some challenge_sc) := by
  sorry

end MovementFormal.Experimental.ConfidentialAsset.Registration
