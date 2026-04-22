import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv.Part2B

/-!
This file is **Part2C** (PCs 55–62) of the split `EvalEquiv` proof.
See `Registration.EvalEquiv` and the sibling `Part2A` (PCs 31–43) and `Part2B` (PCs 44–54).
-/


namespace MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.MoveModel.Programs.Registration
open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
open MovementFormal.Experimental.ConfidentialAsset.Registration.Formal

set_option linter.unusedSimpArgs false

/-! ### PC 55 (`immBorrowLoc 15` — borrow hs) -/

@[simp] theorem verifyRegistrationProofCode_idx55 :
    verifyRegistrationProofCode[55]'(by rw [verifyRegistrationProofCode_size_val]; decide) =
      .immBorrowLoc 15 := rfl

theorem registrationFramePc55_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size = 19 := by
  have hsz53 := registrationFramePc53_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt
  simp [registrationFramePc55AfterStLoc15, Array.size_set, hsz53]

theorem registrationFramePc55_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs.size = 19 :=
  registrationFramePc51_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt

theorem registrationFramePc55_locals_idx15_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    15 < (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size := by
  rw [registrationFramePc55_locals_size]; decide

theorem registrationFramePc55_localRefs_idx15_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    15 < (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs.size := by
  rw [registrationFramePc55_localRefs_size]; decide

set_option maxHeartbeats 3200000 in
theorem registrationFramePc55_locals_idx15_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals[15]'
      (registrationFramePc55_locals_idx15_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) =
        some hsPt := by
  unfold registrationFramePc55AfterStLoc15
  rw [Array.getElem_set_self]

/-- **Shape lemma (prototype).** `Pc55.localRefs` reduces by `rfl` to `Pc22.localRefs.set 11 none`:
every intermediate frame from Pc44 to Pc53 either only rewrites `locals` or only bumps `pc`.
Proving this once lets downstream `localRefs`-indexing theorems rewrite through it without
having to `unfold` the 8-frame chain at each call site. -/
theorem registrationFramePc55_localRefs_eq_pc22_set11
    (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs =
      (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.set 11 none
        (registrationFramePc22_localRefs_idx11_lt args h mv rCompressed sOpt sVal) := rfl

theorem registrationFramePc55_localRefs_idx15_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs[15]'
      (registrationFramePc55_localRefs_idx15_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) = none := by
  have hne11 : (11 : Nat) ≠ 15 := by decide
  have hszR22 := registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal
  show ((registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.set 11 none
      (registrationFramePc22_localRefs_idx11_lt args h mv rCompressed sOpt sVal))[15]'_ = none
  rw [Array.getElem_set_ne (h := hne11)
    (pj := by rw [hszR22]; decide)
    (h' := by rw [hszR22]; decide)]
  exact registrationFramePc22_localRefs_idx15_eq args h mv rCompressed sOpt sVal

/-- Frame after `immBorrowLoc 15` (PC 55): same frame, pc := 56. -/
def registrationFramePc56AfterImmBorrow15 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) : Frame :=
  { registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with pc := 56 }

/-- **Projection cache (#1):** cache `(Pc55...).code = verifyRegistrationProofCode` once by `rfl`.
Downstream `hpc`/`hc` proofs rewrite through this instead of unfolding the 20-frame chain. -/
@[simp] theorem registrationFramePc55_code_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).code =
      verifyRegistrationProofCode := rfl

set_option maxHeartbeats 3200000 in
theorem registration_step_pc55_immBorrowLoc15_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc55AfterStLoc15 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with
            pc := 55 })
        [] rest ms =
      ExecResult.ok
        (registrationFramePc56AfterImmBorrow15 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] (.immRef (ms.containers.alloc hsPt).2 :: rest)
        { ms with containers := (ms.containers.alloc hsPt).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc55AfterStLoc15 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with
                pc := 55 }) with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [hfr', registrationFramePc55_code_eq, verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 15 := by
    simp [hfr', registrationFramePc55_code_eq, verifyRegistrationProofCode_idx55]
  have hlocLt : 15 < fr'.locals.size :=
    registrationFramePc55_locals_idx15_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocVal : fr'.locals[15]'hlocLt = some hsPt :=
    registrationFramePc55_locals_idx15_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocRefLt : 15 < fr'.localRefs.size :=
    registrationFramePc55_localRefs_idx15_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocRefVal : fr'.localRefs[15]'hlocRefLt = none :=
    registrationFramePc55_localRefs_idx15_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 56 (`immBorrowLoc 14` — borrow ekPt) -/

@[simp] theorem verifyRegistrationProofCode_idx56 :
    verifyRegistrationProofCode[56]'(by rw [verifyRegistrationProofCode_size_val]; decide) =
      .immBorrowLoc 14 := rfl

theorem registrationFramePc56_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size = 19 :=
  registrationFramePc55_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt

theorem registrationFramePc56_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs.size = 19 :=
  registrationFramePc55_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt

theorem registrationFramePc56_locals_idx14_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    14 < (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size := by
  rw [registrationFramePc56_locals_size]; decide

theorem registrationFramePc56_localRefs_idx14_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    14 < (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs.size := by
  rw [registrationFramePc56_localRefs_size]; decide

set_option maxHeartbeats 3200000 in
theorem registrationFramePc56_locals_idx14_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals[14]'
      (registrationFramePc56_locals_idx14_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) =
        some ekPt := by
  have hne15 : (15 : Nat) ≠ 14 := by decide
  have hsz49 : (registrationFramePc49AfterMoveLoc3 args h mv rCompressed sOpt sVal eScalar hPoint).locals.size = 19 := by
    simp [registrationFramePc49AfterMoveLoc3, Array.size_set,
      registrationFramePc48_locals_size args h mv rCompressed sOpt sVal eScalar hPoint]
  unfold registrationFramePc56AfterImmBorrow15 registrationFramePc55AfterStLoc15
    registrationFramePc53AfterImmBorrow10 registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14
  rw [Array.getElem_set_ne (h := hne15)
    (pj := by simp [Array.size_set, hsz49])
    (h' := by simp [Array.size_set, hsz49])]
  rw [Array.getElem_set_self]

set_option maxHeartbeats 3200000 in
theorem registrationFramePc56_localRefs_idx14_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs[14]'
      (registrationFramePc56_localRefs_idx14_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) = none := by
  have hne11 : (11 : Nat) ≠ 14 := by decide
  have hszR22 := registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal
  have hpc22 := registrationFramePc22_localRefs_idx14_eq args h mv rCompressed sOpt sVal
  unfold registrationFramePc56AfterImmBorrow15 registrationFramePc55AfterStLoc15
    registrationFramePc53AfterImmBorrow10 registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14
    registrationFramePc49AfterMoveLoc3 registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12
    registrationFramePc44AfterMoveLoc11
  rw [Array.getElem_set_ne (h := hne11)
    (pj := by rw [hszR22]; decide)
    (h' := by rw [hszR22]; decide)]
  exact hpc22

/-- Frame after `immBorrowLoc 14` (PC 56): same frame, pc := 57. -/
def registrationFramePc57AfterImmBorrow14 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) : Frame :=
  { registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with pc := 57 }

@[simp] theorem registrationFramePc56_pc_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).pc = 56 := rfl

@[simp] theorem registrationFramePc56_code_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).code =
      verifyRegistrationProofCode := rfl

set_option maxHeartbeats 3200000 in
theorem registration_step_pc56_immBorrowLoc14_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc56AfterImmBorrow15 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] rest ms =
      ExecResult.ok
        (registrationFramePc57AfterImmBorrow14 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] (.immRef (ms.containers.alloc ekPt).2 :: rest)
        { ms with containers := (ms.containers.alloc ekPt).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := registrationFramePc56AfterImmBorrow15 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [hfr', registrationFramePc56_pc_eq, registrationFramePc56_code_eq,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 14 := by
    simp [hfr', registrationFramePc56_pc_eq, registrationFramePc56_code_eq, verifyRegistrationProofCode_idx56]
  have hlocLt : 14 < fr'.locals.size :=
    registrationFramePc56_locals_idx14_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocVal : fr'.locals[14]'hlocLt = some ekPt :=
    registrationFramePc56_locals_idx14_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocRefLt : 14 < fr'.localRefs.size :=
    registrationFramePc56_localRefs_idx14_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocRefVal : fr'.localRefs[14]'hlocRefLt = none :=
    registrationFramePc56_localRefs_idx14_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 57 (`immBorrowLoc 12` — borrow eScalar) -/

@[simp] theorem verifyRegistrationProofCode_idx57 :
    verifyRegistrationProofCode[57]'(by rw [verifyRegistrationProofCode_size_val]; decide) =
      .immBorrowLoc 12 := rfl

theorem registrationFramePc57_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size = 19 :=
  registrationFramePc56_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt

theorem registrationFramePc57_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs.size = 19 :=
  registrationFramePc56_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt

theorem registrationFramePc57_locals_idx12_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    12 < (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size := by
  rw [registrationFramePc57_locals_size]; decide

theorem registrationFramePc57_localRefs_idx12_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    12 < (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs.size := by
  rw [registrationFramePc57_localRefs_size]; decide

set_option maxHeartbeats 3200000 in
theorem registrationFramePc57_locals_idx12_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals[12]'
      (registrationFramePc57_locals_idx12_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) =
        some eScalar := by
  have hne15 : (15 : Nat) ≠ 12 := by decide
  have hne14 : (14 : Nat) ≠ 12 := by decide
  have hne3 : (3 : Nat) ≠ 12 := by decide
  have hne13 : (13 : Nat) ≠ 12 := by decide
  have hsz44 := registrationFramePc44_locals_size args h mv rCompressed sOpt sVal
  unfold registrationFramePc57AfterImmBorrow14 registrationFramePc56AfterImmBorrow15
    registrationFramePc55AfterStLoc15 registrationFramePc53AfterImmBorrow10
    registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3
    registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12
  rw [Array.getElem_set_ne (h := hne15)
    (pj := by simp [Array.size_set, hsz44])
    (h' := by simp [Array.size_set, hsz44])]
  rw [Array.getElem_set_ne (h := hne14)
    (pj := by simp [Array.size_set, hsz44])
    (h' := by simp [Array.size_set, hsz44])]
  rw [Array.getElem_set_ne (h := hne3)
    (pj := by simp [Array.size_set, hsz44])
    (h' := by simp [Array.size_set, hsz44])]
  rw [Array.getElem_set_ne (h := hne13)
    (pj := by simp [Array.size_set, hsz44])
    (h' := by simp [Array.size_set, hsz44])]
  rw [Array.getElem_set_self]

set_option maxHeartbeats 3200000 in
theorem registrationFramePc57_localRefs_idx12_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs[12]'
      (registrationFramePc57_localRefs_idx12_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) = none := by
  have hne11 : (11 : Nat) ≠ 12 := by decide
  have hszR22 := registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal
  have hpc22 := registrationFramePc22_localRefs_idx12_eq args h mv rCompressed sOpt sVal
  unfold registrationFramePc57AfterImmBorrow14 registrationFramePc56AfterImmBorrow15
    registrationFramePc55AfterStLoc15 registrationFramePc53AfterImmBorrow10
    registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3
    registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12 registrationFramePc44AfterMoveLoc11
  rw [Array.getElem_set_ne (h := hne11)
    (pj := by rw [hszR22]; decide)
    (h' := by rw [hszR22]; decide)]
  exact hpc22

/-- Frame after `immBorrowLoc 12` (PC 57): same frame, pc := 58. -/
def registrationFramePc58AfterImmBorrow12 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) : Frame :=
  { registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with pc := 58 }

@[simp] theorem registrationFramePc57_pc_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).pc = 57 := rfl

@[simp] theorem registrationFramePc57_code_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).code =
      verifyRegistrationProofCode := rfl

set_option maxHeartbeats 3200000 in
theorem registration_step_pc57_immBorrowLoc12_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc57AfterImmBorrow14 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] rest ms =
      ExecResult.ok
        (registrationFramePc58AfterImmBorrow12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] (.immRef (ms.containers.alloc eScalar).2 :: rest)
        { ms with containers := (ms.containers.alloc eScalar).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := registrationFramePc57AfterImmBorrow14 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [hfr', registrationFramePc57_pc_eq, registrationFramePc57_code_eq,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 12 := by
    simp [hfr', registrationFramePc57_pc_eq, registrationFramePc57_code_eq, verifyRegistrationProofCode_idx57]
  have hlocLt : 12 < fr'.locals.size :=
    registrationFramePc57_locals_idx12_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocVal : fr'.locals[12]'hlocLt = some eScalar :=
    registrationFramePc57_locals_idx12_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocRefLt : 12 < fr'.localRefs.size :=
    registrationFramePc57_localRefs_idx12_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  have hlocRefVal : fr'.localRefs[12]'hlocRefLt = none :=
    registrationFramePc57_localRefs_idx12_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 58 (`call 12` = `point_mul` for ekPt * e → eke) -/

@[simp] theorem verifyRegistrationProofCode_idx58 :
    verifyRegistrationProofCode[58]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 12 := rfl

set_option maxHeartbeats 3200000 in
theorem registration_step_pc58_call_pointMul_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) (ms : MachineState)
    (ridEk ridE : RefId) (ekVal eVal ekePt : MoveValue) (restBelow : List MoveValue)
    (hreadEk : ms.containers.read ridEk = some ekVal)
    (hreadE : ms.containers.read ridE = some eVal)
    (horacle : o.pointMul [ekVal, eVal] = some [ekePt]) :
    step (registrationModuleEnv o)
        (registrationFramePc58AfterImmBorrow12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] (.immRef ridE :: .immRef ridEk :: restBelow) ms =
      ExecResult.ok
        ({ registrationFramePc58AfterImmBorrow12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with
            pc := 59 })
        [] (ekePt :: restBelow) ms := by
  have hnative : wrapOracleImmRef2 o.pointMul ms.containers
        [.immRef ridEk, .immRef ridE] =
      some ([ekePt], ms.containers) := by
    show (Option.bind (derefImm ms.containers (.immRef ridEk))
          (fun v1 => Option.bind (derefImm ms.containers (.immRef ridE))
            (fun v2 => Option.bind (o.pointMul [v1, v2])
              (fun results => some (results, ms.containers))))) =
        some ([ekePt], ms.containers)
    simp only [derefImm]
    rw [hreadEk]
    simp only [Option.bind_some]
    rw [hreadE]
    simp only [Option.bind_some]
    rw [horacle]
    rfl
  simp only [step, registrationModuleEnv, registrationFramePc58AfterImmBorrow12,
    registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
    registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx58,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx12_lt, registrationModuleEnv_functions_at12, FuncDesc.body,
    takeN_two_cons_cons, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

/-! ### PC 59 (`stLoc 16` — store eke into local 16) -/

@[simp] theorem verifyRegistrationProofCode_idx59 :
    verifyRegistrationProofCode[59]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 16 := rfl

theorem registrationFramePc58_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc58AfterImmBorrow12 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size = 19 :=
  registrationFramePc57_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt

theorem registrationFramePc58_locals_idx16_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    16 < (registrationFramePc58AfterImmBorrow12 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.size := by
  rw [registrationFramePc58_locals_size]; decide

/-- Frame after `stLoc 16` (PC 59). -/
def registrationFramePc60AfterStLoc16 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) : Frame :=
  let fr := registrationFramePc58AfterImmBorrow12 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt
  { fr with
      pc := 60
      locals := fr.locals.set 16 (some ekePt)
        (registrationFramePc58_locals_idx16_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) }

set_option maxHeartbeats 3200000 in
theorem registration_step_pc59_stLoc16_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc58AfterImmBorrow12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with
            pc := 59 })
        [] (ekePt :: rest) ms =
      ExecResult.ok
        (registrationFramePc60AfterStLoc16 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt)
        [] rest ms := by
  simp [step, registrationModuleEnv, registrationFramePc60AfterStLoc16,
    registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
    registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx59,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-! ### localRefs structural identities from Pc44 up to Pc60

Since immBorrowLoc, stLoc, and call instructions don't modify `frame.localRefs`
in this chain, the localRefs field of every intermediate frame from Pc44 onward
is definitionally equal to `Pc44AfterMoveLoc11.localRefs`. We prove these via
`rfl` to avoid deep `whnf` chains. -/

theorem registrationFramePc46_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar : MoveValue) :
    (registrationFramePc46AfterStLoc12 args h mv rCompressed sOpt sVal eScalar).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

theorem registrationFramePc48_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    (registrationFramePc48AfterStLoc13 args h mv rCompressed sOpt sVal eScalar hPoint).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

theorem registrationFramePc49_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    (registrationFramePc49AfterMoveLoc3 args h mv rCompressed sOpt sVal eScalar hPoint).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

theorem registrationFramePc51_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

theorem registrationFramePc52_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

theorem registrationFramePc53_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc53AfterImmBorrow10 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

theorem registrationFramePc55_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc55AfterStLoc15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

theorem registrationFramePc56_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc56AfterImmBorrow15 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

theorem registrationFramePc57_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc57AfterImmBorrow14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

theorem registrationFramePc58_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) :
    (registrationFramePc58AfterImmBorrow12 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

theorem registrationFramePc60_localRefs_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).localRefs =
      (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs := rfl

/-! `Pc44.localRefs = Pc22.localRefs.set 11 none` (PC 43 moveLoc 11 takes the `some`-branch of localRefs[11]). -/
theorem registrationFramePc44_localRefs_set_Pc22 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).localRefs =
      (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.set 11 none
        (registrationFramePc22_localRefs_idx11_lt args h mv rCompressed sOpt sVal) := rfl

theorem registrationFramePc22_locals_idx16_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    16 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx16_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    16 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx16_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[16]'
      (registrationFramePc22_localRefs_idx16_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

/-! ### PC 60 (`immBorrowLoc 16` — borrow ekePt) -/

@[simp] theorem verifyRegistrationProofCode_idx60 :
    verifyRegistrationProofCode[60]'(by rw [verifyRegistrationProofCode_size_val]; decide) =
      .immBorrowLoc 16 := rfl

set_option maxHeartbeats 1600000 in
/-- Direct structural equality: `Pc60.locals = Pc58.locals.set 16 (some ekePt) _`. -/
theorem registrationFramePc60_locals_eq_set (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).locals =
      (registrationFramePc58AfterImmBorrow12 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt).locals.set 16
          (some ekePt)
          (registrationFramePc58_locals_idx16_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt) := rfl

set_option maxHeartbeats 1600000 in
theorem registrationFramePc60_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).locals.size = 19 := by
  rw [registrationFramePc60_locals_eq_set, Array.size_set, registrationFramePc58_locals_size]

set_option maxHeartbeats 1600000 in
theorem registrationFramePc60_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).localRefs.size = 19 := by
  rw [registrationFramePc60_localRefs_eq, registrationFramePc44_localRefs_set_Pc22, Array.size_set,
    registrationFramePc22_localRefs_size]

set_option maxHeartbeats 800000 in
theorem registrationFramePc60_locals_idx16_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    16 < (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).locals.size := by
  rw [registrationFramePc60_locals_size]; decide

set_option maxHeartbeats 800000 in
theorem registrationFramePc60_localRefs_idx16_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    16 < (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).localRefs.size := by
  rw [registrationFramePc60_localRefs_size]; decide

set_option maxHeartbeats 12800000 in
theorem registrationFramePc60_locals_idx16_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).locals[16]'
      (registrationFramePc60_locals_idx16_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt) =
        some ekePt := by
  unfold registrationFramePc60AfterStLoc16
  rw [Array.getElem_set_self]

set_option maxHeartbeats 1600000 in
theorem registrationFramePc60_localRefs_eq_setPc22 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).localRefs =
      (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.set 11 none
        (registrationFramePc22_localRefs_idx11_lt args h mv rCompressed sOpt sVal) := rfl

theorem registrationFramePc60_localRefs_idx16_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).localRefs[16]'
      (registrationFramePc60_localRefs_idx16_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt) = none := by
  have hne : (11 : Nat) ≠ 16 := by decide
  have hpc22 := registrationFramePc22_localRefs_idx16_eq args h mv rCompressed sOpt sVal
  have heq := registrationFramePc60_localRefs_eq_setPc22 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  simp only [heq, Array.getElem_set_ne (h := hne)]
  exact hpc22

/-- Frame after `immBorrowLoc 16` (PC 60): same frame, pc := 61. -/
def registrationFramePc61AfterImmBorrow16 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) : Frame :=
  { registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt with pc := 61 }

/-- **Prototype (#1 projection-cache):** cache `.pc` and `.code` projections of `Pc60` once by `rfl`,
so downstream `step_pc60_*` proofs can rewrite through them instead of unfolding the full 20-frame
chain on each invocation (each such simp currently costs ~6.5s × 2 calls). -/
@[simp] theorem registrationFramePc60_pc_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).pc = 60 := rfl

@[simp] theorem registrationFramePc60_code_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).code =
      verifyRegistrationProofCode := rfl

set_option maxHeartbeats 12800000 in
theorem registration_step_pc60_immBorrowLoc16_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc60AfterStLoc16 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt)
        [] rest ms =
      ExecResult.ok
        (registrationFramePc61AfterImmBorrow16 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt)
        [] (.immRef (ms.containers.alloc ekePt).2 :: rest)
        { ms with containers := (ms.containers.alloc ekePt).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := registrationFramePc60AfterStLoc16 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [hfr', registrationFramePc60_pc_eq, registrationFramePc60_code_eq,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 16 := by
    simp [hfr', registrationFramePc60_pc_eq, registrationFramePc60_code_eq, verifyRegistrationProofCode_idx60]
  have hlocLt : 16 < fr'.locals.size :=
    registrationFramePc60_locals_idx16_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  have hlocVal : fr'.locals[16]'hlocLt = some ekePt :=
    registrationFramePc60_locals_idx16_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  have hlocRefLt : 16 < fr'.localRefs.size :=
    registrationFramePc60_localRefs_idx16_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  have hlocRefVal : fr'.localRefs[16]'hlocRefLt = none :=
    registrationFramePc60_localRefs_idx16_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 61 (`call 13` = `point_add` for hsPt + ekePt → lhsPt) -/

@[simp] theorem verifyRegistrationProofCode_idx61 :
    verifyRegistrationProofCode[61]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 13 := rfl

theorem registration_env_funcIdx13_lt (o : RegistrationNativeOracle) :
    13 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

theorem registrationModuleEnv_functions_at13 (o : RegistrationNativeOracle)
    (h : 13 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[13]'h =
      { numParams := 2, numReturns := 1, body := .nativeRef (wrapOracleImmRef2 o.pointAdd) } := by
  simp [registrationModuleEnv]

set_option maxHeartbeats 3200000 in
theorem registration_step_pc61_call_pointAdd_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) (ms : MachineState)
    (ridHs ridEke : RefId) (hsVal ekeVal lhsPt : MoveValue) (restBelow : List MoveValue)
    (hreadHs : ms.containers.read ridHs = some hsVal)
    (hreadEke : ms.containers.read ridEke = some ekeVal)
    (horacle : o.pointAdd [hsVal, ekeVal] = some [lhsPt]) :
    step (registrationModuleEnv o)
        (registrationFramePc61AfterImmBorrow16 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt)
        [] (.immRef ridEke :: .immRef ridHs :: restBelow) ms =
      ExecResult.ok
        ({ registrationFramePc61AfterImmBorrow16 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt with
            pc := 62 })
        [] (lhsPt :: restBelow) ms := by
  have hnative : wrapOracleImmRef2 o.pointAdd ms.containers
        [.immRef ridHs, .immRef ridEke] =
      some ([lhsPt], ms.containers) := by
    show (Option.bind (derefImm ms.containers (.immRef ridHs))
          (fun v1 => Option.bind (derefImm ms.containers (.immRef ridEke))
            (fun v2 => Option.bind (o.pointAdd [v1, v2])
              (fun results => some (results, ms.containers))))) =
        some ([lhsPt], ms.containers)
    simp only [derefImm]
    rw [hreadHs]
    simp only [Option.bind_some]
    rw [hreadEke]
    simp only [Option.bind_some]
    rw [horacle]
    rfl
  simp only [step, registrationModuleEnv, registrationFramePc61AfterImmBorrow16,
    registrationFramePc60AfterStLoc16, registrationFramePc58AfterImmBorrow12,
    registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
    registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx61,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx13_lt, registrationModuleEnv_functions_at13, FuncDesc.body,
    takeN_two_cons_cons, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

/-! ### PC 62 (`stLoc 17` — store lhsPt into local 17) -/

@[simp] theorem verifyRegistrationProofCode_idx62 :
    verifyRegistrationProofCode[62]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 17 := rfl

theorem registrationFramePc61_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc61AfterImmBorrow16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).locals.size = 19 :=
  registrationFramePc60_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt

theorem registrationFramePc61_locals_idx17_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    17 < (registrationFramePc61AfterImmBorrow16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).locals.size := by
  rw [registrationFramePc61_locals_size]; decide

/-- Frame after `stLoc 17` (PC 62): locals[17] = some lhsPt, pc := 63. -/
def registrationFramePc63AfterStLoc17 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) : Frame :=
  let fr := registrationFramePc61AfterImmBorrow16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  { fr with
      pc := 63
      locals := fr.locals.set 17 (some lhsPt)
        (registrationFramePc61_locals_idx17_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt) }

set_option maxHeartbeats 3200000 in
theorem registration_step_pc62_stLoc17_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc61AfterImmBorrow16 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt with
            pc := 62 })
        [] (lhsPt :: rest) ms =
      ExecResult.ok
        (registrationFramePc63AfterStLoc17 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt)
        [] rest ms := by
  simp [step, registrationModuleEnv, registrationFramePc63AfterStLoc17,
    registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
    registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
    registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx62,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

