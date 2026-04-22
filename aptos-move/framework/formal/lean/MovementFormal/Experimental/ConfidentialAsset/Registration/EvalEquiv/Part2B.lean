import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv.Part2A

/-!
This file is **Part2B** (PCs 44–54) of the split `EvalEquiv` proof.
See `Registration.EvalEquiv` and the sibling `Part2A` (PCs 31–43) and `Part2C` (PCs 55–62).
-/


namespace MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.MoveModel.Programs.Registration
open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
open MovementFormal.Experimental.ConfidentialAsset.Registration.Formal

set_option linter.unusedSimpArgs false

/-! ### PC 44 (`call 9` = `new_scalar_from_sha2_512`) and PC 45 (`stLoc 12`) -/

@[simp] theorem verifyRegistrationProofCode_idx44 :
    verifyRegistrationProofCode[44]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 9 := rfl

theorem registration_env_funcIdx9_lt (o : RegistrationNativeOracle) :
    9 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

theorem registrationModuleEnv_functions_at9 (o : RegistrationNativeOracle)
    (h : 9 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[9]'h = newScalarFromSha2_512Desc := by
  simp [registrationModuleEnv]

-- PC 44 (generic): `call 9` = `new_scalar_from_sha2_512` (native, 1 param, 1 return).
-- Consumes `msgVal`, produces the scalar `e = Scalar.fromSha2_512(msg)`.
set_option maxHeartbeats 800000 in
theorem registration_step_pc44_call_newScalarFromSha2_512_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState)
    (msgVal eScalar : MoveValue)
    (hnative : newScalarFromSha2_512 [msgVal] = some [eScalar]) :
    step (registrationModuleEnv o)
        ({ registrationFramePc44AfterMoveLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 44 })
        [] [msgVal] ms =
      ExecResult.ok
        ({ registrationFramePc44AfterMoveLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 45 })
        [] [eScalar] ms := by
  simp only [step, registrationModuleEnv, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx44,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx9_lt, registrationModuleEnv_functions_at9, newScalarFromSha2_512Desc, FuncDesc.body,
    takeN_one_singleton, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

@[simp] theorem verifyRegistrationProofCode_idx45 :
    verifyRegistrationProofCode[45]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 12 := rfl

theorem registrationFramePc44_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).locals.size = 19 := by
  simp [registrationFramePc44AfterMoveLoc11, Array.size_set,
    registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]

theorem registrationFramePc44_locals_idx12_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    12 < (registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc44_locals_size args h mv rCompressed sOpt sVal]; decide

/-- Frame after `stLoc 12` (PC 45): locals[12] = some eScalar, pc := 46. -/
def registrationFramePc46AfterStLoc12 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar : MoveValue) : Frame :=
  let fr := registrationFramePc44AfterMoveLoc11 args h mv rCompressed sOpt sVal
  { fr with
      pc := 46
      locals := fr.locals.set 12 (some eScalar)
        (registrationFramePc44_locals_idx12_lt args h mv rCompressed sOpt sVal) }

-- PC 45 (generic): `stLoc 12` pops `eScalar`, stores in local 12, pc 45→46.
set_option maxHeartbeats 800000 in
theorem registration_step_pc45_stLoc12_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc44AfterMoveLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 45 })
        [] [eScalar] ms =
      ExecResult.ok
        (registrationFramePc46AfterStLoc12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar)
        [] [] ms := by
  simp [step, registrationModuleEnv, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx45,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-! ### PC 46 (`call 10` = `hash_to_point_base`) and PC 47 (`stLoc 13`) -/

@[simp] theorem verifyRegistrationProofCode_idx46 :
    verifyRegistrationProofCode[46]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 10 := rfl

theorem registration_env_funcIdx10_lt (o : RegistrationNativeOracle) :
    10 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

theorem registrationModuleEnv_functions_at10 (o : RegistrationNativeOracle)
    (h : 10 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[10]'h =
      { numParams := 0, numReturns := 1, body := .native o.hashToPointBase } := by
  simp [registrationModuleEnv]

set_option maxHeartbeats 800000 in
theorem registration_step_pc46_call_hashToPointBase_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar : MoveValue) (ms : MachineState)
    (h : MoveValue)
    (horacle : o.hashToPointBase [] = some [h]) :
    step (registrationModuleEnv o)
        ({ registrationFramePc46AfterStLoc12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar with
            pc := 46 })
        [] [] ms =
      ExecResult.ok
        ({ registrationFramePc46AfterStLoc12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar with
            pc := 47 })
        [] [h] ms := by
  simp only [step, registrationModuleEnv, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx46,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx10_lt, registrationModuleEnv_functions_at10, FuncDesc.body,
    takeN_nil_zero, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [horacle]
  simp only [handleNativeResult_ret1]

@[simp] theorem verifyRegistrationProofCode_idx47 :
    verifyRegistrationProofCode[47]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 13 := rfl

theorem registrationFramePc46_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar : MoveValue) :
    (registrationFramePc46AfterStLoc12 args h mv rCompressed sOpt sVal eScalar).locals.size = 19 := by
  simp [registrationFramePc46AfterStLoc12, Array.size_set,
    registrationFramePc44_locals_size args h mv rCompressed sOpt sVal]

theorem registrationFramePc46_locals_idx13_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar : MoveValue) :
    13 < (registrationFramePc46AfterStLoc12 args h mv rCompressed sOpt sVal eScalar).locals.size := by
  rw [registrationFramePc46_locals_size args h mv rCompressed sOpt sVal eScalar]; decide

/-- Frame after `stLoc 13` (PC 47): locals[13] = some h, pc := 48. -/
def registrationFramePc48AfterStLoc13 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) : Frame :=
  let fr := registrationFramePc46AfterStLoc12 args h mv rCompressed sOpt sVal eScalar
  { fr with
      pc := 48
      locals := fr.locals.set 13 (some hPoint)
        (registrationFramePc46_locals_idx13_lt args h mv rCompressed sOpt sVal eScalar) }

set_option maxHeartbeats 800000 in
theorem registration_step_pc47_stLoc13_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc46AfterStLoc12 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar with
            pc := 47 })
        [] [hPoint] ms =
      ExecResult.ok
        (registrationFramePc48AfterStLoc13 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar hPoint)
        [] [] ms := by
  simp [step, registrationModuleEnv, registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12,
    registrationFramePc44AfterMoveLoc11, registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx47,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-! ### PC 48 (`moveLoc 3` push ek), PC 49 (`call 11` = `pubkey_to_point`), PC 50 (`stLoc 14`) -/

@[simp] theorem verifyRegistrationProofCode_idx48 :
    verifyRegistrationProofCode[48]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .moveLoc 3 := rfl

theorem registrationFramePc48_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    (registrationFramePc48AfterStLoc13 args h mv rCompressed sOpt sVal eScalar hPoint).locals.size = 19 := by
  simp [registrationFramePc48AfterStLoc13, Array.size_set,
    registrationFramePc46_locals_size args h mv rCompressed sOpt sVal eScalar]

theorem registrationFramePc48_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    (registrationFramePc48AfterStLoc13 args h mv rCompressed sOpt sVal eScalar hPoint).localRefs.size = 19 := by
  simp [registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]

theorem registrationFramePc48_locals_idx3_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    3 < (registrationFramePc48AfterStLoc13 args h mv rCompressed sOpt sVal eScalar hPoint).locals.size := by
  rw [registrationFramePc48_locals_size args h mv rCompressed sOpt sVal eScalar hPoint]; decide

theorem registrationFramePc48_localRefs_idx3_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    3 < (registrationFramePc48AfterStLoc13 args h mv rCompressed sOpt sVal eScalar hPoint).localRefs.size := by
  rw [registrationFramePc48_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint]; decide

set_option maxHeartbeats 800000 in
theorem registrationFramePc48_locals_idx3_eq
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    (registrationFramePc48AfterStLoc13 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
      (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
      mv rCompressed sOpt sVal eScalar hPoint).locals[3]'
      (registrationFramePc48_locals_idx3_lt _ _ mv rCompressed sOpt sVal eScalar hPoint) =
        some (.struct_ [.vector .u8 (ekBa.toList.map .u8)]) := by
  have hpc22 := registrationFramePc22_locals_idx3_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hne11 : (11 : Nat) ≠ 3 := by decide
  have hne12 : (12 : Nat) ≠ 3 := by decide
  have hne13 : (13 : Nat) ≠ 3 := by decide
  simp only [registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    Array.getElem_set_ne (h := hne11),
    Array.getElem_set_ne (h := hne12),
    Array.getElem_set_ne (h := hne13)]
  exact hpc22

set_option maxHeartbeats 800000 in
theorem registrationFramePc48_localRefs_idx3_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    (registrationFramePc48AfterStLoc13 args h mv rCompressed sOpt sVal eScalar hPoint).localRefs[3]'
      (registrationFramePc48_localRefs_idx3_lt args h mv rCompressed sOpt sVal eScalar hPoint) = none := by
  have hpc22 := registrationFramePc22_localRefs_idx3_eq args h mv rCompressed sOpt sVal
  have hne11 : (11 : Nat) ≠ 3 := by decide
  simp only [registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    Array.getElem_set_ne (h := hne11)]
  exact hpc22

/-- Frame after `moveLoc 3` (PC 48): locals[3] := none, pc := 49. LocalRefs[3] stays none. -/
def registrationFramePc49AfterMoveLoc3 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) : Frame :=
  let fr := registrationFramePc48AfterStLoc13 args h mv rCompressed sOpt sVal eScalar hPoint
  { fr with
      pc := 49
      locals := fr.locals.set 3 none
        (registrationFramePc48_locals_idx3_lt args h mv rCompressed sOpt sVal eScalar hPoint) }

set_option maxHeartbeats 800000 in
theorem registration_step_pc48_moveLoc3_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc48AfterStLoc13 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar hPoint with
            pc := 48 })
        [] [] ms =
      ExecResult.ok
        (registrationFramePc49AfterMoveLoc3 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint)
        [] [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc48AfterStLoc13 args hlen mv rCompressed sOpt sVal eScalar hPoint with pc := 48 }) with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.moveLoc 3 := by
    simp [fr', registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx48]
  have hlocLt : 3 < fr'.locals.size :=
    registrationFramePc48_locals_idx3_lt args hlen mv rCompressed sOpt sVal eScalar hPoint
  have hlocVal : fr'.locals[3]'hlocLt = some (.struct_ [.vector .u8 (ekBa.toList.map .u8)]) :=
    registrationFramePc48_locals_idx3_eq chainId sender contract token ekBa commitBa respBa
      mv rCompressed sOpt sVal eScalar hPoint
  have hlocRefLt : 3 < fr'.localRefs.size :=
    registrationFramePc48_localRefs_idx3_lt args hlen mv rCompressed sOpt sVal eScalar hPoint
  have hlocRefVal : fr'.localRefs[3]'hlocRefLt = none :=
    registrationFramePc48_localRefs_idx3_eq args hlen mv rCompressed sOpt sVal eScalar hPoint
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

@[simp] theorem verifyRegistrationProofCode_idx49 :
    verifyRegistrationProofCode[49]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 11 := rfl

theorem registration_env_funcIdx11_lt (o : RegistrationNativeOracle) :
    11 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

theorem registrationModuleEnv_functions_at11 (o : RegistrationNativeOracle)
    (h : 11 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[11]'h =
      { numParams := 1, numReturns := 1, body := .nativeRef (wrapOracleImmRef1 o.pubkeyToPoint) } := by
  simp [registrationModuleEnv]

set_option maxHeartbeats 800000 in
theorem registration_step_pc49_call_pubkeyToPoint_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) (ms : MachineState)
    (ekPt : MoveValue)
    (horacle : o.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] = some [ekPt]) :
    step (registrationModuleEnv o)
        ({ registrationFramePc49AfterMoveLoc3 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar hPoint with
            pc := 49 })
        [] [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] ms =
      ExecResult.ok
        ({ registrationFramePc49AfterMoveLoc3 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar hPoint with
            pc := 50 })
        [] [ekPt] ms := by
  have hnative : wrapOracleImmRef1 o.pubkeyToPoint ms.containers
        [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some ([ekPt], ms.containers) := by
    show (Option.bind (derefImm ms.containers
            (.struct_ [.vector .u8 (ekBa.toList.map .u8)]))
          (fun v => Option.bind (o.pubkeyToPoint [v])
              (fun results => some (results, ms.containers)))) =
        some ([ekPt], ms.containers)
    simp only [derefImm, Option.bind_some]
    rw [horacle]
    rfl
  simp only [step, registrationModuleEnv, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx49,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx11_lt, registrationModuleEnv_functions_at11, FuncDesc.body,
    takeN_one_singleton, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

@[simp] theorem verifyRegistrationProofCode_idx50 :
    verifyRegistrationProofCode[50]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 14 := rfl

theorem registrationFramePc49_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    (registrationFramePc49AfterMoveLoc3 args h mv rCompressed sOpt sVal eScalar hPoint).locals.size = 19 := by
  simp [registrationFramePc49AfterMoveLoc3, Array.size_set,
    registrationFramePc48_locals_size args h mv rCompressed sOpt sVal eScalar hPoint]

theorem registrationFramePc49_locals_idx14_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue) :
    14 < (registrationFramePc49AfterMoveLoc3 args h mv rCompressed sOpt sVal eScalar hPoint).locals.size := by
  rw [registrationFramePc49_locals_size args h mv rCompressed sOpt sVal eScalar hPoint]; decide

/-- Frame after `stLoc 14` (PC 50): locals[14] = some ekPt, pc := 51. -/
def registrationFramePc51AfterStLoc14 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) : Frame :=
  let fr := registrationFramePc49AfterMoveLoc3 args h mv rCompressed sOpt sVal eScalar hPoint
  { fr with
      pc := 51
      locals := fr.locals.set 14 (some ekPt)
        (registrationFramePc49_locals_idx14_lt args h mv rCompressed sOpt sVal eScalar hPoint) }

set_option maxHeartbeats 800000 in
theorem registration_step_pc50_stLoc14_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc49AfterMoveLoc3 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint with
            pc := 50 })
        [] [ekPt] ms =
      ExecResult.ok
        (registrationFramePc51AfterStLoc14 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt)
        [] [] ms := by
  simp [step, registrationModuleEnv, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx50,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-! ### PC 51 (`immBorrowLoc 13` — alloc h at new ref, push immRef) -/

@[simp] theorem verifyRegistrationProofCode_idx51 :
    verifyRegistrationProofCode[51]'(by rw [verifyRegistrationProofCode_size_val]; decide) =
      .immBorrowLoc 13 := rfl

theorem registrationFramePc51_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals.size = 19 := by
  simp [registrationFramePc51AfterStLoc14, Array.size_set,
    registrationFramePc49AfterMoveLoc3, registrationFramePc48_locals_size args h mv rCompressed sOpt sVal eScalar hPoint]

theorem registrationFramePc51_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs.size = 19 := by
  simp [registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint]

theorem registrationFramePc51_locals_idx13_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    13 < (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals.size := by
  rw [registrationFramePc51_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt]; decide

theorem registrationFramePc51_localRefs_idx13_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    13 < (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs.size := by
  rw [registrationFramePc51_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt]; decide

theorem registrationFramePc22_localRefs_idx13_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    13 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx13_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[13]'
      (registrationFramePc22_localRefs_idx13_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

set_option maxHeartbeats 1600000 in
theorem registrationFramePc51_locals_idx13_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals[13]'
      (registrationFramePc51_locals_idx13_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt) =
        some hPoint := by
  have hne14 : (14 : Nat) ≠ 13 := by decide
  have hne3 : (3 : Nat) ≠ 13 := by decide
  have hsz46 := registrationFramePc46_locals_size args h mv rCompressed sOpt sVal eScalar
  unfold registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3 registrationFramePc48AfterStLoc13
  rw [Array.getElem_set_ne (h := hne14)
    (pj := by simp [Array.size_set, hsz46])
    (h' := by simp [Array.size_set, hsz46])]
  rw [Array.getElem_set_ne (h := hne3)
    (pj := by simp [Array.size_set, hsz46])
    (h' := by simp [Array.size_set, hsz46])]
  rw [Array.getElem_set_self]

set_option maxHeartbeats 3200000 in
theorem registrationFramePc51_localRefs_idx13_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs[13]'
      (registrationFramePc51_localRefs_idx13_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt) = none := by
  have hne11 : (11 : Nat) ≠ 13 := by decide
  have hpc22 := registrationFramePc22_localRefs_idx13_eq args h mv rCompressed sOpt sVal
  have hsz22 := registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal
  unfold registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3
    registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12 registrationFramePc44AfterMoveLoc11
  rw [Array.getElem_set_ne (h := hne11)
    (pj := by rw [hsz22]; decide)
    (h' := by rw [hsz22]; decide)]
  exact hpc22

/-- Frame after `immBorrowLoc 13` (PC 51): pc := 52, localRefs unchanged (none case allocates
fresh ref but doesn't record it). -/
def registrationFramePc52AfterImmBorrow13 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) : Frame :=
  { registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt with pc := 52 }

@[simp] theorem registrationFramePc51_code_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc51AfterStLoc14 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).code =
      verifyRegistrationProofCode := rfl

@[simp] theorem registrationFramePc52_code_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).code =
      verifyRegistrationProofCode := rfl

@[simp] theorem registrationFramePc52_pc_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).pc = 52 := rfl

set_option maxHeartbeats 3200000 in
theorem registration_step_pc51_immBorrowLoc13_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc51AfterStLoc14 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt with
            pc := 51 })
        [] rest ms =
      ExecResult.ok
        (registrationFramePc52AfterImmBorrow13 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt)
        [] (.immRef (ms.containers.alloc hPoint).2 :: rest)
        { ms with containers := (ms.containers.alloc hPoint).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc51AfterStLoc14 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt with
                pc := 51 }) with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [hfr', registrationFramePc51_code_eq, verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 13 := by
    simp [hfr', registrationFramePc51_code_eq, verifyRegistrationProofCode_idx51]
  have hlocLt : 13 < fr'.locals.size :=
    registrationFramePc51_locals_idx13_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  have hlocVal : fr'.locals[13]'hlocLt = some hPoint :=
    registrationFramePc51_locals_idx13_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  have hlocRefLt : 13 < fr'.localRefs.size :=
    registrationFramePc51_localRefs_idx13_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  have hlocRefVal : fr'.localRefs[13]'hlocRefLt = none :=
    registrationFramePc51_localRefs_idx13_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 52 (`immBorrowLoc 10` — alloc s at new ref, push immRef over existing immRef) -/

@[simp] theorem verifyRegistrationProofCode_idx52 :
    verifyRegistrationProofCode[52]'(by rw [verifyRegistrationProofCode_size_val]; decide) =
      .immBorrowLoc 10 := rfl

-- Pc22.locals[10] = some sVal (stLoc 10 at PC 17 sets it; no subsequent change).
theorem registrationFramePc22_locals_idx10_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    10 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx10_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    10 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_locals_idx10_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals[10]'
      (registrationFramePc22_locals_idx10_lt args h mv rCompressed sOpt sVal) = some sVal := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

theorem registrationFramePc22_localRefs_idx10_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[10]'
      (registrationFramePc22_localRefs_idx10_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

-- Pc52AfterImmBorrow13 frame has same locals/localRefs as Pc51AfterStLoc14 (just pc := 52).
-- So we build idx10 eq/lt helpers for Pc52.

theorem registrationFramePc52_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals.size = 19 :=
  registrationFramePc51_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt

theorem registrationFramePc52_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs.size = 19 :=
  registrationFramePc51_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt

theorem registrationFramePc52_locals_idx10_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    10 < (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals.size := by
  rw [registrationFramePc52_locals_size]; decide

theorem registrationFramePc52_localRefs_idx10_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    10 < (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs.size := by
  rw [registrationFramePc52_localRefs_size]; decide

set_option maxHeartbeats 3200000 in
theorem registrationFramePc52_locals_idx10_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals[10]'
      (registrationFramePc52_locals_idx10_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt) =
        some sVal := by
  have hne14 : (14 : Nat) ≠ 10 := by decide
  have hne3 : (3 : Nat) ≠ 10 := by decide
  have hne13 : (13 : Nat) ≠ 10 := by decide
  have hne12 : (12 : Nat) ≠ 10 := by decide
  have hne11 : (11 : Nat) ≠ 10 := by decide
  have hsz22 := registrationFramePc22_locals_size args h mv rCompressed sOpt sVal
  have hpc22 := registrationFramePc22_locals_idx10_eq args h mv rCompressed sOpt sVal
  unfold registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3
    registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12 registrationFramePc44AfterMoveLoc11
  rw [Array.getElem_set_ne (h := hne14)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne3)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne13)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne12)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne11)
    (pj := by rw [hsz22]; decide)
    (h' := by rw [hsz22]; decide)]
  exact hpc22

set_option maxHeartbeats 3200000 in
theorem registrationFramePc52_localRefs_idx10_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).localRefs[10]'
      (registrationFramePc52_localRefs_idx10_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt) = none := by
  have hne11 : (11 : Nat) ≠ 10 := by decide
  have hpc22 := registrationFramePc22_localRefs_idx10_eq args h mv rCompressed sOpt sVal
  have hszR22 := registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal
  unfold registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3
    registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12 registrationFramePc44AfterMoveLoc11
  rw [Array.getElem_set_ne (h := hne11)
    (pj := by rw [hszR22]; decide)
    (h' := by rw [hszR22]; decide)]
  exact hpc22

/-- Frame after `immBorrowLoc 10` (PC 52): pc := 53, same locals/localRefs. -/
def registrationFramePc53AfterImmBorrow10 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) : Frame :=
  { registrationFramePc52AfterImmBorrow13 args h mv rCompressed sOpt sVal eScalar hPoint ekPt with pc := 53 }

set_option maxHeartbeats 3200000 in
theorem registration_step_pc52_immBorrowLoc10_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc52AfterImmBorrow13 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt with
            pc := 52 })
        [] rest ms =
      ExecResult.ok
        (registrationFramePc53AfterImmBorrow10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt)
        [] (.immRef (ms.containers.alloc sVal).2 :: rest)
        { ms with containers := (ms.containers.alloc sVal).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc52AfterImmBorrow13 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt with
                pc := 52 }) with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [hfr', registrationFramePc52_code_eq, verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 10 := by
    simp [hfr', registrationFramePc52_code_eq, verifyRegistrationProofCode_idx52]
  have hlocLt : 10 < fr'.locals.size :=
    registrationFramePc52_locals_idx10_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  have hlocVal : fr'.locals[10]'hlocLt = some sVal :=
    registrationFramePc52_locals_idx10_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  have hlocRefLt : 10 < fr'.localRefs.size :=
    registrationFramePc52_localRefs_idx10_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  have hlocRefVal : fr'.localRefs[10]'hlocRefLt = none :=
    registrationFramePc52_localRefs_idx10_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 53 (`call 12` = `point_mul` via `wrapOracleImmRef2`) -/

@[simp] theorem verifyRegistrationProofCode_idx53 :
    verifyRegistrationProofCode[53]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 12 := rfl

theorem registration_env_funcIdx12_lt (o : RegistrationNativeOracle) :
    12 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

theorem registrationModuleEnv_functions_at12 (o : RegistrationNativeOracle)
    (h : 12 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[12]'h =
      { numParams := 2, numReturns := 1, body := .nativeRef (wrapOracleImmRef2 o.pointMul) } := by
  simp [registrationModuleEnv]

set_option maxHeartbeats 3200000 in
theorem registration_step_pc53_call_pointMul_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) (ms : MachineState)
    (ridH ridS : RefId) (hVal sValForMul hsPt : MoveValue)
    (hreadH : ms.containers.read ridH = some hVal)
    (hreadS : ms.containers.read ridS = some sValForMul)
    (horacle : o.pointMul [hVal, sValForMul] = some [hsPt]) :
    step (registrationModuleEnv o)
        (registrationFramePc53AfterImmBorrow10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt)
        [] [.immRef ridS, .immRef ridH] ms =
      ExecResult.ok
        ({ registrationFramePc53AfterImmBorrow10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt with
            pc := 54 })
        [] [hsPt] ms := by
  have hnative : wrapOracleImmRef2 o.pointMul ms.containers
        [.immRef ridH, .immRef ridS] =
      some ([hsPt], ms.containers) := by
    show (Option.bind (derefImm ms.containers (.immRef ridH))
          (fun v1 => Option.bind (derefImm ms.containers (.immRef ridS))
            (fun v2 => Option.bind (o.pointMul [v1, v2])
              (fun results => some (results, ms.containers))))) =
        some ([hsPt], ms.containers)
    simp only [derefImm]
    rw [hreadH]
    simp only [Option.bind_some]
    rw [hreadS]
    simp only [Option.bind_some]
    rw [horacle]
    rfl
  simp only [step, registrationModuleEnv, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx53,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx12_lt, registrationModuleEnv_functions_at12, FuncDesc.body,
    takeN_two_pair, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

/-! ### PC 54 (`stLoc 15` — store hs into local 15) -/

@[simp] theorem verifyRegistrationProofCode_idx54 :
    verifyRegistrationProofCode[54]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 15 := rfl

theorem registrationFramePc53_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    (registrationFramePc53AfterImmBorrow10 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals.size = 19 :=
  registrationFramePc51_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt

theorem registrationFramePc53_locals_idx15_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue) :
    15 < (registrationFramePc53AfterImmBorrow10 args h mv rCompressed sOpt sVal eScalar hPoint ekPt).locals.size := by
  rw [registrationFramePc53_locals_size]; decide

/-- Frame after `stLoc 15` (PC 54): locals[15] = some hs, pc := 55. -/
def registrationFramePc55AfterStLoc15 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) : Frame :=
  let fr := registrationFramePc53AfterImmBorrow10 args h mv rCompressed sOpt sVal eScalar hPoint ekPt
  { fr with
      pc := 55
      locals := fr.locals.set 15 (some hsPt)
        (registrationFramePc53_locals_idx15_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt) }

set_option maxHeartbeats 3200000 in
theorem registration_step_pc54_stLoc15_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc53AfterImmBorrow10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt with
            pc := 54 })
        [] (hsPt :: rest) ms =
      ExecResult.ok
        (registrationFramePc55AfterStLoc15 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] rest ms := by
  simp [step, registrationModuleEnv, registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
    registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
    registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx54,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-! ### PC 22 base helpers for indices 12, 14, 15, 16, 17, 18 (all `none` at Pc22) -/

theorem registrationFramePc22_locals_idx12_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    12 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx12_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    12 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx12_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[12]'
      (registrationFramePc22_localRefs_idx12_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

theorem registrationFramePc22_locals_idx14_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    14 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx14_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    14 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx14_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[14]'
      (registrationFramePc22_localRefs_idx14_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

theorem registrationFramePc22_localRefs_idx15_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    15 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx15_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[15]'
      (registrationFramePc22_localRefs_idx15_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

