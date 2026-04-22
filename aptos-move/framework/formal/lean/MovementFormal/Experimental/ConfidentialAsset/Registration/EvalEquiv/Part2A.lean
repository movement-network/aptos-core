import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv.Part1

/-!
This file is **Part2A** (PCs 31–43) of the split `EvalEquiv` proof.
See `Registration.EvalEquiv` and the sibling `Part2B` (PCs 44–54) and `Part2C` (PCs 55–62).
-/


namespace MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.MoveModel.Programs.Registration
open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim
open MovementFormal.Experimental.ConfidentialAsset.Registration.Formal

set_option linter.unusedSimpArgs false

/-! ### PC 31–34: `mutBorrowLoc 11`, `immBorrowLoc 4` (token → ref 7), `call 5`, `call 6`.

For scalability, PC 31–34 are stated generically over an arbitrary input `MachineState`.
This avoids the exponential whnf blow-up that would happen if we directly referred to the
deep MS chain `registrationMsAfterAppendContract` in the theorem signature. The specialised
corollaries (used downstream) are obtained by applying the generic lemma. -/

@[simp] theorem verifyRegistrationProofCode_idx31 :
    verifyRegistrationProofCode[31]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 11 := rfl

-- PC 31 (generic): `mutBorrowLoc 11` reuses existing ref 4, same as PC 23/27.
set_option maxHeartbeats 800000 in
theorem registration_step_pc31_mutBorrowLoc11_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 31 })
        [] [] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 32 })
        [] [.mutRef 4] ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 31 })
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.mutBorrowLoc 11 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx31]
  have hlocLt : 11 < fr'.locals.size :=
    registrationFramePc22_locals_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx11_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefLt : 11 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx11_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

@[simp] theorem verifyRegistrationProofCode_idx32 :
    verifyRegistrationProofCode[32]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .immBorrowLoc 4 := rfl

theorem registrationFramePc22_locals_idx4_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    4 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx4_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    4 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_locals_idx4_eq
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
      (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal).locals[4]'
      (registrationFramePc22_locals_idx4_lt _ _ mv rCompressed sOpt sVal) = some (.address token) := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs]

theorem registrationFramePc22_localRefs_idx4_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[4]'
      (registrationFramePc22_localRefs_idx4_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

-- Frame after PC 32: same base but with pc := 33. `immBorrowLoc` does not update `localRefs`.
def registrationFramePc33AfterImmBorrow4 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) : Frame :=
  { registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal with pc := 33 }

-- PC 32 (generic): `immBorrowLoc 4` — alloc `token` at `ms.store.size`, push `immRef`.
set_option maxHeartbeats 800000 in
theorem registration_step_pc32_immBorrowLoc4_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 32 })
        [] [.mutRef 4] ms =
      ExecResult.ok
        (registrationFramePc33AfterImmBorrow4 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.immRef (ms.containers.alloc (.address token)).2, .mutRef 4]
        { ms with containers := (ms.containers.alloc (.address token)).1 } := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 32 })
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.immBorrowLoc 4 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val,
      verifyRegistrationProofCode_idx32]
  have hlocLt : 4 < fr'.locals.size :=
    registrationFramePc22_locals_idx4_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx4_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefLt : 4 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx4_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx4_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

@[simp] theorem verifyRegistrationProofCode_idx33 :
    verifyRegistrationProofCode[33]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 5 := rfl

-- PC 33 (generic): `call 5` = `bcs::to_bytes<address>`; reads address at `refId`, pushes bytes.
set_option maxHeartbeats 800000 in
theorem registration_step_pc33_call_bcsToBytes_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState) (refId : RefId) (addr : ByteArray)
    (hread : ms.containers.read refId = some (.address addr)) :
    step (registrationModuleEnv o)
        (registrationFramePc33AfterImmBorrow4 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [.immRef refId, .mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc33AfterImmBorrow4 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 34 })
        [] [.vector .u8 (addr.toList.map .u8), .mutRef 4] ms := by
  have hnative : bcsToBytesAddressRef ms.containers [.immRef refId] =
      some ([.vector .u8 (addr.toList.map .u8)], ms.containers) := by
    simp only [bcsToBytesAddressRef]; rw [hread]
  simp only [step, registrationModuleEnv, registrationFramePc33AfterImmBorrow4,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx33,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx5_lt, registrationModuleEnv_functions_at5, FuncDesc.body, bcsToBytesAddressRefDesc,
    takeN_two_one, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

@[simp] theorem verifyRegistrationProofCode_idx34 :
    verifyRegistrationProofCode[34]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 6 := rfl

-- PC 34 (generic): `call 6` = `vector::append<u8>`; appends second arg to vector at ref 4.
set_option maxHeartbeats 800000 in
theorem registration_step_pc34_call_append_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState)
    (existing appended : List MoveValue) (cs' : ContainerStore)
    (hread : ms.containers.read 4 = some (.vector .u8 existing))
    (hwrite : ms.containers.write 4 (.vector .u8 (existing ++ appended)) = some cs') :
    step (registrationModuleEnv o)
        ({ registrationFramePc33AfterImmBorrow4 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 34 })
        [] [.vector .u8 appended, .mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc33AfterImmBorrow4 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 35 })
        [] [] { ms with containers := cs' } := by
  have hnative : vectorAppendU8Ref ms.containers [.mutRef 4, .vector .u8 appended] =
      some ([], cs') := by
    simp only [vectorAppendU8Ref]; rw [hread]; simp only; rw [hwrite]
  simp only [step, registrationModuleEnv, registrationFramePc33AfterImmBorrow4,
    registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
    registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx34,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx6_lt, registrationModuleEnv_functions_at6, FuncDesc.body, vectorAppendU8RefDesc,
    takeN_two_pair, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append,
    List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd,
    Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret0]

/-! ### PC 35–38: second iteration of Fiat–Shamir append for `ek`.
PC 35 `mutBorrowLoc 11`, PC 36 `copyLoc 3` (push `ek` struct),
PC 37 `call 7` `pubkey_to_bytes(&CompressedPubkey) → vector<u8>`,
PC 38 `call 6` `vector::append<u8>(&mut msg, ekBytes)`.
All stated generically over an arbitrary input `MachineState`. -/

@[simp] theorem verifyRegistrationProofCode_idx35 :
    verifyRegistrationProofCode[35]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 11 := rfl

-- PC 35 (generic): `mutBorrowLoc 11` reuses existing ref 4, pc 35→36.
set_option maxHeartbeats 800000 in
theorem registration_step_pc35_mutBorrowLoc11_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 35 })
        [] [] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 36 })
        [] [.mutRef 4] ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 35 })
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.mutBorrowLoc 11 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx35]
  have hlocLt : 11 < fr'.locals.size :=
    registrationFramePc22_locals_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx11_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefLt : 11 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx11_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

@[simp] theorem verifyRegistrationProofCode_idx36 :
    verifyRegistrationProofCode[36]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .copyLoc 3 := rfl

theorem registrationFramePc22_locals_idx3_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    3 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx3_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    3 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_locals_idx3_eq
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
      (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal).locals[3]'
      (registrationFramePc22_locals_idx3_lt _ _ mv rCompressed sOpt sVal) =
        some (.struct_ [.vector .u8 (ekBa.toList.map .u8)]) := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs]

theorem registrationFramePc22_localRefs_idx3_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[3]'
      (registrationFramePc22_localRefs_idx3_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

-- PC 36 (generic): `copyLoc 3` pushes `ek` struct value on stack (no ref tracked at local 3).
set_option maxHeartbeats 800000 in
theorem registration_step_pc36_copyLoc3_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 36 })
        [] [.mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 37 })
        [] [.struct_ [.vector .u8 (ekBa.toList.map .u8)], .mutRef 4] ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 36 })
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.copyLoc 3 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx36]
  have hlocLt : 3 < fr'.locals.size :=
    registrationFramePc22_locals_idx3_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx3_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefLt : 3 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx3_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx3_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

@[simp] theorem verifyRegistrationProofCode_idx37 :
    verifyRegistrationProofCode[37]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 7 := rfl

theorem registration_env_funcIdx7_lt (o : RegistrationNativeOracle) :
    7 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

theorem registrationModuleEnv_functions_at7 (o : RegistrationNativeOracle)
    (h : 7 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[7]'h =
      { numParams := 1, numReturns := 1, body := .nativeRef (wrapOracleImmRef1 o.pubkeyToBytes) } := by
  simp [registrationModuleEnv]

-- PC 37 (generic): `call 7` = `pubkey_to_bytes`; consumes the `ek` struct on stack, pushes `ekBytes`.
-- Specialised to the struct shape produced by `copyLoc 3`, so `derefImm` collapses to identity.
set_option maxHeartbeats 800000 in
theorem registration_step_pc37_call_pubkeyToBytes_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState)
    (ekBytes : MoveValue)
    (horacle : o.pubkeyToBytes [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] = some [ekBytes]) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 37 })
        [] [.struct_ [.vector .u8 (ekBa.toList.map .u8)], .mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 38 })
        [] [ekBytes, .mutRef 4] ms := by
  have hnative : wrapOracleImmRef1 o.pubkeyToBytes ms.containers
        [.struct_ [.vector .u8 (ekBa.toList.map .u8)]] =
      some ([ekBytes], ms.containers) := by
    show (Option.bind (derefImm ms.containers
            (.struct_ [.vector .u8 (ekBa.toList.map .u8)]))
          (fun v => Option.bind (o.pubkeyToBytes [v])
              (fun results => some (results, ms.containers)))) =
        some ([ekBytes], ms.containers)
    simp only [derefImm, Option.bind_some]
    rw [horacle]
    rfl
  simp only [step, registrationModuleEnv, registrationFramePc22AfterMoveLoc0,
    registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx37,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx7_lt, registrationModuleEnv_functions_at7, FuncDesc.body,
    takeN_two_one, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret1]

@[simp] theorem verifyRegistrationProofCode_idx38 :
    verifyRegistrationProofCode[38]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 6 := rfl

-- PC 38 (generic): `call 6` = `vector::append<u8>`; appends `appended` bytes to `existing` at ref 4.
-- Same pattern as PC 34 generic; only pc changes (38→39).
set_option maxHeartbeats 800000 in
theorem registration_step_pc38_call_append_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState)
    (existing appended : List MoveValue) (cs' : ContainerStore)
    (hread : ms.containers.read 4 = some (.vector .u8 existing))
    (hwrite : ms.containers.write 4 (.vector .u8 (existing ++ appended)) = some cs') :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 38 })
        [] [.vector .u8 appended, .mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 39 })
        [] [] { ms with containers := cs' } := by
  have hnative : vectorAppendU8Ref ms.containers [.mutRef 4, .vector .u8 appended] =
      some ([], cs') := by
    simp only [vectorAppendU8Ref]; rw [hread]; simp only; rw [hwrite]
  simp only [step, registrationModuleEnv, registrationFramePc22AfterMoveLoc0,
    registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx38,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx6_lt, registrationModuleEnv_functions_at6, FuncDesc.body, vectorAppendU8RefDesc,
    takeN_two_pair, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append,
    List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd,
    Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret0]

/-! ### PC 39–45: Fiat–Shamir append of `r_compressed`, `moveLoc 11`, SHA2-512 scalar.
- PC 39 `mutBorrowLoc 11`  (≈ PC 35)
- PC 40 `copyLoc 8`        (push `r_compressed` value from local 8)
- PC 41 `call 8`           (`compressed_point_to_bytes`, native oracle)
- PC 42 `call 6`           (`vector::append<u8>`, ≈ PC 38)
- PC 43 `moveLoc 11`       (push `msg` from ref 4, clear local 11 / localRefs[11])
- PC 44 `call 9`           (`new_scalar_from_sha2_512`, native)
- PC 45 `stLoc 12`         (store `e`)
All stated generically over an arbitrary input `MachineState`. -/

/-- Helper for `copyLoc 8`: `locals[8]` at the PC 22 frame equals `some rCompressed`. -/
theorem registrationFramePc22_locals_idx8_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    8 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals.size := by
  rw [registrationFramePc22_locals_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_localRefs_idx8_lt (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    8 < (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs.size := by
  rw [registrationFramePc22_localRefs_size args h mv rCompressed sOpt sVal]; decide

theorem registrationFramePc22_locals_idx8_eq
    (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).locals[8]'
      (registrationFramePc22_locals_idx8_lt args h mv rCompressed sOpt sVal) = some rCompressed := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

theorem registrationFramePc22_localRefs_idx8_eq (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) :
    (registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal).localRefs[8]'
      (registrationFramePc22_localRefs_idx8_lt args h mv rCompressed sOpt sVal) = none := by
  simp [registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9, registrationFramePc12AfterStLoc9,
    registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6, registrationFramePc9AfterStLoc8,
    registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow, registrationFramePc3AfterStLoc,
    registrationFrameAtPc2, registrationInitFrame]

@[simp] theorem verifyRegistrationProofCode_idx40 :
    verifyRegistrationProofCode[40]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .copyLoc 8 := rfl

-- PC 40 (generic): `copyLoc 8` pushes `rCompressed` value from local 8 (no ref tracked).
set_option maxHeartbeats 800000 in
theorem registration_step_pc40_copyLoc8_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 40 })
        [] [.mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 41 })
        [] [rCompressed, .mutRef 4] ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 40 })
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.copyLoc 8 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx40]
  have hlocLt : 8 < fr'.locals.size :=
    registrationFramePc22_locals_idx8_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx8_eq args hlen mv rCompressed sOpt sVal
  have hlocRefLt : 8 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx8_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx8_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

@[simp] theorem verifyRegistrationProofCode_idx41 :
    verifyRegistrationProofCode[41]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 8 := rfl

theorem registration_env_funcIdx8_lt (o : RegistrationNativeOracle) :
    8 < (registrationModuleEnv o).functions.size := by
  rw [registration_module_env_size o]; decide

theorem registrationModuleEnv_functions_at8 (o : RegistrationNativeOracle)
    (h : 8 < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[8]'h =
      { numParams := 1, numReturns := 1, body := .native o.compressedPointToBytes } := by
  simp [registrationModuleEnv]

-- PC 41 (generic): `call 8` = `compressed_point_to_bytes` (native); consumes `rCompressed`, pushes `rcBytes`.
set_option maxHeartbeats 800000 in
theorem registration_step_pc41_call_compressedPointToBytes_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState)
    (rcBytes : MoveValue)
    (horacle : o.compressedPointToBytes [rCompressed] = some [rcBytes]) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 41 })
        [] [rCompressed, .mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 42 })
        [] [rcBytes, .mutRef 4] ms := by
  simp only [step, registrationModuleEnv, registrationFramePc22AfterMoveLoc0,
    registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx41,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx8_lt, registrationModuleEnv_functions_at8, FuncDesc.body,
    takeN_two_one, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate,
    List.cons_append, List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add,
    Nat.reduceAdd, Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [horacle]
  simp only [handleNativeResult_ret1]

/-! ### PC 39, 42: more occurrences of `mutBorrowLoc 11` / `call 6` (append).
Same patterns as PC 35 / PC 38, with PC labels shifted by 4. -/

@[simp] theorem verifyRegistrationProofCode_idx39 :
    verifyRegistrationProofCode[39]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .mutBorrowLoc 11 := rfl

-- PC 39 (generic): `mutBorrowLoc 11` — reuses existing ref 4, pc 39→40.
set_option maxHeartbeats 800000 in
theorem registration_step_pc39_mutBorrowLoc11_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 39 })
        [] [] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 40 })
        [] [.mutRef 4] ms := by
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  let fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 39 })
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.mutBorrowLoc 11 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx39]
  have hlocLt : 11 < fr'.locals.size :=
    registrationFramePc22_locals_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocVal := registrationFramePc22_locals_idx11_eq chainId sender contract token ekBa commitBa respBa
    mv rCompressed sOpt sVal
  have hlocRefLt : 11 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal := registrationFramePc22_localRefs_idx11_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rfl

@[simp] theorem verifyRegistrationProofCode_idx42 :
    verifyRegistrationProofCode[42]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .call 6 := rfl

-- PC 42 (generic): `call 6` = `vector::append<u8>`; same pattern as PC 34/38, pc 42→43.
set_option maxHeartbeats 800000 in
theorem registration_step_pc42_call_append_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState)
    (existing appended : List MoveValue) (cs' : ContainerStore)
    (hread : ms.containers.read 4 = some (.vector .u8 existing))
    (hwrite : ms.containers.write 4 (.vector .u8 (existing ++ appended)) = some cs') :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 42 })
        [] [.vector .u8 appended, .mutRef 4] ms =
      ExecResult.ok
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 43 })
        [] [] { ms with containers := cs' } := by
  have hnative : vectorAppendU8Ref ms.containers [.mutRef 4, .vector .u8 appended] =
      some ([], cs') := by
    simp only [vectorAppendU8Ref]; rw [hread]; simp only; rw [hwrite]
  simp only [step, registrationModuleEnv, registrationFramePc22AfterMoveLoc0,
    registrationFramePc21AfterMutBorrowMsg, registrationFramePc20AfterStLoc11,
    registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
    registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
    registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
    registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame, registrationVerifyArgs,
    verifyRegistrationProofCode, verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx42,
    registrationInitFrame_idx5_lt, registration_locals_after_set5_idx7_lt, registrationVerifyArgs_len,
    registration_env_funcIdx6_lt, registrationModuleEnv_functions_at6, FuncDesc.body, vectorAppendU8RefDesc,
    takeN_two_pair, List.map_cons, List.map_nil, Nat.reduceSub, List.reduceReplicate, List.cons_append,
    List.nil_append, List.size_toArray, List.length_cons, List.length_nil, zero_add, Nat.reduceAdd,
    Nat.reduceLT, Nat.one_lt_ofNat, ↓reduceDIte, List.getElem_toArray, List.getElem_cons_succ,
    List.getElem_cons_zero, Nat.ofNat_pos, Nat.reduceBEq, Bool.false_eq_true, BEq.rfl, List.set_toArray,
    List.set_cons_succ, List.set_cons_zero, beq_iff_eq]
  rw [hnative]
  simp only [handleNativeResult_ret0]

@[simp] theorem verifyRegistrationProofCode_idx43 :
    verifyRegistrationProofCode[43]'(by rw [verifyRegistrationProofCode_size_val]; decide) = .moveLoc 11 := rfl

/-- Frame after `moveLoc 11` (PC 43): local 11 and localRef 11 cleared, pc := 44.
The stack holds the current container value at ref 4 (the accumulated FS message). -/
def registrationFramePc44AfterMoveLoc11 (args : List MoveValue) (h : args.length = 7)
    (mv rCompressed sOpt sVal : MoveValue) : Frame :=
  let fr := registrationFramePc22AfterMoveLoc0 args h mv rCompressed sOpt sVal
  { fr with
      pc := 44,
      locals := fr.locals.set 11 none (registrationFramePc22_locals_idx11_lt args h mv rCompressed sOpt sVal)
      localRefs := fr.localRefs.set 11 none (registrationFramePc22_localRefs_idx11_lt args h mv rCompressed sOpt sVal) }

-- PC 43 (generic): `moveLoc 11` consumes `msg`:
--   * `locals[11] = some _` (initial DST vector — ignored; the pushed value comes from `containers.read 4`)
--   * `localRefs[11] = some 4` (ref was allocated by PC 20 `mutBorrowLoc 11`)
-- Result: clears `locals[11]` and `localRefs[11]`, pushes the **current** container value at ref 4
-- (i.e. the accumulated message `DST ++ [chainId] ++ senderBytes ++ contractBytes ++ tokenBytes ++ ekBytes ++ rcBytes`),
-- pc 43→44.
set_option maxHeartbeats 800000 in
theorem registration_step_pc43_moveLoc11_generic (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (mv rCompressed sOpt sVal : MoveValue) (ms : MachineState)
    (msgVal : MoveValue)
    (hread : ms.containers.read 4 = some msgVal) :
    step (registrationModuleEnv o)
        ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 43 })
        [] [] ms =
      ExecResult.ok
        (registrationFramePc44AfterMoveLoc11 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
          (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal)
        [] [msgVal] ms := by
  show step (registrationModuleEnv o)
      ({ registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
              (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal with
            pc := 43 })
      [] [] ms =
    ExecResult.ok
      (let fr := registrationFramePc22AfterMoveLoc0 (registrationVerifyArgs chainId sender contract token ekBa commitBa respBa)
                   (registrationVerifyArgs_len chainId sender contract token ekBa commitBa respBa) mv rCompressed sOpt sVal
       { fr with
           pc := 44
           locals := fr.locals.set 11 none
             (registrationFramePc22_locals_idx11_lt _ _ mv rCompressed sOpt sVal)
           localRefs := fr.localRefs.set 11 none
             (registrationFramePc22_localRefs_idx11_lt _ _ mv rCompressed sOpt sVal) })
      [] [msgVal] ms
  let args := registrationVerifyArgs chainId sender contract token ekBa commitBa respBa
  let hlen : args.length = 7 := registrationVerifyArgs_len _ _ _ _ _ _ _
  set fr' := ({ registrationFramePc22AfterMoveLoc0 args hlen mv rCompressed sOpt sVal with pc := 43 }) with hfr'
  have hpc : fr'.pc < fr'.code.size := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val]
  have hc : fr'.code[fr'.pc]'hpc = MoveInstr.moveLoc 11 := by
    simp [fr', registrationFramePc22AfterMoveLoc0, registrationFramePc21AfterMutBorrowMsg,
      registrationFramePc20AfterStLoc11, registrationFramePc18AfterStLoc10, registrationFramePc16AfterMutBorrow9,
      registrationFramePc12AfterStLoc9, registrationFramePc11AfterCall3, registrationFramePc10AfterMoveLoc6,
      registrationFramePc9AfterStLoc8, registrationFramePc7AfterMutBorrowLoc7, registrationFramePc4AfterImmBorrow,
      registrationFramePc3AfterStLoc, registrationFrameAtPc2, registrationInitFrame,
      verifyRegistrationProofCode_size_val, verifyRegistrationProofCode_idx43]
  have hlocLt : 11 < fr'.locals.size :=
    registrationFramePc22_locals_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocVal : fr'.locals[11]'hlocLt = some fiatShamirRegistrationDstValue :=
    registrationFramePc22_locals_idx11_eq chainId sender contract token ekBa commitBa respBa
      mv rCompressed sOpt sVal
  have hlocRefLt : 11 < fr'.localRefs.size :=
    registrationFramePc22_localRefs_idx11_lt args hlen mv rCompressed sOpt sVal
  have hlocRefVal : fr'.localRefs[11]'hlocRefLt = some 4 :=
    registrationFramePc22_localRefs_idx11_eq args hlen mv rCompressed sOpt sVal
  simp only [step, dif_pos hpc, hc, dif_pos hlocLt, hlocVal, dif_pos hlocRefLt, hlocRefVal]
  rw [hread]

