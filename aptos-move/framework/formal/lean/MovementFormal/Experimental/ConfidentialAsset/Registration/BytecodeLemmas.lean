import MovementFormal.MoveModel.Programs.Registration
import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State

/-! # Bytecode Access Lemmas for Registration

Concrete proofs that specific PCs contain specific instructions.
These lemmas are used throughout the singleton branch proofs.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeLemmas

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Registration

/-! ## Function Indices

Actual function indices in registrationModuleEnv, matching the definition
in MovementFormal/MoveModel/Programs/Registration.lean lines 188-219.
-/

def funcIdx_newCompressedPointFromBytes : Nat := 0
def funcIdx_optionIsSome : Nat := 1
def funcIdx_optionExtract : Nat := 2
def funcIdx_newScalarFromBytes : Nat := 3
def funcIdx_vectorPushBackU8 : Nat := 4
def funcIdx_bcsToBytes : Nat := 5
def funcIdx_vectorAppendU8 : Nat := 6
def funcIdx_pubkeyToBytes : Nat := 7
def funcIdx_compressedPointToBytes : Nat := 8
def funcIdx_newScalarFromSha2_512 : Nat := 9
def funcIdx_hashToPointBase : Nat := 10
def funcIdx_pubkeyToPoint : Nat := 11
def funcIdx_pointMul : Nat := 12
def funcIdx_pointAdd : Nat := 13
def funcIdx_pointDecompress : Nat := 14
def funcIdx_pointEquals : Nat := 15
def funcIdx_errorInvalidArgument : Nat := 16
def funcIdx_verifyRegistrationProof : Nat := 17

/-! ## PC Bound Lemmas

These prove that specific PC values are within bounds.
Provable by `decide` since the size is concrete.
-/

theorem pc43_inbounds : 43 < verifyRegistrationProofCode.size := by decide
theorem pc44_inbounds : 44 < verifyRegistrationProofCode.size := by decide
theorem pc45_inbounds : 45 < verifyRegistrationProofCode.size := by decide
theorem pc46_inbounds : 46 < verifyRegistrationProofCode.size := by decide
theorem pc47_inbounds : 47 < verifyRegistrationProofCode.size := by decide
theorem pc48_inbounds : 48 < verifyRegistrationProofCode.size := by decide
theorem pc49_inbounds : 49 < verifyRegistrationProofCode.size := by decide
theorem pc50_inbounds : 50 < verifyRegistrationProofCode.size := by decide
theorem pc51_inbounds : 51 < verifyRegistrationProofCode.size := by decide
theorem pc52_inbounds : 52 < verifyRegistrationProofCode.size := by decide
theorem pc53_inbounds : 53 < verifyRegistrationProofCode.size := by decide
theorem pc54_inbounds : 54 < verifyRegistrationProofCode.size := by decide
theorem pc55_inbounds : 55 < verifyRegistrationProofCode.size := by decide
theorem pc56_inbounds : 56 < verifyRegistrationProofCode.size := by decide
theorem pc57_inbounds : 57 < verifyRegistrationProofCode.size := by decide
theorem pc58_inbounds : 58 < verifyRegistrationProofCode.size := by decide
theorem pc59_inbounds : 59 < verifyRegistrationProofCode.size := by decide
theorem pc60_inbounds : 60 < verifyRegistrationProofCode.size := by decide

/-! ## Instruction Lemmas

These prove that specific PCs contain specific instructions.
Provable by `rfl` since the bytecode is concrete.
-/

theorem instr43_eq : verifyRegistrationProofCode[43]'pc43_inbounds = .moveLoc 11 := by rfl
theorem instr44_eq : verifyRegistrationProofCode[44]'pc44_inbounds = .call funcIdx_newScalarFromSha2_512 := by rfl
theorem instr45_eq : verifyRegistrationProofCode[45]'pc45_inbounds = .stLoc 12 := by rfl
theorem instr46_eq : verifyRegistrationProofCode[46]'pc46_inbounds = .call funcIdx_hashToPointBase := by rfl
theorem instr47_eq : verifyRegistrationProofCode[47]'pc47_inbounds = .stLoc 13 := by rfl
theorem instr48_eq : verifyRegistrationProofCode[48]'pc48_inbounds = .moveLoc 3 := by rfl
theorem instr49_eq : verifyRegistrationProofCode[49]'pc49_inbounds = .call funcIdx_pubkeyToPoint := by rfl
theorem instr50_eq : verifyRegistrationProofCode[50]'pc50_inbounds = .stLoc 14 := by rfl
theorem instr51_eq : verifyRegistrationProofCode[51]'pc51_inbounds = .immBorrowLoc 13 := by rfl
theorem instr52_eq : verifyRegistrationProofCode[52]'pc52_inbounds = .immBorrowLoc 10 := by rfl
theorem instr53_eq : verifyRegistrationProofCode[53]'pc53_inbounds = .call funcIdx_pointMul := by rfl
theorem instr54_eq : verifyRegistrationProofCode[54]'pc54_inbounds = .stLoc 15 := by rfl
theorem instr55_eq : verifyRegistrationProofCode[55]'pc55_inbounds = .immBorrowLoc 15 := by rfl
theorem instr56_eq : verifyRegistrationProofCode[56]'pc56_inbounds = .immBorrowLoc 14 := by rfl
theorem instr57_eq : verifyRegistrationProofCode[57]'pc57_inbounds = .immBorrowLoc 12 := by rfl
theorem instr58_eq : verifyRegistrationProofCode[58]'pc58_inbounds = .call funcIdx_pointMul := by rfl
theorem instr59_eq : verifyRegistrationProofCode[59]'pc59_inbounds = .stLoc 16 := by rfl
theorem instr60_eq : verifyRegistrationProofCode[60]'pc60_inbounds = .immBorrowLoc 16 := by rfl

end MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeLemmas
