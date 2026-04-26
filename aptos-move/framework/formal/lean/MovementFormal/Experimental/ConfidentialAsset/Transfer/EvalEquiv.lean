import MovementFormal.MoveModel.Programs.Transfer
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Structs
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.ExecResultDropMs
import MovementFormal.Experimental.ConfidentialAsset.Helpers.ArgumentMarshaling
import MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleComposition
import MovementFormal.Experimental.ConfidentialAsset.Transfer.ConcreteHelpers
import Mathlib.Tactic.Common
import Mathlib.Tactic.Set
import MovementFormal.Experimental.ConfidentialAsset.Transfer.BytecodeLemmas

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

/-! ## Bytecode access lemmas (extracted to BytecodeLemmas.lean) -/

private abbrev tr_code_pc0  := BytecodeLemmas.instr0_eq
private abbrev tr_code_pc1  := BytecodeLemmas.instr1_eq
private abbrev tr_code_pc2  := BytecodeLemmas.instr2_eq
private abbrev tr_code_pc3  := BytecodeLemmas.instr3_eq
private abbrev tr_code_pc4  := BytecodeLemmas.instr4_eq
private abbrev tr_code_pc5  := BytecodeLemmas.instr5_eq
private abbrev tr_code_pc6  := BytecodeLemmas.instr6_eq
private abbrev tr_code_pc7  := BytecodeLemmas.instr7_eq
private abbrev tr_code_pc8  := BytecodeLemmas.instr8_eq
private abbrev tr_code_pc9  := BytecodeLemmas.instr9_eq
private abbrev tr_code_pc10 := BytecodeLemmas.instr10_eq
private abbrev tr_code_pc11 := BytecodeLemmas.instr11_eq
private abbrev tr_code_pc12 := BytecodeLemmas.instr12_eq
private abbrev tr_code_pc13 := BytecodeLemmas.instr13_eq
private abbrev tr_code_pc14 := BytecodeLemmas.instr14_eq
private abbrev tr_code_pc15 := BytecodeLemmas.instr15_eq
private abbrev tr_code_pc16 := BytecodeLemmas.instr16_eq
private abbrev tr_code_pc17 := BytecodeLemmas.instr17_eq
private abbrev tr_code_pc18 := BytecodeLemmas.instr18_eq
private abbrev tr_code_pc19 := BytecodeLemmas.instr19_eq
private abbrev tr_code_pc20 := BytecodeLemmas.instr20_eq
private abbrev tr_code_pc21 := BytecodeLemmas.instr21_eq
private abbrev tr_code_pc22 := BytecodeLemmas.instr22_eq
private abbrev tr_code_pc23 := BytecodeLemmas.instr23_eq

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

theorem step_transfer_pc14_multi (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 14)
    (args rest : List MoveValue) (v : MoveValue) (vs : List MoveValue)
    (containers' : ContainerStore)
    (htake : takeN stack 13 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = some (v :: vs, containers')) :
    step (transferModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; exact tr_code_pc14
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (transferModuleEnv o).functions.size by simp)]
  simp only [transferModuleEnv_fn0_numParams, htake, transferModuleEnv_fn0_body, himpl]
  unfold handleNativeResult
  cases vs with
  | nil => simp [transferModuleEnv_fn0_numReturns]
  | cons w ws => simp [transferModuleEnv_fn0_numReturns]

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

theorem step_transfer_pc18_multi (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 18)
    (args rest : List MoveValue) (v : MoveValue) (vs : List MoveValue)
    (containers' : ContainerStore)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyNewBalanceRangeProof ms.containers args = some (v :: vs, containers')) :
    step (transferModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; exact tr_code_pc18
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (transferModuleEnv o).functions.size by simp)]
  simp only [transferModuleEnv_fn1_numParams, htake, transferModuleEnv_fn1_body, himpl]
  unfold handleNativeResult
  cases vs with
  | nil => simp [transferModuleEnv_fn1_numReturns]
  | cons w ws => simp [transferModuleEnv_fn1_numReturns]

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

theorem step_transfer_pc22_multi (o : TransferModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyTransferProofCode) (hpc : frame.pc = 22)
    (args rest : List MoveValue) (v : MoveValue) (vs : List MoveValue)
    (containers' : ContainerStore)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyTransferAmountRangeProof ms.containers args = some (v :: vs, containers')) :
    step (transferModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 2 := by simp only [hcode, hpc]; exact tr_code_pc22
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 2 < (transferModuleEnv o).functions.size by simp)]
  simp only [transferModuleEnv_fn2_numParams, htake, transferModuleEnv_fn2_body, himpl]
  unfold handleNativeResult
  cases vs with
  | nil => simp [transferModuleEnv_fn2_numReturns]
  | cons w ws => simp [transferModuleEnv_fn2_numReturns]

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

/-! ## Phase 4 closure: error- and success-path PC chain helpers -/

set_option maxHeartbeats 800000 in
/-- When sigma oracle returns none, transfer run produces error.
    Chains PCs 0-14: 6 moveLoc + copyLoc + moveLoc + copyLoc + 3 moveLoc + copyLoc +
    immBorrowField (sigma alloc) + sigma-call-none → `.error`. -/
theorem tr_run_to_sigma_fail_produces_error
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 : ContainerStore) (sigmaFid : RefId)
    (hFieldCount : 0 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc : initMs.containers.alloc (proofFields[0]'hFieldCount) = (cs1, sigmaFid))
    (fuel : Nat)
    (hfuel : fuel ≥ 15)
    (hsigmaFail :
       o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                senderEkRef, recipientEkRef, curBalRef, newBalRef,
                                senderAmountRef, recipientAmountRef,
                                auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                                .immRef sigmaFid] = none) :
    run (transferModuleEnv o)
        { code := verifyTransferProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      senderEkRef, recipientEkRef, curBalRef, newBalRef,
                      senderAmountRef, recipientAmountRef,
                      auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                      proofRef].map some).toArray,
          localRefs := (List.replicate 13 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyTransferProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    senderEkRef, recipientEkRef, curBalRef, newBalRef,
                    senderAmountRef, recipientAmountRef,
                    auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                    proofRef].map some).toArray,
        localRefs := (List.replicate 13 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 13 := by simp [f0]
  -- PC 0: moveLoc 0 (chainId)
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_transfer_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  -- PC 1: moveLoc 1 (sender)
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 13 := by
    show (f0.locals.set 0 none hf0_lt0).size = 13; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_transfer_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  -- PC 2: moveLoc 2 (contract)
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 13 := by
    show (f1.locals.set 1 none hf1_lt1).size = 13; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_transfer_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  -- PC 3: moveLoc 3 (senderEkRef)
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 13 := by
    show (f2.locals.set 2 none hf2_lt2).size = 13; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some senderEkRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_transfer_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderEkRef hf3_lt3 hf3_v3 hf3_ref3
  -- PC 4: moveLoc 4 (recipientEkRef)
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 13 := by
    show (f3.locals.set 3 none hf3_lt3).size = 13; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some recipientEkRef := by
    show (f3.locals.set 3 none hf3_lt3)[4]'hf4_lt4 = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 4)]
    show (f2.locals.set 2 none hf2_lt2)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 4)]
    show (f1.locals.set 1 none hf1_lt1)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 4)]
    show (f0.locals.set 0 none hf0_lt0)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 4)]; simp [f0]
  have hf4_ref4 : ¬ 4 < f4.localRefs.size ∨
                  ∃ h : 4 < f4.localRefs.size, f4.localRefs[4]'h = none := by
    right; refine ⟨by simp [f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_transfer_pc4 o f4 []
                  [senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl recipientEkRef hf4_lt4 hf4_v4 hf4_ref4
  -- PC 5: moveLoc 5 (curBalRef)
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 13 := by
    show (f4.locals.set 4 none hf4_lt4).size = 13; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some curBalRef := by
    show (f4.locals.set 4 none hf4_lt4)[5]'hf5_lt5 = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 5)]
    show (f3.locals.set 3 none hf3_lt3)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 5)]
    show (f2.locals.set 2 none hf2_lt2)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 5)]
    show (f1.locals.set 1 none hf1_lt1)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 5)]
    show (f0.locals.set 0 none hf0_lt0)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 5)]; simp [f0]
  have hf5_ref5 : ¬ 5 < f5.localRefs.size ∨
                  ∃ h : 5 < f5.localRefs.size, f5.localRefs[5]'h = none := by
    right; refine ⟨by simp [f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_transfer_pc5 o f5 []
                  [recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  -- PC 6: copyLoc 6 (newBalRef, no clear)
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 13 := by
    show (f5.locals.set 5 none hf5_lt5).size = 13; rw [Array.size_set]; exact hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some newBalRef := by
    show (f5.locals.set 5 none hf5_lt5)[6]'hf6_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]
    show (f4.locals.set 4 none hf4_lt4)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 6)]
    show (f3.locals.set 3 none hf3_lt3)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 6)]
    show (f2.locals.set 2 none hf2_lt2)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 6)]
    show (f1.locals.set 1 none hf1_lt1)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 6)]
    show (f0.locals.set 0 none hf0_lt0)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 6)]; simp [f0]
  have hf6_ref6 : ¬ 6 < f6.localRefs.size ∨
                  ∃ h : 6 < f6.localRefs.size, f6.localRefs[6]'h = none := by
    right; refine ⟨by simp [f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_transfer_pc6 o f6 []
                  [curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  -- PC 7: moveLoc 7 (senderAmountRef) - locals at f7 = f6 (copyLoc didn't clear)
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 13 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some senderAmountRef := by
    show f6.locals[7]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 7)]
    show (f4.locals.set 4 none hf4_lt4)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 7)]
    show (f3.locals.set 3 none hf3_lt3)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 7)]
    show (f2.locals.set 2 none hf2_lt2)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 7)]
    show (f1.locals.set 1 none hf1_lt1)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 7)]
    show (f0.locals.set 0 none hf0_lt0)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 7)]; simp [f0]
  have hf7_ref7 : ¬ 7 < f7.localRefs.size ∨
                  ∃ h : 7 < f7.localRefs.size, f7.localRefs[7]'h = none := by
    right; refine ⟨by simp [f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_transfer_pc7 o f7 []
                  [newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderAmountRef hf7_lt7 hf7_v7 hf7_ref7
  -- PC 8: copyLoc 8 (recipientAmountRef, no clear)
  set f8 := { f7 with pc := 8, locals := f7.locals.set 7 none hf7_lt7 } with hf8_def
  have hf8_size : f8.locals.size = 13 := by
    show (f7.locals.set 7 none hf7_lt7).size = 13; rw [Array.size_set]; exact hf7_size
  have hf8_lt8 : 8 < f8.locals.size := by rw [hf8_size]; decide
  have hf8_v8 : f8.locals[8]'hf8_lt8 = some recipientAmountRef := by
    show (f7.locals.set 7 none hf7_lt7)[8]'hf8_lt8 = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 8)]
    show f6.locals[8]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 8)]
    show (f4.locals.set 4 none hf4_lt4)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 8)]
    show (f3.locals.set 3 none hf3_lt3)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 8)]
    show (f2.locals.set 2 none hf2_lt2)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 8)]
    show (f1.locals.set 1 none hf1_lt1)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 8)]
    show (f0.locals.set 0 none hf0_lt0)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 8)]; simp [f0]
  have hf8_ref8 : ¬ 8 < f8.localRefs.size ∨
                  ∃ h : 8 < f8.localRefs.size, f8.localRefs[8]'h = none := by
    right; refine ⟨by simp [f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[8]'(by simp) = none; decide
  have step9 := step_transfer_pc8 o f8 []
                  [senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl recipientAmountRef hf8_lt8 hf8_v8 hf8_ref8
  -- PC 9: moveLoc 9 (auditorEksRef) - f9.locals = f8.locals (copyLoc 8 didn't clear)
  set f9 := { f8 with pc := 9 } with hf9_def
  have hf9_size : f9.locals.size = 13 := hf8_size
  have hf9_lt9 : 9 < f9.locals.size := by rw [hf9_size]; decide
  have hf9_v9 : f9.locals[9]'hf9_lt9 = some auditorEksRef := by
    show (f7.locals.set 7 none hf7_lt7)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 9)]
    show f6.locals[9]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 9)]
    show (f4.locals.set 4 none hf4_lt4)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 9)]
    show (f3.locals.set 3 none hf3_lt3)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 9)]
    show (f2.locals.set 2 none hf2_lt2)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 9)]
    show (f1.locals.set 1 none hf1_lt1)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 9)]
    show (f0.locals.set 0 none hf0_lt0)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 9)]; simp [f0]
  have hf9_ref9 : ¬ 9 < f9.localRefs.size ∨
                  ∃ h : 9 < f9.localRefs.size, f9.localRefs[9]'h = none := by
    right; refine ⟨by simp [f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[9]'(by simp) = none; decide
  have step10 := step_transfer_pc9 o f9 []
                  [recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl auditorEksRef hf9_lt9 hf9_v9 hf9_ref9
  -- PC 10: moveLoc 10 (auditorAmountsRef)
  set f10 := { f9 with pc := 10, locals := f9.locals.set 9 none hf9_lt9 } with hf10_def
  have hf10_size : f10.locals.size = 13 := by
    show (f9.locals.set 9 none hf9_lt9).size = 13; rw [Array.size_set]; exact hf9_size
  have hf10_lt10 : 10 < f10.locals.size := by rw [hf10_size]; decide
  have hf10_v10 : f10.locals[10]'hf10_lt10 = some auditorAmountsRef := by
    show (f9.locals.set 9 none hf9_lt9)[10]'hf10_lt10 = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 10)]
    show (f7.locals.set 7 none hf7_lt7)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 10)]
    show f6.locals[10]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 10)]
    show (f4.locals.set 4 none hf4_lt4)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 10)]
    show (f3.locals.set 3 none hf3_lt3)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 10)]
    show (f2.locals.set 2 none hf2_lt2)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 10)]
    show (f1.locals.set 1 none hf1_lt1)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 10)]
    show (f0.locals.set 0 none hf0_lt0)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 10)]; simp [f0]
  have hf10_ref10 : ¬ 10 < f10.localRefs.size ∨
                    ∃ h : 10 < f10.localRefs.size, f10.localRefs[10]'h = none := by
    right; refine ⟨by simp [f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[10]'(by simp) = none; decide
  have step11 := step_transfer_pc10 o f10 []
                  [auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl auditorAmountsRef hf10_lt10 hf10_v10 hf10_ref10
  -- PC 11: moveLoc 11 (senderAuditorHintRef)
  set f11 := { f10 with pc := 11, locals := f10.locals.set 10 none hf10_lt10 } with hf11_def
  have hf11_size : f11.locals.size = 13 := by
    show (f10.locals.set 10 none hf10_lt10).size = 13; rw [Array.size_set]; exact hf10_size
  have hf11_lt11 : 11 < f11.locals.size := by rw [hf11_size]; decide
  have hf11_v11 : f11.locals[11]'hf11_lt11 = some senderAuditorHintRef := by
    show (f10.locals.set 10 none hf10_lt10)[11]'hf11_lt11 = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 11)]
    show (f9.locals.set 9 none hf9_lt9)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 11)]
    show (f7.locals.set 7 none hf7_lt7)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 11)]
    show f6.locals[11]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 11)]
    show (f4.locals.set 4 none hf4_lt4)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 11)]
    show (f3.locals.set 3 none hf3_lt3)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 11)]
    show (f2.locals.set 2 none hf2_lt2)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 11)]
    show (f1.locals.set 1 none hf1_lt1)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 11)]
    show (f0.locals.set 0 none hf0_lt0)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 11)]; simp [f0]
  have hf11_ref11 : ¬ 11 < f11.localRefs.size ∨
                    ∃ h : 11 < f11.localRefs.size, f11.localRefs[11]'h = none := by
    right; refine ⟨by simp [f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[11]'(by simp) = none; decide
  have step12 := step_transfer_pc11 o f11 []
                  [auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderAuditorHintRef hf11_lt11 hf11_v11 hf11_ref11
  -- PC 12: copyLoc 12 (proofRef, no clear)
  set f12 := { f11 with pc := 12, locals := f11.locals.set 11 none hf11_lt11 } with hf12_def
  have hf12_size : f12.locals.size = 13 := by
    show (f11.locals.set 11 none hf11_lt11).size = 13; rw [Array.size_set]; exact hf11_size
  have hf12_lt12 : 12 < f12.locals.size := by rw [hf12_size]; decide
  have hf12_v12 : f12.locals[12]'hf12_lt12 = some proofRef := by
    show (f11.locals.set 11 none hf11_lt11)[12]'hf12_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 12)]
    show (f10.locals.set 10 none hf10_lt10)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 12)]
    show (f9.locals.set 9 none hf9_lt9)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 12)]
    show (f7.locals.set 7 none hf7_lt7)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 12)]
    show f6.locals[12]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 12)]
    show (f4.locals.set 4 none hf4_lt4)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 12)]
    show (f3.locals.set 3 none hf3_lt3)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 12)]
    show (f2.locals.set 2 none hf2_lt2)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 12)]
    show (f1.locals.set 1 none hf1_lt1)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 12)]
    show (f0.locals.set 0 none hf0_lt0)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 12)]; simp [f0]
  have hf12_ref12 : ¬ 12 < f12.localRefs.size ∨
                    ∃ h : 12 < f12.localRefs.size, f12.localRefs[12]'h = none := by
    right; refine ⟨by simp [f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  have step13 := step_transfer_pc12 o f12 []
                  [senderAuditorHintRef, auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf12_lt12 hf12_v12 hf12_ref12
  -- PC 13: immBorrowField 0 (sigma_proof field, alloc)
  set f13 := { f12 with pc := 13 } with hf13_def
  have step14 := step_transfer_pc13 o f13 []
                  [senderAuditorHintRef, auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread hFieldCount halloc
  -- PC 14: sigma call (none → error)
  set f14 := { f13 with pc := 14 } with hf14_def
  set ms14 : MachineState := { initMs with containers := cs1 } with hms14_def
  have htake :
      takeN [(.immRef sigmaFid : MoveValue), senderAuditorHintRef, auditorAmountsRef, auditorEksRef,
              recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef,
              (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)] 13 =
        some ([.u8 chainId, .address sender, .address contract,
               senderEkRef, recipientEkRef, curBalRef, newBalRef,
               senderAmountRef, recipientAmountRef,
               auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
               .immRef sigmaFid], []) := rfl
  have step15 := step_transfer_pc14_none o f14 []
                  [(.immRef sigmaFid : MoveValue), senderAuditorHintRef, auditorAmountsRef, auditorEksRef,
                    recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms14 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   senderEkRef, recipientEkRef, curBalRef, newBalRef,
                   senderAmountRef, recipientAmountRef,
                   auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                   .immRef sigmaFid]
                  [] htake hsigmaFail
  -- Compose: 14 OK steps + 1 error step = 15 fuel.
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 15 := ⟨fuel - 15, by omega⟩
  rw [hef]
  rw [show ef + 15 = (ef + 14) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 14) _ _ _ _ step1,
      show ef + 14 = (ef + 13) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 13) _ _ _ _ step2,
      show ef + 13 = (ef + 12) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 12) _ _ _ _ step3,
      show ef + 12 = (ef + 11) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 11) _ _ _ _ step4,
      show ef + 11 = (ef + 10) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 10) _ _ _ _ step5,
      show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step6,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step7,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step8,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step9,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step10,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step11,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step12,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step13,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step14,
      StepLemmas.run_succ_error_of_step ef step15]

set_option maxHeartbeats 800000 in
/-- When sigma oracle returns a non-empty result list (arity mismatch), run produces error.
    Same first 14 OK steps as `tr_run_to_sigma_fail_produces_error`; final step uses
    `step_transfer_pc14_multi`. -/
theorem tr_run_to_sigma_arity_mismatch_produces_error
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 : ContainerStore) (sigmaFid : RefId)
    (sigmaResultHead : MoveValue) (sigmaResultTail : List MoveValue)
    (hFieldCount : 0 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc : initMs.containers.alloc (proofFields[0]'hFieldCount) = (cs1, sigmaFid))
    (fuel : Nat)
    (hfuel : fuel ≥ 15)
    (hsigmaArityMismatch :
       o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                senderEkRef, recipientEkRef, curBalRef, newBalRef,
                                senderAmountRef, recipientAmountRef,
                                auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                                .immRef sigmaFid] = some (sigmaResultHead :: sigmaResultTail, cs2)) :
    run (transferModuleEnv o)
        { code := verifyTransferProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      senderEkRef, recipientEkRef, curBalRef, newBalRef,
                      senderAmountRef, recipientAmountRef,
                      auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                      proofRef].map some).toArray,
          localRefs := (List.replicate 13 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyTransferProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    senderEkRef, recipientEkRef, curBalRef, newBalRef,
                    senderAmountRef, recipientAmountRef,
                    auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                    proofRef].map some).toArray,
        localRefs := (List.replicate 13 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 13 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_transfer_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 13 := by
    show (f0.locals.set 0 none hf0_lt0).size = 13; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_transfer_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 13 := by
    show (f1.locals.set 1 none hf1_lt1).size = 13; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_transfer_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 13 := by
    show (f2.locals.set 2 none hf2_lt2).size = 13; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some senderEkRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_transfer_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderEkRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 13 := by
    show (f3.locals.set 3 none hf3_lt3).size = 13; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some recipientEkRef := by
    show (f3.locals.set 3 none hf3_lt3)[4]'hf4_lt4 = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 4)]
    show (f2.locals.set 2 none hf2_lt2)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 4)]
    show (f1.locals.set 1 none hf1_lt1)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 4)]
    show (f0.locals.set 0 none hf0_lt0)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 4)]; simp [f0]
  have hf4_ref4 : ¬ 4 < f4.localRefs.size ∨
                  ∃ h : 4 < f4.localRefs.size, f4.localRefs[4]'h = none := by
    right; refine ⟨by simp [f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_transfer_pc4 o f4 []
                  [senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl recipientEkRef hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 13 := by
    show (f4.locals.set 4 none hf4_lt4).size = 13; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some curBalRef := by
    show (f4.locals.set 4 none hf4_lt4)[5]'hf5_lt5 = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 5)]
    show (f3.locals.set 3 none hf3_lt3)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 5)]
    show (f2.locals.set 2 none hf2_lt2)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 5)]
    show (f1.locals.set 1 none hf1_lt1)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 5)]
    show (f0.locals.set 0 none hf0_lt0)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 5)]; simp [f0]
  have hf5_ref5 : ¬ 5 < f5.localRefs.size ∨
                  ∃ h : 5 < f5.localRefs.size, f5.localRefs[5]'h = none := by
    right; refine ⟨by simp [f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_transfer_pc5 o f5 []
                  [recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 13 := by
    show (f5.locals.set 5 none hf5_lt5).size = 13; rw [Array.size_set]; exact hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some newBalRef := by
    show (f5.locals.set 5 none hf5_lt5)[6]'hf6_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]
    show (f4.locals.set 4 none hf4_lt4)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 6)]
    show (f3.locals.set 3 none hf3_lt3)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 6)]
    show (f2.locals.set 2 none hf2_lt2)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 6)]
    show (f1.locals.set 1 none hf1_lt1)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 6)]
    show (f0.locals.set 0 none hf0_lt0)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 6)]; simp [f0]
  have hf6_ref6 : ¬ 6 < f6.localRefs.size ∨
                  ∃ h : 6 < f6.localRefs.size, f6.localRefs[6]'h = none := by
    right; refine ⟨by simp [f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_transfer_pc6 o f6 []
                  [curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 13 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some senderAmountRef := by
    show f6.locals[7]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 7)]
    show (f4.locals.set 4 none hf4_lt4)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 7)]
    show (f3.locals.set 3 none hf3_lt3)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 7)]
    show (f2.locals.set 2 none hf2_lt2)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 7)]
    show (f1.locals.set 1 none hf1_lt1)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 7)]
    show (f0.locals.set 0 none hf0_lt0)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 7)]; simp [f0]
  have hf7_ref7 : ¬ 7 < f7.localRefs.size ∨
                  ∃ h : 7 < f7.localRefs.size, f7.localRefs[7]'h = none := by
    right; refine ⟨by simp [f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_transfer_pc7 o f7 []
                  [newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderAmountRef hf7_lt7 hf7_v7 hf7_ref7
  set f8 := { f7 with pc := 8, locals := f7.locals.set 7 none hf7_lt7 } with hf8_def
  have hf8_size : f8.locals.size = 13 := by
    show (f7.locals.set 7 none hf7_lt7).size = 13; rw [Array.size_set]; exact hf7_size
  have hf8_lt8 : 8 < f8.locals.size := by rw [hf8_size]; decide
  have hf8_v8 : f8.locals[8]'hf8_lt8 = some recipientAmountRef := by
    show (f7.locals.set 7 none hf7_lt7)[8]'hf8_lt8 = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 8)]
    show f6.locals[8]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 8)]
    show (f4.locals.set 4 none hf4_lt4)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 8)]
    show (f3.locals.set 3 none hf3_lt3)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 8)]
    show (f2.locals.set 2 none hf2_lt2)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 8)]
    show (f1.locals.set 1 none hf1_lt1)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 8)]
    show (f0.locals.set 0 none hf0_lt0)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 8)]; simp [f0]
  have hf8_ref8 : ¬ 8 < f8.localRefs.size ∨
                  ∃ h : 8 < f8.localRefs.size, f8.localRefs[8]'h = none := by
    right; refine ⟨by simp [f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[8]'(by simp) = none; decide
  have step9 := step_transfer_pc8 o f8 []
                  [senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl recipientAmountRef hf8_lt8 hf8_v8 hf8_ref8
  set f9 := { f8 with pc := 9 } with hf9_def
  have hf9_size : f9.locals.size = 13 := hf8_size
  have hf9_lt9 : 9 < f9.locals.size := by rw [hf9_size]; decide
  have hf9_v9 : f9.locals[9]'hf9_lt9 = some auditorEksRef := by
    show (f7.locals.set 7 none hf7_lt7)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 9)]
    show f6.locals[9]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 9)]
    show (f4.locals.set 4 none hf4_lt4)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 9)]
    show (f3.locals.set 3 none hf3_lt3)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 9)]
    show (f2.locals.set 2 none hf2_lt2)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 9)]
    show (f1.locals.set 1 none hf1_lt1)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 9)]
    show (f0.locals.set 0 none hf0_lt0)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 9)]; simp [f0]
  have hf9_ref9 : ¬ 9 < f9.localRefs.size ∨
                  ∃ h : 9 < f9.localRefs.size, f9.localRefs[9]'h = none := by
    right; refine ⟨by simp [f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[9]'(by simp) = none; decide
  have step10 := step_transfer_pc9 o f9 []
                  [recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl auditorEksRef hf9_lt9 hf9_v9 hf9_ref9
  set f10 := { f9 with pc := 10, locals := f9.locals.set 9 none hf9_lt9 } with hf10_def
  have hf10_size : f10.locals.size = 13 := by
    show (f9.locals.set 9 none hf9_lt9).size = 13; rw [Array.size_set]; exact hf9_size
  have hf10_lt10 : 10 < f10.locals.size := by rw [hf10_size]; decide
  have hf10_v10 : f10.locals[10]'hf10_lt10 = some auditorAmountsRef := by
    show (f9.locals.set 9 none hf9_lt9)[10]'hf10_lt10 = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 10)]
    show (f7.locals.set 7 none hf7_lt7)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 10)]
    show f6.locals[10]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 10)]
    show (f4.locals.set 4 none hf4_lt4)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 10)]
    show (f3.locals.set 3 none hf3_lt3)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 10)]
    show (f2.locals.set 2 none hf2_lt2)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 10)]
    show (f1.locals.set 1 none hf1_lt1)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 10)]
    show (f0.locals.set 0 none hf0_lt0)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 10)]; simp [f0]
  have hf10_ref10 : ¬ 10 < f10.localRefs.size ∨
                    ∃ h : 10 < f10.localRefs.size, f10.localRefs[10]'h = none := by
    right; refine ⟨by simp [f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[10]'(by simp) = none; decide
  have step11 := step_transfer_pc10 o f10 []
                  [auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl auditorAmountsRef hf10_lt10 hf10_v10 hf10_ref10
  set f11 := { f10 with pc := 11, locals := f10.locals.set 10 none hf10_lt10 } with hf11_def
  have hf11_size : f11.locals.size = 13 := by
    show (f10.locals.set 10 none hf10_lt10).size = 13; rw [Array.size_set]; exact hf10_size
  have hf11_lt11 : 11 < f11.locals.size := by rw [hf11_size]; decide
  have hf11_v11 : f11.locals[11]'hf11_lt11 = some senderAuditorHintRef := by
    show (f10.locals.set 10 none hf10_lt10)[11]'hf11_lt11 = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 11)]
    show (f9.locals.set 9 none hf9_lt9)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 11)]
    show (f7.locals.set 7 none hf7_lt7)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 11)]
    show f6.locals[11]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 11)]
    show (f4.locals.set 4 none hf4_lt4)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 11)]
    show (f3.locals.set 3 none hf3_lt3)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 11)]
    show (f2.locals.set 2 none hf2_lt2)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 11)]
    show (f1.locals.set 1 none hf1_lt1)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 11)]
    show (f0.locals.set 0 none hf0_lt0)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 11)]; simp [f0]
  have hf11_ref11 : ¬ 11 < f11.localRefs.size ∨
                    ∃ h : 11 < f11.localRefs.size, f11.localRefs[11]'h = none := by
    right; refine ⟨by simp [f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[11]'(by simp) = none; decide
  have step12 := step_transfer_pc11 o f11 []
                  [auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderAuditorHintRef hf11_lt11 hf11_v11 hf11_ref11
  set f12 := { f11 with pc := 12, locals := f11.locals.set 11 none hf11_lt11 } with hf12_def
  have hf12_size : f12.locals.size = 13 := by
    show (f11.locals.set 11 none hf11_lt11).size = 13; rw [Array.size_set]; exact hf11_size
  have hf12_lt12 : 12 < f12.locals.size := by rw [hf12_size]; decide
  have hf12_v12 : f12.locals[12]'hf12_lt12 = some proofRef := by
    show (f11.locals.set 11 none hf11_lt11)[12]'hf12_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 12)]
    show (f10.locals.set 10 none hf10_lt10)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 12)]
    show (f9.locals.set 9 none hf9_lt9)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 12)]
    show (f7.locals.set 7 none hf7_lt7)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 12)]
    show f6.locals[12]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 12)]
    show (f4.locals.set 4 none hf4_lt4)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 12)]
    show (f3.locals.set 3 none hf3_lt3)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 12)]
    show (f2.locals.set 2 none hf2_lt2)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 12)]
    show (f1.locals.set 1 none hf1_lt1)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 12)]
    show (f0.locals.set 0 none hf0_lt0)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 12)]; simp [f0]
  have hf12_ref12 : ¬ 12 < f12.localRefs.size ∨
                    ∃ h : 12 < f12.localRefs.size, f12.localRefs[12]'h = none := by
    right; refine ⟨by simp [f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  have step13 := step_transfer_pc12 o f12 []
                  [senderAuditorHintRef, auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf12_lt12 hf12_v12 hf12_ref12
  set f13 := { f12 with pc := 13 } with hf13_def
  have step14 := step_transfer_pc13 o f13 []
                  [senderAuditorHintRef, auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread hFieldCount halloc
  set f14 := { f13 with pc := 14 } with hf14_def
  set ms14 : MachineState := { initMs with containers := cs1 } with hms14_def
  have htake :
      takeN [(.immRef sigmaFid : MoveValue), senderAuditorHintRef, auditorAmountsRef, auditorEksRef,
              recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef,
              (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)] 13 =
        some ([.u8 chainId, .address sender, .address contract,
               senderEkRef, recipientEkRef, curBalRef, newBalRef,
               senderAmountRef, recipientAmountRef,
               auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
               .immRef sigmaFid], []) := rfl
  have step15 := step_transfer_pc14_multi o f14 []
                  [(.immRef sigmaFid : MoveValue), senderAuditorHintRef, auditorAmountsRef, auditorEksRef,
                    recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms14 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   senderEkRef, recipientEkRef, curBalRef, newBalRef,
                   senderAmountRef, recipientAmountRef,
                   auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                   .immRef sigmaFid]
                  [] sigmaResultHead sigmaResultTail cs2 htake hsigmaArityMismatch
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 15 := ⟨fuel - 15, by omega⟩
  rw [hef]
  rw [show ef + 15 = (ef + 14) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 14) _ _ _ _ step1,
      show ef + 14 = (ef + 13) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 13) _ _ _ _ step2,
      show ef + 13 = (ef + 12) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 12) _ _ _ _ step3,
      show ef + 12 = (ef + 11) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 11) _ _ _ _ step4,
      show ef + 11 = (ef + 10) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 10) _ _ _ _ step5,
      show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step6,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step7,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step8,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step9,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step10,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step11,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step12,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step13,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step14,
      StepLemmas.run_succ_error_of_step ef step15]

set_option maxHeartbeats 1000000 in
/-- When sigma succeeds but new-balance range oracle returns none, run produces error.
    Chains PCs 0-18: full sigma_fail prefix + sigma OK + moveLoc 6 + copyLoc 12 +
    immBorrowField 1 (zkrp_new_balance alloc) + newBalRange-call-none → `.error`. -/
theorem tr_run_to_newBalRange_fail_produces_error
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 cs3 : ContainerStore) (sigmaFid zkrpNewBalFid : RefId)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hread2 : cs2.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc0 : initMs.containers.alloc
                  (proofFields[0]'(by omega : 0 < proofFields.length)) = (cs1, sigmaFid))
    (hsigmaOk :
       o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                senderEkRef, recipientEkRef, curBalRef, newBalRef,
                                senderAmountRef, recipientAmountRef,
                                auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                                .immRef sigmaFid] = some ([], cs2))
    (halloc1 : cs2.alloc (proofFields[1]'hFieldCount) = (cs3, zkrpNewBalFid))
    (hNewBalRangeFail : o.verifyNewBalanceRangeProof cs3 [newBalRef, .immRef zkrpNewBalFid] = none)
    (fuel : Nat)
    (hfuel : fuel ≥ 19) :
    run (transferModuleEnv o)
        { code := verifyTransferProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      senderEkRef, recipientEkRef, curBalRef, newBalRef,
                      senderAmountRef, recipientAmountRef,
                      auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                      proofRef].map some).toArray,
          localRefs := (List.replicate 13 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyTransferProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    senderEkRef, recipientEkRef, curBalRef, newBalRef,
                    senderAmountRef, recipientAmountRef,
                    auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                    proofRef].map some).toArray,
        localRefs := (List.replicate 13 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 13 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_transfer_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 13 := by
    show (f0.locals.set 0 none hf0_lt0).size = 13; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_transfer_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 13 := by
    show (f1.locals.set 1 none hf1_lt1).size = 13; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_transfer_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 13 := by
    show (f2.locals.set 2 none hf2_lt2).size = 13; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some senderEkRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_transfer_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderEkRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 13 := by
    show (f3.locals.set 3 none hf3_lt3).size = 13; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some recipientEkRef := by
    show (f3.locals.set 3 none hf3_lt3)[4]'hf4_lt4 = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 4)]
    show (f2.locals.set 2 none hf2_lt2)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 4)]
    show (f1.locals.set 1 none hf1_lt1)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 4)]
    show (f0.locals.set 0 none hf0_lt0)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 4)]; simp [f0]
  have hf4_ref4 : ¬ 4 < f4.localRefs.size ∨
                  ∃ h : 4 < f4.localRefs.size, f4.localRefs[4]'h = none := by
    right; refine ⟨by simp [f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_transfer_pc4 o f4 []
                  [senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl recipientEkRef hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 13 := by
    show (f4.locals.set 4 none hf4_lt4).size = 13; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some curBalRef := by
    show (f4.locals.set 4 none hf4_lt4)[5]'hf5_lt5 = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 5)]
    show (f3.locals.set 3 none hf3_lt3)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 5)]
    show (f2.locals.set 2 none hf2_lt2)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 5)]
    show (f1.locals.set 1 none hf1_lt1)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 5)]
    show (f0.locals.set 0 none hf0_lt0)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 5)]; simp [f0]
  have hf5_ref5 : ¬ 5 < f5.localRefs.size ∨
                  ∃ h : 5 < f5.localRefs.size, f5.localRefs[5]'h = none := by
    right; refine ⟨by simp [f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_transfer_pc5 o f5 []
                  [recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 13 := by
    show (f5.locals.set 5 none hf5_lt5).size = 13; rw [Array.size_set]; exact hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some newBalRef := by
    show (f5.locals.set 5 none hf5_lt5)[6]'hf6_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]
    show (f4.locals.set 4 none hf4_lt4)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 6)]
    show (f3.locals.set 3 none hf3_lt3)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 6)]
    show (f2.locals.set 2 none hf2_lt2)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 6)]
    show (f1.locals.set 1 none hf1_lt1)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 6)]
    show (f0.locals.set 0 none hf0_lt0)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 6)]; simp [f0]
  have hf6_ref6 : ¬ 6 < f6.localRefs.size ∨
                  ∃ h : 6 < f6.localRefs.size, f6.localRefs[6]'h = none := by
    right; refine ⟨by simp [f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_transfer_pc6 o f6 []
                  [curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 13 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some senderAmountRef := by
    show f6.locals[7]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 7)]
    show (f4.locals.set 4 none hf4_lt4)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 7)]
    show (f3.locals.set 3 none hf3_lt3)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 7)]
    show (f2.locals.set 2 none hf2_lt2)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 7)]
    show (f1.locals.set 1 none hf1_lt1)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 7)]
    show (f0.locals.set 0 none hf0_lt0)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 7)]; simp [f0]
  have hf7_ref7 : ¬ 7 < f7.localRefs.size ∨
                  ∃ h : 7 < f7.localRefs.size, f7.localRefs[7]'h = none := by
    right; refine ⟨by simp [f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_transfer_pc7 o f7 []
                  [newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderAmountRef hf7_lt7 hf7_v7 hf7_ref7
  set f8 := { f7 with pc := 8, locals := f7.locals.set 7 none hf7_lt7 } with hf8_def
  have hf8_size : f8.locals.size = 13 := by
    show (f7.locals.set 7 none hf7_lt7).size = 13; rw [Array.size_set]; exact hf7_size
  have hf8_lt8 : 8 < f8.locals.size := by rw [hf8_size]; decide
  have hf8_v8 : f8.locals[8]'hf8_lt8 = some recipientAmountRef := by
    show (f7.locals.set 7 none hf7_lt7)[8]'hf8_lt8 = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 8)]
    show f6.locals[8]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 8)]
    show (f4.locals.set 4 none hf4_lt4)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 8)]
    show (f3.locals.set 3 none hf3_lt3)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 8)]
    show (f2.locals.set 2 none hf2_lt2)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 8)]
    show (f1.locals.set 1 none hf1_lt1)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 8)]
    show (f0.locals.set 0 none hf0_lt0)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 8)]; simp [f0]
  have hf8_ref8 : ¬ 8 < f8.localRefs.size ∨
                  ∃ h : 8 < f8.localRefs.size, f8.localRefs[8]'h = none := by
    right; refine ⟨by simp [f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[8]'(by simp) = none; decide
  have step9 := step_transfer_pc8 o f8 []
                  [senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl recipientAmountRef hf8_lt8 hf8_v8 hf8_ref8
  set f9 := { f8 with pc := 9 } with hf9_def
  have hf9_size : f9.locals.size = 13 := hf8_size
  have hf9_lt9 : 9 < f9.locals.size := by rw [hf9_size]; decide
  have hf9_v9 : f9.locals[9]'hf9_lt9 = some auditorEksRef := by
    show (f7.locals.set 7 none hf7_lt7)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 9)]
    show f6.locals[9]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 9)]
    show (f4.locals.set 4 none hf4_lt4)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 9)]
    show (f3.locals.set 3 none hf3_lt3)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 9)]
    show (f2.locals.set 2 none hf2_lt2)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 9)]
    show (f1.locals.set 1 none hf1_lt1)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 9)]
    show (f0.locals.set 0 none hf0_lt0)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 9)]; simp [f0]
  have hf9_ref9 : ¬ 9 < f9.localRefs.size ∨
                  ∃ h : 9 < f9.localRefs.size, f9.localRefs[9]'h = none := by
    right; refine ⟨by simp [f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[9]'(by simp) = none; decide
  have step10 := step_transfer_pc9 o f9 []
                  [recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl auditorEksRef hf9_lt9 hf9_v9 hf9_ref9
  set f10 := { f9 with pc := 10, locals := f9.locals.set 9 none hf9_lt9 } with hf10_def
  have hf10_size : f10.locals.size = 13 := by
    show (f9.locals.set 9 none hf9_lt9).size = 13; rw [Array.size_set]; exact hf9_size
  have hf10_lt10 : 10 < f10.locals.size := by rw [hf10_size]; decide
  have hf10_v10 : f10.locals[10]'hf10_lt10 = some auditorAmountsRef := by
    show (f9.locals.set 9 none hf9_lt9)[10]'hf10_lt10 = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 10)]
    show (f7.locals.set 7 none hf7_lt7)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 10)]
    show f6.locals[10]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 10)]
    show (f4.locals.set 4 none hf4_lt4)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 10)]
    show (f3.locals.set 3 none hf3_lt3)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 10)]
    show (f2.locals.set 2 none hf2_lt2)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 10)]
    show (f1.locals.set 1 none hf1_lt1)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 10)]
    show (f0.locals.set 0 none hf0_lt0)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 10)]; simp [f0]
  have hf10_ref10 : ¬ 10 < f10.localRefs.size ∨
                    ∃ h : 10 < f10.localRefs.size, f10.localRefs[10]'h = none := by
    right; refine ⟨by simp [f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[10]'(by simp) = none; decide
  have step11 := step_transfer_pc10 o f10 []
                  [auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl auditorAmountsRef hf10_lt10 hf10_v10 hf10_ref10
  set f11 := { f10 with pc := 11, locals := f10.locals.set 10 none hf10_lt10 } with hf11_def
  have hf11_size : f11.locals.size = 13 := by
    show (f10.locals.set 10 none hf10_lt10).size = 13; rw [Array.size_set]; exact hf10_size
  have hf11_lt11 : 11 < f11.locals.size := by rw [hf11_size]; decide
  have hf11_v11 : f11.locals[11]'hf11_lt11 = some senderAuditorHintRef := by
    show (f10.locals.set 10 none hf10_lt10)[11]'hf11_lt11 = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 11)]
    show (f9.locals.set 9 none hf9_lt9)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 11)]
    show (f7.locals.set 7 none hf7_lt7)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 11)]
    show f6.locals[11]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 11)]
    show (f4.locals.set 4 none hf4_lt4)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 11)]
    show (f3.locals.set 3 none hf3_lt3)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 11)]
    show (f2.locals.set 2 none hf2_lt2)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 11)]
    show (f1.locals.set 1 none hf1_lt1)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 11)]
    show (f0.locals.set 0 none hf0_lt0)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 11)]; simp [f0]
  have hf11_ref11 : ¬ 11 < f11.localRefs.size ∨
                    ∃ h : 11 < f11.localRefs.size, f11.localRefs[11]'h = none := by
    right; refine ⟨by simp [f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[11]'(by simp) = none; decide
  have step12 := step_transfer_pc11 o f11 []
                  [auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderAuditorHintRef hf11_lt11 hf11_v11 hf11_ref11
  set f12 := { f11 with pc := 12, locals := f11.locals.set 11 none hf11_lt11 } with hf12_def
  have hf12_size : f12.locals.size = 13 := by
    show (f11.locals.set 11 none hf11_lt11).size = 13; rw [Array.size_set]; exact hf11_size
  have hf12_lt12 : 12 < f12.locals.size := by rw [hf12_size]; decide
  have hf12_v12 : f12.locals[12]'hf12_lt12 = some proofRef := by
    show (f11.locals.set 11 none hf11_lt11)[12]'hf12_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 12)]
    show (f10.locals.set 10 none hf10_lt10)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 12)]
    show (f9.locals.set 9 none hf9_lt9)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 12)]
    show (f7.locals.set 7 none hf7_lt7)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 12)]
    show f6.locals[12]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 12)]
    show (f4.locals.set 4 none hf4_lt4)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 12)]
    show (f3.locals.set 3 none hf3_lt3)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 12)]
    show (f2.locals.set 2 none hf2_lt2)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 12)]
    show (f1.locals.set 1 none hf1_lt1)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 12)]
    show (f0.locals.set 0 none hf0_lt0)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 12)]; simp [f0]
  have hf12_ref12 : ¬ 12 < f12.localRefs.size ∨
                    ∃ h : 12 < f12.localRefs.size, f12.localRefs[12]'h = none := by
    right; refine ⟨by simp [f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  have step13 := step_transfer_pc12 o f12 []
                  [senderAuditorHintRef, auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf12_lt12 hf12_v12 hf12_ref12
  set f13 := { f12 with pc := 13 } with hf13_def
  have step14 := step_transfer_pc13 o f13 []
                  [senderAuditorHintRef, auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread (by omega : 0 < proofFields.length) halloc0
  -- PC 14: sigma OK → cs2
  set f14 := { f13 with pc := 14 } with hf14_def
  set ms14 : MachineState := { initMs with containers := cs1 } with hms14_def
  have htake_pc14 :
      takeN [(.immRef sigmaFid : MoveValue), senderAuditorHintRef, auditorAmountsRef, auditorEksRef,
              recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef,
              (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)] 13 =
        some ([.u8 chainId, .address sender, .address contract,
               senderEkRef, recipientEkRef, curBalRef, newBalRef,
               senderAmountRef, recipientAmountRef,
               auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
               .immRef sigmaFid], []) := rfl
  have step15 := step_transfer_pc14 o f14 []
                  [(.immRef sigmaFid : MoveValue), senderAuditorHintRef, auditorAmountsRef, auditorEksRef,
                    recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms14 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   senderEkRef, recipientEkRef, curBalRef, newBalRef,
                   senderAmountRef, recipientAmountRef,
                   auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                   .immRef sigmaFid]
                  [] cs2 htake_pc14 hsigmaOk
  -- After step15: pc=15, stack=[], containers=cs2.
  set f15 := { f14 with pc := 15 } with hf15_def
  set ms15 : MachineState := { ms14 with containers := cs2, globals := ms14.globals } with hms15_def
  -- PC 15: moveLoc 6 (newBalRef). f15.locals = f14.locals = f13.locals = f12.locals.
  have hf15_lt6 : 6 < f15.locals.size := hf6_lt6
  have hf15_v6 : f15.locals[6]'hf15_lt6 = some newBalRef := by
    show (f11.locals.set 11 none hf11_lt11)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 6)]
    show (f10.locals.set 10 none hf10_lt10)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 6)]
    show (f9.locals.set 9 none hf9_lt9)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 6)]
    show (f7.locals.set 7 none hf7_lt7)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 6)]
    exact hf6_v6
  have hf15_ref6 : ¬ 6 < f15.localRefs.size ∨
                   ∃ h : 6 < f15.localRefs.size, f15.localRefs[6]'h = none := hf6_ref6
  have step16 := step_transfer_pc15 o f15 [] [] ms15 rfl rfl newBalRef
                   hf15_lt6 hf15_v6 hf15_ref6
  -- After step16: pc=16, stack=[newBalRef], locals[6]:=none, containers=cs2.
  set f16 := { f15 with pc := 16, locals := f15.locals.set 6 none hf15_lt6 } with hf16_def
  have hf16_size : f16.locals.size = 13 := by
    show (f15.locals.set 6 none hf15_lt6).size = 13; rw [Array.size_set]; exact hf12_size
  have hf16_lt12 : 12 < f16.locals.size := by rw [hf16_size]; decide
  have hf16_v12 : f16.locals[12]'hf16_lt12 = some proofRef := by
    show (f15.locals.set 6 none hf15_lt6)[12]'hf16_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (6 : Nat) ≠ 12)]
    exact hf12_v12
  have hf16_ref12 : ¬ 12 < f16.localRefs.size ∨
                    ∃ h : 12 < f16.localRefs.size, f16.localRefs[12]'h = none := by
    right; refine ⟨by simp [f16, f15, f14, f13, f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  -- PC 16: copyLoc 12 (proofRef, no clear)
  have step17 := step_transfer_pc16 o f16 [] [newBalRef] ms15 rfl rfl proofRef
                   hf16_lt12 hf16_v12 hf16_ref12
  -- After step17: pc=17, stack=[proofRef, newBalRef], locals unchanged, containers=cs2.
  set f17 := { f16 with pc := 17 } with hf17_def
  -- PC 17: immBorrowField 1 (zkrp_new_balance, alloc proofFields[1] in cs2 → cs3)
  have hms15_read : ms15.containers.read proofRid = some (.struct_ proofFields) := by
    show cs2.read proofRid = _; exact hread2
  have step18 := step_transfer_pc17 o f17 [] [newBalRef] ms15 rfl rfl proofRid proofFields
                   cs3 zkrpNewBalFid proofRef hproofRef hms15_read hFieldCount
                   (show ms15.containers.alloc _ = (cs3, zkrpNewBalFid) from
                     show cs2.alloc _ = (cs3, zkrpNewBalFid) from halloc1)
  -- After step18: pc=18, stack=[.immRef zkrpNewBalFid, newBalRef], containers=cs3.
  set f18 := { f17 with pc := 18 } with hf18_def
  set ms18 : MachineState := { ms15 with containers := cs3 } with hms18_def
  -- PC 18: newBalRange call (none → error)
  have htake_pc18 :
      takeN [(.immRef zkrpNewBalFid : MoveValue), newBalRef] 2 =
        some ([newBalRef, .immRef zkrpNewBalFid], []) := rfl
  have step19 := step_transfer_pc18_none o f18 []
                   [(.immRef zkrpNewBalFid : MoveValue), newBalRef]
                   ms18 rfl rfl
                   [newBalRef, .immRef zkrpNewBalFid] [] htake_pc18 hNewBalRangeFail
  -- Compose: 18 OK steps + 1 error step = 19 fuel.
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 19 := ⟨fuel - 19, by omega⟩
  rw [hef]
  rw [show ef + 19 = (ef + 18) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 18) _ _ _ _ step1,
      show ef + 18 = (ef + 17) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 17) _ _ _ _ step2,
      show ef + 17 = (ef + 16) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 16) _ _ _ _ step3,
      show ef + 16 = (ef + 15) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 15) _ _ _ _ step4,
      show ef + 15 = (ef + 14) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 14) _ _ _ _ step5,
      show ef + 14 = (ef + 13) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 13) _ _ _ _ step6,
      show ef + 13 = (ef + 12) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 12) _ _ _ _ step7,
      show ef + 12 = (ef + 11) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 11) _ _ _ _ step8,
      show ef + 11 = (ef + 10) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 10) _ _ _ _ step9,
      show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step10,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step11,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step12,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step13,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step14,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step15,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step16,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step17,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step18,
      StepLemmas.run_succ_error_of_step ef step19]

set_option maxHeartbeats 1000000 in
/-- When sigma succeeds but new-balance range oracle returns a non-empty list (arity mismatch),
    run produces error. Same first 18 OK steps as `tr_run_to_newBalRange_fail_produces_error`;
    final step uses `step_transfer_pc18_multi`. -/
theorem tr_run_to_newBalRange_arity_mismatch_produces_error
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 cs3 cs4 : ContainerStore) (sigmaFid zkrpNewBalFid : RefId)
    (rangeResultHead : MoveValue) (rangeResultTail : List MoveValue)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hread2 : cs2.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc0 : initMs.containers.alloc
                  (proofFields[0]'(by omega : 0 < proofFields.length)) = (cs1, sigmaFid))
    (hsigmaOk :
       o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                senderEkRef, recipientEkRef, curBalRef, newBalRef,
                                senderAmountRef, recipientAmountRef,
                                auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                                .immRef sigmaFid] = some ([], cs2))
    (halloc1 : cs2.alloc (proofFields[1]'hFieldCount) = (cs3, zkrpNewBalFid))
    (hNewBalRangeArity :
       o.verifyNewBalanceRangeProof cs3 [newBalRef, .immRef zkrpNewBalFid] =
         some (rangeResultHead :: rangeResultTail, cs4))
    (fuel : Nat)
    (hfuel : fuel ≥ 19) :
    run (transferModuleEnv o)
        { code := verifyTransferProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      senderEkRef, recipientEkRef, curBalRef, newBalRef,
                      senderAmountRef, recipientAmountRef,
                      auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                      proofRef].map some).toArray,
          localRefs := (List.replicate 13 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyTransferProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    senderEkRef, recipientEkRef, curBalRef, newBalRef,
                    senderAmountRef, recipientAmountRef,
                    auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                    proofRef].map some).toArray,
        localRefs := (List.replicate 13 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 13 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_transfer_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 13 := by
    show (f0.locals.set 0 none hf0_lt0).size = 13; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_transfer_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 13 := by
    show (f1.locals.set 1 none hf1_lt1).size = 13; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_transfer_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 13 := by
    show (f2.locals.set 2 none hf2_lt2).size = 13; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some senderEkRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_transfer_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderEkRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 13 := by
    show (f3.locals.set 3 none hf3_lt3).size = 13; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some recipientEkRef := by
    show (f3.locals.set 3 none hf3_lt3)[4]'hf4_lt4 = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 4)]
    show (f2.locals.set 2 none hf2_lt2)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 4)]
    show (f1.locals.set 1 none hf1_lt1)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 4)]
    show (f0.locals.set 0 none hf0_lt0)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 4)]; simp [f0]
  have hf4_ref4 : ¬ 4 < f4.localRefs.size ∨
                  ∃ h : 4 < f4.localRefs.size, f4.localRefs[4]'h = none := by
    right; refine ⟨by simp [f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_transfer_pc4 o f4 []
                  [senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl recipientEkRef hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 13 := by
    show (f4.locals.set 4 none hf4_lt4).size = 13; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some curBalRef := by
    show (f4.locals.set 4 none hf4_lt4)[5]'hf5_lt5 = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 5)]
    show (f3.locals.set 3 none hf3_lt3)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 5)]
    show (f2.locals.set 2 none hf2_lt2)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 5)]
    show (f1.locals.set 1 none hf1_lt1)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 5)]
    show (f0.locals.set 0 none hf0_lt0)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 5)]; simp [f0]
  have hf5_ref5 : ¬ 5 < f5.localRefs.size ∨
                  ∃ h : 5 < f5.localRefs.size, f5.localRefs[5]'h = none := by
    right; refine ⟨by simp [f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_transfer_pc5 o f5 []
                  [recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 13 := by
    show (f5.locals.set 5 none hf5_lt5).size = 13; rw [Array.size_set]; exact hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some newBalRef := by
    show (f5.locals.set 5 none hf5_lt5)[6]'hf6_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]
    show (f4.locals.set 4 none hf4_lt4)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 6)]
    show (f3.locals.set 3 none hf3_lt3)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 6)]
    show (f2.locals.set 2 none hf2_lt2)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 6)]
    show (f1.locals.set 1 none hf1_lt1)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 6)]
    show (f0.locals.set 0 none hf0_lt0)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 6)]; simp [f0]
  have hf6_ref6 : ¬ 6 < f6.localRefs.size ∨
                  ∃ h : 6 < f6.localRefs.size, f6.localRefs[6]'h = none := by
    right; refine ⟨by simp [f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_transfer_pc6 o f6 []
                  [curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 13 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some senderAmountRef := by
    show f6.locals[7]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 7)]
    show (f4.locals.set 4 none hf4_lt4)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 7)]
    show (f3.locals.set 3 none hf3_lt3)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 7)]
    show (f2.locals.set 2 none hf2_lt2)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 7)]
    show (f1.locals.set 1 none hf1_lt1)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 7)]
    show (f0.locals.set 0 none hf0_lt0)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 7)]; simp [f0]
  have hf7_ref7 : ¬ 7 < f7.localRefs.size ∨
                  ∃ h : 7 < f7.localRefs.size, f7.localRefs[7]'h = none := by
    right; refine ⟨by simp [f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_transfer_pc7 o f7 []
                  [newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderAmountRef hf7_lt7 hf7_v7 hf7_ref7
  set f8 := { f7 with pc := 8, locals := f7.locals.set 7 none hf7_lt7 } with hf8_def
  have hf8_size : f8.locals.size = 13 := by
    show (f7.locals.set 7 none hf7_lt7).size = 13; rw [Array.size_set]; exact hf7_size
  have hf8_lt8 : 8 < f8.locals.size := by rw [hf8_size]; decide
  have hf8_v8 : f8.locals[8]'hf8_lt8 = some recipientAmountRef := by
    show (f7.locals.set 7 none hf7_lt7)[8]'hf8_lt8 = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 8)]
    show f6.locals[8]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 8)]
    show (f4.locals.set 4 none hf4_lt4)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 8)]
    show (f3.locals.set 3 none hf3_lt3)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 8)]
    show (f2.locals.set 2 none hf2_lt2)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 8)]
    show (f1.locals.set 1 none hf1_lt1)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 8)]
    show (f0.locals.set 0 none hf0_lt0)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 8)]; simp [f0]
  have hf8_ref8 : ¬ 8 < f8.localRefs.size ∨
                  ∃ h : 8 < f8.localRefs.size, f8.localRefs[8]'h = none := by
    right; refine ⟨by simp [f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[8]'(by simp) = none; decide
  have step9 := step_transfer_pc8 o f8 []
                  [senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl recipientAmountRef hf8_lt8 hf8_v8 hf8_ref8
  set f9 := { f8 with pc := 9 } with hf9_def
  have hf9_size : f9.locals.size = 13 := hf8_size
  have hf9_lt9 : 9 < f9.locals.size := by rw [hf9_size]; decide
  have hf9_v9 : f9.locals[9]'hf9_lt9 = some auditorEksRef := by
    show (f7.locals.set 7 none hf7_lt7)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 9)]
    show f6.locals[9]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 9)]
    show (f4.locals.set 4 none hf4_lt4)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 9)]
    show (f3.locals.set 3 none hf3_lt3)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 9)]
    show (f2.locals.set 2 none hf2_lt2)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 9)]
    show (f1.locals.set 1 none hf1_lt1)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 9)]
    show (f0.locals.set 0 none hf0_lt0)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 9)]; simp [f0]
  have hf9_ref9 : ¬ 9 < f9.localRefs.size ∨
                  ∃ h : 9 < f9.localRefs.size, f9.localRefs[9]'h = none := by
    right; refine ⟨by simp [f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[9]'(by simp) = none; decide
  have step10 := step_transfer_pc9 o f9 []
                  [recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl auditorEksRef hf9_lt9 hf9_v9 hf9_ref9
  set f10 := { f9 with pc := 10, locals := f9.locals.set 9 none hf9_lt9 } with hf10_def
  have hf10_size : f10.locals.size = 13 := by
    show (f9.locals.set 9 none hf9_lt9).size = 13; rw [Array.size_set]; exact hf9_size
  have hf10_lt10 : 10 < f10.locals.size := by rw [hf10_size]; decide
  have hf10_v10 : f10.locals[10]'hf10_lt10 = some auditorAmountsRef := by
    show (f9.locals.set 9 none hf9_lt9)[10]'hf10_lt10 = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 10)]
    show (f7.locals.set 7 none hf7_lt7)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 10)]
    show f6.locals[10]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 10)]
    show (f4.locals.set 4 none hf4_lt4)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 10)]
    show (f3.locals.set 3 none hf3_lt3)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 10)]
    show (f2.locals.set 2 none hf2_lt2)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 10)]
    show (f1.locals.set 1 none hf1_lt1)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 10)]
    show (f0.locals.set 0 none hf0_lt0)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 10)]; simp [f0]
  have hf10_ref10 : ¬ 10 < f10.localRefs.size ∨
                    ∃ h : 10 < f10.localRefs.size, f10.localRefs[10]'h = none := by
    right; refine ⟨by simp [f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[10]'(by simp) = none; decide
  have step11 := step_transfer_pc10 o f10 []
                  [auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl auditorAmountsRef hf10_lt10 hf10_v10 hf10_ref10
  set f11 := { f10 with pc := 11, locals := f10.locals.set 10 none hf10_lt10 } with hf11_def
  have hf11_size : f11.locals.size = 13 := by
    show (f10.locals.set 10 none hf10_lt10).size = 13; rw [Array.size_set]; exact hf10_size
  have hf11_lt11 : 11 < f11.locals.size := by rw [hf11_size]; decide
  have hf11_v11 : f11.locals[11]'hf11_lt11 = some senderAuditorHintRef := by
    show (f10.locals.set 10 none hf10_lt10)[11]'hf11_lt11 = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 11)]
    show (f9.locals.set 9 none hf9_lt9)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 11)]
    show (f7.locals.set 7 none hf7_lt7)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 11)]
    show f6.locals[11]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 11)]
    show (f4.locals.set 4 none hf4_lt4)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 11)]
    show (f3.locals.set 3 none hf3_lt3)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 11)]
    show (f2.locals.set 2 none hf2_lt2)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 11)]
    show (f1.locals.set 1 none hf1_lt1)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 11)]
    show (f0.locals.set 0 none hf0_lt0)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 11)]; simp [f0]
  have hf11_ref11 : ¬ 11 < f11.localRefs.size ∨
                    ∃ h : 11 < f11.localRefs.size, f11.localRefs[11]'h = none := by
    right; refine ⟨by simp [f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[11]'(by simp) = none; decide
  have step12 := step_transfer_pc11 o f11 []
                  [auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderAuditorHintRef hf11_lt11 hf11_v11 hf11_ref11
  set f12 := { f11 with pc := 12, locals := f11.locals.set 11 none hf11_lt11 } with hf12_def
  have hf12_size : f12.locals.size = 13 := by
    show (f11.locals.set 11 none hf11_lt11).size = 13; rw [Array.size_set]; exact hf11_size
  have hf12_lt12 : 12 < f12.locals.size := by rw [hf12_size]; decide
  have hf12_v12 : f12.locals[12]'hf12_lt12 = some proofRef := by
    show (f11.locals.set 11 none hf11_lt11)[12]'hf12_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 12)]
    show (f10.locals.set 10 none hf10_lt10)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 12)]
    show (f9.locals.set 9 none hf9_lt9)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 12)]
    show (f7.locals.set 7 none hf7_lt7)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 12)]
    show f6.locals[12]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 12)]
    show (f4.locals.set 4 none hf4_lt4)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 12)]
    show (f3.locals.set 3 none hf3_lt3)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 12)]
    show (f2.locals.set 2 none hf2_lt2)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 12)]
    show (f1.locals.set 1 none hf1_lt1)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 12)]
    show (f0.locals.set 0 none hf0_lt0)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 12)]; simp [f0]
  have hf12_ref12 : ¬ 12 < f12.localRefs.size ∨
                    ∃ h : 12 < f12.localRefs.size, f12.localRefs[12]'h = none := by
    right; refine ⟨by simp [f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  have step13 := step_transfer_pc12 o f12 []
                  [senderAuditorHintRef, auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf12_lt12 hf12_v12 hf12_ref12
  set f13 := { f12 with pc := 13 } with hf13_def
  have step14 := step_transfer_pc13 o f13 []
                  [senderAuditorHintRef, auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread (by omega : 0 < proofFields.length) halloc0
  set f14 := { f13 with pc := 14 } with hf14_def
  set ms14 : MachineState := { initMs with containers := cs1 } with hms14_def
  have htake_pc14 :
      takeN [(.immRef sigmaFid : MoveValue), senderAuditorHintRef, auditorAmountsRef, auditorEksRef,
              recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef,
              (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)] 13 =
        some ([.u8 chainId, .address sender, .address contract,
               senderEkRef, recipientEkRef, curBalRef, newBalRef,
               senderAmountRef, recipientAmountRef,
               auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
               .immRef sigmaFid], []) := rfl
  have step15 := step_transfer_pc14 o f14 []
                  [(.immRef sigmaFid : MoveValue), senderAuditorHintRef, auditorAmountsRef, auditorEksRef,
                    recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms14 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   senderEkRef, recipientEkRef, curBalRef, newBalRef,
                   senderAmountRef, recipientAmountRef,
                   auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                   .immRef sigmaFid]
                  [] cs2 htake_pc14 hsigmaOk
  set f15 := { f14 with pc := 15 } with hf15_def
  set ms15 : MachineState := { ms14 with containers := cs2, globals := ms14.globals } with hms15_def
  have hf15_lt6 : 6 < f15.locals.size := hf6_lt6
  have hf15_v6 : f15.locals[6]'hf15_lt6 = some newBalRef := by
    show (f11.locals.set 11 none hf11_lt11)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 6)]
    show (f10.locals.set 10 none hf10_lt10)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 6)]
    show (f9.locals.set 9 none hf9_lt9)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 6)]
    show (f7.locals.set 7 none hf7_lt7)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 6)]
    exact hf6_v6
  have hf15_ref6 : ¬ 6 < f15.localRefs.size ∨
                   ∃ h : 6 < f15.localRefs.size, f15.localRefs[6]'h = none := hf6_ref6
  have step16 := step_transfer_pc15 o f15 [] [] ms15 rfl rfl newBalRef
                   hf15_lt6 hf15_v6 hf15_ref6
  set f16 := { f15 with pc := 16, locals := f15.locals.set 6 none hf15_lt6 } with hf16_def
  have hf16_size : f16.locals.size = 13 := by
    show (f15.locals.set 6 none hf15_lt6).size = 13; rw [Array.size_set]; exact hf12_size
  have hf16_lt12 : 12 < f16.locals.size := by rw [hf16_size]; decide
  have hf16_v12 : f16.locals[12]'hf16_lt12 = some proofRef := by
    show (f15.locals.set 6 none hf15_lt6)[12]'hf16_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (6 : Nat) ≠ 12)]
    exact hf12_v12
  have hf16_ref12 : ¬ 12 < f16.localRefs.size ∨
                    ∃ h : 12 < f16.localRefs.size, f16.localRefs[12]'h = none := by
    right; refine ⟨by simp [f16, f15, f14, f13, f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  have step17 := step_transfer_pc16 o f16 [] [newBalRef] ms15 rfl rfl proofRef
                   hf16_lt12 hf16_v12 hf16_ref12
  set f17 := { f16 with pc := 17 } with hf17_def
  have hms15_read : ms15.containers.read proofRid = some (.struct_ proofFields) := by
    show cs2.read proofRid = _; exact hread2
  have step18 := step_transfer_pc17 o f17 [] [newBalRef] ms15 rfl rfl proofRid proofFields
                   cs3 zkrpNewBalFid proofRef hproofRef hms15_read hFieldCount
                   (show ms15.containers.alloc _ = (cs3, zkrpNewBalFid) from
                     show cs2.alloc _ = (cs3, zkrpNewBalFid) from halloc1)
  set f18 := { f17 with pc := 18 } with hf18_def
  set ms18 : MachineState := { ms15 with containers := cs3 } with hms18_def
  have htake_pc18 :
      takeN [(.immRef zkrpNewBalFid : MoveValue), newBalRef] 2 =
        some ([newBalRef, .immRef zkrpNewBalFid], []) := rfl
  have step19 := step_transfer_pc18_multi o f18 []
                   [(.immRef zkrpNewBalFid : MoveValue), newBalRef]
                   ms18 rfl rfl
                   [newBalRef, .immRef zkrpNewBalFid] []
                   rangeResultHead rangeResultTail cs4 htake_pc18 hNewBalRangeArity
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 19 := ⟨fuel - 19, by omega⟩
  rw [hef]
  rw [show ef + 19 = (ef + 18) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 18) _ _ _ _ step1,
      show ef + 18 = (ef + 17) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 17) _ _ _ _ step2,
      show ef + 17 = (ef + 16) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 16) _ _ _ _ step3,
      show ef + 16 = (ef + 15) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 15) _ _ _ _ step4,
      show ef + 15 = (ef + 14) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 14) _ _ _ _ step5,
      show ef + 14 = (ef + 13) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 13) _ _ _ _ step6,
      show ef + 13 = (ef + 12) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 12) _ _ _ _ step7,
      show ef + 12 = (ef + 11) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 11) _ _ _ _ step8,
      show ef + 11 = (ef + 10) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 10) _ _ _ _ step9,
      show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step10,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step11,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step12,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step13,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step14,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step15,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step16,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step17,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step18,
      StepLemmas.run_succ_error_of_step ef step19]

set_option maxHeartbeats 1200000 in
/-- When sigma + new-balance range succeed but transfer-amount range oracle returns none,
    run produces error. Chains PCs 0-22. -/
theorem tr_run_to_transferRange_fail_produces_error
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 cs3 cs4 cs5 : ContainerStore)
    (sigmaFid zkrpNewBalFid zkrpTransferFid : RefId)
    (hFieldCount : 2 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hread2 : cs2.read proofRid = some (.struct_ proofFields))
    (hread4 : cs4.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc0 : initMs.containers.alloc
                  (proofFields[0]'(by omega : 0 < proofFields.length)) = (cs1, sigmaFid))
    (hsigmaOk :
       o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                senderEkRef, recipientEkRef, curBalRef, newBalRef,
                                senderAmountRef, recipientAmountRef,
                                auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                                .immRef sigmaFid] = some ([], cs2))
    (halloc1 : cs2.alloc (proofFields[1]'(by omega : 1 < proofFields.length)) = (cs3, zkrpNewBalFid))
    (hNewBalRangeOk :
       o.verifyNewBalanceRangeProof cs3 [newBalRef, .immRef zkrpNewBalFid] = some ([], cs4))
    (halloc2 : cs4.alloc (proofFields[2]'hFieldCount) = (cs5, zkrpTransferFid))
    (hTransferRangeFail :
       o.verifyTransferAmountRangeProof cs5
         [recipientAmountRef, .immRef zkrpTransferFid] = none)
    (fuel : Nat)
    (hfuel : fuel ≥ 23) :
    run (transferModuleEnv o)
        { code := verifyTransferProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      senderEkRef, recipientEkRef, curBalRef, newBalRef,
                      senderAmountRef, recipientAmountRef,
                      auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                      proofRef].map some).toArray,
          localRefs := (List.replicate 13 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyTransferProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    senderEkRef, recipientEkRef, curBalRef, newBalRef,
                    senderAmountRef, recipientAmountRef,
                    auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                    proofRef].map some).toArray,
        localRefs := (List.replicate 13 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 13 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_transfer_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 13 := by
    show (f0.locals.set 0 none hf0_lt0).size = 13; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_transfer_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 13 := by
    show (f1.locals.set 1 none hf1_lt1).size = 13; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_transfer_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 13 := by
    show (f2.locals.set 2 none hf2_lt2).size = 13; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some senderEkRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_transfer_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderEkRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 13 := by
    show (f3.locals.set 3 none hf3_lt3).size = 13; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some recipientEkRef := by
    show (f3.locals.set 3 none hf3_lt3)[4]'hf4_lt4 = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 4)]
    show (f2.locals.set 2 none hf2_lt2)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 4)]
    show (f1.locals.set 1 none hf1_lt1)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 4)]
    show (f0.locals.set 0 none hf0_lt0)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 4)]; simp [f0]
  have hf4_ref4 : ¬ 4 < f4.localRefs.size ∨
                  ∃ h : 4 < f4.localRefs.size, f4.localRefs[4]'h = none := by
    right; refine ⟨by simp [f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_transfer_pc4 o f4 []
                  [senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl recipientEkRef hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 13 := by
    show (f4.locals.set 4 none hf4_lt4).size = 13; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some curBalRef := by
    show (f4.locals.set 4 none hf4_lt4)[5]'hf5_lt5 = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 5)]
    show (f3.locals.set 3 none hf3_lt3)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 5)]
    show (f2.locals.set 2 none hf2_lt2)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 5)]
    show (f1.locals.set 1 none hf1_lt1)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 5)]
    show (f0.locals.set 0 none hf0_lt0)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 5)]; simp [f0]
  have hf5_ref5 : ¬ 5 < f5.localRefs.size ∨
                  ∃ h : 5 < f5.localRefs.size, f5.localRefs[5]'h = none := by
    right; refine ⟨by simp [f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_transfer_pc5 o f5 []
                  [recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 13 := by
    show (f5.locals.set 5 none hf5_lt5).size = 13; rw [Array.size_set]; exact hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some newBalRef := by
    show (f5.locals.set 5 none hf5_lt5)[6]'hf6_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]
    show (f4.locals.set 4 none hf4_lt4)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 6)]
    show (f3.locals.set 3 none hf3_lt3)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 6)]
    show (f2.locals.set 2 none hf2_lt2)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 6)]
    show (f1.locals.set 1 none hf1_lt1)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 6)]
    show (f0.locals.set 0 none hf0_lt0)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 6)]; simp [f0]
  have hf6_ref6 : ¬ 6 < f6.localRefs.size ∨
                  ∃ h : 6 < f6.localRefs.size, f6.localRefs[6]'h = none := by
    right; refine ⟨by simp [f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_transfer_pc6 o f6 []
                  [curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 13 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some senderAmountRef := by
    show f6.locals[7]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 7)]
    show (f4.locals.set 4 none hf4_lt4)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 7)]
    show (f3.locals.set 3 none hf3_lt3)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 7)]
    show (f2.locals.set 2 none hf2_lt2)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 7)]
    show (f1.locals.set 1 none hf1_lt1)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 7)]
    show (f0.locals.set 0 none hf0_lt0)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 7)]; simp [f0]
  have hf7_ref7 : ¬ 7 < f7.localRefs.size ∨
                  ∃ h : 7 < f7.localRefs.size, f7.localRefs[7]'h = none := by
    right; refine ⟨by simp [f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_transfer_pc7 o f7 []
                  [newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderAmountRef hf7_lt7 hf7_v7 hf7_ref7
  set f8 := { f7 with pc := 8, locals := f7.locals.set 7 none hf7_lt7 } with hf8_def
  have hf8_size : f8.locals.size = 13 := by
    show (f7.locals.set 7 none hf7_lt7).size = 13; rw [Array.size_set]; exact hf7_size
  have hf8_lt8 : 8 < f8.locals.size := by rw [hf8_size]; decide
  have hf8_v8 : f8.locals[8]'hf8_lt8 = some recipientAmountRef := by
    show (f7.locals.set 7 none hf7_lt7)[8]'hf8_lt8 = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 8)]
    show f6.locals[8]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 8)]
    show (f4.locals.set 4 none hf4_lt4)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 8)]
    show (f3.locals.set 3 none hf3_lt3)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 8)]
    show (f2.locals.set 2 none hf2_lt2)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 8)]
    show (f1.locals.set 1 none hf1_lt1)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 8)]
    show (f0.locals.set 0 none hf0_lt0)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 8)]; simp [f0]
  have hf8_ref8 : ¬ 8 < f8.localRefs.size ∨
                  ∃ h : 8 < f8.localRefs.size, f8.localRefs[8]'h = none := by
    right; refine ⟨by simp [f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[8]'(by simp) = none; decide
  have step9 := step_transfer_pc8 o f8 []
                  [senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl recipientAmountRef hf8_lt8 hf8_v8 hf8_ref8
  set f9 := { f8 with pc := 9 } with hf9_def
  have hf9_size : f9.locals.size = 13 := hf8_size
  have hf9_lt9 : 9 < f9.locals.size := by rw [hf9_size]; decide
  have hf9_v9 : f9.locals[9]'hf9_lt9 = some auditorEksRef := by
    show (f7.locals.set 7 none hf7_lt7)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 9)]
    show f6.locals[9]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 9)]
    show (f4.locals.set 4 none hf4_lt4)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 9)]
    show (f3.locals.set 3 none hf3_lt3)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 9)]
    show (f2.locals.set 2 none hf2_lt2)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 9)]
    show (f1.locals.set 1 none hf1_lt1)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 9)]
    show (f0.locals.set 0 none hf0_lt0)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 9)]; simp [f0]
  have hf9_ref9 : ¬ 9 < f9.localRefs.size ∨
                  ∃ h : 9 < f9.localRefs.size, f9.localRefs[9]'h = none := by
    right; refine ⟨by simp [f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[9]'(by simp) = none; decide
  have step10 := step_transfer_pc9 o f9 []
                  [recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl auditorEksRef hf9_lt9 hf9_v9 hf9_ref9
  set f10 := { f9 with pc := 10, locals := f9.locals.set 9 none hf9_lt9 } with hf10_def
  have hf10_size : f10.locals.size = 13 := by
    show (f9.locals.set 9 none hf9_lt9).size = 13; rw [Array.size_set]; exact hf9_size
  have hf10_lt10 : 10 < f10.locals.size := by rw [hf10_size]; decide
  have hf10_v10 : f10.locals[10]'hf10_lt10 = some auditorAmountsRef := by
    show (f9.locals.set 9 none hf9_lt9)[10]'hf10_lt10 = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 10)]
    show (f7.locals.set 7 none hf7_lt7)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 10)]
    show f6.locals[10]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 10)]
    show (f4.locals.set 4 none hf4_lt4)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 10)]
    show (f3.locals.set 3 none hf3_lt3)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 10)]
    show (f2.locals.set 2 none hf2_lt2)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 10)]
    show (f1.locals.set 1 none hf1_lt1)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 10)]
    show (f0.locals.set 0 none hf0_lt0)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 10)]; simp [f0]
  have hf10_ref10 : ¬ 10 < f10.localRefs.size ∨
                    ∃ h : 10 < f10.localRefs.size, f10.localRefs[10]'h = none := by
    right; refine ⟨by simp [f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[10]'(by simp) = none; decide
  have step11 := step_transfer_pc10 o f10 []
                  [auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl auditorAmountsRef hf10_lt10 hf10_v10 hf10_ref10
  set f11 := { f10 with pc := 11, locals := f10.locals.set 10 none hf10_lt10 } with hf11_def
  have hf11_size : f11.locals.size = 13 := by
    show (f10.locals.set 10 none hf10_lt10).size = 13; rw [Array.size_set]; exact hf10_size
  have hf11_lt11 : 11 < f11.locals.size := by rw [hf11_size]; decide
  have hf11_v11 : f11.locals[11]'hf11_lt11 = some senderAuditorHintRef := by
    show (f10.locals.set 10 none hf10_lt10)[11]'hf11_lt11 = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 11)]
    show (f9.locals.set 9 none hf9_lt9)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 11)]
    show (f7.locals.set 7 none hf7_lt7)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 11)]
    show f6.locals[11]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 11)]
    show (f4.locals.set 4 none hf4_lt4)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 11)]
    show (f3.locals.set 3 none hf3_lt3)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 11)]
    show (f2.locals.set 2 none hf2_lt2)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 11)]
    show (f1.locals.set 1 none hf1_lt1)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 11)]
    show (f0.locals.set 0 none hf0_lt0)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 11)]; simp [f0]
  have hf11_ref11 : ¬ 11 < f11.localRefs.size ∨
                    ∃ h : 11 < f11.localRefs.size, f11.localRefs[11]'h = none := by
    right; refine ⟨by simp [f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[11]'(by simp) = none; decide
  have step12 := step_transfer_pc11 o f11 []
                  [auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderAuditorHintRef hf11_lt11 hf11_v11 hf11_ref11
  set f12 := { f11 with pc := 12, locals := f11.locals.set 11 none hf11_lt11 } with hf12_def
  have hf12_size : f12.locals.size = 13 := by
    show (f11.locals.set 11 none hf11_lt11).size = 13; rw [Array.size_set]; exact hf11_size
  have hf12_lt12 : 12 < f12.locals.size := by rw [hf12_size]; decide
  have hf12_v12 : f12.locals[12]'hf12_lt12 = some proofRef := by
    show (f11.locals.set 11 none hf11_lt11)[12]'hf12_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 12)]
    show (f10.locals.set 10 none hf10_lt10)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 12)]
    show (f9.locals.set 9 none hf9_lt9)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 12)]
    show (f7.locals.set 7 none hf7_lt7)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 12)]
    show f6.locals[12]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 12)]
    show (f4.locals.set 4 none hf4_lt4)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 12)]
    show (f3.locals.set 3 none hf3_lt3)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 12)]
    show (f2.locals.set 2 none hf2_lt2)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 12)]
    show (f1.locals.set 1 none hf1_lt1)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 12)]
    show (f0.locals.set 0 none hf0_lt0)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 12)]; simp [f0]
  have hf12_ref12 : ¬ 12 < f12.localRefs.size ∨
                    ∃ h : 12 < f12.localRefs.size, f12.localRefs[12]'h = none := by
    right; refine ⟨by simp [f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  have step13 := step_transfer_pc12 o f12 []
                  [senderAuditorHintRef, auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf12_lt12 hf12_v12 hf12_ref12
  set f13 := { f12 with pc := 13 } with hf13_def
  have step14 := step_transfer_pc13 o f13 []
                  [senderAuditorHintRef, auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread (by omega : 0 < proofFields.length) halloc0
  set f14 := { f13 with pc := 14 } with hf14_def
  set ms14 : MachineState := { initMs with containers := cs1 } with hms14_def
  have htake_pc14 :
      takeN [(.immRef sigmaFid : MoveValue), senderAuditorHintRef, auditorAmountsRef, auditorEksRef,
              recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef,
              (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)] 13 =
        some ([.u8 chainId, .address sender, .address contract,
               senderEkRef, recipientEkRef, curBalRef, newBalRef,
               senderAmountRef, recipientAmountRef,
               auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
               .immRef sigmaFid], []) := rfl
  have step15 := step_transfer_pc14 o f14 []
                  [(.immRef sigmaFid : MoveValue), senderAuditorHintRef, auditorAmountsRef, auditorEksRef,
                    recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms14 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   senderEkRef, recipientEkRef, curBalRef, newBalRef,
                   senderAmountRef, recipientAmountRef,
                   auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                   .immRef sigmaFid]
                  [] cs2 htake_pc14 hsigmaOk
  set f15 := { f14 with pc := 15 } with hf15_def
  set ms15 : MachineState := { ms14 with containers := cs2, globals := ms14.globals } with hms15_def
  have hf15_lt6 : 6 < f15.locals.size := hf6_lt6
  have hf15_v6 : f15.locals[6]'hf15_lt6 = some newBalRef := by
    show (f11.locals.set 11 none hf11_lt11)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 6)]
    show (f10.locals.set 10 none hf10_lt10)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 6)]
    show (f9.locals.set 9 none hf9_lt9)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 6)]
    show (f7.locals.set 7 none hf7_lt7)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 6)]
    exact hf6_v6
  have hf15_ref6 : ¬ 6 < f15.localRefs.size ∨
                   ∃ h : 6 < f15.localRefs.size, f15.localRefs[6]'h = none := hf6_ref6
  have step16 := step_transfer_pc15 o f15 [] [] ms15 rfl rfl newBalRef
                   hf15_lt6 hf15_v6 hf15_ref6
  set f16 := { f15 with pc := 16, locals := f15.locals.set 6 none hf15_lt6 } with hf16_def
  have hf16_size : f16.locals.size = 13 := by
    show (f15.locals.set 6 none hf15_lt6).size = 13; rw [Array.size_set]; exact hf12_size
  have hf16_lt12 : 12 < f16.locals.size := by rw [hf16_size]; decide
  have hf16_v12 : f16.locals[12]'hf16_lt12 = some proofRef := by
    show (f15.locals.set 6 none hf15_lt6)[12]'hf16_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (6 : Nat) ≠ 12)]
    exact hf12_v12
  have hf16_ref12 : ¬ 12 < f16.localRefs.size ∨
                    ∃ h : 12 < f16.localRefs.size, f16.localRefs[12]'h = none := by
    right; refine ⟨by simp [f16, f15, f14, f13, f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  have step17 := step_transfer_pc16 o f16 [] [newBalRef] ms15 rfl rfl proofRef
                   hf16_lt12 hf16_v12 hf16_ref12
  set f17 := { f16 with pc := 17 } with hf17_def
  have hms15_read : ms15.containers.read proofRid = some (.struct_ proofFields) := by
    show cs2.read proofRid = _; exact hread2
  have step18 := step_transfer_pc17 o f17 [] [newBalRef] ms15 rfl rfl proofRid proofFields
                   cs3 zkrpNewBalFid proofRef hproofRef hms15_read (by omega : 1 < proofFields.length)
                   (show ms15.containers.alloc _ = (cs3, zkrpNewBalFid) from
                     show cs2.alloc _ = (cs3, zkrpNewBalFid) from halloc1)
  set f18 := { f17 with pc := 18 } with hf18_def
  set ms18 : MachineState := { ms15 with containers := cs3 } with hms18_def
  have htake_pc18 :
      takeN [(.immRef zkrpNewBalFid : MoveValue), newBalRef] 2 =
        some ([newBalRef, .immRef zkrpNewBalFid], []) := rfl
  have step19 := step_transfer_pc18 o f18 []
                   [(.immRef zkrpNewBalFid : MoveValue), newBalRef]
                   ms18 rfl rfl
                   [newBalRef, .immRef zkrpNewBalFid] [] cs4 htake_pc18 hNewBalRangeOk
  -- After step19: pc=19, stack=[], containers=cs4.
  set f19 := { f18 with pc := 19 } with hf19_def
  set ms19 : MachineState := { ms18 with containers := cs4, globals := ms18.globals } with hms19_def
  -- PC 19: moveLoc 8 (recipientAmountRef)
  have hf19_lt8 : 8 < f19.locals.size := hf8_lt8
  have hf19_v8 : f19.locals[8]'hf19_lt8 = some recipientAmountRef := by
    show (f15.locals.set 6 none hf15_lt6)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (6 : Nat) ≠ 8)]
    show (f11.locals.set 11 none hf11_lt11)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 8)]
    show (f10.locals.set 10 none hf10_lt10)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 8)]
    show (f9.locals.set 9 none hf9_lt9)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 8)]
    exact hf8_v8
  have hf19_ref8 : ¬ 8 < f19.localRefs.size ∨
                   ∃ h : 8 < f19.localRefs.size, f19.localRefs[8]'h = none := by
    right; refine ⟨by simp [f19, f18, f17, f16, f15, f14, f13, f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[8]'(by simp) = none; decide
  have step20 := step_transfer_pc19 o f19 [] [] ms19 rfl rfl recipientAmountRef
                   hf19_lt8 hf19_v8 hf19_ref8
  -- After step20: pc=20, stack=[recipientAmountRef], locals[8]:=none, containers=cs4.
  set f20 := { f19 with pc := 20, locals := f19.locals.set 8 none hf19_lt8 } with hf20_def
  have hf20_size : f20.locals.size = 13 := by
    show (f19.locals.set 8 none hf19_lt8).size = 13; rw [Array.size_set]; exact hf16_size
  have hf20_lt12 : 12 < f20.locals.size := by rw [hf20_size]; decide
  have hf20_v12 : f20.locals[12]'hf20_lt12 = some proofRef := by
    show (f19.locals.set 8 none hf19_lt8)[12]'hf20_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (8 : Nat) ≠ 12)]
    exact hf16_v12
  have hf20_ref12 : ¬ 12 < f20.localRefs.size ∨
                    ∃ h : 12 < f20.localRefs.size, f20.localRefs[12]'h = none := by
    right; refine ⟨by simp [f20, f19, f18, f17, f16, f15, f14, f13, f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  -- PC 20: moveLoc 12 (proofRef)
  have step21 := step_transfer_pc20 o f20 [] [recipientAmountRef] ms19 rfl rfl proofRef
                   hf20_lt12 hf20_v12 hf20_ref12
  -- After step21: pc=21, stack=[proofRef, recipientAmountRef], locals[12]:=none, containers=cs4.
  set f21 := { f20 with pc := 21, locals := f20.locals.set 12 none hf20_lt12 } with hf21_def
  have hms19_read : ms19.containers.read proofRid = some (.struct_ proofFields) := by
    show cs4.read proofRid = _; exact hread4
  have step22 := step_transfer_pc21 o f21 [] [recipientAmountRef] ms19 rfl rfl proofRid proofFields
                   cs5 zkrpTransferFid proofRef hproofRef hms19_read hFieldCount
                   (show ms19.containers.alloc _ = (cs5, zkrpTransferFid) from
                     show cs4.alloc _ = (cs5, zkrpTransferFid) from halloc2)
  -- After step22: pc=22, stack=[.immRef zkrpTransferFid, recipientAmountRef], containers=cs5.
  set f22 := { f21 with pc := 22 } with hf22_def
  set ms22 : MachineState := { ms19 with containers := cs5 } with hms22_def
  -- PC 22: transferRange call (none → error)
  have htake_pc22 :
      takeN [(.immRef zkrpTransferFid : MoveValue), recipientAmountRef] 2 =
        some ([recipientAmountRef, .immRef zkrpTransferFid], []) := rfl
  have step23 := step_transfer_pc22_none o f22 []
                   [(.immRef zkrpTransferFid : MoveValue), recipientAmountRef]
                   ms22 rfl rfl
                   [recipientAmountRef, .immRef zkrpTransferFid] [] htake_pc22 hTransferRangeFail
  -- Compose: 22 OK steps + 1 error step = 23 fuel.
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 23 := ⟨fuel - 23, by omega⟩
  rw [hef]
  rw [show ef + 23 = (ef + 22) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 22) _ _ _ _ step1,
      show ef + 22 = (ef + 21) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 21) _ _ _ _ step2,
      show ef + 21 = (ef + 20) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 20) _ _ _ _ step3,
      show ef + 20 = (ef + 19) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 19) _ _ _ _ step4,
      show ef + 19 = (ef + 18) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 18) _ _ _ _ step5,
      show ef + 18 = (ef + 17) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 17) _ _ _ _ step6,
      show ef + 17 = (ef + 16) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 16) _ _ _ _ step7,
      show ef + 16 = (ef + 15) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 15) _ _ _ _ step8,
      show ef + 15 = (ef + 14) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 14) _ _ _ _ step9,
      show ef + 14 = (ef + 13) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 13) _ _ _ _ step10,
      show ef + 13 = (ef + 12) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 12) _ _ _ _ step11,
      show ef + 12 = (ef + 11) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 11) _ _ _ _ step12,
      show ef + 11 = (ef + 10) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 10) _ _ _ _ step13,
      show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step14,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step15,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step16,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step17,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step18,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step19,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step20,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step21,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step22,
      StepLemmas.run_succ_error_of_step ef step23]

set_option maxHeartbeats 1200000 in
/-- When sigma + new-balance succeed but transfer-amount range oracle returns non-empty list,
    run produces error. Same chain as `tr_run_to_transferRange_fail_produces_error`;
    final step uses `step_transfer_pc22_multi`. -/
theorem tr_run_to_transferRange_arity_mismatch_produces_error
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 cs3 cs4 cs5 cs6 : ContainerStore)
    (sigmaFid zkrpNewBalFid zkrpTransferFid : RefId)
    (rangeResultHead : MoveValue) (rangeResultTail : List MoveValue)
    (hFieldCount : 2 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hread2 : cs2.read proofRid = some (.struct_ proofFields))
    (hread4 : cs4.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc0 : initMs.containers.alloc
                  (proofFields[0]'(by omega : 0 < proofFields.length)) = (cs1, sigmaFid))
    (hsigmaOk :
       o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                senderEkRef, recipientEkRef, curBalRef, newBalRef,
                                senderAmountRef, recipientAmountRef,
                                auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                                .immRef sigmaFid] = some ([], cs2))
    (halloc1 : cs2.alloc (proofFields[1]'(by omega : 1 < proofFields.length)) = (cs3, zkrpNewBalFid))
    (hNewBalRangeOk :
       o.verifyNewBalanceRangeProof cs3 [newBalRef, .immRef zkrpNewBalFid] = some ([], cs4))
    (halloc2 : cs4.alloc (proofFields[2]'hFieldCount) = (cs5, zkrpTransferFid))
    (hTransferRangeArity :
       o.verifyTransferAmountRangeProof cs5
         [recipientAmountRef, .immRef zkrpTransferFid] =
         some (rangeResultHead :: rangeResultTail, cs6))
    (fuel : Nat)
    (hfuel : fuel ≥ 23) :
    run (transferModuleEnv o)
        { code := verifyTransferProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      senderEkRef, recipientEkRef, curBalRef, newBalRef,
                      senderAmountRef, recipientAmountRef,
                      auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                      proofRef].map some).toArray,
          localRefs := (List.replicate 13 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyTransferProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    senderEkRef, recipientEkRef, curBalRef, newBalRef,
                    senderAmountRef, recipientAmountRef,
                    auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                    proofRef].map some).toArray,
        localRefs := (List.replicate 13 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 13 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_transfer_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 13 := by
    show (f0.locals.set 0 none hf0_lt0).size = 13; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_transfer_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 13 := by
    show (f1.locals.set 1 none hf1_lt1).size = 13; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_transfer_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 13 := by
    show (f2.locals.set 2 none hf2_lt2).size = 13; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some senderEkRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_transfer_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderEkRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 13 := by
    show (f3.locals.set 3 none hf3_lt3).size = 13; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some recipientEkRef := by
    show (f3.locals.set 3 none hf3_lt3)[4]'hf4_lt4 = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 4)]
    show (f2.locals.set 2 none hf2_lt2)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 4)]
    show (f1.locals.set 1 none hf1_lt1)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 4)]
    show (f0.locals.set 0 none hf0_lt0)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 4)]; simp [f0]
  have hf4_ref4 : ¬ 4 < f4.localRefs.size ∨
                  ∃ h : 4 < f4.localRefs.size, f4.localRefs[4]'h = none := by
    right; refine ⟨by simp [f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_transfer_pc4 o f4 []
                  [senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl recipientEkRef hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 13 := by
    show (f4.locals.set 4 none hf4_lt4).size = 13; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some curBalRef := by
    show (f4.locals.set 4 none hf4_lt4)[5]'hf5_lt5 = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 5)]
    show (f3.locals.set 3 none hf3_lt3)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 5)]
    show (f2.locals.set 2 none hf2_lt2)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 5)]
    show (f1.locals.set 1 none hf1_lt1)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 5)]
    show (f0.locals.set 0 none hf0_lt0)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 5)]; simp [f0]
  have hf5_ref5 : ¬ 5 < f5.localRefs.size ∨
                  ∃ h : 5 < f5.localRefs.size, f5.localRefs[5]'h = none := by
    right; refine ⟨by simp [f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_transfer_pc5 o f5 []
                  [recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 13 := by
    show (f5.locals.set 5 none hf5_lt5).size = 13; rw [Array.size_set]; exact hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some newBalRef := by
    show (f5.locals.set 5 none hf5_lt5)[6]'hf6_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]
    show (f4.locals.set 4 none hf4_lt4)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 6)]
    show (f3.locals.set 3 none hf3_lt3)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 6)]
    show (f2.locals.set 2 none hf2_lt2)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 6)]
    show (f1.locals.set 1 none hf1_lt1)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 6)]
    show (f0.locals.set 0 none hf0_lt0)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 6)]; simp [f0]
  have hf6_ref6 : ¬ 6 < f6.localRefs.size ∨
                  ∃ h : 6 < f6.localRefs.size, f6.localRefs[6]'h = none := by
    right; refine ⟨by simp [f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_transfer_pc6 o f6 []
                  [curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 13 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some senderAmountRef := by
    show f6.locals[7]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 7)]
    show (f4.locals.set 4 none hf4_lt4)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 7)]
    show (f3.locals.set 3 none hf3_lt3)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 7)]
    show (f2.locals.set 2 none hf2_lt2)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 7)]
    show (f1.locals.set 1 none hf1_lt1)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 7)]
    show (f0.locals.set 0 none hf0_lt0)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 7)]; simp [f0]
  have hf7_ref7 : ¬ 7 < f7.localRefs.size ∨
                  ∃ h : 7 < f7.localRefs.size, f7.localRefs[7]'h = none := by
    right; refine ⟨by simp [f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_transfer_pc7 o f7 []
                  [newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderAmountRef hf7_lt7 hf7_v7 hf7_ref7
  set f8 := { f7 with pc := 8, locals := f7.locals.set 7 none hf7_lt7 } with hf8_def
  have hf8_size : f8.locals.size = 13 := by
    show (f7.locals.set 7 none hf7_lt7).size = 13; rw [Array.size_set]; exact hf7_size
  have hf8_lt8 : 8 < f8.locals.size := by rw [hf8_size]; decide
  have hf8_v8 : f8.locals[8]'hf8_lt8 = some recipientAmountRef := by
    show (f7.locals.set 7 none hf7_lt7)[8]'hf8_lt8 = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 8)]
    show f6.locals[8]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 8)]
    show (f4.locals.set 4 none hf4_lt4)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 8)]
    show (f3.locals.set 3 none hf3_lt3)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 8)]
    show (f2.locals.set 2 none hf2_lt2)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 8)]
    show (f1.locals.set 1 none hf1_lt1)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 8)]
    show (f0.locals.set 0 none hf0_lt0)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 8)]; simp [f0]
  have hf8_ref8 : ¬ 8 < f8.localRefs.size ∨
                  ∃ h : 8 < f8.localRefs.size, f8.localRefs[8]'h = none := by
    right; refine ⟨by simp [f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[8]'(by simp) = none; decide
  have step9 := step_transfer_pc8 o f8 []
                  [senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl recipientAmountRef hf8_lt8 hf8_v8 hf8_ref8
  set f9 := { f8 with pc := 9 } with hf9_def
  have hf9_size : f9.locals.size = 13 := hf8_size
  have hf9_lt9 : 9 < f9.locals.size := by rw [hf9_size]; decide
  have hf9_v9 : f9.locals[9]'hf9_lt9 = some auditorEksRef := by
    show (f7.locals.set 7 none hf7_lt7)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 9)]
    show f6.locals[9]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 9)]
    show (f4.locals.set 4 none hf4_lt4)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 9)]
    show (f3.locals.set 3 none hf3_lt3)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 9)]
    show (f2.locals.set 2 none hf2_lt2)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 9)]
    show (f1.locals.set 1 none hf1_lt1)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 9)]
    show (f0.locals.set 0 none hf0_lt0)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 9)]; simp [f0]
  have hf9_ref9 : ¬ 9 < f9.localRefs.size ∨
                  ∃ h : 9 < f9.localRefs.size, f9.localRefs[9]'h = none := by
    right; refine ⟨by simp [f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[9]'(by simp) = none; decide
  have step10 := step_transfer_pc9 o f9 []
                  [recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl auditorEksRef hf9_lt9 hf9_v9 hf9_ref9
  set f10 := { f9 with pc := 10, locals := f9.locals.set 9 none hf9_lt9 } with hf10_def
  have hf10_size : f10.locals.size = 13 := by
    show (f9.locals.set 9 none hf9_lt9).size = 13; rw [Array.size_set]; exact hf9_size
  have hf10_lt10 : 10 < f10.locals.size := by rw [hf10_size]; decide
  have hf10_v10 : f10.locals[10]'hf10_lt10 = some auditorAmountsRef := by
    show (f9.locals.set 9 none hf9_lt9)[10]'hf10_lt10 = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 10)]
    show (f7.locals.set 7 none hf7_lt7)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 10)]
    show f6.locals[10]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 10)]
    show (f4.locals.set 4 none hf4_lt4)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 10)]
    show (f3.locals.set 3 none hf3_lt3)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 10)]
    show (f2.locals.set 2 none hf2_lt2)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 10)]
    show (f1.locals.set 1 none hf1_lt1)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 10)]
    show (f0.locals.set 0 none hf0_lt0)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 10)]; simp [f0]
  have hf10_ref10 : ¬ 10 < f10.localRefs.size ∨
                    ∃ h : 10 < f10.localRefs.size, f10.localRefs[10]'h = none := by
    right; refine ⟨by simp [f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[10]'(by simp) = none; decide
  have step11 := step_transfer_pc10 o f10 []
                  [auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl auditorAmountsRef hf10_lt10 hf10_v10 hf10_ref10
  set f11 := { f10 with pc := 11, locals := f10.locals.set 10 none hf10_lt10 } with hf11_def
  have hf11_size : f11.locals.size = 13 := by
    show (f10.locals.set 10 none hf10_lt10).size = 13; rw [Array.size_set]; exact hf10_size
  have hf11_lt11 : 11 < f11.locals.size := by rw [hf11_size]; decide
  have hf11_v11 : f11.locals[11]'hf11_lt11 = some senderAuditorHintRef := by
    show (f10.locals.set 10 none hf10_lt10)[11]'hf11_lt11 = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 11)]
    show (f9.locals.set 9 none hf9_lt9)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 11)]
    show (f7.locals.set 7 none hf7_lt7)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 11)]
    show f6.locals[11]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 11)]
    show (f4.locals.set 4 none hf4_lt4)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 11)]
    show (f3.locals.set 3 none hf3_lt3)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 11)]
    show (f2.locals.set 2 none hf2_lt2)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 11)]
    show (f1.locals.set 1 none hf1_lt1)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 11)]
    show (f0.locals.set 0 none hf0_lt0)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 11)]; simp [f0]
  have hf11_ref11 : ¬ 11 < f11.localRefs.size ∨
                    ∃ h : 11 < f11.localRefs.size, f11.localRefs[11]'h = none := by
    right; refine ⟨by simp [f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[11]'(by simp) = none; decide
  have step12 := step_transfer_pc11 o f11 []
                  [auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderAuditorHintRef hf11_lt11 hf11_v11 hf11_ref11
  set f12 := { f11 with pc := 12, locals := f11.locals.set 11 none hf11_lt11 } with hf12_def
  have hf12_size : f12.locals.size = 13 := by
    show (f11.locals.set 11 none hf11_lt11).size = 13; rw [Array.size_set]; exact hf11_size
  have hf12_lt12 : 12 < f12.locals.size := by rw [hf12_size]; decide
  have hf12_v12 : f12.locals[12]'hf12_lt12 = some proofRef := by
    show (f11.locals.set 11 none hf11_lt11)[12]'hf12_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 12)]
    show (f10.locals.set 10 none hf10_lt10)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 12)]
    show (f9.locals.set 9 none hf9_lt9)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 12)]
    show (f7.locals.set 7 none hf7_lt7)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 12)]
    show f6.locals[12]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 12)]
    show (f4.locals.set 4 none hf4_lt4)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 12)]
    show (f3.locals.set 3 none hf3_lt3)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 12)]
    show (f2.locals.set 2 none hf2_lt2)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 12)]
    show (f1.locals.set 1 none hf1_lt1)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 12)]
    show (f0.locals.set 0 none hf0_lt0)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 12)]; simp [f0]
  have hf12_ref12 : ¬ 12 < f12.localRefs.size ∨
                    ∃ h : 12 < f12.localRefs.size, f12.localRefs[12]'h = none := by
    right; refine ⟨by simp [f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  have step13 := step_transfer_pc12 o f12 []
                  [senderAuditorHintRef, auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf12_lt12 hf12_v12 hf12_ref12
  set f13 := { f12 with pc := 13 } with hf13_def
  have step14 := step_transfer_pc13 o f13 []
                  [senderAuditorHintRef, auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread (by omega : 0 < proofFields.length) halloc0
  set f14 := { f13 with pc := 14 } with hf14_def
  set ms14 : MachineState := { initMs with containers := cs1 } with hms14_def
  have htake_pc14 :
      takeN [(.immRef sigmaFid : MoveValue), senderAuditorHintRef, auditorAmountsRef, auditorEksRef,
              recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef,
              (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)] 13 =
        some ([.u8 chainId, .address sender, .address contract,
               senderEkRef, recipientEkRef, curBalRef, newBalRef,
               senderAmountRef, recipientAmountRef,
               auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
               .immRef sigmaFid], []) := rfl
  have step15 := step_transfer_pc14 o f14 []
                  [(.immRef sigmaFid : MoveValue), senderAuditorHintRef, auditorAmountsRef, auditorEksRef,
                    recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms14 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   senderEkRef, recipientEkRef, curBalRef, newBalRef,
                   senderAmountRef, recipientAmountRef,
                   auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                   .immRef sigmaFid]
                  [] cs2 htake_pc14 hsigmaOk
  set f15 := { f14 with pc := 15 } with hf15_def
  set ms15 : MachineState := { ms14 with containers := cs2, globals := ms14.globals } with hms15_def
  have hf15_lt6 : 6 < f15.locals.size := hf6_lt6
  have hf15_v6 : f15.locals[6]'hf15_lt6 = some newBalRef := by
    show (f11.locals.set 11 none hf11_lt11)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 6)]
    show (f10.locals.set 10 none hf10_lt10)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 6)]
    show (f9.locals.set 9 none hf9_lt9)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 6)]
    show (f7.locals.set 7 none hf7_lt7)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 6)]
    exact hf6_v6
  have hf15_ref6 : ¬ 6 < f15.localRefs.size ∨
                   ∃ h : 6 < f15.localRefs.size, f15.localRefs[6]'h = none := hf6_ref6
  have step16 := step_transfer_pc15 o f15 [] [] ms15 rfl rfl newBalRef
                   hf15_lt6 hf15_v6 hf15_ref6
  set f16 := { f15 with pc := 16, locals := f15.locals.set 6 none hf15_lt6 } with hf16_def
  have hf16_size : f16.locals.size = 13 := by
    show (f15.locals.set 6 none hf15_lt6).size = 13; rw [Array.size_set]; exact hf12_size
  have hf16_lt12 : 12 < f16.locals.size := by rw [hf16_size]; decide
  have hf16_v12 : f16.locals[12]'hf16_lt12 = some proofRef := by
    show (f15.locals.set 6 none hf15_lt6)[12]'hf16_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (6 : Nat) ≠ 12)]
    exact hf12_v12
  have hf16_ref12 : ¬ 12 < f16.localRefs.size ∨
                    ∃ h : 12 < f16.localRefs.size, f16.localRefs[12]'h = none := by
    right; refine ⟨by simp [f16, f15, f14, f13, f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  have step17 := step_transfer_pc16 o f16 [] [newBalRef] ms15 rfl rfl proofRef
                   hf16_lt12 hf16_v12 hf16_ref12
  set f17 := { f16 with pc := 17 } with hf17_def
  have hms15_read : ms15.containers.read proofRid = some (.struct_ proofFields) := by
    show cs2.read proofRid = _; exact hread2
  have step18 := step_transfer_pc17 o f17 [] [newBalRef] ms15 rfl rfl proofRid proofFields
                   cs3 zkrpNewBalFid proofRef hproofRef hms15_read (by omega : 1 < proofFields.length)
                   (show ms15.containers.alloc _ = (cs3, zkrpNewBalFid) from
                     show cs2.alloc _ = (cs3, zkrpNewBalFid) from halloc1)
  set f18 := { f17 with pc := 18 } with hf18_def
  set ms18 : MachineState := { ms15 with containers := cs3 } with hms18_def
  have htake_pc18 :
      takeN [(.immRef zkrpNewBalFid : MoveValue), newBalRef] 2 =
        some ([newBalRef, .immRef zkrpNewBalFid], []) := rfl
  have step19 := step_transfer_pc18 o f18 []
                   [(.immRef zkrpNewBalFid : MoveValue), newBalRef]
                   ms18 rfl rfl
                   [newBalRef, .immRef zkrpNewBalFid] [] cs4 htake_pc18 hNewBalRangeOk
  set f19 := { f18 with pc := 19 } with hf19_def
  set ms19 : MachineState := { ms18 with containers := cs4, globals := ms18.globals } with hms19_def
  have hf19_lt8 : 8 < f19.locals.size := hf8_lt8
  have hf19_v8 : f19.locals[8]'hf19_lt8 = some recipientAmountRef := by
    show (f15.locals.set 6 none hf15_lt6)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (6 : Nat) ≠ 8)]
    show (f11.locals.set 11 none hf11_lt11)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 8)]
    show (f10.locals.set 10 none hf10_lt10)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 8)]
    show (f9.locals.set 9 none hf9_lt9)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 8)]
    exact hf8_v8
  have hf19_ref8 : ¬ 8 < f19.localRefs.size ∨
                   ∃ h : 8 < f19.localRefs.size, f19.localRefs[8]'h = none := by
    right; refine ⟨by simp [f19, f18, f17, f16, f15, f14, f13, f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[8]'(by simp) = none; decide
  have step20 := step_transfer_pc19 o f19 [] [] ms19 rfl rfl recipientAmountRef
                   hf19_lt8 hf19_v8 hf19_ref8
  set f20 := { f19 with pc := 20, locals := f19.locals.set 8 none hf19_lt8 } with hf20_def
  have hf20_size : f20.locals.size = 13 := by
    show (f19.locals.set 8 none hf19_lt8).size = 13; rw [Array.size_set]; exact hf16_size
  have hf20_lt12 : 12 < f20.locals.size := by rw [hf20_size]; decide
  have hf20_v12 : f20.locals[12]'hf20_lt12 = some proofRef := by
    show (f19.locals.set 8 none hf19_lt8)[12]'hf20_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (8 : Nat) ≠ 12)]
    exact hf16_v12
  have hf20_ref12 : ¬ 12 < f20.localRefs.size ∨
                    ∃ h : 12 < f20.localRefs.size, f20.localRefs[12]'h = none := by
    right; refine ⟨by simp [f20, f19, f18, f17, f16, f15, f14, f13, f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  have step21 := step_transfer_pc20 o f20 [] [recipientAmountRef] ms19 rfl rfl proofRef
                   hf20_lt12 hf20_v12 hf20_ref12
  set f21 := { f20 with pc := 21, locals := f20.locals.set 12 none hf20_lt12 } with hf21_def
  have hms19_read : ms19.containers.read proofRid = some (.struct_ proofFields) := by
    show cs4.read proofRid = _; exact hread4
  have step22 := step_transfer_pc21 o f21 [] [recipientAmountRef] ms19 rfl rfl proofRid proofFields
                   cs5 zkrpTransferFid proofRef hproofRef hms19_read hFieldCount
                   (show ms19.containers.alloc _ = (cs5, zkrpTransferFid) from
                     show cs4.alloc _ = (cs5, zkrpTransferFid) from halloc2)
  set f22 := { f21 with pc := 22 } with hf22_def
  set ms22 : MachineState := { ms19 with containers := cs5 } with hms22_def
  have htake_pc22 :
      takeN [(.immRef zkrpTransferFid : MoveValue), recipientAmountRef] 2 =
        some ([recipientAmountRef, .immRef zkrpTransferFid], []) := rfl
  have step23 := step_transfer_pc22_multi o f22 []
                   [(.immRef zkrpTransferFid : MoveValue), recipientAmountRef]
                   ms22 rfl rfl
                   [recipientAmountRef, .immRef zkrpTransferFid] []
                   rangeResultHead rangeResultTail cs6 htake_pc22 hTransferRangeArity
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 23 := ⟨fuel - 23, by omega⟩
  rw [hef]
  rw [show ef + 23 = (ef + 22) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 22) _ _ _ _ step1,
      show ef + 22 = (ef + 21) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 21) _ _ _ _ step2,
      show ef + 21 = (ef + 20) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 20) _ _ _ _ step3,
      show ef + 20 = (ef + 19) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 19) _ _ _ _ step4,
      show ef + 19 = (ef + 18) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 18) _ _ _ _ step5,
      show ef + 18 = (ef + 17) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 17) _ _ _ _ step6,
      show ef + 17 = (ef + 16) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 16) _ _ _ _ step7,
      show ef + 16 = (ef + 15) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 15) _ _ _ _ step8,
      show ef + 15 = (ef + 14) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 14) _ _ _ _ step9,
      show ef + 14 = (ef + 13) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 13) _ _ _ _ step10,
      show ef + 13 = (ef + 12) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 12) _ _ _ _ step11,
      show ef + 12 = (ef + 11) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 11) _ _ _ _ step12,
      show ef + 11 = (ef + 10) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 10) _ _ _ _ step13,
      show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step14,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step15,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step16,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step17,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step18,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step19,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step20,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step21,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step22,
      StepLemmas.run_succ_error_of_step ef step23]

set_option maxHeartbeats 1200000 in
/-- Happy path: sigma + new-balance + transfer-amount succeed, ret. Run produces
    `.returned [] ms_final`. -/
theorem tr_run_to_success_produces_returned
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 cs3 cs4 cs5 cs6 : ContainerStore)
    (sigmaFid zkrpNewBalFid zkrpTransferFid : RefId)
    (hFieldCount : 2 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hread2 : cs2.read proofRid = some (.struct_ proofFields))
    (hread4 : cs4.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc0 : initMs.containers.alloc
                  (proofFields[0]'(by omega : 0 < proofFields.length)) = (cs1, sigmaFid))
    (hsigmaOk :
       o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                senderEkRef, recipientEkRef, curBalRef, newBalRef,
                                senderAmountRef, recipientAmountRef,
                                auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                                .immRef sigmaFid] = some ([], cs2))
    (halloc1 : cs2.alloc (proofFields[1]'(by omega : 1 < proofFields.length)) = (cs3, zkrpNewBalFid))
    (hNewBalRangeOk :
       o.verifyNewBalanceRangeProof cs3 [newBalRef, .immRef zkrpNewBalFid] = some ([], cs4))
    (halloc2 : cs4.alloc (proofFields[2]'hFieldCount) = (cs5, zkrpTransferFid))
    (hTransferRangeOk :
       o.verifyTransferAmountRangeProof cs5
         [recipientAmountRef, .immRef zkrpTransferFid] = some ([], cs6))
    (fuel : Nat)
    (hfuel : fuel ≥ 24) :
    run (transferModuleEnv o)
        { code := verifyTransferProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      senderEkRef, recipientEkRef, curBalRef, newBalRef,
                      senderAmountRef, recipientAmountRef,
                      auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                      proofRef].map some).toArray,
          localRefs := (List.replicate 13 none).toArray }
        [] [] initMs fuel =
    .returned [] { initMs with containers := cs6, globals := initMs.globals } := by
  set f0 : Frame :=
      { code := verifyTransferProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    senderEkRef, recipientEkRef, curBalRef, newBalRef,
                    senderAmountRef, recipientAmountRef,
                    auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                    proofRef].map some).toArray,
        localRefs := (List.replicate 13 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 13 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_transfer_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 13 := by
    show (f0.locals.set 0 none hf0_lt0).size = 13; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_transfer_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 13 := by
    show (f1.locals.set 1 none hf1_lt1).size = 13; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_transfer_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 13 := by
    show (f2.locals.set 2 none hf2_lt2).size = 13; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some senderEkRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_transfer_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderEkRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 13 := by
    show (f3.locals.set 3 none hf3_lt3).size = 13; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some recipientEkRef := by
    show (f3.locals.set 3 none hf3_lt3)[4]'hf4_lt4 = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 4)]
    show (f2.locals.set 2 none hf2_lt2)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 4)]
    show (f1.locals.set 1 none hf1_lt1)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 4)]
    show (f0.locals.set 0 none hf0_lt0)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 4)]; simp [f0]
  have hf4_ref4 : ¬ 4 < f4.localRefs.size ∨
                  ∃ h : 4 < f4.localRefs.size, f4.localRefs[4]'h = none := by
    right; refine ⟨by simp [f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_transfer_pc4 o f4 []
                  [senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl recipientEkRef hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 13 := by
    show (f4.locals.set 4 none hf4_lt4).size = 13; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some curBalRef := by
    show (f4.locals.set 4 none hf4_lt4)[5]'hf5_lt5 = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 5)]
    show (f3.locals.set 3 none hf3_lt3)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 5)]
    show (f2.locals.set 2 none hf2_lt2)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 5)]
    show (f1.locals.set 1 none hf1_lt1)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 5)]
    show (f0.locals.set 0 none hf0_lt0)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 5)]; simp [f0]
  have hf5_ref5 : ¬ 5 < f5.localRefs.size ∨
                  ∃ h : 5 < f5.localRefs.size, f5.localRefs[5]'h = none := by
    right; refine ⟨by simp [f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_transfer_pc5 o f5 []
                  [recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 13 := by
    show (f5.locals.set 5 none hf5_lt5).size = 13; rw [Array.size_set]; exact hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some newBalRef := by
    show (f5.locals.set 5 none hf5_lt5)[6]'hf6_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]
    show (f4.locals.set 4 none hf4_lt4)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 6)]
    show (f3.locals.set 3 none hf3_lt3)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 6)]
    show (f2.locals.set 2 none hf2_lt2)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 6)]
    show (f1.locals.set 1 none hf1_lt1)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 6)]
    show (f0.locals.set 0 none hf0_lt0)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 6)]; simp [f0]
  have hf6_ref6 : ¬ 6 < f6.localRefs.size ∨
                  ∃ h : 6 < f6.localRefs.size, f6.localRefs[6]'h = none := by
    right; refine ⟨by simp [f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_transfer_pc6 o f6 []
                  [curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 13 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some senderAmountRef := by
    show f6.locals[7]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 7)]
    show (f4.locals.set 4 none hf4_lt4)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 7)]
    show (f3.locals.set 3 none hf3_lt3)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 7)]
    show (f2.locals.set 2 none hf2_lt2)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 7)]
    show (f1.locals.set 1 none hf1_lt1)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 7)]
    show (f0.locals.set 0 none hf0_lt0)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 7)]; simp [f0]
  have hf7_ref7 : ¬ 7 < f7.localRefs.size ∨
                  ∃ h : 7 < f7.localRefs.size, f7.localRefs[7]'h = none := by
    right; refine ⟨by simp [f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_transfer_pc7 o f7 []
                  [newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderAmountRef hf7_lt7 hf7_v7 hf7_ref7
  set f8 := { f7 with pc := 8, locals := f7.locals.set 7 none hf7_lt7 } with hf8_def
  have hf8_size : f8.locals.size = 13 := by
    show (f7.locals.set 7 none hf7_lt7).size = 13; rw [Array.size_set]; exact hf7_size
  have hf8_lt8 : 8 < f8.locals.size := by rw [hf8_size]; decide
  have hf8_v8 : f8.locals[8]'hf8_lt8 = some recipientAmountRef := by
    show (f7.locals.set 7 none hf7_lt7)[8]'hf8_lt8 = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 8)]
    show f6.locals[8]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 8)]
    show (f4.locals.set 4 none hf4_lt4)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 8)]
    show (f3.locals.set 3 none hf3_lt3)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 8)]
    show (f2.locals.set 2 none hf2_lt2)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 8)]
    show (f1.locals.set 1 none hf1_lt1)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 8)]
    show (f0.locals.set 0 none hf0_lt0)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 8)]; simp [f0]
  have hf8_ref8 : ¬ 8 < f8.localRefs.size ∨
                  ∃ h : 8 < f8.localRefs.size, f8.localRefs[8]'h = none := by
    right; refine ⟨by simp [f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[8]'(by simp) = none; decide
  have step9 := step_transfer_pc8 o f8 []
                  [senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl recipientAmountRef hf8_lt8 hf8_v8 hf8_ref8
  set f9 := { f8 with pc := 9 } with hf9_def
  have hf9_size : f9.locals.size = 13 := hf8_size
  have hf9_lt9 : 9 < f9.locals.size := by rw [hf9_size]; decide
  have hf9_v9 : f9.locals[9]'hf9_lt9 = some auditorEksRef := by
    show (f7.locals.set 7 none hf7_lt7)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 9)]
    show f6.locals[9]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 9)]
    show (f4.locals.set 4 none hf4_lt4)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 9)]
    show (f3.locals.set 3 none hf3_lt3)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 9)]
    show (f2.locals.set 2 none hf2_lt2)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 9)]
    show (f1.locals.set 1 none hf1_lt1)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 9)]
    show (f0.locals.set 0 none hf0_lt0)[9]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 9)]; simp [f0]
  have hf9_ref9 : ¬ 9 < f9.localRefs.size ∨
                  ∃ h : 9 < f9.localRefs.size, f9.localRefs[9]'h = none := by
    right; refine ⟨by simp [f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[9]'(by simp) = none; decide
  have step10 := step_transfer_pc9 o f9 []
                  [recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl auditorEksRef hf9_lt9 hf9_v9 hf9_ref9
  set f10 := { f9 with pc := 10, locals := f9.locals.set 9 none hf9_lt9 } with hf10_def
  have hf10_size : f10.locals.size = 13 := by
    show (f9.locals.set 9 none hf9_lt9).size = 13; rw [Array.size_set]; exact hf9_size
  have hf10_lt10 : 10 < f10.locals.size := by rw [hf10_size]; decide
  have hf10_v10 : f10.locals[10]'hf10_lt10 = some auditorAmountsRef := by
    show (f9.locals.set 9 none hf9_lt9)[10]'hf10_lt10 = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 10)]
    show (f7.locals.set 7 none hf7_lt7)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 10)]
    show f6.locals[10]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 10)]
    show (f4.locals.set 4 none hf4_lt4)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 10)]
    show (f3.locals.set 3 none hf3_lt3)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 10)]
    show (f2.locals.set 2 none hf2_lt2)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 10)]
    show (f1.locals.set 1 none hf1_lt1)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 10)]
    show (f0.locals.set 0 none hf0_lt0)[10]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 10)]; simp [f0]
  have hf10_ref10 : ¬ 10 < f10.localRefs.size ∨
                    ∃ h : 10 < f10.localRefs.size, f10.localRefs[10]'h = none := by
    right; refine ⟨by simp [f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[10]'(by simp) = none; decide
  have step11 := step_transfer_pc10 o f10 []
                  [auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl auditorAmountsRef hf10_lt10 hf10_v10 hf10_ref10
  set f11 := { f10 with pc := 11, locals := f10.locals.set 10 none hf10_lt10 } with hf11_def
  have hf11_size : f11.locals.size = 13 := by
    show (f10.locals.set 10 none hf10_lt10).size = 13; rw [Array.size_set]; exact hf10_size
  have hf11_lt11 : 11 < f11.locals.size := by rw [hf11_size]; decide
  have hf11_v11 : f11.locals[11]'hf11_lt11 = some senderAuditorHintRef := by
    show (f10.locals.set 10 none hf10_lt10)[11]'hf11_lt11 = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 11)]
    show (f9.locals.set 9 none hf9_lt9)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 11)]
    show (f7.locals.set 7 none hf7_lt7)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 11)]
    show f6.locals[11]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 11)]
    show (f4.locals.set 4 none hf4_lt4)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 11)]
    show (f3.locals.set 3 none hf3_lt3)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 11)]
    show (f2.locals.set 2 none hf2_lt2)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 11)]
    show (f1.locals.set 1 none hf1_lt1)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 11)]
    show (f0.locals.set 0 none hf0_lt0)[11]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 11)]; simp [f0]
  have hf11_ref11 : ¬ 11 < f11.localRefs.size ∨
                    ∃ h : 11 < f11.localRefs.size, f11.localRefs[11]'h = none := by
    right; refine ⟨by simp [f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[11]'(by simp) = none; decide
  have step12 := step_transfer_pc11 o f11 []
                  [auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl senderAuditorHintRef hf11_lt11 hf11_v11 hf11_ref11
  set f12 := { f11 with pc := 12, locals := f11.locals.set 11 none hf11_lt11 } with hf12_def
  have hf12_size : f12.locals.size = 13 := by
    show (f11.locals.set 11 none hf11_lt11).size = 13; rw [Array.size_set]; exact hf11_size
  have hf12_lt12 : 12 < f12.locals.size := by rw [hf12_size]; decide
  have hf12_v12 : f12.locals[12]'hf12_lt12 = some proofRef := by
    show (f11.locals.set 11 none hf11_lt11)[12]'hf12_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 12)]
    show (f10.locals.set 10 none hf10_lt10)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 12)]
    show (f9.locals.set 9 none hf9_lt9)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 12)]
    show (f7.locals.set 7 none hf7_lt7)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 12)]
    show f6.locals[12]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 12)]
    show (f4.locals.set 4 none hf4_lt4)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 12)]
    show (f3.locals.set 3 none hf3_lt3)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 12)]
    show (f2.locals.set 2 none hf2_lt2)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 12)]
    show (f1.locals.set 1 none hf1_lt1)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 12)]
    show (f0.locals.set 0 none hf0_lt0)[12]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 12)]; simp [f0]
  have hf12_ref12 : ¬ 12 < f12.localRefs.size ∨
                    ∃ h : 12 < f12.localRefs.size, f12.localRefs[12]'h = none := by
    right; refine ⟨by simp [f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  have step13 := step_transfer_pc12 o f12 []
                  [senderAuditorHintRef, auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf12_lt12 hf12_v12 hf12_ref12
  set f13 := { f12 with pc := 13 } with hf13_def
  have step14 := step_transfer_pc13 o f13 []
                  [senderAuditorHintRef, auditorAmountsRef, auditorEksRef, recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread (by omega : 0 < proofFields.length) halloc0
  set f14 := { f13 with pc := 14 } with hf14_def
  set ms14 : MachineState := { initMs with containers := cs1 } with hms14_def
  have htake_pc14 :
      takeN [(.immRef sigmaFid : MoveValue), senderAuditorHintRef, auditorAmountsRef, auditorEksRef,
              recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef,
              (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)] 13 =
        some ([.u8 chainId, .address sender, .address contract,
               senderEkRef, recipientEkRef, curBalRef, newBalRef,
               senderAmountRef, recipientAmountRef,
               auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
               .immRef sigmaFid], []) := rfl
  have step15 := step_transfer_pc14 o f14 []
                  [(.immRef sigmaFid : MoveValue), senderAuditorHintRef, auditorAmountsRef, auditorEksRef,
                    recipientAmountRef, senderAmountRef, newBalRef, curBalRef, recipientEkRef, senderEkRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms14 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   senderEkRef, recipientEkRef, curBalRef, newBalRef,
                   senderAmountRef, recipientAmountRef,
                   auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                   .immRef sigmaFid]
                  [] cs2 htake_pc14 hsigmaOk
  set f15 := { f14 with pc := 15 } with hf15_def
  set ms15 : MachineState := { ms14 with containers := cs2, globals := ms14.globals } with hms15_def
  have hf15_lt6 : 6 < f15.locals.size := hf6_lt6
  have hf15_v6 : f15.locals[6]'hf15_lt6 = some newBalRef := by
    show (f11.locals.set 11 none hf11_lt11)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 6)]
    show (f10.locals.set 10 none hf10_lt10)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 6)]
    show (f9.locals.set 9 none hf9_lt9)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 6)]
    show (f7.locals.set 7 none hf7_lt7)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (7 : Nat) ≠ 6)]
    exact hf6_v6
  have hf15_ref6 : ¬ 6 < f15.localRefs.size ∨
                   ∃ h : 6 < f15.localRefs.size, f15.localRefs[6]'h = none := hf6_ref6
  have step16 := step_transfer_pc15 o f15 [] [] ms15 rfl rfl newBalRef
                   hf15_lt6 hf15_v6 hf15_ref6
  set f16 := { f15 with pc := 16, locals := f15.locals.set 6 none hf15_lt6 } with hf16_def
  have hf16_size : f16.locals.size = 13 := by
    show (f15.locals.set 6 none hf15_lt6).size = 13; rw [Array.size_set]; exact hf12_size
  have hf16_lt12 : 12 < f16.locals.size := by rw [hf16_size]; decide
  have hf16_v12 : f16.locals[12]'hf16_lt12 = some proofRef := by
    show (f15.locals.set 6 none hf15_lt6)[12]'hf16_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (6 : Nat) ≠ 12)]
    exact hf12_v12
  have hf16_ref12 : ¬ 12 < f16.localRefs.size ∨
                    ∃ h : 12 < f16.localRefs.size, f16.localRefs[12]'h = none := by
    right; refine ⟨by simp [f16, f15, f14, f13, f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  have step17 := step_transfer_pc16 o f16 [] [newBalRef] ms15 rfl rfl proofRef
                   hf16_lt12 hf16_v12 hf16_ref12
  set f17 := { f16 with pc := 17 } with hf17_def
  have hms15_read : ms15.containers.read proofRid = some (.struct_ proofFields) := by
    show cs2.read proofRid = _; exact hread2
  have step18 := step_transfer_pc17 o f17 [] [newBalRef] ms15 rfl rfl proofRid proofFields
                   cs3 zkrpNewBalFid proofRef hproofRef hms15_read (by omega : 1 < proofFields.length)
                   (show ms15.containers.alloc _ = (cs3, zkrpNewBalFid) from
                     show cs2.alloc _ = (cs3, zkrpNewBalFid) from halloc1)
  set f18 := { f17 with pc := 18 } with hf18_def
  set ms18 : MachineState := { ms15 with containers := cs3 } with hms18_def
  have htake_pc18 :
      takeN [(.immRef zkrpNewBalFid : MoveValue), newBalRef] 2 =
        some ([newBalRef, .immRef zkrpNewBalFid], []) := rfl
  have step19 := step_transfer_pc18 o f18 []
                   [(.immRef zkrpNewBalFid : MoveValue), newBalRef]
                   ms18 rfl rfl
                   [newBalRef, .immRef zkrpNewBalFid] [] cs4 htake_pc18 hNewBalRangeOk
  set f19 := { f18 with pc := 19 } with hf19_def
  set ms19 : MachineState := { ms18 with containers := cs4, globals := ms18.globals } with hms19_def
  have hf19_lt8 : 8 < f19.locals.size := hf8_lt8
  have hf19_v8 : f19.locals[8]'hf19_lt8 = some recipientAmountRef := by
    show (f15.locals.set 6 none hf15_lt6)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (6 : Nat) ≠ 8)]
    show (f11.locals.set 11 none hf11_lt11)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (11 : Nat) ≠ 8)]
    show (f10.locals.set 10 none hf10_lt10)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (10 : Nat) ≠ 8)]
    show (f9.locals.set 9 none hf9_lt9)[8]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (9 : Nat) ≠ 8)]
    exact hf8_v8
  have hf19_ref8 : ¬ 8 < f19.localRefs.size ∨
                   ∃ h : 8 < f19.localRefs.size, f19.localRefs[8]'h = none := by
    right; refine ⟨by simp [f19, f18, f17, f16, f15, f14, f13, f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[8]'(by simp) = none; decide
  have step20 := step_transfer_pc19 o f19 [] [] ms19 rfl rfl recipientAmountRef
                   hf19_lt8 hf19_v8 hf19_ref8
  set f20 := { f19 with pc := 20, locals := f19.locals.set 8 none hf19_lt8 } with hf20_def
  have hf20_size : f20.locals.size = 13 := by
    show (f19.locals.set 8 none hf19_lt8).size = 13; rw [Array.size_set]; exact hf16_size
  have hf20_lt12 : 12 < f20.locals.size := by rw [hf20_size]; decide
  have hf20_v12 : f20.locals[12]'hf20_lt12 = some proofRef := by
    show (f19.locals.set 8 none hf19_lt8)[12]'hf20_lt12 = _
    rw [Array.getElem_set, if_neg (by decide : (8 : Nat) ≠ 12)]
    exact hf16_v12
  have hf20_ref12 : ¬ 12 < f20.localRefs.size ∨
                    ∃ h : 12 < f20.localRefs.size, f20.localRefs[12]'h = none := by
    right; refine ⟨by simp [f20, f19, f18, f17, f16, f15, f14, f13, f12, f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 13 (none : Option RefId)).toArray)[12]'(by simp) = none; decide
  have step21 := step_transfer_pc20 o f20 [] [recipientAmountRef] ms19 rfl rfl proofRef
                   hf20_lt12 hf20_v12 hf20_ref12
  set f21 := { f20 with pc := 21, locals := f20.locals.set 12 none hf20_lt12 } with hf21_def
  have hms19_read : ms19.containers.read proofRid = some (.struct_ proofFields) := by
    show cs4.read proofRid = _; exact hread4
  have step22 := step_transfer_pc21 o f21 [] [recipientAmountRef] ms19 rfl rfl proofRid proofFields
                   cs5 zkrpTransferFid proofRef hproofRef hms19_read hFieldCount
                   (show ms19.containers.alloc _ = (cs5, zkrpTransferFid) from
                     show cs4.alloc _ = (cs5, zkrpTransferFid) from halloc2)
  set f22 := { f21 with pc := 22 } with hf22_def
  set ms22 : MachineState := { ms19 with containers := cs5 } with hms22_def
  have htake_pc22 :
      takeN [(.immRef zkrpTransferFid : MoveValue), recipientAmountRef] 2 =
        some ([recipientAmountRef, .immRef zkrpTransferFid], []) := rfl
  have step23 := step_transfer_pc22 o f22 []
                   [(.immRef zkrpTransferFid : MoveValue), recipientAmountRef]
                   ms22 rfl rfl
                   [recipientAmountRef, .immRef zkrpTransferFid] [] cs6 htake_pc22 hTransferRangeOk
  set f23 := { f22 with pc := 23 } with hf23_def
  set ms23 : MachineState := { ms22 with containers := cs6, globals := ms22.globals } with hms23_def
  have step24 := step_transfer_pc23 o f23 [] ms23 rfl rfl
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 24 := ⟨fuel - 24, by omega⟩
  rw [hef]
  rw [show ef + 24 = (ef + 23) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 23) _ _ _ _ step1,
      show ef + 23 = (ef + 22) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 22) _ _ _ _ step2,
      show ef + 22 = (ef + 21) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 21) _ _ _ _ step3,
      show ef + 21 = (ef + 20) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 20) _ _ _ _ step4,
      show ef + 20 = (ef + 19) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 19) _ _ _ _ step5,
      show ef + 19 = (ef + 18) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 18) _ _ _ _ step6,
      show ef + 18 = (ef + 17) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 17) _ _ _ _ step7,
      show ef + 17 = (ef + 16) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 16) _ _ _ _ step8,
      show ef + 16 = (ef + 15) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 15) _ _ _ _ step9,
      show ef + 15 = (ef + 14) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 14) _ _ _ _ step10,
      show ef + 14 = (ef + 13) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 13) _ _ _ _ step11,
      show ef + 13 = (ef + 12) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 12) _ _ _ _ step12,
      show ef + 12 = (ef + 11) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 11) _ _ _ _ step13,
      show ef + 11 = (ef + 10) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 10) _ _ _ _ step14,
      show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step15,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step16,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step17,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step18,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step19,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step20,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step21,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step22,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step23,
      StepLemmas.run_succ_returned_of_step ef [] ms23 step24]

/-! ## Top-level equivalence theorem (Phase 4 closure) -/

/-- Frame condition: sigma oracle preserves the proof-struct read in cs2. -/
abbrev TransferSigmaPreservesProofRead
    (o : TransferModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (senderEkRef recipientEkRef curBalRef newBalRef : MoveValue)
    (senderAmountRef recipientAmountRef : MoveValue)
    (auditorEksRef auditorAmountsRef senderAuditorHintRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState) (hFieldCount : 0 < proofFields.length) : Prop :=
  ∀ cs2,
    o.verifySigmaProof (initMs.containers.alloc (proofFields[0]'hFieldCount)).1
        [.u8 chainId, .address sender, .address contract,
         senderEkRef, recipientEkRef, curBalRef, newBalRef,
         senderAmountRef, recipientAmountRef,
         auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
         .immRef (initMs.containers.alloc (proofFields[0]'hFieldCount)).2] =
        some ([], cs2) →
    cs2.read proofRid = some (.struct_ proofFields)

/-- Frame condition: new-balance range oracle preserves the proof-struct read in cs4.
    The cs3 (post-second-alloc) read follows from cs2's read since alloc only appends. -/
abbrev TransferNewBalRangePreservesProofRead
    (o : TransferModuleOracle) (newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue) : Prop :=
  ∀ (cs2 : ContainerStore) (proofFieldsOne : MoveValue) cs3 zkrpNewBalFid cs4,
    cs2.alloc proofFieldsOne = (cs3, zkrpNewBalFid) →
    cs2.read proofRid = some (.struct_ proofFields) →
    o.verifyNewBalanceRangeProof cs3 [newBalRef, .immRef zkrpNewBalFid] = some ([], cs4) →
    cs4.read proofRid = some (.struct_ proofFields)

set_option maxHeartbeats 1200000 in
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
    (hSigmaPreserves :
       TransferSigmaPreservesProofRead o chainId sender contract
         senderEkRef recipientEkRef curBalRef newBalRef
         senderAmountRef recipientAmountRef
         auditorEksRef auditorAmountsRef senderAuditorHintRef
         proofRid proofFields initMs (by omega : 0 < proofFields.length))
    (hNewBalRangePreserves :
       TransferNewBalRangePreservesProofRead o newBalRef proofRid proofFields)
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
    | .returned _ => .returned [] MachineState.empty
    | .error => .error := by
  show (eval (transferModuleEnv o) verifyTransferProofIdx
          [.u8 chainId, .address sender, .address contract,
           senderEkRef, recipientEkRef, curBalRef, newBalRef,
           senderAmountRef, recipientAmountRef,
           auditorEksRef, auditorAmountsRef, senderAuditorHintRef, proofRef]
          fuel initMs).dropMs = _
  rw [eval_transfer_eq_run]
  unfold verifyTransferBytecodeResult
  rcases hSigmaPair : initMs.containers.alloc (proofFields[0]'(by omega : 0 < proofFields.length))
    with ⟨cs1, sigmaFid⟩
  match hsigma : o.verifySigmaProof cs1
                    [.u8 chainId, .address sender, .address contract,
                     senderEkRef, recipientEkRef, curBalRef, newBalRef,
                     senderAmountRef, recipientAmountRef,
                     auditorEksRef, auditorAmountsRef, senderAuditorHintRef,
                     .immRef sigmaFid] with
  | none =>
    have hRun := tr_run_to_sigma_fail_produces_error o chainId sender contract
                  senderEkRef recipientEkRef curBalRef newBalRef
                  senderAmountRef recipientAmountRef
                  auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef
                  proofRid proofFields initMs cs1 sigmaFid
                  (by omega : 0 < proofFields.length) hread hproofRef hSigmaPair
                  fuel (by omega) hsigma
    rw [hRun]
    simp only [ExecResult.dropMs_error, hSigmaPair, hsigma]
  | some (sHead :: sTail, cs2) =>
    have hRun := tr_run_to_sigma_arity_mismatch_produces_error o chainId sender contract
                  senderEkRef recipientEkRef curBalRef newBalRef
                  senderAmountRef recipientAmountRef
                  auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef
                  proofRid proofFields initMs cs1 cs2 sigmaFid sHead sTail
                  (by omega : 0 < proofFields.length) hread hproofRef hSigmaPair
                  fuel (by omega) hsigma
    rw [hRun]
    simp only [ExecResult.dropMs_error, hSigmaPair, hsigma]
  | some ([], cs2) =>
    have hread2 : cs2.read proofRid = some (.struct_ proofFields) := by
      apply hSigmaPreserves cs2
      rw [hSigmaPair]; exact hsigma
    rcases hRangePair1 : cs2.alloc (proofFields[1]'(by omega : 1 < proofFields.length))
      with ⟨cs3, zkrpNewBalFid⟩
    match hNewBalRange : o.verifyNewBalanceRangeProof cs3 [newBalRef, .immRef zkrpNewBalFid] with
    | none =>
      have hRun := tr_run_to_newBalRange_fail_produces_error o chainId sender contract
                    senderEkRef recipientEkRef curBalRef newBalRef
                    senderAmountRef recipientAmountRef
                    auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef
                    proofRid proofFields initMs cs1 cs2 cs3 sigmaFid zkrpNewBalFid
                    (by omega : 1 < proofFields.length) hread hread2 hproofRef
                    hSigmaPair hsigma hRangePair1 hNewBalRange fuel (by omega)
      rw [hRun]
      simp only [ExecResult.dropMs_error, hSigmaPair, hsigma, hRangePair1, hNewBalRange]
    | some (rHead :: rTail, cs4) =>
      have hRun := tr_run_to_newBalRange_arity_mismatch_produces_error o chainId sender contract
                    senderEkRef recipientEkRef curBalRef newBalRef
                    senderAmountRef recipientAmountRef
                    auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef
                    proofRid proofFields initMs cs1 cs2 cs3 cs4 sigmaFid zkrpNewBalFid
                    rHead rTail (by omega : 1 < proofFields.length) hread hread2
                    hproofRef hSigmaPair hsigma hRangePair1 hNewBalRange fuel (by omega)
      rw [hRun]
      simp only [ExecResult.dropMs_error, hSigmaPair, hsigma, hRangePair1, hNewBalRange]
    | some ([], cs4) =>
      have hread4 : cs4.read proofRid = some (.struct_ proofFields) :=
        hNewBalRangePreserves cs2 (proofFields[1]'(by omega : 1 < proofFields.length))
          cs3 zkrpNewBalFid cs4 hRangePair1 hread2 hNewBalRange
      rcases hRangePair2 : cs4.alloc (proofFields[2]'hFieldCount)
        with ⟨cs5, zkrpTransferFid⟩
      match hTransferRange : o.verifyTransferAmountRangeProof cs5
                                [recipientAmountRef, .immRef zkrpTransferFid] with
      | none =>
        have hRun := tr_run_to_transferRange_fail_produces_error o chainId sender contract
                      senderEkRef recipientEkRef curBalRef newBalRef
                      senderAmountRef recipientAmountRef
                      auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef
                      proofRid proofFields initMs cs1 cs2 cs3 cs4 cs5
                      sigmaFid zkrpNewBalFid zkrpTransferFid
                      hFieldCount hread hread2 hread4 hproofRef
                      hSigmaPair hsigma hRangePair1 hNewBalRange hRangePair2
                      hTransferRange fuel (by omega)
        rw [hRun]
        simp only [ExecResult.dropMs_error, hSigmaPair, hsigma, hRangePair1,
                   hNewBalRange, hRangePair2, hTransferRange]
      | some (tHead :: tTail, cs6) =>
        have hRun := tr_run_to_transferRange_arity_mismatch_produces_error o chainId sender contract
                      senderEkRef recipientEkRef curBalRef newBalRef
                      senderAmountRef recipientAmountRef
                      auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef
                      proofRid proofFields initMs cs1 cs2 cs3 cs4 cs5 cs6
                      sigmaFid zkrpNewBalFid zkrpTransferFid
                      tHead tTail hFieldCount hread hread2 hread4 hproofRef
                      hSigmaPair hsigma hRangePair1 hNewBalRange hRangePair2
                      hTransferRange fuel (by omega)
        rw [hRun]
        simp only [ExecResult.dropMs_error, hSigmaPair, hsigma, hRangePair1,
                   hNewBalRange, hRangePair2, hTransferRange]
      | some ([], cs6) =>
        have hRun := tr_run_to_success_produces_returned o chainId sender contract
                      senderEkRef recipientEkRef curBalRef newBalRef
                      senderAmountRef recipientAmountRef
                      auditorEksRef auditorAmountsRef senderAuditorHintRef proofRef
                      proofRid proofFields initMs cs1 cs2 cs3 cs4 cs5 cs6
                      sigmaFid zkrpNewBalFid zkrpTransferFid
                      hFieldCount hread hread2 hread4 hproofRef
                      hSigmaPair hsigma hRangePair1 hNewBalRange hRangePair2
                      hTransferRange fuel (by omega)
        rw [hRun]
        simp only [ExecResult.dropMs_returned, hSigmaPair, hsigma, hRangePair1,
                   hNewBalRange, hRangePair2, hTransferRange]

/-! ## Helper axioms for PC-range chaining (Transfer-specific)

Similar to Withdrawal/Normalization, we could define helper axioms that abstract PC-range chains:
-/

end MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv
