import MovementFormal.MoveModel.Programs.Registration

/-! # Simple Facts for PC 4-20 Helper

Proves the simple `sorry` placeholders in PC4_20_concrete_helper that are
just concrete arithmetic or array bounds checks.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Registration

/-! ## Code Size Facts -/

theorem verifyRegistrationProofCode_size_gt_6 :
    6 < verifyRegistrationProofCode.size := by
  decide

theorem verifyRegistrationProofCode_size_gt_7 :
    7 < verifyRegistrationProofCode.size := by
  decide

theorem verifyRegistrationProofCode_size_gt_70 :
    70 < verifyRegistrationProofCode.size := by
  decide

/-! ## PC 6 Instruction Check -/

theorem verifyRegistrationProofCode_at_6
    (h : 6 < verifyRegistrationProofCode.size) :
    verifyRegistrationProofCode[6]'h = MoveInstr.mutBorrowLoc 7 := by
  rfl

/-! ## Locals Size Facts -/

theorem registrationLocals_size
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (v : MoveValue) :
    (registrationLocals chainId sender contract token ekBa commitBa respBa v none none none none none none none none none none none none).size = 19 := by
  rfl

theorem registrationLocals_size_gt_7
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (v : MoveValue) :
    7 < (registrationLocals chainId sender contract token ekBa commitBa respBa v none none none none none none none none none none none none).size := by
  rw [registrationLocals_size]
  decide

/-! ## LocalRefs Facts -/

theorem replicate_19_none_size :
    ((List.replicate 19 none).toArray : Array (Option RefId)).size = 19 := by
  rfl

theorem replicate_19_none_size_gt_7 :
    7 < ((List.replicate 19 none).toArray : Array (Option RefId)).size := by
  rw [replicate_19_none_size]
  decide

end MovementFormal.Experimental.ConfidentialAsset.Registration
