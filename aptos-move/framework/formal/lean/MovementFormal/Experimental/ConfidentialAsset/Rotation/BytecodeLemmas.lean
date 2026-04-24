import MovementFormal.MoveModel.Programs.Rotation

/-!
# Bytecode Specification Lemmas for Rotation

Provides proved lemmas about `verifyRotationProofCode` bytecode array.
Extracted from inline proofs in `EvalEquiv.lean` to improve organization
and reusability.

## Coverage

All 15 PCs (0-14) with complete specification:
- PC bound lemmas (pc*_inbounds)
- Instruction equality lemmas (instr*_eq)
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Rotation.BytecodeLemmas

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Rotation

/-! ## PC bound lemmas -/

theorem pc0_inbounds  : 0  < verifyRotationProofCode.size := by decide
theorem pc1_inbounds  : 1  < verifyRotationProofCode.size := by decide
theorem pc2_inbounds  : 2  < verifyRotationProofCode.size := by decide
theorem pc3_inbounds  : 3  < verifyRotationProofCode.size := by decide
theorem pc4_inbounds  : 4  < verifyRotationProofCode.size := by decide
theorem pc5_inbounds  : 5  < verifyRotationProofCode.size := by decide
theorem pc6_inbounds  : 6  < verifyRotationProofCode.size := by decide
theorem pc7_inbounds  : 7  < verifyRotationProofCode.size := by decide
theorem pc8_inbounds  : 8  < verifyRotationProofCode.size := by decide
theorem pc9_inbounds  : 9  < verifyRotationProofCode.size := by decide
theorem pc10_inbounds : 10 < verifyRotationProofCode.size := by decide
theorem pc11_inbounds : 11 < verifyRotationProofCode.size := by decide
theorem pc12_inbounds : 12 < verifyRotationProofCode.size := by decide
theorem pc13_inbounds : 13 < verifyRotationProofCode.size := by decide
theorem pc14_inbounds : 14 < verifyRotationProofCode.size := by decide

/-! ## Instruction equality lemmas -/

theorem instr0_eq  : verifyRotationProofCode[0]'pc0_inbounds   = .moveLoc 0        := by rfl
theorem instr1_eq  : verifyRotationProofCode[1]'pc1_inbounds   = .moveLoc 1        := by rfl
theorem instr2_eq  : verifyRotationProofCode[2]'pc2_inbounds   = .moveLoc 2        := by rfl
theorem instr3_eq  : verifyRotationProofCode[3]'pc3_inbounds   = .moveLoc 3        := by rfl
theorem instr4_eq  : verifyRotationProofCode[4]'pc4_inbounds   = .moveLoc 4        := by rfl
theorem instr5_eq  : verifyRotationProofCode[5]'pc5_inbounds   = .moveLoc 5        := by rfl
theorem instr6_eq  : verifyRotationProofCode[6]'pc6_inbounds   = .copyLoc 6        := by rfl
theorem instr7_eq  : verifyRotationProofCode[7]'pc7_inbounds   = .copyLoc 7        := by rfl
theorem instr8_eq  : verifyRotationProofCode[8]'pc8_inbounds   = .immBorrowField 0 := by rfl
theorem instr9_eq  : verifyRotationProofCode[9]'pc9_inbounds   = .call 0           := by rfl
theorem instr10_eq : verifyRotationProofCode[10]'pc10_inbounds = .moveLoc 6        := by rfl
theorem instr11_eq : verifyRotationProofCode[11]'pc11_inbounds = .moveLoc 7        := by rfl
theorem instr12_eq : verifyRotationProofCode[12]'pc12_inbounds = .immBorrowField 1 := by rfl
theorem instr13_eq : verifyRotationProofCode[13]'pc13_inbounds = .call 1           := by rfl
theorem instr14_eq : verifyRotationProofCode[14]'pc14_inbounds = .ret              := by rfl

end MovementFormal.Experimental.ConfidentialAsset.Rotation.BytecodeLemmas
