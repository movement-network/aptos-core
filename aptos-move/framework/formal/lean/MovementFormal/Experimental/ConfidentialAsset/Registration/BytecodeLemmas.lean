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

-- Message assembly range (PCs 20-42)
theorem pc20_inbounds : 20 < verifyRegistrationProofCode.size := by decide
theorem pc21_inbounds : 21 < verifyRegistrationProofCode.size := by decide
theorem pc22_inbounds : 22 < verifyRegistrationProofCode.size := by decide
theorem pc23_inbounds : 23 < verifyRegistrationProofCode.size := by decide
theorem pc24_inbounds : 24 < verifyRegistrationProofCode.size := by decide
theorem pc25_inbounds : 25 < verifyRegistrationProofCode.size := by decide
theorem pc26_inbounds : 26 < verifyRegistrationProofCode.size := by decide
theorem pc27_inbounds : 27 < verifyRegistrationProofCode.size := by decide
theorem pc28_inbounds : 28 < verifyRegistrationProofCode.size := by decide
theorem pc29_inbounds : 29 < verifyRegistrationProofCode.size := by decide
theorem pc30_inbounds : 30 < verifyRegistrationProofCode.size := by decide
theorem pc31_inbounds : 31 < verifyRegistrationProofCode.size := by decide
theorem pc32_inbounds : 32 < verifyRegistrationProofCode.size := by decide
theorem pc33_inbounds : 33 < verifyRegistrationProofCode.size := by decide
theorem pc34_inbounds : 34 < verifyRegistrationProofCode.size := by decide
theorem pc35_inbounds : 35 < verifyRegistrationProofCode.size := by decide
theorem pc36_inbounds : 36 < verifyRegistrationProofCode.size := by decide
theorem pc37_inbounds : 37 < verifyRegistrationProofCode.size := by decide
theorem pc38_inbounds : 38 < verifyRegistrationProofCode.size := by decide
theorem pc39_inbounds : 39 < verifyRegistrationProofCode.size := by decide
theorem pc40_inbounds : 40 < verifyRegistrationProofCode.size := by decide
theorem pc41_inbounds : 41 < verifyRegistrationProofCode.size := by decide
theorem pc42_inbounds : 42 < verifyRegistrationProofCode.size := by decide

-- Sigma verification range (PCs 43-70)
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
theorem pc61_inbounds : 61 < verifyRegistrationProofCode.size := by decide
theorem pc62_inbounds : 62 < verifyRegistrationProofCode.size := by decide
theorem pc63_inbounds : 63 < verifyRegistrationProofCode.size := by decide
theorem pc64_inbounds : 64 < verifyRegistrationProofCode.size := by decide
theorem pc65_inbounds : 65 < verifyRegistrationProofCode.size := by decide
theorem pc66_inbounds : 66 < verifyRegistrationProofCode.size := by decide
theorem pc67_inbounds : 67 < verifyRegistrationProofCode.size := by decide
theorem pc68_inbounds : 68 < verifyRegistrationProofCode.size := by decide
theorem pc69_inbounds : 69 < verifyRegistrationProofCode.size := by decide
theorem pc70_inbounds : 70 < verifyRegistrationProofCode.size := by decide

/-! ## Instruction Lemmas

These prove that specific PCs contain specific instructions.
Provable by `rfl` since the bytecode is concrete.
-/

-- Message assembly instructions (PCs 20-42)
theorem instr20_eq : verifyRegistrationProofCode[20]'pc20_inbounds = .mutBorrowLoc 11 := by rfl
theorem instr21_eq : verifyRegistrationProofCode[21]'pc21_inbounds = .moveLoc 0 := by rfl
theorem instr22_eq : verifyRegistrationProofCode[22]'pc22_inbounds = .call funcIdx_vectorPushBackU8 := by rfl
theorem instr23_eq : verifyRegistrationProofCode[23]'pc23_inbounds = .mutBorrowLoc 11 := by rfl
theorem instr24_eq : verifyRegistrationProofCode[24]'pc24_inbounds = .immBorrowLoc 1 := by rfl
theorem instr25_eq : verifyRegistrationProofCode[25]'pc25_inbounds = .call funcIdx_bcsToBytes := by rfl
theorem instr26_eq : verifyRegistrationProofCode[26]'pc26_inbounds = .call funcIdx_vectorAppendU8 := by rfl
theorem instr27_eq : verifyRegistrationProofCode[27]'pc27_inbounds = .mutBorrowLoc 11 := by rfl
theorem instr28_eq : verifyRegistrationProofCode[28]'pc28_inbounds = .immBorrowLoc 2 := by rfl
theorem instr29_eq : verifyRegistrationProofCode[29]'pc29_inbounds = .call funcIdx_bcsToBytes := by rfl
theorem instr30_eq : verifyRegistrationProofCode[30]'pc30_inbounds = .call funcIdx_vectorAppendU8 := by rfl
theorem instr31_eq : verifyRegistrationProofCode[31]'pc31_inbounds = .mutBorrowLoc 11 := by rfl
theorem instr32_eq : verifyRegistrationProofCode[32]'pc32_inbounds = .immBorrowLoc 4 := by rfl
theorem instr33_eq : verifyRegistrationProofCode[33]'pc33_inbounds = .call funcIdx_bcsToBytes := by rfl
theorem instr34_eq : verifyRegistrationProofCode[34]'pc34_inbounds = .call funcIdx_vectorAppendU8 := by rfl
theorem instr35_eq : verifyRegistrationProofCode[35]'pc35_inbounds = .mutBorrowLoc 11 := by rfl
theorem instr36_eq : verifyRegistrationProofCode[36]'pc36_inbounds = .copyLoc 3 := by rfl
theorem instr37_eq : verifyRegistrationProofCode[37]'pc37_inbounds = .call funcIdx_pubkeyToBytes := by rfl
theorem instr38_eq : verifyRegistrationProofCode[38]'pc38_inbounds = .call funcIdx_vectorAppendU8 := by rfl
theorem instr39_eq : verifyRegistrationProofCode[39]'pc39_inbounds = .mutBorrowLoc 11 := by rfl
theorem instr40_eq : verifyRegistrationProofCode[40]'pc40_inbounds = .copyLoc 8 := by rfl
theorem instr41_eq : verifyRegistrationProofCode[41]'pc41_inbounds = .call funcIdx_compressedPointToBytes := by rfl
theorem instr42_eq : verifyRegistrationProofCode[42]'pc42_inbounds = .call funcIdx_vectorAppendU8 := by rfl

-- Sigma verification instructions (PCs 43-70)
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
theorem instr61_eq : verifyRegistrationProofCode[61]'pc61_inbounds = .call funcIdx_pointAdd := by rfl
theorem instr62_eq : verifyRegistrationProofCode[62]'pc62_inbounds = .stLoc 17 := by rfl
theorem instr63_eq : verifyRegistrationProofCode[63]'pc63_inbounds = .immBorrowLoc 8 := by rfl
theorem instr64_eq : verifyRegistrationProofCode[64]'pc64_inbounds = .call funcIdx_pointDecompress := by rfl
theorem instr65_eq : verifyRegistrationProofCode[65]'pc65_inbounds = .stLoc 18 := by rfl
theorem instr66_eq : verifyRegistrationProofCode[66]'pc66_inbounds = .immBorrowLoc 17 := by rfl
theorem instr67_eq : verifyRegistrationProofCode[67]'pc67_inbounds = .immBorrowLoc 18 := by rfl
theorem instr68_eq : verifyRegistrationProofCode[68]'pc68_inbounds = .call funcIdx_pointEquals := by rfl
theorem instr69_eq : verifyRegistrationProofCode[69]'pc69_inbounds = .brFalse 71 := by rfl
theorem instr70_eq : verifyRegistrationProofCode[70]'pc70_inbounds = .ret := by rfl

end MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeLemmas
