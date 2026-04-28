import MovementFormal.MoveModel.Programs.Transfer

/-!
# Bytecode Specification Lemmas for Transfer

Provides proved lemmas about `verifyTransferProofCode` bytecode array.
Extracted from inline proofs in `EvalEquiv.lean` to improve organization
and reusability.

## Coverage

All 24 PCs (0-23) with complete specification:
- PC bound lemmas (pc*_inbounds)
- Instruction equality lemmas (instr*_eq)
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Transfer.BytecodeLemmas

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Transfer

/-! ## PC bound lemmas -/

theorem pc0_inbounds  : 0  < verifyTransferProofCode.size := by decide
theorem pc1_inbounds  : 1  < verifyTransferProofCode.size := by decide
theorem pc2_inbounds  : 2  < verifyTransferProofCode.size := by decide
theorem pc3_inbounds  : 3  < verifyTransferProofCode.size := by decide
theorem pc4_inbounds  : 4  < verifyTransferProofCode.size := by decide
theorem pc5_inbounds  : 5  < verifyTransferProofCode.size := by decide
theorem pc6_inbounds  : 6  < verifyTransferProofCode.size := by decide
theorem pc7_inbounds  : 7  < verifyTransferProofCode.size := by decide
theorem pc8_inbounds  : 8  < verifyTransferProofCode.size := by decide
theorem pc9_inbounds  : 9  < verifyTransferProofCode.size := by decide
theorem pc10_inbounds : 10 < verifyTransferProofCode.size := by decide
theorem pc11_inbounds : 11 < verifyTransferProofCode.size := by decide
theorem pc12_inbounds : 12 < verifyTransferProofCode.size := by decide
theorem pc13_inbounds : 13 < verifyTransferProofCode.size := by decide
theorem pc14_inbounds : 14 < verifyTransferProofCode.size := by decide
theorem pc15_inbounds : 15 < verifyTransferProofCode.size := by decide
theorem pc16_inbounds : 16 < verifyTransferProofCode.size := by decide
theorem pc17_inbounds : 17 < verifyTransferProofCode.size := by decide
theorem pc18_inbounds : 18 < verifyTransferProofCode.size := by decide
theorem pc19_inbounds : 19 < verifyTransferProofCode.size := by decide
theorem pc20_inbounds : 20 < verifyTransferProofCode.size := by decide
theorem pc21_inbounds : 21 < verifyTransferProofCode.size := by decide
theorem pc22_inbounds : 22 < verifyTransferProofCode.size := by decide
theorem pc23_inbounds : 23 < verifyTransferProofCode.size := by decide

/-! ## Instruction equality lemmas -/

theorem instr0_eq  : verifyTransferProofCode[0]'pc0_inbounds   = .moveLoc 0        := by rfl
theorem instr1_eq  : verifyTransferProofCode[1]'pc1_inbounds   = .moveLoc 1        := by rfl
theorem instr2_eq  : verifyTransferProofCode[2]'pc2_inbounds   = .moveLoc 2        := by rfl
theorem instr3_eq  : verifyTransferProofCode[3]'pc3_inbounds   = .moveLoc 3        := by rfl
theorem instr4_eq  : verifyTransferProofCode[4]'pc4_inbounds   = .moveLoc 4        := by rfl
theorem instr5_eq  : verifyTransferProofCode[5]'pc5_inbounds   = .moveLoc 5        := by rfl
theorem instr6_eq  : verifyTransferProofCode[6]'pc6_inbounds   = .copyLoc 6        := by rfl
theorem instr7_eq  : verifyTransferProofCode[7]'pc7_inbounds   = .moveLoc 7        := by rfl
theorem instr8_eq  : verifyTransferProofCode[8]'pc8_inbounds   = .copyLoc 8        := by rfl
theorem instr9_eq  : verifyTransferProofCode[9]'pc9_inbounds   = .moveLoc 9        := by rfl
theorem instr10_eq : verifyTransferProofCode[10]'pc10_inbounds = .moveLoc 10       := by rfl
theorem instr11_eq : verifyTransferProofCode[11]'pc11_inbounds = .moveLoc 11       := by rfl
theorem instr12_eq : verifyTransferProofCode[12]'pc12_inbounds = .copyLoc 12       := by rfl
theorem instr13_eq : verifyTransferProofCode[13]'pc13_inbounds = .immBorrowField 0 := by rfl
theorem instr14_eq : verifyTransferProofCode[14]'pc14_inbounds = .call 0           := by rfl
theorem instr15_eq : verifyTransferProofCode[15]'pc15_inbounds = .moveLoc 6        := by rfl
theorem instr16_eq : verifyTransferProofCode[16]'pc16_inbounds = .copyLoc 12       := by rfl
theorem instr17_eq : verifyTransferProofCode[17]'pc17_inbounds = .immBorrowField 1 := by rfl
theorem instr18_eq : verifyTransferProofCode[18]'pc18_inbounds = .call 1           := by rfl
theorem instr19_eq : verifyTransferProofCode[19]'pc19_inbounds = .moveLoc 8        := by rfl
theorem instr20_eq : verifyTransferProofCode[20]'pc20_inbounds = .moveLoc 12       := by rfl
theorem instr21_eq : verifyTransferProofCode[21]'pc21_inbounds = .immBorrowField 2 := by rfl
theorem instr22_eq : verifyTransferProofCode[22]'pc22_inbounds = .call 2           := by rfl
theorem instr23_eq : verifyTransferProofCode[23]'pc23_inbounds = .ret              := by rfl

end MovementFormal.Experimental.ConfidentialAsset.Transfer.BytecodeLemmas
