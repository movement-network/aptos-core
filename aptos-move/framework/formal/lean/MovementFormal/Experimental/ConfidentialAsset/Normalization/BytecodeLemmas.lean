import MovementFormal.MoveModel.Programs.Normalization

/-!
# Bytecode Specification Lemmas for Normalization

Provides proved lemmas about `verifyNormalizationProofCode` bytecode array.
Extracted from inline proofs in `EvalEquiv.lean` to improve organization
and reusability.

## Coverage

All 14 PCs (0-13) with complete specification:
- Array size lemma
- PC bound lemmas (pc*_inbounds)
- Instruction equality lemmas (instr*_eq)
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Normalization.BytecodeLemmas

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Normalization

/-! ## Array size -/

theorem code_size : verifyNormalizationProofCode.size = 14 := by rfl

/-! ## PC bound lemmas -/

theorem pc0_inbounds  : 0  < verifyNormalizationProofCode.size := by decide
theorem pc1_inbounds  : 1  < verifyNormalizationProofCode.size := by decide
theorem pc2_inbounds  : 2  < verifyNormalizationProofCode.size := by decide
theorem pc3_inbounds  : 3  < verifyNormalizationProofCode.size := by decide
theorem pc4_inbounds  : 4  < verifyNormalizationProofCode.size := by decide
theorem pc5_inbounds  : 5  < verifyNormalizationProofCode.size := by decide
theorem pc6_inbounds  : 6  < verifyNormalizationProofCode.size := by decide
theorem pc7_inbounds  : 7  < verifyNormalizationProofCode.size := by decide
theorem pc8_inbounds  : 8  < verifyNormalizationProofCode.size := by decide
theorem pc9_inbounds  : 9  < verifyNormalizationProofCode.size := by decide
theorem pc10_inbounds : 10 < verifyNormalizationProofCode.size := by decide
theorem pc11_inbounds : 11 < verifyNormalizationProofCode.size := by decide
theorem pc12_inbounds : 12 < verifyNormalizationProofCode.size := by decide
theorem pc13_inbounds : 13 < verifyNormalizationProofCode.size := by decide

/-! ## Instruction equality lemmas -/

theorem instr0_eq  : verifyNormalizationProofCode[0]'pc0_inbounds   = .moveLoc 0        := by rfl
theorem instr1_eq  : verifyNormalizationProofCode[1]'pc1_inbounds   = .moveLoc 1        := by rfl
theorem instr2_eq  : verifyNormalizationProofCode[2]'pc2_inbounds   = .moveLoc 2        := by rfl
theorem instr3_eq  : verifyNormalizationProofCode[3]'pc3_inbounds   = .moveLoc 3        := by rfl
theorem instr4_eq  : verifyNormalizationProofCode[4]'pc4_inbounds   = .moveLoc 4        := by rfl
theorem instr5_eq  : verifyNormalizationProofCode[5]'pc5_inbounds   = .copyLoc 5        := by rfl
theorem instr6_eq  : verifyNormalizationProofCode[6]'pc6_inbounds   = .copyLoc 6        := by rfl
theorem instr7_eq  : verifyNormalizationProofCode[7]'pc7_inbounds   = .immBorrowField 0 := by rfl
theorem instr8_eq  : verifyNormalizationProofCode[8]'pc8_inbounds   = .call 0           := by rfl
theorem instr9_eq  : verifyNormalizationProofCode[9]'pc9_inbounds   = .moveLoc 5        := by rfl
theorem instr10_eq : verifyNormalizationProofCode[10]'pc10_inbounds = .moveLoc 6        := by rfl
theorem instr11_eq : verifyNormalizationProofCode[11]'pc11_inbounds = .immBorrowField 1 := by rfl
theorem instr12_eq : verifyNormalizationProofCode[12]'pc12_inbounds = .call 1           := by rfl
theorem instr13_eq : verifyNormalizationProofCode[13]'pc13_inbounds = .ret              := by rfl

end MovementFormal.Experimental.ConfidentialAsset.Normalization.BytecodeLemmas
