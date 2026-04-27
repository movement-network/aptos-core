import MovementFormal.MoveModel.Programs.Withdrawal
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Structs
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.ExecResultDropMs
import MovementFormal.MoveModel.OpaqueFrames
import MovementFormal.Experimental.ConfidentialAsset.Helpers.ArgumentMarshaling
import MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleComposition
import MovementFormal.Experimental.ConfidentialAsset.Withdrawal.ConcreteHelpers
import MovementFormal.Experimental.ConfidentialAsset.Withdrawal.BytecodeLemmas
import Mathlib.Tactic.Common
import Mathlib.Tactic.Set

/-!
# Bytecode eval ≡ functional simulation for `verify_withdrawal_proof` — Phase 4

Proves that the `verify_withdrawal_proof` bytecode (15 instructions dispatching to
`verify_withdrawal_sigma_proof` + `verify_new_balance_range_proof`) evaluates to the
functional simulation result under the module oracle.

Withdrawal has 8 params (includes `amount: u64` at local 4 instead of a ref).
Otherwise same pattern as Rotation/Normalization.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Withdrawal

def withdrawalArgs (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef proofRef : MoveValue)
    : List MoveValue :=
  [.u8 chainId, .address sender, .address contract,
   ekRef, .u64 amount, curBalRef, newBalRef, proofRef]

/-! ## Module environment simp lemmas -/

@[simp] theorem withdrawalModuleEnv_functions_size (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions.size = 3 := by
  unfold withdrawalModuleEnv; rfl

@[simp] theorem withdrawalModuleEnv_fn0_numParams (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[0].numParams = 8 := by
  unfold withdrawalModuleEnv; rfl

@[simp] theorem withdrawalModuleEnv_fn0_numReturns (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[0].numReturns = 0 := by
  unfold withdrawalModuleEnv; rfl

@[simp] theorem withdrawalModuleEnv_fn0_body (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[0].body = .nativeRef o.verifySigmaProof := by
  unfold withdrawalModuleEnv; rfl

@[simp] theorem withdrawalModuleEnv_fn1_numParams (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[1].numParams = 2 := by
  unfold withdrawalModuleEnv; rfl

@[simp] theorem withdrawalModuleEnv_fn1_numReturns (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[1].numReturns = 0 := by
  unfold withdrawalModuleEnv; rfl

@[simp] theorem withdrawalModuleEnv_fn1_body (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[1].body = .nativeRef o.verifyRangeProof := by
  unfold withdrawalModuleEnv; rfl

@[simp] theorem withdrawalModuleEnv_fn2_numParams (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[2].numParams = 8 := by
  unfold withdrawalModuleEnv verifyWithdrawalProofDesc; rfl

@[simp] theorem withdrawalModuleEnv_fn2_body (o : WithdrawalModuleOracle) :
    (withdrawalModuleEnv o).functions[2].body = .bytecode verifyWithdrawalProofCode 8 := by
  unfold withdrawalModuleEnv verifyWithdrawalProofDesc; rfl

/-! ## Bytecode access lemmas (extracted to BytecodeLemmas.lean) -/

private abbrev wdl_code_pc0  := BytecodeLemmas.instr0_eq
private abbrev wdl_code_pc1  := BytecodeLemmas.instr1_eq
private abbrev wdl_code_pc2  := BytecodeLemmas.instr2_eq
private abbrev wdl_code_pc3  := BytecodeLemmas.instr3_eq
private abbrev wdl_code_pc4  := BytecodeLemmas.instr4_eq
private abbrev wdl_code_pc5  := BytecodeLemmas.instr5_eq
private abbrev wdl_code_pc6  := BytecodeLemmas.instr6_eq
private abbrev wdl_code_pc7  := BytecodeLemmas.instr7_eq
private abbrev wdl_code_pc8  := BytecodeLemmas.instr8_eq
private abbrev wdl_code_pc9  := BytecodeLemmas.instr9_eq
private abbrev wdl_code_pc10 := BytecodeLemmas.instr10_eq
private abbrev wdl_code_pc11 := BytecodeLemmas.instr11_eq
private abbrev wdl_code_pc12 := BytecodeLemmas.instr12_eq
private abbrev wdl_code_pc13 := BytecodeLemmas.instr13_eq
private abbrev wdl_code_pc14 := BytecodeLemmas.instr14_eq

/-! ## `eval` → `run` entry-point unfolding -/

theorem eval_withdrawal_eq_run (o : WithdrawalModuleOracle)
    (args : List MoveValue) (fuel : Nat) (initMs : MachineState) :
    eval (withdrawalModuleEnv o) verifyWithdrawalProofIdx args fuel initMs =
      run (withdrawalModuleEnv o)
        { code := verifyWithdrawalProofCode,
          pc := 0,
          locals := (args.map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel := by
  unfold eval verifyWithdrawalProofIdx
  simp only [withdrawalModuleEnv_functions_size, show (2 : Nat) < 3 from by decide, dif_pos,
             withdrawalModuleEnv_fn2_body, withdrawalModuleEnv_fn2_numParams]
  simp [List.replicate]

/-! ## Per-PC step theorems (moveLoc PCs 0–5) -/

theorem step_withdrawal_pc0 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 0)
    (v : MoveValue) (hlt : 0 < frame.locals.size) (hv : frame.locals[0]'hlt = some v)
    (hRefNone : ¬ 0 < frame.localRefs.size ∨ ∃ h : 0 < frame.localRefs.size, frame.localRefs[0]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 1, locals := frame.locals.set 0 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 0 := by simp only [hcode, hpc]; exact wdl_code_pc0
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    0 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 1 from by omega] at h; exact h

theorem step_withdrawal_pc1 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 1)
    (v : MoveValue) (hlt : 1 < frame.locals.size) (hv : frame.locals[1]'hlt = some v)
    (hRefNone : ¬ 1 < frame.localRefs.size ∨ ∃ h : 1 < frame.localRefs.size, frame.localRefs[1]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 2, locals := frame.locals.set 1 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 1 := by simp only [hcode, hpc]; exact wdl_code_pc1
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    1 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 2 from by omega] at h; exact h

theorem step_withdrawal_pc2 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 2)
    (v : MoveValue) (hlt : 2 < frame.locals.size) (hv : frame.locals[2]'hlt = some v)
    (hRefNone : ¬ 2 < frame.localRefs.size ∨ ∃ h : 2 < frame.localRefs.size, frame.localRefs[2]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 3, locals := frame.locals.set 2 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 2 := by simp only [hcode, hpc]; exact wdl_code_pc2
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    2 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 3 from by omega] at h; exact h

theorem step_withdrawal_pc3 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 3)
    (v : MoveValue) (hlt : 3 < frame.locals.size) (hv : frame.locals[3]'hlt = some v)
    (hRefNone : ¬ 3 < frame.localRefs.size ∨ ∃ h : 3 < frame.localRefs.size, frame.localRefs[3]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 4, locals := frame.locals.set 3 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 3 := by simp only [hcode, hpc]; exact wdl_code_pc3
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    3 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 4 from by omega] at h; exact h

theorem step_withdrawal_pc4 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 4)
    (v : MoveValue) (hlt : 4 < frame.locals.size) (hv : frame.locals[4]'hlt = some v)
    (hRefNone : ¬ 4 < frame.localRefs.size ∨ ∃ h : 4 < frame.localRefs.size, frame.localRefs[4]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 5, locals := frame.locals.set 4 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 4 := by simp only [hcode, hpc]; exact wdl_code_pc4
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    4 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 5 from by omega] at h; exact h

theorem step_withdrawal_pc5 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 5)
    (v : MoveValue) (hlt : 5 < frame.locals.size) (hv : frame.locals[5]'hlt = some v)
    (hRefNone : ¬ 5 < frame.localRefs.size ∨ ∃ h : 5 < frame.localRefs.size, frame.localRefs[5]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 6, locals := frame.locals.set 5 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 5 := by simp only [hcode, hpc]; exact wdl_code_pc5
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    5 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 6 from by omega] at h; exact h

/-! ## copyLoc PCs 6–7 -/

theorem step_withdrawal_pc6 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 6)
    (v : MoveValue) (hlt : 6 < frame.locals.size) (hv : frame.locals[6]'hlt = some v)
    (hRefNone : ¬ 6 < frame.localRefs.size ∨ ∃ h : 6 < frame.localRefs.size, frame.localRefs[6]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms = .ok { frame with pc := 7 } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 6 := by simp only [hcode, hpc]; exact wdl_code_pc6
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    6 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 7 from by omega] at h; exact h

theorem step_withdrawal_pc7 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 7)
    (v : MoveValue) (hlt : 7 < frame.locals.size) (hv : frame.locals[7]'hlt = some v)
    (hRefNone : ¬ 7 < frame.localRefs.size ∨ ∃ h : 7 < frame.localRefs.size, frame.localRefs[7]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms = .ok { frame with pc := 8 } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 7 := by simp only [hcode, hpc]; exact wdl_code_pc7
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := withdrawalModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    7 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 8 from by omega] at h; exact h

/-! ## PC 8 — immBorrowField 0 (proof.sigma_proof) -/

theorem step_withdrawal_pc8 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 8)
    (rid : RefId) (proofFields : List MoveValue) (containers' : ContainerStore) (fid : RefId)
    (ref : MoveValue)
    (hRef : getRefId ref = some rid)
    (hread : ms.containers.read rid = some (.struct_ proofFields))
    (hlt : 0 < proofFields.length)
    (halloc : ms.containers.alloc (proofFields[0]'hlt) = (containers', fid)) :
    step (withdrawalModuleEnv o) frame cs (ref :: rest) ms =
      .ok { frame with pc := 9 } cs (.immRef fid :: rest) { ms with containers := containers' } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowField 0 := by simp only [hcode, hpc]; exact wdl_code_pc8
  simp only [step, dif_pos hpc_lt, hc, hRef, hread, dif_pos hlt, halloc]
  rw [show frame.pc + 1 = 9 from by omega]

/-! ## PC 9 — call 0 (verifySigmaProof, 8 args) -/

theorem step_withdrawal_pc9 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 9)
    (args rest : List MoveValue) (containers' : ContainerStore)
    (htake : takeN stack 8 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = some ([], containers')) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 10 } cs rest { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; exact wdl_code_pc9
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (withdrawalModuleEnv o).functions.size by simp)]
  simp only [withdrawalModuleEnv_fn0_numParams, htake, withdrawalModuleEnv_fn0_body, himpl]
  unfold handleNativeResult
  simp only [withdrawalModuleEnv_fn0_numReturns, beq_self_eq_true, ↓reduceIte]
  rw [show frame.pc + 1 = 10 from by omega]

theorem step_withdrawal_pc9_multi (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 9)
    (args rest : List MoveValue) (v : MoveValue) (vs : List MoveValue)
    (containers' : ContainerStore)
    (htake : takeN stack 8 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = some (v :: vs, containers')) :
    step (withdrawalModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; exact wdl_code_pc9
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (withdrawalModuleEnv o).functions.size by simp)]
  simp only [withdrawalModuleEnv_fn0_numParams, htake, withdrawalModuleEnv_fn0_body, himpl]
  unfold handleNativeResult
  cases vs with
  | nil => simp [withdrawalModuleEnv_fn0_numReturns]
  | cons w ws => simp [withdrawalModuleEnv_fn0_numReturns]

theorem step_withdrawal_pc9_none (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 9)
    (args rest : List MoveValue)
    (htake : takeN stack 8 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = none) :
    step (withdrawalModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; exact wdl_code_pc9
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (withdrawalModuleEnv o).functions.size by simp)]
  simp only [withdrawalModuleEnv_fn0_numParams, htake, withdrawalModuleEnv_fn0_body, himpl]

/-! ## moveLoc PCs 10–11 (after sigma call) -/

theorem step_withdrawal_pc10 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 10)
    (v : MoveValue) (hlt : 6 < frame.locals.size) (hv : frame.locals[6]'hlt = some v)
    (hRefNone : ¬ 6 < frame.localRefs.size ∨ ∃ h : 6 < frame.localRefs.size, frame.localRefs[6]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 11, locals := frame.locals.set 6 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 6 := by simp only [hcode, hpc]; exact wdl_code_pc10
  simp only [step, dif_pos hpc_lt, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]; rw [show frame.pc + 1 = 11 from by omega]
  · simp only [dif_pos hSz, hNone]; rw [show frame.pc + 1 = 11 from by omega]

theorem step_withdrawal_pc11 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 11)
    (v : MoveValue) (hlt : 7 < frame.locals.size) (hv : frame.locals[7]'hlt = some v)
    (hRefNone : ¬ 7 < frame.localRefs.size ∨ ∃ h : 7 < frame.localRefs.size, frame.localRefs[7]'h = none) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 12, locals := frame.locals.set 7 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 7 := by simp only [hcode, hpc]; exact wdl_code_pc11
  simp only [step, dif_pos hpc_lt, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]; rw [show frame.pc + 1 = 12 from by omega]
  · simp only [dif_pos hSz, hNone]; rw [show frame.pc + 1 = 12 from by omega]

/-! ## PC 12 — immBorrowField 1 (proof.zkrp_new_balance) -/

theorem step_withdrawal_pc12 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 12)
    (rid : RefId) (proofFields : List MoveValue) (containers' : ContainerStore) (fid : RefId)
    (ref : MoveValue)
    (hRef : getRefId ref = some rid)
    (hread : ms.containers.read rid = some (.struct_ proofFields))
    (hlt : 1 < proofFields.length)
    (halloc : ms.containers.alloc (proofFields[1]'hlt) = (containers', fid)) :
    step (withdrawalModuleEnv o) frame cs (ref :: rest) ms =
      .ok { frame with pc := 13 } cs (.immRef fid :: rest) { ms with containers := containers' } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowField 1 := by simp only [hcode, hpc]; exact wdl_code_pc12
  simp only [step, dif_pos hpc_lt, hc, hRef, hread, dif_pos hlt, halloc]
  rw [show frame.pc + 1 = 13 from by omega]

/-! ## PC 13 — call 1 (verifyRangeProof, 2 args) -/

theorem step_withdrawal_pc13 (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 13)
    (args rest : List MoveValue) (containers' : ContainerStore)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyRangeProof ms.containers args = some ([], containers')) :
    step (withdrawalModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 14 } cs rest { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; exact wdl_code_pc13
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (withdrawalModuleEnv o).functions.size by simp)]
  simp only [withdrawalModuleEnv_fn1_numParams, htake, withdrawalModuleEnv_fn1_body, himpl]
  unfold handleNativeResult
  simp only [withdrawalModuleEnv_fn1_numReturns, beq_self_eq_true, ↓reduceIte]
  rw [show frame.pc + 1 = 14 from by omega]

theorem step_withdrawal_pc13_multi (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 13)
    (args rest : List MoveValue) (v : MoveValue) (vs : List MoveValue)
    (containers' : ContainerStore)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyRangeProof ms.containers args = some (v :: vs, containers')) :
    step (withdrawalModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; exact wdl_code_pc13
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (withdrawalModuleEnv o).functions.size by simp)]
  simp only [withdrawalModuleEnv_fn1_numParams, htake, withdrawalModuleEnv_fn1_body, himpl]
  unfold handleNativeResult
  cases vs with
  | nil => simp [withdrawalModuleEnv_fn1_numReturns]
  | cons w ws => simp [withdrawalModuleEnv_fn1_numReturns]

theorem step_withdrawal_pc13_none (o : WithdrawalModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 13)
    (args rest : List MoveValue)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyRangeProof ms.containers args = none) :
    step (withdrawalModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; exact wdl_code_pc13
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (withdrawalModuleEnv o).functions.size by simp)]
  simp only [withdrawalModuleEnv_fn1_numParams, htake, withdrawalModuleEnv_fn1_body, himpl]

/-! ## PC 14 — ret -/

theorem step_withdrawal_pc14 (o : WithdrawalModuleOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyWithdrawalProofCode) (hpc : frame.pc = 14) :
    step (withdrawalModuleEnv o) frame [] stack ms = .returned stack ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .ret := by simp only [hcode, hpc]; exact wdl_code_pc14
  exact StepLemmas.step_ret_top hpc_lt hc

/-! ## Functional simulation — Phase 6

The functional simulation captures the high-level behavior of `verify_withdrawal_proof`:
wires chain_id, sender, contract, ek, amount, current_balance, new_balance, and the
proof's sigma_proof field (via ImmBorrowField) to the sigma verifier, then new_balance
and the proof's zkrp_new_balance field to the range verifier.

The result is `.returned [] ms_final` on success (both sub-calls return `some`) or
`.error` if either sub-call fails. -/

inductive WithdrawalBytecodeResult where
  | returned (ms : MachineState)
  | error

def verifyWithdrawalBytecodeResult
    (o : WithdrawalModuleOracle) (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef : MoveValue)
    (_proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length) : WithdrawalBytecodeResult :=
  let (cs1, sigmaFid) := initMs.containers.alloc (proofFields[0]'(by omega))
  let sigmaArgs := [.u8 chainId, .address sender, .address contract,
                    ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid]
  match o.verifySigmaProof cs1 sigmaArgs with
  | none => .error
  | some ([], cs2) =>
    let (cs3, zkrpFid) := cs2.alloc (proofFields[1]'hFieldCount)
    let rangeArgs := [newBalRef, .immRef zkrpFid]
    match o.verifyRangeProof cs3 rangeArgs with
    | none => .error
    | some ([], cs4) => .returned { initMs with containers := cs4, globals := initMs.globals }
    | some (_ :: _, _) => .error
  | some (_ :: _, _) => .error

/-! ## Irreducible frame helpers (following registration pattern) -/

/-- Initial frame for withdrawal verifier eval.

    Made `@[irreducible]` to prevent elaborator from expanding array literals
    in theorem statements, avoiding "free variable constraint" errors. -/
@[irreducible]
def withdrawalInitFrame (args : List MoveValue) : Frame :=
  { code := verifyWithdrawalProofCode
    pc := 0
    locals := args.toArray.map some
    localRefs := #[] }

/-- Exposed form so `simp` can reduce when needed. -/
theorem withdrawalInitFrame_def (args : List MoveValue) :
    withdrawalInitFrame args =
      { code := verifyWithdrawalProofCode, pc := 0,
        locals := args.toArray.map some, localRefs := #[] } := by
  rw [withdrawalInitFrame]

theorem withdrawalInitFrame_code (args : List MoveValue) :
    (withdrawalInitFrame args).code = verifyWithdrawalProofCode := by
  rw [withdrawalInitFrame]

theorem withdrawalInitFrame_pc (args : List MoveValue) :
    (withdrawalInitFrame args).pc = 0 := by
  rw [withdrawalInitFrame]

/-! ## PC-chaining helper lemmas -/

/-! ## Functional simulation shape lemmas -/

/-- Functional simulation shape lemma: sigma failure → .error -/
theorem verifyWithdrawalBytecodeResult_sigmaFails
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (hsigmaFail : ∀ cs args, o.verifySigmaProof cs args = none) :
    verifyWithdrawalBytecodeResult o chainId sender contract
        ekRef amount curBalRef newBalRef proofRid proofFields initMs hFieldCount =
    .error := by
  unfold verifyWithdrawalBytecodeResult
  simp [hsigmaFail]

/-- Functional simulation shape lemma: range failure → .error -/
theorem verifyWithdrawalBytecodeResult_rangeFails
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (sigmaCs : ContainerStore)
    (hsigmaOk : o.verifySigmaProof (initMs.containers.alloc (proofFields[0]'(by omega))).1
                    [.u8 chainId, .address sender, .address contract,
                     ekRef, .u64 amount, curBalRef, newBalRef,
                     .immRef (initMs.containers.alloc (proofFields[0]'(by omega))).2] =
                 some ([], sigmaCs))
    (hrangeFail : ∀ cs args, o.verifyRangeProof cs args = none) :
    verifyWithdrawalBytecodeResult o chainId sender contract
        ekRef amount curBalRef newBalRef proofRid proofFields initMs hFieldCount =
    .error := by
  unfold verifyWithdrawalBytecodeResult
  simp only [hsigmaOk, hrangeFail]

/-- Functional simulation shape lemma: happy path → .returned -/
theorem verifyWithdrawalBytecodeResult_success
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (sigmaCs rangeCs : ContainerStore)
    (sigmaFid : RefId)
    (halloc0 : initMs.containers.alloc (proofFields[0]'(by omega)) = (sigmaCs, sigmaFid))
    (hsigmaOk : o.verifySigmaProof sigmaCs
                    [.u8 chainId, .address sender, .address contract,
                     ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid] =
                 some ([], rangeCs))
    (hrange : o.verifyRangeProof (rangeCs.alloc (proofFields[1]'hFieldCount)).1
                  [newBalRef, .immRef (rangeCs.alloc (proofFields[1]'hFieldCount)).2] =
               some ([], (rangeCs.alloc (proofFields[1]'hFieldCount)).1)) :
    verifyWithdrawalBytecodeResult o chainId sender contract
        ekRef amount curBalRef newBalRef proofRid proofFields initMs hFieldCount =
    .returned { initMs with containers := (rangeCs.alloc (proofFields[1]'hFieldCount)).1 } := by
  unfold verifyWithdrawalBytecodeResult
  simp only [halloc0, hsigmaOk, hrange]

/-! ## Top-level composition theorem (Phase 6)

The full eval↔functional-sim equivalence proving that bytecode execution matches
the functional simulation.

**Proof structure (150 lines, 3 axioms, 4 sorries remaining):**
1. ✅ Unfold eval to run via `eval_withdrawal_eq_run`
2. ✅ Match on sigma oracle outcome (mirrors functional sim structure)
3. ✅ Sigma failure case: Uses `run_to_sigma_fail_produces_error` axiom
4. ✅ Range failure case: Uses `run_to_range_fail_produces_error` axiom
5. ✅ Golden path: Structured with sorry for 15-PC chain
6. ⚠️  Arity mismatch cases: Sorry placeholders (impossible in well-typed code)

**Remaining work to complete:**
- Prove `run_to_sigma_fail_produces_error`: Chain PCs 0-9, show error propagation (~80 lines)
- Prove `run_to_range_fail_produces_error`: Chain PCs 0-13, show error propagation (~100 lines)
- Complete golden path: Chain all 15 PCs, show containers threading (~120 lines)
- Simplify functional sim match trees to show equality in each case (~50 lines)

**Total estimated:** ~350 additional lines to eliminate all axioms and sorries.

**Build status:** ✅ Compiles with expected axiom/sorry warnings, full tree builds (1896 jobs). -/

/-! ## Helper axioms for PC-chaining (to be proved later)

These axioms abstract the PC-chaining proofs that show bytecode execution through multiple
instructions. Each axiom states that given certain oracle outcomes, running the bytecode from
the initial frame produces a specific result.

To prove these axioms, one would need to:
1. Apply individual step theorems for PCs 0-7 (marshal arguments)
2. Apply step theorem for PC 8 (immBorrowField to get sigma proof field)
3. Apply step theorem for PC 9 (call sigma oracle) with the given oracle outcome
4. For range failure/success, continue through PCs 10-13
5. Chain all steps together using run_succ_N_ok lemmas
6. Show final result matches the stated conclusion

Current blockers: Array indexing in frame construction requires opaque frame helpers or
concrete index-specific lemmas (see ConcreteHelpers.lean).
-/

/-- Helper: When sigma oracle returns none, run produces error.

Proof sketch (blocked on frame chaining):

The proof would:
1. Apply step theorems for PCs 0-8 (marshal parameters + borrow sigma proof field)
2. Use OpaqueFrames.step_result_moveLoc_to_opaque to convert each step result to opaque frames
3. Chain with run_succ_eight_ok to advance 8 PCs
4. Apply step_withdrawal_pc9_none showing PC 9 call produces .error when sigma oracle fails
5. Use run_succ_error_of_step to propagate error

Blocker: Need explicit frame/stack/ms witnesses for all 9 PCs. The ConcreteHelpers module
provides frame *constructors* but not proofs that run/step produce those frames.

Alternative: prove "run_through_pc8" lemma showing full 8-PC chain, similar to
registration_run_through_pc2 in Registration/EvalEquivRebuild.lean.
-/
-- Refactored to take explicit parameters instead of generic initFrame
theorem run_to_sigma_fail_produces_error
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64)
    (curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 : ContainerStore) (sigmaFid : RefId)
    (hFieldCount : 0 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc : initMs.containers.alloc (proofFields[0]'hFieldCount) = (cs1, sigmaFid))
    (fuel : Nat)
    (hfuel : fuel ≥ 15)
    (hsigmaFail : o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                          ekRef, .u64 amount, curBalRef, newBalRef,
                                          .immRef sigmaFid] = none) :
    run (withdrawalModuleEnv o)
        { code := verifyWithdrawalProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      ekRef, .u64 amount, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel = .error := by
  -- Initial frame f0 with 8 args.
  set f0 : Frame :=
      { code := verifyWithdrawalProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    ekRef, .u64 amount, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 8 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 8 := by simp [f0]
  -- PC 0: moveLoc 0
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_withdrawal_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  -- f1 at PC 1
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 8 := by
    show (f0.locals.set 0 none hf0_lt0).size = 8; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_withdrawal_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  -- f2 at PC 2
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 8 := by
    show (f1.locals.set 1 none hf1_lt1).size = 8; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_withdrawal_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  -- f3 at PC 3
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 8 := by
    show (f2.locals.set 2 none hf2_lt2).size = 8; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some ekRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_withdrawal_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl ekRef hf3_lt3 hf3_v3 hf3_ref3
  -- f4 at PC 4
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 8 := by
    show (f3.locals.set 3 none hf3_lt3).size = 8; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some (.u64 amount) := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_withdrawal_pc4 o f4 []
                  [ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl (.u64 amount) hf4_lt4 hf4_v4 hf4_ref4
  -- f5 at PC 5
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 8 := by
    show (f4.locals.set 4 none hf4_lt4).size = 8; rw [Array.size_set]; exact hf4_size
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_withdrawal_pc5 o f5 []
                  [(.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  -- f6 at PC 6 (locals updated by pc5 stLoc, but copyLoc 6 leaves them alone)
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 8 := by
    show (f5.locals.set 5 none hf5_lt5).size = 8; rw [Array.size_set]; exact hf5_size
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_withdrawal_pc6 o f6 []
                  [curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  -- f7 at PC 7 (copyLoc didn't change locals)
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 8 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some proofRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_withdrawal_pc7 o f7 []
                  [newBalRef, curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf7_lt7 hf7_v7 hf7_ref7
  -- f8 at PC 8 (copyLoc unchanged)
  set f8 := { f7 with pc := 8 } with hf8_def
  -- step9: PC 8 immBorrowField 0 — pops proofRef, allocates sigmaFid, pushes .immRef sigmaFid
  have step9 := step_withdrawal_pc8 o f8 []
                  [newBalRef, curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread hFieldCount halloc
  -- step10: PC 9 call verifySigmaProof, hsigmaFail makes it return .error
  set f9 := { f8 with pc := 9 } with hf9_def
  set ms9 : MachineState := { initMs with containers := cs1 } with hms9_def
  have htake :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, (.u64 amount : MoveValue),
              ekRef, (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 8 =
        some ([.u8 chainId, .address sender, .address contract, ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step10 := step_withdrawal_pc9_none o f9 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, (.u64 amount : MoveValue),
                    ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms9 rfl rfl
                  [.u8 chainId, .address sender, .address contract, ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid]
                  [] htake hsigmaFail
  -- Compose: 9 OK steps + 1 error step.
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 10 := ⟨fuel - 10, by omega⟩
  rw [hef]
  rw [show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step1,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step2,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step3,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step4,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step5,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step6,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step7,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step8,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step9,
      StepLemmas.run_succ_error_of_step ef step10]
/-- Helper: When range oracle returns none after sigma success, run produces error.

Proof outline (to be completed):
1. Chain PCs 0-8 as in sigma failure case (8 steps)
2. At PC 9, apply step_withdrawal_pc9 with hsigmaOk showing sigma success
3. Continue from PC 10: apply step_withdrawal_pc10 (moveLoc)
4. PC 11: apply step_withdrawal_pc11 (moveLoc)
5. PC 12: apply step_withdrawal_pc12 (immBorrowField) - allocates zkrpFid
6. At PC 13, apply step_withdrawal_pc13_none with hrangeFail
7. step_withdrawal_pc13_none shows step returns .error
8. Use run_succ_error_of_step to propagate error
9. Total: ~100 lines (more than sigma failure due to longer PC chain)
-/
-- Refactored to take explicit parameters
theorem run_to_range_fail_produces_error
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64)
    (curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 cs3 : ContainerStore)
    (sigmaFid zkrpFid : RefId)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc0 : initMs.containers.alloc (proofFields[0]'(by omega : 0 < proofFields.length)) = (cs1, sigmaFid))
    (hsigmaOk : o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                        ekRef, .u64 amount, curBalRef, newBalRef,
                                        .immRef sigmaFid] = some ([], cs2))
    -- Sigma oracle preserves the proof container (frame condition; signature fix
    -- vs. the original axiom — the original silently assumed this).
    (hread2 : cs2.read proofRid = some (.struct_ proofFields))
    (halloc1 : cs2.alloc (proofFields[1]'hFieldCount) = (cs3, zkrpFid))
    (hrangeFail : o.verifyRangeProof cs3 [newBalRef, .immRef zkrpFid] = none)
    (fuel : Nat)
    (hfuel : fuel ≥ 15) :
    run (withdrawalModuleEnv o)
        { code := verifyWithdrawalProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      ekRef, .u64 amount, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel = .error := by
  -- PCs 0-9 are identical to sigma_fail's chain (just sigma succeeds here, gets cs2).
  -- PCs 10-13 then handle range proof marshaling and call.
  set f0 : Frame :=
      { code := verifyWithdrawalProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    ekRef, .u64 amount, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 8 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 8 := by simp [f0]
  -- Step 1: PC 0 moveLoc 0
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_withdrawal_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 8 := by
    show (f0.locals.set 0 none hf0_lt0).size = 8; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_withdrawal_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 8 := by
    show (f1.locals.set 1 none hf1_lt1).size = 8; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_withdrawal_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 8 := by
    show (f2.locals.set 2 none hf2_lt2).size = 8; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some ekRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_withdrawal_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl ekRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 8 := by
    show (f3.locals.set 3 none hf3_lt3).size = 8; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some (.u64 amount) := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_withdrawal_pc4 o f4 []
                  [ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl (.u64 amount) hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 8 := by
    show (f4.locals.set 4 none hf4_lt4).size = 8; rw [Array.size_set]; exact hf4_size
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_withdrawal_pc5 o f5 []
                  [(.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 8 := by
    show (f5.locals.set 5 none hf5_lt5).size = 8; rw [Array.size_set]; exact hf5_size
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_withdrawal_pc6 o f6 []
                  [curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 8 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some proofRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_withdrawal_pc7 o f7 []
                  [newBalRef, curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf7_lt7 hf7_v7 hf7_ref7
  -- f8 at PC 8 (immBorrowField 0)
  set f8 := { f7 with pc := 8 } with hf8_def
  have step9 := step_withdrawal_pc8 o f8 []
                  [newBalRef, curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread (by omega : 0 < proofFields.length) halloc0
  -- f9 at PC 9 (call sigma SUCCESS this time)
  set f9 := { f8 with pc := 9 } with hf9_def
  set ms9 : MachineState := { initMs with containers := cs1 } with hms9_def
  have htake_pc9 :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, (.u64 amount : MoveValue),
              ekRef, (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 8 =
        some ([.u8 chainId, .address sender, .address contract, ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step10 := step_withdrawal_pc9 o f9 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, (.u64 amount : MoveValue),
                    ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms9 rfl rfl
                  [.u8 chainId, .address sender, .address contract, ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid]
                  [] cs2 htake_pc9 hsigmaOk
  -- f10 at PC 10 (moveLoc 6 newBalRef)
  set f10 := { f9 with pc := 10 } with hf10_def
  set ms10 : MachineState := { ms9 with containers := cs2, globals := ms9.globals } with hms10_def
  have hf10_lt6 : 6 < f10.locals.size := hf6_lt6
  have hf10_v6 : f10.locals[6]'hf10_lt6 = some newBalRef := hf6_v6
  have hf10_ref6 : ¬ 6 < f10.localRefs.size ∨
                   ∃ h : 6 < f10.localRefs.size, f10.localRefs[6]'h = none := hf6_ref6
  have step11 := step_withdrawal_pc10 o f10 [] [] ms10 rfl rfl newBalRef
                   hf10_lt6 hf10_v6 hf10_ref6
  -- f11 at PC 11 (moveLoc 7 proofRef)
  set f11 := { f10 with pc := 11, locals := f10.locals.set 6 none hf10_lt6 } with hf11_def
  have hf11_size : f11.locals.size = 8 := by
    show (f10.locals.set 6 none hf10_lt6).size = 8; rw [Array.size_set]; exact hf7_size
  have hf11_lt7 : 7 < f11.locals.size := by rw [hf11_size]; decide
  have hf11_v7 : f11.locals[7]'hf11_lt7 = some proofRef := by
    show (f10.locals.set 6 none hf10_lt6)[7]'hf11_lt7 = _
    rw [Array.getElem_set, if_neg (by decide : (6 : Nat) ≠ 7)]
    exact hf7_v7
  have hf11_ref7 : ¬ 7 < f11.localRefs.size ∨
                   ∃ h : 7 < f11.localRefs.size, f11.localRefs[7]'h = none := by
    right; refine ⟨by simp [f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step12 := step_withdrawal_pc11 o f11 [] [newBalRef] ms10 rfl rfl proofRef
                   hf11_lt7 hf11_v7 hf11_ref7
  -- f12 at PC 12 (immBorrowField 1)
  set f12 := { f11 with pc := 12, locals := f11.locals.set 7 none hf11_lt7 } with hf12_def
  have hms10_read : ms10.containers.read proofRid = some (.struct_ proofFields) := by
    show cs2.read proofRid = _
    exact hread2
  have step13 := step_withdrawal_pc12 o f12 [] [newBalRef] ms10 rfl rfl proofRid proofFields cs3
                   zkrpFid proofRef hproofRef hms10_read hFieldCount
                   (show ms10.containers.alloc _ = (cs3, zkrpFid) from
                     show cs2.alloc _ = (cs3, zkrpFid) from halloc1)
  -- f13 at PC 13 (call verifyRangeProof; .none → .error)
  set f13 := { f12 with pc := 13 } with hf13_def
  set ms13 : MachineState := { ms10 with containers := cs3 } with hms13_def
  have htake_pc13 :
      takeN [(.immRef zkrpFid : MoveValue), newBalRef] 2 =
        some ([newBalRef, .immRef zkrpFid], []) := rfl
  have step14 := step_withdrawal_pc13_none o f13 []
                   [(.immRef zkrpFid : MoveValue), newBalRef]
                   ms13 rfl rfl
                   [newBalRef, .immRef zkrpFid] [] htake_pc13 hrangeFail
  -- Compose: 13 OK steps + 1 error step = 14 fuel.
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 14 := ⟨fuel - 14, by omega⟩
  rw [hef]
  rw [show ef + 14 = (ef + 13) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 13) _ _ _ _ step1,
      show ef + 13 = (ef + 12) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 12) _ _ _ _ step2,
      show ef + 12 = (ef + 11) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 11) _ _ _ _ step3,
      show ef + 11 = (ef + 10) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 10) _ _ _ _ step4,
      show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step5,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step6,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step7,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step8,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step9,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step10,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step11,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step12,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step13,
      StepLemmas.run_succ_error_of_step ef step14]

/-- When sigma oracle returns a non-empty result list (arity mismatch),
    run produces error. Same first 9 OK steps as `run_to_sigma_fail_produces_error`;
    final step uses `step_withdrawal_pc9_multi`. -/
theorem run_to_sigma_arity_mismatch_produces_error
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64)
    (curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 : ContainerStore) (sigmaFid : RefId)
    (sigmaResultHead : MoveValue) (sigmaResultTail : List MoveValue)
    (hFieldCount : 0 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc : initMs.containers.alloc (proofFields[0]'hFieldCount) = (cs1, sigmaFid))
    (fuel : Nat)
    (hfuel : fuel ≥ 10)
    (hsigmaArityMismatch :
       o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                ekRef, .u64 amount, curBalRef, newBalRef,
                                .immRef sigmaFid] = some (sigmaResultHead :: sigmaResultTail, cs2)) :
    run (withdrawalModuleEnv o)
        { code := verifyWithdrawalProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      ekRef, .u64 amount, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyWithdrawalProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    ekRef, .u64 amount, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 8 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 8 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_withdrawal_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 8 := by
    show (f0.locals.set 0 none hf0_lt0).size = 8; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_withdrawal_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 8 := by
    show (f1.locals.set 1 none hf1_lt1).size = 8; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_withdrawal_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 8 := by
    show (f2.locals.set 2 none hf2_lt2).size = 8; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some ekRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_withdrawal_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl ekRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 8 := by
    show (f3.locals.set 3 none hf3_lt3).size = 8; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some (.u64 amount) := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_withdrawal_pc4 o f4 []
                  [ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl (.u64 amount) hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 8 := by
    show (f4.locals.set 4 none hf4_lt4).size = 8; rw [Array.size_set]; exact hf4_size
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_withdrawal_pc5 o f5 []
                  [(.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 8 := by
    show (f5.locals.set 5 none hf5_lt5).size = 8; rw [Array.size_set]; exact hf5_size
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_withdrawal_pc6 o f6 []
                  [curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 8 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some proofRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_withdrawal_pc7 o f7 []
                  [newBalRef, curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf7_lt7 hf7_v7 hf7_ref7
  set f8 := { f7 with pc := 8 } with hf8_def
  have step9 := step_withdrawal_pc8 o f8 []
                  [newBalRef, curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread hFieldCount halloc
  set f9 := { f8 with pc := 9 } with hf9_def
  set ms9 : MachineState := { initMs with containers := cs1 } with hms9_def
  have htake :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, (.u64 amount : MoveValue),
              ekRef, (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 8 =
        some ([.u8 chainId, .address sender, .address contract, ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step10 := step_withdrawal_pc9_multi o f9 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, (.u64 amount : MoveValue),
                    ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms9 rfl rfl
                  [.u8 chainId, .address sender, .address contract, ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid]
                  [] sigmaResultHead sigmaResultTail cs2 htake hsigmaArityMismatch
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 10 := ⟨fuel - 10, by omega⟩
  rw [hef]
  rw [show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step1,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step2,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step3,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step4,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step5,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step6,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step7,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step8,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step9,
      StepLemmas.run_succ_error_of_step ef step10]

/-- When sigma succeeds but range oracle returns a non-empty result list (arity mismatch),
    run produces error. Same first 13 OK steps as `run_to_range_fail_produces_error`;
    final step uses `step_withdrawal_pc13_multi`. -/
theorem run_to_range_arity_mismatch_produces_error
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64)
    (curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 cs3 cs4 : ContainerStore)
    (sigmaFid zkrpFid : RefId)
    (rangeResultHead : MoveValue) (rangeResultTail : List MoveValue)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc0 : initMs.containers.alloc (proofFields[0]'(by omega : 0 < proofFields.length)) = (cs1, sigmaFid))
    (hsigmaOk : o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                        ekRef, .u64 amount, curBalRef, newBalRef,
                                        .immRef sigmaFid] = some ([], cs2))
    (hread2 : cs2.read proofRid = some (.struct_ proofFields))
    (halloc1 : cs2.alloc (proofFields[1]'hFieldCount) = (cs3, zkrpFid))
    (hrangeArityMismatch :
       o.verifyRangeProof cs3 [newBalRef, .immRef zkrpFid] =
         some (rangeResultHead :: rangeResultTail, cs4))
    (fuel : Nat)
    (hfuel : fuel ≥ 14) :
    run (withdrawalModuleEnv o)
        { code := verifyWithdrawalProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      ekRef, .u64 amount, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyWithdrawalProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    ekRef, .u64 amount, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 8 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 8 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_withdrawal_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 8 := by
    show (f0.locals.set 0 none hf0_lt0).size = 8; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_withdrawal_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 8 := by
    show (f1.locals.set 1 none hf1_lt1).size = 8; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_withdrawal_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 8 := by
    show (f2.locals.set 2 none hf2_lt2).size = 8; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some ekRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_withdrawal_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl ekRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 8 := by
    show (f3.locals.set 3 none hf3_lt3).size = 8; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some (.u64 amount) := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_withdrawal_pc4 o f4 []
                  [ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl (.u64 amount) hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 8 := by
    show (f4.locals.set 4 none hf4_lt4).size = 8; rw [Array.size_set]; exact hf4_size
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_withdrawal_pc5 o f5 []
                  [(.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 8 := by
    show (f5.locals.set 5 none hf5_lt5).size = 8; rw [Array.size_set]; exact hf5_size
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_withdrawal_pc6 o f6 []
                  [curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 8 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some proofRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_withdrawal_pc7 o f7 []
                  [newBalRef, curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf7_lt7 hf7_v7 hf7_ref7
  set f8 := { f7 with pc := 8 } with hf8_def
  have step9 := step_withdrawal_pc8 o f8 []
                  [newBalRef, curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread (by omega : 0 < proofFields.length) halloc0
  set f9 := { f8 with pc := 9 } with hf9_def
  set ms9 : MachineState := { initMs with containers := cs1 } with hms9_def
  have htake_pc9 :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, (.u64 amount : MoveValue),
              ekRef, (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 8 =
        some ([.u8 chainId, .address sender, .address contract, ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step10 := step_withdrawal_pc9 o f9 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, (.u64 amount : MoveValue),
                    ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms9 rfl rfl
                  [.u8 chainId, .address sender, .address contract, ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid]
                  [] cs2 htake_pc9 hsigmaOk
  set f10 := { f9 with pc := 10 } with hf10_def
  set ms10 : MachineState := { ms9 with containers := cs2, globals := ms9.globals } with hms10_def
  have hf10_lt6 : 6 < f10.locals.size := hf6_lt6
  have hf10_v6 : f10.locals[6]'hf10_lt6 = some newBalRef := hf6_v6
  have hf10_ref6 : ¬ 6 < f10.localRefs.size ∨
                   ∃ h : 6 < f10.localRefs.size, f10.localRefs[6]'h = none := hf6_ref6
  have step11 := step_withdrawal_pc10 o f10 [] [] ms10 rfl rfl newBalRef
                   hf10_lt6 hf10_v6 hf10_ref6
  set f11 := { f10 with pc := 11, locals := f10.locals.set 6 none hf10_lt6 } with hf11_def
  have hf11_size : f11.locals.size = 8 := by
    show (f10.locals.set 6 none hf10_lt6).size = 8; rw [Array.size_set]; exact hf7_size
  have hf11_lt7 : 7 < f11.locals.size := by rw [hf11_size]; decide
  have hf11_v7 : f11.locals[7]'hf11_lt7 = some proofRef := by
    show (f10.locals.set 6 none hf10_lt6)[7]'hf11_lt7 = _
    rw [Array.getElem_set, if_neg (by decide : (6 : Nat) ≠ 7)]
    exact hf7_v7
  have hf11_ref7 : ¬ 7 < f11.localRefs.size ∨
                   ∃ h : 7 < f11.localRefs.size, f11.localRefs[7]'h = none := by
    right; refine ⟨by simp [f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step12 := step_withdrawal_pc11 o f11 [] [newBalRef] ms10 rfl rfl proofRef
                   hf11_lt7 hf11_v7 hf11_ref7
  set f12 := { f11 with pc := 12, locals := f11.locals.set 7 none hf11_lt7 } with hf12_def
  have hms10_read : ms10.containers.read proofRid = some (.struct_ proofFields) := by
    show cs2.read proofRid = _
    exact hread2
  have step13 := step_withdrawal_pc12 o f12 [] [newBalRef] ms10 rfl rfl proofRid proofFields cs3
                   zkrpFid proofRef hproofRef hms10_read hFieldCount
                   (show ms10.containers.alloc _ = (cs3, zkrpFid) from
                     show cs2.alloc _ = (cs3, zkrpFid) from halloc1)
  set f13 := { f12 with pc := 13 } with hf13_def
  set ms13 : MachineState := { ms10 with containers := cs3 } with hms13_def
  have htake_pc13 :
      takeN [(.immRef zkrpFid : MoveValue), newBalRef] 2 =
        some ([newBalRef, .immRef zkrpFid], []) := rfl
  have step14 := step_withdrawal_pc13_multi o f13 []
                   [(.immRef zkrpFid : MoveValue), newBalRef]
                   ms13 rfl rfl
                   [newBalRef, .immRef zkrpFid] []
                   rangeResultHead rangeResultTail cs4 htake_pc13 hrangeArityMismatch
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 14 := ⟨fuel - 14, by omega⟩
  rw [hef]
  rw [show ef + 14 = (ef + 13) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 13) _ _ _ _ step1,
      show ef + 13 = (ef + 12) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 12) _ _ _ _ step2,
      show ef + 12 = (ef + 11) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 11) _ _ _ _ step3,
      show ef + 11 = (ef + 10) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 10) _ _ _ _ step4,
      show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step5,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step6,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step7,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step8,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step9,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step10,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step11,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step12,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step13,
      StepLemmas.run_succ_error_of_step ef step14]

/-- Happy path: sigma succeeds, range succeeds, ret. Run produces `.returned [] ms_final`. -/
theorem run_to_success_produces_returned
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64)
    (curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 cs3 cs4 : ContainerStore) (sigmaFid zkrpFid : RefId)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc0 : initMs.containers.alloc (proofFields[0]'(by omega : 0 < proofFields.length)) = (cs1, sigmaFid))
    (hsigmaOk : o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                        ekRef, .u64 amount, curBalRef, newBalRef,
                                        .immRef sigmaFid] = some ([], cs2))
    (hread2 : cs2.read proofRid = some (.struct_ proofFields))
    (halloc1 : cs2.alloc (proofFields[1]'hFieldCount) = (cs3, zkrpFid))
    (hrangeOk : o.verifyRangeProof cs3 [newBalRef, .immRef zkrpFid] = some ([], cs4))
    (fuel : Nat)
    (hfuel : fuel ≥ 15) :
    run (withdrawalModuleEnv o)
        { code := verifyWithdrawalProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      ekRef, .u64 amount, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel =
    .returned [] { initMs with containers := cs4, globals := initMs.globals } := by
  set f0 : Frame :=
      { code := verifyWithdrawalProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    ekRef, .u64 amount, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 8 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 8 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_withdrawal_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 8 := by
    show (f0.locals.set 0 none hf0_lt0).size = 8; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_withdrawal_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 8 := by
    show (f1.locals.set 1 none hf1_lt1).size = 8; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_withdrawal_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 8 := by
    show (f2.locals.set 2 none hf2_lt2).size = 8; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some ekRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_withdrawal_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl ekRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 8 := by
    show (f3.locals.set 3 none hf3_lt3).size = 8; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some (.u64 amount) := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_withdrawal_pc4 o f4 []
                  [ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl (.u64 amount) hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 8 := by
    show (f4.locals.set 4 none hf4_lt4).size = 8; rw [Array.size_set]; exact hf4_size
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_withdrawal_pc5 o f5 []
                  [(.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 8 := by
    show (f5.locals.set 5 none hf5_lt5).size = 8; rw [Array.size_set]; exact hf5_size
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_withdrawal_pc6 o f6 []
                  [curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 8 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some proofRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_withdrawal_pc7 o f7 []
                  [newBalRef, curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf7_lt7 hf7_v7 hf7_ref7
  set f8 := { f7 with pc := 8 } with hf8_def
  have step9 := step_withdrawal_pc8 o f8 []
                  [newBalRef, curBalRef, (.u64 amount : MoveValue), ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread (by omega : 0 < proofFields.length) halloc0
  set f9 := { f8 with pc := 9 } with hf9_def
  set ms9 : MachineState := { initMs with containers := cs1 } with hms9_def
  have htake_pc9 :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, (.u64 amount : MoveValue),
              ekRef, (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 8 =
        some ([.u8 chainId, .address sender, .address contract, ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step10 := step_withdrawal_pc9 o f9 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, (.u64 amount : MoveValue),
                    ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms9 rfl rfl
                  [.u8 chainId, .address sender, .address contract, ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid]
                  [] cs2 htake_pc9 hsigmaOk
  set f10 := { f9 with pc := 10 } with hf10_def
  set ms10 : MachineState := { ms9 with containers := cs2, globals := ms9.globals } with hms10_def
  have hf10_lt6 : 6 < f10.locals.size := hf6_lt6
  have hf10_v6 : f10.locals[6]'hf10_lt6 = some newBalRef := hf6_v6
  have hf10_ref6 : ¬ 6 < f10.localRefs.size ∨
                   ∃ h : 6 < f10.localRefs.size, f10.localRefs[6]'h = none := hf6_ref6
  have step11 := step_withdrawal_pc10 o f10 [] [] ms10 rfl rfl newBalRef
                   hf10_lt6 hf10_v6 hf10_ref6
  set f11 := { f10 with pc := 11, locals := f10.locals.set 6 none hf10_lt6 } with hf11_def
  have hf11_size : f11.locals.size = 8 := by
    show (f10.locals.set 6 none hf10_lt6).size = 8; rw [Array.size_set]; exact hf7_size
  have hf11_lt7 : 7 < f11.locals.size := by rw [hf11_size]; decide
  have hf11_v7 : f11.locals[7]'hf11_lt7 = some proofRef := by
    show (f10.locals.set 6 none hf10_lt6)[7]'hf11_lt7 = _
    rw [Array.getElem_set, if_neg (by decide : (6 : Nat) ≠ 7)]
    exact hf7_v7
  have hf11_ref7 : ¬ 7 < f11.localRefs.size ∨
                   ∃ h : 7 < f11.localRefs.size, f11.localRefs[7]'h = none := by
    right; refine ⟨by simp [f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step12 := step_withdrawal_pc11 o f11 [] [newBalRef] ms10 rfl rfl proofRef
                   hf11_lt7 hf11_v7 hf11_ref7
  set f12 := { f11 with pc := 12, locals := f11.locals.set 7 none hf11_lt7 } with hf12_def
  have hms10_read : ms10.containers.read proofRid = some (.struct_ proofFields) := by
    show cs2.read proofRid = _
    exact hread2
  have step13 := step_withdrawal_pc12 o f12 [] [newBalRef] ms10 rfl rfl proofRid proofFields cs3
                   zkrpFid proofRef hproofRef hms10_read hFieldCount
                   (show ms10.containers.alloc _ = (cs3, zkrpFid) from
                     show cs2.alloc _ = (cs3, zkrpFid) from halloc1)
  set f13 := { f12 with pc := 13 } with hf13_def
  set ms13 : MachineState := { ms10 with containers := cs3 } with hms13_def
  have htake_pc13 :
      takeN [(.immRef zkrpFid : MoveValue), newBalRef] 2 =
        some ([newBalRef, .immRef zkrpFid], []) := rfl
  have step14 := step_withdrawal_pc13 o f13 []
                   [(.immRef zkrpFid : MoveValue), newBalRef]
                   ms13 rfl rfl
                   [newBalRef, .immRef zkrpFid] [] cs4 htake_pc13 hrangeOk
  set f14 := { f13 with pc := 14 } with hf14_def
  set ms14 : MachineState := { ms13 with containers := cs4, globals := ms13.globals } with hms14_def
  have step15 := step_withdrawal_pc14 o f14 [] ms14 rfl rfl
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
      StepLemmas.run_succ_returned_of_step ef [] ms14 step15]

/-! ## Top-level equivalence theorem (Phase 4 closure) -/

/-- The withdrawal sigma oracle's frame condition: if sigma succeeds, the post-call
    container store still resolves the proof struct read. Same rationale as the
    Rotation analog. -/
abbrev WithdrawalSigmaPreservesProofRead
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState) (hFieldCount : 0 < proofFields.length) : Prop :=
  ∀ cs2,
    o.verifySigmaProof (initMs.containers.alloc (proofFields[0]'hFieldCount)).1
        [.u8 chainId, .address sender, .address contract,
         ekRef, .u64 amount, curBalRef, newBalRef,
         .immRef (initMs.containers.alloc (proofFields[0]'hFieldCount)).2] =
        some ([], cs2) →
    cs2.read proofRid = some (.struct_ proofFields)

theorem withdrawal_eval_equiv_functional_sim
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (hSigmaPreserves :
       WithdrawalSigmaPreservesProofRead o chainId sender contract ekRef amount
         curBalRef newBalRef proofRid proofFields initMs
         (by omega : 0 < proofFields.length))
    (fuel : Nat)
    (hfuel : fuel ≥ 15) :
    let args := [.u8 chainId, .address sender, .address contract,
                 ekRef, .u64 amount, curBalRef, newBalRef, proofRef]
    (eval (withdrawalModuleEnv o) verifyWithdrawalProofIdx args fuel initMs).dropMs =
    match verifyWithdrawalBytecodeResult o chainId sender contract ekRef amount curBalRef newBalRef
            proofRid proofFields initMs hFieldCount with
    | .returned _ => .returned [] MachineState.empty
    | .error => .error := by
  show (eval (withdrawalModuleEnv o) verifyWithdrawalProofIdx
          [.u8 chainId, .address sender, .address contract,
           ekRef, .u64 amount, curBalRef, newBalRef, proofRef]
          fuel initMs).dropMs = _
  rw [eval_withdrawal_eq_run]
  unfold verifyWithdrawalBytecodeResult
  rcases hSigmaPair : initMs.containers.alloc (proofFields[0]'(by omega : 0 < proofFields.length))
    with ⟨cs1, sigmaFid⟩
  match hsigma : o.verifySigmaProof cs1
                    [.u8 chainId, .address sender, .address contract,
                     ekRef, .u64 amount, curBalRef, newBalRef, .immRef sigmaFid] with
  | none =>
    have hRun := run_to_sigma_fail_produces_error o chainId sender contract
                  ekRef amount curBalRef newBalRef proofRef proofRid proofFields
                  initMs cs1 sigmaFid (by omega : 0 < proofFields.length)
                  hread hproofRef hSigmaPair fuel (by omega) hsigma
    rw [hRun]
    simp only [ExecResult.dropMs_error, hsigma]
  | some (sHead :: sTail, cs2) =>
    have hRun := run_to_sigma_arity_mismatch_produces_error o chainId sender contract
                  ekRef amount curBalRef newBalRef proofRef proofRid proofFields
                  initMs cs1 cs2 sigmaFid sHead sTail
                  (by omega : 0 < proofFields.length) hread hproofRef hSigmaPair
                  fuel (by omega) hsigma
    rw [hRun]
    simp only [ExecResult.dropMs_error, hsigma]
  | some ([], cs2) =>
    have hread2 : cs2.read proofRid = some (.struct_ proofFields) := by
      apply hSigmaPreserves cs2
      rw [hSigmaPair]; exact hsigma
    rcases hRangePair : cs2.alloc (proofFields[1]'hFieldCount) with ⟨cs3, zkrpFid⟩
    match hrange : o.verifyRangeProof cs3 [newBalRef, .immRef zkrpFid] with
    | none =>
      have hRun := run_to_range_fail_produces_error o chainId sender contract
                    ekRef amount curBalRef newBalRef proofRef proofRid proofFields
                    initMs cs1 cs2 cs3 sigmaFid zkrpFid hFieldCount hread hproofRef
                    hSigmaPair hsigma hread2 hRangePair hrange fuel (by omega)
      rw [hRun]
      simp only [ExecResult.dropMs_error, hsigma, hRangePair, hrange]
    | some (rHead :: rTail, cs4) =>
      have hRun := run_to_range_arity_mismatch_produces_error o chainId sender contract
                    ekRef amount curBalRef newBalRef proofRef proofRid proofFields
                    initMs cs1 cs2 cs3 cs4 sigmaFid zkrpFid rHead rTail hFieldCount
                    hread hproofRef hSigmaPair hsigma hread2 hRangePair hrange
                    fuel (by omega)
      rw [hRun]
      simp only [ExecResult.dropMs_error, hsigma, hRangePair, hrange]
    | some ([], cs4) =>
      have hRun := run_to_success_produces_returned o chainId sender contract
                    ekRef amount curBalRef newBalRef proofRef proofRid proofFields
                    initMs cs1 cs2 cs3 cs4 sigmaFid zkrpFid hFieldCount hread hproofRef
                    hSigmaPair hsigma hread2 hRangePair hrange fuel (by omega)
      rw [hRun]
      simp only [ExecResult.dropMs_returned, hsigma, hRangePair, hrange]

end MovementFormal.Experimental.ConfidentialAsset.Withdrawal.EvalEquiv
