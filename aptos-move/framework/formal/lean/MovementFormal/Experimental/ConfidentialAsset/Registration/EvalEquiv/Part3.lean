import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv.Part2

/-!
This file is **Part3** of the split `EvalEquiv` proof (see `Registration.EvalEquiv`).
-/


namespace MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.MoveModel.Programs.Registration
open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
open MovementFormal.Experimental.ConfidentialAsset.Registration.Formal

set_option linter.unusedSimpArgs false

/-! ### Projection caches (build-time optimization)

Caching `.pc` and `.code` projections of the late-PC frames as `rfl`-proven `@[simp]` lemmas lets
downstream `hpc`/`hc` proofs rewrite through them instead of unfolding the full 20+-frame chain
on every call site (each such unfold was costing ~6s × 2 per theorem pre-optimization). -/

@[simp] theorem registrationFramePc63_code_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).code =
      verifyRegistrationProofCode := rfl

@[simp] theorem registrationFramePc63_pc_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).pc = 63 := rfl

/-! ### PC 63 (`immBorrowLoc 8` — push `&rCompressed`) -/

@[simp] theorem verifyRegistrationProofCode_idx63 :
    verifyRegistrationProofCode[63]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 8 := rfl

/-! `Pc60.locals[8] = some rCompressed`: unchanged since `Pc8.stLoc 8`. The chain from `Pc60`
back to `Pc22` involves sets at indices 16, 15, 14, 3, 13, 12, 11 — all ≠ 8. -/
set_option maxHeartbeats 12800000 in
theorem registrationFramePc60_locals_idx8_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).locals[8]'
      (by rw [registrationFramePc60_locals_size]; decide) = some rCompressed := by
  have hne16 : (16 : Nat) ≠ 8 := by decide
  have hne15 : (15 : Nat) ≠ 8 := by decide
  have hne14 : (14 : Nat) ≠ 8 := by decide
  have hne3 : (3 : Nat) ≠ 8 := by decide
  have hne13 : (13 : Nat) ≠ 8 := by decide
  have hne12 : (12 : Nat) ≠ 8 := by decide
  have hne11 : (11 : Nat) ≠ 8 := by decide
  have hsz22 := registrationFramePc22_locals_size args h mv rCompressed sOpt sVal
  have hpc22 := registrationFramePc22_locals_idx8_eq args h mv rCompressed sOpt sVal
  unfold registrationFramePc60AfterStLoc16 registrationFramePc58AfterImmBorrow12
    registrationFramePc57AfterImmBorrow14 registrationFramePc56AfterImmBorrow15
    registrationFramePc55AfterStLoc15 registrationFramePc53AfterImmBorrow10
    registrationFramePc52AfterImmBorrow13 registrationFramePc51AfterStLoc14 registrationFramePc49AfterMoveLoc3
    registrationFramePc48AfterStLoc13 registrationFramePc46AfterStLoc12 registrationFramePc44AfterMoveLoc11
  rw [Array.getElem_set_ne (h := hne16)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
  rw [Array.getElem_set_ne (h := hne15)
    (pj := by simp [Array.size_set, hsz22])
    (h' := by simp [Array.size_set, hsz22])]
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

theorem registrationFramePc60_localRefs_idx8_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt : MoveValue) :
    (registrationFramePc60AfterStLoc16 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt).localRefs[8]'
      (by rw [registrationFramePc60_localRefs_size]; decide) = none := by
  have hne : (11 : Nat) ≠ 8 := by decide
  have hpc22 := registrationFramePc22_localRefs_idx8_eq args h mv rCompressed sOpt sVal
  have heq := registrationFramePc60_localRefs_eq_setPc22 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  simp only [heq, Array.getElem_set_ne (h := hne)]
  exact hpc22

theorem registrationFramePc63AfterStLoc17_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).locals.size = 19 := by
  unfold registrationFramePc63AfterStLoc17
  rw [Array.size_set, registrationFramePc61_locals_size]

theorem registrationFramePc63AfterStLoc17_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).localRefs.size = 19 :=
  registrationFramePc60_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt

theorem registrationFramePc63AfterStLoc17_locals_idx8_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    8 < (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).locals.size := by
  rw [registrationFramePc63AfterStLoc17_locals_size]; decide

theorem registrationFramePc63AfterStLoc17_localRefs_idx8_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    8 < (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).localRefs.size := by
  rw [registrationFramePc63AfterStLoc17_localRefs_size]; decide

set_option maxHeartbeats 12800000 in
theorem registrationFramePc63AfterStLoc17_locals_idx8_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).locals[8]'
      (registrationFramePc63AfterStLoc17_locals_idx8_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt) =
        some rCompressed := by
  have hne : (17 : Nat) ≠ 8 := by decide
  have hsz61 := registrationFramePc61_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  have hpc60 := registrationFramePc60_locals_idx8_eq args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  unfold registrationFramePc63AfterStLoc17
  rw [Array.getElem_set_ne (h := hne)
    (pj := by rw [hsz61]; decide)
    (h' := by rw [hsz61]; decide)]
  exact hpc60

theorem registrationFramePc63AfterStLoc17_localRefs_idx8_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).localRefs[8]'
      (registrationFramePc63AfterStLoc17_localRefs_idx8_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt) =
        none := by
  have hpc60 := registrationFramePc60_localRefs_idx8_eq args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt
  unfold registrationFramePc63AfterStLoc17
  exact hpc60

/-- Frame after `immBorrowLoc 8` (PC 63): same frame, pc := 64. -/
def registrationFramePc64AfterImmBorrow8 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) : Frame :=
  { registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt with pc := 64 }

set_option maxHeartbeats 12800000 in
theorem registration_step_pc63_immBorrowLoc8_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc63AfterStLoc17 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt)
        [] rest ms =
      ExecResult.ok
        (registrationFramePc64AfterImmBorrow8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt)
        [] (.immRef (ms.containers.alloc rCompressed).2 :: rest)
        { ms with containers := (ms.containers.alloc rCompressed).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := registrationFramePc63AfterStLoc17 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [hfr', registrationFramePc63_pc_eq, registrationFramePc63_code_eq,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 8 := by
    simp [hfr', registrationFramePc63_pc_eq, registrationFramePc63_code_eq, verifyRegistrationProofCode_idx63]
  have hlocLt : 8 < fr'.locals.size :=
    registrationFramePc63AfterStLoc17_locals_idx8_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
  have hlocVal : fr'.locals[8]'hlocLt = some rCompressed :=
    registrationFramePc63AfterStLoc17_locals_idx8_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
  have hlocRefLt : 8 < fr'.localRefs.size :=
    registrationFramePc63AfterStLoc17_localRefs_idx8_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
  have hlocRefVal : fr'.localRefs[8]'hlocRefLt = none :=
    registrationFramePc63AfterStLoc17_localRefs_idx8_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 64 (`call 14` = `point_decompress` on `&rCompressed`) -/

@[simp] theorem verifyRegistrationProofCode_idx64 :
    verifyRegistrationProofCode[64]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 14 := rfl

theorem registration_env_funcIdx14_lt (o : RegistrationNativeOracle) :
    14 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

theorem registrationModuleEnv_functions_at14 (o : RegistrationNativeOracle)
    (h : 14 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[14]'h =
      { numParams := 1, numReturns := 1, body := .nativeRef (wrapOracleImmRef1 o.pointDecompress) } := by
  simp [registrationModuleEnv]

set_option maxHeartbeats 3200000 in
theorem registration_step_pc64_call_pointDecompress_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) (ms : MachineState)
    (ridR : RefId) (rVal rhsPt : MoveValue) (restBelow : List MoveValue)
    (hreadR : ms.containers.read ridR = some rVal)
    (horacle : o.pointDecompress [rVal] = some [rhsPt]) :
    step (registrationModuleEnv o)
        (registrationFramePc64AfterImmBorrow8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt)
        [] (.immRef ridR :: restBelow) ms =
      ExecResult.ok
        ({ registrationFramePc64AfterImmBorrow8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt with
            pc := 65 })
        [] (rhsPt :: restBelow) ms := by
  have hnative : wrapOracleImmRef1 o.pointDecompress ms.containers
        [.immRef ridR] =
      some ([rhsPt], ms.containers) := by
    show (Option.bind (derefImm ms.containers (.immRef ridR))
          (fun v => Option.bind (o.pointDecompress [v])
              (fun results => some (results, ms.containers)))) =
        some ([rhsPt], ms.containers)
    simp only [derefImm]
    rw [hreadR]
    simp only [Option.bind_some]
    rw [horacle]
    rfl
  simp only [step, registrationModuleEnv, registrationFramePc64AfterImmBorrow8,
    registrationFramePc63AfterStLoc17, registrationFramePc61AfterImmBorrow16,
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
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx64,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx14_lt, registrationModuleEnv_functions_at14, FuncDesc.body,
    takeN_one_cons, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

/-! ### PC 65 (`stLoc 18` — store rhsPt into local 18) -/

@[simp] theorem verifyRegistrationProofCode_idx65 :
    verifyRegistrationProofCode[65]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .stLoc 18 := rfl

theorem registrationFramePc64_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc64AfterImmBorrow8 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).locals.size = 19 :=
  registrationFramePc63AfterStLoc17_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt

theorem registrationFramePc64_locals_idx18_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    18 < (registrationFramePc64AfterImmBorrow8 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).locals.size := by
  rw [registrationFramePc64_locals_size]; decide

/-- Frame after `stLoc 18` (PC 65): locals[18] = some rhsPt, pc := 66. -/
def registrationFramePc66AfterStLoc18 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) : Frame :=
  let fr := registrationFramePc64AfterImmBorrow8 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
  { fr with
      pc := 66
      locals := fr.locals.set 18 (some rhsPt)
        (registrationFramePc64_locals_idx18_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt) }

set_option maxHeartbeats 3200000 in
theorem registration_step_pc65_stLoc18_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc64AfterImmBorrow8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt with
            pc := 65 })
        [] (rhsPt :: rest) ms =
      ExecResult.ok
        (registrationFramePc66AfterStLoc18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] rest ms := by
  simp [step, registrationModuleEnv, registrationFramePc66AfterStLoc18,
    registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
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
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx65,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-! ### PC 66 (`immBorrowLoc 17` — borrow lhsPt) -/

@[simp] theorem verifyRegistrationProofCode_idx66 :
    verifyRegistrationProofCode[66]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 17 := rfl

theorem registrationFramePc66AfterStLoc18_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).locals.size = 19 := by
  unfold registrationFramePc66AfterStLoc18
  rw [Array.size_set, registrationFramePc64_locals_size]

theorem registrationFramePc66AfterStLoc18_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs.size = 19 :=
  registrationFramePc60_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt

theorem registrationFramePc66AfterStLoc18_locals_idx17_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    17 < (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).locals.size := by
  rw [registrationFramePc66AfterStLoc18_locals_size]; decide

theorem registrationFramePc66AfterStLoc18_localRefs_idx17_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    17 < (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs.size := by
  rw [registrationFramePc66AfterStLoc18_localRefs_size]; decide

theorem registrationFramePc22_localRefs_idx17_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    17 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx17_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[17]'
      (registrationFramePc22_localRefs_idx17_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

/-! Direct: `Pc63.locals[17] = some lhsPt` because `Pc63 = stLoc 17`. -/
set_option maxHeartbeats 3200000 in
theorem registrationFramePc63_locals_idx17_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc63AfterStLoc17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).locals[17]'
      (by rw [registrationFramePc63AfterStLoc17_locals_size]; decide) = some lhsPt := by
  unfold registrationFramePc63AfterStLoc17
  rw [Array.getElem_set_self]

/-! `Pc64.locals = Pc63.locals` since Pc64 only changes `pc`. -/
set_option maxHeartbeats 3200000 in
theorem registrationFramePc64_locals_idx17_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue) :
    (registrationFramePc64AfterImmBorrow8 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt).locals[17]'
      (by rw [registrationFramePc64_locals_size]; decide) = some lhsPt :=
  registrationFramePc63_locals_idx17_eq args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt

set_option maxHeartbeats 25600000 in
theorem registrationFramePc66AfterStLoc18_locals_idx17_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).locals[17]'
      (registrationFramePc66AfterStLoc18_locals_idx17_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt) =
        some lhsPt := by
  have hne : (18 : Nat) ≠ 17 := by decide
  have hsz64 := registrationFramePc64_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
  have hpc64 := registrationFramePc64_locals_idx17_eq args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt
  unfold registrationFramePc66AfterStLoc18
  rw [Array.getElem_set_ne (h := hne)
    (pj := by rw [hsz64]; decide)
    (h' := by rw [hsz64]; decide)]
  exact hpc64

set_option maxHeartbeats 3200000 in
theorem registrationFramePc66AfterStLoc18_localRefs_idx17_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs[17]'
      (registrationFramePc66AfterStLoc18_localRefs_idx17_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt) =
        none := by
  have hne : (11 : Nat) ≠ 17 := by decide
  have hpc22 := registrationFramePc22_localRefs_idx17_eq args h mv rCompressed sOpt sVal
  have heq : (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs =
      (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.set 11 none
        (registrationFramePc22_localRefs_idx11_lt args h mv rCompressed sOpt sVal) := rfl
  simp only [heq, Array.getElem_set_ne (h := hne)]
  exact hpc22

@[simp] theorem registrationFramePc66_code_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).code =
      verifyRegistrationProofCode := rfl

@[simp] theorem registrationFramePc66_pc_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).pc = 66 := rfl

/-- Frame after `immBorrowLoc 17` (PC 66): same frame, pc := 67. -/
def registrationFramePc67AfterImmBorrow17 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) : Frame :=
  { registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with pc := 67 }

@[simp] theorem registrationFramePc67_code_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).code =
      verifyRegistrationProofCode := rfl

@[simp] theorem registrationFramePc67_pc_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).pc = 67 := rfl

set_option maxHeartbeats 25600000 in
theorem registration_step_pc66_immBorrowLoc17_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc66AfterStLoc18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] rest ms =
      ExecResult.ok
        (registrationFramePc67AfterImmBorrow17 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] (.immRef (ms.containers.alloc lhsPt).2 :: rest)
        { ms with containers := (ms.containers.alloc lhsPt).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := registrationFramePc66AfterStLoc18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [hfr', registrationFramePc66_pc_eq, registrationFramePc66_code_eq,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 17 := by
    simp [hfr', registrationFramePc66_pc_eq, registrationFramePc66_code_eq, verifyRegistrationProofCode_idx66]
  have hlocLt : 17 < fr'.locals.size :=
    registrationFramePc66AfterStLoc18_locals_idx17_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  have hlocVal : fr'.locals[17]'hlocLt = some lhsPt :=
    registrationFramePc66AfterStLoc18_locals_idx17_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  have hlocRefLt : 17 < fr'.localRefs.size :=
    registrationFramePc66AfterStLoc18_localRefs_idx17_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  have hlocRefVal : fr'.localRefs[17]'hlocRefLt = none :=
    registrationFramePc66AfterStLoc18_localRefs_idx17_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 67 (`immBorrowLoc 18` — borrow rhsPt) -/

@[simp] theorem verifyRegistrationProofCode_idx67 :
    verifyRegistrationProofCode[67]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 18 := rfl

theorem registrationFramePc67_locals_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).locals.size = 19 :=
  registrationFramePc66AfterStLoc18_locals_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt

theorem registrationFramePc67_localRefs_size (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs.size = 19 :=
  registrationFramePc66AfterStLoc18_localRefs_size args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt

theorem registrationFramePc67_locals_idx18_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    18 < (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).locals.size := by
  rw [registrationFramePc67_locals_size]; decide

theorem registrationFramePc67_localRefs_idx18_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    18 < (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs.size := by
  rw [registrationFramePc67_localRefs_size]; decide

/-- Direct: `Pc66.locals[18] = some rhsPt` because `Pc66 = stLoc 18`. -/
theorem registrationFramePc66_locals_idx18_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc66AfterStLoc18 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).locals[18]'
      (by rw [registrationFramePc66AfterStLoc18_locals_size]; decide) = some rhsPt := by
  unfold registrationFramePc66AfterStLoc18
  rw [Array.getElem_set_self]

set_option maxHeartbeats 25600000 in
theorem registrationFramePc67_locals_idx18_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).locals[18]'
      (registrationFramePc67_locals_idx18_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt) =
        some rhsPt :=
  registrationFramePc66_locals_idx18_eq args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt

theorem registrationFramePc22_localRefs_idx18_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    18 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx18_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[18]'
      (registrationFramePc22_localRefs_idx18_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

set_option maxHeartbeats 3200000 in
theorem registrationFramePc67_localRefs_idx18_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) :
    (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs[18]'
      (registrationFramePc67_localRefs_idx18_lt args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt) =
        none := by
  have hne : (11 : Nat) ≠ 18 := by decide
  have hpc22 := registrationFramePc22_localRefs_idx18_eq args h mv rCompressed sOpt sVal
  have heq : (registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt).localRefs =
      (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.set 11 none
        (registrationFramePc22_localRefs_idx11_lt args h mv rCompressed sOpt sVal) := rfl
  simp only [heq, Array.getElem_set_ne (h := hne)]
  exact hpc22

/-- Frame after `immBorrowLoc 18` (PC 67): same frame, pc := 68. -/
def registrationFramePc68AfterImmBorrow18 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) : Frame :=
  { registrationFramePc67AfterImmBorrow17 args h mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with pc := 68 }

set_option maxHeartbeats 25600000 in
theorem registration_step_pc67_immBorrowLoc18_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        (registrationFramePc67AfterImmBorrow17 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] rest ms =
      ExecResult.ok
        (registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] (.immRef (ms.containers.alloc rhsPt).2 :: rest)
        { ms with containers := (ms.containers.alloc rhsPt).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := registrationFramePc67AfterImmBorrow17 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [hfr', registrationFramePc67_pc_eq, registrationFramePc67_code_eq,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 18 := by
    simp [hfr', registrationFramePc67_pc_eq, registrationFramePc67_code_eq, verifyRegistrationProofCode_idx67]
  have hlocLt : 18 < fr'.locals.size :=
    registrationFramePc67_locals_idx18_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  have hlocVal : fr'.locals[18]'hlocLt = some rhsPt :=
    registrationFramePc67_locals_idx18_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  have hlocRefLt : 18 < fr'.localRefs.size :=
    registrationFramePc67_localRefs_idx18_lt args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  have hlocRefVal : fr'.localRefs[18]'hlocRefLt = none :=
    registrationFramePc67_localRefs_idx18_eq args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

/-! ### PC 68 (`call 15` = `point_equals` for lhsPt = rhsPt) -/

@[simp] theorem verifyRegistrationProofCode_idx68 :
    verifyRegistrationProofCode[68]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 15 := rfl

theorem registration_env_funcIdx15_lt (o : RegistrationNativeOracle) :
    15 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

theorem registrationModuleEnv_functions_at15 (o : RegistrationNativeOracle)
    (h : 15 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[15]'h =
      { numParams := 2, numReturns := 1, body := .nativeRef (wrapOracleImmRef2 o.pointEquals) } := by
  simp [registrationModuleEnv]

set_option maxHeartbeats 3200000 in
theorem registration_step_pc68_call_pointEquals_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ms : MachineState)
    (ridLhs ridRhs : RefId) (lhsVal rhsVal : MoveValue) (b : Bool) (restBelow : List MoveValue)
    (hreadLhs : ms.containers.read ridLhs = some lhsVal)
    (hreadRhs : ms.containers.read ridRhs = some rhsVal)
    (horacle : o.pointEquals [lhsVal, rhsVal] = some [.bool b]) :
    step (registrationModuleEnv o)
        (registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
          mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] (.immRef ridRhs :: .immRef ridLhs :: restBelow) ms =
      ExecResult.ok
        ({ registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with
            pc := 69 })
        [] (.bool b :: restBelow) ms := by
  have hnative : wrapOracleImmRef2 o.pointEquals ms.containers
        [.immRef ridLhs, .immRef ridRhs] =
      some ([.bool b], ms.containers) := by
    show (Option.bind (derefImm ms.containers (.immRef ridLhs))
          (fun v1 => Option.bind (derefImm ms.containers (.immRef ridRhs))
            (fun v2 => Option.bind (o.pointEquals [v1, v2])
              (fun results => some (results, ms.containers))))) =
        some ([.bool b], ms.containers)
    simp only [derefImm]
    rw [hreadLhs]
    simp only [Option.bind_some]
    rw [hreadRhs]
    simp only [Option.bind_some]
    rw [horacle]
    rfl
  simp only [step, registrationModuleEnv, registrationFramePc68AfterImmBorrow18,
    registrationFramePc67AfterImmBorrow17, registrationFramePc66AfterStLoc18,
    registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
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
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx68,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx15_lt, registrationModuleEnv_functions_at15, FuncDesc.body,
    takeN_two_cons_cons, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

/-! ### PC 69 (`brFalse 71` — branch on equality result) -/

@[simp] theorem verifyRegistrationProofCode_idx69 :
    verifyRegistrationProofCode[69]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .brFalse 71 := rfl

set_option maxHeartbeats 3200000 in
theorem registration_step_pc69_brFalse_true_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with
            pc := 69 })
        [] (.bool true :: rest) ms =
      ExecResult.ok
        ({ registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with
            pc := 70 })
        [] rest ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc68AfterImmBorrow18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with pc := 69 })
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc68AfterImmBorrow18, registrationFramePc67AfterImmBorrow17,
      registrationFramePc66AfterStLoc18, registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
      registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
      registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.brFalse 71 := by
    simp [fr', registrationFramePc68AfterImmBorrow18, registrationFramePc67AfterImmBorrow17,
      registrationFramePc66AfterStLoc18, registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
      registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
      registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx69]
  exact step_brFalse_true_stack (registrationModuleEnv o) fr' [] 71 rest ms hpc hc

set_option maxHeartbeats 3200000 in
theorem registration_step_pc69_brFalse_false_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with
            pc := 69 })
        [] (.bool false :: rest) ms =
      ExecResult.ok
        ({ registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with
            pc := 71 })
        [] rest ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc68AfterImmBorrow18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with pc := 69 })
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc68AfterImmBorrow18, registrationFramePc67AfterImmBorrow17,
      registrationFramePc66AfterStLoc18, registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
      registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
      registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.brFalse 71 := by
    simp [fr', registrationFramePc68AfterImmBorrow18, registrationFramePc67AfterImmBorrow17,
      registrationFramePc66AfterStLoc18, registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
      registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
      registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx69]
  exact step_brFalse_false_stack (registrationModuleEnv o) fr' [] 71 rest ms hpc hc

/-! ### PC 70 (`ret` — return from function) -/

@[simp] theorem verifyRegistrationProofCode_idx70 :
    verifyRegistrationProofCode[70]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .ret := rfl

set_option maxHeartbeats 3200000 in
theorem registration_step_pc70_ret_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue) (ms : MachineState)
    (rest : List MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc68AfterImmBorrow18 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
              mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with
            pc := 70 })
        [] rest ms =
      ExecResult.returned rest ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc68AfterImmBorrow18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with pc := 70 })
    with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc68AfterImmBorrow18, registrationFramePc67AfterImmBorrow17,
      registrationFramePc66AfterStLoc18, registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
      registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
      registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.ret := by
    simp [fr', registrationFramePc68AfterImmBorrow18, registrationFramePc67AfterImmBorrow17,
      registrationFramePc66AfterStLoc18, registrationFramePc64AfterImmBorrow8, registrationFramePc63AfterStLoc17,
      registrationFramePc61AfterImmBorrow16, registrationFramePc60AfterStLoc16,
      registrationFramePc58AfterImmBorrow12, registrationFramePc57AfterImmBorrow14, registrationFramePc56AfterImmBorrow15,
      registrationFramePc55AfterStLoc15, registrationFramePc53AfterImmBorrow10,
      registrationFramePc52AfterImmBorrow13, registrationFramePc51AfterStLoc14, registrationFramePc49AfterMoveLoc3,
      registrationFramePc48AfterStLoc13, registrationFramePc46AfterStLoc12, registrationFramePc44AfterMoveLoc11,
      registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx70]
  simp only [step, dif_pos hpc, hc]

/-- PC 8: `stLoc 8` — pop `rCompressed`, store in local 8, PC→9. -/
theorem registration_step_pc8_stLoc8 (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed : MoveValue) :
    step (registrationModuleEnv o)
        ({ registrationFramePc7AfterMutBorrowLoc7 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv with pc := 8 })
        [] [rCompressed] (registrationMsAfterOptionExtractDup1 mv) =
      ExecResult.ok
        (registrationFramePc9AfterStLoc8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed)
        [] [] (registrationMsAfterOptionExtractDup1 mv) := by
  simp [step, registrationModuleEnv, registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7,
    registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
    registrationVerifyArgs, verifyRegistrationProofCode, verifyRegistrationProofCode_size_val,
    verifyRegistrationProofCode_idx8, registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt,
    registration_locals_after_set5_set7_idx8_lt, registrationVerifyArgs_len]

/-- Four `ok` steps: PC 2→3→4→5→6 with `mv = Option<CompressedPoint>` struct tag `true` on the `is_some` path. -/
theorem registration_run_from_pc2_to_pc6_somePath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv : MoveValue) (tag : Bool) (rest : List MoveValue)
    (hmv : mv = .struct_ (.bool tag :: rest)) (htag : tag = true)
    (fuel : Nat) (_hf : 6 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) =
      run (registrationModuleEnv o)
        ({ registrationFramePc4AfterImmBorrow (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv with
            pc := 6 })
        [] [] (registrationMsAfterImmBorrow7 mv) (fuel - 6) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel - 2 = (fuel - 6) + 4 := by omega
  rw [hfuel]
  have hs2 :=
    registration_step_pc2_stLoc7 o chainId sender contract token ekBa commitBa respBa mv
  have hs3 :=
    registration_step_pc3_immBorrowLoc7 o chainId sender contract token ekBa commitBa respBa mv
  have hs4 :=
    registration_step_pc4_call_optionIsSome o chainId sender contract token ekBa commitBa respBa mv tag rest hmv
  have hs5 := registration_step_pc5_brFalse_fallthrough o chainId sender contract token ekBa commitBa respBa mv tag rest htag
  exact run_succ_succ_succ_succ_ok (registrationModuleEnv o)
    (registrationFrameAtPc2 args hlen)
    (registrationFramePc3AfterStLoc args hlen mv)
    (registrationFramePc4AfterImmBorrow args hlen mv)
    ({ registrationFramePc4AfterImmBorrow args hlen mv with pc := 5 })
    ({ registrationFramePc4AfterImmBorrow args hlen mv with pc := 6 })
    []
    [mv] [] [.immRef 0] [.bool tag] []
    MachineState.empty MachineState.empty (registrationMsAfterImmBorrow7 mv) (registrationMsAfterImmBorrow7 mv)
      (registrationMsAfterImmBorrow7 mv)
    (fuel - 6) hs2 hs3 hs4 hs5

/-- After PC 0–1 with singleton native result `[mv]`, `run` from the entry frame equals `run` from PC 2 with stack `[mv]` and `fuel - 2` remaining steps. -/
theorem registration_run_eq_from_pc2_singleton
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) (mv : MoveValue)
    (fuel : Nat) (hf : 2 ≤ fuel)
    (hl : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some [mv]) :
    run (registrationModuleEnv o)
        (registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa))
        [] [] MachineState.empty fuel =
      run (registrationModuleEnv o)
        (registrationFrameAtPc2 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa))
        [] [mv] MachineState.empty (fuel - 2) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  have hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  have hs0 := registration_step0_moveLoc5 o chainId sender contract token ekBa commitBa respBa
  have hs1 := registration_step1_call0_singleton o chainId sender contract token ekBa commitBa respBa mv hl
  have hfuel : fuel = (fuel - 2) + 2 := by omega
  rw [hfuel]
  exact run_succ_succ_ok (registrationModuleEnv o)
    (registrationInitFrame args)
    ({ registrationInitFrame args with
        pc := 1,
        locals :=
          (registrationInitFrame args).locals.set 5 none (registrationInitFrame_idx5_lt args hlen) })
    (registrationFrameAtPc2 args hlen)
    []
    []
    [.vector .u8 (commitBa.toList.map .u8)]
    [mv]
    MachineState.empty MachineState.empty MachineState.empty
    (fuel - 2) hs0 hs1

/-- From function entry through PC 6 on the `option::is_some` / `brFalse` fall-through path
(singleton decompress + struct tag `true`). -/
theorem registration_run_from_entry_to_pc6_somePath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv : MoveValue) (tag : Bool) (rest : List MoveValue)
    (hmv : mv = .struct_ (.bool tag :: rest)) (htag : tag = true)
    (fuel : Nat) (hf : 6 ≤ fuel)
    (hl : o.newCompressedPointFromBytes [.vector .u8 (commitBa.toList.map .u8)] = some [mv]) :
    run (registrationModuleEnv o)
        (registrationInitFrame (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa))
        [] [] MachineState.empty fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc4AfterImmBorrow (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv with
            pc := 6 })
        [] [] (registrationMsAfterImmBorrow7 mv) (fuel - 6) := by
  have hf2 : 2 ≤ fuel := by omega
  rw [registration_run_eq_from_pc2_singleton o chainId sender contract token ekBa commitBa respBa mv fuel hf2 hl]
  exact registration_run_from_pc2_to_pc6_somePath o chainId sender contract token ekBa commitBa respBa mv tag rest hmv htag
    fuel hf

/-! ## Run-chain: three-step helper (PC 6 → 7 → 8 → 9 success) -/

theorem run_succ_succ_succ_ok (env : ModuleEnv) (f₀ f₁ f₂ f₃ : Frame) (cs : List Frame)
    (s₀ s₁ s₂ s₃ : List MoveValue) (ms₀ ms₁ ms₂ ms₃ : MachineState) (n : Nat)
    (h₀ : step env f₀ cs s₀ ms₀ = ExecResult.ok f₁ cs s₁ ms₁)
    (h₁ : step env f₁ cs s₁ ms₁ = ExecResult.ok f₂ cs s₂ ms₂)
    (h₂ : step env f₂ cs s₂ ms₂ = ExecResult.ok f₃ cs s₃ ms₃) :
    run env f₀ cs s₀ ms₀ n.succ.succ.succ = run env f₃ cs s₃ ms₃ n := by
  simp only [run, h₀, run, h₁, run, h₂]

/-- From `pc 6` (after PC 5 fall-through) through PCs 6 (mutBorrowLoc 7), 7 (call 2 optionExtract)
and 8 (stLoc 8) to the start of PC 9. -/
theorem registration_run_from_pc6_to_pc9_somePath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed : MoveValue) (rest : List MoveValue)
    (hmv : mv = .struct_ (.bool true :: rCompressed :: rest))
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc4AfterImmBorrow (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv with pc := 6 })
        [] [] (registrationMsAfterImmBorrow7 mv) fuel =
      run (registrationModuleEnv o)
        (registrationFramePc9AfterStLoc8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed)
        [] [] (registrationMsAfterOptionExtractDup1 mv) (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs6 := registration_step_pc6_mutBorrowLoc7 o chainId sender contract token ekBa commitBa respBa mv
  have hs7 := registration_step_pc7_call_optionExtract o chainId sender contract token ekBa commitBa respBa mv rCompressed rest hmv
  have hs8 := registration_step_pc8_stLoc8 o chainId sender contract token ekBa commitBa respBa mv rCompressed
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc4AfterImmBorrow args hlen mv with pc := 6 })
    (registrationFramePc7AfterMutBorrowLoc7 args hlen mv)
    ({ registrationFramePc7AfterMutBorrowLoc7 args hlen mv with pc := 8 })
    (registrationFramePc9AfterStLoc8 args hlen mv rCompressed)
    []
    [] [.mutRef 1] [rCompressed] []
    (registrationMsAfterImmBorrow7 mv)
    (registrationMsAfterMutBorrowDup7 mv)
    (registrationMsAfterOptionExtractDup1 mv)
    (registrationMsAfterOptionExtractDup1 mv)
    (fuel - 3) hs6 hs7 hs8

/-- From `pc 9` through PCs 9 (moveLoc 6), 10 (call 3 = newScalarFromBytes), 11 (stLoc 9)
to the start of PC 12, given the singleton `newScalarFromBytes` hypothesis. -/
theorem registration_run_from_pc9_to_pc12_singletonPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt : MoveValue)
    (hs : o.newScalarFromBytes [.vector .u8 (respBa.toList.map .u8)] = some [sOpt])
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc9AfterStLoc8 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed)
        [] [] (registrationMsAfterOptionExtractDup1 mv) fuel =
      run (registrationModuleEnv o)
        (registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt)
        [] [] (registrationMsAfterOptionExtractDup1 mv) (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs9 := registration_step_pc9_moveLoc6 o chainId sender contract token ekBa commitBa respBa mv rCompressed
  have hs10 := registration_step_pc10_call3_singleton o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt hs
  have hs11 := registration_step_pc11_stLoc9 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    (registrationFramePc9AfterStLoc8 args hlen mv rCompressed)
    (registrationFramePc10AfterMoveLoc6 args hlen mv rCompressed)
    (registrationFramePc11AfterCall3 args hlen mv rCompressed)
    (registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt)
    []
    [] [.vector .u8 (respBa.toList.map .u8)] [sOpt] []
    (registrationMsAfterOptionExtractDup1 mv)
    (registrationMsAfterOptionExtractDup1 mv)
    (registrationMsAfterOptionExtractDup1 mv)
    (registrationMsAfterOptionExtractDup1 mv)
    (fuel - 3) hs9 hs10 hs11

/-- From `pc 12` through PCs 12 (immBorrowLoc 9), 13 (call 1 isSome on &sOpt),
14 (brFalse 74 fallthrough when stag=true) to `pc := 15`. -/
theorem registration_run_from_pc12_to_pc15_someSOptPath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt : MoveValue) (stag : Bool) (srest : List MoveValue)
    (hsOpt : sOpt = .struct_ (.bool stag :: srest)) (hstag : stag = true)
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt)
        [] [] (registrationMsAfterOptionExtractDup1 mv) fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt with
            pc := 15 })
        [] [] (registrationMsAfterImmBorrow9 mv sOpt) (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs12 := registration_step_pc12_immBorrowLoc9 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt
  have hs13 := registration_step_pc13_call_optionIsSome o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt stag srest hsOpt
  have hs14 := registration_step_pc14_brFalse_fallthrough o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt stag srest hstag
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    (registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt)
    ({ registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt with pc := 13 })
    ({ registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt with pc := 14 })
    ({ registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt with pc := 15 })
    []
    [] [.immRef 2] [.bool stag] []
    (registrationMsAfterOptionExtractDup1 mv)
    (registrationMsAfterImmBorrow9 mv sOpt)
    (registrationMsAfterImmBorrow9 mv sOpt)
    (registrationMsAfterImmBorrow9 mv sOpt)
    (fuel - 3) hs12 hs13 hs14

/-- From `pc 15` through PCs 15 (mutBorrowLoc 9), 16 (call 2 extract on &mut sOpt),
17 (stLoc 10 for sVal) to pre-PC 18. -/
theorem registration_run_from_pc15_to_pc18_singletonSomePath
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (srest' : List MoveValue)
    (hsOpt : sOpt = .struct_ (.bool true :: sVal :: srest'))
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc12AfterStLoc9 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt with
            pc := 15 })
        [] [] (registrationMsAfterImmBorrow9 mv sOpt) fuel =
      run (registrationModuleEnv o)
        (registrationFramePc18AfterStLoc10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [] (registrationMsAfterOptionExtractDup3 mv sOpt) (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs15 := registration_step_pc15_mutBorrowLoc9 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt
  have hs16 := registration_step_pc16_call_optionExtract o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal srest' hsOpt
  have hs17 := registration_step_pc17_stLoc10 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc12AfterStLoc9 args hlen mv rCompressed sOpt with pc := 15 })
    (registrationFramePc16AfterMutBorrow9 args hlen mv rCompressed sOpt)
    ({ registrationFramePc16AfterMutBorrow9 args hlen mv rCompressed sOpt with pc := 17 })
    (registrationFramePc18AfterStLoc10 args hlen mv rCompressed sOpt sVal)
    []
    [] [.mutRef 3] [sVal] []
    (registrationMsAfterImmBorrow9 mv sOpt)
    (registrationMsAfterMutBorrow9 mv sOpt)
    (registrationMsAfterOptionExtractDup3 mv sOpt)
    (registrationMsAfterOptionExtractDup3 mv sOpt)
    (fuel - 3) hs15 hs16 hs17

/-- From `pc 18` through PCs 18 (ldConst 5 DST), 19 (stLoc 11 for msg) to pre-PC 20. -/
theorem registration_run_from_pc18_to_pc20_path
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (fuel : Nat) (_hf : 2 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc18AfterStLoc10 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [] (registrationMsAfterOptionExtractDup3 mv sOpt) fuel =
      run (registrationModuleEnv o)
        (registrationFramePc20AfterStLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [] (registrationMsAfterOptionExtractDup3 mv sOpt) (fuel - 2) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 2) + 2 := by omega
  rw [hfuel]
  have hs18 := registration_step_pc18_ldConst5 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs19 := registration_step_pc19_stLoc11 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  exact run_succ_succ_ok (registrationModuleEnv o)
    (registrationFramePc18AfterStLoc10 args hlen mv rCompressed sOpt sVal)
    ({ registrationFramePc18AfterStLoc10 args hlen mv rCompressed sOpt sVal with pc := 19 })
    (registrationFramePc20AfterStLoc11 args hlen mv rCompressed sOpt sVal)
    []
    [] [fiatShamirRegistrationDstValue] []
    (registrationMsAfterOptionExtractDup3 mv sOpt)
    (registrationMsAfterOptionExtractDup3 mv sOpt)
    (registrationMsAfterOptionExtractDup3 mv sOpt)
    (fuel - 2) hs18 hs19

/-- From `pc 20` through PCs 20 (mutBorrowLoc 11 alloc msg), 21 (moveLoc 0 push chainId) to pre-PC 22. -/
theorem registration_run_from_pc20_to_pc22_path
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (fuel : Nat) (_hf : 2 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc20AfterStLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [] (registrationMsAfterOptionExtractDup3 mv sOpt) fuel =
      run (registrationModuleEnv o)
        (registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.u8 chainId, .mutRef 4] (registrationMsAfterMutBorrowMsg mv sOpt) (fuel - 2) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 2) + 2 := by omega
  rw [hfuel]
  have hs20 := registration_step_pc20_mutBorrowLoc11 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs21 := registration_step_pc21_moveLoc0 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  exact run_succ_succ_ok (registrationModuleEnv o)
    (registrationFramePc20AfterStLoc11 args hlen mv rCompressed sOpt sVal)
    (registrationFramePc21AfterMutBorrowMsg args hlen mv rCompressed sOpt sVal)
    (registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal)
    []
    [] [.mutRef 4] [.u8 chainId, .mutRef 4]
    (registrationMsAfterOptionExtractDup3 mv sOpt)
    (registrationMsAfterMutBorrowMsg mv sOpt)
    (registrationMsAfterMutBorrowMsg mv sOpt)
    (fuel - 2) hs20 hs21

/-- From `pc 22` through PCs 22 (call 4 pushBack chainId), 23 (mutBorrowLoc 11 reuse),
24 (immBorrowLoc 1 alloc sender) to `Pc25AfterImmBorrow1`. -/
theorem registration_run_from_pc22_to_pc25_path
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.u8 chainId, .mutRef 4] (registrationMsAfterMutBorrowMsg mv sOpt) fuel =
      run (registrationModuleEnv o)
        (registrationFramePc25AfterImmBorrow1 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.immRef 5, .mutRef 4] (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender) (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs22 := registration_step_pc22_call_pushBackChainId o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs23 := registration_step_pc23_mutBorrowLoc11 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs24 := registration_step_pc24_immBorrowLoc1 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    (registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal)
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 23 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 24 })
    (registrationFramePc25AfterImmBorrow1 args hlen mv rCompressed sOpt sVal)
    []
    [.u8 chainId, .mutRef 4] [] [.mutRef 4] [.immRef 5, .mutRef 4]
    (registrationMsAfterMutBorrowMsg mv sOpt)
    (registrationMsAfterPushBackChainId mv sOpt chainId)
    (registrationMsAfterPushBackChainId mv sOpt chainId)
    (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender)
    (fuel - 3) hs22 hs23 hs24

/-- From `pc 25` (via `Pc25AfterImmBorrow1`) through PCs 25 (call 5 bcs sender), 26 (call 6 append sender),
27 (mutBorrowLoc 11 reuse) to `{ Pc22 with pc := 28 }`. -/
theorem registration_run_from_pc25_to_pc28_path
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc25AfterImmBorrow1 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.immRef 5, .mutRef 4] (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender) fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 28 })
        [] [.mutRef 4] (registrationMsAfterAppendSender mv sOpt chainId sender) (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs25 := registration_step_pc25_call_bcsToBytes_sender o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs26 := registration_step_pc26_call_appendSender o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs27 := registration_step_pc27_mutBorrowLoc11 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    (registrationFramePc25AfterImmBorrow1 args hlen mv rCompressed sOpt sVal)
    ({ registrationFramePc25AfterImmBorrow1 args hlen mv rCompressed sOpt sVal with pc := 26 })
    ({ registrationFramePc25AfterImmBorrow1 args hlen mv rCompressed sOpt sVal with pc := 27 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 28 })
    []
    [.immRef 5, .mutRef 4] [.vector .u8 (sender.toList.map .u8), .mutRef 4] [] [.mutRef 4]
    (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender)
    (registrationMsAfterImmBorrow1_sender mv sOpt chainId sender)
    (registrationMsAfterAppendSender mv sOpt chainId sender)
    (registrationMsAfterAppendSender mv sOpt chainId sender)
    (fuel - 3) hs25 hs26 hs27

/-- From `{Pc22 with pc := 28}` through PCs 28 (immBorrowLoc 2 alloc contract),
29 (call 5 bcs contract), 30 (call 6 append contract) to `{Pc22 with pc := 31}`. -/
theorem registration_run_from_pc28_to_pc31_path
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 28 })
        [] [.mutRef 4] (registrationMsAfterAppendSender mv sOpt chainId sender) fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 31 })
        [] [] (registrationMsAfterAppendContract mv sOpt chainId sender contract) (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs28 := registration_step_pc28_immBorrowLoc2 o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs29 := registration_step_pc29_call_bcsToBytes_contract o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  have hs30 := registration_step_pc30_call_appendContract o chainId sender contract token ekBa commitBa respBa mv rCompressed sOpt sVal
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 28 })
    (registrationFramePc29AfterImmBorrow2 args hlen mv rCompressed sOpt sVal)
    ({ registrationFramePc29AfterImmBorrow2 args hlen mv rCompressed sOpt sVal with pc := 30 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 31 })
    []
    [.mutRef 4] [.immRef 6, .mutRef 4] [.vector .u8 (contract.toList.map .u8), .mutRef 4] []
    (registrationMsAfterAppendSender mv sOpt chainId sender)
    (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract)
    (registrationMsAfterImmBorrow2_contract mv sOpt chainId sender contract)
    (registrationMsAfterAppendContract mv sOpt chainId sender contract)
    (fuel - 3) hs28 hs29 hs30

/-! ### Generic alloc / read helper (used to thread the alloc'd ref through PC 31+ chains) -/

theorem containerStore_read_alloc_new (cs : ContainerStore) (v : MoveValue) :
    (cs.alloc v).1.read (cs.alloc v).2 = some v := by
  simp only [ContainerStore.alloc, ContainerStore.read]
  have hlt : cs.store.size < (cs.store.push v).size := by
    simp [Array.size_push]
  rw [dif_pos hlt]
  congr 1
  exact Array.getElem_push_eq

/-- Allocating a fresh cell preserves reads at existing (in-bounds) refs. -/
theorem containerStore_read_alloc_old (cs : ContainerStore) (v : MoveValue) (rid : RefId)
    (h : rid < cs.store.size) :
    (cs.alloc v).1.read rid = cs.read rid := by
  simp only [ContainerStore.alloc, ContainerStore.read]
  have hlt' : rid < (cs.store.push v).size := by
    simp only [Array.size_push]
    exact Nat.lt_succ_of_lt h
  rw [dif_pos hlt', dif_pos h]
  congr 1
  rw [Array.getElem_push_lt h]

/-- Reading a specific `some`-yielding ref is preserved by a fresh alloc. -/
theorem containerStore_read_alloc_of_read_some (cs : ContainerStore) (v : MoveValue)
    (rid : RefId) (u : MoveValue) (h : cs.read rid = some u) :
    (cs.alloc v).1.read rid = some u := by
  have hlt : rid < cs.store.size := by
    by_contra hnlt
    push_neg at hnlt
    simp [ContainerStore.read, Nat.not_lt.mpr hnlt] at h
  rw [containerStore_read_alloc_old cs v rid hlt, h]

/-! ### PC 31–34 chain: generic-MS threading

Extends the run-level chain from PC 31 to PC 35, absorbing the four instructions:
`mutBorrowLoc 11` / `immBorrowLoc 4` (alloc token) / `call 5` (`bcs::to_bytes`) / `call 6` (`vector::append`).

Stated with an abstract input `ms : MachineState` plus hypotheses
(a) `ms1.containers.read 4 = some (.vector .u8 existing)` — current msg at ref 4 (on the
    *post-alloc* MS, since the alloc at `ms.store.size` is a fresh cell), and
(b) `ms1.containers.write 4 (existing ++ tokenBytes) = some cs'` — the append succeeds.
The caller is responsible for discharging (a)/(b) when instantiating; they typically
hold trivially because `alloc` at a fresh index does not touch the existing ref 4. -/

theorem registration_run_from_pc31_to_pc35_abstractMs
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (ms : MachineState)
    (existing : List MoveValue) (csFinal : ContainerStore)
    (hread4_post_alloc :
      (ms.containers.alloc (.address token)).1.read 4 = some (.vector .u8 existing))
    (hwrite4_post_alloc :
      (ms.containers.alloc (.address token)).1.write 4
        (.vector .u8 (existing ++ token.toList.map .u8)) = some csFinal)
    (fuel : Nat) (_hf : 4 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0
              (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 31 })
        [] [] ms fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc33AfterImmBorrow4
              (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 35 })
        [] []
        { { ms with containers := (ms.containers.alloc (.address token)).1 } with containers := csFinal }
        (fuel - 4) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 4) + 4 := by omega
  rw [hfuel]
  have hs31 := registration_step_pc31_mutBorrowLoc11_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal ms
  have hs32 := registration_step_pc32_immBorrowLoc4_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal ms
  have hread_new :
      ({ ms with containers := (ms.containers.alloc (.address token)).1 }).containers.read
        (ms.containers.alloc (.address token)).2 = some (.address token) := by
    show (ms.containers.alloc (.address token)).1.read (ms.containers.alloc (.address token)).2 = _
    exact containerStore_read_alloc_new ms.containers (.address token)
  have hs33 := registration_step_pc33_call_bcsToBytes_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal
    { ms with containers := (ms.containers.alloc (.address token)).1 }
    (ms.containers.alloc (.address token)).2 token hread_new
  have hs34 := registration_step_pc34_call_append_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal
    { ms with containers := (ms.containers.alloc (.address token)).1 }
    existing (token.toList.map .u8) csFinal hread4_post_alloc hwrite4_post_alloc
  exact run_succ_succ_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 31 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 32 })
    (registrationFramePc33AfterImmBorrow4 args hlen mv rCompressed sOpt sVal)
    ({ registrationFramePc33AfterImmBorrow4 args hlen mv rCompressed sOpt sVal with pc := 34 })
    ({ registrationFramePc33AfterImmBorrow4 args hlen mv rCompressed sOpt sVal with pc := 35 })
    []
    [] [.mutRef 4]
    [.immRef (ms.containers.alloc (.address token)).2, .mutRef 4]
    [.vector .u8 (token.toList.map .u8), .mutRef 4]
    []
    ms ms
    { ms with containers := (ms.containers.alloc (.address token)).1 }
    { ms with containers := (ms.containers.alloc (.address token)).1 }
    { { ms with containers := (ms.containers.alloc (.address token)).1 } with containers := csFinal }
    (fuel - 4) hs31 hs32 hs33 hs34

/-! ### PC 35–38 chain: generic-MS threading

Extends the run-level chain from PC 35 to PC 39, absorbing four instructions:
`mutBorrowLoc 11` / `copyLoc 3` / `call 7` (`pubkey_to_bytes`) / `call 6` (`vector::append`).

Unlike the PC 31 → PC 35 chain, there is no fresh `alloc` here (ref 4 already exists);
only `call 6` at PC 38 mutates the container store. -/

theorem registration_run_from_pc35_to_pc39_abstractMs
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (ms : MachineState)
    (ekBytesList existing : List MoveValue) (csFinal : ContainerStore)
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some [.vector .u8 ekBytesList])
    (hread4 : ms.containers.read 4 = some (.vector .u8 existing))
    (hwrite4 : ms.containers.write 4 (.vector .u8 (existing ++ ekBytesList)) = some csFinal)
    (fuel : Nat) (_hf : 4 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0
              (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 35 })
        [] [] ms fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0
              (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 39 })
        [] [] { ms with containers := csFinal } (fuel - 4) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 4) + 4 := by omega
  rw [hfuel]
  have hs35 := registration_step_pc35_mutBorrowLoc11_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal ms
  have hs36 := registration_step_pc36_copyLoc3_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal ms
  have hs37 := registration_step_pc37_call_pubkeyToBytes_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal ms (.vector .u8 ekBytesList) horacle
  have hs38 := registration_step_pc38_call_append_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal ms existing ekBytesList csFinal hread4 hwrite4
  exact run_succ_succ_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 35 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 36 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 37 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 38 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 39 })
    []
    [] [.mutRef 4]
    [.struct_ [.vector .u8 (ekBa.toList.map .u8)], .mutRef 4]
    [.vector .u8 ekBytesList, .mutRef 4]
    []
    ms ms ms ms { ms with containers := csFinal }
    (fuel - 4) hs35 hs36 hs37 hs38

/-! ### PC 39–42 chain: generic-MS threading

Extends the chain from PC 39 to PC 43, absorbing:
`mutBorrowLoc 11` / `copyLoc 8` / `call 8` (`compressed_point_to_bytes`) / `call 6` (`vector::append`).

Same shape as PC 35 → PC 39. -/

theorem registration_run_from_pc39_to_pc43_abstractMs
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (ms : MachineState)
    (rcBytesList existing : List MoveValue) (csFinal : ContainerStore)
    (horacle : o.compressedPointToBytes [rCompressed] = some [.vector .u8 rcBytesList])
    (hread4 : ms.containers.read 4 = some (.vector .u8 existing))
    (hwrite4 : ms.containers.write 4 (.vector .u8 (existing ++ rcBytesList)) = some csFinal)
    (fuel : Nat) (_hf : 4 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0
              (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 39 })
        [] [] ms fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0
              (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 43 })
        [] [] { ms with containers := csFinal } (fuel - 4) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 4) + 4 := by omega
  rw [hfuel]
  have hs39 := registration_step_pc39_mutBorrowLoc11_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal ms
  have hs40 := registration_step_pc40_copyLoc8_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal ms
  have hs41 := registration_step_pc41_call_compressedPointToBytes_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal ms (.vector .u8 rcBytesList) horacle
  have hs42 := registration_step_pc42_call_append_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal ms existing rcBytesList csFinal hread4 hwrite4
  exact run_succ_succ_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 39 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 40 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 41 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 42 })
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 43 })
    []
    [] [.mutRef 4]
    [rCompressed, .mutRef 4]
    [.vector .u8 rcBytesList, .mutRef 4]
    []
    ms ms ms ms { ms with containers := csFinal }
    (fuel - 4) hs39 hs40 hs41 hs42

/-! ### PC 43–45 chain: `moveLoc 11` / `call 9` (SHA2-512) / `stLoc 12`.
Three steps — the frame transitions from `Pc22AfterMoveLoc0` → `Pc44AfterMoveLoc11`
(clears locals[11] + localRefs[11]) then to `Pc46AfterStLoc12` (stores `eScalar`). -/

theorem registration_run_from_pc43_to_pc46_abstractMs
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue)
    (ms : MachineState)
    (msgVal eScalar : MoveValue)
    (hread4 : ms.containers.read 4 = some msgVal)
    (hnative : newScalarFromSha2_512 [msgVal] = some [eScalar])
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0
              (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 43 })
        [] [] ms fuel =
      run (registrationModuleEnv o)
        (registrationFramePc46AfterStLoc12
            (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar)
        [] [] ms (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs43 := registration_step_pc43_moveLoc11_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal ms msgVal hread4
  have hs44 := registration_step_pc44_call_newScalarFromSha2_512_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal ms msgVal eScalar hnative
  have hs45 := registration_step_pc45_stLoc12_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar ms
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 43 })
    (registrationFramePc44AfterMoveLoc11 args hlen mv rCompressed sOpt sVal)
    ({ registrationFramePc44AfterMoveLoc11 args hlen mv rCompressed sOpt sVal with pc := 45 })
    (registrationFramePc46AfterStLoc12 args hlen mv rCompressed sOpt sVal eScalar)
    []
    [] [msgVal] [eScalar] []
    ms ms ms ms
    (fuel - 3) hs43 hs44 hs45

/-! ### PC 46–47 chain: `call 10` (`hash_to_point_base`) / `stLoc 13`.
Two steps; frame transitions `Pc46AfterStLoc12` → `Pc48AfterStLoc13`. -/

theorem registration_run_from_pc46_to_pc48_abstractMs
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar : MoveValue)
    (ms : MachineState)
    (hPoint : MoveValue)
    (horacle : o.hashToPointBase [] = some [hPoint])
    (fuel : Nat) (_hf : 2 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc46AfterStLoc12
              (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar with
            pc := 46 })
        [] [] ms fuel =
      run (registrationModuleEnv o)
        (registrationFramePc48AfterStLoc13
            (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
            mv rCompressed sOpt sVal eScalar hPoint)
        [] [] ms (fuel - 2) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 2) + 2 := by omega
  rw [hfuel]
  have hs46 := registration_step_pc46_call_hashToPointBase_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar ms hPoint horacle
  have hs47 := registration_step_pc47_stLoc13_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ms
  exact run_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc46AfterStLoc12 args hlen mv rCompressed sOpt sVal eScalar with pc := 46 })
    ({ registrationFramePc46AfterStLoc12 args hlen mv rCompressed sOpt sVal eScalar with pc := 47 })
    (registrationFramePc48AfterStLoc13 args hlen mv rCompressed sOpt sVal eScalar hPoint)
    []
    [] [hPoint] []
    ms ms ms
    (fuel - 2) hs46 hs47

/-! ### PC 48–50 chain: `moveLoc 3` / `call 11` (`pubkey_to_point`) / `stLoc 14`.
Three steps; frame transitions `Pc48AfterStLoc13` → `Pc49AfterMoveLoc3` → `Pc51AfterStLoc14`. -/

theorem registration_run_from_pc48_to_pc51_abstractMs
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint : MoveValue)
    (ms : MachineState)
    (ekPt : MoveValue)
    (horacle : o.pubkeyToPoint [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] = some [ekPt])
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc48AfterStLoc13
              (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar hPoint with
            pc := 48 })
        [] [] ms fuel =
      run (registrationModuleEnv o)
        (registrationFramePc51AfterStLoc14
            (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
            mv rCompressed sOpt sVal eScalar hPoint ekPt)
        [] [] ms (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  have hs48 := registration_step_pc48_moveLoc3_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ms
  have hs49 := registration_step_pc49_call_pubkeyToPoint_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ms ekPt horacle
  have hs50 := registration_step_pc50_stLoc14_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt ms
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc48AfterStLoc13 args hlen mv rCompressed sOpt sVal eScalar hPoint with pc := 48 })
    (registrationFramePc49AfterMoveLoc3 args hlen mv rCompressed sOpt sVal eScalar hPoint)
    ({ registrationFramePc49AfterMoveLoc3 args hlen mv rCompressed sOpt sVal eScalar hPoint with pc := 50 })
    (registrationFramePc51AfterStLoc14 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt)
    []
    [] [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] [ekPt] []
    ms ms ms ms
    (fuel - 3) hs48 hs49 hs50

/-! ### PC 51–54 chain: `immBorrowLoc 13` / `immBorrowLoc 10` / `call 12` (`point_mul`) / `stLoc 15`.
Four steps — two fresh allocs (hPoint and sVal) thread through to `point_mul`. -/

theorem registration_run_from_pc51_to_pc55_abstractMs
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt : MoveValue)
    (ms : MachineState)
    (hsPt : MoveValue)
    (horacle : o.pointMul [hPoint, sVal] = some [hsPt])
    (fuel : Nat) (_hf : 4 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc51AfterStLoc14
              (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar hPoint ekPt with
            pc := 51 })
        [] [] ms fuel =
      run (registrationModuleEnv o)
        (registrationFramePc55AfterStLoc15
            (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
            mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
        [] []
        { ms with containers := ((ms.containers.alloc hPoint).1.alloc sVal).1 }
        (fuel - 4) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 4) + 4 := by omega
  rw [hfuel]
  -- PC 51: alloc hPoint into ms.containers, getting ref (ms.alloc hPoint).2 and cs1.
  have hs51 := registration_step_pc51_immBorrowLoc13_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt ms []
  -- After PC 51: ms → ms1 = { ms with containers := (ms.alloc hPoint).1 }
  -- PC 52 on ms1: alloc sVal, getting ref (ms1.alloc sVal).2 = (cs1.alloc sVal).2 and cs2.
  have hs52 := registration_step_pc52_immBorrowLoc10_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt
    { ms with containers := (ms.containers.alloc hPoint).1 }
    [.immRef (ms.containers.alloc hPoint).2]
  -- After PC 52: ms → ms2 = { ms with containers := ((ms.alloc hPoint).1.alloc sVal).1 }
  set cs1 := (ms.containers.alloc hPoint).1 with hcs1
  set cs2 := (cs1.alloc sVal).1 with hcs2
  set ms2 : MachineState := { ms with containers := cs2 } with hms2
  -- At ms2 the two refs read hPoint and sVal respectively.
  have hreadH_ms2 : ms2.containers.read (ms.containers.alloc hPoint).2 = some hPoint := by
    show cs2.read (ms.containers.alloc hPoint).2 = _
    rw [hcs2]
    rw [containerStore_read_alloc_of_read_some cs1 sVal (ms.containers.alloc hPoint).2 hPoint]
    show cs1.read _ = _
    rw [hcs1]
    exact containerStore_read_alloc_new ms.containers hPoint
  have hreadS_ms2 : ms2.containers.read (cs1.alloc sVal).2 = some sVal := by
    show cs2.read (cs1.alloc sVal).2 = _
    rw [hcs2]
    exact containerStore_read_alloc_new cs1 sVal
  -- Specialise PC 53 at ms2 with the two reads.
  have hs53 := registration_step_pc53_call_pointMul_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt ms2
    (ms.containers.alloc hPoint).2 (cs1.alloc sVal).2
    hPoint sVal hsPt hreadH_ms2 hreadS_ms2 horacle
  -- PC 54 at ms2.
  have hs54 := registration_step_pc54_stLoc15_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ms2 []
  exact run_succ_succ_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc51AfterStLoc14 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt with pc := 51 })
    (registrationFramePc52AfterImmBorrow13 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt)
    (registrationFramePc53AfterImmBorrow10 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt)
    ({ registrationFramePc53AfterImmBorrow10 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt with pc := 54 })
    (registrationFramePc55AfterStLoc15 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
    []
    []
    [.immRef (ms.containers.alloc hPoint).2]
    [.immRef (cs1.alloc sVal).2, .immRef (ms.containers.alloc hPoint).2]
    [hsPt]
    []
    ms
    { ms with containers := cs1 }
    ms2 ms2 ms2
    (fuel - 4) hs51 hs52 hs53 hs54

/-! ### PC 55–58 chain: `immBorrowLoc 15` / `immBorrowLoc 14` / `immBorrowLoc 12` / `call 12` (`point_mul`).
Four steps — three fresh allocs (hsPt, ekPt, eScalar) then `pointMul(ekPt, eScalar)`. Ends at
frame `{ Pc58AfterImmBorrow12 with pc := 59 }` with stack `[ekePt, .immRef ridHsPt]`. -/

theorem registration_run_from_pc55_to_pc59_abstractMs
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt : MoveValue)
    (ms : MachineState)
    (ekePt : MoveValue)
    (horacle : o.pointMul [ekPt, eScalar] = some [ekePt])
    (fuel : Nat) (_hf : 4 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc55AfterStLoc15
              (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with
            pc := 55 })
        [] [] ms fuel =
      run (registrationModuleEnv o)
        ({ registrationFramePc58AfterImmBorrow12
              (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with
            pc := 59 })
        [] [ekePt, .immRef (ms.containers.alloc hsPt).2]
        { ms with containers := (((ms.containers.alloc hsPt).1.alloc ekPt).1.alloc eScalar).1 }
        (fuel - 4) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 4) + 4 := by omega
  rw [hfuel]
  set cs1 := (ms.containers.alloc hsPt).1 with hcs1
  set cs2 := (cs1.alloc ekPt).1 with hcs2
  set cs3 := (cs2.alloc eScalar).1 with hcs3
  set ms1 : MachineState := { ms with containers := cs1 } with hms1
  set ms2 : MachineState := { ms with containers := cs2 } with hms2
  set ms3 : MachineState := { ms with containers := cs3 } with hms3
  have hs55 := registration_step_pc55_immBorrowLoc15_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ms []
  have hs56 := registration_step_pc56_immBorrowLoc14_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ms1
    [.immRef (ms.containers.alloc hsPt).2]
  have hs57 := registration_step_pc57_immBorrowLoc12_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ms2
    [.immRef (cs1.alloc ekPt).2, .immRef (ms.containers.alloc hsPt).2]
  have hreadEkPt_ms3 : ms3.containers.read (cs1.alloc ekPt).2 = some ekPt := by
    show cs3.read (cs1.alloc ekPt).2 = _
    rw [hcs3]
    rw [containerStore_read_alloc_of_read_some cs2 eScalar (cs1.alloc ekPt).2 ekPt]
    show cs2.read _ = _
    rw [hcs2]
    exact containerStore_read_alloc_new cs1 ekPt
  have hreadEScalar_ms3 : ms3.containers.read (cs2.alloc eScalar).2 = some eScalar := by
    show cs3.read (cs2.alloc eScalar).2 = _
    rw [hcs3]
    exact containerStore_read_alloc_new cs2 eScalar
  have hs58 := registration_step_pc58_call_pointMul_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ms3
    (cs1.alloc ekPt).2 (cs2.alloc eScalar).2
    ekPt eScalar ekePt [.immRef (ms.containers.alloc hsPt).2]
    hreadEkPt_ms3 hreadEScalar_ms3 horacle
  exact run_succ_succ_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc55AfterStLoc15 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with pc := 55 })
    (registrationFramePc56AfterImmBorrow15 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
    (registrationFramePc57AfterImmBorrow14 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
    (registrationFramePc58AfterImmBorrow12 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt)
    ({ registrationFramePc58AfterImmBorrow12 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with pc := 59 })
    []
    []
    [.immRef (ms.containers.alloc hsPt).2]
    [.immRef (cs1.alloc ekPt).2, .immRef (ms.containers.alloc hsPt).2]
    [.immRef (cs2.alloc eScalar).2, .immRef (cs1.alloc ekPt).2, .immRef (ms.containers.alloc hsPt).2]
    [ekePt, .immRef (ms.containers.alloc hsPt).2]
    ms ms1 ms2 ms3 ms3
    (fuel - 4) hs55 hs56 hs57 hs58

/-! ### PC 59–62 chain: `stLoc 16` / `immBorrowLoc 16` / `call 13` (`point_add`) / `stLoc 17`.
Four steps — store ekePt, borrow it, add (hsPt + ekePt → lhsPt), store lhsPt. Ends at frame
`registrationFramePc63AfterStLoc17` with stack `[]`, and `ms` extended with one alloc of `ekePt`. -/

theorem registration_run_from_pc59_to_pc63_abstractMs
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt : MoveValue)
    (ms : MachineState)
    (ridHsPt : RefId)
    (hreadHsPt : ms.containers.read ridHsPt = some hsPt)
    (horacle : o.pointAdd [hsPt, ekePt] = some [lhsPt])
    (fuel : Nat) (_hf : 4 ≤ fuel) :
    run (registrationModuleEnv o)
        ({ registrationFramePc58AfterImmBorrow12
              (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with
            pc := 59 })
        [] [ekePt, .immRef ridHsPt] ms fuel =
      run (registrationModuleEnv o)
        (registrationFramePc63AfterStLoc17
            (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
            mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt)
        [] []
        { ms with containers := (ms.containers.alloc ekePt).1 }
        (fuel - 4) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 4) + 4 := by omega
  rw [hfuel]
  set cs1 := (ms.containers.alloc ekePt).1 with hcs1
  set ms1 : MachineState := { ms with containers := cs1 } with hms1
  have hs59 := registration_step_pc59_stLoc16_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt ms
    [.immRef ridHsPt]
  have hs60 := registration_step_pc60_immBorrowLoc16_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt ms
    [.immRef ridHsPt]
  have hreadHs_ms1 : ms1.containers.read ridHsPt = some hsPt := by
    show cs1.read _ = _
    rw [hcs1]
    exact containerStore_read_alloc_of_read_some ms.containers ekePt ridHsPt hsPt hreadHsPt
  have hreadEke_ms1 : ms1.containers.read (ms.containers.alloc ekePt).2 = some ekePt := by
    show cs1.read _ = _
    rw [hcs1]
    exact containerStore_read_alloc_new ms.containers ekePt
  have hs61 := registration_step_pc61_call_pointAdd_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt ms1
    ridHsPt (ms.containers.alloc ekePt).2 hsPt ekePt lhsPt []
    hreadHs_ms1 hreadEke_ms1 horacle
  have hs62 := registration_step_pc62_stLoc17_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt ms1 []
  exact run_succ_succ_succ_succ_ok (registrationModuleEnv o)
    ({ registrationFramePc58AfterImmBorrow12 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt with pc := 59 })
    (registrationFramePc60AfterStLoc16 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt)
    (registrationFramePc61AfterImmBorrow16 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt)
    ({ registrationFramePc61AfterImmBorrow16 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt with pc := 62 })
    (registrationFramePc63AfterStLoc17 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt)
    []
    [ekePt, .immRef ridHsPt]
    [.immRef ridHsPt]
    [.immRef (ms.containers.alloc ekePt).2, .immRef ridHsPt]
    [lhsPt]
    []
    ms ms ms1 ms1 ms1
    (fuel - 4) hs59 hs60 hs61 hs62

/-! ### PC 63–65 chain: `immBorrowLoc 8` / `call 14` (`point_decompress`) / `stLoc 18`.
Three steps — borrow rCompressed, decompress to rhsPt, store. Ends at frame
`registrationFramePc66AfterStLoc18` with stack `[]`, `ms` extended with one alloc of `rCompressed`. -/

theorem registration_run_from_pc63_to_pc66_abstractMs
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue)
    (ms : MachineState)
    (horacle : o.pointDecompress [rCompressed] = some [rhsPt])
    (fuel : Nat) (_hf : 3 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc63AfterStLoc17
            (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
            mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt)
        [] [] ms fuel =
      run (registrationModuleEnv o)
        (registrationFramePc66AfterStLoc18
            (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
            mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] []
        { ms with containers := (ms.containers.alloc rCompressed).1 }
        (fuel - 3) := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = (fuel - 3) + 3 := by omega
  rw [hfuel]
  set cs1 := (ms.containers.alloc rCompressed).1 with hcs1
  set ms1 : MachineState := { ms with containers := cs1 } with hms1
  have hs63 := registration_step_pc63_immBorrowLoc8_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt ms []
  have hreadR_ms1 : ms1.containers.read (ms.containers.alloc rCompressed).2 = some rCompressed := by
    show cs1.read _ = _
    rw [hcs1]
    exact containerStore_read_alloc_new ms.containers rCompressed
  have hs64 := registration_step_pc64_call_pointDecompress_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt ms1
    (ms.containers.alloc rCompressed).2 rCompressed rhsPt [] hreadR_ms1 horacle
  have hs65 := registration_step_pc65_stLoc18_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt ms1 []
  exact run_succ_succ_succ_ok (registrationModuleEnv o)
    (registrationFramePc63AfterStLoc17 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt)
    (registrationFramePc64AfterImmBorrow8 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt)
    ({ registrationFramePc64AfterImmBorrow8 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt with pc := 65 })
    (registrationFramePc66AfterStLoc18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
    []
    []
    [.immRef (ms.containers.alloc rCompressed).2]
    [rhsPt]
    []
    ms ms1 ms1 ms1
    (fuel - 3) hs63 hs64 hs65

/-! ### PC 66–70 chain (success/true branch): `immBorrowLoc 17` / `immBorrowLoc 18` / `call 15` (`point_equals`) /
`brFalse 71` (fall-through) / `ret`. The boolean is `true`, so `brFalse` does not jump; PC 70 is `ret`,
which terminates with `ExecResult.returned [] ms'`. Five total instructions — four `ok` steps followed by
a terminal `returned` step. -/

theorem registration_run_from_pc66_to_returned_abstractMs
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt : MoveValue)
    (ms : MachineState)
    (horacle : o.pointEquals [lhsPt, rhsPt] = some [.bool true])
    (fuel : Nat) (_hf : 5 ≤ fuel) :
    run (registrationModuleEnv o)
        (registrationFramePc66AfterStLoc18
            (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
            (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa)
            mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
        [] [] ms fuel =
      ExecResult.returned []
        { ms with containers := ((ms.containers.alloc lhsPt).1.alloc rhsPt).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen := registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa
  have hfuel : fuel = ((fuel - 5) + 1) + 4 := by omega
  rw [hfuel]
  set cs1 := (ms.containers.alloc lhsPt).1 with hcs1
  set cs2 := (cs1.alloc rhsPt).1 with hcs2
  set ms1 : MachineState := { ms with containers := cs1 } with hms1
  set ms2 : MachineState := { ms with containers := cs2 } with hms2
  have hs66 := registration_step_pc66_immBorrowLoc17_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt ms []
  have hs67 := registration_step_pc67_immBorrowLoc18_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt ms1
    [.immRef (ms.containers.alloc lhsPt).2]
  have hreadLhs_ms2 : ms2.containers.read (ms.containers.alloc lhsPt).2 = some lhsPt := by
    show cs2.read _ = _
    rw [hcs2]
    rw [containerStore_read_alloc_of_read_some cs1 rhsPt (ms.containers.alloc lhsPt).2 lhsPt]
    show cs1.read _ = _
    rw [hcs1]
    exact containerStore_read_alloc_new ms.containers lhsPt
  have hreadRhs_ms2 : ms2.containers.read (cs1.alloc rhsPt).2 = some rhsPt := by
    show cs2.read _ = _
    rw [hcs2]
    exact containerStore_read_alloc_new cs1 rhsPt
  have hs68 := registration_step_pc68_call_pointEquals_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt ms2
    (ms.containers.alloc lhsPt).2 (cs1.alloc rhsPt).2 lhsPt rhsPt true []
    hreadLhs_ms2 hreadRhs_ms2 horacle
  have hs69 := registration_step_pc69_brFalse_true_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt ms2 []
  have hs70 := registration_step_pc70_ret_generic o chainId sender contract token
    ekBa commitBa respBa mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt ms2 []
  have h4step : run (registrationModuleEnv o)
      (registrationFramePc66AfterStLoc18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
      [] [] ms (((fuel - 5) + 1) + 4) =
    run (registrationModuleEnv o)
      ({ registrationFramePc68AfterImmBorrow18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with pc := 70 })
      [] [] ms2 ((fuel - 5) + 1) :=
    run_succ_succ_succ_succ_ok (registrationModuleEnv o)
      (registrationFramePc66AfterStLoc18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
      (registrationFramePc67AfterImmBorrow17 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
      (registrationFramePc68AfterImmBorrow18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt)
      ({ registrationFramePc68AfterImmBorrow18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with pc := 69 })
      ({ registrationFramePc68AfterImmBorrow18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with pc := 70 })
      []
      []
      [.immRef (ms.containers.alloc lhsPt).2]
      [.immRef (cs1.alloc rhsPt).2, .immRef (ms.containers.alloc lhsPt).2]
      [.bool true]
      []
      ms ms1 ms2 ms2 ms2
      ((fuel - 5) + 1) hs66 hs67 hs68 hs69
  rw [h4step]
  exact run_succ_returned (registrationModuleEnv o)
    ({ registrationFramePc68AfterImmBorrow18 args hlen mv rCompressed sOpt sVal eScalar hPoint ekPt hsPt ekePt lhsPt rhsPt with pc := 70 })
    [] [] ms2 (fuel - 5) [] ms2 hs70

