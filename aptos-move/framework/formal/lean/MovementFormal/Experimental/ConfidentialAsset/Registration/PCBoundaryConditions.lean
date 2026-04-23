import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.Experimental.ConfidentialAsset.Registration.FrameConstructionHelpers
import MovementFormal.Experimental.ConfidentialAsset.Registration.ValidationLemmas

/-! # PC Boundary Conditions

This file specifies the exact state conditions that must hold at specific PC
boundaries in the registration singleton branch proof. These conditions serve as:
- Preconditions for entering a PC range
- Postconditions for exiting a PC range
- Invariants that hold at specific PCs

## Key PC Boundaries

- **PC 0**: Entry point, parameters initialized
- **PC 4**: Start of happy path, after initial setup
- **PC 5**: Error path (invalid commitment)
- **PC 14**: Error path (invalid response scalar)
- **PC 20**: End of Phase 1, start of Phase 2 (message assembly)
- **PC 43**: End of Phase 2, start of Phase 3 (sigma verification)
- **PC 70**: End of Phase 3, validation complete
- **PC 73**: Final branch before ret
- **PC 74/78/79**: Abort paths

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.PCBoundaryConditions

open MovementFormal.MoveModel
open MovementFormal.Experimental.ConfidentialAsset.Registration.FrameConstructionHelpers
open MovementFormal.Experimental.ConfidentialAsset.Registration.Validation

/-! ## PC 0 Boundary (Entry Point)

Conditions at function entry.
-/

/-- State at PC 0 (function entry). -/
structure StateAtPC0 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  -- Input parameters
  chainId : UInt8
  sender contract token : ByteArray
  ekBa commitBa respBa : ByteArray
  -- Frame properties
  h_pc : frame.pc = 0
  h_code : frame.code = verifyRegistrationProofCode
  h_locals : frame.locals = buildInitialLocals chainId sender contract token ekBa commitBa respBa
  h_localRefs : frame.localRefs = buildInitialLocalRefs
  -- Stack properties
  h_stack_empty : stack = []
  -- Machine state properties
  h_containers_empty : ms.containers = ContainerStore.empty

theorem stateAtPC0_wellformed
    (o : RegistrationNativeOracle)
    (s : StateAtPC0 o) :
    IsValidFrame s.frame ∧
    s.frame.locals.size = 19 ∧
    s.frame.localRefs.size = 19 := by
  sorry  -- From buildInitialLocals and buildInitialLocalRefs

theorem stateAtPC0_params_populated
    (o : RegistrationNativeOracle)
    (s : StateAtPC0 o)
    (idx : Nat)
    (h : idx < 7) :
    ∃ v, s.frame.locals[idx]? = some (some v) := by
  sorry  -- Parameters 0-6 are populated

theorem stateAtPC0_locals_unpopulated
    (o : RegistrationNativeOracle)
    (s : StateAtPC0 o)
    (idx : Nat)
    (h : 7 ≤ idx ∧ idx < 19) :
    s.frame.locals[idx]? = some none := by
  sorry  -- Locals 7-18 are none

/-! ## PC 4 Boundary (Happy Path Start)

Conditions after initial bytecode setup, at start of oracle validation.
-/

/-- State at PC 4 (start of happy path). -/
structure StateAtPC4 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  -- Original inputs (preserved in locals 0-6)
  chainId : UInt8
  sender contract token : ByteArray
  ekBa commitBa respBa : ByteArray
  -- Frame properties
  h_pc : frame.pc = 4
  h_code : frame.code = verifyRegistrationProofCode
  h_locals_size : frame.locals.size = 19
  h_localRefs_size : frame.localRefs.size = 19
  -- Parameters still present
  h_param0 : frame.locals[0]? = some (some (.u8 chainId))
  h_param1 : frame.locals[1]? = some (some (.address sender))
  h_param2 : frame.locals[2]? = some (some (.address contract))
  h_param3 : frame.locals[3]? = some (some (.address token))
  h_param4 : frame.locals[4]? = some (some (.vector .u8 (ekBa.toList.map .u8)))
  h_param5 : frame.locals[5]? = some (some (.vector .u8 (commitBa.toList.map .u8)))
  h_param6 : frame.locals[6]? = some (some (.vector .u8 (respBa.toList.map .u8)))
  -- Stack has option result from newCompressedPointFromBytes at PC 3
  h_stack_shape : ∃ option_val, stack = [option_val]

theorem stateAtPC4_ready_for_phase1
    (o : RegistrationNativeOracle)
    (s : StateAtPC4 o) :
    s.frame.pc = 4 ∧ s.frame.code = verifyRegistrationProofCode := by
  constructor
  · exact s.h_pc
  · exact s.h_code

/-! ## PC 20 Boundary (Phase 1 End / Phase 2 Start)

Conditions after oracle validation, before message assembly.
-/

/-- State at PC 20 (end of Phase 1, start of Phase 2). -/
structure StateAtPC20 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  -- Extracted values
  rCompressed : MoveValue
  responseScalar : MoveValue
  -- Original parameters (still in locals 0-6)
  chainId : UInt8
  sender contract token : ByteArray
  ekBa : ByteArray
  -- Frame properties
  h_pc : frame.pc = 20
  h_code : frame.code = verifyRegistrationProofCode
  -- Locals: parameters + extracted values
  h_local7 : ∃ rid_v, frame.locals[7]? = some (some (.immRef rid_v))
  h_local8 : frame.locals[8]? = some (some rCompressed)
  h_local9 : ∃ rid_s, frame.locals[9]? = some (some (.immRef rid_s))
  h_local10 : frame.locals[10]? = some (some responseScalar)
  -- Validity
  h_r_valid : IsValidCompressedPoint rCompressed
  h_s_valid : IsValidScalar responseScalar
  -- Stack empty
  h_stack_empty : stack = []

theorem stateAtPC20_phase1_complete
    (o : RegistrationNativeOracle)
    (s : StateAtPC20 o) :
    IsValidCompressedPoint s.rCompressed ∧
    IsValidScalar s.responseScalar := by
  constructor
  · exact s.h_r_valid
  · exact s.h_s_valid

theorem stateAtPC20_ready_for_message_assembly
    (o : RegistrationNativeOracle)
    (s : StateAtPC20 o) :
    s.frame.pc = 20 ∧ s.stack = [] := by
  constructor
  · exact s.h_pc
  · exact s.h_stack_empty

/-! ## PC 43 Boundary (Phase 2 End / Phase 3 Start)

Conditions after message assembly, before sigma verification.
-/

/-- State at PC 43 (end of Phase 2, start of Phase 3). -/
structure StateAtPC43 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  -- Phase 1 results (still in locals)
  rCompressed responseScalar : MoveValue
  -- Message buffer
  rid_msg : RefId
  assembled_bytes : List MoveValue
  -- Original parameters
  chainId : UInt8
  sender contract token ekBa : ByteArray
  -- Frame properties
  h_pc : frame.pc = 43
  h_code : frame.code = verifyRegistrationProofCode
  -- Locals: Phase 1 results + message buffer reference
  h_local8 : frame.locals[8]? = some (some rCompressed)
  h_local10 : frame.locals[10]? = some (some responseScalar)
  h_local11 : ∃ rid, frame.locals[11]? = some (some (.mutRef rid)) ∧ rid = rid_msg
  -- Message buffer contents
  h_msg_assembled : ms.containers.read rid_msg = some (.vector .u8 assembled_bytes)
  h_msg_length : assembled_bytes.length = 129  -- 1 + 32 + 32 + 32 + 32
  h_msg_structure : assembled_bytes =
    [.u8 chainId] ++
    (sender.toList.map .u8) ++
    (contract.toList.map .u8) ++
    (token.toList.map .u8) ++
    (ekBa.toList.map .u8)
  -- Stack empty
  h_stack_empty : stack = []

theorem stateAtPC43_message_ready
    (o : RegistrationNativeOracle)
    (s : StateAtPC43 o) :
    ∃ msg_bytes,
      s.ms.containers.read s.rid_msg = some (.vector .u8 msg_bytes) ∧
      msg_bytes.length = 129 := by
  use s.assembled_bytes
  constructor
  · exact s.h_msg_assembled
  · exact s.h_msg_length

theorem stateAtPC43_ready_for_sigma
    (o : RegistrationNativeOracle)
    (s : StateAtPC43 o) :
    s.frame.pc = 43 ∧ s.stack = [] := by
  constructor
  · exact s.h_pc
  · exact s.h_stack_empty

/-! ## PC 70 Boundary (Phase 3 End)

Conditions after sigma verification completes successfully.
-/

/-- State at PC 70 (end of Phase 3, validation complete). -/
structure StateAtPC70 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  -- Verification result
  equals_result : Bool
  -- Frame properties
  h_pc : frame.pc = 70
  h_code : frame.code = verifyRegistrationProofCode
  -- Stack has equality result
  h_stack : stack = [.bool equals_result]
  -- Happy path: equals_result = true
  h_equals_true : equals_result = true

theorem stateAtPC70_verification_passed
    (o : RegistrationNativeOracle)
    (s : StateAtPC70 o) :
    s.equals_result = true := by
  exact s.h_equals_true

theorem stateAtPC70_ready_for_final_branch
    (o : RegistrationNativeOracle)
    (s : StateAtPC70 o) :
    s.frame.pc = 70 ∧ s.stack = [.bool true] := by
  constructor
  · exact s.h_pc
  · rw [s.h_stack, s.h_equals_true]

/-! ## PC 73 Boundary (Final Branch)

Conditions at final brFalse before ret.
-/

/-- State at PC 73 (final branch check). -/
structure StateAtPC73 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  -- Frame properties
  h_pc : frame.pc = 73
  h_code : frame.code = verifyRegistrationProofCode
  -- Stack has true (happy path)
  h_stack : stack = [.bool true]

theorem stateAtPC73_branch_not_taken
    (o : RegistrationNativeOracle)
    (s : StateAtPC73 o) :
    -- brFalse at PC 73 will not jump (continues to ret at PC 74)
    s.stack = [.bool true] := by
  exact s.h_stack

/-! ## Error Path PC Boundaries

Conditions at error path PCs.
-/

/-- State at PC 5 (commitment validation failed). -/
structure StateAtPC5 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  h_pc : frame.pc = 5
  h_code : frame.code = verifyRegistrationProofCode
  -- Stack has false from optionIsSomeRef
  h_stack : stack = [.bool false]

theorem stateAtPC5_branches_to_error
    (o : RegistrationNativeOracle)
    (s : StateAtPC5 o) :
    -- brFalse at PC 5 will jump to PC 79 (abort)
    s.stack = [.bool false] := by
  exact s.h_stack

/-- State at PC 14 (response scalar validation failed). -/
structure StateAtPC14 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  h_pc : frame.pc = 14
  h_code : frame.code = verifyRegistrationProofCode
  h_stack : stack = [.bool false]

theorem stateAtPC14_branches_to_error
    (o : RegistrationNativeOracle)
    (s : StateAtPC14 o) :
    -- brFalse at PC 14 will jump to PC 74 (abort setup)
    s.stack = [.bool false] := by
  exact s.h_stack

/-- State at PC 74 (error path, about to abort). -/
structure StateAtPC74 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  h_pc : frame.pc = 74
  h_code : frame.code = verifyRegistrationProofCode

/-- State at PC 78 (error path, about to abort). -/
structure StateAtPC78 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  h_pc : frame.pc = 78
  h_code : frame.code = verifyRegistrationProofCode

/-- State at PC 79 (abort with error code). -/
structure StateAtPC79 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  h_pc : frame.pc = 79
  h_code : frame.code = verifyRegistrationProofCode
  -- Stack has error code 65537 = INVALID_ARGUMENT
  h_stack : stack = [.u64 65537]

theorem stateAtPC79_aborts
    (o : RegistrationNativeOracle)
    (s : StateAtPC79 o) :
    s.stack = [.u64 65537] := by
  exact s.h_stack

/-! ## Intermediate PC Conditions

Conditions at other significant intermediate PCs.
-/

/-- State at PC 8 (after extracting compressed point). -/
structure StateAtPC8 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  rCompressed : MoveValue
  h_pc : frame.pc = 8
  h_local8 : frame.locals[8]? = some (some rCompressed)
  h_stack : stack = [rCompressed]

/-- State at PC 18 (after extracting scalar). -/
structure StateAtPC18 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  responseScalar : MoveValue
  h_pc : frame.pc = 18
  h_local10 : frame.locals[10]? = some (some responseScalar)
  h_stack : stack = [responseScalar]

/-- State at PC 44 (after computing challenge). -/
structure StateAtPC44 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  challenge : MoveValue
  h_pc : frame.pc = 44
  h_stack : stack = [challenge]

/-- State at PC 50 (after storing challenge, base point on stack). -/
structure StateAtPC50 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  base : MoveValue
  challenge : MoveValue
  h_pc : frame.pc = 50
  h_local12 : frame.locals[12]? = some (some challenge)
  h_stack : stack = [base]

/-- State at PC 58 (after first point multiplication). -/
structure StateAtPC58 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  hs_product : MoveValue
  h_pc : frame.pc = 58
  h_local15 : frame.locals[15]? = some (some hs_product)
  h_stack : stack = []

/-- State at PC 68 (after point addition, before decompress). -/
structure StateAtPC68 (o : RegistrationNativeOracle) where
  frame : Frame
  stack : List MoveValue
  ms : MachineState
  lhs_sum : MoveValue
  h_pc : frame.pc = 68
  h_local17 : frame.locals[17]? = some (some lhs_sum)
  h_stack : stack = []

/-! ## Boundary Transition Theorems

Theorems about transitioning between PC boundaries.
-/

/-- Transition from PC 0 to PC 4 (setup). -/
axiom transition_pc0_to_pc4
    (o : RegistrationNativeOracle)
    (s0 : StateAtPC0 o) :
    ∃ (s4 : StateAtPC4 o),
      -- Parameters preserved
      s4.chainId = s0.chainId ∧
      s4.sender = s0.sender ∧
      s4.contract = s0.contract ∧
      s4.token = s0.token ∧
      s4.ekBa = s0.ekBa ∧
      s4.commitBa = s0.commitBa ∧
      s4.respBa = s0.respBa

/-- Transition from PC 4 to PC 20 (Phase 1). -/
axiom transition_pc4_to_pc20
    (o : RegistrationNativeOracle)
    (s4 : StateAtPC4 o)
    (h_valid_inputs : ValidRegistrationInputs s4.commitBa s4.respBa) :
    ∃ (s20 : StateAtPC20 o),
      -- Parameters preserved
      s20.chainId = s4.chainId ∧
      s20.sender = s4.sender ∧
      s20.contract = s4.contract ∧
      s20.token = s4.token ∧
      s20.ekBa = s4.ekBa

/-- Transition from PC 20 to PC 43 (Phase 2). -/
axiom transition_pc20_to_pc43
    (o : RegistrationNativeOracle)
    (s20 : StateAtPC20 o) :
    ∃ (s43 : StateAtPC43 o),
      -- Phase 1 results preserved
      s43.rCompressed = s20.rCompressed ∧
      s43.responseScalar = s20.responseScalar ∧
      -- Message assembled
      s43.assembled_bytes.length = 129

/-- Transition from PC 43 to PC 70 (Phase 3). -/
axiom transition_pc43_to_pc70
    (o : RegistrationNativeOracle)
    (s43 : StateAtPC43 o)
    (h_valid_proof : True) :  -- Placeholder for actual proof validity condition
    ∃ (s70 : StateAtPC70 o),
      s70.equals_result = true

/-- Transition from PC 70 to PC 73 (final steps). -/
axiom transition_pc70_to_pc73
    (o : RegistrationNativeOracle)
    (s70 : StateAtPC70 o) :
    ∃ (s73 : StateAtPC73 o),
      s73.stack = [.bool true]

/-! ## Auxiliary Utilities

Helper definitions for boundary condition reasoning.
-/

/-- Check if state is at a phase boundary. -/
def isAtPhaseBoundary (pc : Nat) : Bool :=
  pc = 0 ∨ pc = 4 ∨ pc = 20 ∨ pc = 43 ∨ pc = 70 ∨ pc = 73

/-- Check if state is on error path. -/
def isOnErrorPath (pc : Nat) : Bool :=
  pc = 5 ∨ pc = 14 ∨ pc = 74 ∨ pc = 78 ∨ pc = 79

/-- Check if state is on happy path. -/
def isOnHappyPath (pc : Nat) : Bool :=
  4 ≤ pc ∧ pc ≤ 73 ∧ ¬isOnErrorPath pc

theorem happy_path_excludes_error_pcs
    (pc : Nat)
    (h_happy : isOnHappyPath pc) :
    ¬isOnErrorPath pc := by
  unfold isOnHappyPath at h_happy
  sorry  -- From definition

end MovementFormal.Experimental.ConfidentialAsset.Registration.PCBoundaryConditions
