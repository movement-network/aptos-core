import MovementFormal.MoveModel.Programs.Transfer
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Structs
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.ExecResultDropMs

/-!
# Bytecode eval ≡ functional simulation for `verify_transfer_proof` — Phase 4

Proves that the `verify_transfer_proof` bytecode (24 instructions dispatching to
`verify_transfer_sigma_proof` + `verify_new_balance_range_proof` +
`verify_transfer_amount_range_proof`) evaluates to the functional simulation result
under the module oracle.

Transfer is the most complex dispatcher: 13 params, 3 sub-calls, and 3 `ImmBorrowField`
instructions extracting `sigma_proof`, `zkrp_new_balance`, and `zkrp_transfer_amount`
from the `TransferProof` struct.

Architecture follows `Registration/EvalEquivRebuild.lean` and Withdrawal/EvalEquiv.lean.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Transfer

def transferArgs (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef senderAmtRef recipientAmtRef
     auditorEksRef auditorAmtsRef senderAuditorHintRef proofRef : MoveValue) : List MoveValue :=
  [.u8 chainId, .address sender, .address contract,
   senderEkRef, recipientEkRef, curBalRef, newBalRef, senderAmtRef, recipientAmtRef,
   auditorEksRef, auditorAmtsRef, senderAuditorHintRef, proofRef]

/-! ## Module environment simp lemmas -/

@[simp] theorem transferModuleEnv_functions_size (o : TransferModuleOracle) :
    (transferModuleEnv o).functions.size = 4 := by
  unfold transferModuleEnv; rfl

@[simp] theorem transferModuleEnv_fn0_numParams (o : TransferModuleOracle) :
    (transferModuleEnv o).functions[0].numParams = 13 := by
  unfold transferModuleEnv; rfl

@[simp] theorem transferModuleEnv_fn0_numReturns (o : TransferModuleOracle) :
    (transferModuleEnv o).functions[0].numReturns = 0 := by
  unfold transferModuleEnv; rfl

@[simp] theorem transferModuleEnv_fn0_body (o : TransferModuleOracle) :
    (transferModuleEnv o).functions[0].body = .nativeRef o.verifySigmaProof := by
  unfold transferModuleEnv; rfl

@[simp] theorem transferModuleEnv_fn1_numParams (o : TransferModuleOracle) :
    (transferModuleEnv o).functions[1].numParams = 2 := by
  unfold transferModuleEnv; rfl

@[simp] theorem transferModuleEnv_fn1_numReturns (o : TransferModuleOracle) :
    (transferModuleEnv o).functions[1].numReturns = 0 := by
  unfold transferModuleEnv; rfl

@[simp] theorem transferModuleEnv_fn1_body (o : TransferModuleOracle) :
    (transferModuleEnv o).functions[1].body = .nativeRef o.verifyNewBalanceRangeProof := by
  unfold transferModuleEnv; rfl

@[simp] theorem transferModuleEnv_fn2_numParams (o : TransferModuleOracle) :
    (transferModuleEnv o).functions[2].numParams = 2 := by
  unfold transferModuleEnv; rfl

@[simp] theorem transferModuleEnv_fn2_numReturns (o : TransferModuleOracle) :
    (transferModuleEnv o).functions[2].numReturns = 0 := by
  unfold transferModuleEnv; rfl

@[simp] theorem transferModuleEnv_fn2_body (o : TransferModuleOracle) :
    (transferModuleEnv o).functions[2].body = .nativeRef o.verifyTransferAmountRangeProof := by
  unfold transferModuleEnv; rfl

@[simp] theorem transferModuleEnv_fn3_numParams (o : TransferModuleOracle) :
    (transferModuleEnv o).functions[3].numParams = 13 := by
  unfold transferModuleEnv verifyTransferProofDesc; rfl

@[simp] theorem transferModuleEnv_fn3_body (o : TransferModuleOracle) :
    (transferModuleEnv o).functions[3].body = .bytecode verifyTransferProofCode 13 := by
  unfold transferModuleEnv verifyTransferProofDesc; rfl

/-! ## Bytecode access lemmas -/

private theorem tr_code_pc0  : verifyTransferProofCode[0]'(by decide)  = .moveLoc 0  := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc1  : verifyTransferProofCode[1]'(by decide)  = .moveLoc 1  := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc2  : verifyTransferProofCode[2]'(by decide)  = .moveLoc 2  := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc3  : verifyTransferProofCode[3]'(by decide)  = .moveLoc 3  := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc4  : verifyTransferProofCode[4]'(by decide)  = .moveLoc 4  := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc5  : verifyTransferProofCode[5]'(by decide)  = .moveLoc 5  := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc6  : verifyTransferProofCode[6]'(by decide)  = .copyLoc 6  := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc7  : verifyTransferProofCode[7]'(by decide)  = .moveLoc 7  := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc8  : verifyTransferProofCode[8]'(by decide)  = .copyLoc 8  := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc9  : verifyTransferProofCode[9]'(by decide)  = .moveLoc 9  := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc10 : verifyTransferProofCode[10]'(by decide) = .moveLoc 10 := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc11 : verifyTransferProofCode[11]'(by decide) = .moveLoc 11 := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc12 : verifyTransferProofCode[12]'(by decide) = .copyLoc 12 := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc13 : verifyTransferProofCode[13]'(by decide) = .immBorrowField 0 := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc14 : verifyTransferProofCode[14]'(by decide) = .call 0     := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc15 : verifyTransferProofCode[15]'(by decide) = .moveLoc 6  := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc16 : verifyTransferProofCode[16]'(by decide) = .copyLoc 12 := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc17 : verifyTransferProofCode[17]'(by decide) = .immBorrowField 1 := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc18 : verifyTransferProofCode[18]'(by decide) = .call 1     := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc19 : verifyTransferProofCode[19]'(by decide) = .moveLoc 8  := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc20 : verifyTransferProofCode[20]'(by decide) = .moveLoc 12 := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc21 : verifyTransferProofCode[21]'(by decide) = .immBorrowField 2 := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc22 : verifyTransferProofCode[22]'(by decide) = .call 2     := by unfold verifyTransferProofCode; rfl
private theorem tr_code_pc23 : verifyTransferProofCode[23]'(by decide) = .ret        := by unfold verifyTransferProofCode; rfl

/-! ## `eval` → `run` entry-point unfolding -/

theorem eval_transfer_eq_run (o : TransferModuleOracle)
    (args : List MoveValue) (fuel : Nat) (initMs : MachineState) :
    eval (transferModuleEnv o) verifyTransferProofIdx args fuel initMs =
      run (transferModuleEnv o)
        { code := verifyTransferProofCode,
          pc := 0,
          locals := (args.map some).toArray,
          localRefs := (List.replicate 13 none).toArray }
        [] [] initMs fuel := by
  unfold eval verifyTransferProofIdx
  simp only [transferModuleEnv_functions_size, show (3 : Nat) < 4 from by decide, dif_pos,
             transferModuleEnv_fn3_body, transferModuleEnv_fn3_numParams]
  simp [List.replicate]

/-! ## Per-PC step theorems — moveLoc PCs 0–5 -/

theorem step_transfer_pc0 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 0)
    (v : MoveValue) (hlt : 0 < frame.locals.size) (hv : frame.locals[0]'hlt = some v)
    (hRefNone : ¬ 0 < frame.localRefs.size ∨ ∃ h : 0 < frame.localRefs.size, frame.localRefs[0]'h = none) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 1, locals := frame.locals.set 0 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 0 := by simp only [hcode, hpc]; exact tr_code_pc0
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := transferModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    0 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 1 from by omega] at h; exact h

theorem step_transfer_pc1 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 1)
    (v : MoveValue) (hlt : 1 < frame.locals.size) (hv : frame.locals[1]'hlt = some v)
    (hRefNone : ¬ 1 < frame.localRefs.size ∨ ∃ h : 1 < frame.localRefs.size, frame.localRefs[1]'h = none) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 2, locals := frame.locals.set 1 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 1 := by simp only [hcode, hpc]; exact tr_code_pc1
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := transferModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    1 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 2 from by omega] at h; exact h

theorem step_transfer_pc2 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 2)
    (v : MoveValue) (hlt : 2 < frame.locals.size) (hv : frame.locals[2]'hlt = some v)
    (hRefNone : ¬ 2 < frame.localRefs.size ∨ ∃ h : 2 < frame.localRefs.size, frame.localRefs[2]'h = none) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 3, locals := frame.locals.set 2 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 2 := by simp only [hcode, hpc]; exact tr_code_pc2
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := transferModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    2 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 3 from by omega] at h; exact h

theorem step_transfer_pc3 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 3)
    (v : MoveValue) (hlt : 3 < frame.locals.size) (hv : frame.locals[3]'hlt = some v)
    (hRefNone : ¬ 3 < frame.localRefs.size ∨ ∃ h : 3 < frame.localRefs.size, frame.localRefs[3]'h = none) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 4, locals := frame.locals.set 3 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 3 := by simp only [hcode, hpc]; exact tr_code_pc3
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := transferModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    3 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 4 from by omega] at h; exact h

theorem step_transfer_pc4 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 4)
    (v : MoveValue) (hlt : 4 < frame.locals.size) (hv : frame.locals[4]'hlt = some v)
    (hRefNone : ¬ 4 < frame.localRefs.size ∨ ∃ h : 4 < frame.localRefs.size, frame.localRefs[4]'h = none) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 5, locals := frame.locals.set 4 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 4 := by simp only [hcode, hpc]; exact tr_code_pc4
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := transferModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    4 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 5 from by omega] at h; exact h

theorem step_transfer_pc5 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 5)
    (v : MoveValue) (hlt : 5 < frame.locals.size) (hv : frame.locals[5]'hlt = some v)
    (hRefNone : ¬ 5 < frame.localRefs.size ∨ ∃ h : 5 < frame.localRefs.size, frame.localRefs[5]'h = none) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 6, locals := frame.locals.set 5 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 5 := by simp only [hcode, hpc]; exact tr_code_pc5
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := transferModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    5 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 6 from by omega] at h; exact h

/-! ## PC 6 — copyLoc 6 (new_balance, first copy) -/

theorem step_transfer_pc6 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 6)
    (v : MoveValue) (hlt : 6 < frame.locals.size) (hv : frame.locals[6]'hlt = some v)
    (hRefNone : ¬ 6 < frame.localRefs.size ∨ ∃ h : 6 < frame.localRefs.size, frame.localRefs[6]'h = none) :
    step (transferModuleEnv o) frame cs stack ms = .ok { frame with pc := 7 } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 6 := by simp only [hcode, hpc]; exact tr_code_pc6
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := transferModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    6 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 7 from by omega] at h; exact h

/-! ## PC 7 — moveLoc 7 (sender_amount) -/

theorem step_transfer_pc7 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 7)
    (v : MoveValue) (hlt : 7 < frame.locals.size) (hv : frame.locals[7]'hlt = some v)
    (hRefNone : ¬ 7 < frame.localRefs.size ∨ ∃ h : 7 < frame.localRefs.size, frame.localRefs[7]'h = none) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 8, locals := frame.locals.set 7 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 7 := by simp only [hcode, hpc]; exact tr_code_pc7
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := transferModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    7 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 8 from by omega] at h; exact h

/-! ## PC 8 — copyLoc 8 (recipient_amount, first copy) -/

theorem step_transfer_pc8 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 8)
    (v : MoveValue) (hlt : 8 < frame.locals.size) (hv : frame.locals[8]'hlt = some v)
    (hRefNone : ¬ 8 < frame.localRefs.size ∨ ∃ h : 8 < frame.localRefs.size, frame.localRefs[8]'h = none) :
    step (transferModuleEnv o) frame cs stack ms = .ok { frame with pc := 9 } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 8 := by simp only [hcode, hpc]; exact tr_code_pc8
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := transferModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    8 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 9 from by omega] at h; exact h

/-! ## moveLoc PCs 9–11 (auditor_eks, auditor_amounts, sender_auditor_hint) -/

theorem step_transfer_pc9 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 9)
    (v : MoveValue) (hlt : 9 < frame.locals.size) (hv : frame.locals[9]'hlt = some v)
    (hRefNone : ¬ 9 < frame.localRefs.size ∨ ∃ h : 9 < frame.localRefs.size, frame.localRefs[9]'h = none) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 10, locals := frame.locals.set 9 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 9 := by simp only [hcode, hpc]; exact tr_code_pc9
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := transferModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    9 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 10 from by omega] at h; exact h

theorem step_transfer_pc10 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 10)
    (v : MoveValue) (hlt : 10 < frame.locals.size) (hv : frame.locals[10]'hlt = some v)
    (hRefNone : ¬ 10 < frame.localRefs.size ∨ ∃ h : 10 < frame.localRefs.size, frame.localRefs[10]'h = none) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 11, locals := frame.locals.set 10 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 10 := by simp only [hcode, hpc]; exact tr_code_pc10
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := transferModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    10 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 11 from by omega] at h; exact h

theorem step_transfer_pc11 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 11)
    (v : MoveValue) (hlt : 11 < frame.locals.size) (hv : frame.locals[11]'hlt = some v)
    (hRefNone : ¬ 11 < frame.localRefs.size ∨ ∃ h : 11 < frame.localRefs.size, frame.localRefs[11]'h = none) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 12, locals := frame.locals.set 11 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 11 := by simp only [hcode, hpc]; exact tr_code_pc11
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := transferModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    11 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 12 from by omega] at h; exact h

/-! ## PC 12 — copyLoc 12 (proof, first copy) -/

theorem step_transfer_pc12 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 12)
    (v : MoveValue) (hlt : 12 < frame.locals.size) (hv : frame.locals[12]'hlt = some v)
    (hRefNone : ¬ 12 < frame.localRefs.size ∨ ∃ h : 12 < frame.localRefs.size, frame.localRefs[12]'h = none) :
    step (transferModuleEnv o) frame cs stack ms = .ok { frame with pc := 13 } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 12 := by simp only [hcode, hpc]; exact tr_code_pc12
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := transferModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    12 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 13 from by omega] at h; exact h

/-! ## PC 13 — immBorrowField 0 (proof.sigma_proof) -/

theorem step_transfer_pc13 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 13)
    (rid : RefId) (proofFields : List MoveValue) (containers' : ContainerStore) (fid : RefId)
    (ref : MoveValue)
    (hRef : getRefId ref = some rid)
    (hread : ms.containers.read rid = some (.struct_ proofFields))
    (hlt : 0 < proofFields.length)
    (halloc : ms.containers.alloc (proofFields[0]'hlt) = (containers', fid)) :
    step (transferModuleEnv o) frame cs (ref :: rest) ms =
      .ok { frame with pc := 14 } cs (.immRef fid :: rest) { ms with containers := containers' } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowField 0 := by simp only [hcode, hpc]; exact tr_code_pc13
  simp only [step, dif_pos hpc_lt, hc, hRef, hread, dif_pos hlt, halloc]
  rw [show frame.pc + 1 = 14 from by omega]

/-! ## PC 14 — call 0 (verifySigmaProof, 13 args, 0 returns) -/

theorem step_transfer_pc14 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 14)
    (args rest : List MoveValue) (containers' : ContainerStore)
    (htake : takeN stack 13 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = some ([], containers')) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 15 } cs rest { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; exact tr_code_pc14
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (transferModuleEnv o).functions.size by simp)]
  simp only [transferModuleEnv_fn0_numParams, htake, transferModuleEnv_fn0_body, himpl]
  unfold handleNativeResult
  simp only [transferModuleEnv_fn0_numReturns, beq_self_eq_true, ↓reduceIte]
  rw [show frame.pc + 1 = 15 from by omega]

theorem step_transfer_pc14_none (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 14)
    (args rest : List MoveValue)
    (htake : takeN stack 13 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = none) :
    step (transferModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; exact tr_code_pc14
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (transferModuleEnv o).functions.size by simp)]
  simp only [transferModuleEnv_fn0_numParams, htake, transferModuleEnv_fn0_body, himpl]

/-! ## PC 15 — moveLoc 6 (new_balance, consumed) -/

theorem step_transfer_pc15 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 15)
    (v : MoveValue) (hlt : 6 < frame.locals.size) (hv : frame.locals[6]'hlt = some v)
    (hRefNone : ¬ 6 < frame.localRefs.size ∨ ∃ h : 6 < frame.localRefs.size, frame.localRefs[6]'h = none) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 16, locals := frame.locals.set 6 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 6 := by simp only [hcode, hpc]; exact tr_code_pc15
  simp only [step, dif_pos hpc_lt, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]; rw [show frame.pc + 1 = 16 from by omega]
  · simp only [dif_pos hSz, hNone]; rw [show frame.pc + 1 = 16 from by omega]

/-! ## PC 16 — copyLoc 12 (proof, second copy) -/

theorem step_transfer_pc16 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 16)
    (v : MoveValue) (hlt : 12 < frame.locals.size) (hv : frame.locals[12]'hlt = some v)
    (hRefNone : ¬ 12 < frame.localRefs.size ∨ ∃ h : 12 < frame.localRefs.size, frame.localRefs[12]'h = none) :
    step (transferModuleEnv o) frame cs stack ms = .ok { frame with pc := 17 } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 12 := by simp only [hcode, hpc]; exact tr_code_pc16
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := transferModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    12 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 17 from by omega] at h; exact h

/-! ## PC 17 — immBorrowField 1 (proof.zkrp_new_balance) -/

theorem step_transfer_pc17 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 17)
    (rid : RefId) (proofFields : List MoveValue) (containers' : ContainerStore) (fid : RefId)
    (ref : MoveValue)
    (hRef : getRefId ref = some rid)
    (hread : ms.containers.read rid = some (.struct_ proofFields))
    (hlt : 1 < proofFields.length)
    (halloc : ms.containers.alloc (proofFields[1]'hlt) = (containers', fid)) :
    step (transferModuleEnv o) frame cs (ref :: rest) ms =
      .ok { frame with pc := 18 } cs (.immRef fid :: rest) { ms with containers := containers' } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowField 1 := by simp only [hcode, hpc]; exact tr_code_pc17
  simp only [step, dif_pos hpc_lt, hc, hRef, hread, dif_pos hlt, halloc]
  rw [show frame.pc + 1 = 18 from by omega]

/-! ## PC 18 — call 1 (verifyNewBalanceRangeProof, 2 args, 0 returns) -/

theorem step_transfer_pc18 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 18)
    (args rest : List MoveValue) (containers' : ContainerStore)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyNewBalanceRangeProof ms.containers args = some ([], containers')) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 19 } cs rest { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; exact tr_code_pc18
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (transferModuleEnv o).functions.size by simp)]
  simp only [transferModuleEnv_fn1_numParams, htake, transferModuleEnv_fn1_body, himpl]
  unfold handleNativeResult
  simp only [transferModuleEnv_fn1_numReturns, beq_self_eq_true, ↓reduceIte]
  rw [show frame.pc + 1 = 19 from by omega]

theorem step_transfer_pc18_none (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 18)
    (args rest : List MoveValue)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyNewBalanceRangeProof ms.containers args = none) :
    step (transferModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; exact tr_code_pc18
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (transferModuleEnv o).functions.size by simp)]
  simp only [transferModuleEnv_fn1_numParams, htake, transferModuleEnv_fn1_body, himpl]

/-! ## PC 19 — moveLoc 8 (recipient_amount, consumed) -/

theorem step_transfer_pc19 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 19)
    (v : MoveValue) (hlt : 8 < frame.locals.size) (hv : frame.locals[8]'hlt = some v)
    (hRefNone : ¬ 8 < frame.localRefs.size ∨ ∃ h : 8 < frame.localRefs.size, frame.localRefs[8]'h = none) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 20, locals := frame.locals.set 8 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 8 := by simp only [hcode, hpc]; exact tr_code_pc19
  simp only [step, dif_pos hpc_lt, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]; rw [show frame.pc + 1 = 20 from by omega]
  · simp only [dif_pos hSz, hNone]; rw [show frame.pc + 1 = 20 from by omega]

/-! ## PC 20 — moveLoc 12 (proof, consumed) -/

theorem step_transfer_pc20 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 20)
    (v : MoveValue) (hlt : 12 < frame.locals.size) (hv : frame.locals[12]'hlt = some v)
    (hRefNone : ¬ 12 < frame.localRefs.size ∨ ∃ h : 12 < frame.localRefs.size, frame.localRefs[12]'h = none) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 21, locals := frame.locals.set 12 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 12 := by simp only [hcode, hpc]; exact tr_code_pc20
  simp only [step, dif_pos hpc_lt, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]; rw [show frame.pc + 1 = 21 from by omega]
  · simp only [dif_pos hSz, hNone]; rw [show frame.pc + 1 = 21 from by omega]

/-! ## PC 21 — immBorrowField 2 (proof.zkrp_transfer_amount) -/

theorem step_transfer_pc21 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 21)
    (rid : RefId) (proofFields : List MoveValue) (containers' : ContainerStore) (fid : RefId)
    (ref : MoveValue)
    (hRef : getRefId ref = some rid)
    (hread : ms.containers.read rid = some (.struct_ proofFields))
    (hlt : 2 < proofFields.length)
    (halloc : ms.containers.alloc (proofFields[2]'hlt) = (containers', fid)) :
    step (transferModuleEnv o) frame cs (ref :: rest) ms =
      .ok { frame with pc := 22 } cs (.immRef fid :: rest) { ms with containers := containers' } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowField 2 := by simp only [hcode, hpc]; exact tr_code_pc21
  simp only [step, dif_pos hpc_lt, hc, hRef, hread, dif_pos hlt, halloc]
  rw [show frame.pc + 1 = 22 from by omega]

/-! ## PC 22 — call 2 (verifyTransferAmountRangeProof, 2 args, 0 returns) -/

theorem step_transfer_pc22 (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 22)
    (args rest : List MoveValue) (containers' : ContainerStore)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyTransferAmountRangeProof ms.containers args = some ([], containers')) :
    step (transferModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 23 } cs rest { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 2 := by simp only [hcode, hpc]; exact tr_code_pc22
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 2 < (transferModuleEnv o).functions.size by simp)]
  simp only [transferModuleEnv_fn2_numParams, htake, transferModuleEnv_fn2_body, himpl]
  unfold handleNativeResult
  simp only [transferModuleEnv_fn2_numReturns, beq_self_eq_true, ↓reduceIte]
  rw [show frame.pc + 1 = 23 from by omega]

theorem step_transfer_pc22_none (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 22)
    (args rest : List MoveValue)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyTransferAmountRangeProof ms.containers args = none) :
    step (transferModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 2 := by simp only [hcode, hpc]; exact tr_code_pc22
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 2 < (transferModuleEnv o).functions.size by simp)]
  simp only [transferModuleEnv_fn2_numParams, htake, transferModuleEnv_fn2_body, himpl]

/-! ## PC 23 — ret -/

theorem step_transfer_pc23 (o : TransferModuleOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 23) :
    step (transferModuleEnv o) frame [] stack ms = .returned stack ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .ret := by simp only [hcode, hpc]; exact tr_code_pc23
  exact StepLemmas.step_ret_top hpc_lt hc

/-! ## Functional simulation — Phase 6

The functional simulation captures the high-level behavior of `verify_transfer_proof`:
wires chain_id, sender, contract, sender_ek, recipient_ek, current_balance, new_balance,
sender_amount, recipient_amount, auditor_eks, auditor_amounts, sender_auditor_hint,
and the proof's sigma_proof field (via ImmBorrowField) to the sigma verifier, then
dispatches two range proofs: new_balance range proof and transfer_amount range proof.

Transfer is the most complex verifier with 13 params and 3 sub-calls.

The result is `.returned [] ms_final` on success (all three sub-calls return `some`) or
`.error` if any sub-call fails. -/

inductive TransferBytecodeResult where
  | returned (ms : MachineState)
  | error

def verifyTransferBytecodeResult
    (o : TransferModuleOracle) (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef : MoveValue)
    (_proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 2 < proofFields.length) : TransferBytecodeResult :=
  let (cs1, sigmaFid) := initMs.containers.alloc (proofFields[0]'(by omega))
  let sigmaArgs := [.u8 chainId, .address sender, .address contract,
                    senderEkRef, recipientEkRef, curBalRef, newBalRef,
                    senderAmountRef, recipientAmountRef,
                    auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                    .immRef sigmaFid]
  match o.verifySigmaProof cs1 sigmaArgs with
  | none => .error
  | some ([], cs2) =>
    let (cs3, zkrpNewBalFid) := cs2.alloc (proofFields[1]'(by omega))
    let newBalRangeArgs := [newBalRef, .immRef zkrpNewBalFid]
    match o.verifyNewBalanceRangeProof cs3 newBalRangeArgs with
    | none => .error
    | some ([], cs4) =>
      let (cs5, zkrpTransferFid) := cs4.alloc (proofFields[2]'hFieldCount)
      let transferRangeArgs := [recipientAmountRef, .immRef zkrpTransferFid]
      match o.verifyTransferAmountRangeProof cs5 transferRangeArgs with
      | none => .error
      | some ([], cs6) => .returned { initMs with containers := cs6, globals := initMs.globals }
      | some (_ :: _, _) => .error
    | some (_ :: _, _) => .error
  | some (_ :: _, _) => .error

/-! ## Functional simulation shape lemmas -/

/-- Functional simulation shape lemma: sigma failure → .error -/
theorem verifyTransferBytecodeResult_sigmaFails
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 2 < proofFields.length)
    (hsigmaFail : ∀ cs args, o.verifySigmaProof cs args = none) :
    verifyTransferBytecodeResult o chainId sender contract
        senderEkRef recipientEkRef curBalRef newBalRef
        senderAmountRef recipientAmountRef
        auditorEksRef auditorAmountsRef senderAuditorHintRef
        proofRid proofFields initMs hFieldCount =
    .error := by
  unfold verifyTransferBytecodeResult
  simp [hsigmaFail]

/-- Functional simulation shape lemma: new balance range failure → .error -/
theorem verifyTransferBytecodeResult_newBalanceRangeFails
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 2 < proofFields.length)
    (sigmaCs : ContainerStore)
    (hsigmaOk : o.verifySigmaProof (initMs.containers.alloc (proofFields[0]'(by omega))).1
                    [.u8 chainId, .address sender, .address contract,
                     senderEkRef, recipientEkRef, curBalRef, newBalRef,
                     senderAmountRef, recipientAmountRef,
                     auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                     .immRef (initMs.containers.alloc (proofFields[0]'(by omega))).2] =
                 some ([], sigmaCs))
    (hNewBalRangeFail : ∀ cs args, o.verifyNewBalanceRangeProof cs args = none) :
    verifyTransferBytecodeResult o chainId sender contract
        senderEkRef recipientEkRef curBalRef newBalRef
        senderAmountRef recipientAmountRef
        auditorEksRef auditorAmountsRef senderAuditorHintRef
        proofRid proofFields initMs hFieldCount =
    .error := by
  unfold verifyTransferBytecodeResult
  simp only [hsigmaOk, hNewBalRangeFail]

/-- Functional simulation shape lemma: transfer amount range failure → .error -/
theorem verifyTransferBytecodeResult_transferAmountRangeFails
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 2 < proofFields.length)
    (sigmaCs newBalRangeCs : ContainerStore)
    (hsigmaOk : o.verifySigmaProof (initMs.containers.alloc (proofFields[0]'(by omega))).1
                    [.u8 chainId, .address sender, .address contract,
                     senderEkRef, recipientEkRef, curBalRef, newBalRef,
                     senderAmountRef, recipientAmountRef,
                     auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                     .immRef (initMs.containers.alloc (proofFields[0]'(by omega))).2] =
                 some ([], sigmaCs))
    (hNewBalRangeOk : o.verifyNewBalanceRangeProof (sigmaCs.alloc (proofFields[1]'(by omega))).1
                         [newBalRef, .immRef (sigmaCs.alloc (proofFields[1]'(by omega))).2] =
                       some ([], newBalRangeCs))
    (hTransferRangeFail : ∀ cs args, o.verifyTransferAmountRangeProof cs args = none) :
    verifyTransferBytecodeResult o chainId sender contract
        senderEkRef recipientEkRef curBalRef newBalRef
        senderAmountRef recipientAmountRef
        auditorEksRef auditorAmountsRef senderAuditorHintRef
        proofRid proofFields initMs hFieldCount =
    .error := by
  unfold verifyTransferBytecodeResult
  simp only [hsigmaOk, hNewBalRangeOk, hTransferRangeFail]

/-- Functional simulation shape lemma: happy path → .returned

Transfer success path with 3 nested oracle calls: sigma, new balance range, transfer amount range.
Each successful call returns empty list and new container store. The final machine state has
containers updated through the full allocation chain. -/
theorem verifyTransferBytecodeResult_success
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 2 < proofFields.length)
    (sigmaCs newBalRangeCs transferAmountRangeCs : ContainerStore)
    (sigmaFid newBalRangeFid transferAmountRangeFid : RefId)
    (halloc0 : initMs.containers.alloc (proofFields[0]'(by omega)) = (sigmaCs, sigmaFid))
    (hsigmaOk : o.verifySigmaProof sigmaCs
                    [.u8 chainId, .address sender, .address contract,
                     senderEkRef, recipientEkRef, curBalRef, newBalRef,
                     senderAmountRef, recipientAmountRef,
                     auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                     .immRef sigmaFid] =
                 some ([], newBalRangeCs))
    (halloc1 : newBalRangeCs.alloc (proofFields[1]'(by omega)) = (transferAmountRangeCs, newBalRangeFid))
    (hNewBalRangeOk : o.verifyNewBalanceRangeProof transferAmountRangeCs
                         [newBalRef, .immRef newBalRangeFid] =
                       some ([], (transferAmountRangeCs.alloc (proofFields[2]'hFieldCount)).1))
    (halloc2 : (transferAmountRangeCs.alloc (proofFields[2]'hFieldCount)) =
               ((transferAmountRangeCs.alloc (proofFields[2]'hFieldCount)).1, transferAmountRangeFid))
    (hTransferAmountRangeOk : o.verifyTransferAmountRangeProof
                                (transferAmountRangeCs.alloc (proofFields[2]'hFieldCount)).1
                                [recipientAmountRef, .immRef transferAmountRangeFid] =
                              some ([], (transferAmountRangeCs.alloc (proofFields[2]'hFieldCount)).1)) :
    verifyTransferBytecodeResult o chainId sender contract
        senderEkRef recipientEkRef curBalRef newBalRef
        senderAmountRef recipientAmountRef
        auditorEksRef auditorAmountsRef senderAuditorHintRef
        proofRid proofFields initMs hFieldCount =
    .returned { initMs with
                containers := (transferAmountRangeCs.alloc (proofFields[2]'hFieldCount)).1,
                globals := initMs.globals } := by
  unfold verifyTransferBytecodeResult
  -- The 3-nested allocation chain requires careful rewrites matching the exact allocation order:
  -- 1. halloc0: initMs.containers.alloc (proofFields[0]) = (sigmaCs, sigmaFid)
  -- 2. sigma call produces newBalRangeCs
  -- 3. halloc1: newBalRangeCs.alloc (proofFields[1]) = (transferAmountRangeCs, newBalRangeFid)
  -- 4. new balance range call produces (transferAmountRangeCs.alloc (proofFields[2])).1
  -- 5. transfer amount range call confirms final container state
  --
  -- Each rewrite must thread through the nested match structure. The proof requires explicit
  -- equation matching for the 3-level allocation nesting.
  sorry

/-! ## Top-level composition theorem (Phase 6)

The full eval↔functional-sim equivalence. Structure:
1. Unfold eval to run via `eval_transfer_eq_run`
2. Chain PCs 0-13 (argument marshaling) using individual step theorems
3. At PC 14, split on sigma oracle outcome
4. On sigma success, chain PCs 15-17
5. At PC 18, split on new balance range oracle outcome
6. On new balance range success, chain PCs 19-21
7. At PC 22, split on transfer amount range oracle outcome
8. On transfer amount range success, execute PC 23 (ret)
9. Apply shape lemmas to connect to functional sim

Transfer is the most complex dispatcher with 13 params and 3 sub-calls (sigma + new balance
range + transfer amount range). The proof requires ~400 lines of frame manipulation and
triple oracle case splitting. Currently structured with sorry placeholders for incremental
completion. -/

theorem transfer_eval_equiv_functional_sim
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 2 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (fuel : Nat)
    (hfuel : fuel ≥ 24) :
    let args := [.u8 chainId, .address sender, .address contract,
                 senderEkRef, recipientEkRef, curBalRef, newBalRef,
                 senderAmountRef, recipientAmountRef,
                 auditorEksRef, auditorAmountsRef, senderAuditorHintRef, proofRef]
    (eval (transferModuleEnv o) verifyTransferProofIdx args fuel initMs).dropMs =
    match verifyTransferBytecodeResult o chainId sender contract
            senderEkRef recipientEkRef curBalRef newBalRef
            senderAmountRef recipientAmountRef
            auditorEksRef auditorAmountsRef senderAuditorHintRef
            proofRid proofFields initMs hFieldCount with
    | .returned ms => .returned [] ms
    | .error => .error := by
  -- Unfold eval to run
  show (eval (transferModuleEnv o) verifyTransferProofIdx
          [.u8 chainId, .address sender, .address contract,
           senderEkRef, recipientEkRef, curBalRef, newBalRef,
           senderAmountRef, recipientAmountRef,
           auditorEksRef, auditorAmountsRef, senderAuditorHintRef, proofRef]
          fuel initMs).dropMs = _
  rw [eval_transfer_eq_run]

  -- TODO Phase 6: Chain all 24 PCs using run_succ_ok_of_step
  -- Pattern: apply step theorems sequentially, split on three oracle outcomes
  -- at PC 14 (sigma), PC 18 (new balance range), and PC 22 (transfer amount range),
  -- apply shape lemmas to connect to functional sim
  sorry

end MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv
