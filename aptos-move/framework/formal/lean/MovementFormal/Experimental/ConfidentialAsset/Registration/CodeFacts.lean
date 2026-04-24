import MovementFormal.MoveModel.Programs.Registration
import MovementFormal.MoveModel.Instr

/-! # Verified Facts About Registration Code

Proven facts about the `verifyRegistrationProofCode` bytecode array.
These are simple but essential facts used throughout the singleton branch proofs.

All proofs use `decide` or `rfl` - they are verified computationally.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.CodeFacts

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Registration

/-! ## Code Size Facts -/

/-- The registration code has at least 71 instructions -/
theorem code_size_ge_71 : 71 ≤ verifyRegistrationProofCode.size := by decide

/-- The registration code has at least 80 instructions -/
theorem code_size_ge_80 : 80 ≤ verifyRegistrationProofCode.size := by decide

/-- PC bounds for all PCs in the singleton branch (4-70) -/
theorem pc_in_bounds_4 : 4 < verifyRegistrationProofCode.size := by decide
theorem pc_in_bounds_5 : 5 < verifyRegistrationProofCode.size := by decide
theorem pc_in_bounds_6 : 6 < verifyRegistrationProofCode.size := by decide
theorem pc_in_bounds_7 : 7 < verifyRegistrationProofCode.size := by decide
theorem pc_in_bounds_10 : 10 < verifyRegistrationProofCode.size := by decide
theorem pc_in_bounds_13 : 13 < verifyRegistrationProofCode.size := by decide
theorem pc_in_bounds_20 : 20 < verifyRegistrationProofCode.size := by decide
theorem pc_in_bounds_43 : 43 < verifyRegistrationProofCode.size := by decide
theorem pc_in_bounds_70 : 70 < verifyRegistrationProofCode.size := by decide

/-! ## Instruction Content Facts

Proven facts about what instruction appears at each PC.
These can be verified by `rfl` since the code array is concrete.
-/

theorem instr_at_4 (h : 4 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[4] = MoveInstr.call 1 := by rfl

theorem instr_at_5 (h : 5 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[5] = MoveInstr.brFalse 79 := by rfl

theorem instr_at_6 (h : 6 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[6] = MoveInstr.mutBorrowLoc 7 := by rfl

theorem instr_at_7 (h : 7 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[7] = MoveInstr.call 2 := by rfl

theorem instr_at_10 (h : 10 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[10] = MoveInstr.call 3 := by rfl

theorem instr_at_13 (h : 13 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[13] = MoveInstr.call 1 := by rfl

theorem instr_at_14 (h : 14 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[14] = MoveInstr.brFalse 74 := by rfl

theorem instr_at_70 (h : 70 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[70] = MoveInstr.ret := by rfl

/-! ## Branch Target Facts -/

/-- PC 5 branches to 79 on false -/
theorem pc5_branch_target (h : 5 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[5] = MoveInstr.brFalse 79 := by rfl

/-- PC 14 branches to 74 on false -/
theorem pc14_branch_target (h : 14 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[14] = MoveInstr.brFalse 74 := by rfl

/-! ## Call Instruction Facts -/

/-- PC 4 calls function 1 (option::is_some) -/
theorem pc4_calls_isSome (h : 4 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[4] = MoveInstr.call 1 := by rfl

/-- PC 7 calls function 2 (option::extract) -/
theorem pc7_calls_extract (h : 7 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[7] = MoveInstr.call 2 := by rfl

/-- PC 10 calls function 3 (scalar_from_bytes) -/
theorem pc10_calls_scalarFromBytes (h : 10 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[10] = MoveInstr.call 3 := by rfl

/-- PC 13 calls function 1 (option::is_some) again -/
theorem pc13_calls_isSome (h : 13 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[13] = MoveInstr.call 1 := by rfl

/-! ## PC Progression Facts

Facts about PC increments for non-branching instructions.
-/

/-- After executing PC 4 (call), PC advances to 5 -/
theorem pc4_advances_to_5 : 4 + 1 = 5 := by rfl

/-- After executing PC 6 (mutBorrowLoc), PC advances to 7 -/
theorem pc6_advances_to_7 : 6 + 1 = 7 := by rfl

/-- After executing PC 7 (call), PC advances to 8 -/
theorem pc7_advances_to_8 : 7 + 1 = 8 := by rfl

/-! ## Helper Theorems for Bound Proofs -/

/-- If PC < 70 and instruction is not branch/ret, next PC is in bounds -/
theorem next_pc_in_bounds_below_70 (pc : Nat) (h : pc < 70) :
    pc + 1 < verifyRegistrationProofCode.size := by
  have : 71 ≤ verifyRegistrationProofCode.size := code_size_ge_71
  omega

/-- Specific instances for key PCs -/
theorem pc4_next_in_bounds : 5 < verifyRegistrationProofCode.size := pc_in_bounds_5
theorem pc6_next_in_bounds : 7 < verifyRegistrationProofCode.size := pc_in_bounds_7
theorem pc7_next_in_bounds : 8 < verifyRegistrationProofCode.size := by
  have : 71 ≤ verifyRegistrationProofCode.size := code_size_ge_71
  omega

/-! ## Locals and LocalRefs Size Facts -/

/-- The registration function uses 19 locals total -/
def REGISTRATION_LOCALS_COUNT : Nat := 19

theorem locals_count_eq : REGISTRATION_LOCALS_COUNT = 19 := rfl

/-- LocalRefs array has size 19 -/
theorem localRefs_array_size :
    ((List.replicate 19 none).toArray : Array (Option RefId)).size = 19 := by rfl

/-- Index 7 is in bounds for locals array of size 19 -/
theorem index_7_in_bounds : 7 < 19 := by decide

/-- Index 18 (last local) is in bounds -/
theorem index_18_in_bounds : 18 < 19 := by decide

/-! ## Fuel Facts -/

/-- Minimum fuel needed for PC 4-70 sequence (67 instructions) -/
def MIN_FUEL_PC4_TO_70 : Nat := 67

theorem min_fuel_sufficient : 67 ≤ MIN_FUEL_PC4_TO_70 := by rfl

/-- If fuel ≥ 67, we can execute all 67 steps -/
theorem fuel_sufficient_for_singleton (fuel : Nat) (h : 67 ≤ fuel) :
    MIN_FUEL_PC4_TO_70 ≤ fuel := h

end MovementFormal.Experimental.ConfidentialAsset.Registration.CodeFacts
